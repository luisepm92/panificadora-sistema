"""
GENERADOR DE RECIBOS PDF
Sistema Panificadora
Flujo: Genera PDF -> Guarda en carpeta local -> Retorna (ruta_local, pdf_bytes)
"""

import os
import io
import logging
import asyncpg
from datetime import datetime
from reportlab.lib import colors
from reportlab.lib.pagesizes import A5
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.enums import TA_CENTER
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer

logger = logging.getLogger(__name__)

# ============================================================
# CONFIGURACION
# ============================================================
RECIBOS_DIR    = os.getenv("RECIBOS_DIR", "/Users/blackrave/panificadora_sistema/Recibos")
EMPRESA_NOMBRE = os.getenv("EMPRESA_NOMBRE", "PANIFICADORA")
EMPRESA_SLOGAN = os.getenv("EMPRESA_SLOGAN", "Pan fresco cada día")

DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "panificadora"),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}

# Crear carpeta de recibos al importar el módulo
os.makedirs(RECIBOS_DIR, exist_ok=True)

# ============================================================
# GENERADOR DE PDF
# ============================================================
def generar_pdf(pedido: dict, cliente: dict, items: list) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A5,
        rightMargin=10*mm, leftMargin=10*mm,
        topMargin=10*mm,   bottomMargin=10*mm
    )

    styles = getSampleStyleSheet()
    story  = []

    st_empresa = ParagraphStyle("empresa",
        parent=styles["Title"], fontSize=18,
        textColor=colors.HexColor("#2C3E50"), alignment=TA_CENTER, spaceAfter=1)

    st_slogan = ParagraphStyle("slogan",
        parent=styles["Normal"], fontSize=9,
        textColor=colors.HexColor("#7F8C8D"), alignment=TA_CENTER, spaceAfter=3)

    st_centro = ParagraphStyle("centro",
        parent=styles["Normal"], fontSize=9, alignment=TA_CENTER, spaceAfter=2)

    st_label = ParagraphStyle("label",
        parent=styles["Normal"], fontSize=8, textColor=colors.grey, spaceAfter=1)

    st_valor = ParagraphStyle("valor",
        parent=styles["Normal"], fontSize=10, fontName="Helvetica-Bold", spaceAfter=2)

    st_pie = ParagraphStyle("pie",
        parent=styles["Normal"], fontSize=7,
        textColor=colors.grey, alignment=TA_CENTER)

    linea = Table([[""]], colWidths=[125*mm], rowHeights=[0.5],
                  style=TableStyle([("LINEABOVE", (0,0), (-1,-1), 0.8, colors.HexColor("#2C3E50"))]))

    story.append(Paragraph(EMPRESA_NOMBRE, st_empresa))
    story.append(Paragraph(EMPRESA_SLOGAN, st_slogan))
    story.append(linea)
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph(f"<b>RECIBO N° {pedido['numero_recibo']}</b>", st_centro))
    fecha_ped = pedido["fecha_pedido"].strftime("%d/%m/%Y %H:%M") if hasattr(pedido["fecha_pedido"], "strftime") else str(pedido["fecha_pedido"])
    fecha_ent = pedido["fecha_entrega"].strftime("%d/%m/%Y") if hasattr(pedido["fecha_entrega"], "strftime") else str(pedido["fecha_entrega"])
    story.append(Paragraph(f"Emitido: {fecha_ped}  |  Entrega: {fecha_ent}", st_centro))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph("CLIENTE:", st_label))
    story.append(Paragraph(cliente["nombre_negocio"], st_valor))
    if cliente.get("telefono"):
        story.append(Paragraph(f"Tel: {cliente['telefono']}", st_label))
    story.append(Spacer(1, 4*mm))

    encabezado = [["Tipo de Pan", "Peso", "Cant.", "P.Unit.", "Total"]]
    filas = [[
        item["tipo_pan"],
        f"{item['peso_g']}g",
        str(item["cantidad"]),
        f"${item['precio_unitario']:.2f}",
        f"${item['subtotal']:.2f}"
    ] for item in items]

    tabla = Table(
        encabezado + filas,
        colWidths=[50*mm, 18*mm, 15*mm, 20*mm, 20*mm]
    )
    tabla.setStyle(TableStyle([
        ("BACKGROUND",    (0,0), (-1,0),  colors.HexColor("#2C3E50")),
        ("TEXTCOLOR",     (0,0), (-1,0),  colors.white),
        ("FONTNAME",      (0,0), (-1,0),  "Helvetica-Bold"),
        ("FONTSIZE",      (0,0), (-1,-1), 8),
        ("ALIGN",         (1,0), (-1,-1), "CENTER"),
        ("ROWBACKGROUNDS",(0,1), (-1,-1), [colors.white, colors.HexColor("#F8F9FA")]),
        ("GRID",          (0,0), (-1,-1), 0.4, colors.HexColor("#DEE2E6")),
        ("TOPPADDING",    (0,0), (-1,-1), 3),
        ("BOTTOMPADDING", (0,0), (-1,-1), 3),
    ]))
    story.append(tabla)
    story.append(Spacer(1, 4*mm))

    total_tabla = Table(
        [["", "MONTO TOTAL:", f"${pedido['monto_total']:.2f}"]],
        colWidths=[68*mm, 32*mm, 23*mm]
    )
    total_tabla.setStyle(TableStyle([
        ("FONTNAME",      (1,0), (-1,0), "Helvetica-Bold"),
        ("FONTSIZE",      (1,0), (-1,0), 11),
        ("BACKGROUND",    (1,0), (-1,0), colors.HexColor("#2C3E50")),
        ("TEXTCOLOR",     (1,0), (-1,0), colors.white),
        ("ALIGN",         (1,0), (-1,0), "CENTER"),
        ("TOPPADDING",    (0,0), (-1,-1), 5),
        ("BOTTOMPADDING", (0,0), (-1,-1), 5),
    ]))
    story.append(total_tabla)
    story.append(Spacer(1, 6*mm))

    story.append(linea)
    story.append(Paragraph("COPIA sin Derecho a Crédito Fiscal", st_pie))

    doc.build(story)
    return buffer.getvalue()

