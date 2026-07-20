"""
BOT TELEGRAM - MODULO CLIENTE B2B
Sistema Panificadora
Modelo IA: Claude Haiku (rapido y ligero para pedidos simples)
Funcion: Solo toma pedidos y envia recibo PDF al cliente
"""

import os
import logging
from datetime import date, timedelta
import asyncpg
import anthropic
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, filters, ContextTypes, ConversationHandler
)

# ============================================================
# CONFIGURACION
# ============================================================
TELEGRAM_TOKEN  = os.getenv("TELEGRAM_TOKEN")
DUENO_TELEGRAM_ID = os.getenv("DUENO_TELEGRAM_ID", "@luisepm92")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
MODEL_RAPIDO    = "claude-haiku-4-5-20251001"

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "panificadora"),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Estados del ConversationHandler
SELECCIONAR_TIPO, SELECCIONAR_PESO, INGRESAR_CANTIDAD, CONFIRMAR_PEDIDO = range(4)

# ============================================================
# CATALOGO DE PRODUCTOS
# ============================================================
TIPOS_PAN = [
    "BRIOCHE", "BASICA", "FRANCESA", "ESTANDAR",
    "SOBADA HB", "SOBADA PE", "ABRIOCHADA",
    "PAPA", "BATATA", "MANTEQUILLA",
    "HOJALDRES", "CROISSANTS", "CROISSANTS SEMI",
    "AFRECHO MANT. Y MIEL"
]

PESOS_POR_TIPO = {
    "BRIOCHE":              [70, 90, 100, 110],
    "BASICA":               [45, 55, 75, 85, 95, 105, 115, 155],
    "FRANCESA":             [50, 100, 200],
    "ESTANDAR":             [55, 75, 100],
    "SOBADA HB":            [55, 75, 100],
    "SOBADA PE":            [55, 75, 100],
    "ABRIOCHADA":           [55, 75, 100],
    "PAPA":                 [55, 75, 100, 640],
    "BATATA":               [55, 75, 100, 640],
    "MANTEQUILLA":          [55, 75, 100],
    "HOJALDRES":            [50, 100],
    "CROISSANTS":           [60, 100],
    "CROISSANTS SEMI":      [60, 100],
    "AFRECHO MANT. Y MIEL": [55, 75, 100],
}

PRECIOS = {
    "BRIOCHE":   {70: 1.2, 90: 1.5, 100: 1.8, 110: 2.0},
    "BASICA":    {45: 1.5, 55: 1.7, 75: 1.7, 85: 1.8, 95: 1.8, 105: 2.0, 115: 2.3, 155: 3.0},
    "PAPA":      {55: 2.0, 75: 2.5, 100: 3.0, 640: 3.3},
    "BATATA":    {55: 2.0, 75: 2.5, 100: 3.0, 640: 3.3},
    "CROISSANTS":{60: 1.5, 100: 2.3},
}

def obtener_precio(tipo: str, peso: int) -> float:
    return PRECIOS.get(tipo, {}).get(peso, 1.5)

# ============================================================
# BASE DE DATOS
# ============================================================
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

async def guardar_pedido(cliente_id: int, items: list, nombre_cliente: str) -> tuple:
    """Guarda pedido en BD y retorna (id_pedido, numero_recibo, total)"""
    conn = await get_conn()
    try:
        total = sum(i["subtotal"] for i in items)
        fecha_entrega = date.today() + timedelta(days=1)
        num_recibo = await conn.fetchval("SELECT generar_numero_recibo()")

        async with conn.transaction():
            id_pedido = await conn.fetchval("""
                INSERT INTO pedidos
                    (id_cliente, numero_recibo, fecha_entrega, estado, monto_total, registrado_por)
                VALUES ($1, $2, $3, 'confirmado', $4, $5)
                RETURNING id_pedido
            """, cliente_id, num_recibo, fecha_entrega, total, nombre_cliente)

            for item in items:
                await conn.execute("""
                    INSERT INTO detalle_pedidos
                        (id_pedido, tipo_pan, producto, peso_g, cantidad, tipo_unidad, precio_unitario, subtotal)
                    VALUES ($1, $2, $3, $4, $5, 'unidad', $6, $7)
                """, id_pedido, item["tipo_pan"], item["producto"],
                    item["peso_g"], item["cantidad"],
                    item["precio_unitario"], item["subtotal"])

            await conn.execute("""
                INSERT INTO deudas (id_cliente, id_pedido, monto_original)
                VALUES ($1, $2, $3)
            """, cliente_id, id_pedido, total)

            await conn.execute("SELECT consolidar_produccion($1)", fecha_entrega)

        return id_pedido, num_recibo, total, fecha_entrega
    finally:
        await conn.close()

# ============================================================
# HANDLERS
# ============================================================
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    tg_id = f"@{update.effective_user.username}" if update.effective_user.username else str(update.effective_user.id)
    cliente = await get_cliente(tg_id)

    if not cliente:
        await update.message.reply_text(
            "❌ No estás registrado como cliente.\n\n"
            f"Contacta con la panificadora para activar tu acceso:\n"
            f"👤 {DUENO_TELEGRAM_ID}"
        )
        return ConversationHandler.END

    context.user_data["cliente"] = dict(cliente)
    context.user_data["items"]   = []

    teclado = [[InlineKeyboardButton("🍞 Realizar Pedido", callback_data="nuevo_pedido")]]
    await update.message.reply_text(
        f"🍞 *Bienvenido, {cliente['nombre_negocio']}*\n\n"
        f"📅 Entrega: *{(date.today() + timedelta(days=1)).strftime('%d/%m/%Y')}*",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )

