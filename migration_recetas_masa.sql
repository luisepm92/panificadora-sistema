-- ============================================================
-- MIGRACIÓN: tipos_masa + recetas_masa completas
-- Fuente: recetas entregadas por Luis (jun 2026)
-- Aplicar: psql -U panif_user -d panificadora -f migration_recetas_masa.sql
-- ============================================================
-- Los valores de cantidad_por_kg_masa = ingrediente_g / total_batch_g
-- (kg de ingrediente por kg de masa producida)
-- ============================================================

-- ── 1. Crear tipos_masa que no existen ────────────────────────────────────────

INSERT INTO tipos_masa (tipo_masa, peso_masa_g, descripcion) VALUES
  ('BASICA',        2169, 'Masa Básica'),
  ('BASICA_LM',     2184, 'Masa Básica Larga Maduración'),
  ('FRANCESA',      2195, 'Masa Francesa'),
  ('ESTANDAR',      2065, 'Masa Estándar'),
  ('SOBADA',        2039, 'Masa Sobada para Hamburguesa'),
  ('SOBADA_PE',     2023, 'Masa Sobada para Perro Caliente'),
  ('SOBADA_PA',     1993, 'Masa Sobada para Pan / Panini'),
  ('ABRIOCHADA',    2164, 'Masa Abriochada'),
  ('PAPA',          2096, 'Masa de Papa'),
  ('PAPA_LM',       2113, 'Masa de Papa Larga Maduración'),
  ('BATATA',        2291, 'Masa de Batata'),
  ('BATATA_LM',     2308, 'Masa de Batata Larga Maduración'),
  ('MANTEQUILLA',   2073, 'Masa de Mantequilla'),
  ('MANTEQUILLA_LM',2089, 'Masa de Mantequilla Larga Maduración')
ON CONFLICT (tipo_masa) DO UPDATE SET
  peso_masa_g = EXCLUDED.peso_masa_g,
  descripcion = EXCLUDED.descripcion;

-- ── 2. Limpiar recetas existentes (se reemplazan todas) ──────────────────────

DELETE FROM recetas_masa WHERE tipo_masa IN (
  'BASICA','BASICA_LM','FRANCESA','ESTANDAR',
  'SOBADA','SOBADA_PE','SOBADA_PA',
  'ABRIOCHADA',
  'PAPA','PAPA_LM',
  'BATATA','BATATA_LM',
  'MANTEQUILLA','MANTEQUILLA_LM'
);

-- ── 3. MASA BÁSICA  (batch total: 2169 g) ────────────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('BASICA','HARINA',           0.4610, 'kg'),
  ('BASICA','AZUCAR',           0.0277, 'kg'),
  ('BASICA','SAL',              0.0092, 'kg'),
  ('BASICA','CONSERVANTE',      0.0028, 'kg'),
  ('BASICA','MANTECA',          0.0138, 'kg'),
  ('BASICA','MARGARINA',        0.0277, 'kg'),
  ('BASICA','HUEVO',            0.0231, 'kg'),
  ('BASICA','ESENCIA VAINILLA', 0.0046, 'kg'),
  ('BASICA','LEVADURA',         0.0028, 'kg'),
  ('BASICA','HIELO',            0.1268, 'kg'),
  ('BASICA','AGUA',             0.2535, 'kg'),
  ('BASICA','PIE',              0.0461, 'kg'),
  ('BASICA','EMULSIPAN',        0.0009, 'kg');

-- ── 4. MASA BÁSICA LM  (batch total: 2184 g) ─────────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('BASICA_LM','HARINA',           0.4579, 'kg'),
  ('BASICA_LM','AZUCAR',           0.0275, 'kg'),
  ('BASICA_LM','SAL',              0.0092, 'kg'),
  ('BASICA_LM','CONSERVANTE',      0.0037, 'kg'),
  ('BASICA_LM','MANTECA',          0.0137, 'kg'),
  ('BASICA_LM','MARGARINA',        0.0275, 'kg'),
  ('BASICA_LM','HUEVO',            0.0229, 'kg'),
  ('BASICA_LM','ESENCIA VAINILLA', 0.0046, 'kg'),
  ('BASICA_LM','LEVADURA',         0.0027, 'kg'),
  ('BASICA_LM','HIELO',            0.1259, 'kg'),
  ('BASICA_LM','AGUA',             0.2518, 'kg'),
  ('BASICA_LM','PIE',              0.0458, 'kg'),
  ('BASICA_LM','S-500',            0.0069, 'kg');

