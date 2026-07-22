"""
BOT TELEGRAM - MODULO CLIENTE B2B
Sistema Panificadora
Flujo: Tipo de Pan → Masa → Producto → Cantidad
Catálogo 100% data-driven desde tabla productos
"""

import io
import os
import logging
from datetime import date, timedelta
import asyncpg
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, filters, ContextTypes, ConversationHandler
)

from generador_recibos import procesar_recibo

# ── Config ──────────────────────────────────────────────────────────────────
TELEGRAM_TOKEN    = os.getenv("TELEGRAM_TOKEN")
DUENO_TELEGRAM_ID = os.getenv("DUENO_TELEGRAM_ID", "@luisepm92")

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "panificadora"),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

(SEL_TIPO_PAN, SEL_MASA, SEL_PRODUCTO,
 INGRESAR_CANTIDAD, SEL_TOPING, CONFIRMAR_PEDIDO,
 CAMBIAR_CANTIDAD_MOD, MODIFICAR_CARRITO) = range(8)

# ── Base de datos ────────────────────────────────────────────────────────────
async def get_conn():
    return await asyncpg.connect(**DB_CONFIG)

async def get_cliente(telegram_id: str):
    conn = await get_conn()
    try:
        return await conn.fetchrow(
            "SELECT * FROM clientes WHERE telegram_id = $1 AND estado = 'activo'",
            telegram_id
        )
    finally:
        await conn.close()

async def get_deuda(cliente_id: int) -> float:
    conn = await get_conn()
    try:
        return await conn.fetchval(
            "SELECT COALESCE(SUM(saldo_pendiente), 0) FROM deudas WHERE id_cliente = $1 AND estado != 'pagado'",
            cliente_id
        ) or 0.0
    finally:
        await conn.close()

async def db_tipos_pan() -> list[str]:
    """Tipos de pan físico disponibles, ordenados alfabéticamente."""
    conn = await get_conn()
    try:
        rows = await conn.fetch(
            "SELECT DISTINCT tipo_pan FROM productos WHERE activo = TRUE ORDER BY tipo_pan"
        )
        return [r["tipo_pan"] for r in rows]
    finally:
        await conn.close()

async def db_masas_para_pan(tipo_pan: str) -> list[str]:
    """Masas disponibles para un tipo de pan."""
    conn = await get_conn()
    try:
        rows = await conn.fetch(
            "SELECT DISTINCT tipo_masa FROM productos WHERE tipo_pan = $1 AND activo = TRUE AND tipo_masa IS NOT NULL ORDER BY tipo_masa",
            tipo_pan
        )
        return [r["tipo_masa"] for r in rows]
    finally:
        await conn.close()

async def db_productos(tipo_pan: str, tipo_masa: str) -> list[dict]:
    """Productos para un tipo de pan + masa, ordenados por peso."""
    conn = await get_conn()
    try:
        rows = await conn.fetch("""
            SELECT id_producto, nombre, peso_g, precio_unitario,
                   paquete_cantidad, paquete_tipo
            FROM productos
            WHERE tipo_pan = $1 AND tipo_masa = $2 AND activo = TRUE
            ORDER BY peso_g NULLS LAST, precio_unitario
        """, tipo_pan, tipo_masa)
        return [dict(r) for r in rows]
    finally:
        await conn.close()

async def db_topings() -> list[dict]:
    """Topings activos para mostrar en el bot."""
    conn = await get_conn()
    try:
        rows = await conn.fetch(
            "SELECT id_toping, nombre FROM topings WHERE activo = TRUE ORDER BY nombre"
        )
        return [dict(r) for r in rows]
    finally:
        await conn.close()

