const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType,
  ShadingType, VerticalAlign, PageNumber, PageBreak, LevelFormat
} = require('docx');
const fs = require('fs');

// ── Colores ───────────────────────────────────────────────────────────────────
const C = {
  azul:       '1F4E79',
  azulClaro:  '2E75B6',
  azulPale:   'D6E4F0',
  grisHead:   '404040',
  grisPale:   'F2F2F2',
  verde:      '1E7145',
  verdePale:  'E2EFDA',
  rojo:       'C00000',
  rojoPale:   'FCE4D6',
  amarillo:   'F4B942',
  amarilloPale:'FFF2CC',
  blanco:     'FFFFFF',
  negro:      '000000',
};

const border1 = { style: BorderStyle.SINGLE, size: 1, color: 'CCCCCC' };
const borders = { top: border1, bottom: border1, left: border1, right: border1 };
const borderNone = { style: BorderStyle.NIL, size: 0, color: 'FFFFFF' };
const bordersNone = { top: borderNone, bottom: borderNone, left: borderNone, right: borderNone };

// ── Helpers ───────────────────────────────────────────────────────────────────
const sp = (n) => new Paragraph({ children: [new TextRun('')], spacing: { before: n, after: 0 } });

function heading1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    children: [new TextRun({ text, font: 'Arial', size: 28, bold: true, color: C.azul })],
    spacing: { before: 360, after: 120 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: C.azulClaro, space: 4 } },
  });
}

function heading2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    children: [new TextRun({ text, font: 'Arial', size: 24, bold: true, color: C.azulClaro })],
    spacing: { before: 240, after: 80 },
  });
}

function heading3(text, color = C.grisHead) {
  return new Paragraph({
    children: [new TextRun({ text, font: 'Arial', size: 22, bold: true, color })],
    spacing: { before: 180, after: 60 },
  });
}

function para(text, opts = {}) {
  return new Paragraph({
    children: [new TextRun({ text, font: 'Arial', size: 20, color: C.negro, ...opts })],
    spacing: { before: 60, after: 60 },
  });
}

function cell(text, { shade, bold, center, width, small, color } = {}) {
  return new TableCell({
    borders,
    width: width ? { size: width, type: WidthType.DXA } : undefined,
    shading: shade ? { fill: shade, type: ShadingType.CLEAR } : undefined,
    margins: { top: 60, bottom: 60, left: 100, right: 100 },
    verticalAlign: VerticalAlign.CENTER,
    children: [new Paragraph({
      alignment: center ? AlignmentType.CENTER : AlignmentType.LEFT,
      children: [new TextRun({
        text: String(text ?? '—'),
        font: 'Arial',
        size: small ? 16 : 18,
        bold: !!bold,
        color: color || C.negro,
      })],
    })],
  });
}

function headerRow(labels, widths, shade = C.azul) {
  return new TableRow({
    tableHeader: true,
    children: labels.map((l, i) => cell(l, {
      shade, bold: true, width: widths[i], color: C.blanco
    })),
  });
}

// ── DATA ──────────────────────────────────────────────────────────────────────