-- ── 5. MASA FRANCESA  (batch total: 2195 g) ──────────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('FRANCESA','HARINA',              0.4557, 'kg'),
  ('FRANCESA','AZUCAR',              0.0364, 'kg'),
  ('FRANCESA','SAL',                 0.0091, 'kg'),
  ('FRANCESA','CONSERVANTE',         0.0014, 'kg'),
  ('FRANCESA','MANTECA',             0.0547, 'kg'),
  ('FRANCESA','ESENCIA MANTEQUILLA', 0.0023, 'kg'),
  ('FRANCESA','LEVADURA',            0.0023, 'kg'),
  ('FRANCESA','HIELO',               0.1640, 'kg'),
  ('FRANCESA','AGUA',                0.2733, 'kg'),
  ('FRANCESA','EMULSIPAN',           0.0009, 'kg');

-- ── 6. MASA ESTÁNDAR  (batch total: 2065 g) ──────────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('ESTANDAR','HARINA',           0.4842, 'kg'),
  ('ESTANDAR','AZUCAR',           0.0387, 'kg'),
  ('ESTANDAR','SAL',              0.0073, 'kg'),
  ('ESTANDAR','CONSERVANTE',      0.0015, 'kg'),
  ('ESTANDAR','MANTECA',          0.0339, 'kg'),
  ('ESTANDAR','ESENCIA VAINILLA', 0.0024, 'kg'),
  ('ESTANDAR','LEVADURA',         0.0024, 'kg'),
  ('ESTANDAR','HIELO',            0.1428, 'kg'),
  ('ESTANDAR','AGUA',             0.2857, 'kg'),
  ('ESTANDAR','EMULSIPAN',        0.0010, 'kg');

-- ── 7. MASA SOBADA HB → tipo: SOBADA  (batch total: 2039 g) ──────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('SOBADA','HARINA',           0.4904, 'kg'),
  ('SOBADA','AZUCAR',           0.0441, 'kg'),
  ('SOBADA','SAL',              0.0074, 'kg'),
  ('SOBADA','CONSERVANTE',      0.0015, 'kg'),
  ('SOBADA','MANTECA',          0.0294, 'kg'),
  ('SOBADA','ESENCIA VAINILLA', 0.0039, 'kg'),
  ('SOBADA','LEVADURA',         0.0029, 'kg'),
  ('SOBADA','HIELO',            0.1398, 'kg'),
  ('SOBADA','AGUA',             0.2796, 'kg'),
  ('SOBADA','EMULSIPAN',        0.0010, 'kg');

-- ── 8. MASA SOBADA PE → tipo: SOBADA_PE  (batch total: 2023 g) ───────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('SOBADA_PE','HARINA',           0.4943, 'kg'),
  ('SOBADA_PE','AZUCAR',           0.0445, 'kg'),
  ('SOBADA_PE','SAL',              0.0074, 'kg'),
  ('SOBADA_PE','CONSERVANTE',      0.0015, 'kg'),
  ('SOBADA_PE','MANTECA',          0.0297, 'kg'),
  ('SOBADA_PE','ESENCIA VAINILLA', 0.0040, 'kg'),
  ('SOBADA_PE','LEVADURA',         0.0025, 'kg'),
  ('SOBADA_PE','HIELO',            0.1384, 'kg'),
  ('SOBADA_PE','AGUA',             0.2769, 'kg'),
  ('SOBADA_PE','EMULSIPAN',        0.0010, 'kg');

-- ── 9. MASA SOBADA PA → tipo: SOBADA_PA  (batch total: 1993 g) ───────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('SOBADA_PA','HARINA',           0.5018, 'kg'),
  ('SOBADA_PA','AZUCAR',           0.0251, 'kg'),
  ('SOBADA_PA','SAL',              0.0075, 'kg'),
  ('SOBADA_PA','CONSERVANTE',      0.0015, 'kg'),
  ('SOBADA_PA','MANTECA',          0.0301, 'kg'),
  ('SOBADA_PA','ESENCIA VAINILLA', 0.0015, 'kg'),
  ('SOBADA_PA','LEVADURA',         0.1003, 'kg'),
  ('SOBADA_PA','HIELO',            0.1405, 'kg'),
  ('SOBADA_PA','AGUA',             0.2810, 'kg'),
  ('SOBADA_PA','EMULSIPAN',        0.0010, 'kg');