async def guardar_pedido(cliente_id: int, items: list, nombre_cliente: str) -> tuple:
    conn = await get_conn()
    try:
        total         = sum(i["subtotal"] for i in items)
        fecha_entrega = date.today() + timedelta(days=1)
        num_recibo    = await conn.fetchval("SELECT generar_numero_recibo()")

        async with conn.transaction():
            id_pedido = await conn.fetchval("""
                INSERT INTO pedidos
                    (id_cliente, numero_recibo, fecha_entrega, estado, monto_total, registrado_por)
                VALUES ($1, $2, $3, 'pendiente', $4, $5)
                RETURNING id_pedido
            """, cliente_id, num_recibo, fecha_entrega, total, nombre_cliente)

            for item in items:
                await conn.execute("""
                    INSERT INTO detalle_pedidos
                        (id_pedido, tipo_pan, producto, peso_g, cantidad, tipo_unidad, precio_unitario, subtotal, toping)
                    VALUES ($1, $2, $3, $4, $5, $6::tipo_unidad, $7, $8, $9)
                """, id_pedido,
                    item["tipo_masa"],
                    item["nombre"],
                    item["peso_g"],
                    item["cantidad"],
                    item.get("tipo_unidad", "unidad"),
                    item["precio_unitario"],
                    item["subtotal"],
                    item.get("toping"))

            await conn.execute(
                "INSERT INTO deudas (id_cliente, id_pedido, monto_original) VALUES ($1, $2, $3)",
                cliente_id, id_pedido, total
            )

        return id_pedido, num_recibo, total, fecha_entrega
    finally:
        await conn.close()

# ── Helpers UI ───────────────────────────────────────────────────────────────
def _teclado_lista(items: list[str], prefix: str, cols: int = 2,
                   extra: list[list] | None = None) -> InlineKeyboardMarkup:
    """Genera teclado inline en grid de `cols` columnas."""
    filas, fila = [], []
    for item in items:
        fila.append(InlineKeyboardButton(item, callback_data=f"{prefix}|{item}"))
        if len(fila) == cols:
            filas.append(fila)
            fila = []
    if fila:
        filas.append(fila)
    if extra:
        filas.extend(extra)
    filas.append([InlineKeyboardButton("❌ Cancelar pedido", callback_data="cancelar_pedido")])
    return InlineKeyboardMarkup(filas)

def _label_producto(p: dict) -> str:
    peso = f"{p['peso_g']}g" if p.get("peso_g") else ""
    if p.get("paquete_cantidad") and p["paquete_cantidad"] > 1:
        return f"{peso} x{p['paquete_cantidad']} — ${float(p['precio_unitario']):.2f}".strip(" — ")
    return f"{peso} — ${float(p['precio_unitario']):.2f}".strip(" — ")

def _resumen_carrito(items: list) -> tuple[str, float]:
    lineas = []
    for i in items:
        peso = f"{i['peso_g']}g" if i.get("peso_g") else ""
        paq  = i.get("paquete_cantidad", 1)
        if paq > 1:
            unidades_reales = i["cantidad"] * paq
            unidad_str = f"×{i['cantidad']} paq ({unidades_reales} uds)"
        else:
            unidad_str = f"×{i['cantidad']}"
        toping_str = f" 🌿 {i['toping']}" if i.get("toping") else ""
        lineas.append(
            f"• {i['tipo_pan_display']} {i['tipo_masa']} {peso} {unidad_str}{toping_str} = ${i['subtotal']:.2f}"
        )
    total = sum(i["subtotal"] for i in items)
    return "\n".join(lineas), total