const TABLAS = [
  {
    nombre: 'clientes',
    desc: 'Registro maestro de clientes B2B (restaurantes, cafeterías, markets). Cada cliente puede hacer múltiples pedidos. Es el punto de entrada del flujo comercial.',
    columnas: [
      { col: 'id_cliente',        tipo: 'SERIAL PK',        nulo: 'NO', desc: 'Identificador único autoincremental' },
      { col: 'telegram_id',       tipo: 'VARCHAR(100)',      nulo: 'SÍ', desc: 'ID de Telegram del cliente (UNIQUE). Permite vincular pedidos del bot' },
      { col: 'nombre_negocio',    tipo: 'VARCHAR(200)',      nulo: 'NO', desc: 'Nombre del negocio cliente' },
      { col: 'telefono',          tipo: 'VARCHAR(50)',       nulo: 'SÍ', desc: 'Teléfono de contacto' },
      { col: 'direccion',         tipo: 'TEXT',              nulo: 'SÍ', desc: 'Dirección de entrega' },
      { col: 'contacto_principal',tipo: 'VARCHAR(200)',      nulo: 'SÍ', desc: 'Nombre de la persona de contacto' },
      { col: 'categoria',         tipo: 'ENUM categoria_cliente', nulo: 'SÍ', desc: 'restaurante | cafeteria | market | otro' },
      { col: 'estado',            tipo: 'ENUM estado_cliente',    nulo: 'SÍ', desc: 'activo | inactivo | bloqueado. Default: activo' },
      { col: 'fecha_registro',    tipo: 'TIMESTAMP',         nulo: 'SÍ', desc: 'Fecha de alta del cliente' },
    ],
    obs: 'Índices: idx_clientes_estado, idx_clientes_nombre. Sin FK propias; es tabla padre de pedidos y deudas.',
  },
  {
    nombre: 'pedidos',
    desc: 'Núcleo del sistema. Registra cada pedido realizado por un cliente, ya sea desde el Bot Telegram o manualmente desde el Dashboard. Controla el ciclo de vida: pendiente → confirmado → entregado.',
    columnas: [
      { col: 'id_pedido',                   tipo: 'SERIAL PK',       nulo: 'NO', desc: 'Identificador único' },
      { col: 'id_cliente',                  tipo: 'INTEGER FK',      nulo: 'NO', desc: 'Referencia a clientes.id_cliente' },
      { col: 'numero_recibo',               tipo: 'VARCHAR(20)',     nulo: 'NO', desc: 'Número de recibo secuencial (UNIQUE). Generado por función generar_numero_recibo()' },
      { col: 'fecha_pedido',                tipo: 'TIMESTAMP',       nulo: 'SÍ', desc: 'Fecha/hora en que se registró el pedido. Default: NOW()' },
      { col: 'fecha_entrega',               tipo: 'DATE',            nulo: 'NO', desc: 'Fecha comprometida de entrega al cliente' },
      { col: 'estado',                      tipo: 'ENUM estado_pedido', nulo: 'SÍ', desc: 'pendiente | confirmado | entregado | cancelado. Default: pendiente' },
      { col: 'monto_total',                 tipo: 'NUMERIC(10,2)',   nulo: 'SÍ', desc: 'Suma total del pedido calculada desde las líneas. Default: 0' },
      { col: 'archivo_pdf_url',             tipo: 'TEXT',            nulo: 'SÍ', desc: 'URL del recibo PDF generado' },
      { col: 'observaciones',               tipo: 'TEXT',            nulo: 'SÍ', desc: 'Notas libres del pedido' },
      { col: 'registrado_por',              tipo: 'VARCHAR(200)',    nulo: 'SÍ', desc: 'Nombre del cliente (bot) o "admin_dashboard"' },
      { col: 'fecha_produccion_requerida',  tipo: 'DATE',            nulo: 'SÍ', desc: 'Fecha en que se debe producir el pan. Se asigna al confirmar' },
      { col: 'fecha_despacho_real',         tipo: 'DATE',            nulo: 'SÍ', desc: 'Fecha real de despacho. Se asigna al confirmar' },
      { col: 'confirmado_por_admin',        tipo: 'BOOLEAN',         nulo: 'SÍ', desc: 'TRUE si fue confirmado desde el Dashboard. Default: FALSE' },
      { col: 'fecha_confirmacion_admin',    tipo: 'TIMESTAMP',       nulo: 'SÍ', desc: 'Timestamp de confirmación por admin' },
      { col: 'despacho_confirmado',         tipo: 'BOOLEAN',         nulo: 'SÍ', desc: 'TRUE si el despacho fue marcado como realizado' },
      { col: 'fecha_confirmacion_despacho', tipo: 'TIMESTAMP',       nulo: 'SÍ', desc: 'Timestamp de confirmación de entrega' },
      { col: 'monto_delivery',              tipo: 'NUMERIC(10,2)',   nulo: 'SÍ', desc: 'Costo adicional de delivery. Default: 0' },
      { col: 'aplica_iva',                  tipo: 'BOOLEAN',         nulo: 'SÍ', desc: 'Indica si aplica IVA al monto. Default: FALSE' },
    ],
    obs: 'FK: id_cliente → clientes(id_cliente). Índices: idx_pedidos_cliente, idx_pedidos_estado, idx_pedidos_fecha, numero_recibo UNIQUE.',
  },
  {
    nombre: 'detalle_pedidos',
    desc: 'Líneas individuales de cada pedido. Un pedido puede tener múltiples líneas (diferentes productos/masas). Se eliminan en cascada cuando se elimina el pedido padre.',
    columnas: [
      { col: 'id_detalle',       tipo: 'SERIAL PK',           nulo: 'NO', desc: 'Identificador único de la línea' },
      { col: 'id_pedido',        tipo: 'INTEGER FK CASCADE',  nulo: 'NO', desc: 'Referencia a pedidos.id_pedido. ON DELETE CASCADE' },
      { col: 'tipo_pan',         tipo: 'VARCHAR(100)',         nulo: 'NO', desc: 'Tipo de masa almacenado (BASICA, BRIOCHE, SOBADA, etc.). El bot guarda el nombre de la masa, no el tipo de pan' },
      { col: 'producto',         tipo: 'VARCHAR(100)',         nulo: 'NO', desc: 'Nombre del producto. Ej: "BRIOCHE 70g" o nombre desde catálogo' },
      { col: 'peso_g',           tipo: 'INTEGER',             nulo: 'NO', desc: 'Peso unitario del pan en gramos' },
      { col: 'cantidad',         tipo: 'INTEGER',             nulo: 'NO', desc: 'Número de unidades pedidas' },
      { col: 'tipo_unidad',      tipo: 'ENUM tipo_unidad',    nulo: 'SÍ', desc: 'unidad | paquete. Default: unidad' },
      { col: 'precio_unitario',  tipo: 'NUMERIC(10,2)',       nulo: 'NO', desc: 'Precio por unidad al momento del pedido' },
      { col: 'subtotal',         tipo: 'NUMERIC(10,2)',       nulo: 'NO', desc: 'cantidad × precio_unitario' },
    ],
    obs: 'FK: id_pedido → pedidos(id_pedido) ON DELETE CASCADE. NOTA TÉCNICA: tipo_pan almacena el nombre del tipo de masa (no el tipo de pan físico) por convención del bot Telegram.',
  },
  {
    nombre: 'deudas',
    desc: 'Registro de deudas por pedido. Cada pedido confirmado genera automáticamente una deuda. El trigger trg_sync_saldo mantiene saldo_pendiente actualizado. Los pagos reducen monto_pagado vía trigger.',
    columnas: [
      { col: 'id_deuda',         tipo: 'SERIAL PK',      nulo: 'NO', desc: 'Identificador único' },
      { col: 'id_cliente',       tipo: 'INTEGER FK',     nulo: 'NO', desc: 'Referencia a clientes.id_cliente' },
      { col: 'id_pedido',        tipo: 'INTEGER FK',     nulo: 'NO', desc: 'Referencia a pedidos.id_pedido' },
      { col: 'monto_original',   tipo: 'NUMERIC(10,2)',  nulo: 'NO', desc: 'Monto total del pedido al momento de crear la deuda' },
      { col: 'monto_pagado',     tipo: 'NUMERIC(10,2)',  nulo: 'SÍ', desc: 'Acumulado de pagos recibidos. Default: 0' },
      { col: 'saldo_pendiente',  tipo: 'NUMERIC(10,2)',  nulo: 'SÍ', desc: 'Calculado automáticamente: monto_original - monto_pagado (via trigger trg_sync_saldo)' },
      { col: 'estado',           tipo: 'ENUM estado_deuda', nulo: 'SÍ', desc: 'pendiente | parcial | pagado. Default: pendiente' },
      { col: 'fecha_creacion',   tipo: 'TIMESTAMP',      nulo: 'SÍ', desc: 'Fecha de creación de la deuda' },
      { col: 'fecha_vencimiento',tipo: 'DATE',           nulo: 'SÍ', desc: 'Fecha límite de pago (opcional)' },
    ],
    obs: 'FK: id_cliente → clientes, id_pedido → pedidos. Índices: idx_deudas_cliente, idx_deudas_estado. La deuda se crea en el mismo transaction que el pedido (bot y dashboard).',
  },
  {
    nombre: 'pagos',
    desc: 'Registro histórico de cada pago recibido. Al insertar un pago, el trigger trg_actualizar_deuda actualiza automáticamente monto_pagado y estado en la tabla deudas.',
    columnas: [
      { col: 'id_pago',         tipo: 'SERIAL PK',        nulo: 'NO', desc: 'Identificador único del pago' },
      { col: 'id_deuda',        tipo: 'INTEGER FK',       nulo: 'NO', desc: 'Referencia a deudas.id_deuda' },
      { col: 'id_cliente',      tipo: 'INTEGER FK',       nulo: 'NO', desc: 'Referencia a clientes.id_cliente (desnormalizado para queries directas)' },
      { col: 'monto_pagado',    tipo: 'NUMERIC(10,2)',    nulo: 'NO', desc: 'Monto de este pago específico' },
      { col: 'fecha_pago',      tipo: 'TIMESTAMP',        nulo: 'SÍ', desc: 'Fecha/hora del pago. Default: NOW()' },
      { col: 'metodo',          tipo: 'ENUM metodo_pago', nulo: 'SÍ', desc: 'efectivo | transferencia | otro. Default: efectivo' },
      { col: 'registrado_por',  tipo: 'VARCHAR(200)',     nulo: 'NO', desc: 'Nombre o sistema que registró el pago' },
      { col: 'notas',           tipo: 'TEXT',             nulo: 'SÍ', desc: 'Observaciones opcionales del pago' },
    ],
    obs: 'FK: id_deuda → deudas, id_cliente → clientes. Índices: idx_pagos_cliente, idx_pagos_fecha. Tabla append-only: los pagos no se editan ni eliminan.',
  },
  {
    nombre: 'produccion_diaria',
    desc: 'Consolidado de producción por fecha. Se popula al confirmar un pedido desde el Dashboard. Cada fila representa la producción de un producto/masa en una fecha. El constraint UNIQUE en (fecha_produccion, tipo_pan, producto, peso_g) consolida pedidos del mismo día.',
    columnas: [
      { col: 'id_produccion',             tipo: 'SERIAL PK',          nulo: 'NO', desc: 'Identificador único' },
      { col: 'fecha_produccion',          tipo: 'DATE',               nulo: 'NO', desc: 'Fecha en que se programó la producción (day of confirmation)' },
      { col: 'tipo_pan',                  tipo: 'VARCHAR(100)',        nulo: 'NO', desc: 'Nombre del tipo de masa (BASICA, BRIOCHE, etc.). Se usa para join con recetas_masa' },
      { col: 'producto',                  tipo: 'VARCHAR(100)',        nulo: 'NO', desc: 'Nombre del producto (ej: "BRIOCHE 70g")' },
      { col: 'peso_g',                    tipo: 'INTEGER',             nulo: 'NO', desc: 'Peso unitario del pan en gramos' },
      { col: 'total_unidades',            tipo: 'INTEGER',             nulo: 'NO', desc: 'Total de unidades a producir. Se acumula vía ON CONFLICT DO UPDATE si hay mismo día/masa/producto/peso' },
      { col: 'peso_total_g',              tipo: 'NUMERIC(10,2)',       nulo: 'SÍ', desc: 'total_unidades × peso_g' },
      { col: 'estado',                    tipo: 'ENUM estado_produccion', nulo: 'SÍ', desc: 'pendiente | en_proceso | completado. Default: pendiente (campo no actualizado actualmente)' },
      { col: 'fecha_produccion_requerida',tipo: 'DATE',               nulo: 'SÍ', desc: 'Fecha en que el pan debe estar listo. Se usa como FK lógica para vista_ingredientes_por_fecha' },
      { col: 'cliente',                   tipo: 'VARCHAR(100)',        nulo: 'SÍ', desc: 'Nombre del cliente (desnormalizado, legado)' },
      { col: 'id_pedido',                 tipo: 'INTEGER FK',          nulo: 'SÍ', desc: 'Referencia al pedido que originó esta fila (puede no ser el único si hubo acumulación)' },
    ],
    obs: 'UNIQUE: (fecha_produccion, tipo_pan, producto, peso_g). FK: id_pedido → pedidos. La función consolidar_produccion() existe pero actualmente no se invoca; la inserción es línea por línea al confirmar.',
  },
  {
    nombre: 'tipos_masa',
    desc: 'Catálogo maestro de tipos de masa. Define los 20 tipos disponibles con su peso total de batch. Es la tabla padre de recetas_masa y productos.',
    columnas: [
      { col: 'tipo_masa',       tipo: 'VARCHAR(100) PK', nulo: 'NO', desc: 'Código del tipo de masa (ej: BASICA, BRIOCHE_LM, SOBADA_PE). PK natural' },
      { col: 'peso_masa_g',     tipo: 'INTEGER',         nulo: 'NO', desc: 'Peso total del batch de masa en gramos (suma de todos los ingredientes)' },
      { col: 'descripcion',     tipo: 'TEXT',            nulo: 'SÍ', desc: 'Nombre descriptivo del tipo de masa' },
      { col: 'activo',          tipo: 'BOOLEAN',         nulo: 'SÍ', desc: 'Indica si el tipo de masa está en uso. Default: TRUE' },
      { col: 'fecha_creacion',  tipo: 'TIMESTAMP',       nulo: 'SÍ', desc: 'Fecha de registro' },
    ],
    obs: '20 tipos registrados: BASICA, BASICA_LM, FRANCESA, ESTANDAR, SOBADA, SOBADA_PE, SOBADA_PA, ABRIOCHADA, BRIOCHE, BRIOCHE_LM, PAPA, PAPA_LM, BATATA, BATATA_LM, MANTEQUILLA, MANTEQUILLA_LM, HOJALDRADA, CROISSANTS, CROISSANTS_SEMI, AFRECHO_MANT_MIEL.',
  },
  {
    nombre: 'recetas_masa',
    desc: 'Recetas detalladas por tipo de masa. Cada fila define qué cantidad de un ingrediente se necesita por kg de masa producida. Actualmente tiene 246 ingredientes distribuidos en 20 tipos de masa.',
    columnas: [
      { col: 'id_receta',            tipo: 'SERIAL PK',       nulo: 'NO', desc: 'Identificador único' },
      { col: 'tipo_masa',            tipo: 'VARCHAR(100) FK', nulo: 'NO', desc: 'Referencia a tipos_masa.tipo_masa' },
      { col: 'ingrediente',          tipo: 'VARCHAR(100)',    nulo: 'NO', desc: 'Nombre del ingrediente (HARINA, AZUCAR, LEVADURA, etc.)' },
      { col: 'cantidad_por_kg_masa', tipo: 'NUMERIC(10,4)',   nulo: 'NO', desc: 'Cantidad del ingrediente por kg de masa producida. Calculada como: ingrediente_g / batch_total_g' },
      { col: 'unidad',               tipo: 'VARCHAR(20)',     nulo: 'SÍ', desc: 'Unidad de la cantidad (kg). Default: kg' },
    ],
    obs: 'UNIQUE: (tipo_masa, ingrediente). FK: tipo_masa → tipos_masa ON DELETE CASCADE. La vista vista_ingredientes_por_fecha usa esta tabla para calcular requerimientos de compras.',
  },
  {
    nombre: 'productos',
    desc: 'Catálogo de productos del Bot Telegram. Define cada variante de pan disponible para pedido (tipo_masa + tipo_pan + peso). El Dashboard y el Bot consultan esta tabla para mostrar opciones.',
    columnas: [
      { col: 'id_producto',               tipo: 'SERIAL PK',       nulo: 'NO', desc: 'Identificador único' },
      { col: 'nombre',                    tipo: 'VARCHAR(200)',    nulo: 'NO', desc: 'Nombre completo del producto (UNIQUE). Ej: "Pan Básico Hamburguesa de 55g"' },
      { col: 'tipo_masa',                 tipo: 'VARCHAR(50) FK',  nulo: 'NO', desc: 'Referencia a tipos_masa.tipo_masa' },
      { col: 'tipo_pan',                  tipo: 'VARCHAR(100)',    nulo: 'NO', desc: 'Categoría de pan físico: HAMBURGUESA, PERRO, FRANCESA, CHORIPAN, etc.' },
      { col: 'peso_g',                    tipo: 'INTEGER',         nulo: 'SÍ', desc: 'Peso unitario en gramos' },
      { col: 'precio_unitario',           tipo: 'NUMERIC(10,2)',   nulo: 'NO', desc: 'Precio por unidad o paquete' },
      { col: 'paquete_cantidad',          tipo: 'INTEGER',         nulo: 'SÍ', desc: 'Unidades por paquete (si tipo_unidad = paquete)' },
      { col: 'paquete_tipo',              tipo: 'VARCHAR(50)',     nulo: 'SÍ', desc: 'Descripción del paquete (ej: "bolsa de 10")' },
      { col: 'descripcion',               tipo: 'TEXT',            nulo: 'SÍ', desc: 'Descripción adicional del producto' },
      { col: 'activo',                    tipo: 'BOOLEAN',         nulo: 'SÍ', desc: 'Producto visible para pedidos. Default: TRUE' },
      { col: 'fecha_creacion',            tipo: 'TIMESTAMP',       nulo: 'SÍ', desc: 'Fecha de alta del producto' },
      { col: 'fecha_ultima_modificacion', tipo: 'TIMESTAMP',       nulo: 'SÍ', desc: 'Última modificación del producto' },
    ],
    obs: 'UNIQUE: nombre. FK: tipo_masa → tipos_masa ON DELETE SET NULL. Índices: idx_productos_tipo_masa, idx_productos_activo.',
  },
  {
    nombre: 'relacion_pan_masa',
    desc: 'Tabla de referencia que mapea tipos de pan físico (HAMBURGUESA, PERRO) a tipos de masa compatibles. Actualmente con PK en tipo_pan (relación 1:1). Pendiente de expansión a N:M para soportar múltiples masas por tipo de pan.',
    columnas: [
      { col: 'tipo_pan',       tipo: 'VARCHAR(100) PK',  nulo: 'NO', desc: 'Tipo de pan físico (HAMBURGUESA, PERRO, PANINIS, etc.)' },
      { col: 'tipo_masa',      tipo: 'VARCHAR(100) FK',  nulo: 'NO', desc: 'Referencia a tipos_masa.tipo_masa' },
      { col: 'fecha_creacion', tipo: 'TIMESTAMP',        nulo: 'SÍ', desc: 'Fecha de creación del registro' },
    ],
    obs: 'FK: tipo_masa → tipos_masa. NOTA: La vista_ingredientes_por_fecha NO usa esta tabla (usa produccion_diaria.tipo_pan directamente sobre recetas_masa). Esta tabla está subutilizada en el flujo actual.',
  },
  {
    nombre: 'usuarios',
    desc: 'Administradores con acceso al Bot Telegram Admin. Controla quién puede usar el bot de administración. Distinto de usuarios_dashboard (acceso web).',
    columnas: [
      { col: 'id_usuario',      tipo: 'SERIAL PK',       nulo: 'NO', desc: 'Identificador único' },
      { col: 'telegram_id',     tipo: 'VARCHAR(100)',    nulo: 'NO', desc: 'ID de Telegram (UNIQUE). Formato: @username' },
      { col: 'nombre',          tipo: 'VARCHAR(200)',    nulo: 'NO', desc: 'Nombre del administrador' },
      { col: 'rol',             tipo: 'ENUM rol_usuario',nulo: 'SÍ', desc: 'DUENO | EMPLEADO. Default: EMPLEADO' },
      { col: 'estado',          tipo: 'ENUM estado_usuario', nulo: 'SÍ', desc: 'activo | inactivo. Default: activo' },
      { col: 'fecha_registro',  tipo: 'TIMESTAMP',       nulo: 'SÍ', desc: 'Fecha de registro' },
      { col: 'ultimo_acceso',   tipo: 'TIMESTAMP',       nulo: 'SÍ', desc: 'Último acceso al bot (campo no actualizado actualmente — pendiente implementar)' },
    ],
    obs: 'UNIQUE: telegram_id. Sin FK externas. El decorador @solo_admin del bot valida contra esta tabla antes de cada operación.',
  },
  {
    nombre: 'usuarios_dashboard',
    desc: 'Usuarios con acceso al Dashboard web. Autenticación independiente del bot Telegram. Contraseñas hasheadas.',
    columnas: [
      { col: 'id',             tipo: 'SERIAL PK',   nulo: 'NO', desc: 'Identificador único' },
      { col: 'usuario',        tipo: 'VARCHAR(50)', nulo: 'NO', desc: 'Nombre de usuario (UNIQUE)' },
      { col: 'contraseña',     tipo: 'VARCHAR(255)',nulo: 'NO', desc: 'Hash de la contraseña' },
      { col: 'nombre',         tipo: 'VARCHAR(100)',nulo: 'SÍ', desc: 'Nombre completo del usuario' },
      { col: 'fecha_creacion', tipo: 'TIMESTAMP',   nulo: 'SÍ', desc: 'Fecha de creación de la cuenta' },
    ],
    obs: 'Sin FK externas. Tabla de acceso al sistema web únicamente.',
  },
];

