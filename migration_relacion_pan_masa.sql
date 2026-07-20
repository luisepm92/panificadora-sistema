-- ============================================================
-- MIGRACIÓN: relacion_pan_masa + vista_ingredientes_por_fecha
-- Aplica en psql: \i migration_relacion_pan_masa.sql
-- ============================================================

-- 1. Cambiar PK de tipo_pan solo → composite (tipo_pan, tipo_masa)
ALTER TABLE relacion_pan_masa DROP CONSTRAINT relacion_pan_masa_pkey;
ALTER TABLE relacion_pan_masa ADD PRIMARY KEY (tipo_pan, tipo_masa);

-- 2. Limpiar los 3 registros anteriores e insertar las 40+ combinaciones
DELETE FROM relacion_pan_masa;

INSERT INTO relacion_pan_masa (tipo_pan, tipo_masa) VALUES
-- HAMBURGUESA (8)
('HAMBURGUESA', 'BASICA'),
('HAMBURGUESA', 'ESTANDAR'),
('HAMBURGUESA', 'SOBADA'),
('HAMBURGUESA', 'ABRIOCHADA'),
('HAMBURGUESA', 'PAPA'),
('HAMBURGUESA', 'BATATA'),
('HAMBURGUESA', 'MANTEQUILLA'),
('HAMBURGUESA', 'BRIOCHE'),
-- PERRO (5)
('PERRO', 'BASICA'),
('PERRO', 'SOBADA'),
('PERRO', 'PAPA'),
('PERRO', 'BATATA'),
('PERRO', 'BRIOCHE'),
-- PANINIS (3)
('PANINIS', 'FRANCESA'),
('PANINIS', 'SOBADA'),
('PANINIS', 'BRIOCHE'),
-- CHORIPAN (4)
('CHORIPAN', 'FRANCESA'),
('CHORIPAN', 'SOBADA'),
('CHORIPAN', 'BRIOCHE'),
('CHORIPAN', 'PAPA'),
-- SANDWICH (6)
('SANDWICH', 'BASICA'),
('SANDWICH', 'INTEGRAL'),
('SANDWICH', 'PREMIUM'),
('SANDWICH', 'PAPA'),
('SANDWICH', 'BATATA'),
('SANDWICH', 'BRIOCHE'),
-- Panes únicos (7)
('CROISSANT',  'HOJALDRADA'),
('PALMERITAS', 'HOJALDRADA'),
('CANILLA',    'FRANCESA'),
('SUB',        'FRANCESA'),
('PAN_QUESO',  'MANTEQUILLA'),
('BANQUETE',   'SOBADA'),
('HALLOWEEN',  'SOBADA');

-- 3. Recrear vista_ingredientes_por_fecha usando productos.tipo_masa
--    (evita inflación de ingredientes cuando un pan tiene múltiples masas posibles)
DROP VIEW IF EXISTS vista_ingredientes_por_fecha;
CREATE VIEW vista_ingredientes_por_fecha AS
SELECT
    p.fecha_produccion_requerida,
    r.ingrediente,
    SUM(dp.cantidad * dp.peso_g / 1000.0 * r.cantidad_por_kg_masa) AS cantidad_total,
    r.unidad
FROM pedidos p
JOIN detalle_pedidos dp ON dp.id_pedido = p.id_pedido
JOIN productos prod     ON prod.nombre   = dp.producto
                       AND prod.tipo_pan = dp.tipo_pan
JOIN recetas_masa r     ON r.tipo_masa   = prod.tipo_masa
WHERE p.estado = 'confirmado'
  AND p.fecha_produccion_requerida IS NOT NULL
  AND prod.tipo_masa IS NOT NULL
GROUP BY p.fecha_produccion_requerida, r.ingrediente, r.unidad
ORDER BY p.fecha_produccion_requerida, r.ingrediente;
