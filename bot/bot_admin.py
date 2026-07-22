"""
BOT TELEGRAM - MODULO ADMIN (Solo Lectura)
Sistema Panificadora
Acceso: Solo usuarios en tabla 'usuarios' con estado activo
"""

import os
import logging
from datetime import date, datetime, timedelta
from functools import wraps
import asyncpg
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, filters, ContextTypes, ConversationHandler
)

# ── Configuración ──────────────────────────────────────────────────────────────
ADMIN_TOKEN = os.getenv("ADMIN_TELEGRAM_TOKEN")

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "panificadora"),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

(MENU_PRINCIPAL,
 VER_PEDIDOS,
 SEL_FECHA_PROD, VER_PRODUCCION,
 VER_DESPACHOS,
 MENU_DEUDAS, BUSCAR_DEUDA_INPUT,
 VER_CLIENTES,
 VER_DETALLE_DEUDA,
 INGRESAR_MONTO_PAGO,
 SEL_METODO_PAGO) = range(11)

BTN_MENU = InlineKeyboardButton("◀️ Menú Principal", callback_data="volver_menu")

# ── Base de datos ──────────────────────────────────────────────────────────────
async def get_conn():
    return await asyncpg.connect(**DB_CONFIG)

async def get_usuario(telegram_id: str):
    conn = await get_conn()
    try:
        return await conn.fetchrow(
            "SELECT * FROM usuarios WHERE telegram_id = $1 AND estado = 'activo'",
            telegram_id
        )
    finally:
        await conn.close()

# ── Autenticación ──────────────────────────────────────────────────────────────
def solo_admin(func):
    @wraps(func)
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        obj   = update.message or update.callback_query.message
        user  = update.effective_user
        tg_id = str(user.id)
        usuario = await get_usuario(tg_id)
        if not usuario:
            await obj.reply_text("❌ Acceso no autorizado.\nContacta al administrador del sistema.")
            return ConversationHandler.END
        conn = await get_conn()
        try:
            await conn.execute(
                "UPDATE usuarios SET ultimo_acceso = NOW() WHERE telegram_id = $1",
                tg_id
            )
        finally:
            await conn.close()
        context.user_data["usuario"] = dict(usuario)
        return await func(update, context)
    return wrapper

async def _validar_sesion(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    """Verifica que el usuario haya pasado por @solo_admin. Rechaza si no."""
    if context.user_data.get("usuario"):
        return True
    obj = update.message or (update.callback_query and update.callback_query.message)
    if obj:
        await obj.reply_text("❌ Sesión no válida. Usa /admin para iniciar.")
    return False

# ── Helpers ────────────────────────────────────────────────────────────────────
def teclado_menu() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📝 Pedidos Pendientes", callback_data="menu_pedidos"),
         InlineKeyboardButton("📦 Producción",         callback_data="menu_produccion")],
        [InlineKeyboardButton("🚚 Despachos",           callback_data="menu_despachos"),
         InlineKeyboardButton("💰 Deudas",              callback_data="menu_deudas")],
        [InlineKeyboardButton("👥 Clientes",            callback_data="menu_clientes")],
    ])

def _fmt_deuda(r: dict) -> str:
    ult = r["ultimo_pedido"].strftime("%d/%m/%Y") if r.get("ultimo_pedido") else "—"
    return (
        f"🏪 *{r['nombre_negocio']}*\n"
        f"  💰 Deuda: *${float(r['deuda_total']):.2f}*  |  ✅ Pagado: ${float(r['total_pagado']):.2f}\n"
        f"  📅 Último pedido: {ult}\n\n"
    )

# ── Menú principal ─────────────────────────────────────────────────────────────
@solo_admin
async def start_admin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    usuario = context.user_data["usuario"]
    await update.message.reply_text(
        f"🔐 *Panel Administrativo*\n"
        f"👤 {usuario['nombre']} — {usuario['rol']}\n\n"
        f"Selecciona una opción:",
        reply_markup=teclado_menu(),
        parse_mode="Markdown"
    )
    return MENU_PRINCIPAL