async def _verificar_cliente(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user  = update.effective_user
    tg_id = str(user.id)
    cliente = await get_cliente(tg_id)
    if cliente:
        context.user_data["cliente"] = dict(cliente)
    return cliente

# ── /start ────────────────────────────────────────────────────────────────────
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    cliente = await _verificar_cliente(update, context)
    if not cliente:
        await update.message.reply_text(
            "❌ *No estás registrado como cliente.*\n\n"
            f"Contacta con la panificadora:\n👤 {DUENO_TELEGRAM_ID}",
            parse_mode="Markdown"
        )
        return ConversationHandler.END

    deuda     = await get_deuda(cliente["id_cliente"])
    manana    = (date.today() + timedelta(days=1)).strftime("%d/%m/%Y")
    deuda_str = f"\n💳 Saldo pendiente: *${deuda:.2f}*" if deuda > 0 else "\n✅ Sin deuda pendiente"

    teclado = InlineKeyboardMarkup([
        [InlineKeyboardButton("🍞 Realizar Pedido", callback_data="nuevo_pedido")]
    ])
    await update.message.reply_text(
        f"🍞 *Bienvenido, {cliente['nombre_negocio']}*\n\n"
        f"📅 Entrega: *{manana}*"
        f"{deuda_str}\n\n"
        f"Usa /pedir para comenzar rápidamente.",
        reply_markup=teclado,
        parse_mode="Markdown"
    )

# ── /pedir ────────────────────────────────────────────────────────────────────
async def pedir(update: Update, context: ContextTypes.DEFAULT_TYPE):
    cliente = await _verificar_cliente(update, context)
    if not cliente:
        await update.message.reply_text(
            f"❌ No estás registrado. Contacta con la panificadora:\n👤 {DUENO_TELEGRAM_ID}"
        )
        return ConversationHandler.END

    context.user_data["items"] = []
    tipos = await db_tipos_pan()
    await update.message.reply_text(
        "🍞 *¿Qué tipo de pan necesitas?*",
        reply_markup=_teclado_lista(tipos, "tipopan", cols=2),
        parse_mode="Markdown"
    )
    return SEL_TIPO_PAN

# ── Nuevo pedido (desde botón) ─────────────────────────────────────────────
async def nuevo_pedido(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    context.user_data["items"] = []
    tipos = await db_tipos_pan()
    await query.edit_message_text(
        "🍞 *¿Qué tipo de pan necesitas?*",
        reply_markup=_teclado_lista(tipos, "tipopan", cols=2),
        parse_mode="Markdown"
    )
    return SEL_TIPO_PAN

# ── Agregar más (preserva carrito) ────────────────────────────────────────────
async def agregar_mas(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    items = context.user_data.get("items", [])
    _, total = _resumen_carrito(items)
    tipos = await db_tipos_pan()
    await query.edit_message_text(
        f"🍞 *Agregar otro producto*\n"
        f"_(Carrito: {len(items)} producto(s) — ${total:.2f})_\n\n"
        f"¿Qué tipo de pan necesitas?",
        reply_markup=_teclado_lista(tipos, "tipopan", cols=2),
        parse_mode="Markdown"
    )
    return SEL_TIPO_PAN

# ── PASO 1: Seleccionar tipo de pan ──────────────────────────────────────────
async def seleccionar_tipo_pan(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    tipo_pan = query.data.split("|", 1)[1]
    context.user_data["tipo_pan_actual"] = tipo_pan

    masas = await db_masas_para_pan(tipo_pan)

    if len(masas) == 1:
        # Solo una masa → saltar directo a productos
        context.user_data["tipo_masa_actual"] = masas[0]
        productos = await db_productos(tipo_pan, masas[0])
        return await _mostrar_productos(query, tipo_pan, masas[0], productos)

    await query.edit_message_text(
        f"✅ *{tipo_pan}*\n\n🧪 ¿En qué masa lo quieres?",
        reply_markup=_teclado_lista(masas, "masa", cols=2, extra=[
            [InlineKeyboardButton("🔙 Cambiar tipo de pan", callback_data="cambiar_tipopan")]
        ]),
        parse_mode="Markdown"
    )
    return SEL_MASA

# ── PASO 2: Seleccionar masa ──────────────────────────────────────────────────
async def seleccionar_masa(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    tipo_masa = query.data.split("|", 1)[1]
    tipo_pan  = context.user_data["tipo_pan_actual"]
    context.user_data["tipo_masa_actual"] = tipo_masa

    productos = await db_productos(tipo_pan, tipo_masa)
    return await _mostrar_productos(query, tipo_pan, tipo_masa, productos)

async def _mostrar_productos(query, tipo_pan: str, tipo_masa: str, productos: list):
    if not productos:
        await query.edit_message_text(
            f"⚠️ No hay productos disponibles para *{tipo_pan} — {tipo_masa}*.\n\nVuelve a intentarlo.",
            parse_mode="Markdown"
        )
        return ConversationHandler.END

    filas, fila = [], []
    for p in productos:
        label = _label_producto(p)
        fila.append(InlineKeyboardButton(label, callback_data=f"prod|{p['id_producto']}"))
        if len(fila) == 2:
            filas.append(fila)
            fila = []
    if fila:
        filas.append(fila)
    filas.append([InlineKeyboardButton("🔙 Cambiar masa", callback_data="cambiar_masa")])
    filas.append([InlineKeyboardButton("❌ Cancelar pedido", callback_data="cancelar_pedido")])

    await query.edit_message_text(
        f"✅ *{tipo_pan} — {tipo_masa}*\n\n⚖️ Selecciona peso y precio:",
        reply_markup=InlineKeyboardMarkup(filas),
        parse_mode="Markdown"
    )
    return SEL_PRODUCTO

# ── PASO 3: Seleccionar producto ──────────────────────────────────────────────
async def seleccionar_producto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    id_producto = int(query.data.split("|", 1)[1])

    # Buscar el producto en BD
    conn = await get_conn()
    try:
        prod = await conn.fetchrow(
            "SELECT * FROM productos WHERE id_producto = $1", id_producto
        )
    finally:
        await conn.close()

    if not prod:
        await query.answer("❌ Producto no encontrado.", show_alert=True)
        return SEL_PRODUCTO

    context.user_data["producto_actual"] = dict(prod)
    peso_str   = f"{prod['peso_g']}g" if prod.get("peso_g") else ""
    paq_cant   = prod.get("paquete_cantidad") or 1
    es_paquete = paq_cant > 1

    if es_paquete:
        paq_tipo    = prod.get("paquete_tipo") or "unidades"
        detalle_str = f"📦 1 paquete = *{paq_cant} panes* de {peso_str}\n" if peso_str else f"📦 {paq_cant} panes por paquete\n"
        pregunta    = f"¿Cuántos *paquetes* necesitas?"
        precio_str  = f"💲 *${float(prod['precio_unitario']):.2f}* por paquete"
    else:
        detalle_str = f"⚖️ {peso_str}\n" if peso_str else ""
        pregunta    = f"¿Cuántas *unidades* necesitas?"
        precio_str  = f"💲 *${float(prod['precio_unitario']):.2f}* por unidad"

    await query.edit_message_text(
        f"✅ *{prod['nombre']}*\n"
        f"{detalle_str}"
        f"{precio_str}\n\n"
        f"{pregunta}\n"
        f"_(Escribe el número — o /cancelar para salir)_",
        parse_mode="Markdown"
    )
    return INGRESAR_CANTIDAD

# ── PASO 4: Ingresar cantidad ─────────────────────────────────────────────────
async def ingresar_cantidad(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        cantidad = int(update.message.text.strip())
        if cantidad <= 0:
            raise ValueError
    except ValueError:
        prod = context.user_data.get("producto_actual", {})
        paq  = prod.get("paquete_cantidad") or 1
        tip  = "paquetes" if paq > 1 else "unidades"
        await update.message.reply_text(
            f"❌ Cantidad inválida. Escribe un número entero mayor a 0 ({tip}):\n"
            "_(ej: 2, 5, 10)_\n\n_(o /cancelar para salir)_",
            parse_mode="Markdown"
        )
        return INGRESAR_CANTIDAD

    prod       = context.user_data["producto_actual"]
    precio     = float(prod["precio_unitario"])
    subtotal   = round(precio * cantidad, 2)
    paq_cant   = prod.get("paquete_cantidad") or 1
    tipo_unidad = "paquete" if paq_cant > 1 else "unidad"

    context.user_data["item_pendiente"] = {
        "tipo_pan_display": prod["tipo_pan"],
        "tipo_masa":        prod["tipo_masa"],
        "nombre":           prod["nombre"],
        "peso_g":           prod.get("peso_g"),
        "paquete_cantidad": paq_cant,
        "tipo_unidad":      tipo_unidad,
        "cantidad":         cantidad,
        "precio_unitario":  precio,
        "subtotal":         subtotal,
        "toping":           None,
    }

    # Mostrar selector de toping
    topings = await db_topings()
    botones = [
        [InlineKeyboardButton(t["nombre"], callback_data=f"toping|{t['nombre']}")]
        for t in topings
    ]
    botones.append([InlineKeyboardButton("Sin toping", callback_data="toping|")])

    nombre_prod = prod["nombre"]
    await update.message.reply_text(
        f"🌿 *¿Toping para {nombre_prod}?*\n\nElige uno o selecciona «Sin toping»:",
        reply_markup=InlineKeyboardMarkup(botones),
        parse_mode="Markdown",
    )
    return SEL_TOPING

# ── PASO 4b: Seleccionar toping ───────────────────────────────────────────────
async def seleccionar_toping(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    valor  = query.data.split("|", 1)[1]  # nombre del toping o "" para sin toping
    item   = context.user_data.pop("item_pendiente")
    item["toping"] = valor if valor else None

    context.user_data["items"].append(item)

    toping_txt = f"🌿 _{valor}_" if valor else "sin toping"
    await query.edit_message_text(
        f"✅ *{item['nombre']}* ×{item['cantidad']} agregado ({toping_txt}).",
        parse_mode="Markdown",
    )
    return await _mostrar_resumen_carrito(query.message, context, via_query=False)

# ── Resumen carrito ────────────────────────────────────────────────────────────
async def _mostrar_resumen_carrito(msg_o_query, context, via_query: bool):
    items          = context.user_data.get("items", [])
    resumen, total = _resumen_carrito(items)
    manana         = (date.today() + timedelta(days=1)).strftime("%d/%m/%Y")

    teclado = InlineKeyboardMarkup([
        [InlineKeyboardButton("➕ Agregar otro producto", callback_data="agregar_mas")],
        [InlineKeyboardButton("✏️ Modificar Pedido",      callback_data="modificar_carrito")],
        [InlineKeyboardButton("✅ Confirmar Pedido",       callback_data="confirmar")],
        [InlineKeyboardButton("❌ Cancelar todo",          callback_data="cancelar_pedido")],
    ])
    texto = (
        f"🛒 *Tu pedido ({len(items)} producto(s)):*\n\n"
        f"{resumen}\n\n"
        f"💰 *TOTAL: ${total:.2f}*\n"
        f"📅 Entrega: {manana}"
    )
    if via_query:
        await msg_o_query.edit_message_text(texto, reply_markup=teclado, parse_mode="Markdown")
    else:
        await msg_o_query.reply_text(texto, reply_markup=teclado, parse_mode="Markdown")
    return CONFIRMAR_PEDIDO

# ── Modificar carrito ─────────────────────────────────────────────────────────
async def _mostrar_carrito_modificar(msg_o_query, context, via_query: bool = True):
    items = context.user_data.get("items", [])

    if not items:
        teclado = InlineKeyboardMarkup([
            [InlineKeyboardButton("➕ Agregar productos", callback_data="agregar_mas")],
            [InlineKeyboardButton("❌ Cancelar pedido",   callback_data="cancelar_pedido")],
        ])
        texto = "⚠️ *Carrito vacío*\n\nAgrega al menos un producto."
        if via_query:
            await msg_o_query.edit_message_text(texto, reply_markup=teclado, parse_mode="Markdown")
        else:
            await msg_o_query.reply_text(texto, reply_markup=teclado, parse_mode="Markdown")
        return MODIFICAR_CARRITO

    total = sum(i["subtotal"] for i in items)
    texto = "✏️ *Modificar Carrito*\n\n"
    for n, i in enumerate(items, 1):
        peso = f"{i['peso_g']}g" if i.get("peso_g") else ""
        paq  = i.get("paquete_cantidad", 1)
        if paq > 1:
            cant_str = f"×{i['cantidad']} paq ({i['cantidad'] * paq} uds)"
        else:
            cant_str = f"×{i['cantidad']}"
        texto += f"{n}. {i['tipo_pan_display']} {i['tipo_masa']} {peso} {cant_str} = ${i['subtotal']:.2f}\n"
    texto += f"\n💰 Total: *${total:.2f}*"

    filas = [
        [InlineKeyboardButton(f"{n}. 🗑️ Quitar",  callback_data=f"quitar_carr|{n-1}"),
         InlineKeyboardButton(f"{n}. 📝 Cantidad", callback_data=f"cambiar_carr|{n-1}")]
        for n in range(1, len(items) + 1)
    ]
    filas.append([InlineKeyboardButton("➕ Agregar otro producto",     callback_data="agregar_mas")])
    filas.append([InlineKeyboardButton("✅ Listo — Volver al resumen", callback_data="listo_carrito")])

    teclado = InlineKeyboardMarkup(filas)
    if via_query:
        await msg_o_query.edit_message_text(texto, reply_markup=teclado, parse_mode="Markdown")
    else:
        await msg_o_query.reply_text(texto, reply_markup=teclado, parse_mode="Markdown")
    return MODIFICAR_CARRITO

async def modificar_carrito_btn(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    return await _mostrar_carrito_modificar(query, context)

async def quitar_del_carrito(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    idx   = int(query.data.split("|")[1])
    items = context.user_data.get("items", [])
    if 0 <= idx < len(items):
        items.pop(idx)
        context.user_data["items"] = items
    return await _mostrar_carrito_modificar(query, context)

async def cambiar_cant_carrito(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    idx   = int(query.data.split("|")[1])
    items = context.user_data.get("items", [])
    if idx < 0 or idx >= len(items):
        await query.answer("❌ Producto no encontrado.", show_alert=True)
        return MODIFICAR_CARRITO
    item = items[idx]
    context.user_data["cambiar_carrito_info"] = {
        "idx":             idx,
        "precio_unitario": item["precio_unitario"],
        "cantidad_actual": item["cantidad"],
    }
    peso = f"{item['peso_g']}g" if item.get("peso_g") else ""
    paq  = item.get("paquete_cantidad", 1)
    unidad_label = "paq" if paq > 1 else "uds"
    await query.edit_message_text(
        f"📝 *Cambiar cantidad*\n\n"
        f"*{item['tipo_pan_display']} {item['tipo_masa']} {peso}*\n"
        f"Cantidad actual: *{item['cantidad']} {unidad_label}*\n\n"
        f"¿Cuántas {unidad_label} necesitas?\n_(o /cancelar para salir)_",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("🔙 Volver al carrito", callback_data="listo_carrito")]
        ]),
        parse_mode="Markdown"
    )
    return CAMBIAR_CANTIDAD_MOD

async def recibir_nueva_cantidad(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        nueva = int(update.message.text.strip())
        if nueva <= 0:
            raise ValueError
    except ValueError:
        await update.message.reply_text(
            "❌ Escribe un número entero mayor a 0:", parse_mode="Markdown"
        )
        return CAMBIAR_CANTIDAD_MOD

    info  = context.user_data.pop("cambiar_carrito_info", None)
    if not info:
        await update.message.reply_text("❌ Error de sesión. Vuelve a intentarlo.")
        return ConversationHandler.END

    idx   = info["idx"]
    items = context.user_data.get("items", [])
    if 0 <= idx < len(items):
        items[idx]["cantidad"] = nueva
        items[idx]["subtotal"] = round(info["precio_unitario"] * nueva, 2)
        context.user_data["items"] = items
    return await _mostrar_carrito_modificar(update.message, context, via_query=False)

async def listo_carrito(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    return await _mostrar_resumen_carrito(query, context, via_query=True)

# ── Navegación hacia atrás ────────────────────────────────────────────────────
async def cambiar_tipopan(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    tipos = await db_tipos_pan()
    await query.edit_message_text(
        "🍞 *¿Qué tipo de pan necesitas?*",
        reply_markup=_teclado_lista(tipos, "tipopan", cols=2),
        parse_mode="Markdown"
    )
    return SEL_TIPO_PAN

async def cambiar_masa(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query    = update.callback_query
    await query.answer()
    tipo_pan = context.user_data.get("tipo_pan_actual", "")
    masas    = await db_masas_para_pan(tipo_pan)
    await query.edit_message_text(
        f"✅ *{tipo_pan}*\n\n🧪 ¿En qué masa lo quieres?",
        reply_markup=_teclado_lista(masas, "masa", cols=2, extra=[
            [InlineKeyboardButton("🔙 Cambiar tipo de pan", callback_data="cambiar_tipopan")]
        ]),
        parse_mode="Markdown"
    )
    return SEL_MASA

# ── Confirmar pedido ──────────────────────────────────────────────────────────
async def confirmar_pedido(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query   = update.callback_query
    await query.answer()
    cliente = context.user_data["cliente"]
    items   = context.user_data["items"]

    await query.edit_message_text("⏳ Guardando tu pedido...")

    try:
        id_pedido, num_recibo, total, fecha_entrega = await guardar_pedido(
            cliente["id_cliente"], items, cliente["nombre_negocio"]
        )
    except Exception as e:
        logger.error(f"Error guardando pedido: {e}")
        teclado = InlineKeyboardMarkup([
            [InlineKeyboardButton("🔄 Intentar de nuevo", callback_data="confirmar")],
            [InlineKeyboardButton("❌ Cancelar",           callback_data="cancelar_pedido")],
        ])
        await query.edit_message_text(
            "❌ *Error al procesar el pedido.*\n\nIntenta de nuevo o contacta con la panificadora:\n"
            f"👤 {DUENO_TELEGRAM_ID}",
            reply_markup=teclado,
            parse_mode="Markdown"
        )
        return CONFIRMAR_PEDIDO

    await query.edit_message_text(
        f"⏳ *Tu pedido está en revisión*\n\n"
        f"📄 Recibo N°: *{num_recibo}*\n"
        f"💰 Total: *${total:.2f}*\n\n"
        f"📎 Generando tu recibo PDF...",
        parse_mode="Markdown"
    )

    teclado_nuevo = InlineKeyboardMarkup([
        [InlineKeyboardButton("🍞 Hacer otro pedido", callback_data="nuevo_pedido")]
    ])
    try:
        _ruta, pdf_bytes = await procesar_recibo(id_pedido)
        caption = (
            f"📄 *Recibo N° {num_recibo}*\n"
            f"🏪 {cliente['nombre_negocio']}\n"
            f"💰 Total: ${total:.2f}\n\n"
            f"⏳ Tu pedido está en revisión por el admin."
        )
        await query.message.reply_document(
            document=io.BytesIO(pdf_bytes),
            filename=f"Recibo_{num_recibo}_{cliente['nombre_negocio'].replace(' ', '_')}.pdf",
            caption=caption,
            parse_mode="Markdown",
            reply_markup=teclado_nuevo,
        )
    except Exception as pdf_err:
        logger.error(f"Error generando PDF pedido {id_pedido}: {pdf_err}")
        await query.message.reply_text(
            "⏳ *Tu pedido está en revisión por el admin.*\n\n"
            "⚠️ El recibo PDF no pudo generarse en este momento.\n"
            "Contacta a la panificadora para recibirlo.",
            reply_markup=teclado_nuevo,
            parse_mode="Markdown",
        )

    context.user_data["items"] = []
    return ConversationHandler.END

# ── Cancelar ──────────────────────────────────────────────────────────────────
async def cancelar_pedido_inline(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    items = context.user_data.get("items", [])
    if items:
        _, total = _resumen_carrito(items)
        texto = f"❌ *Pedido cancelado.*\n\nTenías ${total:.2f} en el carrito.\n\n¿Deseas comenzar uno nuevo?"
    else:
        texto = "❌ *Pedido cancelado.*\n\n¿Deseas hacer un nuevo pedido?"
    context.user_data["items"] = []
    teclado = InlineKeyboardMarkup([
        [InlineKeyboardButton("🍞 Nuevo pedido", callback_data="nuevo_pedido")]
    ])
    await query.edit_message_text(texto, reply_markup=teclado, parse_mode="Markdown")
    return ConversationHandler.END

async def cancelar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["items"] = []
    teclado = InlineKeyboardMarkup([
        [InlineKeyboardButton("🍞 Nuevo pedido", callback_data="nuevo_pedido")]
    ])
    await update.message.reply_text(
        "❌ *Pedido cancelado.*\n\n¿Deseas hacer un nuevo pedido?",
        reply_markup=teclado,
        parse_mode="Markdown",
    )
    return ConversationHandler.END

# ── App ───────────────────────────────────────────────────────────────────────
def build_app() -> Application:
    app  = Application.builder().token(TELEGRAM_TOKEN).build()
    conv = ConversationHandler(
        entry_points=[
            CommandHandler("start",  start),
            CommandHandler("pedir",  pedir),
            CallbackQueryHandler(nuevo_pedido, pattern="^nuevo_pedido$"),
            MessageHandler(filters.TEXT & ~filters.COMMAND, start),
        ],
        states={
            SEL_TIPO_PAN: [
                CallbackQueryHandler(seleccionar_tipo_pan,   pattern="^tipopan\\|"),
                CallbackQueryHandler(cancelar_pedido_inline, pattern="^cancelar_pedido$"),
            ],
            SEL_MASA: [
                CallbackQueryHandler(seleccionar_masa,       pattern="^masa\\|"),
                CallbackQueryHandler(cambiar_tipopan,        pattern="^cambiar_tipopan$"),
                CallbackQueryHandler(cancelar_pedido_inline, pattern="^cancelar_pedido$"),
            ],
            SEL_PRODUCTO: [
                CallbackQueryHandler(seleccionar_producto,   pattern="^prod\\|"),
                CallbackQueryHandler(cambiar_masa,           pattern="^cambiar_masa$"),
                CallbackQueryHandler(cambiar_tipopan,        pattern="^cambiar_tipopan$"),
                CallbackQueryHandler(cancelar_pedido_inline, pattern="^cancelar_pedido$"),
            ],
            INGRESAR_CANTIDAD: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, ingresar_cantidad),
            ],
            SEL_TOPING: [
                CallbackQueryHandler(seleccionar_toping,     pattern="^toping\\|"),
                CallbackQueryHandler(cancelar_pedido_inline, pattern="^cancelar_pedido$"),
            ],
            CONFIRMAR_PEDIDO: [
                CallbackQueryHandler(confirmar_pedido,       pattern="^confirmar$"),
                CallbackQueryHandler(agregar_mas,            pattern="^agregar_mas$"),
                CallbackQueryHandler(modificar_carrito_btn,  pattern="^modificar_carrito$"),
                CallbackQueryHandler(cancelar_pedido_inline, pattern="^cancelar_pedido$"),
            ],
            CAMBIAR_CANTIDAD_MOD: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, recibir_nueva_cantidad),
                CallbackQueryHandler(listo_carrito,          pattern="^listo_carrito$"),
            ],
            MODIFICAR_CARRITO: [
                CallbackQueryHandler(quitar_del_carrito,     pattern="^quitar_carr\\|"),
                CallbackQueryHandler(cambiar_cant_carrito,   pattern="^cambiar_carr\\|"),
                CallbackQueryHandler(agregar_mas,            pattern="^agregar_mas$"),
                CallbackQueryHandler(listo_carrito,          pattern="^listo_carrito$"),
                CallbackQueryHandler(cancelar_pedido_inline, pattern="^cancelar_pedido$"),
            ],
        },
        fallbacks=[
            CommandHandler("cancelar", cancelar),
            CommandHandler("start",    start),
            CommandHandler("pedir",    pedir),
        ],
    )
    app.add_handler(conv)
    return app

def main():
    logger.info("✅ Bot Cliente iniciado. Esperando pedidos...")
    build_app().run_polling()

if __name__ == "__main__":
    main()