const VISTAS = [
  {
    nombre: 'vista_deuda_clientes',
    desc: 'Vista principal del módulo de deudas. Consolida por cliente: total pedido, total pagado, deuda actual, pedidos pendientes y fecha del último pedido. Usada en el Dashboard (sección Deudas) y Bot Admin.',
    join: 'clientes LEFT JOIN deudas LEFT JOIN pedidos',
    filtro: 'clientes.estado = activo',
    columnas: 'id_cliente, nombre_negocio, telefono, total_pedidos, total_pagado, deuda_total, pedidos_pendientes, ultimo_pedido',
  },
  {
    nombre: 'vista_top_deudores',
    desc: 'Top 10 clientes con mayor deuda pendiente. Deriva de vista_deuda_clientes.',
    join: 'vista_deuda_clientes (derivada)',
    filtro: 'deuda_total > 0, LIMIT 10',
    columnas: 'nombre_negocio, deuda_total, total_pedidos, total_pagado, pedidos_pendientes',
  },
  {
    nombre: 'vista_produccion_manana',
    desc: 'Producción requerida para mañana. Agrega todas las líneas de pedidos CONFIRMADOS con fecha_entrega = hoy + 1 día.',
    join: 'pedidos JOIN detalle_pedidos JOIN clientes',
    filtro: 'p.fecha_entrega = CURRENT_DATE + 1 AND p.estado = confirmado',
    columnas: 'tipo_pan, producto, peso_g, total_unidades, peso_total_g, clientes',
  },
  {
    nombre: 'vista_produccion_por_fecha',
    desc: 'Producción agrupada por fecha y tipo de masa desde produccion_diaria.',
    join: 'produccion_diaria',
    filtro: 'Sin filtro de estado (incluye todos los registros)',
    columnas: 'fecha_produccion_requerida, tipo_pan, total_unidades, clientes',
  },
  {
    nombre: 'vista_ingredientes_por_fecha',
    desc: 'Vista crítica para compras/producción. Calcula los kg de cada ingrediente necesarios por fecha, cruzando produccion_diaria con recetas_masa. Fórmula: total_unidades × (peso_g / 1000) × cantidad_por_kg_masa.',
    join: 'produccion_diaria JOIN recetas_masa ON recetas_masa.tipo_masa = produccion_diaria.tipo_pan',
    filtro: 'fecha_produccion_requerida IS NOT NULL',
    columnas: 'fecha_produccion_requerida, ingrediente, cantidad_total (kg), unidad',
  },
];