async def volver_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await query.edit_message_text(
        "🔐 *Panel Administrativo*\n\n¿Qué deseas consultar?",
        reply_markup=teclado_menu(),
        parse_mode="Markdown"
    )
    return MENU_PRINCIPAL

# ── Pedidos Pendientes ─────────────────────────────────────────────────────────
async def ver_pedidos(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await _validar_sesion(update, context): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        rows = await conn.fetch("""
            SELECT p.numero_recibo, c.nombre_negocio, p.monto_total, p.fecha_pedido
            FROM pedidos p
            JOIN clientes c ON c.id_cliente = p.id_cliente
            WHERE p.estado = 'pendiente'
            ORDER BY p.fecha_pedido DESC
            LIMIT 25
        """)
    finally:
        await conn.close()

    if not rows:
        texto = "📝 *Pedidos Pendientes*\n\n✅ No hay pedidos pendientes."
    else:
        texto = f"📝 *Pedidos Pendientes* ({len(rows)})\n\n"
        for r in rows:
            fecha = r["fecha_pedido"].strftime("%d/%m %H:%M") if r["fecha_pedido"] else "—"
            texto += (
                f"• *#{r['numero_recibo']}* — {r['nombre_negocio']}\n"
                f"  💰 ${float(r['monto_total']):.2f}  📅 {fecha}\n\n"
            )

    await query.edit_message_text(
        texto,
        reply_markup=InlineKeyboardMarkup([[BTN_MENU]]),
        parse_mode="Markdown"
    )
    return VER_PEDIDOS

# ── Producción ─────────────────────────────────────────────────────────────────
async def menu_produccion(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await _validar_sesion(update, context): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    hoy    = date.today().strftime("%d/%m/%Y")
    manana = (date.today() + timedelta(days=1)).strftime("%d/%m/%Y")
    await query.edit_message_text(
        "📦 *Producción*\n\n¿Qué fecha deseas consultar?\n"
        "_(O escribe la fecha: DD/MM/YYYY)_",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton(f"📅 Hoy ({hoy})",        callback_data="prod|hoy"),
             InlineKeyboardButton(f"📅 Mañana ({manana})",  callback_data="prod|manana")],
            [BTN_MENU],
        ]),
        parse_mode="Markdown"
    )
    return SEL_FECHA_PROD

async def _mostrar_produccion(query_o_msg, context, fecha: date, via_query: bool):
    conn = await get_conn()
    try:
        panes = await conn.fetch("""
            SELECT pd.tipo_pan, pd.producto, pd.peso_g,
                   SUM(pd.total_unidades)                       AS total_unidades,
                   SUM(pd.peso_total_g)                         AS peso_total_g,
                   COALESCE(MAX(pr.paquete_cantidad), 1)        AS paquete_cantidad,
                   STRING_AGG(DISTINCT c.nombre_negocio, ', ')  AS clientes
            FROM produccion_diaria pd
            JOIN pedidos  p ON p.id_pedido  = pd.id_pedido
            JOIN clientes c ON c.id_cliente = p.id_cliente
            LEFT JOIN productos pr ON pr.nombre = pd.producto
            WHERE pd.fecha_produccion_requerida = $1
            GROUP BY pd.tipo_pan, pd.producto, pd.peso_g
            ORDER BY pd.tipo_pan, pd.peso_g, pd.producto
        """, fecha)
    finally:
        await conn.close()

    fecha_str = fecha.strftime("%d/%m/%Y")
    if not panes:
        texto = f"📦 *Producción {fecha_str}*\n\n⚠️ Sin pedidos confirmados para esa fecha."
    else:
        texto = f"📦 *PRODUCCIÓN {fecha_str}*\n"
        tipo_actual = ""
        for p in panes:
            if p["tipo_pan"] != tipo_actual:
                tipo_actual = p["tipo_pan"]
                texto += f"\n🍞 *{tipo_actual}*\n"
            peso_str = f"{p['peso_g']}g" if p.get("peso_g") else "c/u"
            kg_str   = f" ({int(p['peso_total_g'])}g)" if p.get("peso_total_g") else ""
            uds      = p["total_unidades"]
            paq_cant = p["paquete_cantidad"] or 1
            if paq_cant > 1:
                paquetes = uds // paq_cant
                cant_str = f"*{paquetes} paq* ({uds} uds)"
            else:
                cant_str = f"*{uds} uds*"
            texto += f"  • {peso_str} → {cant_str}{kg_str}\n"
            if p["clientes"]:
                texto += f"    _{p['clientes']}_\n"

    teclado = InlineKeyboardMarkup([
        [InlineKeyboardButton("📦 Ver otra fecha", callback_data="menu_produccion")],
        [BTN_MENU],
    ])

    if via_query:
        await query_o_msg.edit_message_text(texto, reply_markup=teclado, parse_mode="Markdown")
    else:
        await query_o_msg.message.reply_text(texto, reply_markup=teclado, parse_mode="Markdown")

    return VER_PRODUCCION

