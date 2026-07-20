-- ============================================================
-- MIGRACIÓN 2: tipos_masa + recetas_masa — lote 2
-- BRIOCHE, BRIOCHE_LM, HOJALDRADA, CROISSANTS, CROISSANTS_SEMI,
-- AFRECHO_MANT_MIEL
-- Aplicar: psql -U panif_user -d panificadora -f migration_recetas_masa_2.sql
-- ============================================================

-- ── 1. Crear tipos_masa nuevos ────────────────────────────────────────────────

INSERT INTO tipos_masa (tipo_masa, peso_masa_g, descripcion) VALUES
  ('BRIOCHE',          2092, 'Masa Brioche'),
  ('BRIOCHE_LM',       2100, 'Masa Brioche Larga Maduración'),
  ('HOJALDRADA',       2145, 'Masa Hojaldrada'),
  ('CROISSANTS',       2408, 'Masa Croissant'),
  ('CROISSANTS_SEMI',  2343, 'Masa Croissant Semi'),
  ('AFRECHO_MANT_MIEL',2490, 'Masa Afrecho Mantequilla y Miel')
ON CONFLICT (tipo_masa) DO UPDATE SET
  peso_masa_g = EXCLUDED.peso_masa_g,
  descripcion = EXCLUDED.descripcion;

-- ── 2. Limpiar recetas existentes ─────────────────────────────────────────────

DELETE FROM recetas_masa WHERE tipo_masa IN (
  'BRIOCHE','BRIOCHE_LM','HOJALDRADA',
  'CROISSANTS','CROISSANTS_SEMI','AFRECHO_MANT_MIEL'
);

-- ── 3. MASA BRIOCHE  (batch total: 2092 g) ───────────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('BRIOCHE','HARINA',              0.4780, 'kg'),
  ('BRIOCHE','AZUCAR',              0.0717, 'kg'),
  ('BRIOCHE','SAL',                 0.0096, 'kg'),
  ('BRIOCHE','CONSERVANTE',         0.0014, 'kg'),
  ('BRIOCHE','MARGARINA',           0.0478, 'kg'),
  ('BRIOCHE','MANTEQUILLA_ING',     0.0191, 'kg'),
  ('BRIOCHE','HUEVO',               0.0717, 'kg'),
  ('BRIOCHE','ESENCIA MANTEQUILLA', 0.0048, 'kg'),
  ('BRIOCHE','LEVADURA',            0.0129, 'kg'),
  ('BRIOCHE','LECHE',               0.0096, 'kg'),
  ('BRIOCHE','HIELO',               0.1004, 'kg'),
  ('BRIOCHE','AGUA',                0.1673, 'kg'),
  ('BRIOCHE','EMULSIPAN',           0.0010, 'kg'),
  ('BRIOCHE','S-500',               0.0048, 'kg');

-- ── 4. MASA BRIOCHE LM  (batch total: 2100 g) ────────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('BRIOCHE_LM','HARINA',              0.4762, 'kg'),
  ('BRIOCHE_LM','AZUCAR',              0.0714, 'kg'),
  ('BRIOCHE_LM','SAL',                 0.0095, 'kg'),
  ('BRIOCHE_LM','CONSERVANTE',         0.0029, 'kg'),
  ('BRIOCHE_LM','MARGARINA',           0.0476, 'kg'),
  ('BRIOCHE_LM','MANTEQUILLA_ING',     0.0190, 'kg'),
  ('BRIOCHE_LM','HUEVO',               0.0714, 'kg'),
  ('BRIOCHE_LM','ESENCIA MANTEQUILLA', 0.0048, 'kg'),
  ('BRIOCHE_LM','LEVADURA',            0.0129, 'kg'),
  ('BRIOCHE_LM','LECHE',               0.0095, 'kg'),
  ('BRIOCHE_LM','HIELO',               0.1000, 'kg'),
  ('BRIOCHE_LM','AGUA',                0.1667, 'kg'),
  ('BRIOCHE_LM','EMULSIPAN',           0.0010, 'kg'),
  ('BRIOCHE_LM','S-500',               0.0071, 'kg');

-- ── 5. HOJALDRES → HOJALDRADA  (batch total: 2145 g) ────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('HOJALDRADA','HARINA',             0.4662, 'kg'),
  ('HOJALDRADA','AZUCAR',             0.0093, 'kg'),
  ('HOJALDRADA','SAL',                0.0047, 'kg'),
  ('HOJALDRADA','CONSERVANTE',        0.0014, 'kg'),
  ('HOJALDRADA','MARGARINA',          0.0932, 'kg'),
  ('HOJALDRADA','AGUA',               0.2378, 'kg'),
  ('HOJALDRADA','EMULSIPAN',          0.0009, 'kg'),
  ('HOJALDRADA','EMPASTE MANTEQUILLA',0.1865, 'kg');