const FLUJOS = [
  {
    titulo: '1. Pedido desde Bot Telegram (Cliente)',
    pasos: [
      'Cliente inicia conversación → bot verifica telegram_id en tabla clientes',
      'Bot presenta menú de masas (TIPOS_PAN) y pesos. El cliente selecciona tipo de masa y peso',
      'Bot crea item: tipo_pan = nombre masa normalizado (ej: BASICA), producto = "{masa} {peso}g"',
      'Al confirmar: INSERT INTO pedidos (estado=pendiente) + INSERT INTO detalle_pedidos (una fila por línea) + INSERT INTO deudas (monto_original = monto_total)',
      'Bot genera PDF del recibo y lo envía al cliente vía Telegram',
    ],
  },
  {
    titulo: '2. Pedido desde Dashboard (Admin)',
    pasos: [
      'Admin usa el modal wizard: selecciona cliente → masa/producto → cantidad → confirma carrito',
      'POST /api/pedidos/crear-manual → INSERT pedidos + detalle_pedidos + deudas en una sola transacción',
      'El pedido queda en estado PENDIENTE visible en la sección Pedidos del Dashboard',
    ],
  },
  {
    titulo: '3. Confirmación de Pedido (Admin)',
    pasos: [
      'Admin hace click en "Confirmar" en el Dashboard → modal solicita fecha_produccion y fecha_despacho',
      'POST /api/pedidos/{id}/confirmar → valida que estado = pendiente (409 si ya confirmado)',
      'UPDATE pedidos: estado=confirmado, fecha_produccion_requerida, fecha_despacho_real, confirmado_por_admin=TRUE',
      'INSERT INTO produccion_diaria por cada línea del detalle. ON CONFLICT acumula unidades si mismo día/masa/producto/peso',
    ],
  },
  {
    titulo: '4. Gestión de Producción',
    pasos: [
      'Dashboard → Producción → Tab "Por Pan": muestra detalle por cliente con filtros y agrupación por masa o cliente',
      'Tab "Ingredientes" → Tabla 1A: panes a producir con masa y unidades. Tabla 1B: masas agrupadas con botón "Ver detalles"',
      'Modal de ingredientes: calcula kg de cada ingrediente usando vista_ingredientes_por_fecha',
    ],
  },
  {
    titulo: '5. Despacho y Entrega',
    pasos: [
      'Dashboard → Despachos: muestra pedidos CONFIRMADOS con fecha de despacho',
      'Admin hace click en "✅ Entregar" → POST /api/pedidos/{id}/entregar → estado=entregado',
    ],
  },
  {
    titulo: '6. Cobro y Pagos',
    pasos: [
      'Dashboard → Deudas: muestra resumen por cliente desde vista_deuda_clientes',
      'Click "💳 Pagos" → modal con deudas pendientes/parciales del cliente',
      'Admin selecciona deuda y registra monto + método → POST /api/pagos → INSERT INTO pagos',
      'Trigger trg_actualizar_deuda: UPDATE deudas SET monto_pagado += monto, estado = pendiente|parcial|pagado',
      'Trigger trg_sync_saldo: UPDATE saldo_pendiente = monto_original - monto_pagado (BEFORE INSERT/UPDATE)',
      'Bot Admin: misma funcionalidad vía conversación Telegram (/admin → Deudas → Buscar cliente → Pagar)',
    ],
  },
];