async def prod_rapida(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    opcion = query.data.split("|")[1]
    fecha  = date.today() if opcion == "hoy" else date.today() + timedelta(days=1)
    return await _mostrar_produccion(query, context, fecha, via_query=True)

async def prod_fecha_texto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    texto = update.message.text.strip()
    try:
        fecha = datetime.strptime(texto, "%d/%m/%Y").date()
    except ValueError:
        await update.message.reply_text(
            "❌ Formato inválido. Escribe la fecha como *DD/MM/YYYY*\n_(ej: 15/05/2025)_",
            reply_markup=InlineKeyboardMarkup([[BTN_MENU]]),
            parse_mode="Markdown"
        )
        return SEL_FECHA_PROD
    return await _mostrar_produccion(update, context, fecha, via_query=False)

# ── Despachos ──────────────────────────────────────────────────────────────────
async def ver_despachos(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await _validar_sesion(update, context): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        rows = await conn.fetch("""
            SELECT p.numero_recibo, c.nombre_negocio, p.monto_total, p.fecha_despacho_real
            FROM pedidos p
            JOIN clientes c ON c.id_cliente = p.id_cliente
            WHERE p.estado = 'confirmado'
              AND p.fecha_despacho_real IS NOT NULL
            ORDER BY p.fecha_despacho_real ASC
            LIMIT 25
        """)
    finally:
        await conn.close()

    if not rows:
        texto = "🚚 *Despachos*\n\n⚠️ No hay despachos programados."
    else:
        texto = f"🚚 *Despachos Programados* ({len(rows)})\n"
        fecha_actual = None
        for r in rows:
            fd = r["fecha_despacho_real"]
            if fd != fecha_actual:
                fecha_actual = fd
                texto += f"\n📅 *{fd.strftime('%d/%m/%Y')}*\n"
            texto += f"  • #{r['numero_recibo']} — {r['nombre_negocio']}  ${float(r['monto_total']):.2f}\n"

    await query.edit_message_text(
        texto,
        reply_markup=InlineKeyboardMarkup([[BTN_MENU]]),
        parse_mode="Markdown"
    )
    return VER_DESPACHOS

# ── Deudas ─────────────────────────────────────────────────────────────────────
async def menu_deudas(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await _validar_sesion(update, context): return ConversationHandler.END
    query = update.callback_query
    await query.answer()

    conn = await get_conn()
    try:
        resumen = await conn.fetchrow("""
            SELECT
                COUNT(*) FILTER (WHERE deuda_total > 0) AS con_deuda,
                COALESCE(SUM(deuda_total), 0)           AS total_general
            FROM vista_deuda_clientes
        """)
    finally:
        await conn.close()

    await query.edit_message_text(
        f"💰 *Deudas*\n\n"
        f"🔴 Clientes con deuda: *{resumen['con_deuda']}*\n"
        f"💵 Total adeudado: *${float(resumen['total_general']):.2f}*\n\n"
        f"Selecciona una opción:",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("📊 Top 10 Deudores",  callback_data="deudas_top10")],
            [InlineKeyboardButton("🔍 Buscar Cliente",   callback_data="deudas_buscar")],
            [InlineKeyboardButton("📋 Todas las Deudas", callback_data="deudas_todas")],
            [BTN_MENU],
        ]),
        parse_mode="Markdown"
    )
    return MENU_DEUDAS

