from fastapi import FastAPI, HTTPException, Depends, Request, Query, Response
from starlette.background import BackgroundTask
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import StreamingResponse, JSONResponse, RedirectResponse, FileResponse
from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime, timedelta
import asyncio
import asyncpg
import hashlib
import io
import os
import secrets
import subprocess
import tempfile
from dotenv import load_dotenv

from reportlab.lib import colors
from reportlab.lib.pagesizes import A5
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.enums import TA_CENTER
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer

load_dotenv()

# Versión del JS calculada al inicio desde el mtime del archivo
_JS_VERSION = str(int(os.path.getmtime("static/app.js"))) if os.path.exists("static/app.js") else "0"

# ── Auth ──────────────────────────────────────────────────────────────────────
_ADMIN_USER = os.getenv("DASHBOARD_USER", "admin")
_DASHBOARD_PASSWORD = os.getenv("DASHBOARD_PASSWORD")
if not _DASHBOARD_PASSWORD:
    raise RuntimeError("DASHBOARD_PASSWORD no está definida en el entorno. El sistema no puede arrancar sin credenciales.")
_ADMIN_HASH = hashlib.sha256(_DASHBOARD_PASSWORD.encode()).hexdigest()
_SESSION_TTL = timedelta(hours=8)

# token → expiry; reemplazar con Redis en producción multi-instancia
_sessions: dict[str, datetime] = {}

# Rate limiting login: ip → (intentos, primer_intento)
_login_attempts: dict[str, tuple[int, datetime]] = {}
_LOGIN_MAX_INTENTOS = 5
_LOGIN_VENTANA      = timedelta(minutes=10)

_AUTH_SKIP = {"/", "/dashboard", "/api/login", "/api/logout", "/health"}

app = FastAPI(title="Dashboard Panificadora")
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

_ALLOWED_ORIGINS = [o.strip() for o in os.getenv("ALLOWED_ORIGINS", "http://localhost:8000").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def no_cache_api(request: Request, call_next):
    response = await call_next(request)
    if request.url.path.startswith("/api/"):
        response.headers["Cache-Control"] = "no-store"
    return response

@app.middleware("http")
async def auth_middleware(request: Request, call_next):
    path = request.url.path
    if path in _AUTH_SKIP or path.startswith("/static/"):
        return await call_next(request)

    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return JSONResponse(status_code=401, content={"detail": "No autorizado"})

    token  = auth[7:]
    expiry = _sessions.get(token)
    if not expiry or datetime.utcnow() > expiry:
        _sessions.pop(token, None)
        return JSONResponse(status_code=401, content={"detail": "Sesión expirada"})

    return await call_next(request)

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "panificadora_db"),
    "port": int(os.getenv("DB_PORT", 5432)),
    "user": os.getenv("DB_USER", "panif_user"),
    "password": os.getenv("DB_PASSWORD", "panif_pass"),
    "database": os.getenv("DB_NAME", "panificadora"),
}

async def get_db():
    conn = await asyncpg.connect(**DB_CONFIG)
    try:
        yield conn
    finally:
        await conn.close()

# ── Models ────────────────────────────────────────────────────────────────────

class PedidoConfirmacion(BaseModel):
    fecha_produccion: date
    fecha_despacho: date

class DespachoFecha(BaseModel):
    nueva_fecha: date

class TipoMasaCreate(BaseModel):
    tipo_masa: str
    peso_masa_g: int
    descripcion: Optional[str] = None

class TipoMasaUpdate(BaseModel):
    peso_masa_g: int
    descripcion: Optional[str] = None

class IngredienteCreate(BaseModel):
    ingrediente: str
    cantidad_por_kg_masa: float
    unidad: str = "kg"

class IngredienteUpdate(BaseModel):
    cantidad_por_kg_masa: float
    unidad: str

class ReciboGenerar(BaseModel):
    monto_delivery: float = 0
    aplica_iva: bool = False

class ProductoCreate(BaseModel):
    nombre: str
    tipo_pan: str
    peso_g: int
    precio_unitario: float
    tipo_masa: Optional[str] = None
    paquete_cantidad: Optional[int] = None
    paquete_tipo: Optional[str] = None

class ProductoUpdate(BaseModel):
    nombre: str
    tipo_pan: str
    peso_g: int
    precio_unitario: float
    tipo_masa: Optional[str] = None
    paquete_cantidad: Optional[int] = None
    paquete_tipo: Optional[str] = None

class LineaPedido(BaseModel):
    tipo_pan: str
    producto: str
    peso_g: int
    cantidad: int
    tipo_unidad: str = "unidad"
    precio_unitario: float
    toping: Optional[str] = None

class PedidoManualCreate(BaseModel):
    id_cliente: int
    lineas: list[LineaPedido]

class PedidoManualEdit(BaseModel):
    lineas: list[LineaPedido]

class PagoRegistrar(BaseModel):
    id_deuda: int
    monto_pagado: float
    metodo: str = "efectivo"
    registrado_por: str = "admin_dashboard"

# ── Pedidos ───────────────────────────────────────────────────────────────────

@app.get("/api/pedidos/pendientes")
async def get_pedidos_pendientes(conn: asyncpg.Connection = Depends(get_db)):
    try:
        rows = await conn.fetch("""
            SELECT
                p.id_pedido,
                p.numero_recibo,
                c.nombre_negocio AS cliente,
                p.monto_total,
                p.fecha_pedido AS fecha_creacion,
                p.estado
            FROM pedidos p
            JOIN clientes c ON c.id_cliente = p.id_cliente
            WHERE p.estado = 'pendiente'
            ORDER BY p.fecha_pedido DESC
        """)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/pedidos/{id_pedido}/detalles")