-- ── 6. MASA CROISSANT → CROISSANTS  (batch total: 2408 g) ───────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('CROISSANTS','HARINA',              0.4152, 'kg'),
  ('CROISSANTS','AZUCAR',              0.0374, 'kg'),
  ('CROISSANTS','SAL',                 0.0062, 'kg'),
  ('CROISSANTS','CONSERVANTE',         0.0012, 'kg'),
  ('CROISSANTS','MANTECA',             0.0166, 'kg'),
  ('CROISSANTS','MARGARINA',           0.0166, 'kg'),
  ('CROISSANTS','HUEVO',               0.0208, 'kg'),
  ('CROISSANTS','ESENCIA MANTEQUILLA', 0.0010, 'kg'),
  ('CROISSANTS','ESENCIA NATA',        0.0010, 'kg'),
  ('CROISSANTS','LEVADURA',            0.0021, 'kg'),
  ('CROISSANTS','HIELO',               0.1038, 'kg'),
  ('CROISSANTS','AGUA',                0.2077, 'kg'),
  ('CROISSANTS','EMULSIPAN',           0.0042, 'kg'),
  ('CROISSANTS','EMPASTE MANTEQUILLA', 0.1661, 'kg');

-- ── 7. MASA CROISSANT SEMI → CROISSANTS_SEMI  (batch total: 2342.5 g) ────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('CROISSANTS_SEMI','HARINA',              0.4269, 'kg'),
  ('CROISSANTS_SEMI','AZUCAR',              0.0384, 'kg'),
  ('CROISSANTS_SEMI','SAL',                 0.0064, 'kg'),
  ('CROISSANTS_SEMI','CONSERVANTE',         0.0013, 'kg'),
  ('CROISSANTS_SEMI','MANTECA',             0.0171, 'kg'),
  ('CROISSANTS_SEMI','MARGARINA',           0.0341, 'kg'),
  ('CROISSANTS_SEMI','HUEVO',               0.0213, 'kg'),
  ('CROISSANTS_SEMI','ESENCIA MANTEQUILLA', 0.0011, 'kg'),
  ('CROISSANTS_SEMI','ESENCIA NATA',        0.0021, 'kg'),
  ('CROISSANTS_SEMI','LEVADURA',            0.0021, 'kg'),
  ('CROISSANTS_SEMI','HIELO',               0.1067, 'kg'),
  ('CROISSANTS_SEMI','AGUA',                0.2135, 'kg'),
  ('CROISSANTS_SEMI','EMULSIPAN',           0.0009, 'kg'),
  ('CROISSANTS_SEMI','EMPASTE MARGARINA',   0.1281, 'kg');

-- ── 8. MASA AFRECHO MANTEQUILLA Y MIEL  (batch total: 2490 g) ────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('AFRECHO_MANT_MIEL','HARINA',          0.4016, 'kg'),
  ('AFRECHO_MANT_MIEL','AZUCAR',          0.0201, 'kg'),
  ('AFRECHO_MANT_MIEL','SAL',             0.0100, 'kg'),
  ('AFRECHO_MANT_MIEL','CONSERVANTE',     0.0012, 'kg'),
  ('AFRECHO_MANT_MIEL','MANTEQUILLA_ING', 0.0402, 'kg'),
  ('AFRECHO_MANT_MIEL','HUEVO',           0.0803, 'kg'),
  ('AFRECHO_MANT_MIEL','LEVADURA',        0.0040, 'kg'),
  ('AFRECHO_MANT_MIEL','LECHE',           0.0080, 'kg'),
  ('AFRECHO_MANT_MIEL','MIEL',            0.0402, 'kg'),
  ('AFRECHO_MANT_MIEL','AFRECHO',         0.0803, 'kg'),
  ('AFRECHO_MANT_MIEL','HIELO',           0.1044, 'kg'),
  ('AFRECHO_MANT_MIEL','AGUA',            0.2088, 'kg'),
  ('AFRECHO_MANT_MIEL','EMULSIPAN',       0.0008, 'kg');

-- ── Verificación final ────────────────────────────────────────────────────────
SELECT tipo_masa, COUNT(*) AS ingredientes
FROM recetas_masa
GROUP BY tipo_masa
ORDER BY tipo_masa;