// ── BUILD DOCUMENT ────────────────────────────────────────────────────────────

const children = [];

// ── PORTADA ──
children.push(
  new Paragraph({ spacing: { before: 1440, after: 0 }, children: [new TextRun('')] }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: 'SISTEMA PANIFICADORA', font: 'Arial', size: 56, bold: true, color: C.azul })],
    spacing: { before: 0, after: 120 },
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: 'Reporte de Estructura de Base de Datos', font: 'Arial', size: 32, color: C.azulClaro })],
    spacing: { before: 0, after: 480 },
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: C.azulClaro, space: 4 } },
    children: [new TextRun({ text: '', font: 'Arial', size: 20 })],
    spacing: { before: 0, after: 240 },
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: 'PostgreSQL 15  ·  Motor: asyncpg  ·  ORM: SQL nativo', font: 'Arial', size: 22, color: C.grisHead })],
    spacing: { before: 0, after: 120 },
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: `Generado: ${new Date().toLocaleDateString('es-VE', { year:'numeric', month:'long', day:'numeric' })}`, font: 'Arial', size: 20, color: C.grisHead })],
    spacing: { before: 0, after: 1440 },
  }),
  new Paragraph({ children: [new PageBreak()] })
);

// ── RESUMEN EJECUTIVO ──
children.push(heading1('1. Resumen Ejecutivo'));
children.push(para('Esta base de datos soporta el Sistema de Gestión de Panificadora, una aplicación B2B que integra un Bot Telegram para clientes, un Bot Admin para administradores, y un Dashboard web para operaciones del negocio.'));

// Tabla resumen
children.push(sp(120));
children.push(new Table({
  width: { size: 9360, type: WidthType.DXA },
  columnWidths: [3200, 3080, 3080],
  rows: [
    new TableRow({ tableHeader: true, children: [
      cell('Categoría', { shade: C.azul, bold: true, color: C.blanco, width: 3200 }),
      cell('Detalle', { shade: C.azul, bold: true, color: C.blanco, width: 3080 }),
      cell('Cantidad', { shade: C.azul, bold: true, color: C.blanco, center: true, width: 3080 }),
    ]}),
    new TableRow({ children: [
      cell('Tablas de negocio', { shade: C.azulPale, bold: true, width: 3200 }),
      cell('clientes, pedidos, detalle_pedidos, deudas, pagos, produccion_diaria, productos, tipos_masa, recetas_masa, relacion_pan_masa, usuarios, usuarios_dashboard', { width: 3080, small: true }),
      cell('12', { center: true, bold: true, width: 3080 }),
    ]}),
    new TableRow({ children: [
      cell('Tablas de sistema', { shade: C.grisPale, width: 3200 }),
      cell('n8n (automatización), OAuth, workflows (62 tablas internas)', { width: 3080, small: true }),
      cell('62', { center: true, width: 3080 }),
    ]}),
    new TableRow({ children: [
      cell('Vistas SQL', { shade: C.azulPale, bold: true, width: 3200 }),
      cell('5 vistas para reportes y cálculos', { width: 3080, small: true }),
      cell('5', { center: true, bold: true, width: 3080 }),
    ]}),
    new TableRow({ children: [
      cell('Tipos ENUM', { shade: C.grisPale, width: 3200 }),
      cell('9 enums de dominio', { width: 3080, small: true }),
      cell('9', { center: true, width: 3080 }),
    ]}),
    new TableRow({ children: [
      cell('Funciones', { shade: C.azulPale, bold: true, width: 3200 }),
      cell('3 funciones de negocio + triggers asociados', { width: 3080, small: true }),
      cell('3', { center: true, bold: true, width: 3080 }),
    ]}),
    new TableRow({ children: [
      cell('Triggers activos', { shade: C.grisPale, width: 3200 }),
      cell('trg_sync_saldo + trg_actualizar_deuda', { width: 3080, small: true }),
      cell('2', { center: true, width: 3080 }),
    ]}),
    new TableRow({ children: [
      cell('Tipos de masa con receta', { shade: C.azulPale, bold: true, width: 3200 }),
      cell('20 tipos, 246 ingredientes registrados', { width: 3080, small: true }),
      cell('20 / 246', { center: true, bold: true, width: 3080 }),
    ]}),
  ],
}));

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── TIPOS ENUM ──
children.push(heading1('2. Tipos de Datos Personalizados (ENUM)'));
children.push(para('PostgreSQL utiliza tipos ENUM para garantizar integridad de dominio en columnas de estado y clasificación. Los valores son estrictos: solo se pueden insertar los definidos.'));
children.push(sp(120));

const ENUMS = [
  { tipo: 'estado_pedido',     valores: 'pendiente | confirmado | entregado | cancelado', uso: 'pedidos.estado — controla el ciclo de vida del pedido' },
  { tipo: 'estado_deuda',      valores: 'pendiente | parcial | pagado',                   uso: 'deudas.estado — estado financiero de cada deuda' },
  { tipo: 'metodo_pago',       valores: 'efectivo | transferencia | otro',                uso: 'pagos.metodo — método usado en cada pago' },
  { tipo: 'estado_produccion', valores: 'pendiente | en_proceso | completado',            uso: 'produccion_diaria.estado — estado del lote de producción (sin actualizar actualmente)' },
  { tipo: 'categoria_cliente', valores: 'restaurante | cafeteria | market | otro',        uso: 'clientes.categoria — tipo de negocio del cliente' },
  { tipo: 'estado_cliente',    valores: 'activo | inactivo | bloqueado',                  uso: 'clientes.estado — estado del cliente' },
  { tipo: 'rol_usuario',       valores: 'DUENO | EMPLEADO',                               uso: 'usuarios.rol — nivel de acceso en el bot admin' },
  { tipo: 'estado_usuario',    valores: 'activo | inactivo',                              uso: 'usuarios.estado' },
  { tipo: 'tipo_unidad',       valores: 'unidad | paquete',                               uso: 'detalle_pedidos.tipo_unidad — si el precio es por unidad o paquete' },
];