async def nuevo_pedido(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    context.user_data["items"] = []

    # Construir botones de tipos de pan (2 por fila)
    teclado = []
    fila = []
    for i, tipo in enumerate(TIPOS_PAN):
        fila.append(InlineKeyboardButton(tipo, callback_data=f"tipo|{tipo}"))
        if len(fila) == 2:
            teclado.append(fila)
            fila = []
    if fila:
        teclado.append(fila)

    await query.edit_message_text(
        "🍞 *Selecciona el tipo de pan:*",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return SELECCIONAR_TIPO

async def seleccionar_tipo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    tipo = query.data.split("|")[1]
    context.user_data["tipo_actual"] = tipo

    pesos = PESOS_POR_TIPO.get(tipo, [55, 75, 100])
    teclado = [[InlineKeyboardButton(f"{p}g", callback_data=f"peso|{p}") for p in pesos]]

    await query.edit_message_text(
        f"✅ *{tipo}*\n\n⚖️ Selecciona el peso:",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return SELECCIONAR_PESO

async def seleccionar_peso(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    peso = int(query.data.split("|")[1])
    context.user_data["peso_actual"] = peso

    await query.edit_message_text(
        f"✅ *{context.user_data['tipo_actual']} {peso}g*\n\n"
        f"📦 ¿Cuántas *unidades* necesitas?\n_(Escribe solo el número)_",
        parse_mode="Markdown"
    )
    return INGRESAR_CANTIDAD

async def ingresar_cantidad(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        cantidad = int(update.message.text.strip())
        if cantidad <= 0:
            raise ValueError
    except ValueError:
        await update.message.reply_text("❌ Ingresa un número entero mayor a 0:")
        return INGRESAR_CANTIDAD

    tipo  = context.user_data["tipo_actual"]
    peso  = context.user_data["peso_actual"]
    precio = obtener_precio(tipo, peso)
    subtotal = round(precio * cantidad, 2)

    context.user_data["items"].append({
        "tipo_pan":       tipo,
        "producto":       "HAMBURGUESA",
        "peso_g":         peso,
        "cantidad":       cantidad,
        "precio_unitario": precio,
        "subtotal":       subtotal
    })

    items   = context.user_data["items"]
    resumen = "\n".join([f"• {i['tipo_pan']} {i['peso_g']}g x{i['cantidad']} = ${i['subtotal']:.2f}" for i in items])
    total   = sum(i["subtotal"] for i in items)

    teclado = [
        [InlineKeyboardButton("➕ Agregar otro", callback_data="nuevo_pedido")],
        [InlineKeyboardButton("✅ Confirmar pedido", callback_data="confirmar")],
        [InlineKeyboardButton("❌ Cancelar todo",   callback_data="cancelar")]
    ]
    await update.message.reply_text(
        f"📋 *Tu pedido:*\n\n{resumen}\n\n"
        f"💰 *TOTAL: ${total:.2f}*\n"
        f"📅 Entrega: {(date.today() + timedelta(days=1)).strftime('%d/%m/%Y')}",
        reply_markup=InlineKeyboardMarkup(teclado),
        parse_mode="Markdown"
    )
    return CONFIRMAR_PEDIDO

async def confirmar_pedido(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    if query.data == "cancelar":
        await query.edit_message_text("❌ Pedido cancelado.")
        return ConversationHandler.END

    if query.data == "nuevo_pedido":
        return await nuevo_pedido(update, context)

    # Guardar en BD
    cliente = context.user_data["cliente"]
    items   = context.user_data["items"]

    await query.edit_message_text("⏳ Procesando tu pedido...")

    try:
        id_pedido, num_recibo, total, fecha_entrega = await guardar_pedido(
            cliente["id_cliente"], items, cliente["nombre_negocio"]
        )
        await query.edit_message_text(
            f"✅ *PEDIDO CONFIRMADO*\n\n"
            f"📄 Recibo N°: *{num_recibo}*\n"
            f"📅 Entrega: *{fecha_entrega.strftime('%d/%m/%Y')}*\n"
            f"💰 Total: *${total:.2f}*\n\n"
            f"📎 Tu recibo llegará en breve. ¡Gracias! 🍞",
            parse_mode="Markdown"
        )
    except Exception as e:
        logger.error(f"Error guardando pedido: {e}")
        await query.edit_message_text("❌ Error al procesar el pedido. Contacta con la panificadora.")

    return ConversationHandler.END

async def cancelar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("❌ Operación cancelada.")
    return ConversationHandler.END

# ============================================================
# MAIN
# ============================================================
def main():
    app = Application.builder().token(TELEGRAM_TOKEN).build()

    conv = ConversationHandler(
        entry_points=[
            CommandHandler("start", start),
            CallbackQueryHandler(nuevo_pedido, pattern="^nuevo_pedido$")
        ],
        states={
            SELECCIONAR_TIPO:    [CallbackQueryHandler(seleccionar_tipo,   pattern="^tipo\\|")],
            SELECCIONAR_PESO:    [CallbackQueryHandler(seleccionar_peso,   pattern="^peso\\|")],
            INGRESAR_CANTIDAD:   [MessageHandler(filters.TEXT & ~filters.COMMAND, ingresar_cantidad)],
            CONFIRMAR_PEDIDO:    [CallbackQueryHandler(confirmar_pedido,   pattern="^(confirmar|cancelar|nuevo_pedido)$")],
        },
        fallbacks=[CommandHandler("cancelar", cancelar)]
    )

    app.add_handler(conv)
    logger.info("✅ Bot Cliente iniciado. Esperando pedidos...")
    app.run_polling()

if __name__ == "__main__":
    main()