async def deudas_top10(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        rows = await conn.fetch("""
            SELECT * FROM vista_deuda_clientes
            WHERE deuda_total > 0
            ORDER BY deuda_total DESC
            LIMIT 10
        """)
    finally:
        await conn.close()

    if not rows:
        texto = "📊 *Top 10 Deudores*\n\n✅ Sin deudas registradas."
    else:
        texto = "📊 *Top 10 Deudores*\n\n"
        for i, r in enumerate(rows, 1):
            texto += f"{i}. {_fmt_deuda(dict(r))}"

    await query.edit_message_text(
        texto,
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("◀️ Volver a Deudas", callback_data="menu_deudas")],
            [BTN_MENU],
        ]),
        parse_mode="Markdown"
    )
    return MENU_DEUDAS

async def deudas_todas(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        rows = await conn.fetch("""
            SELECT * FROM vista_deuda_clientes
            WHERE deuda_total > 0
            ORDER BY deuda_total DESC
            LIMIT 35
        """)
        total_general = await conn.fetchval(
            "SELECT COALESCE(SUM(deuda_total), 0) FROM vista_deuda_clientes"
        )
    finally:
        await conn.close()

    if not rows:
        texto = "📋 *Todas las Deudas*\n\n✅ Sin deudas registradas."
    else:
        texto = f"📋 *Todas las Deudas* ({len(rows)})\n"
        texto += f"💵 Total: *${float(total_general):.2f}*\n\n"
        for r in rows:
            texto += _fmt_deuda(dict(r))
        if len(rows) == 35:
            texto += "_Mostrando los 35 mayores deudores._"

    if len(texto) > 4096:
        texto = texto[:4060] + "\n\n_...lista truncada por longitud._"

    await query.edit_message_text(
        texto,
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("◀️ Volver a Deudas", callback_data="menu_deudas")],
            [BTN_MENU],
        ]),
        parse_mode="Markdown"
    )
    return MENU_DEUDAS

async def deudas_buscar_inicio(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await query.edit_message_text(
        "🔍 *Buscar Cliente*\n\n"
        "¿Nombre del cliente a consultar?\n"
        "_(parte del nombre es suficiente)_",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("◀️ Volver a Deudas", callback_data="menu_deudas")],
            [BTN_MENU],
        ]),
        parse_mode="Markdown"
    )
    return BUSCAR_DEUDA_INPUT