async def get_pedido_detalles(id_pedido: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        pedido = await conn.fetchrow("SELECT * FROM pedidos WHERE id_pedido = $1", id_pedido)
        if not pedido:
            raise HTTPException(status_code=404, detail="Pedido no encontrado")
        detalles = await conn.fetch("SELECT * FROM detalle_pedidos WHERE id_pedido = $1", id_pedido)
        return {"pedido": dict(pedido), "detalles": [dict(d) for d in detalles]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/pedidos/{id_pedido}/confirmar")
async def confirmar_pedido(id_pedido: int, data: PedidoConfirmacion, conn: asyncpg.Connection = Depends(get_db)):
    try:
        estado_actual = await conn.fetchval("SELECT estado FROM pedidos WHERE id_pedido = $1", id_pedido)
        if not estado_actual:
            raise HTTPException(status_code=404, detail="Pedido no encontrado")
        if estado_actual != "pendiente":
            raise HTTPException(status_code=409, detail=f"Solo se pueden confirmar pedidos PENDIENTES (estado actual: {estado_actual})")
        async with conn.transaction():
            await conn.execute("""
                UPDATE pedidos SET
                    estado = 'confirmado',
                    fecha_produccion_requerida = $1,
                    fecha_despacho_real = $2,
                    confirmado_por_admin = TRUE,
                    fecha_confirmacion_admin = NOW()
                WHERE id_pedido = $3
            """, data.fecha_produccion, data.fecha_despacho, id_pedido)

            detalles = await conn.fetch("""
                SELECT dp.tipo_pan, dp.producto, dp.peso_g, dp.cantidad, dp.tipo_unidad,
                       COALESCE(p.paquete_cantidad, 1) AS paquete_cantidad
                FROM detalle_pedidos dp
                LEFT JOIN productos p ON p.nombre = dp.producto
                WHERE dp.id_pedido = $1
            """, id_pedido)
            for d in detalles:
                # Siempre usar paquete_cantidad del producto para convertir a unidades individuales
                factor = d["paquete_cantidad"] if d["paquete_cantidad"] > 1 else 1
                unidades_reales = d["cantidad"] * factor
                peso_total      = unidades_reales * d["peso_g"] if d["peso_g"] else None
                await conn.execute("""
                    INSERT INTO produccion_diaria
                        (id_pedido, fecha_produccion, fecha_produccion_requerida,
                         tipo_pan, producto, peso_g, total_unidades, peso_total_g)
                    VALUES ($1, NOW()::date, $2, $3, $4, $5, $6, $7)
                    ON CONFLICT ON CONSTRAINT produccion_diaria_pedido_tipo_producto_peso_key
                    DO UPDATE SET total_unidades = produccion_diaria.total_unidades + EXCLUDED.total_unidades,
                                  peso_total_g   = produccion_diaria.peso_total_g + EXCLUDED.peso_total_g
                """, id_pedido, data.fecha_produccion,
                    d["tipo_pan"], d["producto"], d["peso_g"],
                    unidades_reales, peso_total)
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/pedidos/{id_pedido}/entregar")
async def entregar_pedido(id_pedido: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        estado_actual = await conn.fetchval("SELECT estado FROM pedidos WHERE id_pedido = $1", id_pedido)
        if not estado_actual:
            raise HTTPException(status_code=404, detail="Pedido no encontrado")
        if estado_actual != "confirmado":
            raise HTTPException(status_code=409, detail=f"Solo se pueden entregar pedidos CONFIRMADOS (estado actual: {estado_actual})")
        async with conn.transaction():
            await conn.execute("""
                UPDATE pedidos SET estado = 'entregado', fecha_confirmacion_despacho = NOW()
                WHERE id_pedido = $1
            """, id_pedido)
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

async def _resolver_tipo_pan(conn, nombre_producto: str, tipo_pan_producto: str) -> str:
    """Devuelve tipo_masa del producto para que sea consistente con el bot en detalle_pedidos."""
    tipo_masa = await conn.fetchval(
        "SELECT tipo_masa FROM productos WHERE nombre = $1 AND tipo_pan = $2 AND tipo_masa IS NOT NULL LIMIT 1",
        nombre_producto, tipo_pan_producto
    )
    return tipo_masa or tipo_pan_producto

@app.post("/api/pedidos/crear-manual")
async def crear_pedido_manual(data: PedidoManualCreate, conn: asyncpg.Connection = Depends(get_db)):
    if not data.lineas:
        raise HTTPException(status_code=422, detail="El pedido debe tener al menos una línea")
    try:
        async with conn.transaction():
            numero_recibo = await conn.fetchval("SELECT generar_numero_recibo()")
            monto_total = round(sum(l.cantidad * l.precio_unitario for l in data.lineas), 2)
            fecha_entrega = date.today() + timedelta(days=1)
            row = await conn.fetchrow("""
                INSERT INTO pedidos (id_cliente, numero_recibo, fecha_entrega, monto_total, estado, registrado_por)
                VALUES ($1, $2, $3, $4, 'pendiente', 'admin_dashboard')
                RETURNING id_pedido
            """, data.id_cliente, numero_recibo, fecha_entrega, monto_total)
            id_pedido = row["id_pedido"]
            for l in data.lineas:
                tipo_pan_detalle = await _resolver_tipo_pan(conn, l.producto, l.tipo_pan)
                subtotal = round(l.cantidad * l.precio_unitario, 2)
                await conn.execute("""
                    INSERT INTO detalle_pedidos
                        (id_pedido, tipo_pan, producto, peso_g, cantidad, tipo_unidad, precio_unitario, subtotal, toping)
                    VALUES ($1, $2, $3, $4, $5, $6::tipo_unidad, $7, $8, $9)
                """, id_pedido, tipo_pan_detalle, l.producto, l.peso_g,
                    l.cantidad, l.tipo_unidad, l.precio_unitario, subtotal, l.toping)
            # Crear deuda igual que el bot cliente
            await conn.execute(
                "INSERT INTO deudas (id_cliente, id_pedido, monto_original) VALUES ($1, $2, $3)",
                data.id_cliente, id_pedido, monto_total
            )
        return {"status": "OK", "id_pedido": id_pedido, "numero_recibo": numero_recibo}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/pedidos/{id_pedido}/editar")
async def editar_pedido_manual(id_pedido: int, data: PedidoManualEdit, conn: asyncpg.Connection = Depends(get_db)):
    if not data.lineas:
        raise HTTPException(status_code=422, detail="El pedido debe tener al menos una línea")
    try:
        pedido = await conn.fetchrow("SELECT estado, id_cliente FROM pedidos WHERE id_pedido = $1", id_pedido)
        if not pedido:
            raise HTTPException(status_code=404, detail="Pedido no encontrado")
        if pedido["estado"] != "pendiente":
            raise HTTPException(status_code=409, detail=f"Solo se pueden editar pedidos PENDIENTES (estado actual: {pedido['estado']})")
        async with conn.transaction():
            monto_total = round(sum(l.cantidad * l.precio_unitario for l in data.lineas), 2)
            await conn.execute("""
                UPDATE pedidos SET monto_total = $1 WHERE id_pedido = $2
            """, monto_total, id_pedido)
            await conn.execute("DELETE FROM detalle_pedidos WHERE id_pedido = $1", id_pedido)
            for l in data.lineas:
                tipo_pan_detalle = await _resolver_tipo_pan(conn, l.producto, l.tipo_pan)
                subtotal = round(l.cantidad * l.precio_unitario, 2)
                await conn.execute("""
                    INSERT INTO detalle_pedidos
                        (id_pedido, tipo_pan, producto, peso_g, cantidad, tipo_unidad, precio_unitario, subtotal, toping)
                    VALUES ($1, $2, $3, $4, $5, $6::tipo_unidad, $7, $8, $9)
                """, id_pedido, tipo_pan_detalle, l.producto, l.peso_g,
                    l.cantidad, l.tipo_unidad, l.precio_unitario, subtotal, l.toping)
            # Validar que el nuevo monto no sea menor a lo ya pagado
            deuda_actual = await conn.fetchrow(
                "SELECT monto_pagado FROM deudas WHERE id_pedido = $1 AND estado IN ('pendiente', 'parcial')",
                id_pedido
            )
            if deuda_actual and monto_total < float(deuda_actual["monto_pagado"]):
                raise HTTPException(status_code=409,
                    detail=f"El nuevo monto ({monto_total}) es menor que lo ya pagado ({float(deuda_actual['monto_pagado'])})")
            # Actualizar monto_original de la deuda si existe (pendiente o parcial)
            await conn.execute("""
                UPDATE deudas SET monto_original = $1
                WHERE id_pedido = $2 AND estado IN ('pendiente', 'parcial')
            """, monto_total, id_pedido)
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/pedidos/{id_pedido}")
async def eliminar_pedido(id_pedido: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        estado_actual = await conn.fetchval("SELECT estado FROM pedidos WHERE id_pedido = $1", id_pedido)
        if not estado_actual:
            raise HTTPException(status_code=404, detail="Pedido no encontrado")
        if estado_actual not in ("pendiente", "cancelado"):
            raise HTTPException(status_code=409, detail=f"Solo se pueden eliminar pedidos PENDIENTES o CANCELADOS (estado actual: {estado_actual})")
        async with conn.transaction():
            await conn.execute("DELETE FROM produccion_diaria WHERE id_pedido = $1", id_pedido)
            await conn.execute("DELETE FROM deudas WHERE id_pedido = $1", id_pedido)
            await conn.execute("DELETE FROM pedidos WHERE id_pedido = $1", id_pedido)
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/pedidos/{id_pedido}/cancelar")
async def cancelar_pedido(id_pedido: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        pedido = await conn.fetchrow(
            "SELECT estado, fecha_produccion_requerida FROM pedidos WHERE id_pedido = $1", id_pedido
        )
        if not pedido:
            raise HTTPException(status_code=404, detail="Pedido no encontrado")
        if pedido["estado"] not in ("pendiente", "confirmado"):
            raise HTTPException(status_code=409, detail=f"No se puede cancelar un pedido en estado {pedido['estado']}")
        async with conn.transaction():
            await conn.execute(
                "UPDATE pedidos SET estado = 'cancelado' WHERE id_pedido = $1", id_pedido
            )
            await conn.execute(
                "UPDATE deudas SET estado = 'pagado'::estado_deuda, monto_pagado = monto_original WHERE id_pedido = $1", id_pedido
            )
            # Si era confirmado, eliminar su entrada de producción
            if pedido["estado"] == "confirmado":
                await conn.execute(
                    "DELETE FROM produccion_diaria WHERE id_pedido = $1", id_pedido
                )
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Producción ────────────────────────────────────────────────────────────────

@app.get("/api/produccion/{fecha}")
async def get_produccion_por_fecha(fecha: date, conn: asyncpg.Connection = Depends(get_db)):
    try:
        rows = await conn.fetch("""
            SELECT
                pd.tipo_pan                                                AS tipo_masa,
                pd.producto,
                MAX(pd.peso_g)                                             AS peso_g,
                SUM(pd.total_unidades)                                     AS total_unidades,
                COALESCE(MAX(pr.paquete_cantidad), 1)                      AS paquete_cantidad,
                STRING_AGG(DISTINCT c.nombre_negocio, ', ')                AS cliente,
                STRING_AGG(DISTINCT COALESCE(dp.toping, 'Sin toping'), ' / ') AS topings
            FROM produccion_diaria pd
            JOIN pedidos  p  ON p.id_pedido   = pd.id_pedido
            JOIN clientes c  ON c.id_cliente  = p.id_cliente
            LEFT JOIN productos pr ON pr.nombre = pd.producto
            LEFT JOIN detalle_pedidos dp ON dp.id_pedido = pd.id_pedido
                AND dp.producto = pd.producto AND dp.peso_g = pd.peso_g
            WHERE pd.fecha_produccion_requerida = $1
            GROUP BY pd.tipo_pan, pd.producto
            ORDER BY pd.tipo_pan, MAX(pd.peso_g)
        """, fecha)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/ingredientes/{fecha}")
async def get_ingredientes_por_fecha(fecha: date, conn: asyncpg.Connection = Depends(get_db)):
    try:
        rows = await conn.fetch("""
            SELECT * FROM vista_ingredientes_por_fecha WHERE fecha_produccion_requerida = $1
        """, fecha)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/produccion/{fecha}/estado")
async def get_estado_produccion(fecha: date, conn: asyncpg.Connection = Depends(get_db)):
    try:
        estado = await conn.fetchval(
            "SELECT estado FROM produccion_diaria WHERE fecha_produccion_requerida = $1 LIMIT 1", fecha
        )
        return {"estado": estado or "pendiente"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/produccion/{fecha}/estado")
async def actualizar_estado_produccion(fecha: date, data: dict, conn: asyncpg.Connection = Depends(get_db)):
    estado = data.get("estado")
    if estado not in ("pendiente", "en_proceso", "completado"):
        raise HTTPException(status_code=422, detail="Estado inválido")
    try:
        await conn.execute(
            "UPDATE produccion_diaria SET estado = $1::estado_produccion WHERE fecha_produccion_requerida = $2",
            estado, fecha
        )
        return {"status": "OK", "estado": estado}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/produccion-detalle/{fecha}")
async def get_produccion_detalle(fecha: date, conn: asyncpg.Connection = Depends(get_db)):
    """Tabla 1A: detalle por tipo_masa + producto + cliente."""
    try:
        rows = await conn.fetch("""
            SELECT
                pd.tipo_pan                                                AS tipo_masa,
                pd.producto,
                COALESCE(MAX(pr.peso_g), MAX(pd.peso_g))                  AS peso_g,
                SUM(pd.total_unidades)                                     AS cantidad,
                COALESCE(MAX(pr.paquete_cantidad), 1)                      AS paquete_cantidad,
                STRING_AGG(DISTINCT c.nombre_negocio, ', ')                AS clientes,
                STRING_AGG(DISTINCT COALESCE(dp.toping, 'Sin toping'), ' / ') AS topings
            FROM produccion_diaria pd
            JOIN pedidos  p ON p.id_pedido  = pd.id_pedido
            JOIN clientes c ON c.id_cliente = p.id_cliente
            LEFT JOIN productos pr ON pr.nombre = pd.producto
            LEFT JOIN detalle_pedidos dp ON dp.id_pedido = pd.id_pedido
                AND dp.producto = pd.producto AND dp.peso_g = pd.peso_g
            WHERE pd.fecha_produccion_requerida = $1
            GROUP BY pd.tipo_pan, pd.producto
            ORDER BY pd.tipo_pan, pd.producto
        """, fecha)
        return [dict(r) for r in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/ingredientes-resumen/{fecha}")
async def get_ingredientes_resumen(fecha: date, conn: asyncpg.Connection = Depends(get_db)):
    """Tabla 1B: por tipo_masa → panes que la usan + total unidades."""
    try:
        rows = await conn.fetch("""
            SELECT
                tipo_pan                                                                AS tipo_masa,
                STRING_AGG(producto || ' (' || total_uds::text || ')', ', '
                           ORDER BY producto)                                           AS panes_detalle,
                SUM(total_uds)                                                         AS unidades_total,
                EXISTS(SELECT 1 FROM recetas_masa rm WHERE rm.tipo_masa = tipo_pan)    AS tiene_receta
            FROM (
                SELECT tipo_pan, producto, SUM(total_unidades) AS total_uds
                FROM produccion_diaria
                WHERE fecha_produccion_requerida = $1
                GROUP BY tipo_pan, producto
            ) sub
            GROUP BY tipo_pan
            ORDER BY tipo_pan
        """, fecha)
        return [dict(r) for r in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/ingredientes-detalle/{fecha}/{tipo_masa}")
async def get_ingredientes_detalle_masa(fecha: date, tipo_masa: str, conn: asyncpg.Connection = Depends(get_db)):
    """Modal: ingredientes de un tipo_masa específico en una fecha."""
    try:
        ingredientes = await conn.fetch("""
            WITH gramos_receta AS (
                SELECT rm.tipo_masa, rm.ingrediente,
                       ROUND(rm.cantidad_por_kg_masa * tm.peso_masa_g) AS gramos,
                       SUM(ROUND(rm.cantidad_por_kg_masa * tm.peso_masa_g))
                           OVER (PARTITION BY rm.tipo_masa) AS total_gramos
                FROM recetas_masa rm
                JOIN tipos_masa tm ON tm.tipo_masa = rm.tipo_masa
                WHERE rm.tipo_masa = $2
            ),
            produccion_masa AS (
                SELECT pd.tipo_pan,
                       SUM(pd.total_unidades * COALESCE(pr.peso_g, pd.peso_g)) AS total_masa_g
                FROM produccion_diaria pd
                LEFT JOIN productos pr ON pr.nombre = pd.producto
                WHERE pd.fecha_produccion_requerida = $1 AND pd.tipo_pan = $2
                GROUP BY pd.tipo_pan
            )
            SELECT gr.ingrediente,
                   ROUND(pm.total_masa_g::numeric / gr.total_gramos * gr.gramos) AS cantidad_g
            FROM gramos_receta gr
            JOIN produccion_masa pm ON pm.tipo_pan = gr.tipo_masa
            ORDER BY gr.ingrediente
        """, fecha, tipo_masa)
        panes = await conn.fetch("""
            SELECT producto, SUM(total_unidades) AS cantidad
            FROM produccion_diaria
            WHERE fecha_produccion_requerida = $1 AND tipo_pan = $2
            GROUP BY producto ORDER BY producto
        """, fecha, tipo_masa)
        return {
            "tipo_masa": tipo_masa,
            "panes": [dict(p) for p in panes],
            "ingredientes": [dict(i) for i in ingredientes],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Despachos ─────────────────────────────────────────────────────────────────

@app.get("/api/despachos")
async def get_despachos(conn: asyncpg.Connection = Depends(get_db)):
    try:
        rows = await conn.fetch("""
            SELECT
                p.id_pedido,
                p.numero_recibo,
                c.nombre_negocio AS cliente,
                p.monto_total,
                p.fecha_despacho_real,
                p.estado
            FROM pedidos p
            JOIN clientes c ON c.id_cliente = p.id_cliente
            WHERE p.estado = 'confirmado'
            ORDER BY p.fecha_despacho_real ASC
        """)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/despachos/{id_pedido}/cambiar-fecha")
async def cambiar_fecha_despacho(id_pedido: int, data: DespachoFecha, conn: asyncpg.Connection = Depends(get_db)):
    try:
        estado = await conn.fetchval("SELECT estado FROM pedidos WHERE id_pedido = $1", id_pedido)
        if estado is None:
            raise HTTPException(status_code=404, detail="Pedido no encontrado")
        if estado in ("cancelado",):
            raise HTTPException(status_code=409, detail=f"No se puede cambiar fecha de despacho de un pedido cancelado")
        resultado = await conn.execute(
            "UPDATE pedidos SET fecha_despacho_real = $1 WHERE id_pedido = $2",
            data.nueva_fecha, id_pedido
        )
        if resultado == "UPDATE 0":
            raise HTTPException(status_code=404, detail="Pedido no encontrado")
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Deudas ────────────────────────────────────────────────────────────────────

@app.get("/api/deudas")
async def get_deudas(
    conn: asyncpg.Connection = Depends(get_db),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
):
    try:
        offset = (page - 1) * limit
        conditions = []
        params: list = []

        if search:
            params.append(f"%{search.upper()}%")
            conditions.append(f"UPPER(v.nombre_negocio) LIKE ${len(params)}")

        where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

        total_row = await conn.fetchrow(
            f"SELECT COUNT(*) FROM vista_deuda_clientes v {where}", *params
        )

        params.extend([limit, offset])
        rows = await conn.fetch(f"""
            SELECT v.* FROM vista_deuda_clientes v
            {where}
            ORDER BY v.deuda_total DESC
            LIMIT ${len(params) - 1} OFFSET ${len(params)}
        """, *params)

        return {
            "total": total_row[0],
            "page": page,
            "limit": limit,
            "items": [dict(row) for row in rows],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Pagos ─────────────────────────────────────────────────────────────────────

@app.get("/api/deudas/{id_cliente}/detalle")
async def get_deuda_detalle(id_cliente: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        cliente = await conn.fetchrow("SELECT nombre_negocio, telefono FROM clientes WHERE id_cliente = $1", id_cliente)
        if not cliente:
            raise HTTPException(status_code=404, detail="Cliente no encontrado")
        deudas = await conn.fetch("""
            SELECT d.id_deuda, d.id_pedido, p.numero_recibo, p.fecha_pedido,
                   d.monto_original, d.monto_pagado, d.saldo_pendiente, d.estado,
                   COALESCE(d.descripcion, p.numero_recibo, 'Sin descripción') AS descripcion_display
            FROM deudas d
            LEFT JOIN pedidos p ON p.id_pedido = d.id_pedido
            WHERE d.id_cliente = $1
            ORDER BY d.fecha_creacion DESC
        """, id_cliente)
        return {
            "cliente": dict(cliente),
            "deudas": [dict(d) for d in deudas]
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class DeudaManualCreate(BaseModel):
    id_cliente: int
    descripcion: str
    monto_original: float

@app.post("/api/deudas/manual")
async def crear_deuda_manual(data: DeudaManualCreate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        if data.monto_original <= 0:
            raise HTTPException(status_code=422, detail="El monto debe ser mayor a 0")
        cliente = await conn.fetchrow("SELECT id_cliente FROM clientes WHERE id_cliente = $1", data.id_cliente)
        if not cliente:
            raise HTTPException(status_code=404, detail="Cliente no encontrado")
        row = await conn.fetchrow("""
            INSERT INTO deudas (id_cliente, id_pedido, monto_original, descripcion, estado)
            VALUES ($1, NULL, $2, $3, 'pendiente')
            RETURNING id_deuda
        """, data.id_cliente, data.monto_original, data.descripcion.strip())
        return {"status": "OK", "id_deuda": row["id_deuda"]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/pagos")
async def registrar_pago(data: PagoRegistrar, conn: asyncpg.Connection = Depends(get_db)):
    try:
        deuda = await conn.fetchrow(
            "SELECT id_cliente, saldo_pendiente, estado FROM deudas WHERE id_deuda = $1", data.id_deuda
        )
        if not deuda:
            raise HTTPException(status_code=404, detail="Deuda no encontrada")
        if deuda["estado"] == "pagado":
            raise HTTPException(status_code=409, detail="Esta deuda ya está pagada")
        if data.monto_pagado <= 0:
            raise HTTPException(status_code=422, detail="El monto debe ser mayor a 0")
        if data.monto_pagado > float(deuda["saldo_pendiente"]):
            raise HTTPException(status_code=422, detail=f"El monto excede el saldo pendiente (${float(deuda['saldo_pendiente']):.2f})")
        async with conn.transaction():
            await conn.execute("""
                INSERT INTO pagos (id_deuda, id_cliente, monto_pagado, metodo, registrado_por)
                VALUES ($1, $2, $3, $4::metodo_pago, $5)
            """, data.id_deuda, deuda["id_cliente"], data.monto_pagado, data.metodo, data.registrado_por)
        nuevo_saldo = await conn.fetchrow(
            "SELECT saldo_pendiente, estado FROM deudas WHERE id_deuda = $1", data.id_deuda
        )
        return {"status": "OK", "saldo_pendiente": float(nuevo_saldo["saldo_pendiente"]), "estado": nuevo_saldo["estado"]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Recetas ───────────────────────────────────────────────────────────────────

@app.get("/api/recetas")
async def listar_recetas(conn: asyncpg.Connection = Depends(get_db)):
    try:
        rows = await conn.fetch("""
            SELECT
                t.tipo_masa, t.peso_masa_g, t.descripcion, t.activo,
                COUNT(r.id_receta) AS num_ingredientes
            FROM tipos_masa t
            LEFT JOIN recetas_masa r ON r.tipo_masa = t.tipo_masa
            GROUP BY t.tipo_masa, t.peso_masa_g, t.descripcion, t.activo
            ORDER BY t.tipo_masa
        """)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/recetas/{tipo_masa}/produccion-impact")
async def produccion_impact(tipo_masa: str, conn: asyncpg.Connection = Depends(get_db)):
    try:
        rows = await conn.fetch("""
            SELECT
                p.fecha_produccion_requerida,
                SUM(dp.cantidad)                              AS total_unidades,
                ROUND(SUM(dp.cantidad * dp.peso_g) / 1000.0, 3) AS kg_masa_total
            FROM detalle_pedidos dp
            JOIN pedidos p    ON p.id_pedido  = dp.id_pedido
            JOIN productos pr ON pr.nombre    = dp.producto
            WHERE pr.tipo_masa = $1
              AND p.estado = 'confirmado'
              AND p.fecha_produccion_requerida >= CURRENT_DATE
            GROUP BY p.fecha_produccion_requerida
            ORDER BY p.fecha_produccion_requerida
        """, tipo_masa)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/recetas/{tipo_masa}")
async def detalle_receta(tipo_masa: str, conn: asyncpg.Connection = Depends(get_db)):
    try:
        masa = await conn.fetchrow("SELECT * FROM tipos_masa WHERE tipo_masa = $1", tipo_masa)
        if not masa:
            raise HTTPException(status_code=404, detail="Receta no encontrada")
        ingredientes = await conn.fetch(
            "SELECT * FROM recetas_masa WHERE tipo_masa = $1 ORDER BY ingrediente", tipo_masa
        )
        return {"masa": dict(masa), "ingredientes": [dict(i) for i in ingredientes]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/recetas")
async def crear_receta(data: TipoMasaCreate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        await conn.execute("""
            INSERT INTO tipos_masa (tipo_masa, peso_masa_g, descripcion)
            VALUES ($1, $2, $3)
        """, data.tipo_masa.upper(), data.peso_masa_g, data.descripcion)
        return {"status": "OK", "tipo_masa": data.tipo_masa.upper()}
    except asyncpg.UniqueViolationError:
        raise HTTPException(status_code=409, detail="Ya existe una receta con ese nombre")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/recetas/{tipo_masa}")
async def editar_receta(tipo_masa: str, data: TipoMasaUpdate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        await conn.execute("""
            UPDATE tipos_masa
            SET peso_masa_g = $1,
                descripcion = COALESCE($2, descripcion)
            WHERE tipo_masa = $3
        """, data.peso_masa_g, data.descripcion, tipo_masa)
        return {"status": "OK"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/recetas/{tipo_masa}")
async def eliminar_receta(tipo_masa: str, conn: asyncpg.Connection = Depends(get_db)):
    try:
        await conn.execute("DELETE FROM recetas_masa WHERE tipo_masa = $1", tipo_masa)
        await conn.execute("DELETE FROM tipos_masa WHERE tipo_masa = $1", tipo_masa)
        return {"status": "OK"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/recetas/{tipo_masa}/desactivar")
async def desactivar_receta(tipo_masa: str, conn: asyncpg.Connection = Depends(get_db)):
    try:
        result = await conn.execute("UPDATE tipos_masa SET activo = false WHERE tipo_masa = $1", tipo_masa)
        if result == "UPDATE 0":
            raise HTTPException(status_code=404, detail="Receta no encontrada")
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/recetas/{tipo_masa}/activar")
async def activar_receta(tipo_masa: str, conn: asyncpg.Connection = Depends(get_db)):
    try:
        result = await conn.execute("UPDATE tipos_masa SET activo = true WHERE tipo_masa = $1", tipo_masa)
        if result == "UPDATE 0":
            raise HTTPException(status_code=404, detail="Receta no encontrada")
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/recetas/{tipo_masa}/ingredientes")
async def agregar_ingrediente(tipo_masa: str, data: IngredienteCreate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        await conn.execute("""
            INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad)
            VALUES ($1, $2, $3, $4)
        """, tipo_masa, data.ingrediente, data.cantidad_por_kg_masa, data.unidad)
        return {"status": "OK"}
    except asyncpg.UniqueViolationError:
        raise HTTPException(status_code=409, detail="Ese ingrediente ya existe en la receta")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/recetas/{tipo_masa}/ingredientes/{id_receta}")
async def editar_ingrediente(tipo_masa: str, id_receta: int, data: IngredienteUpdate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        await conn.execute("""
            UPDATE recetas_masa SET cantidad_por_kg_masa = $1, unidad = $2
            WHERE id_receta = $3 AND tipo_masa = $4
        """, data.cantidad_por_kg_masa, data.unidad, id_receta, tipo_masa)
        return {"status": "OK"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/recetas/{tipo_masa}/ingredientes/{id_receta}")
async def eliminar_ingrediente(tipo_masa: str, id_receta: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        await conn.execute(
            "DELETE FROM recetas_masa WHERE id_receta = $1 AND tipo_masa = $2", id_receta, tipo_masa
        )
        return {"status": "OK"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Recibos PDF ───────────────────────────────────────────────────────────────

def _generar_pdf(pedido: dict, cliente: dict, items: list) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A5,
        rightMargin=10*mm, leftMargin=10*mm, topMargin=10*mm, bottomMargin=10*mm)

    styles = getSampleStyleSheet()
    st_empresa = ParagraphStyle("empresa", parent=styles["Title"], fontSize=18,
        textColor=colors.HexColor("#2C3E50"), alignment=TA_CENTER, spaceAfter=1)
    st_slogan  = ParagraphStyle("slogan",  parent=styles["Normal"], fontSize=9,
        textColor=colors.HexColor("#7F8C8D"), alignment=TA_CENTER, spaceAfter=3)
    st_centro  = ParagraphStyle("centro",  parent=styles["Normal"], fontSize=9,
        alignment=TA_CENTER, spaceAfter=2)
    st_label   = ParagraphStyle("label",   parent=styles["Normal"], fontSize=8,
        textColor=colors.grey, spaceAfter=1)
    st_valor   = ParagraphStyle("valor",   parent=styles["Normal"], fontSize=10,
        fontName="Helvetica-Bold", spaceAfter=2)
    st_pie     = ParagraphStyle("pie",     parent=styles["Normal"], fontSize=7,
        textColor=colors.grey, alignment=TA_CENTER)

    linea = Table([[""]], colWidths=[125*mm], rowHeights=[0.5],
        style=TableStyle([("LINEABOVE", (0, 0), (-1, -1), 0.8, colors.HexColor("#2C3E50"))]))

    story = []
    story.append(Paragraph("PANIFICADORA", st_empresa))
    story.append(Paragraph("Pan fresco cada día", st_slogan))
    story.append(linea)
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph(f"<b>RECIBO N° {pedido['numero_recibo']}</b>", st_centro))
    fp = pedido.get("fecha_pedido")
    fe = pedido.get("fecha_entrega")
    fecha_ped = fp.strftime("%d/%m/%Y %H:%M") if hasattr(fp, "strftime") else str(fp or "")
    fecha_ent = fe.strftime("%d/%m/%Y")        if hasattr(fe, "strftime") else str(fe or "")
    story.append(Paragraph(f"Emitido: {fecha_ped}  |  Entrega: {fecha_ent}", st_centro))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph("CLIENTE:", st_label))
    story.append(Paragraph(cliente["nombre_negocio"], st_valor))
    if cliente.get("telefono"):
        story.append(Paragraph(f"Tel: {cliente['telefono']}", st_label))
    story.append(Spacer(1, 4*mm))

    encabezado = [["Tipo de Pan", "Peso", "Cant.", "P.Unit.", "Total"]]
    filas = [[
        item["tipo_pan"], f"{item['peso_g']}g", str(item["cantidad"]),
        f"${float(item['precio_unitario']):.2f}", f"${float(item['subtotal']):.2f}",
    ] for item in items]

    tabla = Table(encabezado + filas, colWidths=[50*mm, 18*mm, 15*mm, 20*mm, 20*mm])
    tabla.setStyle(TableStyle([
        ("BACKGROUND",     (0, 0), (-1, 0),  colors.HexColor("#2C3E50")),
        ("TEXTCOLOR",      (0, 0), (-1, 0),  colors.white),
        ("FONTNAME",       (0, 0), (-1, 0),  "Helvetica-Bold"),
        ("FONTSIZE",       (0, 0), (-1, -1), 8),
        ("ALIGN",          (1, 0), (-1, -1), "CENTER"),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8F9FA")]),
        ("GRID",           (0, 0), (-1, -1), 0.4, colors.HexColor("#DEE2E6")),
        ("TOPPADDING",     (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING",  (0, 0), (-1, -1), 3),
    ]))
    story.append(tabla)
    story.append(Spacer(1, 4*mm))

    subtotal = float(pedido.get("monto_total") or 0)
    delivery = float(pedido.get("monto_delivery") or 0)
    aplica_iva = bool(pedido.get("aplica_iva", False))
    iva   = round((subtotal + delivery) * 0.16, 2) if aplica_iva else 0
    total = subtotal + delivery + iva

    resumen = [["", "Subtotal:", f"${subtotal:.2f}"]]
    if delivery:
        resumen.append(["", "Delivery:", f"${delivery:.2f}"])
    if aplica_iva:
        resumen.append(["", "IVA 16%:", f"${iva:.2f}"])
    resumen.append(["", "TOTAL:", f"${total:.2f}"])

    resumen_tabla = Table(resumen, colWidths=[68*mm, 32*mm, 23*mm])
    resumen_tabla.setStyle(TableStyle([
        ("FONTNAME",      (1, -1), (-1, -1), "Helvetica-Bold"),
        ("FONTSIZE",      (1, -1), (-1, -1), 11),
        ("BACKGROUND",    (1, -1), (-1, -1), colors.HexColor("#2C3E50")),
        ("TEXTCOLOR",     (1, -1), (-1, -1), colors.white),
        ("ALIGN",         (1,  0), (-1, -1), "CENTER"),
        ("TOPPADDING",    (0,  0), (-1, -1), 4),
        ("BOTTOMPADDING", (0,  0), (-1, -1), 4),
        ("FONTSIZE",      (0,  0), (-1, -2), 9),
    ]))
    story.append(resumen_tabla)
    story.append(Spacer(1, 6*mm))
    story.append(linea)
    story.append(Paragraph("COPIA sin Derecho a Crédito Fiscal", st_pie))

    doc.build(story)
    return buffer.getvalue()


@app.post("/api/recibos/{id_pedido}/generar")
async def generar_recibo(id_pedido: int, data: ReciboGenerar, conn: asyncpg.Connection = Depends(get_db)):
    try:
        pedido = await conn.fetchrow("""
            SELECT p.*, c.nombre_negocio, c.telefono
            FROM pedidos p JOIN clientes c ON c.id_cliente = p.id_cliente
            WHERE p.id_pedido = $1
        """, id_pedido)
        if not pedido:
            raise HTTPException(status_code=404, detail="Pedido no encontrado")

        items = await conn.fetch(
            "SELECT * FROM detalle_pedidos WHERE id_pedido = $1 ORDER BY id_detalle", id_pedido
        )

        pedido_dict = dict(pedido)
        pedido_dict["monto_delivery"] = data.monto_delivery
        pedido_dict["aplica_iva"]     = data.aplica_iva

        cliente   = {"nombre_negocio": pedido["nombre_negocio"], "telefono": pedido["telefono"]}
        pdf_bytes = _generar_pdf(pedido_dict, cliente, [dict(i) for i in items])

        nombre = f"Recibo_{pedido['numero_recibo']}.pdf"
        return StreamingResponse(
            io.BytesIO(pdf_bytes),
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename={nombre}"},
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Clientes ─────────────────────────────────────────────────────────────────

class ClienteCreate(BaseModel):
    nombre_negocio: str
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    contacto_principal: Optional[str] = None
    categoria: str = "otro"
    telegram_id: Optional[str] = None

class ClienteUpdate(BaseModel):
    nombre_negocio: str
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    contacto_principal: Optional[str] = None
    categoria: str = "otro"
    telegram_id: Optional[str] = None

@app.get("/api/clientes")
async def listar_clientes(conn: asyncpg.Connection = Depends(get_db)):
    try:
        rows = await conn.fetch("""
            SELECT
                c.id_cliente, c.nombre_negocio, c.telefono, c.direccion,
                c.contacto_principal, c.categoria, c.estado, c.telegram_id,
                c.fecha_registro,
                COUNT(p.id_pedido) AS total_pedidos
            FROM clientes c
            LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
            GROUP BY c.id_cliente
            ORDER BY c.nombre_negocio
        """)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/clientes/{id_cliente}")
async def detalle_cliente(id_cliente: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        row = await conn.fetchrow("SELECT * FROM clientes WHERE id_cliente = $1", id_cliente)
        if not row:
            raise HTTPException(status_code=404, detail="Cliente no encontrado")
        pedidos = await conn.fetch("""
            SELECT id_pedido, numero_recibo, estado, monto_total, fecha_pedido
            FROM pedidos WHERE id_cliente = $1 ORDER BY fecha_pedido DESC LIMIT 10
        """, id_cliente)
        return {"cliente": dict(row), "pedidos_recientes": [dict(p) for p in pedidos]}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/clientes")
async def crear_cliente(data: ClienteCreate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        existente = await conn.fetchval(
            "SELECT id_cliente FROM clientes WHERE LOWER(nombre_negocio) = LOWER($1)",
            data.nombre_negocio.strip()
        )
        if existente:
            raise HTTPException(status_code=409, detail=f"Ya existe un cliente con ese nombre (id: {existente})")
        row = await conn.fetchrow("""
            INSERT INTO clientes (nombre_negocio, telefono, direccion, contacto_principal, categoria, telegram_id)
            VALUES ($1, $2, $3, $4, $5::categoria_cliente, $6)
            RETURNING id_cliente
        """, data.nombre_negocio.strip(), data.telefono or None, data.direccion or None,
            data.contacto_principal or None, data.categoria, data.telegram_id or None)
        return {"status": "OK", "id_cliente": row["id_cliente"]}
    except asyncpg.UniqueViolationError:
        raise HTTPException(status_code=409, detail="El telegram_id ya está registrado")
    except asyncpg.InvalidTextRepresentationError:
        raise HTTPException(status_code=422, detail="Categoría inválida")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/clientes/{id_cliente}/activar")
async def activar_cliente(id_cliente: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        result = await conn.execute(
            "UPDATE clientes SET estado = 'activo' WHERE id_cliente = $1", id_cliente
        )
        if result == "UPDATE 0":
            raise HTTPException(status_code=404, detail="Cliente no encontrado")
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/clientes/{id_cliente}")
async def editar_cliente(id_cliente: int, data: ClienteUpdate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        await conn.execute("""
            UPDATE clientes SET
                nombre_negocio     = $1,
                telefono           = $2,
                direccion          = $3,
                contacto_principal = $4,
                categoria          = $5::categoria_cliente,
                telegram_id        = $6
            WHERE id_cliente = $7
        """, data.nombre_negocio.strip(), data.telefono or None, data.direccion or None,
            data.contacto_principal or None, data.categoria, data.telegram_id or None, id_cliente)
        return {"status": "OK"}
    except asyncpg.InvalidTextRepresentationError:
        raise HTTPException(status_code=422, detail="Categoría inválida")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/clientes/{id_cliente}")
async def eliminar_cliente(id_cliente: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        tiene_pedidos = await conn.fetchval(
            "SELECT COUNT(*) FROM pedidos WHERE id_cliente = $1", id_cliente
        )
        if tiene_pedidos:
            # soft delete: preserva historial de pedidos
            await conn.execute(
                "UPDATE clientes SET estado = 'inactivo' WHERE id_cliente = $1", id_cliente
            )
            return {"status": "OK", "accion": "desactivado"}
        await conn.execute("DELETE FROM clientes WHERE id_cliente = $1", id_cliente)
        return {"status": "OK", "accion": "eliminado"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Productos ─────────────────────────────────────────────────────────────────

@app.get("/api/productos")
async def listar_productos(
    tipo_masa: Optional[str] = Query(None),
    solo_activos: bool = Query(False),
    conn: asyncpg.Connection = Depends(get_db),
):
    try:
        conditions: list[str] = []
        params: list = []
        if tipo_masa:
            params.append(tipo_masa)
            conditions.append(f"tipo_masa = ${len(params)}")
        if solo_activos:
            conditions.append("activo = TRUE")
        where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
        rows = await conn.fetch(
            f"SELECT * FROM productos {where} ORDER BY tipo_pan, peso_g, nombre",
            *params,
        )
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/productos")
async def crear_producto(data: ProductoCreate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        if data.tipo_masa:
            existe = await conn.fetchval(
                "SELECT 1 FROM tipos_masa WHERE tipo_masa = $1", data.tipo_masa
            )
            if not existe:
                raise HTTPException(status_code=422, detail=f"tipo_masa '{data.tipo_masa}' no existe")
        row = await conn.fetchrow("""
            INSERT INTO productos
                (nombre, tipo_pan, peso_g, precio_unitario, tipo_masa, paquete_cantidad, paquete_tipo)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id_producto
        """, data.nombre.strip(), data.tipo_pan.strip().upper(), data.peso_g,
            data.precio_unitario, data.tipo_masa or None,
            data.paquete_cantidad or None, data.paquete_tipo or None)
        return {"status": "OK", "id_producto": row["id_producto"]}
    except HTTPException:
        raise
    except asyncpg.UniqueViolationError:
        raise HTTPException(status_code=409, detail=f"Ya existe un producto con el nombre '{data.nombre.strip()}'")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/productos/{id_producto}")
async def detalle_producto(id_producto: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        row = await conn.fetchrow("SELECT * FROM productos WHERE id_producto = $1", id_producto)
        if not row:
            raise HTTPException(status_code=404, detail="Producto no encontrado")
        return dict(row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/productos/{id_producto}")
async def editar_producto(
    id_producto: int, data: ProductoUpdate, conn: asyncpg.Connection = Depends(get_db)
):
    try:
        if data.tipo_masa:
            existe = await conn.fetchval(
                "SELECT 1 FROM tipos_masa WHERE tipo_masa = $1", data.tipo_masa
            )
            if not existe:
                raise HTTPException(status_code=422, detail=f"tipo_masa '{data.tipo_masa}' no existe")
        result = await conn.execute("""
            UPDATE productos SET
                nombre                    = $1,
                tipo_pan                  = $2,
                peso_g                    = $3,
                precio_unitario           = $4,
                tipo_masa                 = $5,
                paquete_cantidad          = $6,
                paquete_tipo              = $7,
                fecha_ultima_modificacion = NOW()
            WHERE id_producto = $8
        """, data.nombre.strip(), data.tipo_pan.strip().upper(), data.peso_g,
            data.precio_unitario, data.tipo_masa or None,
            data.paquete_cantidad or None, data.paquete_tipo or None, id_producto)
        if result == "UPDATE 0":
            raise HTTPException(status_code=404, detail="Producto no encontrado")
        return {"status": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/productos/{id_producto}")
async def desactivar_producto(id_producto: int, conn: asyncpg.Connection = Depends(get_db)):
    try:
        result = await conn.execute("""
            UPDATE productos
            SET activo = NOT activo, fecha_ultima_modificacion = NOW()
            WHERE id_producto = $1
        """, id_producto)
        if result == "UPDATE 0":
            raise HTTPException(status_code=404, detail="Producto no encontrado")
        nuevo_estado = await conn.fetchval(
            "SELECT activo FROM productos WHERE id_producto = $1", id_producto
        )
        return {"status": "OK", "activo": nuevo_estado}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Auth endpoints ────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    usuario: str
    password: str

@app.post("/api/login")
async def login(data: LoginRequest, request: Request, response: Response):
    ip = request.client.host
    ahora = datetime.utcnow()

    intentos, primer_intento = _login_attempts.get(ip, (0, ahora))
    if ahora - primer_intento > _LOGIN_VENTANA:
        intentos, primer_intento = 0, ahora

    if intentos >= _LOGIN_MAX_INTENTOS:
        segundos = int((_LOGIN_VENTANA - (ahora - primer_intento)).total_seconds())
        raise HTTPException(status_code=429, detail=f"Demasiados intentos. Espera {segundos}s")

    usuario_hash = hashlib.sha256(data.password.encode()).hexdigest()
    if data.usuario != _ADMIN_USER or usuario_hash != _ADMIN_HASH:
        _login_attempts[ip] = (intentos + 1, primer_intento)
        raise HTTPException(status_code=401, detail="Credenciales inválidas")

    _login_attempts.pop(ip, None)
    token = secrets.token_hex(32)
    _sessions[token] = datetime.utcnow() + _SESSION_TTL
    response.set_cookie(
        key="session", value=token,
        httponly=True, max_age=28800, samesite="lax"
    )
    return {"token": token}

@app.post("/api/logout")
async def logout(request: Request, response: Response):
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        _sessions.pop(auth[7:], None)
    cookie_token = request.cookies.get("session")
    if cookie_token:
        _sessions.pop(cookie_token, None)
    response.delete_cookie("session")
    return {"status": "OK"}

# ── Health / Root ─────────────────────────────────────────────────────────────

# ── Topings ───────────────────────────────────────────────────────────────────

@app.get("/api/topings")
async def get_topings(conn: asyncpg.Connection = Depends(get_db)):
    rows = await conn.fetch("SELECT id_toping, nombre, activo FROM topings ORDER BY nombre")
    return [dict(r) for r in rows]

class TopingCreate(BaseModel):
    nombre: str

@app.post("/api/topings")
async def crear_toping(data: TopingCreate, conn: asyncpg.Connection = Depends(get_db)):
    try:
        row = await conn.fetchrow(
            "INSERT INTO topings (nombre) VALUES ($1) RETURNING id_toping, nombre",
            data.nombre.strip()
        )
        return dict(row)
    except asyncpg.UniqueViolationError:
        raise HTTPException(status_code=409, detail=f"Ya existe un toping con el nombre '{data.nombre.strip()}'")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/topings/{id_toping}")
async def eliminar_toping(id_toping: int, conn: asyncpg.Connection = Depends(get_db)):
    await conn.execute("UPDATE topings SET activo = false WHERE id_toping = $1", id_toping)
    return {"status": "OK"}

@app.put("/api/topings/{id_toping}/activar")
async def activar_toping(id_toping: int, conn: asyncpg.Connection = Depends(get_db)):
    await conn.execute("UPDATE topings SET activo = true WHERE id_toping = $1", id_toping)
    return {"status": "OK"}

# ── Producción con topings ────────────────────────────────────────────────────

@app.get("/api/produccion/{fecha}/topings")
async def get_produccion_topings(fecha: date, conn: asyncpg.Connection = Depends(get_db)):
    """Detalle de topings por producto para una fecha de producción."""
    rows = await conn.fetch("""
        SELECT dp.tipo_pan, dp.producto,
               COALESCE(dp.toping, 'Sin toping') AS toping,
               SUM(dp.cantidad * COALESCE(pr.paquete_cantidad, 1)) AS total_unidades,
               c.nombre_negocio AS cliente
        FROM detalle_pedidos dp
        JOIN pedidos p ON p.id_pedido = dp.id_pedido
        JOIN clientes c ON c.id_cliente = p.id_cliente
        LEFT JOIN productos pr ON pr.nombre = dp.producto
        WHERE p.fecha_produccion_requerida = $1
          AND p.estado IN ('confirmado','entregado')
        GROUP BY dp.tipo_pan, dp.producto, dp.toping, c.nombre_negocio
        ORDER BY dp.tipo_pan, dp.producto, toping
    """, fecha)
    return [dict(r) for r in rows]

# ── Backup ────────────────────────────────────────────────────────────────────

@app.get("/api/backup")
async def descargar_backup():
    db_host = os.getenv("DB_HOST", "postgres")
    db_port = os.getenv("DB_PORT", "5432")
    db_name = os.getenv("DB_NAME", "panificadora")
    db_user = os.getenv("DB_USER", "panif_user")
    db_pass = os.getenv("DB_PASSWORD", "")
    env = os.environ.copy()
    env["PGPASSWORD"] = db_pass
    with tempfile.NamedTemporaryFile(suffix=".sql", delete=False) as f:
        tmp = f.name
    try:
        proc = await asyncio.create_subprocess_exec(
            "pg_dump", "-h", db_host, "-p", db_port, "-U", db_user, "-F", "p", "-f", tmp, db_name,
            env=env, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await proc.communicate()
        if proc.returncode != 0:
            raise HTTPException(status_code=500, detail=f"Error en pg_dump: {stderr.decode()}")
        fecha_str = datetime.now().strftime("%Y%m%d_%H%M")
        return FileResponse(tmp, media_type="application/sql",
                            filename=f"backup_panificadora_{fecha_str}.sql",
                            background=BackgroundTask(os.unlink, tmp))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ── Health / Root ─────────────────────────────────────────────────────────────

@app.get("/health")
async def health_check():
    return {"status": "OK"}

@app.get("/")
async def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.get("/dashboard")
async def dashboard(request: Request):
    token = request.cookies.get("session")
    if not token:
        return RedirectResponse(url="/", status_code=302)
    expiry = _sessions.get(token)
    if not expiry or datetime.utcnow() > expiry:
        _sessions.pop(token, None)
        return RedirectResponse(url="/", status_code=302)
    return templates.TemplateResponse("index.html", {"request": request, "js_version": _JS_VERSION})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