# ============================================================
# GUARDAR EN CARPETA LOCAL
# ============================================================
def guardar_localmente(pdf_bytes: bytes, nombre_archivo: str) -> str:
    """Guarda el PDF en RECIBOS_DIR y retorna la ruta completa."""
    os.makedirs(RECIBOS_DIR, exist_ok=True)
    ruta = os.path.join(RECIBOS_DIR, nombre_archivo)
    with open(ruta, "wb") as f:
        f.write(pdf_bytes)
    logger.info(f"PDF guardado: {ruta}")
    return ruta

# ============================================================
# FUNCION PRINCIPAL: Procesar recibo completo
# ============================================================
async def procesar_recibo(id_pedido: int) -> tuple:
    """
    Obtiene datos del pedido desde BD, genera PDF y lo guarda localmente.
    Retorna (ruta_local, pdf_bytes). ruta_local es "" si falló el guardado.
    El pedido NO se bloquea si el guardado falla — pdf_bytes siempre se retorna.
    """
    conn = await asyncpg.connect(**DB_CONFIG)
    try:
        pedido = await conn.fetchrow("""
            SELECT p.*, c.nombre_negocio, c.telefono
            FROM pedidos p
            JOIN clientes c ON c.id_cliente = p.id_cliente
            WHERE p.id_pedido = $1
        """, id_pedido)

        if not pedido:
            raise ValueError(f"Pedido {id_pedido} no encontrado")

        items = await conn.fetch(
            "SELECT * FROM detalle_pedidos WHERE id_pedido = $1 ORDER BY id_detalle",
            id_pedido
        )

        cliente = {
            "nombre_negocio": pedido["nombre_negocio"],
            "telefono":       pedido["telefono"],
        }

        pdf_bytes = generar_pdf(dict(pedido), cliente, [dict(i) for i in items])

        nombre_archivo = (
            f"Recibo_{pedido['numero_recibo']}_"
            f"{pedido['nombre_negocio'].replace(' ', '_')}_"
            f"{datetime.now().strftime('%Y%m%d')}.pdf"
        )

        ruta_local = ""
        try:
            ruta_local = guardar_localmente(pdf_bytes, nombre_archivo)
            await conn.execute(
                "UPDATE pedidos SET archivo_pdf_url = $1 WHERE id_pedido = $2",
                ruta_local, id_pedido
            )
        except Exception as e:
            logger.error(f"Error guardando PDF local para pedido {id_pedido}: {e}")

        return ruta_local, pdf_bytes

    finally:
        await conn.close()