async def deudas_buscar_texto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    nombre = update.message.text.strip()
    conn   = await get_conn()
    try:
        rows = await conn.fetch(
            "SELECT * FROM vista_deuda_clientes WHERE nombre_negocio ILIKE $1 ORDER BY deuda_total DESC",
            f"%{nombre}%"
        )
    finally:
        await conn.close()

    teclado = InlineKeyboardMarkup([
        [InlineKeyboardButton("🔍 Buscar otro",      callback_data="deudas_buscar")],
        [InlineKeyboardButton("◀️ Volver a Deudas", callback_data="menu_deudas")],
        [BTN_MENU],
    ])

    if not rows:
        await update.message.reply_text(
            f"❌ No encontré clientes con *'{nombre}'*.\nIntenta con otra palabra:",
            reply_markup=teclado,
            parse_mode="Markdown"
        )
        return BUSCAR_DEUDA_INPUT

    # Si hay un solo resultado y tiene deuda, ofrecemos ir directo al detalle/pago
    if len(rows) == 1 and float(rows[0]["deuda_total"]) > 0:
        r = dict(rows[0])
        context.user_data["pago_cliente"] = r
        return await _mostrar_detalle_deudas(update.message, context, r["id_cliente"])

    texto = f"🔍 *Resultados: '{nombre}'* ({len(rows)})\n\n"
    botones = []
    for r in rows[:10]:
        texto += _fmt_deuda(dict(r))
        if float(r["deuda_total"]) > 0:
            botones.append([InlineKeyboardButton(
                f"💳 Pagar — {r['nombre_negocio'][:25]}",
                callback_data=f"ver_deuda_cliente|{r['id_cliente']}"
            )])
    if len(rows) > 10:
        texto += f"_...y {len(rows) - 10} más._"
    botones.append([InlineKeyboardButton("🔍 Buscar otro",      callback_data="deudas_buscar")])
    botones.append([InlineKeyboardButton("◀️ Volver a Deudas", callback_data="menu_deudas")])
    botones.append([BTN_MENU])

    await update.message.reply_text(texto, reply_markup=InlineKeyboardMarkup(botones), parse_mode="Markdown")
    return BUSCAR_DEUDA_INPUT