children.push(new Table({
  width: { size: 9360, type: WidthType.DXA },
  columnWidths: [2400, 3200, 3760],
  rows: [
    new TableRow({ tableHeader: true, children: [
      cell('Tipo ENUM', { shade: C.azulClaro, bold: true, color: C.blanco, width: 2400 }),
      cell('Valores permitidos', { shade: C.azulClaro, bold: true, color: C.blanco, width: 3200 }),
      cell('Uso en el sistema', { shade: C.azulClaro, bold: true, color: C.blanco, width: 3760 }),
    ]}),
    ...ENUMS.map((e, i) => new TableRow({ children: [
      cell(e.tipo, { shade: i%2===0 ? C.grisPale : C.blanco, bold: true, small: true, width: 2400 }),
      cell(e.valores, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, width: 3200 }),
      cell(e.uso, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, width: 3760 }),
    ]})),
  ],
}));

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── TABLAS ──
children.push(heading1('3. Estructura de Tablas'));

TABLAS.forEach((t, ti) => {
  if (ti > 0 && ti % 2 === 0) children.push(new Paragraph({ children: [new PageBreak()] }));

  children.push(heading2(`3.${ti+1}  ${t.nombre.toUpperCase()}`));
  children.push(para(t.desc));

  children.push(new Table({
    width: { size: 9360, type: WidthType.DXA },
    columnWidths: [2100, 1700, 600, 4960],
    rows: [
      new TableRow({ tableHeader: true, children: [
        cell('Columna', { shade: C.azul, bold: true, color: C.blanco, width: 2100 }),
        cell('Tipo / Constraint', { shade: C.azul, bold: true, color: C.blanco, width: 1700 }),
        cell('NULL', { shade: C.azul, bold: true, color: C.blanco, center: true, width: 600 }),
        cell('Descripción', { shade: C.azul, bold: true, color: C.blanco, width: 4960 }),
      ]}),
      ...t.columnas.map((c, ci) => new TableRow({ children: [
        cell(c.col, { shade: ci%2===0 ? C.azulPale : C.blanco, bold: true, small: true, width: 2100 }),
        cell(c.tipo, { shade: ci%2===0 ? C.azulPale : C.blanco, small: true, width: 1700 }),
        cell(c.nulo === 'NO' ? 'NO' : '', { shade: ci%2===0 ? C.azulPale : C.blanco, center: true, small: true, color: c.nulo==='NO' ? C.rojo : C.verde, width: 600 }),
        cell(c.desc, { shade: ci%2===0 ? C.azulPale : C.blanco, small: true, width: 4960 }),
      ]})),
    ],
  }));

  children.push(new Paragraph({
    children: [
      new TextRun({ text: '⚑  ', font: 'Arial', size: 17, color: C.azulClaro }),
      new TextRun({ text: t.obs, font: 'Arial', size: 17, color: C.grisHead, italics: true }),
    ],
    spacing: { before: 80, after: 80 },
    indent: { left: 200 },
  }));

  children.push(sp(160));
});

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── RELACIONES FK ──
children.push(heading1('4. Mapa de Relaciones (Foreign Keys)'));
children.push(para('Las siguientes claves foráneas definen las relaciones entre tablas de negocio. La columna "ON DELETE" indica el comportamiento al eliminar el registro padre.'));
children.push(sp(120));

children.push(new Table({
  width: { size: 9360, type: WidthType.DXA },
  columnWidths: [2200, 1600, 2200, 1800, 1560],
  rows: [
    new TableRow({ tableHeader: true, children: [
      cell('Tabla Hija', { shade: C.azul, bold: true, color: C.blanco, width: 2200 }),
      cell('Columna FK', { shade: C.azul, bold: true, color: C.blanco, width: 1600 }),
      cell('Tabla Padre', { shade: C.azul, bold: true, color: C.blanco, width: 2200 }),
      cell('Columna PK', { shade: C.azul, bold: true, color: C.blanco, width: 1800 }),
      cell('ON DELETE', { shade: C.azul, bold: true, color: C.blanco, center: true, width: 1560 }),
    ]}),
    ...[
      ['pedidos',          'id_cliente',  'clientes',   'id_cliente',  'NO ACTION'],
      ['detalle_pedidos',  'id_pedido',   'pedidos',    'id_pedido',   'CASCADE ⚠'],
      ['deudas',           'id_cliente',  'clientes',   'id_cliente',  'NO ACTION'],
      ['deudas',           'id_pedido',   'pedidos',    'id_pedido',   'NO ACTION'],
      ['pagos',            'id_deuda',    'deudas',     'id_deuda',    'NO ACTION'],
      ['pagos',            'id_cliente',  'clientes',   'id_cliente',  'NO ACTION'],
      ['produccion_diaria','id_pedido',   'pedidos',    'id_pedido',   'NO ACTION'],
      ['productos',        'tipo_masa',   'tipos_masa', 'tipo_masa',   'SET NULL'],
      ['recetas_masa',     'tipo_masa',   'tipos_masa', 'tipo_masa',   'CASCADE'],
      ['relacion_pan_masa','tipo_masa',   'tipos_masa', 'tipo_masa',   'NO ACTION'],
    ].map(([th, fk, tp, pk, del_], i) => new TableRow({ children: [
      cell(th, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, bold: true, width: 2200 }),
      cell(fk, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, width: 1600 }),
      cell(tp, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, width: 2200 }),
      cell(pk, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, width: 1800 }),
      cell(del_, { shade: del_.includes('CASCADE') ? C.amarilloPale : (i%2===0 ? C.grisPale : C.blanco), small: true, center: true, bold: del_.includes('CASCADE'), width: 1560 }),
    ]})),
  ],
}));

children.push(sp(120));
children.push(new Paragraph({
  children: [new TextRun({ text: '⚠  Nota: detalle_pedidos tiene ON DELETE CASCADE desde pedidos — al eliminar un pedido se eliminan todas sus líneas automáticamente. Las deudas y registros de produccion_diaria NO se eliminan en cascada; deben gestionarse explícitamente en el código (el endpoint DELETE /api/pedidos lo hace dentro de una transacción).', font: 'Arial', size: 17, color: C.rojo, italics: true })],
  indent: { left: 200 },
  spacing: { before: 80, after: 80 },
}));

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── VISTAS ──
children.push(heading1('5. Vistas SQL'));
children.push(para('Las vistas encapsulan lógica de consulta compleja. No almacenan datos; se recalculan en cada consulta. Son la capa de reporting del sistema.'));

VISTAS.forEach(v => {
  children.push(heading2(v.nombre));
  children.push(para(v.desc));
  children.push(new Table({
    width: { size: 9360, type: WidthType.DXA },
    columnWidths: [2000, 7360],
    rows: [
      new TableRow({ children: [
        cell('Tablas base', { shade: C.grisPale, bold: true, width: 2000 }),
        cell(v.join, { width: 7360, small: true }),
      ]}),
      new TableRow({ children: [
        cell('Filtros', { shade: C.grisPale, bold: true, width: 2000 }),
        cell(v.filtro, { width: 7360, small: true }),
      ]}),
      new TableRow({ children: [
        cell('Columnas', { shade: C.grisPale, bold: true, width: 2000 }),
        cell(v.columnas, { width: 7360, small: true }),
      ]}),
    ],
  }));
  children.push(sp(120));
});

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── FUNCIONES Y TRIGGERS ──
children.push(heading1('6. Funciones y Triggers'));