-- ── 10. MASA ABRIOCHADA  (batch total: 2163.5 g) ─────────────────────────────
-- EMULSIPAN = 2g (base) | EMULSIPAN 1 = 20g (refuerzo)

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('ABRIOCHADA','HARINA',              0.4622, 'kg'),
  ('ABRIOCHADA','AZUCAR',              0.0416, 'kg'),
  ('ABRIOCHADA','SAL',                 0.0069, 'kg'),
  ('ABRIOCHADA','CONSERVANTE',         0.0014, 'kg'),
  ('ABRIOCHADA','MANTECA',             0.0185, 'kg'),
  ('ABRIOCHADA','MARGARINA',           0.0370, 'kg'),
  ('ABRIOCHADA','HUEVO',               0.0231, 'kg'),
  ('ABRIOCHADA','ESENCIA MANTEQUILLA', 0.0012, 'kg'),
  ('ABRIOCHADA','ESENCIA NATA',        0.0023, 'kg'),
  ('ABRIOCHADA','LEVADURA',            0.0037, 'kg'),
  ('ABRIOCHADA','HIELO',               0.1470, 'kg'),
  ('ABRIOCHADA','AGUA',                0.2450, 'kg'),
  ('ABRIOCHADA','EMULSIPAN',           0.0009, 'kg'),
  ('ABRIOCHADA','EMULSIPAN 1',         0.0092, 'kg');

-- ── 11. MASA DE PAPA  (batch total: 2096 g) ──────────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('PAPA','HARINA',              0.4771, 'kg'),
  ('PAPA','AZUCAR',              0.0429, 'kg'),
  ('PAPA','SAL',                 0.0119, 'kg'),
  ('PAPA','CONSERVANTE',         0.0029, 'kg'),
  ('PAPA','MANTECA',             0.0167, 'kg'),
  ('PAPA','MARGARINA',           0.0334, 'kg'),
  ('PAPA','HUEVO',               0.0716, 'kg'),
  ('PAPA','ESENCIA MANTEQUILLA', 0.0048, 'kg'),
  ('PAPA','LEVADURA',            0.0014, 'kg'),
  ('PAPA','PURE DE PAPA',        0.2863, 'kg'),
  ('PAPA','AGUA',                0.0501, 'kg'),
  ('PAPA','EMULSIPAN',           0.0010, 'kg');

-- ── 12. MASA DE PAPA LM  (batch total: 2113 g) ───────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('PAPA_LM','HARINA',              0.4733, 'kg'),
  ('PAPA_LM','AZUCAR',              0.0426, 'kg'),
  ('PAPA_LM','SAL',                 0.0118, 'kg'),
  ('PAPA_LM','CONSERVANTE',         0.0047, 'kg'),
  ('PAPA_LM','MANTECA',             0.0166, 'kg'),
  ('PAPA_LM','MARGARINA',           0.0331, 'kg'),
  ('PAPA_LM','HUEVO',               0.0710, 'kg'),
  ('PAPA_LM','ESENCIA MANTEQUILLA', 0.0047, 'kg'),
  ('PAPA_LM','LEVADURA',            0.0014, 'kg'),
  ('PAPA_LM','PURE DE PAPA',        0.2840, 'kg'),
  ('PAPA_LM','AGUA',                0.0497, 'kg'),
  ('PAPA_LM','S-500',               0.0071, 'kg');

-- ── 13. MASA DE BATATA  (batch total: 2291 g) ────────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('BATATA','HARINA',       0.4365, 'kg'),
  ('BATATA','AZUCAR',       0.0306, 'kg'),
  ('BATATA','SAL',          0.0087, 'kg'),
  ('BATATA','CONSERVANTE',  0.0026, 'kg'),
  ('BATATA','MANTECA',      0.0153, 'kg'),
  ('BATATA','MARGARINA',    0.0306, 'kg'),
  ('BATATA','HUEVO',        0.0655, 'kg'),
  ('BATATA','ESENCIA NATA', 0.0044, 'kg'),
  ('BATATA','LEVADURA',     0.0013, 'kg'),
  ('BATATA','PURE DE BATATA',0.3580,'kg'),
  ('BATATA','AGUA',         0.0458, 'kg'),
  ('BATATA','EMULSIPAN',    0.0009, 'kg');