async def ver_deuda_cliente_cb(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    id_cliente = int(query.data.split("|")[1])
    return await _mostrar_detalle_deudas(query, context, id_cliente, via_query=True)

async def _mostrar_detalle_deudas(msg_or_query, context, id_cliente: int, via_query: bool = False):
    conn = await get_conn()
    try:
        cliente = await conn.fetchrow(
            "SELECT nombre_negocio FROM clientes WHERE id_cliente = $1", id_cliente
        )
        deudas = await conn.fetch("""
            SELECT d.id_deuda, p.numero_recibo, d.monto_original,
                   d.monto_pagado, d.saldo_pendiente, d.estado,
                   COALESCE(d.descripcion, 'Recibo #' || p.numero_recibo, 'Deuda manual') AS concepto
            FROM deudas d
            LEFT JOIN pedidos p ON p.id_pedido = d.id_pedido
            WHERE d.id_cliente = $1 AND d.estado IN ('pendiente', 'parcial')
            ORDER BY d.fecha_creacion DESC
        """, id_cliente)
    finally:
        await conn.close()

    nombre = cliente["nombre_negocio"] if cliente else "—"
    context.user_data["pago_id_cliente"] = id_cliente
    context.user_data["pago_nombre_cliente"] = nombre

    if not deudas:
        texto = f"✅ *{nombre}*\n\nNo tiene deudas pendientes."
        botones = [[InlineKeyboardButton("◀️ Volver a Deudas", callback_data="menu_deudas")], [BTN_MENU]]
        if via_query:
            await msg_or_query.edit_message_text(texto, reply_markup=InlineKeyboardMarkup(botones), parse_mode="Markdown")
        else:
            await msg_or_query.reply_text(texto, reply_markup=InlineKeyboardMarkup(botones), parse_mode="Markdown")
        return MENU_DEUDAS

    texto = f"💰 *Deudas de {nombre}*\n\nSelecciona una deuda para registrar pago:\n\n"
    botones = []
    for d in deudas:
        estado_icono = "🟡" if d["estado"] == "parcial" else "🔴"
        concepto = d["concepto"] or "—"
        texto += (
            f"{estado_icono} *{concepto}*\n"
            f"  Total: ${float(d['monto_original']):.2f}  |  Pagado: ${float(d['monto_pagado']):.2f}\n"
            f"  *Saldo: ${float(d['saldo_pendiente']):.2f}*\n\n"
        )
        label_btn = concepto[:25]
        concepto_cb = concepto[:20].replace("|", "-")
        botones.append([InlineKeyboardButton(
            f"💳 Pagar {label_btn} (${float(d['saldo_pendiente']):.2f})",
            callback_data=f"pagar_deuda|{d['id_deuda']}|{concepto_cb}|{float(d['saldo_pendiente']):.2f}"
        )])

    botones.append([InlineKeyboardButton("◀️ Volver a Deudas", callback_data="menu_deudas")])
    botones.append([BTN_MENU])

    if via_query:
        await msg_or_query.edit_message_text(texto, reply_markup=InlineKeyboardMarkup(botones), parse_mode="Markdown")
    else:
        await msg_or_query.reply_text(texto, reply_markup=InlineKeyboardMarkup(botones), parse_mode="Markdown")
    return VER_DETALLE_DEUDA

async def seleccionar_deuda_pago(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await _validar_sesion(update, context): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    _, id_deuda, recibo, saldo = query.data.split("|")
    context.user_data["pago_id_deuda"]  = int(id_deuda)
    context.user_data["pago_recibo"]    = recibo
    context.user_data["pago_saldo"]     = float(saldo)

    await query.edit_message_text(
        f"💳 *Registrar Pago*\n\n"
        f"Recibo: *#{recibo}*\n"
        f"Saldo pendiente: *${float(saldo):.2f}*\n\n"
        f"¿Cuánto pagó el cliente?\n"
        f"_(Escribe el monto en dólares — ej: 45.50)_\n\n"
        f"_(o /cancelar para salir)_",
        reply_markup=InlineKeyboardMarkup([[BTN_MENU]]),
        parse_mode="Markdown"
    )
    return INGRESAR_MONTO_PAGO

async def ingresar_monto_pago(update: Update, context: ContextTypes.DEFAULT_TYPE):
    texto = update.message.text.strip().replace(",", ".")
    try:
        monto = float(texto)
        if monto <= 0:
            raise ValueError
    except ValueError:
        await update.message.reply_text(
            "❌ Monto inválido. Escribe solo el número:\n_(ej: 45.50 o 100)_",
            parse_mode="Markdown"
        )
        return INGRESAR_MONTO_PAGO

    saldo = context.user_data["pago_saldo"]
    if monto > saldo + 0.01:
        await update.message.reply_text(
            f"❌ El monto ${monto:.2f} supera el saldo pendiente ${saldo:.2f}.\nIngresa un monto válido:",
            parse_mode="Markdown"
        )
        return INGRESAR_MONTO_PAGO

    context.user_data["pago_monto"] = monto

    await update.message.reply_text(
        f"💳 *Método de pago*\n\n"
        f"Recibo: *#{context.user_data['pago_recibo']}*\n"
        f"Monto: *${monto:.2f}*\n\n"
        f"¿Cómo pagó el cliente?",
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("💵 Efectivo",        callback_data="metodo_pago|efectivo")],
            [InlineKeyboardButton("🏦 Transferencia",   callback_data="metodo_pago|transferencia")],
            [InlineKeyboardButton("📦 Otro",            callback_data="metodo_pago|otro")],
            [BTN_MENU],
        ]),
        parse_mode="Markdown"
    )
    return SEL_METODO_PAGO

