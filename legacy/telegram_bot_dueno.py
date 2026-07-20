"""
BOT TELEGRAM - MODULO ADMIN (Dueno y Empleados)
Sistema Panificadora
Modelo IA: Claude Sonnet (logica compleja de negocio)
Funcion: Gestion interna - clientes, deudas, pagos, produccion, reportes
ACCESO: Solo usuarios registrados en tabla 'usuarios' con estado activo
"""

import os
import logging
from datetime import date
from functools import wraps
import asyncpg
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, filters, ContextTypes, ConversationHandler
)

# ============================================================
# CONFIGURACION
# ============================================================
ADMIN_TOKEN   = os.getenv("ADMIN_TELEGRAM_TOKEN")
MODEL_SMART   = "claude-sonnet-4-6"

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "panificadora"),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Estados
(MENU_PRINCIPAL,
 GESTION_CLIENTES, AGREGAR_NOMBRE, AGREGAR_TG, AGREGAR_TEL, AGREGAR_CAT,
 BUSCAR_DEUDA, VER_DEUDA_CLIENTE,
 BUSCAR_PAGO, VER_CLIENTE_PAGO, MONTO_PAGO, METODO_PAGO,
 AGREGAR_EMPLEADO_NOMBRE, AGREGAR_EMPLEADO_TG) = range(14)

# ============================================================
# BASE DE DATOS
# ============================================================
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

# ============================================================
# DECORADOR DE AUTENTICACION
# ============================================================
def solo_admin(func):
    @wraps(func)
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        obj   = update.message or update.callback_query.message
        user  = update.effective_user
        tg_id = f"@{user.username}" if user.username else str(user.id)
        usuario = await get_usuario(tg_id)
        if not usuario:
            await obj.reply_text("❌ Acceso no autorizado.\nContacta al administrador del sistema.")
            return ConversationHandler.END
        context.user_data["usuario"] = dict(usuario)
        return await func(update, context)
    return wrapper