children.push(heading2('6.1  Funciones de Negocio'));
const FUNCS = [
  { nombre: 'generar_numero_recibo()', desc: 'Genera el siguiente número de recibo secuencial. Consulta el MAX del campo numero_recibo en pedidos, le suma 1 y lo retorna como VARCHAR. Base inicial: 2638.', uso: 'Llamada al crear un pedido (bot y dashboard). No usa SEQUENCE para mantener continuidad con registros históricos.' },
  { nombre: 'actualizar_estado_deuda()', desc: 'Función del trigger trg_actualizar_deuda. Al insertar en pagos, suma monto_pagado a la deuda correspondiente y actualiza el estado: si monto_pagado >= monto_original → pagado; si monto_pagado > 0 → parcial; sino → pendiente.', uso: 'TRIGGER AFTER INSERT ON pagos.' },
  { nombre: 'consolidar_produccion(fecha_prod DATE)', desc: 'Función utilitaria que elimina y reconstruye las filas de produccion_diaria para una fecha específica, consultando todos los pedidos confirmados de esa fecha.', uso: 'PENDIENTE: existe en BD pero no es invocada actualmente. La inserción en produccion_diaria se hace línea por línea al confirmar cada pedido desde el Dashboard.' },
];

FUNCS.forEach(f => {
  children.push(heading3(`▸  ${f.nombre}`, C.azulClaro));
  children.push(para(f.desc));
  children.push(new Paragraph({
    children: [new TextRun({ text: `Uso: ${f.uso}`, font: 'Arial', size: 17, italics: true, color: C.grisHead })],
    indent: { left: 200 },
    spacing: { before: 40, after: 100 },
  }));
});

children.push(heading2('6.2  Triggers Activos'));
children.push(new Table({
  width: { size: 9360, type: WidthType.DXA },
  columnWidths: [2400, 1600, 1200, 1600, 2560],
  rows: [
    new TableRow({ tableHeader: true, children: [
      cell('Trigger', { shade: C.azul, bold: true, color: C.blanco, width: 2400 }),
      cell('Tabla', { shade: C.azul, bold: true, color: C.blanco, width: 1600 }),
      cell('Evento', { shade: C.azul, bold: true, color: C.blanco, width: 1200 }),
      cell('Momento', { shade: C.azul, bold: true, color: C.blanco, width: 1600 }),
      cell('Acción', { shade: C.azul, bold: true, color: C.blanco, width: 2560 }),
    ]}),
    new TableRow({ children: [
      cell('trg_sync_saldo', { shade: C.grisPale, bold: true, small: true, width: 2400 }),
      cell('deudas', { shade: C.grisPale, small: true, width: 1600 }),
      cell('INSERT / UPDATE', { shade: C.grisPale, small: true, center: true, width: 1200 }),
      cell('BEFORE', { shade: C.grisPale, small: true, center: true, width: 1600 }),
      cell('Calcula NEW.saldo_pendiente = monto_original - monto_pagado antes de cada escritura', { shade: C.grisPale, small: true, width: 2560 }),
    ]}),
    new TableRow({ children: [
      cell('trg_actualizar_deuda', { bold: true, small: true, width: 2400 }),
      cell('pagos', { small: true, width: 1600 }),
      cell('INSERT', { small: true, center: true, width: 1200 }),
      cell('AFTER', { small: true, center: true, width: 1600 }),
      cell('Incrementa monto_pagado en deudas y recalcula estado (pendiente/parcial/pagado)', { small: true, width: 2560 }),
    ]}),
  ],
}));

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── ÍNDICES ──
children.push(heading1('7. Índices'));
children.push(para('Los índices optimizan las consultas más frecuentes del sistema. Se agrupan por tabla a continuación.'));
children.push(sp(100));

children.push(new Table({
  width: { size: 9360, type: WidthType.DXA },
  columnWidths: [2200, 2800, 1200, 3160],
  rows: [
    new TableRow({ tableHeader: true, children: [
      cell('Tabla', { shade: C.azul, bold: true, color: C.blanco, width: 2200 }),
      cell('Índice', { shade: C.azul, bold: true, color: C.blanco, width: 2800 }),
      cell('Tipo', { shade: C.azul, bold: true, color: C.blanco, center: true, width: 1200 }),
      cell('Columna(s)', { shade: C.azul, bold: true, color: C.blanco, width: 3160 }),
    ]}),
    ...[
      ['clientes',          'clientes_pkey',                   'UNIQUE',    'id_cliente'],
      ['clientes',          'clientes_telegram_id_key',        'UNIQUE',    'telegram_id'],
      ['clientes',          'idx_clientes_estado',             'btree',     'estado'],
      ['clientes',          'idx_clientes_nombre',             'btree',     'nombre_negocio'],
      ['detalle_pedidos',   'detalle_pedidos_pkey',            'UNIQUE',    'id_detalle'],
      ['detalle_pedidos',   'idx_detalle_pedido',              'btree',     'id_pedido'],
      ['deudas',            'deudas_pkey',                     'UNIQUE',    'id_deuda'],
      ['deudas',            'idx_deudas_cliente',              'btree',     'id_cliente'],
      ['deudas',            'idx_deudas_estado',               'btree',     'estado'],
      ['pagos',             'pagos_pkey',                      'UNIQUE',    'id_pago'],
      ['pagos',             'idx_pagos_cliente',               'btree',     'id_cliente'],
      ['pagos',             'idx_pagos_fecha',                 'btree',     'fecha_pago'],
      ['pedidos',           'pedidos_pkey',                    'UNIQUE',    'id_pedido'],
      ['pedidos',           'pedidos_numero_recibo_key',       'UNIQUE',    'numero_recibo'],
      ['pedidos',           'idx_pedidos_cliente',             'btree',     'id_cliente'],
      ['pedidos',           'idx_pedidos_estado',              'btree',     'estado'],
      ['pedidos',           'idx_pedidos_fecha',               'btree',     'fecha_pedido'],
      ['produccion_diaria', 'produccion_diaria_pkey',          'UNIQUE',    'id_produccion'],
      ['produccion_diaria', 'UNIQUE fecha+tipo+prod+peso',     'UNIQUE',    '(fecha_produccion, tipo_pan, producto, peso_g)'],
      ['produccion_diaria', 'idx_produccion_fecha',            'btree',     'fecha_produccion'],
      ['productos',         'productos_pkey',                  'UNIQUE',    'id_producto'],
      ['productos',         'productos_nombre_key',            'UNIQUE',    'nombre'],
      ['recetas_masa',      'recetas_masa_pkey',               'UNIQUE',    'id_receta'],
      ['recetas_masa',      'recetas_masa_tipo_masa_ing_key',  'UNIQUE',    '(tipo_masa, ingrediente)'],
      ['tipos_masa',        'tipos_masa_pkey',                 'UNIQUE',    'tipo_masa'],
      ['usuarios',          'usuarios_pkey',                   'UNIQUE',    'id_usuario'],
      ['usuarios',          'usuarios_telegram_id_key',        'UNIQUE',    'telegram_id'],
    ].map(([tab, idx, tipo, cols], i) => new TableRow({ children: [
      cell(tab, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, bold: true, width: 2200 }),
      cell(idx, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, width: 2800 }),
      cell(tipo, { shade: tipo==='UNIQUE' ? C.amarilloPale : (i%2===0 ? C.grisPale : C.blanco), small: true, center: true, bold: tipo==='UNIQUE', width: 1200 }),
      cell(cols, { shade: i%2===0 ? C.grisPale : C.blanco, small: true, width: 3160 }),
    ]})),
  ],
}));

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── FLUJOS ──
children.push(heading1('8. Flujos del Sistema'));
children.push(para('Descripción de los 6 flujos principales del sistema, desde el pedido hasta el cobro, con las tablas involucradas en cada etapa.'));

