-- ============================================================
-- SCRIPT SQL COMPLETO - SISTEMA PANIFICADORA
-- PostgreSQL 15
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE rol_usuario        AS ENUM ('DUENO', 'EMPLEADO');
CREATE TYPE estado_usuario     AS ENUM ('activo', 'inactivo');
CREATE TYPE categoria_cliente  AS ENUM ('restaurante', 'cafeteria', 'market', 'otro');
CREATE TYPE estado_cliente     AS ENUM ('activo', 'inactivo', 'bloqueado');
CREATE TYPE estado_pedido      AS ENUM ('pendiente', 'confirmado', 'entregado', 'cancelado');
CREATE TYPE tipo_unidad        AS ENUM ('unidad', 'paquete');
CREATE TYPE estado_deuda       AS ENUM ('pendiente', 'pagado', 'parcial');
CREATE TYPE metodo_pago        AS ENUM ('efectivo', 'transferencia', 'otro');
CREATE TYPE estado_produccion  AS ENUM ('pendiente', 'en_proceso', 'completado');

-- ============================================================
-- TABLA 1: USUARIOS
-- ============================================================
CREATE TABLE usuarios (
    id_usuario     SERIAL PRIMARY KEY,
    telegram_id    VARCHAR(100) UNIQUE NOT NULL,
    nombre         VARCHAR(200) NOT NULL,
    rol            rol_usuario DEFAULT 'EMPLEADO',
    estado         estado_usuario DEFAULT 'activo',
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso  TIMESTAMP
);

INSERT INTO usuarios (telegram_id, nombre, rol)
VALUES ('@luisepm92', 'Luis (Dueno)', 'DUENO');