async def confirmar_metodo_pago(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await _validar_sesion(update, context): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    metodo = query.data.split("|")[1]

    id_deuda = context.user_data["pago_id_deuda"]
    monto    = context.user_data["pago_monto"]
    recibo   = context.user_data["pago_recibo"]
    nombre   = context.user_data.get("pago_nombre_cliente", "—")
    usuario  = context.user_data.get("usuario", {})
    registrado_por = usuario.get("nombre", "admin_bot")

    conn = await get_conn()
    try:
        deuda = await conn.fetchrow(
            "SELECT id_cliente, saldo_pendiente, estado FROM deudas WHERE id_deuda = $1", id_deuda
        )
        if not deuda or deuda["estado"] == "pagado":
            await query.edit_message_text(
                "⚠️ Esta deuda ya está pagada o no existe.",
                reply_markup=InlineKeyboardMarkup([[BTN_MENU]]),
                parse_mode="Markdown"
            )
            return MENU_DEUDAS

        async with conn.transaction():
            await conn.execute("""
                INSERT INTO pagos (id_deuda, id_cliente, monto_pagado, metodo, registrado_por)
                VALUES ($1, $2, $3, $4::metodo_pago, $5)
            """, id_deuda, deuda["id_cliente"], monto, metodo, registrado_por)

        nuevo_saldo = await conn.fetchrow(
            "SELECT saldo_pendiente, estado FROM deudas WHERE id_deuda = $1", id_deuda
        )
        METODO_LABEL = {"efectivo": "💵 Efectivo", "transferencia": "🏦 Transferencia", "otro": "📦 Otro"}

        await query.edit_message_text(
            f"✅ *Pago registrado*\n\n"
            f"🏪 Cliente: *{nombre}*\n"
            f"📄 Recibo: *#{recibo}*\n"
            f"💰 Monto pagado: *${monto:.2f}*\n"
            f"🏧 Método: {METODO_LABEL.get(metodo, metodo)}\n\n"
            f"Saldo restante: *${float(nuevo_saldo['saldo_pendiente']):.2f}*\n"
            f"Estado deuda: *{nuevo_saldo['estado']}*",
            reply_markup=InlineKeyboardMarkup([
                [InlineKeyboardButton("💰 Ver Deudas",    callback_data="menu_deudas")],
                [BTN_MENU],
            ]),
            parse_mode="Markdown"
        )
    finally:
        await conn.close()

    return MENU_DEUDAS

# ── Clientes ───────────────────────────────────────────────────────────────────
async def ver_clientes(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await _validar_sesion(update, context): return ConversationHandler.END
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        clientes = await conn.fetch("""
            SELECT nombre_negocio, categoria, telegram_id
            FROM clientes
            WHERE estado = 'activo'
            ORDER BY nombre_negocio
            LIMIT 50
        """)
        total = await conn.fetchval("SELECT COUNT(*) FROM clientes WHERE estado = 'activo'")
    finally:
        await conn.close()

    CAT_ICONO = {"restaurante": "🍔", "cafeteria": "☕", "market": "🛒", "otro": "📦"}
    texto = f"👥 *Clientes Activos* ({total})\n\n"
    for c in clientes:
        icono = CAT_ICONO.get(c["categoria"], "📦")
        tg    = f" _({c['telegram_id']})_" if c.get("telegram_id") else ""
        texto += f"{icono} {c['nombre_negocio']}{tg}\n"
    if total > 50:
        texto += f"\n_Mostrando 50 de {total}._"

    await query.edit_message_text(
        texto,
        reply_markup=InlineKeyboardMarkup([[BTN_MENU]]),
        parse_mode="Markdown"
    )
    return VER_CLIENTES

# ── Cancelar ───────────────────────────────────────────────────────────────────
async def cancelar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "❌ Acción cancelada. Usa /admin para abrir el menú.",
        parse_mode="Markdown"
    )
    return ConversationHandler.END

# ── Construcción de la App ─────────────────────────────────────────────────────
def build_app() -> Application:
    app  = Application.builder().token(ADMIN_TOKEN).build()
    conv = ConversationHandler(
        entry_points=[CommandHandler("admin", start_admin)],
        states={
            MENU_PRINCIPAL: [
                CallbackQueryHandler(ver_pedidos,     pattern="^menu_pedidos$"),
                CallbackQueryHandler(menu_produccion, pattern="^menu_produccion$"),
                CallbackQueryHandler(ver_despachos,   pattern="^menu_despachos$"),
                CallbackQueryHandler(menu_deudas,     pattern="^menu_deudas$"),
                CallbackQueryHandler(ver_clientes,    pattern="^menu_clientes$"),
            ],
            VER_PEDIDOS: [
                CallbackQueryHandler(volver_menu, pattern="^volver_menu$"),
            ],
            SEL_FECHA_PROD: [
                CallbackQueryHandler(prod_rapida,    pattern="^prod\\|"),
                CallbackQueryHandler(volver_menu,    pattern="^volver_menu$"),
                MessageHandler(filters.TEXT & ~filters.COMMAND, prod_fecha_texto),
            ],
            VER_PRODUCCION: [
                CallbackQueryHandler(menu_produccion, pattern="^menu_produccion$"),
                CallbackQueryHandler(volver_menu,     pattern="^volver_menu$"),
            ],
            VER_DESPACHOS: [
                CallbackQueryHandler(volver_menu, pattern="^volver_menu$"),
            ],
            MENU_DEUDAS: [
                CallbackQueryHandler(deudas_top10,         pattern="^deudas_top10$"),
                CallbackQueryHandler(deudas_todas,         pattern="^deudas_todas$"),
                CallbackQueryHandler(deudas_buscar_inicio, pattern="^deudas_buscar$"),
                CallbackQueryHandler(menu_deudas,          pattern="^menu_deudas$"),
                CallbackQueryHandler(volver_menu,          pattern="^volver_menu$"),
            ],
            BUSCAR_DEUDA_INPUT: [
                CallbackQueryHandler(ver_deuda_cliente_cb, pattern="^ver_deuda_cliente\\|"),
                CallbackQueryHandler(deudas_buscar_inicio, pattern="^deudas_buscar$"),
                CallbackQueryHandler(menu_deudas,          pattern="^menu_deudas$"),
                CallbackQueryHandler(volver_menu,          pattern="^volver_menu$"),
                MessageHandler(filters.TEXT & ~filters.COMMAND, deudas_buscar_texto),
            ],
            VER_DETALLE_DEUDA: [
                CallbackQueryHandler(seleccionar_deuda_pago, pattern="^pagar_deuda\\|"),
                CallbackQueryHandler(deudas_buscar_inicio,   pattern="^deudas_buscar$"),
                CallbackQueryHandler(menu_deudas,            pattern="^menu_deudas$"),
                CallbackQueryHandler(volver_menu,            pattern="^volver_menu$"),
            ],
            INGRESAR_MONTO_PAGO: [
                CallbackQueryHandler(volver_menu, pattern="^volver_menu$"),
                MessageHandler(filters.TEXT & ~filters.COMMAND, ingresar_monto_pago),
            ],
            SEL_METODO_PAGO: [
                CallbackQueryHandler(confirmar_metodo_pago, pattern="^metodo_pago\\|"),
                CallbackQueryHandler(volver_menu,           pattern="^volver_menu$"),
            ],
            VER_CLIENTES: [
                CallbackQueryHandler(volver_menu, pattern="^volver_menu$"),
            ],
        },
        fallbacks=[
            CommandHandler("cancelar", cancelar),
            CommandHandler("admin",    start_admin),
            CallbackQueryHandler(volver_menu,            pattern="^volver_menu$"),
            CallbackQueryHandler(menu_deudas,            pattern="^menu_deudas$"),
            CallbackQueryHandler(deudas_buscar_inicio,   pattern="^deudas_buscar$"),
            CallbackQueryHandler(seleccionar_deuda_pago, pattern="^pagar_deuda\\|"),
            CallbackQueryHandler(confirmar_metodo_pago,  pattern="^metodo_pago\\|"),
        ],
    )
    app.add_handler(conv)
    return app

def main():
    logger.info("✅ Bot Admin iniciado.")
    build_app().run_polling()

if __name__ == "__main__":
    main()