# ============================================================
# MENU PRINCIPAL
# ============================================================
@solo_admin
async def start_admin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    usuario  = context.user_data["usuario"]
    es_dueno = usuario["rol"] == "DUENO"

    teclado = [
        [InlineKeyboardButton("👥 Clientes",         callback_data="m_clientes"),
         InlineKeyboardButton("📊 Deudas",           callback_data="m_deudas")],
        [InlineKeyboardButton("💰 Registrar Pago",   callback_data="m_pagos"),
         InlineKeyboardButton("📦 Producción Hoy",   callback_data="m_produccion")],
        [InlineKeyboardButton("📈 Reportes",         callback_data="m_reportes")],
    ]
    if es_dueno:
        teclado.append([InlineKeyboardButton("⚙️ Empleados", callback_data="m_empleados")])

    await update.message.reply_text(
        f"🔐 *Panel Administrativo*\n"
        f"👤 {usuario['nombre']} — {usuario['rol']}\n\n"
        f"Selecciona una opción:",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return MENU_PRINCIPAL

async def volver_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    usuario  = context.user_data.get("usuario", {})
    es_dueno = usuario.get("rol") == "DUENO"

    teclado = [
        [InlineKeyboardButton("👥 Clientes",         callback_data="m_clientes"),
         InlineKeyboardButton("📊 Deudas",           callback_data="m_deudas")],
        [InlineKeyboardButton("💰 Registrar Pago",   callback_data="m_pagos"),
         InlineKeyboardButton("📦 Producción Hoy",   callback_data="m_produccion")],
        [InlineKeyboardButton("📈 Reportes",         callback_data="m_reportes")],
    ]
    if es_dueno:
        teclado.append([InlineKeyboardButton("⚙️ Empleados", callback_data="m_empleados")])

    await query.edit_message_text(
        f"🔐 *Panel Administrativo*\n\n¿Qué deseas hacer?",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return MENU_PRINCIPAL

# ============================================================
# GESTION DE CLIENTES
# ============================================================
async def menu_clientes(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    teclado = [
        [InlineKeyboardButton("➕ Agregar Cliente",  callback_data="c_agregar")],
        [InlineKeyboardButton("📋 Listar Activos",   callback_data="c_listar")],
        [InlineKeyboardButton("🔍 Buscar Cliente",   callback_data="c_buscar")],
        [InlineKeyboardButton("🔙 Volver",           callback_data="volver_menu")],
    ]
    await query.edit_message_text("👥 *Gestión de Clientes*", reply_markup=InlineKeyboardMarkup(teclado), parse_mode="Markdown")
    return GESTION_CLIENTES

async def listar_clientes(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        clientes = await conn.fetch(
            "SELECT nombre_negocio, estado, categoria FROM clientes ORDER BY nombre_negocio LIMIT 30"
        )
    finally:
        await conn.close()

    texto = "📋 *CLIENTES (primeros 30):*\n\n"
    for c in clientes:
        icono = "✅" if c["estado"] == "activo" else "❌"
        texto += f"{icono} {c['nombre_negocio']} ({c['categoria']})\n"

    teclado = [[InlineKeyboardButton("🔙 Volver", callback_data="m_clientes")]]
    await query.edit_message_text(texto, reply_markup=InlineKeyboardMarkup(teclado), parse_mode="Markdown")
    return GESTION_CLIENTES

async def iniciar_agregar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    context.user_data["nuevo_cliente"] = {}
    await query.edit_message_text("➕ *Nuevo Cliente*\n\n¿Cuál es el *nombre del negocio*?", parse_mode="Markdown")
    return AGREGAR_NOMBRE

async def agregar_nombre(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["nuevo_cliente"]["nombre_negocio"] = update.message.text.upper().strip()
    await update.message.reply_text(
        f"✅ Nombre: *{context.user_data['nuevo_cliente']['nombre_negocio']}*\n\n"
        "¿Usuario de Telegram? (ej: @burger_grill)\n_(Escribe 'no' si no tiene)_",
        parse_mode="Markdown"
    )
    return AGREGAR_TG

async def agregar_tg(update: Update, context: ContextTypes.DEFAULT_TYPE):
    tg = update.message.text.strip()
    context.user_data["nuevo_cliente"]["telegram_id"] = None if tg.lower() == "no" else tg
    await update.message.reply_text("📞 ¿Teléfono de contacto?\n_(Escribe 'no' si no aplica)_")
    return AGREGAR_TEL

async def agregar_tel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    tel = update.message.text.strip()
    context.user_data["nuevo_cliente"]["telefono"] = None if tel.lower() == "no" else tel
    teclado = [
        [InlineKeyboardButton("🍔 Restaurante", callback_data="cat|restaurante"),
         InlineKeyboardButton("☕ Cafetería",   callback_data="cat|cafeteria")],
        [InlineKeyboardButton("🛒 Market",      callback_data="cat|market"),
         InlineKeyboardButton("📦 Otro",        callback_data="cat|otro")]
    ]
    await update.message.reply_text("🏪 ¿Categoría del negocio?", reply_markup=InlineKeyboardMarkup(teclado))
    return AGREGAR_CAT

async def agregar_categoria(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    categoria = query.data.split("|")[1]
    nc = context.user_data["nuevo_cliente"]
    nc["categoria"] = categoria

    conn = await get_conn()
    try:
        await conn.execute("""
            INSERT INTO clientes (telegram_id, nombre_negocio, telefono, categoria)
            VALUES ($1, $2, $3, $4)
        """, nc.get("telegram_id"), nc["nombre_negocio"], nc.get("telefono"), categoria)
    finally:
        await conn.close()

    teclado = [[InlineKeyboardButton("🔙 Menú Clientes", callback_data="m_clientes")]]
    await query.edit_message_text(
        f"✅ *Cliente agregado:*\n\n"
        f"🏪 {nc['nombre_negocio']}\n"
        f"📱 {nc.get('telegram_id', 'Sin Telegram')}\n"
        f"📞 {nc.get('telefono', 'Sin teléfono')}\n"
        f"🏷️ {categoria.capitalize()}",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return GESTION_CLIENTES

# ============================================================
# GESTION DE DEUDAS (Solo interno)
# ============================================================
async def menu_deudas(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        resumen = await conn.fetchrow("""
            SELECT
                COUNT(*) FILTER (WHERE deuda_total > 0)  AS con_deuda,
                COALESCE(SUM(deuda_total), 0)            AS total_general,
                COUNT(*) FILTER (WHERE deuda_total = 0)  AS al_dia
            FROM vista_deuda_clientes
        """)
        top = await conn.fetch("SELECT nombre_negocio, deuda_total FROM vista_top_deudores LIMIT 5")
    finally:
        await conn.close()

    texto = (
        f"📊 *RESUMEN DE DEUDAS*\n\n"
        f"🔴 Con deuda: {resumen['con_deuda']} clientes\n"
        f"💰 Total general: *${resumen['total_general']:.2f}*\n"
        f"✅ Al día: {resumen['al_dia']} clientes\n\n"
        f"*TOP 5 DEUDORES:*\n"
    )
    for d in top:
        texto += f"• {d['nombre_negocio']}: *${d['deuda_total']:.2f}*\n"

    teclado = [
        [InlineKeyboardButton("🔍 Ver deuda de cliente", callback_data="d_buscar")],
        [InlineKeyboardButton("🔙 Volver",              callback_data="volver_menu")]
    ]
    await query.edit_message_text(texto, reply_markup=InlineKeyboardMarkup(teclado), parse_mode="Markdown")
    return MENU_PRINCIPAL

async def buscar_deuda_inicio(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await query.edit_message_text("🔍 ¿Nombre del cliente a consultar?")
    return BUSCAR_DEUDA

async def buscar_deuda_cliente(update: Update, context: ContextTypes.DEFAULT_TYPE):
    nombre = update.message.text.strip()
    conn = await get_conn()
    try:
        clientes = await conn.fetch(
            "SELECT * FROM vista_deuda_clientes WHERE nombre_negocio ILIKE $1",
            f"%{nombre}%"
        )
    finally:
        await conn.close()

    if not clientes:
        await update.message.reply_text("❌ Cliente no encontrado. Intenta de nuevo:")
        return BUSCAR_DEUDA

    if len(clientes) == 1:
        c = dict(clientes[0])
        fecha_ult = c["ultimo_pedido"].strftime("%d/%m/%Y") if c["ultimo_pedido"] else "N/A"
        await update.message.reply_text(
            f"👤 *{c['nombre_negocio']}*\n\n"
            f"💰 Deuda total: *${c['deuda_total']:.2f}*\n"
            f"📦 Pedidos pendientes: {c['pedidos_pendientes']}\n"
            f"📅 Último pedido: {fecha_ult}",
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙 Volver", callback_data="volver_menu")]])
        )
        return MENU_PRINCIPAL

    teclado = [[InlineKeyboardButton(c["nombre_negocio"], callback_data=f"ver_deuda|{c['id_cliente']}")]
               for c in clientes[:8]]
    await update.message.reply_text("Selecciona el cliente:", reply_markup=InlineKeyboardMarkup(teclado))
    return VER_DEUDA_CLIENTE

# ============================================================
# REGISTRAR PAGO
# ============================================================
async def menu_pagos(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await query.edit_message_text("💰 *Registrar Pago*\n\n¿Nombre del cliente?", parse_mode="Markdown")
    return BUSCAR_PAGO

async def buscar_cliente_pago(update: Update, context: ContextTypes.DEFAULT_TYPE):
    nombre = update.message.text.strip()
    conn = await get_conn()
    try:
        clientes = await conn.fetch(
            "SELECT * FROM vista_deuda_clientes WHERE nombre_negocio ILIKE $1 AND deuda_total > 0",
            f"%{nombre}%"
        )
    finally:
        await conn.close()

    if not clientes:
        await update.message.reply_text("❌ Cliente no encontrado o sin deuda. Intenta de nuevo:")
        return BUSCAR_PAGO

    if len(clientes) == 1:
        context.user_data["cliente_pago"] = dict(clientes[0])
        return await mostrar_deuda_para_pago(update, context)

    teclado = [[InlineKeyboardButton(f"{c['nombre_negocio']} (${c['deuda_total']:.2f})",
                callback_data=f"sel_pago|{c['id_cliente']}")]
               for c in clientes[:8]]
    await update.message.reply_text("Selecciona el cliente:", reply_markup=InlineKeyboardMarkup(teclado))
    return VER_CLIENTE_PAGO

async def mostrar_deuda_para_pago(update: Update, context: ContextTypes.DEFAULT_TYPE):
    c    = context.user_data["cliente_pago"]
    msg  = update.message or update.callback_query.message
    fecha = c["ultimo_pedido"].strftime("%d/%m/%Y") if c["ultimo_pedido"] else "N/A"
    await msg.reply_text(
        f"👤 *{c['nombre_negocio']}*\n\n"
        f"💰 Deuda total: *${c['deuda_total']:.2f}*\n"
        f"📦 Pedidos pendientes: {c['pedidos_pendientes']}\n"
        f"📅 Último pedido: {fecha}\n\n"
        f"¿Cuánto paga el cliente? (ingresa el monto)",
        parse_mode="Markdown"
    )
    return MONTO_PAGO

async def ingresar_monto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        monto = float(update.message.text.strip().replace(",", "."))
        if monto <= 0:
            raise ValueError
    except ValueError:
        await update.message.reply_text("❌ Ingresa un monto válido mayor a 0:")
        return MONTO_PAGO

    context.user_data["monto_pago"] = monto
    teclado = [
        [InlineKeyboardButton("💵 Efectivo",      callback_data="pago|efectivo"),
         InlineKeyboardButton("🏦 Transferencia", callback_data="pago|transferencia")],
        [InlineKeyboardButton("📋 Otro",          callback_data="pago|otro")]
    ]
    await update.message.reply_text(
        f"💰 Monto: *${monto:.2f}*\n\n¿Método de pago?",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return METODO_PAGO

async def confirmar_pago(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query   = update.callback_query
    await query.answer()
    metodo  = query.data.split("|")[1]
    monto   = context.user_data["monto_pago"]
    cliente = context.user_data["cliente_pago"]
    usuario = context.user_data["usuario"]

    conn = await get_conn()
    try:
        deuda = await conn.fetchrow(
            "SELECT id_deuda FROM deudas WHERE id_cliente = $1 AND estado != 'pagado' ORDER BY fecha_creacion LIMIT 1",
            cliente["id_cliente"]
        )
        if not deuda:
            await query.edit_message_text("❌ No se encontró deuda activa para este cliente.")
            return MENU_PRINCIPAL

        await conn.execute("""
            INSERT INTO pagos (id_deuda, id_cliente, monto_pagado, metodo, registrado_por)
            VALUES ($1, $2, $3, $4, $5)
        """, deuda["id_deuda"], cliente["id_cliente"], monto, metodo, usuario["nombre"])

        nueva_deuda = await conn.fetchval(
            "SELECT COALESCE(SUM(saldo_pendiente), 0) FROM deudas WHERE id_cliente = $1 AND estado != 'pagado'",
            cliente["id_cliente"]
        )
    finally:
        await conn.close()

    teclado = [[InlineKeyboardButton("🔙 Menú Principal", callback_data="volver_menu")]]
    await query.edit_message_text(
        f"✅ *Pago Registrado*\n\n"
        f"👤 {cliente['nombre_negocio']}\n"
        f"💰 Abono: *${monto:.2f}*\n"
        f"🏦 Método: {metodo.capitalize()}\n"
        f"📊 Saldo pendiente: *${nueva_deuda:.2f}*\n"
        f"👤 Registrado por: {usuario['nombre']}",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return MENU_PRINCIPAL

# ============================================================
# PRODUCCION DEL DIA
# ============================================================
async def produccion_hoy(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        items = await conn.fetch("SELECT * FROM vista_produccion_manana ORDER BY tipo_pan, peso_g")
    finally:
        await conn.close()

    if not items:
        texto = "📦 *Producción Mañana*\n\n⚠️ Sin pedidos confirmados aún."
    else:
        from datetime import timedelta
        manana = (date.today() + timedelta(days=1)).strftime("%d/%m/%Y")
        texto  = f"📦 *PRODUCCIÓN {manana}*\n"
        tipo_actual = ""
        for i in items:
            if i["tipo_pan"] != tipo_actual:
                tipo_actual = i["tipo_pan"]
                texto += f"\n🍞 *{tipo_actual}*\n"
            texto += f"  • {i['peso_g']}g → *{i['total_unidades']} uds* ({i['peso_total_g']:.0f}g total)\n"
            if i["clientes"]:
                texto += f"    _{i['clientes']}_\n"

    teclado = [[InlineKeyboardButton("🔙 Volver", callback_data="volver_menu")]]
    await query.edit_message_text(texto, reply_markup=InlineKeyboardMarkup(teclado), parse_mode="Markdown")
    return MENU_PRINCIPAL

# ============================================================
# REPORTES
# ============================================================
async def menu_reportes(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    conn = await get_conn()
    try:
        hoy = await conn.fetchrow("""
            SELECT COUNT(*) AS pedidos, COALESCE(SUM(monto_total), 0) AS ventas
            FROM pedidos WHERE DATE(fecha_pedido) = CURRENT_DATE AND estado != 'cancelado'
        """)
        mes = await conn.fetchrow("""
            SELECT COUNT(*) AS pedidos, COALESCE(SUM(monto_total), 0) AS ventas
            FROM pedidos
            WHERE DATE_TRUNC('month', fecha_pedido) = DATE_TRUNC('month', CURRENT_DATE)
            AND estado != 'cancelado'
        """)
        top_clientes = await conn.fetch("""
            SELECT nombre_negocio, deuda_total FROM vista_top_deudores LIMIT 3
        """)
    finally:
        await conn.close()

    texto = (
        f"📈 *REPORTES*\n\n"
        f"📅 *HOY:*\n"
        f"  • Pedidos: {hoy['pedidos']}\n"
        f"  • Ventas: *${hoy['ventas']:.2f}*\n\n"
        f"📆 *ESTE MES:*\n"
        f"  • Pedidos: {mes['pedidos']}\n"
        f"  • Ventas: *${mes['ventas']:.2f}*\n\n"
        f"🔴 *TOP DEUDORES:*\n"
    )
    for c in top_clientes:
        texto += f"  • {c['nombre_negocio']}: ${c['deuda_total']:.2f}\n"

    teclado = [[InlineKeyboardButton("🔙 Volver", callback_data="volver_menu")]]
    await query.edit_message_text(texto, reply_markup=InlineKeyboardMarkup(teclado), parse_mode="Markdown")
    return MENU_PRINCIPAL

# ============================================================
# GESTION DE EMPLEADOS (Solo Dueno)
# ============================================================
async def menu_empleados(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    usuario = context.user_data.get("usuario", {})
    if usuario.get("rol") != "DUENO":
        await query.edit_message_text("❌ Solo el dueño puede gestionar empleados.")
        return MENU_PRINCIPAL

    conn = await get_conn()
    try:
        empleados = await conn.fetch(
            "SELECT nombre, telegram_id, rol, estado FROM usuarios ORDER BY rol, nombre"
        )
    finally:
        await conn.close()

    texto = "⚙️ *GESTIÓN DE EMPLEADOS*\n\n"
    for e in empleados:
        icono = "👑" if e["rol"] == "DUENO" else "👤"
        estado = "✅" if e["estado"] == "activo" else "❌"
        texto += f"{icono} {estado} {e['nombre']} ({e['telegram_id']})\n"

    teclado = [
        [InlineKeyboardButton("➕ Agregar Empleado", callback_data="emp_agregar")],
        [InlineKeyboardButton("🔙 Volver",           callback_data="volver_menu")]
    ]
    await query.edit_message_text(texto, reply_markup=InlineKeyboardMarkup(teclado), parse_mode="Markdown")
    return MENU_PRINCIPAL

async def iniciar_agregar_empleado(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await query.edit_message_text("⚙️ *Nuevo Empleado*\n\n¿Cuál es el nombre del empleado?", parse_mode="Markdown")
    return AGREGAR_EMPLEADO_NOMBRE

async def agregar_empleado_nombre(update: Update, context: ContextTypes.DEFAULT_TYPE):
    context.user_data["nuevo_empleado"] = {"nombre": update.message.text.strip()}
    await update.message.reply_text("¿Usuario de Telegram del empleado? (ej: @juan_empleado)")
    return AGREGAR_EMPLEADO_TG

async def agregar_empleado_tg(update: Update, context: ContextTypes.DEFAULT_TYPE):
    tg_id = update.message.text.strip()
    nombre = context.user_data["nuevo_empleado"]["nombre"]
    conn = await get_conn()
    try:
        await conn.execute("""
            INSERT INTO usuarios (telegram_id, nombre, rol)
            VALUES ($1, $2, 'EMPLEADO')
            ON CONFLICT (telegram_id) DO UPDATE SET nombre = $2, estado = 'activo'
        """, tg_id, nombre)
    finally:
        await conn.close()

    teclado = [[InlineKeyboardButton("🔙 Volver", callback_data="volver_menu")]]
    await update.message.reply_text(
        f"✅ *Empleado agregado:*\n👤 {nombre}\n📱 {tg_id}",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return MENU_PRINCIPAL

# ============================================================
# MAIN
# ============================================================
def main():
    app = Application.builder().token(ADMIN_TOKEN).build()

    conv = ConversationHandler(
        entry_points=[CommandHandler("admin", start_admin)],
        states={
            MENU_PRINCIPAL: [
                CallbackQueryHandler(menu_clientes,   pattern="^m_clientes$"),
                CallbackQueryHandler(menu_deudas,     pattern="^m_deudas$"),
                CallbackQueryHandler(menu_pagos,      pattern="^m_pagos$"),
                CallbackQueryHandler(produccion_hoy,  pattern="^m_produccion$"),
                CallbackQueryHandler(menu_reportes,   pattern="^m_reportes$"),
                CallbackQueryHandler(menu_empleados,  pattern="^m_empleados$"),
                CallbackQueryHandler(buscar_deuda_inicio, pattern="^d_buscar$"),
            ],
            GESTION_CLIENTES: [
                CallbackQueryHandler(listar_clientes, pattern="^c_listar$"),
                CallbackQueryHandler(iniciar_agregar, pattern="^c_agregar$"),
                CallbackQueryHandler(volver_menu,     pattern="^volver_menu$"),
            ],
            AGREGAR_NOMBRE:  [MessageHandler(filters.TEXT & ~filters.COMMAND, agregar_nombre)],
            AGREGAR_TG:      [MessageHandler(filters.TEXT & ~filters.COMMAND, agregar_tg)],
            AGREGAR_TEL:     [MessageHandler(filters.TEXT & ~filters.COMMAND, agregar_tel)],
            AGREGAR_CAT:     [CallbackQueryHandler(agregar_categoria, pattern="^cat\\|")],
            BUSCAR_DEUDA:    [MessageHandler(filters.TEXT & ~filters.COMMAND, buscar_deuda_cliente)],
            BUSCAR_PAGO:     [MessageHandler(filters.TEXT & ~filters.COMMAND, buscar_cliente_pago)],
            VER_CLIENTE_PAGO:[CallbackQueryHandler(mostrar_deuda_para_pago, pattern="^sel_pago\\|")],
            MONTO_PAGO:      [MessageHandler(filters.TEXT & ~filters.COMMAND, ingresar_monto)],
            METODO_PAGO:     [CallbackQueryHandler(confirmar_pago, pattern="^pago\\|")],
            AGREGAR_EMPLEADO_NOMBRE: [MessageHandler(filters.TEXT & ~filters.COMMAND, agregar_empleado_nombre)],
            AGREGAR_EMPLEADO_TG:     [MessageHandler(filters.TEXT & ~filters.COMMAND, agregar_empleado_tg)],
        },
        fallbacks=[
            CommandHandler("cancelar", lambda u, c: ConversationHandler.END),
            CallbackQueryHandler(volver_menu, pattern="^volver_menu$"),
        ]
    )

    app.add_handler(conv)
    logger.info("✅ Bot Admin iniciado.")
    app.run_polling()

if __name__ == "__main__":
    main()