FLUJOS.forEach(f => {
  children.push(heading2(f.titulo));
  f.pasos.forEach((p, i) => {
    children.push(new Paragraph({
      numbering: { reference: 'steps', level: 0 },
      children: [new TextRun({ text: p, font: 'Arial', size: 19 })],
    }));
  });
  children.push(sp(80));
});

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── OBSERVACIONES DBA ──
children.push(heading1('9. Observaciones y Recomendaciones del DBA'));

const OBS = [
  { tipo: '⚠ PENDIENTE', color: C.rojo, shade: C.rojoPale,
    titulo: 'Campo ultimo_acceso en usuarios no se actualiza',
    desc: 'El campo usuarios.ultimo_acceso existe pero el bot admin nunca lo actualiza al autenticarse. Recomendación: agregar UPDATE usuarios SET ultimo_acceso = NOW() en el decorador @solo_admin.' },
  { tipo: '⚠ PENDIENTE', color: C.rojo, shade: C.rojoPale,
    titulo: 'consolidar_produccion() no se usa',
    desc: 'La función existe en la BD pero no es invocada. Actualmente la inserción en produccion_diaria se hace línea por línea al confirmar cada pedido. Evaluar si es necesaria o documentar que está deprecada.' },
  { tipo: '⚠ PENDIENTE', color: C.rojo, shade: C.rojoPale,
    titulo: 'estado en produccion_diaria nunca cambia',
    desc: 'El campo produccion_diaria.estado (pendiente/en_proceso/completado) existe pero ningún proceso lo actualiza. Se recomienda implementar el flujo de cambio de estado en el módulo de producción del Dashboard.' },
  { tipo: '⚠ PENDIENTE', color: C.rojo, shade: C.rojoPale,
    titulo: 'relacion_pan_masa subutilizada',
    desc: 'La tabla existe pero no participa en ningún flujo activo. La vista_ingredientes_por_fecha y el bot la ignoran y usan produccion_diaria.tipo_pan directamente. Evaluar si se necesita o puede eliminarse.' },
  { tipo: '📌 DISEÑO', color: C.azulClaro, shade: C.azulPale,
    titulo: 'tipo_pan en detalle_pedidos guarda nombre de masa',
    desc: 'Por convención del bot, la columna detalle_pedidos.tipo_pan almacena el tipo de MASA (ej: BASICA, BRIOCHE), no el tipo de pan físico (HAMBURGUESA, PERRO). Esto es intencional pero contraintuitivo. El campo "producto" es el que identifica el pan.' },
  { tipo: '📌 DISEÑO', color: C.azulClaro, shade: C.azulPale,
    titulo: 'produccion_diaria.id_pedido no garantiza unicidad por pedido',
    desc: 'El constraint UNIQUE es por (fecha_produccion, tipo_pan, producto, peso_g). Si dos pedidos distintos del mismo día tienen la misma combinación, se acumulan en una sola fila via ON CONFLICT DO UPDATE. El campo id_pedido puede apuntar solo al último pedido que tocó esa fila.' },
  { tipo: '✅ BIEN', color: C.verde, shade: C.verdePale,
    titulo: 'Transacciones en operaciones críticas',
    desc: 'Las operaciones de crear pedido, confirmar y eliminar usan transacciones asyncpg correctamente. Garantiza atomicidad: si falla el INSERT en deudas o produccion_diaria, se hace rollback completo del pedido.' },
  { tipo: '✅ BIEN', color: C.verde, shade: C.verdePale,
    titulo: 'Triggers garantizan consistencia financiera',
    desc: 'saldo_pendiente y estado de deudas se calculan automáticamente via triggers, no pueden desincronizarse por código de aplicación defectuoso.' },
];

OBS.forEach(o => {
  children.push(new Table({
    width: { size: 9360, type: WidthType.DXA },
    columnWidths: [1200, 8160],
    rows: [
      new TableRow({ children: [
        cell(o.tipo, { shade: o.shade, bold: true, small: true, center: true, color: o.color, width: 1200 }),
        cell(o.titulo, { shade: o.shade, bold: true, small: true, color: o.color, width: 8160 }),
      ]}),
      new TableRow({ children: [
        new TableCell({ borders, columnSpan: 2, width: { size: 9360, type: WidthType.DXA },
          margins: { top: 60, bottom: 80, left: 160, right: 100 },
          children: [new Paragraph({ children: [new TextRun({ text: o.desc, font: 'Arial', size: 18 })] })],
        }),
      ]}),
    ],
    spacing: { before: 120 },
  }));
  children.push(sp(120));
});

// ── DOCUMENT ──
const doc = new Document({
  numbering: {
    config: [{
      reference: 'steps',
      levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 480, hanging: 360 } } } }],
    }],
  },
  styles: {
    default: { document: { run: { font: 'Arial', size: 20 } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { size: 28, bold: true, font: 'Arial', color: C.azul },
        paragraph: { spacing: { before: 360, after: 120 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { size: 24, bold: true, font: 'Arial', color: C.azulClaro },
        paragraph: { spacing: { before: 240, after: 80 }, outlineLevel: 1 } },
    ],
  },
  sections: [{
    properties: {
      page: {
        size: { width: 12240, height: 15840 },
        margin: { top: 1080, right: 1080, bottom: 1080, left: 1080 },
      },
    },
    headers: {
      default: new Header({ children: [
        new Paragraph({
          children: [
            new TextRun({ text: 'Sistema Panificadora — Estructura de Base de Datos', font: 'Arial', size: 16, color: C.grisHead }),
            new TextRun({ text: '\t', font: 'Arial', size: 16 }),
            new TextRun({ text: 'Confidencial', font: 'Arial', size: 16, color: C.rojo, bold: true }),
          ],
          tabStops: [{ type: 'right', position: 9360 }],
          border: { bottom: { style: BorderStyle.SINGLE, size: 2, color: C.azulClaro, space: 4 } },
        }),
      ]}),
    },
    footers: {
      default: new Footer({ children: [
        new Paragraph({
          children: [
            new TextRun({ text: `Generado: ${new Date().toLocaleDateString('es-VE')}  ·  PostgreSQL 15`, font: 'Arial', size: 16, color: C.grisHead }),
            new TextRun({ text: '\tPágina ', font: 'Arial', size: 16, color: C.grisHead }),
            new TextRun({ children: [PageNumber.CURRENT], font: 'Arial', size: 16, color: C.grisHead }),
          ],
          tabStops: [{ type: 'right', position: 9360 }],
          border: { top: { style: BorderStyle.SINGLE, size: 2, color: C.azulClaro, space: 4 } },
        }),
      ]}),
    },
    children,
  }],
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync('/Users/blackrave/panificadora_sistema/reporte_bd_panificadora.docx', buf);
  console.log('✅ Reporte generado: reporte_bd_panificadora.docx');
});