-- ── 14. MASA DE BATATA LM  (batch total: 2308 g) ─────────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('BATATA_LM','HARINA',        0.4332, 'kg'),
  ('BATATA_LM','AZUCAR',        0.0303, 'kg'),
  ('BATATA_LM','SAL',           0.0087, 'kg'),
  ('BATATA_LM','CONSERVANTE',   0.0043, 'kg'),
  ('BATATA_LM','MANTECA',       0.0152, 'kg'),
  ('BATATA_LM','MARGARINA',     0.0303, 'kg'),
  ('BATATA_LM','HUEVO',         0.0650, 'kg'),
  ('BATATA_LM','ESENCIA NATA',  0.0043, 'kg'),
  ('BATATA_LM','LEVADURA',      0.0013, 'kg'),
  ('BATATA_LM','PURE DE BATATA',0.3552, 'kg'),
  ('BATATA_LM','AGUA',          0.0455, 'kg'),
  ('BATATA_LM','S-500',         0.0065, 'kg');

-- ── 15. MASA DE MANTEQUILLA  (batch total: 2073.3 g) ─────────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('MANTEQUILLA','HARINA',              0.4823, 'kg'),
  ('MANTEQUILLA','AZUCAR',              0.0289, 'kg'),
  ('MANTEQUILLA','SAL',                 0.0096, 'kg'),
  ('MANTEQUILLA','CONSERVANTE',         0.0014, 'kg'),
  ('MANTEQUILLA','MANTEQUILLA_ING',     0.0772, 'kg'),
  ('MANTEQUILLA','HUEVO',               0.0723, 'kg'),
  ('MANTEQUILLA','ESENCIA MANTEQUILLA', 0.0058, 'kg'),
  ('MANTEQUILLA','LEVADURA',            0.0029, 'kg'),
  ('MANTEQUILLA','LECHE',               0.0096, 'kg'),
  ('MANTEQUILLA','COLOR AMARILLO',      0.0001, 'kg'),
  ('MANTEQUILLA','HIELO',               0.1158, 'kg'),
  ('MANTEQUILLA','AGUA',                0.1930, 'kg'),
  ('MANTEQUILLA','EMULSIPAN',           0.0010, 'kg');

-- ── 16. MASA DE MANTEQUILLA LM  (batch total: 2089.3 g) ──────────────────────

INSERT INTO recetas_masa (tipo_masa, ingrediente, cantidad_por_kg_masa, unidad) VALUES
  ('MANTEQUILLA_LM','HARINA',              0.4786, 'kg'),
  ('MANTEQUILLA_LM','AZUCAR',              0.0287, 'kg'),
  ('MANTEQUILLA_LM','SAL',                 0.0096, 'kg'),
  ('MANTEQUILLA_LM','CONSERVANTE',         0.0029, 'kg'),
  ('MANTEQUILLA_LM','MANTEQUILLA_ING',     0.0766, 'kg'),
  ('MANTEQUILLA_LM','HUEVO',               0.0718, 'kg'),
  ('MANTEQUILLA_LM','ESENCIA MANTEQUILLA', 0.0057, 'kg'),
  ('MANTEQUILLA_LM','LEVADURA',            0.0029, 'kg'),
  ('MANTEQUILLA_LM','LECHE',               0.0096, 'kg'),
  ('MANTEQUILLA_LM','COLOR AMARILLO',      0.0001, 'kg'),
  ('MANTEQUILLA_LM','HIELO',               0.1149, 'kg'),
  ('MANTEQUILLA_LM','AGUA',                0.1915, 'kg'),
  ('MANTEQUILLA_LM','S-500',               0.0072, 'kg');

-- ── Verificación ──────────────────────────────────────────────────────────────
SELECT tipo_masa, COUNT(*) AS ingredientes
FROM recetas_masa
GROUP BY tipo_masa
ORDER BY tipo_masa;