-- ============================================================
-- TABLA 2: CLIENTES B2B
-- ============================================================
CREATE TABLE clientes (
    id_cliente         SERIAL PRIMARY KEY,
    telegram_id        VARCHAR(100) UNIQUE,
    nombre_negocio     VARCHAR(200) NOT NULL,
    telefono           VARCHAR(50),
    direccion          TEXT,
    contacto_principal VARCHAR(200),
    categoria          categoria_cliente DEFAULT 'otro',
    estado             estado_cliente DEFAULT 'activo',
    fecha_registro     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_clientes_estado ON clientes(estado);
CREATE INDEX idx_clientes_nombre ON clientes(nombre_negocio);

INSERT INTO clientes (nombre_negocio, categoria) VALUES
('911',                        'restaurante'),
('A Y V COMIDA CHINA',         'restaurante'),
('AHUMADITOS',                 'restaurante'),
('AHUMADOS GRILL',             'restaurante'),
('ANTOJOS BELENSATE',          'restaurante'),
('BE FIT',                     'cafeteria'),
('BOCADOS CONGELADOS',         'otro'),
('BODEGON EL MARQUEZ',         'restaurante'),
('BON APPETIT BURGER',         'restaurante'),
('BURGER GRILL',               'restaurante'),
('BURGER HOUSE',               'restaurante'),
('CABAÑA BISTRO',              'restaurante'),
('CAZZO PIZZA',                'restaurante'),
('CESAR SANCHEZ',              'otro'),
('CHELOS BURGER',              'restaurante'),
('CHEO BURGER',                'restaurante'),
('CHINESSE',                   'restaurante'),
('COLD BREW',                  'cafeteria'),
('DAHAUS',                     'restaurante'),
('DANOVA',                     'restaurante'),
('DAVID COMBY',                'otro'),
('DISFRUPARK',                 'otro'),
('EBERT MATTIE',               'restaurante'),
('LM MARKET CC ALTO CHAMA',    'market');

-- ============================================================
-- TABLA 3: PEDIDOS
-- ============================================================
CREATE TABLE pedidos (
    id_pedido                  SERIAL PRIMARY KEY,
    id_cliente                 INTEGER NOT NULL REFERENCES clientes(id_cliente),
    numero_recibo              VARCHAR(20) UNIQUE NOT NULL,
    fecha_pedido               TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega              DATE NOT NULL,
    estado                     estado_pedido DEFAULT 'pendiente',
    monto_total                NUMERIC(10,2) DEFAULT 0,
    monto_delivery             NUMERIC(10,2) DEFAULT 0,
    aplica_iva                 BOOLEAN DEFAULT FALSE,
    archivo_pdf_url            TEXT,
    registrado_por             VARCHAR(200),
    fecha_produccion_requerida DATE,
    fecha_despacho_real        DATE,
    confirmado_por_admin       BOOLEAN DEFAULT FALSE,
    fecha_confirmacion_admin   TIMESTAMP,
    fecha_confirmacion_despacho TIMESTAMP
);

CREATE INDEX idx_pedidos_cliente    ON pedidos(id_cliente);
CREATE INDEX idx_pedidos_fecha      ON pedidos(fecha_pedido);
CREATE INDEX idx_pedidos_estado     ON pedidos(estado);
CREATE INDEX idx_pedidos_produccion ON pedidos(fecha_produccion_requerida);
CREATE INDEX idx_pedidos_despacho   ON pedidos(fecha_despacho_real);

-- ============================================================
-- TABLA 4: DETALLE DE PEDIDOS
-- ============================================================
CREATE TABLE detalle_pedidos (
    id_detalle      SERIAL PRIMARY KEY,
    id_pedido       INTEGER NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    tipo_pan        VARCHAR(100) NOT NULL,
    producto        VARCHAR(100) NOT NULL,
    peso_g          INTEGER NOT NULL,
    cantidad        INTEGER NOT NULL,
    tipo_unidad     tipo_unidad DEFAULT 'unidad',
    precio_unitario NUMERIC(10,2) NOT NULL,
    subtotal        NUMERIC(10,2) NOT NULL,
    toping          VARCHAR(100)
);

CREATE INDEX idx_detalle_pedido ON detalle_pedidos(id_pedido);

-- ============================================================
-- TABLA 5: TIPOS DE MASA (Recetas)
-- ============================================================
CREATE TABLE tipos_masa (
    tipo_masa   VARCHAR(100) PRIMARY KEY,
    peso_masa_g INTEGER NOT NULL,
    descripcion TEXT,
    activo      BOOLEAN DEFAULT TRUE
);

-- ============================================================
-- TABLA 6: RECETAS DE MASA (Ingredientes por tipo de masa)
-- ============================================================
CREATE TABLE recetas_masa (
    id_receta           SERIAL PRIMARY KEY,
    tipo_masa           VARCHAR(100) NOT NULL REFERENCES tipos_masa(tipo_masa) ON DELETE CASCADE,
    ingrediente         VARCHAR(200) NOT NULL,
    cantidad_por_kg_masa NUMERIC(10,4) NOT NULL,
    unidad              VARCHAR(20) DEFAULT 'kg',
    UNIQUE(tipo_masa, ingrediente)
);

-- ============================================================
-- TABLA 7: RELACION PAN -> MASA
-- ============================================================
CREATE TABLE relacion_pan_masa (
    tipo_pan  VARCHAR(100) PRIMARY KEY,
    tipo_masa VARCHAR(100) NOT NULL REFERENCES tipos_masa(tipo_masa)
);

-- ============================================================
-- TABLA 8: DEUDAS
-- ============================================================
CREATE TABLE deudas (
    id_deuda         SERIAL PRIMARY KEY,
    id_cliente       INTEGER NOT NULL REFERENCES clientes(id_cliente),
    id_pedido        INTEGER REFERENCES pedidos(id_pedido),
    monto_original   NUMERIC(10,2) NOT NULL,
    monto_pagado     NUMERIC(10,2) DEFAULT 0,
    saldo_pendiente  NUMERIC(10,2) GENERATED ALWAYS AS (monto_original - monto_pagado) STORED,
    estado           estado_deuda DEFAULT 'pendiente',
    fecha_creacion   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_vencimiento DATE,
    descripcion      TEXT
);

CREATE INDEX idx_deudas_cliente ON deudas(id_cliente);
CREATE INDEX idx_deudas_estado  ON deudas(estado);

-- ============================================================
-- TABLA 9: PAGOS
-- ============================================================
CREATE TABLE pagos (
    id_pago        SERIAL PRIMARY KEY,
    id_deuda       INTEGER NOT NULL REFERENCES deudas(id_deuda),
    id_cliente     INTEGER NOT NULL REFERENCES clientes(id_cliente),
    monto_pagado   NUMERIC(10,2) NOT NULL,
    fecha_pago     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metodo         metodo_pago DEFAULT 'efectivo',
    registrado_por VARCHAR(200) NOT NULL
);

-- ============================================================
-- TABLA 10: PRODUCCION DIARIA (una fila por pedido+tipo_pan)
-- ============================================================
CREATE TABLE produccion_diaria (
    id_produccion              SERIAL PRIMARY KEY,
    id_pedido                  INTEGER NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    fecha_produccion           DATE NOT NULL,
    fecha_produccion_requerida DATE NOT NULL,
    tipo_pan                   VARCHAR(100) NOT NULL,
    producto                   VARCHAR(100) NOT NULL,
    peso_g                     INTEGER NOT NULL,
    total_unidades             INTEGER NOT NULL,
    peso_total_g               NUMERIC(10,2),
    estado                     estado_produccion DEFAULT 'pendiente',
    CONSTRAINT produccion_diaria_pedido_tipo_producto_peso_key UNIQUE(id_pedido, tipo_pan, producto, peso_g)
);

CREATE INDEX idx_produccion_fecha   ON produccion_diaria(fecha_produccion_requerida);
CREATE INDEX idx_produccion_pedido  ON produccion_diaria(id_pedido);

-- ============================================================
-- VISTAS
-- ============================================================

CREATE VIEW vista_deuda_clientes AS
SELECT
    c.id_cliente,
    c.nombre_negocio,
    c.telefono,
    COALESCE(SUM(d.monto_original), 0)                            AS total_pedidos,
    COALESCE(SUM(d.monto_pagado), 0)                              AS total_pagado,
    COALESCE(SUM(d.saldo_pendiente), 0)                           AS deuda_total,
    COUNT(d.id_deuda) FILTER (WHERE d.estado != 'pagado')         AS pedidos_pendientes,
    MAX(p.fecha_pedido)                                           AS ultimo_pedido
FROM clientes c
LEFT JOIN deudas d  ON d.id_cliente = c.id_cliente
LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
WHERE c.estado = 'activo'
GROUP BY c.id_cliente, c.nombre_negocio, c.telefono
ORDER BY deuda_total DESC;

CREATE VIEW vista_top_deudores AS
SELECT nombre_negocio, deuda_total, total_pedidos, total_pagado, pedidos_pendientes
FROM vista_deuda_clientes
WHERE deuda_total > 0
ORDER BY deuda_total DESC
LIMIT 10;

CREATE VIEW vista_produccion_manana AS
SELECT
    dp.tipo_pan,
    dp.peso_g,
    SUM(dp.cantidad)                           AS total_unidades,
    SUM(dp.cantidad * dp.peso_g)               AS peso_total_g,
    STRING_AGG(DISTINCT c.nombre_negocio, ', ') AS clientes
FROM pedidos p
JOIN detalle_pedidos dp ON dp.id_pedido = p.id_pedido
JOIN clientes c         ON c.id_cliente = p.id_cliente
WHERE p.fecha_entrega = CURRENT_DATE + INTERVAL '1 day'
  AND p.estado = 'confirmado'
GROUP BY dp.tipo_pan, dp.peso_g
ORDER BY dp.tipo_pan, dp.peso_g;

CREATE VIEW vista_produccion_por_fecha AS
SELECT
    p.fecha_produccion_requerida,
    dp.tipo_pan,
    SUM(dp.cantidad)                           AS total_unidades,
    SUM(dp.cantidad * dp.peso_g)               AS peso_total_g,
    STRING_AGG(DISTINCT c.nombre_negocio, ', ') AS clientes
FROM pedidos p
JOIN detalle_pedidos dp ON dp.id_pedido = p.id_pedido
JOIN clientes c         ON c.id_cliente = p.id_cliente
WHERE p.estado = 'confirmado'
  AND p.fecha_produccion_requerida IS NOT NULL
GROUP BY p.fecha_produccion_requerida, dp.tipo_pan
ORDER BY p.fecha_produccion_requerida, dp.tipo_pan;

CREATE VIEW vista_ingredientes_por_fecha AS
SELECT
    p.fecha_produccion_requerida,
    r.ingrediente,
    SUM(dp.cantidad * dp.peso_g / 1000.0 * r.cantidad_por_kg_masa) AS cantidad_total,
    r.unidad
FROM pedidos p
JOIN detalle_pedidos dp ON dp.id_pedido = p.id_pedido
JOIN relacion_pan_masa rpm ON rpm.tipo_pan = dp.tipo_pan
JOIN recetas_masa r        ON r.tipo_masa  = rpm.tipo_masa
WHERE p.estado = 'confirmado'
  AND p.fecha_produccion_requerida IS NOT NULL
GROUP BY p.fecha_produccion_requerida, r.ingrediente, r.unidad
ORDER BY p.fecha_produccion_requerida, r.ingrediente;

-- ============================================================
-- TABLA 11: PRODUCTOS (Catálogo de productos)
-- ============================================================
CREATE TABLE productos (
    id_producto               SERIAL PRIMARY KEY,
    nombre                    VARCHAR(200) NOT NULL,
    tipo_masa                 VARCHAR(100) REFERENCES tipos_masa(tipo_masa) ON DELETE SET NULL,
    tipo_pan                  VARCHAR(100) NOT NULL,
    peso_g                    INTEGER NOT NULL,
    precio_unitario           NUMERIC(10,2) NOT NULL,
    paquete_cantidad          INTEGER,
    paquete_tipo              VARCHAR(50),
    activo                    BOOLEAN DEFAULT TRUE,
    fecha_ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_productos_tipo_masa ON productos(tipo_masa);
CREATE INDEX idx_productos_activo    ON productos(activo);

-- ============================================================
-- FUNCIONES Y TRIGGERS
-- ============================================================

-- Mantiene saldo_pendiente = monto_original - monto_pagado automáticamente
CREATE OR REPLACE FUNCTION sync_saldo_deuda()
RETURNS TRIGGER AS $$
BEGIN
    NEW.saldo_pendiente := NEW.monto_original - NEW.monto_pagado;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_saldo
BEFORE INSERT OR UPDATE ON deudas
FOR EACH ROW EXECUTE FUNCTION sync_saldo_deuda();

-- ============================================================
-- TABLA: TOPINGS
-- ============================================================
CREATE TABLE topings (
    id_toping SERIAL PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL UNIQUE,
    activo    BOOLEAN DEFAULT TRUE
);

INSERT INTO topings (nombre) VALUES
    ('Ajonjoli'), ('Queso'), ('Oregano'), ('Mantequilla'), ('Sin toping');

-- Actualiza monto_pagado y estado de la deuda al registrar un pago
CREATE OR REPLACE FUNCTION actualizar_estado_deuda()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE deudas
    SET
        monto_pagado = monto_pagado + NEW.monto_pagado,
        estado = CASE
            WHEN (monto_pagado + NEW.monto_pagado) >= monto_original THEN 'pagado'::estado_deuda
            WHEN (monto_pagado + NEW.monto_pagado) > 0               THEN 'parcial'::estado_deuda
            ELSE 'pendiente'::estado_deuda
        END
    WHERE id_deuda = NEW.id_deuda;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_deuda
AFTER INSERT ON pagos
FOR EACH ROW EXECUTE FUNCTION actualizar_estado_deuda();

-- Genera número de recibo secuencial
CREATE OR REPLACE FUNCTION generar_numero_recibo()
RETURNS VARCHAR AS $$
DECLARE
    ultimo_num INTEGER;
BEGIN
    SELECT COALESCE(MAX(CAST(numero_recibo AS INTEGER)), 2638)
    INTO ultimo_num FROM pedidos;
    RETURN CAST(ultimo_num + 1 AS VARCHAR);
END;
$$ LANGUAGE plpgsql;

-- Consolida producción diaria desde pedidos confirmados (por fecha_produccion_requerida)
CREATE OR REPLACE FUNCTION consolidar_produccion(fecha_prod DATE)
RETURNS VOID AS $$
BEGIN
    DELETE FROM produccion_diaria WHERE fecha_produccion_requerida = fecha_prod;

    INSERT INTO produccion_diaria
        (id_pedido, fecha_produccion, fecha_produccion_requerida, tipo_pan, producto, peso_g, total_unidades, peso_total_g)
    SELECT
        p.id_pedido,
        CURRENT_DATE,
        fecha_prod,
        dp.tipo_pan,
        dp.producto,
        dp.peso_g,
        SUM(dp.cantidad),
        SUM(dp.cantidad * dp.peso_g)
    FROM pedidos p
    JOIN detalle_pedidos dp ON dp.id_pedido = p.id_pedido
    WHERE p.fecha_produccion_requerida = fecha_prod
      AND p.estado = 'confirmado'
    GROUP BY p.id_pedido, dp.tipo_pan, dp.producto, dp.peso_g;
END;
$$ LANGUAGE plpgsql;
