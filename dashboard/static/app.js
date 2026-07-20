const API = '';

function esc(str) {
    return String(str ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}

// ── Auth ──────────────────────────────────────────────────────────────────────

async function apiFetch(url, opts = {}) {
    const token = localStorage.getItem('dashboard_token');
    if (!token) { window.location.href = '/'; return null; }
    opts.headers = { ...opts.headers, 'Authorization': 'Bearer ' + token };
    const res = await window.fetch(url, opts);
    if (res.status === 401) {
        localStorage.removeItem('dashboard_token');
        window.location.href = '/';
        return res;
    }
    return res;
}

async function logout() {
    try { await apiFetch(`${API}/api/logout`, { method: 'POST' }); } catch {}
    localStorage.removeItem('dashboard_token');
    window.location.href = '/';
}

// ── Estado global ─────────────────────────────────────────────────────────────
let pedidoActivoId      = null;
let despachoActivoId    = null;
let reciboActivoId      = null;
let recetaActivaNombre  = null;
let ingredienteActivoId = null;
let clienteActivoId     = null;
let productoActivoId    = null;
let deudaPagina         = 1;
let deudaBusqueda       = '';
let todosLosProductos   = [];

// tracks qué secciones ya cargaron sus datos
const seccionCargada = new Set();

// ── Utilidades ────────────────────────────────────────────────────────────────

function formatFecha(iso) {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString('es-VE', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function formatMonto(n) {
    if (n == null) return '—';
    return '$' + parseFloat(n).toFixed(2);
}

function hoy()    { return new Date().toISOString().split('T')[0]; }
function manana() {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toISOString().split('T')[0];
}

// ── Modales ───────────────────────────────────────────────────────────────────

function cerrarModal(id) {
    const m = document.getElementById(id);
    if (m) { m.style.display = 'none'; m.classList.add('hidden'); }
}

function abrirModal(id) {
    const m = document.getElementById(id);
    if (m) { m.classList.remove('hidden'); m.style.display = 'flex'; }
}

document.addEventListener('click', e => {
    if (e.target.classList.contains('modal')) {
        e.target.style.display = 'none';
        e.target.classList.add('hidden');
    }
});

// ── Navegación principal (Tabs de sección) ────────────────────────────────────

const CARGADORES = {
    pedidos:    cargarPedidos,
    produccion: cargarProduccion,
    despachos:  cargarDespachos,
    deudas:     cargarDeudas,
    clientes:   cargarClientes,
    recetas:    cargarRecetas,
    productos:  () => { cargarProductos(); cargarTopings(); },
};

function activarSeccion(id) {
    document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
    document.querySelectorAll('.nav-link').forEach(a => a.classList.remove('active'));

    document.getElementById(id).classList.add('active');
    document.querySelector(`.nav-link[data-section="${id}"]`).classList.add('active');

    if (!seccionCargada.has(id) && CARGADORES[id]) {
        CARGADORES[id]();
        seccionCargada.add(id);
    }
}

// ── Tabs internos de Producción ───────────────────────────────────────────────

function switchProdTab(tabId, btn) {
    document.querySelectorAll('#produccion .prod-panel').forEach(p => p.classList.add('hidden'));
    document.querySelectorAll('#produccion .tab-btn').forEach(b => b.classList.remove('active'));
    document.getElementById(tabId).classList.remove('hidden');
    btn.classList.add('active');
}

// ── Pedidos ───────────────────────────────────────────────────────────────────

async function cargarPedidos() {
    const tbody = document.querySelector('#pedidos-table tbody');
    tbody.innerHTML = '<tr><td colspan="5" class="loading">Cargando...</td></tr>';
    try {
        const res = await apiFetch(`${API}/api/pedidos/pendientes`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const pedidos = await res.json();

        if (!pedidos.length) {
            tbody.innerHTML = '<tr><td colspan="5" class="empty">Sin pedidos pendientes</td></tr>';
            return;
        }
        tbody.innerHTML = pedidos.map(p => `
            <tr>
                <td><strong>${p.numero_recibo}</strong></td>
                <td>${p.cliente}</td>
                <td>${formatMonto(p.monto_total)}</td>
                <td>${formatFecha(p.fecha_creacion)}</td>
                <td>
                    <button onclick="abrirModalConfirmar(${p.id_pedido})">✅ Confirmar</button>
                    <button onclick="verDetalles(${p.id_pedido})">🔍 Ver</button>
                    <button onclick="abrirModalEditarPedido(${p.id_pedido})">✏️ Editar</button>
                    <button class="delete" onclick="eliminarPedido(${p.id_pedido})">🗑️</button>
                    <button style="background:#dc3545;color:#fff" onclick="cancelarPedido(${p.id_pedido}, '${p.numero_recibo}')">🚫 Cancelar</button>
                </td>
            </tr>`).join('');
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="5" class="error">Error: ${e.message}</td></tr>`;
    }
}

function abrirModalConfirmar(idPedido) {
    pedidoActivoId = idPedido;
    document.getElementById('fecha-produccion').value = hoy();
    document.getElementById('fecha-despacho').value   = hoy();
    abrirModal('modal-confirmar');
}

async function confirmarPedido() {
    const fechaProd = document.getElementById('fecha-produccion').value;
    const fechaDesp = document.getElementById('fecha-despacho').value;
    if (!fechaProd || !fechaDesp) { alert('Completa ambas fechas.'); return; }
    try {
        const res = await apiFetch(`${API}/api/pedidos/${pedidoActivoId}/confirmar`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ fecha_produccion: fechaProd, fecha_despacho: fechaDesp }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        cerrarModal('modal-confirmar');
        cargarPedidos();
        if (seccionCargada.has('produccion')) cargarProduccion();
        if (seccionCargada.has('despachos'))  cargarDespachos();
    } catch (e) { alert(`Error confirmando pedido: ${e.message}`); }
}

async function verDetalles(idPedido) {
    try {
        const res = await apiFetch(`${API}/api/pedidos/${idPedido}/detalles`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const { pedido, detalles } = await res.json();
        const filas = detalles.map(d => `
            <tr>
                <td>${esc(d.tipo_pan)}</td><td>${esc(d.producto)}</td><td>${esc(d.peso_g)}g</td>
                <td>${esc(d.cantidad)}</td><td>${esc(d.tipo_unidad)}</td>
                <td>${formatMonto(d.precio_unitario)}</td><td>${formatMonto(d.subtotal)}</td>
            </tr>`).join('');
        const win = window.open('', '_blank', 'width=700,height=500');
        win.document.write(`<html><head><title>Pedido ${esc(pedido.numero_recibo)}</title>
            <style>body{font-family:sans-serif;padding:20px}table{width:100%;border-collapse:collapse}
            th,td{padding:10px;border:1px solid #ddd;text-align:left}thead{background:#667eea;color:white}</style>
            </head><body><h2>Pedido #${esc(pedido.numero_recibo)}</h2>
            <table><thead><tr>
                <th>Tipo</th><th>Producto</th><th>Peso</th><th>Cant.</th>
                <th>Unidad</th><th>P.Unit</th><th>Subtotal</th>
            </tr></thead><tbody>${filas}</tbody></table></body></html>`);
    } catch (e) { alert(`Error: ${e.message}`); }
}

async function eliminarPedido(idPedido) {
    if (!confirm('¿Eliminar este pedido? No se puede deshacer.')) return;
    try {
        const res = await apiFetch(`${API}/api/pedidos/${idPedido}`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        cargarPedidos();
    } catch (e) { alert(`Error eliminando pedido: ${e.message}`); }
}

async function cancelarPedido(idPedido, numRecibo) {
    if (!confirm(`¿Cancelar el pedido #${numRecibo}?\n\nSi está confirmado, se recalculará la producción del día. No se puede deshacer.`)) return;
    try {
        const res = await apiFetch(`${API}/api/pedidos/${idPedido}/cancelar`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        cargarPedidos();
        cargarDespachos();
    } catch (e) { alert(`Error cancelando pedido: ${e.message}`); }
}

// ── Producción ────────────────────────────────────────────────────────────────

async function cargarProduccion() {
    const fechaInput = document.getElementById('prod-fecha');
    const fecha = fechaInput.value || manana();
    if (!fechaInput.value) fechaInput.value = fecha;

    document.getElementById('prod-pan').innerHTML = '<p class="loading">Cargando...</p>';
    document.getElementById('prod-ing').innerHTML = '<p class="loading">Cargando...</p>';

    try {
        const [resPan] = await Promise.all([
            apiFetch(`${API}/api/produccion/${fecha}`),
        ]);

        const panes = resPan.ok ? await resPan.json() : [];
        _renderPorPan(panes);

        // Tab Ingredientes — Tabla 1A + 1B
        await _renderIngredientesTab(fecha);

        // Botón de estado de producción
        await _cargarEstadoProd(fecha);
    } catch (e) {
        document.getElementById('prod-pan').innerHTML = `<p class="error">Error: ${e.message}</p>`;
    }
}

const _PROD_ESTADO_CFG = {
    pendiente:   { label: '⏳ Pendiente',    bg: '#6c757d', next: 'en_proceso' },
    en_proceso:  { label: '🔄 En Proceso',   bg: '#f4a824', next: 'completado' },
    completado:  { label: '✅ Completado',   bg: '#28a745', next: 'pendiente'  },
};

async function _cargarEstadoProd(fecha) {
    const btn = document.getElementById('btn-estado-prod');
    try {
        const res = await apiFetch(`${API}/api/produccion/${fecha}/estado`);
        if (!res.ok) { btn.style.display = 'none'; return; }
        const { estado } = await res.json();
        btn.dataset.fecha  = fecha;
        btn.dataset.estado = estado;
        const cfg = _PROD_ESTADO_CFG[estado] || _PROD_ESTADO_CFG.pendiente;
        btn.textContent       = cfg.label;
        btn.style.background  = cfg.bg;
        btn.style.color       = '#fff';
        btn.style.display     = 'inline-block';
    } catch { btn.style.display = 'none'; }
}

async function ciclarEstadoProduccion() {
    const btn   = document.getElementById('btn-estado-prod');
    const fecha = btn.dataset.fecha;
    const actual = btn.dataset.estado || 'pendiente';
    const next  = _PROD_ESTADO_CFG[actual]?.next || 'en_proceso';
    try {
        const res = await apiFetch(`${API}/api/produccion/${fecha}/estado`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ estado: next }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        await _cargarEstadoProd(fecha);
    } catch (e) { alert(`Error actualizando estado: ${e.message}`); }
}

// ── Producción — Tab Por Pan ───────────────────────────────────────────────────

function _paqCols(row) {
    // Devuelve [celda_paquetes, celda_uds] para separar en 2 columnas
    const paq = row.paquete_cantidad || 1;
    const uds = row.total_unidades;
    if (paq > 1) {
        return [`<strong>${Math.round(uds / paq)}</strong>`, `<strong>${uds}</strong>`];
    }
    return [`<span style="color:#bbb">—</span>`, `<strong>${uds}</strong>`];
}

function _paqColsDet(cantidad, paquete_cantidad) {
    // Versión para tabla1A (usa campo 'cantidad' en vez de 'total_unidades')
    const paq = paquete_cantidad || 1;
    if (paq > 1) {
        return [`<strong>${Math.round(cantidad / paq)}</strong>`, `<strong>${cantidad}</strong>`];
    }
    return [`<span style="color:#bbb">—</span>`, `<strong>${cantidad}</strong>`];
}

function _totalUdsLabel(filas) {
    const totalUds = filas.reduce((s, r) => s + r.total_unidades, 0);
    const totalPaq = filas.reduce((s, r) => {
        const paq = r.paquete_cantidad || 1;
        return paq > 1 ? s + Math.round(r.total_unidades / paq) : s;
    }, 0);
    return totalPaq > 0 ? `${totalPaq} paq · ${totalUds} uds` : `${totalUds} uds`;
}

let _porPanDatos = [];
let _porPanGrupo = 'masa'; // 'masa' | 'cliente'

function _renderPorPan(datos) {
    _porPanDatos = datos;
    const el = document.getElementById('prod-pan');

    if (!datos.length) {
        el.innerHTML = '<p class="empty">Sin producción confirmada para esa fecha.</p>';
        return;
    }

    const masasUnicas    = [...new Set(datos.map(r => r.tipo_masa))].sort();
    const clientesUnicos = [...new Set(datos.map(r => r.cliente))].sort();

    el.innerHTML = `
        <div class="toolbar" style="margin-bottom:14px;flex-wrap:wrap;gap:8px">
            <input type="text"  id="pan-filtro-cli"  placeholder="🔍 Buscar cliente..."
                   oninput="_filtrarPorPan()" style="min-width:180px">
            <select id="pan-filtro-masa" onchange="_filtrarPorPan()" style="padding:8px 10px;border:1px solid #ddd;border-radius:5px;font-size:14px">
                <option value="">Todas las masas</option>
                ${masasUnicas.map(m => `<option value="${m}">${m}</option>`).join('')}
            </select>
            <div style="display:flex;gap:4px;margin-left:auto">
                <button id="btn-grupo-masa"    onclick="_setPorPanGrupo('masa')"
                    style="padding:6px 14px;font-size:13px;background:#667eea">Agrupar por Masa</button>
                <button id="btn-grupo-cliente" onclick="_setPorPanGrupo('cliente')"
                    style="padding:6px 14px;font-size:13px;background:#6c757d">Agrupar por Cliente</button>
            </div>
        </div>
        <div id="pan-tabla-container"></div>`;

    _filtrarPorPan();
}

function _setPorPanGrupo(grupo) {
    _porPanGrupo = grupo;
    document.getElementById('btn-grupo-masa').style.background    = grupo === 'masa'    ? '#667eea' : '#6c757d';
    document.getElementById('btn-grupo-cliente').style.background = grupo === 'cliente' ? '#667eea' : '#6c757d';
    _filtrarPorPan();
}

function _filtrarPorPan() {
    const txtCli  = (document.getElementById('pan-filtro-cli')?.value  || '').toLowerCase();
    const txtMasa = (document.getElementById('pan-filtro-masa')?.value || '');

    const filtrados = _porPanDatos.filter(r =>
        (!txtCli  || r.cliente.toLowerCase().includes(txtCli)) &&
        (!txtMasa || r.tipo_masa === txtMasa)
    );

    const container = document.getElementById('pan-tabla-container');
    if (!filtrados.length) {
        container.innerHTML = '<p class="empty">Sin resultados para ese filtro.</p>';
        return;
    }

    if (_porPanGrupo === 'masa') {
        _renderGrupado(container, filtrados, 'tipo_masa',
            (key, filas) => `🍞 ${key} — <span style="color:#fff;opacity:.8">${_totalUdsLabel(filas)}</span>`,
            r => { const [cp, cu] = _paqCols(r); return `
                  <td><span class="badge" style="background:#667eea">${r.tipo_masa}</span></td>
                  <td>${r.producto}</td>
                  <td style="text-align:center">${r.peso_g ? r.peso_g+'g' : '—'}</td>
                  <td style="text-align:center">${cp}</td>
                  <td style="text-align:center">${cu}</td>
                  <td>${r.cliente}</td>`; },
            ['Tipo Masa','Producto','Peso','Paquetes','Uds','Cliente']
        );
    } else {
        _renderGrupado(container, filtrados, 'cliente',
            (key, filas) => `🏪 ${key} — <span style="color:#fff;opacity:.8">${_totalUdsLabel(filas)}</span>`,
            r => { const [cp, cu] = _paqCols(r); return `
                  <td>${r.cliente}</td>
                  <td><span class="badge" style="background:#667eea">${r.tipo_masa}</span></td>
                  <td>${r.producto}</td>
                  <td style="text-align:center">${r.peso_g ? r.peso_g+'g' : '—'}</td>
                  <td style="text-align:center">${cp}</td>
                  <td style="text-align:center">${cu}</td>`; },
            ['Cliente','Tipo Masa','Producto','Peso','Paquetes','Uds']
        );
    }
}

function _renderGrupado(container, datos, campoGrupo, labelFn, rowFn, headers) {
    const grupos = {};
    datos.forEach(r => {
        const k = r[campoGrupo];
        if (!grupos[k]) grupos[k] = [];
        grupos[k].push(r);
    });

    container.innerHTML = `
        <div style="text-align:right;margin-bottom:8px;font-size:13px;color:#666">
            Total: <strong>${_totalUdsLabel(datos)}</strong> · ${Object.keys(grupos).length} grupos
        </div>
        ${Object.entries(grupos).sort(([a],[b])=>a.localeCompare(b)).map(([key, filas]) => `
        <div style="margin-bottom:16px">
            <div style="background:#667eea;color:#fff;padding:8px 14px;border-radius:6px 6px 0 0;font-weight:600;font-size:14px">
                ${labelFn(key, filas)}
            </div>
            <table style="margin:0;box-shadow:0 2px 8px rgba(0,0,0,.08);border-radius:0 0 6px 6px;overflow:hidden">
                <thead><tr>${headers.map(h=>`<th>${h}</th>`).join('')}</tr></thead>
                <tbody>${filas.map(r=>`<tr>${rowFn(r)}</tr>`).join('')}</tbody>
                <tfoot><tr>
                    <td colspan="${headers.length - 2}" style="text-align:right;font-size:13px;color:#666;padding:8px 14px">
                        Subtotal:</td>
                    <td style="font-weight:bold;text-align:center">${
                        filas.some(r => (r.paquete_cantidad||1) > 1)
                            ? filas.reduce((s,r)=>{ const p=r.paquete_cantidad||1; return p>1?s+Math.round(r.total_unidades/p):s; },0)
                            : '<span style="color:#bbb">—</span>'
                    }</td>
                    <td style="font-weight:bold;text-align:center">${filas.reduce((s,r)=>s+r.total_unidades,0)}</td>
                </tr></tfoot>
            </table>
        </div>`).join('')}`;
}

// ── Producción — Tab Ingredientes ─────────────────────────────────────────────

async function _renderIngredientesTab(fecha) {
    const el = document.getElementById('prod-ing');
    el.innerHTML = '<p class="loading">Cargando ingredientes...</p>';

    try {
        const [resDetalle, resResumen] = await Promise.all([
            apiFetch(`${API}/api/produccion-detalle/${fecha}`),
            apiFetch(`${API}/api/ingredientes-resumen/${fecha}`),
        ]);
        const detalle = resDetalle.ok ? await resDetalle.json() : [];
        const resumen = resResumen.ok ? await resResumen.json() : [];

        if (!detalle.length && !resumen.length) {
            el.innerHTML = '<p class="empty">Sin producción confirmada para esa fecha.</p>';
            return;
        }

        // ── Tabla 1A: Detalle de Panes a Producir ──
        const tabla1A = !detalle.length ? '<p class="empty">Sin panes registrados.</p>' : `
            <table>
                <thead>
                    <tr>
                        <th>Tipo Masa</th>
                        <th>Producto</th>
                        <th style="text-align:center">Peso</th>
                        <th style="text-align:center">Paquetes</th>
                        <th style="text-align:center">Uds</th>
                        <th>Cliente(s)</th>
                    </tr>
                </thead>
                <tbody>
                    ${detalle.map(r => {
                        const [cp, cu] = _paqColsDet(r.cantidad, r.paquete_cantidad);
                        return `
                    <tr>
                        <td><span class="badge" style="background:#667eea">${r.tipo_masa}</span></td>
                        <td>${r.producto}</td>
                        <td style="text-align:center">${r.peso_g ? r.peso_g+'g' : '—'}</td>
                        <td style="text-align:center">${cp}</td>
                        <td style="text-align:center">${cu}</td>
                        <td style="color:#555;font-size:13px">${r.clientes || '—'}</td>
                    </tr>`;}).join('')}
                </tbody>
            </table>`;

        // ── Tabla 1B: Ingredientes por Tipo de Masa ──
        const tabla1B = !resumen.length ? '<p class="empty">Sin masas con receta para esta fecha.</p>' : `
            <table>
                <thead>
                    <tr>
                        <th>Tipo Masa</th>
                        <th>Panes incluidos</th>
                        <th style="text-align:center">Uds. Total</th>
                        <th style="text-align:center">Acción</th>
                    </tr>
                </thead>
                <tbody>
                    ${resumen.map(r => `
                    <tr>
                        <td><span class="badge" style="background:#667eea">${r.tipo_masa}</span></td>
                        <td style="font-size:13px;color:#444">${r.panes_detalle || '—'}</td>
                        <td style="text-align:center"><strong>${r.unidades_total}</strong></td>
                        <td style="text-align:center">
                            ${r.tiene_receta
                                ? `<button style="padding:4px 12px;font-size:12px"
                                       onclick="abrirModalIngDetalle('${fecha}','${r.tipo_masa}')">
                                       🧂 Ver detalles</button>`
                                : `<span style="color:#999;font-size:12px">Sin receta</span>`}
                        </td>
                    </tr>`).join('')}
                </tbody>
            </table>`;

        el.innerHTML = `
            <h4 style="margin:0 0 10px;color:#444">📋 Detalle de Panes a Producir</h4>
            ${tabla1A}
            <h4 style="margin:24px 0 10px;color:#444">🧂 Ingredientes Totales por Tipo de Masa</h4>
            ${tabla1B}`;

    } catch (e) {
        el.innerHTML = `<p class="error">Error: ${e.message}</p>`;
    }
}

async function abrirModalIngDetalle(fecha, tipoMasa) {
    document.getElementById('ing-detalle-titulo').textContent = `Ingredientes — Masa ${tipoMasa}`;
    document.getElementById('ing-detalle-panes').textContent  = 'Cargando...';
    document.getElementById('ing-detalle-body').innerHTML     = '<tr><td colspan="3" class="loading">Cargando...</td></tr>';
    abrirModal('modal-ing-detalle');

    try {
        const res = await apiFetch(`${API}/api/ingredientes-detalle/${fecha}/${tipoMasa}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const { panes, ingredientes } = await res.json();

        document.getElementById('ing-detalle-panes').innerHTML =
            `<strong>Panes con esta masa:</strong> ` +
            panes.map(p => `${p.producto} <strong>(${p.cantidad} uds)</strong>`).join(' · ');

        if (!ingredientes.length) {
            document.getElementById('ing-detalle-body').innerHTML =
                '<tr><td colspan="3" class="empty">Sin ingredientes registrados para esta masa.</td></tr>';
            return;
        }

        document.getElementById('ing-detalle-body').innerHTML = ingredientes.map(i => `
            <tr>
                <td>${i.ingrediente}</td>
                <td style="text-align:right"><strong>${parseInt(i.cantidad_g)} g</strong></td>
            </tr>`).join('');
    } catch (e) {
        document.getElementById('ing-detalle-body').innerHTML =
            `<tr><td colspan="2" class="error">Error: ${e.message}</td></tr>`;
    }
}

function imprimirIngDetalle() {
    const titulo  = document.getElementById('ing-detalle-titulo').textContent;
    const panes   = document.getElementById('ing-detalle-panes').innerHTML;
    const filas   = document.getElementById('ing-detalle-body').innerHTML;
    const ventana = window.open('', '_blank', 'width=520,height=700');
    ventana.document.write(`<!DOCTYPE html><html><head>
        <meta charset="UTF-8">
        <title>${titulo}</title>
        <style>
            body { font-family: Arial, sans-serif; padding: 24px; font-size: 14px; color: #222; }
            h2   { margin: 0 0 6px; font-size: 18px; }
            .panes { background: #f0f4ff; border-radius: 6px; padding: 8px 12px;
                     margin-bottom: 16px; font-size: 13px; }
            table { width: 100%; border-collapse: collapse; margin-top: 8px; }
            th    { background: #667eea; color: #fff; padding: 8px 12px; text-align: left; font-size: 13px; }
            th:last-child { text-align: right; }
            td    { padding: 7px 12px; border-bottom: 1px solid #e0e0e0; }
            td:last-child { text-align: right; font-weight: bold; }
            tr:nth-child(even) td { background: #f9f9f9; }
            .fecha { font-size: 12px; color: #888; margin-bottom: 14px; }
            @media print { button { display: none; } }
        </style>
    </head><body>
        <h2>${titulo}</h2>
        <p class="fecha">${new Date().toLocaleDateString('es-VE', { day:'2-digit', month:'long', year:'numeric' })}</p>
        <div class="panes">${panes}</div>
        <table>
            <thead><tr><th>Ingrediente</th><th>Cantidad (g)</th></tr></thead>
            <tbody>${filas}</tbody>
        </table>
        <script>window.onload = () => { window.print(); }<\/script>
    </body></html>`);
    ventana.document.close();
}

// ── Despachos ─────────────────────────────────────────────────────────────────

async function cargarDespachos() {
    const tbody = document.querySelector('#despachos-table tbody');
    tbody.innerHTML = '<tr><td colspan="5" class="loading">Cargando...</td></tr>';
    try {
        const res = await apiFetch(`${API}/api/despachos`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const despachos = await res.json();

        if (!despachos.length) {
            tbody.innerHTML = '<tr><td colspan="5" class="empty">Sin despachos confirmados</td></tr>';
            return;
        }
        tbody.innerHTML = despachos.map(d => `
            <tr>
                <td><strong>${d.numero_recibo}</strong></td>
                <td>${d.cliente}</td>
                <td>${formatMonto(d.monto_total)}</td>
                <td>${formatFecha(d.fecha_despacho_real)}</td>
                <td>
                    <button onclick="abrirModalDespacho(${d.id_pedido})">📅 Fecha</button>
                    <button onclick="abrirModalRecibo(${d.id_pedido})">📄 PDF</button>
                    <button style="background:#28a745" onclick="marcarEntregado(${d.id_pedido}, '${d.numero_recibo}')">✅ Entregar</button>
                    <button style="background:#dc3545;color:#fff" onclick="cancelarPedido(${d.id_pedido}, '${d.numero_recibo}')">🚫 Cancelar</button>
                </td>
            </tr>`).join('');
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="5" class="error">Error: ${e.message}</td></tr>`;
    }
}

async function marcarEntregado(idPedido, numRecibo) {
    if (!confirm(`¿Marcar el pedido #${numRecibo} como ENTREGADO?\nEsta acción no se puede deshacer.`)) return;
    try {
        const res = await apiFetch(`${API}/api/pedidos/${idPedido}/entregar`, { method: 'POST' });
        if (!res.ok) { const err = await res.json(); throw new Error(err.detail || `HTTP ${res.status}`); }
        cargarDespachos();
    } catch (e) { alert(`Error: ${e.message}`); }
}

function abrirModalDespacho(idPedido) {
    despachoActivoId = idPedido;
    document.getElementById('nueva-fecha-despacho').value = hoy();
    abrirModal('modal-despacho');
}

async function cambiarDespacho() {
    const nuevaFecha = document.getElementById('nueva-fecha-despacho').value;
    if (!nuevaFecha) { alert('Selecciona una fecha.'); return; }
    try {
        const res = await apiFetch(`${API}/api/despachos/${despachoActivoId}/cambiar-fecha`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ nueva_fecha: nuevaFecha }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        cerrarModal('modal-despacho');
        cargarDespachos();
    } catch (e) { alert(`Error cambiando fecha: ${e.message}`); }
}

// ── Recibos PDF ───────────────────────────────────────────────────────────────

function abrirModalRecibo(idPedido) {
    reciboActivoId = idPedido;
    document.getElementById('recibo-delivery').value = '0';
    document.getElementById('recibo-iva').checked    = false;
    abrirModal('modal-recibo');
}

async function generarRecibo() {
    const delivery  = parseFloat(document.getElementById('recibo-delivery').value) || 0;
    const aplicaIva = document.getElementById('recibo-iva').checked;
    try {
        const res = await apiFetch(`${API}/api/recibos/${reciboActivoId}/generar`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ monto_delivery: delivery, aplica_iva: aplicaIva }),
        });
        if (!res.ok) {
            const err = await res.json();
            throw new Error(err.detail || `HTTP ${res.status}`);
        }
        const blob = await res.blob();
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href = url; a.download = `Recibo_${reciboActivoId}.pdf`; a.click();
        URL.revokeObjectURL(url);
        cerrarModal('modal-recibo');
    } catch (e) { alert(`Error generando PDF: ${e.message}`); }
}

// ── Deudas ────────────────────────────────────────────────────────────────────

let deudaTimer = null;
function buscarDeudas() {
    clearTimeout(deudaTimer);
    deudaTimer = setTimeout(() => {
        deudaBusqueda = document.getElementById('deudas-search').value;
        deudaPagina   = 1;
        cargarDeudas();
    }, 350);
}

async function cargarDeudas() {
    const tbody = document.querySelector('#deudas-table tbody');
    tbody.innerHTML = '<tr><td colspan="6" class="loading">Cargando...</td></tr>';
    try {
        const params = new URLSearchParams({ page: deudaPagina, limit: 10 });
        if (deudaBusqueda) params.set('search', deudaBusqueda);

        const res = await apiFetch(`${API}/api/deudas?${params}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const { total, page, limit, items } = await res.json();

        if (!items.length) {
            tbody.innerHTML = '<tr><td colspan="6" class="empty">Sin resultados</td></tr>';
        } else {
            tbody.innerHTML = items.map(d => `
                <tr>
                    <td><strong>${d.nombre_negocio}</strong></td>
                    <td>${d.telefono || '—'}</td>
                    <td>${formatMonto(d.total_pedidos)}</td>
                    <td>${formatMonto(d.total_pagado)}</td>
                    <td style="color:${d.deuda_total > 0 ? '#dc3545' : '#28a745'};font-weight:bold">
                        ${formatMonto(d.deuda_total)}</td>
                    <td>${formatFecha(d.ultimo_pedido)}</td>
                    <td><button onclick="abrirModalPago(${d.id_cliente}, '${d.nombre_negocio.replace(/'/g,"\\'")}')">💳 Pagos</button></td>
                </tr>`).join('');
        }

        // actualizar header de deudas para incluir columna acción
        document.querySelector('#deudas-table thead tr').innerHTML =
            '<th>Cliente</th><th>Teléfono</th><th>Total Pedidos</th><th>Total Pagado</th><th>Deuda</th><th>Ú. Pedido</th><th>Acción</th>';

        const totalPags = Math.ceil(total / limit);
        const pag = document.getElementById('deudas-paginacion');
        if (totalPags <= 1) { pag.innerHTML = ''; return; }
        let btns = '';
        if (page > 1)         btns += `<button onclick="irPagDeudas(${page-1})">‹ Anterior</button>`;
        btns += `<span class="pag-info">Pág ${page} / ${totalPags} (${total})</span>`;
        if (page < totalPags) btns += `<button onclick="irPagDeudas(${page+1})">Siguiente ›</button>`;
        pag.innerHTML = btns;
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="6" class="error">Error: ${e.message}</td></tr>`;
    }
}

function irPagDeudas(p) { deudaPagina = p; cargarDeudas(); }

// ── Clientes ──────────────────────────────────────────────────────────────────

let todosLosClientes = [];

async function cargarClientes() {
    const tbody = document.querySelector('#clientes-table tbody');
    tbody.innerHTML = '<tr><td colspan="7" class="loading">Cargando...</td></tr>';
    try {
        const res = await apiFetch(`${API}/api/clientes`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        todosLosClientes = await res.json();
        renderClientes(todosLosClientes);
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="7" class="error">Error: ${e.message}</td></tr>`;
    }
}

function renderClientes(lista) {
    const tbody = document.querySelector('#clientes-table tbody');
    if (!lista.length) {
        tbody.innerHTML = '<tr><td colspan="7" class="empty">Sin clientes registrados</td></tr>';
        return;
    }
    const ESTADO_COLOR = { activo: '#28a745', inactivo: '#6c757d', bloqueado: '#dc3545' };
    tbody.innerHTML = lista.map(c => `
        <tr class="${c.estado !== 'activo' ? 'row-inactivo' : ''}">
            <td><strong>${c.nombre_negocio}</strong></td>
            <td>${c.telefono || '—'}</td>
            <td>${c.contacto_principal || '—'}</td>
            <td><span class="badge-cat">${c.categoria}</span></td>
            <td><span style="color:${ESTADO_COLOR[c.estado] || '#333'};font-weight:bold">${c.estado}</span></td>
            <td><span class="badge">${c.total_pedidos}</span></td>
            <td>
                <button onclick="verDetalleCliente(${c.id_cliente})">🔍 Ver</button>
                <button onclick="abrirModalEditarCliente(${c.id_cliente})">✏️</button>
                <button class="delete" onclick="eliminarCliente(${c.id_cliente}, '${c.nombre_negocio.replace(/'/g, "\\'")}')">🗑️</button>
            </td>
        </tr>`).join('');
}

let clientesFiltroTimer = null;
function filtrarClientes() {
    clearTimeout(clientesFiltroTimer);
    clientesFiltroTimer = setTimeout(() => {
        const q = document.getElementById('clientes-search').value.toLowerCase();
        const filtrados = q
            ? todosLosClientes.filter(c =>
                c.nombre_negocio.toLowerCase().includes(q) ||
                (c.telefono || '').includes(q) ||
                (c.contacto_principal || '').toLowerCase().includes(q))
            : todosLosClientes;
        renderClientes(filtrados);
    }, 250);
}

function abrirModalNuevoCliente() {
    clienteActivoId = null;
    document.getElementById('modal-cliente-titulo').textContent = 'Nuevo Cliente';
    document.getElementById('cli-nombre').value    = '';
    document.getElementById('cli-telefono').value  = '';
    document.getElementById('cli-direccion').value = '';
    document.getElementById('cli-contacto').value  = '';
    document.getElementById('cli-categoria').value = 'otro';
    document.getElementById('cli-telegram').value  = '';
    abrirModal('modal-cliente');
}

function abrirModalEditarCliente(idCliente) {
    const c = todosLosClientes.find(x => x.id_cliente === idCliente);
    if (!c) return;
    clienteActivoId = idCliente;
    document.getElementById('modal-cliente-titulo').textContent = `Editar: ${c.nombre_negocio}`;
    document.getElementById('cli-nombre').value    = c.nombre_negocio;
    document.getElementById('cli-telefono').value  = c.telefono || '';
    document.getElementById('cli-direccion').value = c.direccion || '';
    document.getElementById('cli-contacto').value  = c.contacto_principal || '';
    document.getElementById('cli-categoria').value = c.categoria || 'otro';
    document.getElementById('cli-telegram').value  = c.telegram_id || '';
    abrirModal('modal-cliente');
}

async function guardarCliente() {
    const nombre = document.getElementById('cli-nombre').value.trim();
    if (!nombre) { alert('El nombre del negocio es obligatorio.'); return; }

    const body = {
        nombre_negocio:     nombre,
        telefono:           document.getElementById('cli-telefono').value.trim()  || null,
        direccion:          document.getElementById('cli-direccion').value.trim() || null,
        contacto_principal: document.getElementById('cli-contacto').value.trim()  || null,
        categoria:          document.getElementById('cli-categoria').value,
        telegram_id:        document.getElementById('cli-telegram').value.trim()  || null,
    };

    try {
        const url    = clienteActivoId ? `${API}/api/clientes/${clienteActivoId}` : `${API}/api/clientes`;
        const method = clienteActivoId ? 'PUT' : 'POST';
        const res    = await apiFetch(url, {
            method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
        });
        if (!res.ok) {
            const err = await res.json();
            throw new Error(err.detail || `HTTP ${res.status}`);
        }
        cerrarModal('modal-cliente');
        await cargarClientes();
    } catch (e) { alert(`Error guardando cliente: ${e.message}`); }
}

async function eliminarCliente(idCliente, nombre) {
    if (!confirm(`¿Eliminar a "${nombre}"?\n\nSi tiene pedidos asociados se marcará como inactivo.`)) return;
    try {
        const res = await apiFetch(`${API}/api/clientes/${idCliente}`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (data.accion === 'desactivado') {
            alert(`"${nombre}" fue marcado como inactivo (tiene pedidos asociados).`);
        }
        await cargarClientes();
    } catch (e) { alert(`Error eliminando cliente: ${e.message}`); }
}

async function verDetalleCliente(idCliente) {
    abrirModal('modal-detalle-cliente');
    document.getElementById('detalle-cliente-nombre').textContent = 'Cargando...';
    document.getElementById('detalle-cliente-info').innerHTML = '';
    document.querySelector('#detalle-cliente-pedidos tbody').innerHTML =
        '<tr><td colspan="4" class="loading">Cargando...</td></tr>';

    try {
        const res = await apiFetch(`${API}/api/clientes/${idCliente}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const { cliente: c, pedidos_recientes } = await res.json();

        document.getElementById('detalle-cliente-nombre').textContent = c.nombre_negocio;
        document.getElementById('detalle-cliente-info').innerHTML = `
            <p>📞 ${c.telefono || '—'} &nbsp;|&nbsp; 👤 ${c.contacto_principal || '—'}</p>
            <p>📍 ${c.direccion || '—'} &nbsp;|&nbsp; 🏷️ ${c.categoria} &nbsp;|&nbsp; Estado: <strong>${c.estado}</strong></p>
            ${c.telegram_id ? `<p>Telegram ID: ${c.telegram_id}</p>` : ''}`;

        const ESTADO_COLOR = { confirmado: '#28a745', pendiente: '#ffc107', cancelado: '#dc3545', entregado: '#17a2b8' };
        document.querySelector('#detalle-cliente-pedidos tbody').innerHTML =
            !pedidos_recientes.length
                ? '<tr><td colspan="4" class="empty">Sin pedidos</td></tr>'
                : pedidos_recientes.map(p => `
                    <tr>
                        <td>${p.numero_recibo}</td>
                        <td style="color:${ESTADO_COLOR[p.estado] || '#333'}">${p.estado}</td>
                        <td>${formatMonto(p.monto_total)}</td>
                        <td>${formatFecha(p.fecha_pedido)}</td>
                    </tr>`).join('');
    } catch (e) {
        document.getElementById('detalle-cliente-nombre').textContent = 'Error';
        document.getElementById('detalle-cliente-info').textContent = e.message;
    }
}

// ── Recetas ───────────────────────────────────────────────────────────────────

async function cargarRecetas() {
    const tbody = document.querySelector('#recetas-table tbody');
    tbody.innerHTML = '<tr><td colspan="5" class="loading">Cargando...</td></tr>';
    try {
        const res = await apiFetch(`${API}/api/recetas`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const recetas = await res.json();

        if (!recetas.length) {
            tbody.innerHTML = '<tr><td colspan="5" class="empty">Sin recetas registradas</td></tr>';
            return;
        }
        tbody.innerHTML = recetas.map(r => `
            <tr>
                <td><strong>${r.tipo_masa}</strong></td>
                <td>${r.descripcion || '—'}</td>
                <td><span class="badge">${r.num_ingredientes}</span></td>
                <td>${r.activo ? '✅' : '❌'}</td>
                <td>
                    <button onclick="abrirDetalleReceta('${r.tipo_masa}')">🔍 Ver</button>
                    <button onclick="abrirModalEditarReceta('${r.tipo_masa}', ${r.peso_masa_g}, \`${(r.descripcion || '').replace(/`/g, '\\`')}\`)">✏️</button>
                    <button class="delete" onclick="eliminarReceta('${r.tipo_masa}')">🗑️</button>
                </td>
            </tr>`).join('');
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="5" class="error">Error: ${e.message}</td></tr>`;
    }
}

function abrirModalNuevaReceta() {
    recetaActivaNombre = null;
    document.getElementById('modal-receta-titulo').textContent  = 'Nueva Receta';
    document.getElementById('receta-nombre').value      = '';
    document.getElementById('receta-nombre').disabled   = false;
    document.getElementById('receta-descripcion').value = '';
    abrirModal('modal-receta');
}

function abrirModalEditarReceta(tipoMasa, peso, desc) {
    recetaActivaNombre = tipoMasa;
    _recetaPesoMasaG   = peso || 0;
    document.getElementById('modal-receta-titulo').textContent  = `Editar: ${tipoMasa}`;
    document.getElementById('receta-nombre').value      = tipoMasa;
    document.getElementById('receta-nombre').disabled   = true;
    document.getElementById('receta-descripcion').value = desc;
    abrirModal('modal-receta');
}

async function guardarReceta() {
    const nombre = document.getElementById('receta-nombre').value.trim().toUpperCase();
    const desc   = document.getElementById('receta-descripcion').value.trim() || null;
    if (!nombre) { alert('El nombre es obligatorio.'); return; }
    try {
        const esEdicion = !!recetaActivaNombre;
        const res = await apiFetch(
            esEdicion ? `${API}/api/recetas/${recetaActivaNombre}` : `${API}/api/recetas`,
            {
                method: esEdicion ? 'PUT' : 'POST',
                headers: { 'Content-Type': 'application/json' },
                // Al crear, peso_masa_g=1 como placeholder; se actualiza al guardar ingredientes
                body: JSON.stringify(esEdicion
                    ? { peso_masa_g: _recetaPesoMasaG || 1, descripcion: desc }
                    : { tipo_masa: nombre, peso_masa_g: 1, descripcion: desc }),
            }
        );
        if (!res.ok) { const err = await res.json(); throw new Error(err.detail || `HTTP ${res.status}`); }
        cerrarModal('modal-receta');
        await cargarRecetas();
    } catch (e) { alert(`Error guardando receta: ${e.message}`); }
}

async function eliminarReceta(tipoMasa) {
    if (!confirm(`¿Eliminar la receta "${tipoMasa}" y todos sus ingredientes?`)) return;
    try {
        const res = await apiFetch(`${API}/api/recetas/${tipoMasa}`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        await cargarRecetas();
    } catch (e) { alert(`Error eliminando receta: ${e.message}`); }
}

let _recetaPesoMasaG = 0;

async function abrirDetalleReceta(tipoMasa) {
    recetaActivaNombre = tipoMasa;
    _recetaPesoMasaG   = 0;
    document.getElementById('detalle-receta-titulo').textContent = `Receta: ${tipoMasa}`;
    document.querySelector('#ingredientes-table tbody').innerHTML =
        '<tr><td colspan="4" class="loading">Cargando...</td></tr>';
    document.getElementById('impact-tabla').innerHTML = '<p class="loading">Calculando...</p>';
    document.getElementById('receta-total-g').textContent = '— g';
    abrirModal('modal-detalle-receta');

    const [resDetalle, resImpact] = await Promise.all([
        apiFetch(`${API}/api/recetas/${tipoMasa}`),
        apiFetch(`${API}/api/recetas/${tipoMasa}/produccion-impact`),
    ]);

    if (resDetalle.ok) {
        const { masa, ingredientes } = await resDetalle.json();
        _recetaPesoMasaG = masa.peso_masa_g;
        renderIngredientes(ingredientes, masa.peso_masa_g);
    }

    if (resImpact.ok) {
        const impacto = await resImpact.json();
        document.getElementById('impact-tabla').innerHTML = !impacto.length
            ? '<p class="empty">Sin producción futura confirmada para esta masa.</p>'
            : `<table>
                <thead><tr><th>Fecha</th><th>Unidades</th><th>Kg Masa</th></tr></thead>
                <tbody>${impacto.map(i => `
                    <tr>
                        <td>${formatFecha(i.fecha_produccion_requerida)}</td>
                        <td>${i.total_unidades} und.</td>
                        <td><strong>${parseFloat(i.kg_masa_total).toFixed(3)} kg</strong></td>
                    </tr>`).join('')}
                </tbody></table>`;
    }
}

function _actualizarTotalReceta() {
    const inputs = document.querySelectorAll('#ingredientes-table tbody .ing-gramos');
    const total  = Array.from(inputs).reduce((s, el) => s + (parseFloat(el.value) || 0), 0);
    document.getElementById('receta-total-g').textContent = `${Math.round(total)} g`;
    // Actualizar ratios en vivo
    inputs.forEach(el => {
        const g     = parseFloat(el.value) || 0;
        const ratio = total > 0 ? (g / total).toFixed(4) : '0.0000';
        const span  = el.closest('tr').querySelector('.ing-ratio');
        if (span) span.textContent = ratio;
    });
}

function renderIngredientes(ingredientes, pesoMasaG) {
    const tbody = document.querySelector('#ingredientes-table tbody');
    if (!ingredientes.length) {
        tbody.innerHTML = '<tr><td colspan="4" class="empty">Sin ingredientes. Agrega el primero.</td></tr>';
        document.getElementById('receta-total-g').textContent = '0 g';
        return;
    }
    tbody.innerHTML = ingredientes.map(i => {
        const gramos = Math.round(i.cantidad_por_kg_masa * pesoMasaG);
        const ratio  = parseFloat(i.cantidad_por_kg_masa).toFixed(4);
        return `
        <tr data-id="${i.id_receta}" data-nombre="${i.ingrediente}">
            <td><strong>${i.ingrediente}</strong></td>
            <td style="text-align:center">
                <input type="number" class="ing-gramos" value="${gramos}" min="0" step="1"
                    style="width:90px;font-size:14px;text-align:right;padding:4px 6px"
                    oninput="_actualizarTotalReceta()"> g
            </td>
            <td style="text-align:center;color:#888;font-size:13px">
                <span class="ing-ratio">${ratio}</span>
            </td>
            <td style="text-align:center">
                <button class="delete" onclick="eliminarIngrediente(${i.id_receta})">🗑️</button>
            </td>
        </tr>`;
    }).join('');
    _actualizarTotalReceta();
}

function abrirModalIngrediente() {
    ingredienteActivoId = null;
    document.getElementById('modal-ingrediente-titulo').textContent = 'Agregar Ingrediente';
    document.getElementById('ing-nombre').value    = '';
    document.getElementById('ing-nombre').disabled = false;
    document.getElementById('ing-cantidad').value  = '';
    abrirModal('modal-ingrediente');
}

async function guardarIngrediente() {
    const nombre = document.getElementById('ing-nombre').value.trim().toUpperCase();
    const gramos = parseFloat(document.getElementById('ing-cantidad').value);
    if (!nombre || isNaN(gramos) || gramos <= 0) {
        alert('Ingresa el nombre y los gramos del ingrediente.'); return;
    }
    // Calcular ratio provisional con el total actual + nuevo ingrediente
    const inputs     = document.querySelectorAll('#ingredientes-table tbody .ing-gramos');
    const totalActual = Array.from(inputs).reduce((s, el) => s + (parseFloat(el.value) || 0), 0);
    const nuevoTotal  = totalActual + gramos;
    const ratio       = nuevoTotal > 0 ? gramos / nuevoTotal : 0;
    try {
        const res = await apiFetch(`${API}/api/recetas/${recetaActivaNombre}/ingredientes`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ingrediente: nombre, cantidad_por_kg_masa: ratio, unidad: 'kg' }),
        });
        if (!res.ok) { const err = await res.json(); throw new Error(err.detail || `HTTP ${res.status}`); }
        cerrarModal('modal-ingrediente');
        // Recargar y guardar todo para recalcular todos los ratios con el nuevo total
        const resD = await apiFetch(`${API}/api/recetas/${recetaActivaNombre}`);
        if (resD.ok) {
            const { masa, ingredientes } = await resD.json();
            // Sobreescribir los gramos del nuevo con lo que ingresó el usuario
            const idx = ingredientes.findIndex(i => i.ingrediente === nombre);
            if (idx >= 0) ingredientes[idx]._gramos_override = gramos;
            _recetaPesoMasaG = masa.peso_masa_g;
            renderIngredientes(ingredientes, masa.peso_masa_g);
            // Forzar el valor del nuevo ingrediente
            if (idx >= 0) {
                const rows = document.querySelectorAll('#ingredientes-table tbody tr');
                if (rows[idx]) {
                    const input = rows[idx].querySelector('.ing-gramos');
                    if (input) { input.value = gramos; _actualizarTotalReceta(); }
                }
            }
        }
    } catch (e) { alert(`Error agregando ingrediente: ${e.message}`); }
}

async function guardarTodaReceta() {
    const rows = document.querySelectorAll('#ingredientes-table tbody tr[data-id]');
    if (!rows.length) { alert('No hay ingredientes para guardar.'); return; }

    // Leer todos los gramos
    const items = Array.from(rows).map(tr => ({
        id:     parseInt(tr.dataset.id),
        gramos: parseFloat(tr.querySelector('.ing-gramos').value) || 0,
    }));
    // Usar gramos redondeados para que el total sea exactamente la suma de enteros
    const itemsRedondeados = items.map(i => ({ ...i, gramos: Math.round(i.gramos) }));
    const nuevoTotal = itemsRedondeados.reduce((s, i) => s + i.gramos, 0);
    if (nuevoTotal <= 0) { alert('El total de gramos debe ser mayor a 0.'); return; }

    try {
        // 1. Actualizar peso_masa_g = suma exacta de gramos redondeados
        const resMasa = await apiFetch(`${API}/api/recetas/${recetaActivaNombre}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ peso_masa_g: nuevoTotal, descripcion: null }),
        });
        if (!resMasa.ok) throw new Error('Error actualizando peso del batch');

        // 2. Guardar ratio = gramos_redondeados / total (sin redondear el ratio)
        const resultados = await Promise.all(itemsRedondeados.map(item => {
            const ratio = item.gramos / nuevoTotal;
            return apiFetch(`${API}/api/recetas/${recetaActivaNombre}/ingredientes/${item.id}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ cantidad_por_kg_masa: ratio, unidad: 'kg' }),
            });
        }));
        const fallidos = resultados.filter(r => !r.ok).length;
        if (fallidos > 0) throw new Error(`${fallidos} ingrediente(s) no se guardaron correctamente`);

        _recetaPesoMasaG = nuevoTotal;
        alert(`✅ Receta guardada. Peso del batch: ${nuevoTotal} g`);
        await cargarRecetas();
    } catch (e) { alert(`Error guardando receta: ${e.message}`); }
}

async function eliminarIngrediente(idReceta) {
    if (!confirm('¿Eliminar este ingrediente?')) return;
    try {
        const res = await apiFetch(`${API}/api/recetas/${recetaActivaNombre}/ingredientes/${idReceta}`,
            { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const resD = await apiFetch(`${API}/api/recetas/${recetaActivaNombre}`);
        if (resD.ok) { const { ingredientes } = await resD.json(); renderIngredientes(ingredientes, _recetaPesoMasaG); }
    } catch (e) { alert(`Error eliminando ingrediente: ${e.message}`); }
}

// ── Productos ─────────────────────────────────────────────────────────────────

let productosFiltroTimer = null;

async function cargarProductos() {
    const tbody = document.querySelector('#productos-table tbody');
    tbody.innerHTML = '<tr><td colspan="8" class="loading">Cargando...</td></tr>';
    const soloActivos = document.getElementById('productos-solo-activos').checked;
    try {
        const params = new URLSearchParams();
        if (soloActivos) params.set('solo_activos', 'true');
        const res = await apiFetch(`${API}/api/productos?${params}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        todosLosProductos = await res.json();
        renderProductos(todosLosProductos);
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="8" class="error">Error: ${e.message}</td></tr>`;
    }
}

function renderProductos(lista) {
    const tbody = document.querySelector('#productos-table tbody');
    if (!lista.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="empty">Sin productos registrados</td></tr>';
        return;
    }
    tbody.innerHTML = lista.map(p => `
        <tr class="${!p.activo ? 'row-inactivo' : ''}">
            <td><strong>${p.nombre}</strong></td>
            <td>${p.tipo_pan}</td>
            <td>${p.peso_g}g</td>
            <td>${p.tipo_masa || '—'}</td>
            <td><strong>${formatMonto(p.precio_unitario)}</strong></td>
            <td>${p.paquete_cantidad ? `${p.paquete_cantidad} × ${p.paquete_tipo || '?'}` : '—'}</td>
            <td>${p.activo ? '✅' : '❌'}</td>
            <td>
                <button onclick="abrirModalEditarProducto(${p.id_producto})">✏️</button>
                <button class="${p.activo ? 'delete' : ''}" onclick="toggleProducto(${p.id_producto}, '${p.nombre.replace(/'/g, "\\'")}', ${p.activo})">
                    ${p.activo ? '🚫 Desact.' : '✅ Activar'}
                </button>
            </td>
        </tr>`).join('');
}

function filtrarProductos() {
    clearTimeout(productosFiltroTimer);
    productosFiltroTimer = setTimeout(() => {
        const q = document.getElementById('productos-search').value.toLowerCase();
        const filtrados = q
            ? todosLosProductos.filter(p =>
                p.nombre.toLowerCase().includes(q) ||
                p.tipo_pan.toLowerCase().includes(q) ||
                (p.tipo_masa || '').toLowerCase().includes(q))
            : todosLosProductos;
        renderProductos(filtrados);
    }, 250);
}

async function _cargarTiposMasaSelect(valorSeleccionado = '') {
    const sel = document.getElementById('prod-tipo-masa');
    sel.innerHTML = '<option value="">— Sin asignar —</option>';
    try {
        const res = await apiFetch(`${API}/api/recetas`);
        if (!res.ok) return;
        const recetas = await res.json();
        recetas.filter(r => r.activo).forEach(r => {
            const opt = document.createElement('option');
            opt.value = r.tipo_masa;
            opt.textContent = r.tipo_masa;
            if (r.tipo_masa === valorSeleccionado) opt.selected = true;
            sel.appendChild(opt);
        });
    } catch {}
}

async function abrirModalNuevoProducto() {
    productoActivoId = null;
    document.getElementById('modal-producto-titulo').textContent = 'Nuevo Producto';
    document.getElementById('prod-nombre').value       = '';
    document.getElementById('prod-tipo-pan').value     = '';
    document.getElementById('prod-peso').value         = '';
    document.getElementById('prod-precio').value       = '';
    document.getElementById('prod-paq-cantidad').value = '';
    document.getElementById('prod-paq-tipo').value     = '';
    await _cargarTiposMasaSelect('');
    abrirModal('modal-producto');
}

async function abrirModalEditarProducto(idProducto) {
    const p = todosLosProductos.find(x => x.id_producto === idProducto);
    if (!p) return;
    productoActivoId = idProducto;
    document.getElementById('modal-producto-titulo').textContent = `Editar: ${p.nombre}`;
    document.getElementById('prod-nombre').value       = p.nombre;
    document.getElementById('prod-tipo-pan').value     = p.tipo_pan;
    document.getElementById('prod-peso').value         = p.peso_g;
    document.getElementById('prod-precio').value       = parseFloat(p.precio_unitario).toFixed(2);
    document.getElementById('prod-paq-cantidad').value = p.paquete_cantidad || '';
    document.getElementById('prod-paq-tipo').value     = p.paquete_tipo || '';
    await _cargarTiposMasaSelect(p.tipo_masa || '');
    abrirModal('modal-producto');
}

async function guardarProducto() {
    const nombre   = document.getElementById('prod-nombre').value.trim();
    const tipoPan  = document.getElementById('prod-tipo-pan').value.trim().toUpperCase();
    const peso     = parseInt(document.getElementById('prod-peso').value);
    const precio   = parseFloat(document.getElementById('prod-precio').value);
    const tipoMasa = document.getElementById('prod-tipo-masa').value || null;
    const paqCant  = parseInt(document.getElementById('prod-paq-cantidad').value) || null;
    const paqTipo  = document.getElementById('prod-paq-tipo').value.trim() || null;

    if (!nombre || !tipoPan || !peso || isNaN(precio) || precio < 0) {
        alert('Nombre, Tipo Pan, Peso y Precio son obligatorios.'); return;
    }

    const body = {
        nombre, tipo_pan: tipoPan, peso_g: peso, precio_unitario: precio,
        tipo_masa: tipoMasa, paquete_cantidad: paqCant, paquete_tipo: paqTipo,
    };
    try {
        const url    = productoActivoId ? `${API}/api/productos/${productoActivoId}` : `${API}/api/productos`;
        const method = productoActivoId ? 'PUT' : 'POST';
        const res    = await apiFetch(url, {
            method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
        });
        if (!res.ok) { const err = await res.json(); throw new Error(err.detail || `HTTP ${res.status}`); }
        cerrarModal('modal-producto');
        await cargarProductos();
    } catch (e) { alert(`Error guardando producto: ${e.message}`); }
}

async function toggleProducto(idProducto, nombre, activo) {
    const accion = activo ? 'desactivar' : 'activar';
    if (!confirm(`¿${accion.charAt(0).toUpperCase() + accion.slice(1)} "${nombre}"?`)) return;
    try {
        const res = await apiFetch(`${API}/api/productos/${idProducto}`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        await cargarProductos();
    } catch (e) { alert(`Error: ${e.message}`); }
}

// ── Pagos ─────────────────────────────────────────────────────────────────────

let pagoDeudaActiva = null;
let _pagoIdClienteActivo = null;

async function abrirModalPago(idCliente, nombreCliente) {
    _pagoIdClienteActivo = idCliente;
    document.getElementById('modal-pago-titulo').textContent = `Deudas — ${nombreCliente}`;
    document.getElementById('pago-cliente-info').textContent = '';
    document.getElementById('pago-deudas-body').innerHTML =
        '<tr><td colspan="7" class="loading">Cargando...</td></tr>';
    document.getElementById('pago-form').classList.add('hidden');
    pagoDeudaActiva = null;
    abrirModal('modal-pago');

    try {
        const res = await apiFetch(`${API}/api/deudas/${idCliente}/detalle`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const { cliente, deudas } = await res.json();

        document.getElementById('pago-cliente-info').textContent =
            `📞 ${cliente.telefono || '—'}`;

        const ESTADO_COLOR = { pendiente: '#dc3545', parcial: '#fd7e14', pagado: '#28a745', anulado: '#6c757d' };
        const tbody = document.getElementById('pago-deudas-body');

        if (!deudas.length) {
            tbody.innerHTML = '<tr><td colspan="7" class="empty">Sin deudas registradas</td></tr>';
            return;
        }

        tbody.innerHTML = deudas.map(d => {
            const label = (d.descripcion_display || d.numero_recibo || 'Deuda').replace(/"/g, '&quot;');
            return `
            <tr>
                <td><strong>${d.descripcion_display || d.numero_recibo || '—'}</strong></td>
                <td>${formatFecha(d.fecha_pedido)}</td>
                <td>${formatMonto(d.monto_original)}</td>
                <td>${formatMonto(d.monto_pagado)}</td>
                <td style="font-weight:bold;color:${ESTADO_COLOR[d.estado] || '#333'}">
                    ${formatMonto(d.saldo_pendiente)}</td>
                <td><span style="color:${ESTADO_COLOR[d.estado]};font-weight:bold">${d.estado}</span></td>
                <td>${(d.estado !== 'pagado' && d.estado !== 'anulado')
                    ? `<button style="background:#28a745;padding:4px 10px"
                           data-id="${d.id_deuda}" data-label="${label}"
                           data-saldo="${d.saldo_pendiente}" data-original="${d.monto_original}"
                           data-pagado="${d.monto_pagado}"
                           onclick="abrirFormPagoBtn(this)">💳 Abonar</button>`
                    : '—'}</td>
            </tr>`;}).join('');
    } catch (e) {
        document.getElementById('pago-deudas-body').innerHTML =
            `<tr><td colspan="7" class="error">Error: ${e.message}</td></tr>`;
    }
}

let _pagoSaldoActual = 0;

function abrirFormPagoBtn(btn) {
    abrirFormPago(
        parseInt(btn.dataset.id),
        btn.dataset.label,
        parseFloat(btn.dataset.saldo),
        parseFloat(btn.dataset.original),
        parseFloat(btn.dataset.pagado)
    );
}

function abrirFormPago(idDeuda, numRecibo, saldo, montoOriginal, montoAbonado) {
    pagoDeudaActiva  = idDeuda;
    _pagoSaldoActual = parseFloat(saldo);
    document.getElementById('pago-recibo-label').textContent   = `#${numRecibo}`;
    document.getElementById('pago-original-label').textContent = formatMonto(montoOriginal);
    document.getElementById('pago-abonado-label').textContent  = formatMonto(montoAbonado);
    document.getElementById('pago-saldo-label').textContent    = formatMonto(saldo);
    document.getElementById('pago-monto').value                = '';
    document.getElementById('pago-metodo').value               = 'efectivo';
    document.getElementById('pago-preview-saldo').textContent  = '';
    document.getElementById('pago-form').classList.remove('hidden');
    document.getElementById('pago-form').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    setTimeout(() => document.getElementById('pago-monto').focus(), 150);
}

function _pagarTotal() {
    document.getElementById('pago-monto').value = _pagoSaldoActual.toFixed(2);
    _previsualizarAbono();
}

function _previsualizarAbono() {
    const monto   = parseFloat(document.getElementById('pago-monto').value) || 0;
    const nuevo   = _pagoSaldoActual - monto;
    const preview = document.getElementById('pago-preview-saldo');
    if (monto <= 0) { preview.textContent = ''; return; }
    if (monto > _pagoSaldoActual) {
        preview.innerHTML = `<span style="color:#dc3545">⚠️ El monto supera el saldo pendiente ($${_pagoSaldoActual.toFixed(2)})</span>`;
    } else if (nuevo <= 0) {
        preview.innerHTML = `<span style="color:#28a745">✅ Cancela la deuda completamente</span>`;
    } else {
        preview.innerHTML = `Saldo restante después del abono: <strong style="color:#fd7e14">$${nuevo.toFixed(2)}</strong>`;
    }
}

function cancelarFormPago() {
    pagoDeudaActiva = null;
    _pagoSaldoActual = 0;
    document.getElementById('pago-form').classList.add('hidden');
    document.getElementById('pago-preview-saldo').textContent = '';
}

async function confirmarPago() {
    if (!pagoDeudaActiva) return;
    const monto  = parseFloat(document.getElementById('pago-monto').value);
    const metodo = document.getElementById('pago-metodo').value;
    if (!monto || monto <= 0) { alert('Ingresa un monto válido.'); return; }

    try {
        const res = await apiFetch(`${API}/api/pagos`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_deuda: pagoDeudaActiva, monto_pagado: monto, metodo }),
        });
        if (!res.ok) { const err = await res.json(); throw new Error(err.detail || `HTTP ${res.status}`); }
        const data = await res.json();

        cancelarFormPago();

        // Refrescar el modal con los datos actualizados
        const nombre = document.getElementById('modal-pago-titulo').textContent.replace('Deudas — ', '');
        if (_pagoIdClienteActivo) await abrirModalPago(_pagoIdClienteActivo, nombre);

        // Refrescar tabla principal
        deudaPagina = 1;
        cargarDeudas();

        const nuevoSaldo = parseFloat(data.saldo_pendiente);
        const msg = nuevoSaldo <= 0
            ? `✅ Abono de $${monto.toFixed(2)} registrado.\n🎉 Deuda cancelada completamente.`
            : `✅ Abono de $${monto.toFixed(2)} registrado.\nSaldo restante: $${nuevoSaldo.toFixed(2)}`;
        alert(msg);
    } catch (e) { alert(`Error registrando pago: ${e.message}`); }
}

// ── Deuda Manual ─────────────────────────────────────────────────────────────
async function abrirModalDeudaManual() {
    const select = document.getElementById('dm-cliente');
    try {
        const res = await apiFetch(`${API}/api/clientes`);
        const data = await res.json();
        // /api/clientes devuelve array plano
        const clientes = Array.isArray(data) ? data : (data.items || []);
        select.innerHTML = '<option value="">— Seleccionar —</option>' +
            clientes.map(c => `<option value="${c.id_cliente}">${c.nombre_negocio}</option>`).join('');
    } catch (e) { alert('Error cargando clientes: ' + e.message); return; }
    document.getElementById('dm-descripcion').value = '';
    document.getElementById('dm-monto').value = '';
    document.getElementById('modal-deuda-manual').classList.remove('hidden');
}

async function guardarDeudaManual() {
    const id_cliente  = parseInt(document.getElementById('dm-cliente').value);
    const descripcion = document.getElementById('dm-descripcion').value.trim();
    const monto       = parseFloat(document.getElementById('dm-monto').value);

    if (!id_cliente)           { alert('Selecciona un cliente.'); return; }
    if (!descripcion)          { alert('Ingresa un concepto.'); return; }
    if (!monto || monto <= 0)  { alert('Ingresa un monto válido.'); return; }

    try {
        const res = await apiFetch(`${API}/api/deudas/manual`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_cliente, descripcion, monto_original: monto }),
        });
        if (!res.ok) { const err = await res.json(); throw new Error(err.detail || `HTTP ${res.status}`); }
        cerrarModal('modal-deuda-manual');
        deudaPagina = 1;
        cargarDeudas();
        alert(`✅ Deuda de $${monto.toFixed(2)} registrada correctamente.`);
    } catch (e) { alert('Error: ' + e.message); }
}

// ── Pedido Manual — Wizard (crear / editar) ───────────────────────────────────

let pedidoManualId          = null;
let pedidoCarrito           = [];   // [{tipo_pan, producto, peso_g, cantidad, precio_unitario}]
let pedidoProdActual        = null; // producto seleccionado en paso 2
let _prodsCatalogo          = [];   // caché de productos activos
let _clientesCargados       = false;
let _clientesCatalogo       = [];
let _clienteSeleccionado    = null;

function _mostrarPaso(id) {
    document.querySelectorAll('.pedido-paso').forEach(el => el.classList.add('hidden'));
    document.getElementById(id).classList.remove('hidden');
}

async function _cargarClientesSelectPedido() {
    if (_clientesCargados) return;
    try {
        const res = await apiFetch(`${API}/api/clientes`);
        if (!res.ok) return;
        const todos = await res.json();
        _clientesCatalogo = todos.filter(c => c.estado === 'activo');
        _clientesCargados = true;
    } catch {}
}

function pedidoFiltrarClientes() {
    const q = document.getElementById('pedido-cli-buscar').value.toLowerCase();
    const filtrados = q
        ? _clientesCatalogo.filter(c => c.nombre_negocio.toLowerCase().includes(q))
        : _clientesCatalogo;
    _renderListaClientes(filtrados);
}

function _renderListaClientes(lista) {
    const div = document.getElementById('pedido-cli-lista');
    if (!lista.length) {
        div.innerHTML = '<p class="empty" style="padding:10px">Sin clientes que coincidan.</p>';
        return;
    }
    div.innerHTML = lista.map(c => `
        <div onclick="pedidoSeleccionarCliente(${c.id_cliente}, '${c.nombre_negocio.replace(/'/g,"\\'")}' )"
             style="padding:9px 14px;cursor:pointer;border-bottom:1px solid #dee2e6;font-size:14px;
                    ${_clienteSeleccionado === c.id_cliente ? 'background:#e8edff;font-weight:bold' : ''}"
             onmouseover="this.style.background='#f0f4ff'" onmouseout="this.style.background='${_clienteSeleccionado === c.id_cliente ? '#e8edff' : ''}'">
            ${c.nombre_negocio}
            <span style="color:#999;font-size:12px"> · ${c.categoria}</span>
        </div>`).join('');
}

function pedidoSeleccionarCliente(id, nombre) {
    _clienteSeleccionado = id;
    document.getElementById('pedido-cliente-id').value = id;
    const box = document.getElementById('pedido-cli-seleccionado');
    box.style.display = 'block';
    box.innerHTML = `✅ <strong>${nombre}</strong>`;
    _renderListaClientes(
        document.getElementById('pedido-cli-buscar').value
            ? _clientesCatalogo.filter(c => c.nombre_negocio.toLowerCase().includes(document.getElementById('pedido-cli-buscar').value.toLowerCase()))
            : _clientesCatalogo
    );
}

async function _cargarProductosCatalogo() {
    if (_prodsCatalogo.length) return;
    try {
        const res = await apiFetch(`${API}/api/productos?solo_activos=true`);
        if (!res.ok) return;
        _prodsCatalogo = await res.json();
    } catch {}
}

function _renderCarritoMini() {
    const mini = document.getElementById('pedido-carrito-mini');
    if (!pedidoCarrito.length) { mini.style.display = 'none'; return; }
    const total = pedidoCarrito.reduce((s, i) => s + i.cantidad * i.precio_unitario, 0);
    mini.style.display = 'block';
    mini.innerHTML = `<strong>🛒 Carrito (${pedidoCarrito.length} prod.) — $${total.toFixed(2)}</strong><br>` +
        pedidoCarrito.map(i => `• ${i.producto} ×${i.cantidad} = $${(i.cantidad * i.precio_unitario).toFixed(2)}`).join('<br>');
}

function pedidoFiltrarProductos() {
    const q = document.getElementById('pedido-prod-buscar').value.toLowerCase();
    const filtrados = q
        ? _prodsCatalogo.filter(p =>
            p.nombre.toLowerCase().includes(q) ||
            p.tipo_pan.toLowerCase().includes(q))
        : _prodsCatalogo;
    _renderListaProductos(filtrados);
}

function _renderListaProductos(lista) {
    const div = document.getElementById('pedido-prod-lista');
    if (!lista.length) {
        div.innerHTML = '<p class="empty" style="padding:12px">Sin productos que coincidan.</p>';
        return;
    }
    div.innerHTML = lista.map(p => `
        <div onclick="pedidoSeleccionarProducto(${p.id_producto})"
             style="padding:10px 14px;cursor:pointer;border-bottom:1px solid #dee2e6;transition:background .15s"
             onmouseover="this.style.background='#f0f4ff'" onmouseout="this.style.background=''">
            <strong>${p.nombre}</strong>
            <span style="color:#666;font-size:13px"> — ${p.tipo_pan} · ${p.peso_g}g · <b>$${parseFloat(p.precio_unitario).toFixed(2)}</b></span>
        </div>`).join('');
}

// Paso 1 → abrir con cliente/fecha
async function abrirModalNuevoPedido() {
    pedidoManualId       = null;
    pedidoCarrito        = [];
    pedidoProdActual     = null;
    _clienteSeleccionado = null;
    document.getElementById('modal-pedido-titulo').textContent    = 'Nuevo Pedido';
    document.getElementById('pedido-cliente-id').value            = '';
    document.getElementById('pedido-cli-buscar').value            = '';
    document.getElementById('pedido-cli-seleccionado').style.display = 'none';
    await Promise.all([_cargarClientesSelectPedido(), _cargarProductosCatalogo()]);
    _renderListaClientes(_clientesCatalogo);
    _mostrarPaso('pedido-paso-cliente');
    abrirModal('modal-pedido');
}

async function abrirModalEditarPedido(idPedido) {
    pedidoManualId       = idPedido;
    pedidoCarrito        = [];
    pedidoProdActual     = null;
    _clienteSeleccionado = null;
    document.getElementById('modal-pedido-titulo').textContent = `Editar Pedido #${idPedido}`;
    await Promise.all([_cargarClientesSelectPedido(), _cargarProductosCatalogo()]);

    try {
        const res = await apiFetch(`${API}/api/pedidos/${idPedido}/detalles`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const { pedido, detalles } = await res.json();

        // Cliente fijo en edición
        _clienteSeleccionado = pedido.id_cliente;
        document.getElementById('pedido-cliente-id').value = pedido.id_cliente;
        const cli = _clientesCatalogo.find(c => c.id_cliente === pedido.id_cliente);
        const box = document.getElementById('pedido-cli-seleccionado');
        box.style.display = 'block';
        box.innerHTML = `✅ <strong>${cli ? cli.nombre_negocio : pedido.id_cliente}</strong> <em style="color:#999">(no editable)</em>`;
        document.getElementById('pedido-cli-buscar').disabled = true;
        document.getElementById('pedido-cli-lista').innerHTML = '';

        // fecha_entrega se calcula automáticamente en el backend

        pedidoCarrito = detalles.map(d => ({
            tipo_pan:         d.tipo_pan,
            producto:         d.producto,
            peso_g:           d.peso_g,
            cantidad:         d.cantidad,
            precio_unitario:  parseFloat(d.precio_unitario),
            tipo_unidad:      d.tipo_unidad || 'unidad',
            toping:           d.toping || null,
            paquete_cantidad: d.paquete_cantidad || 1,
        }));

        _renderResumen();
        _mostrarPaso('pedido-paso-resumen');
        abrirModal('modal-pedido');
    } catch (e) { alert(`Error cargando pedido: ${e.message}`); }
}

// Navegación entre pasos
function pedidoPaso1() {
    document.getElementById('pedido-cli-buscar').disabled = false;
    _mostrarPaso('pedido-paso-cliente');
}

function pedidoPaso2() {
    const idCliente = document.getElementById('pedido-cliente-id').value;
    if (!idCliente) { alert('Selecciona un cliente de la lista.'); return; }

    document.getElementById('pedido-prod-buscar').value = '';
    _renderListaProductos(_prodsCatalogo);
    _renderCarritoMini();
    _mostrarPaso('pedido-paso-producto');
}

function pedidoSeleccionarProducto(idProducto) {
    pedidoProdActual = _prodsCatalogo.find(p => p.id_producto === idProducto);
    if (!pedidoProdActual) return;

    const _paq = pedidoProdActual.paquete_cantidad || 1;
    const _esPaq = _paq > 1;
    const _unidadLabel = _esPaq ? 'paquetes' : 'unidades';
    const _precioLabel = _esPaq ? 'paquete' : 'unidad';
    const _paqDetalle  = _esPaq
        ? `<span style="color:#667eea;font-size:13px">📦 1 paquete = ${_paq} panes de ${pedidoProdActual.peso_g}g</span><br>`
        : '';

    document.getElementById('pedido-prod-seleccionado').innerHTML = `
        <strong style="font-size:16px">${pedidoProdActual.nombre}</strong><br>
        <span style="color:#555">${pedidoProdActual.tipo_pan} · ${pedidoProdActual.peso_g}g</span><br>
        ${_paqDetalle}
        <span style="color:#2C3E50;font-size:18px;font-weight:bold">$${parseFloat(pedidoProdActual.precio_unitario).toFixed(2)} / ${_precioLabel}</span>`;

    document.getElementById('pedido-cantidad-label').childNodes[0].textContent = `¿Cuántos ${_unidadLabel}? `;
    document.getElementById('pedido-cantidad').value = '';
    document.getElementById('pedido-subtotal-preview').textContent = '';
    _mostrarPaso('pedido-paso-cantidad');

    // Actualizar subtotal en vivo
    document.getElementById('pedido-cantidad').oninput = function() {
        const q = parseInt(this.value) || 0;
        const sub = q * parseFloat(pedidoProdActual.precio_unitario);
        const udsInfo = _esPaq ? ` (${q * _paq} uds)` : '';
        document.getElementById('pedido-subtotal-preview').textContent =
            q > 0 ? `Subtotal: $${sub.toFixed(2)}${udsInfo}` : '';
    };
    setTimeout(() => document.getElementById('pedido-cantidad').focus(), 80);
}

let _pedidoCantidadTemp = 0;
let _topingsCatalogo   = [];

function pedidoPaso3() {
    _mostrarPaso('pedido-paso-cantidad');
    setTimeout(() => document.getElementById('pedido-cantidad').focus(), 80);
}

async function pedidoPaso4Toping() {
    const cantidad = parseInt(document.getElementById('pedido-cantidad').value);
    if (!pedidoProdActual) { alert('Selecciona un producto primero.'); return; }
    if (!cantidad || cantidad < 1) { alert('Ingresa una cantidad válida.'); return; }
    _pedidoCantidadTemp = cantidad;

    // Cargar topings si no están cargados
    if (!_topingsCatalogo.length) {
        try {
            const r = await apiFetch(`${API}/api/topings`);
            _topingsCatalogo = r.ok ? (await r.json()).filter(t => t.activo) : [];
        } catch { _topingsCatalogo = []; }
    }

    const paq  = pedidoProdActual.paquete_cantidad || 1;
    const uds  = paq > 1 ? ` (${cantidad * paq} uds)` : '';
    document.getElementById('pedido-toping-prod').innerHTML =
        `<strong>${pedidoProdActual.nombre}</strong> · ${cantidad} ${paq > 1 ? 'paq' : 'uds'}${uds}`;

    const lista = document.getElementById('pedido-topings-lista');
    const todos = [..._topingsCatalogo.filter(t => t.nombre !== 'Sin toping'),
                   { id_toping: 0, nombre: 'Sin toping' }];
    lista.innerHTML = todos.map(t => `
        <button onclick="pedidoAgregarItem('${t.nombre.replace(/'/g,"\\'")}')"`
            + ` style="padding:12px;font-size:14px;background:${t.nombre==='Sin toping'?'#6c757d':'#667eea'};border-radius:8px">
            ${t.nombre}
        </button>`).join('');

    _mostrarPaso('pedido-paso-toping');
}

function pedidoAgregarItem(toping) {
    const cantidad = _pedidoCantidadTemp;
    if (!pedidoProdActual || !cantidad) return;

    const paqCant = pedidoProdActual.paquete_cantidad || 1;
    pedidoCarrito.push({
        tipo_pan:         pedidoProdActual.tipo_pan,
        producto:         pedidoProdActual.nombre,
        peso_g:           pedidoProdActual.peso_g,
        cantidad,
        paquete_cantidad: paqCant,
        tipo_unidad:      paqCant > 1 ? 'paquete' : 'unidad',
        precio_unitario:  parseFloat(pedidoProdActual.precio_unitario),
        toping:           toping === 'Sin toping' ? null : toping,
    });

    pedidoProdActual = null;
    _pedidoCantidadTemp = 0;
    _renderResumen();
    _mostrarPaso('pedido-paso-resumen');
}

function _renderResumen() {
    const lista = document.getElementById('pedido-resumen-lista');
    const total = pedidoCarrito.reduce((s, i) => s + i.cantidad * i.precio_unitario, 0);

    lista.innerHTML = pedidoCarrito.map((i, idx) => {
        const paq = i.paquete_cantidad || 1;
        const cantStr = paq > 1
            ? `${i.cantidad} paq <span style="opacity:.65;font-size:.88em">(${i.cantidad * paq} uds)</span>`
            : `${i.cantidad} uds`;
        const topingStr = i.toping ? `<span style="color:#667eea;font-size:12px">🌿 ${i.toping}</span>` : '';
        return `
        <div style="display:flex;justify-content:space-between;align-items:center;
                    padding:10px 12px;border-bottom:1px solid #dee2e6;font-size:14px">
            <div>
                <strong>${i.producto}</strong><br>
                <span style="color:#666">${i.peso_g}g · ${cantStr}</span>
                ${topingStr ? '<br>' + topingStr : ''}
            </div>
            <div style="display:flex;align-items:center;gap:10px">
                <strong>$${(i.cantidad * i.precio_unitario).toFixed(2)}</strong>
                <button class="delete" style="padding:2px 8px" onclick="pedidoQuitarItem(${idx})">🗑️</button>
            </div>
        </div>`;}).join('');

    document.getElementById('pedido-total-final').textContent = `$${total.toFixed(2)}`;
}

function pedidoQuitarItem(idx) {
    pedidoCarrito.splice(idx, 1);
    if (!pedidoCarrito.length) {
        // Carrito vacío → volver a seleccionar producto
        _renderCarritoMini();
        _renderListaProductos(_prodsCatalogo);
        _mostrarPaso('pedido-paso-producto');
    } else {
        _renderResumen();
    }
}

function pedidoAgregarOtro() {
    document.getElementById('pedido-prod-buscar').value = '';
    _renderListaProductos(_prodsCatalogo);
    _renderCarritoMini();
    _mostrarPaso('pedido-paso-producto');
}

async function guardarPedidoManual() {
    if (!pedidoCarrito.length) { alert('El pedido está vacío.'); return; }

    const idCliente       = parseInt(document.getElementById('pedido-cliente-id').value);
    if (!idCliente) { alert('Selecciona un cliente.'); return; }

    const lineas = pedidoCarrito.map(i => ({
        tipo_pan:        i.tipo_pan,
        producto:        i.producto,
        peso_g:          i.peso_g,
        cantidad:        i.cantidad,
        tipo_unidad:     i.tipo_unidad || 'unidad',
        precio_unitario: i.precio_unitario,
        toping:          i.toping || null,
    }));

    try {
        let res;
        if (pedidoManualId) {
            res = await apiFetch(`${API}/api/pedidos/${pedidoManualId}/editar`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ lineas }),
            });
        } else {
            res = await apiFetch(`${API}/api/pedidos/crear-manual`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id_cliente: idCliente, lineas }),
            });
        }
        if (!res.ok) { const err = await res.json(); throw new Error(err.detail || `HTTP ${res.status}`); }
        document.getElementById('pedido-cli-buscar').disabled = false;
        cerrarModal('modal-pedido');
        seccionCargada.delete('pedidos');
        cargarPedidos();
    } catch (e) { alert(`Error guardando pedido: ${e.message}`); }
}

// ── Topings ───────────────────────────────────────────────────────────────────

async function cargarTopings() {
    try {
        const res  = await apiFetch(`${API}/api/topings`);
        const rows = await res.json();
        const tbody = document.querySelector('#topings-table tbody');
        if (!rows.length) { tbody.innerHTML = '<tr><td colspan="3" class="empty">Sin topings registrados</td></tr>'; return; }
        tbody.innerHTML = rows.map(t => `
            <tr>
                <td><strong>${t.nombre}</strong></td>
                <td><span style="color:${t.activo ? '#28a745' : '#dc3545'}">${t.activo ? 'Activo' : 'Inactivo'}</span></td>
                <td>${t.activo ? `<button class="delete" onclick="eliminarToping(${t.id_toping})">🗑️ Eliminar</button>` : '—'}</td>
            </tr>`).join('');
    } catch (e) { console.error(e); }
}

function abrirModalNuevoToping() {
    document.getElementById('toping-nombre').value = '';
    document.getElementById('modal-nuevo-toping').classList.remove('hidden');
    setTimeout(() => document.getElementById('toping-nombre').focus(), 80);
}

async function guardarNuevoToping() {
    const nombre = document.getElementById('toping-nombre').value.trim();
    if (!nombre) { alert('Ingresa un nombre.'); return; }
    try {
        const res = await apiFetch(`${API}/api/topings`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ nombre }),
        });
        if (!res.ok) { const e = await res.json(); throw new Error(e.detail); }
        cerrarModal('modal-nuevo-toping');
        _topingsCatalogo = []; // reset cache
        cargarTopings();
    } catch (e) { alert('Error: ' + e.message); }
}

async function eliminarToping(id) {
    if (!confirm('¿Desactivar este toping?')) return;
    await apiFetch(`${API}/api/topings/${id}`, { method: 'DELETE' });
    _topingsCatalogo = [];
    cargarTopings();
}

// ── Producción con topings ────────────────────────────────────────────────────

async function verTopingsProduccion(fecha) {
    if (!fecha) { alert('Selecciona una fecha primero.'); return; }
    try {
        const res  = await apiFetch(`${API}/api/produccion/${fecha}/topings`);
        const rows = await res.json();
        if (!rows.length) { alert('Sin topings registrados para esta fecha.'); return; }

        // Agrupar por producto
        const porProducto = {};
        rows.forEach(r => {
            if (!porProducto[r.producto]) porProducto[r.producto] = [];
            porProducto[r.producto].push(r);
        });

        const html = Object.entries(porProducto).map(([prod, items]) => `
            <div style="margin-bottom:14px">
                <strong>${esc(prod)}</strong>
                <table style="width:100%;margin-top:6px;font-size:13px">
                    <thead><tr><th>Toping</th><th>Cliente</th><th style="text-align:right">Uds</th></tr></thead>
                    <tbody>${items.map(i => `
                        <tr>
                            <td>${esc(i.toping)}</td>
                            <td style="color:#555">${esc(i.cliente)}</td>
                            <td style="text-align:right">${esc(i.total_unidades)}</td>
                        </tr>`).join('')}
                    </tbody>
                </table>
            </div>`).join('');

        const win = window.open('', '_blank', 'width=700,height=600');
        win.document.write(`<html><head><title>Topings ${esc(fecha)}</title>
            <style>body{font-family:sans-serif;padding:20px}table{border-collapse:collapse;width:100%}
            th,td{border:1px solid #ddd;padding:6px 10px}th{background:#f0f4ff}</style></head>
            <body><h2>🌿 Topings — ${esc(fecha)}</h2>${html}
            <script>window.print()<\/script></body></html>`);
    } catch (e) { alert('Error: ' + e.message); }
}

// ── Imprimir producción ───────────────────────────────────────────────────────

async function imprimirProduccionPorMasa(fecha) {
    if (!fecha) { alert('Selecciona una fecha primero.'); return; }
    try {
        const [resPan] = await Promise.all([
            apiFetch(`${API}/api/produccion-detalle/${fecha}`),
        ]);
        const panes = resPan.ok ? await resPan.json() : [];
        if (!panes.length) { alert('Sin producción para esta fecha.'); return; }

        // Agrupar panes por tipo_masa
        const porMasa = {};
        panes.forEach(p => {
            const m = p.tipo_masa || 'Sin masa';
            if (!porMasa[m]) porMasa[m] = [];
            porMasa[m].push(p);
        });

        const panHtml = Object.entries(porMasa).map(([masa, items]) => {
            const totalUds = items.reduce((s, i) => s + Number(i.cantidad || 0), 0);
            return `<div style="page-break-inside:avoid;margin-bottom:20px;border:1px solid #ddd;border-radius:8px;padding:14px">
                <h3 style="margin:0 0 10px;color:#667eea">🍞 ${esc(masa)} — ${totalUds} uds</h3>
                <table style="width:100%;border-collapse:collapse;font-size:13px">
                    <thead><tr><th>Producto</th><th style="text-align:right">Paq</th><th style="text-align:right">Uds</th><th style="text-align:right">Peso(g)</th></tr></thead>
                    <tbody>${items.map(p => {
                        const paq = Number(p.paquete_cantidad) || 1;
                        const uds = Number(p.cantidad) || 0;
                        const paqCount = paq > 1 ? Math.round(uds / paq) : '—';
                        return `<tr><td>${esc(p.producto)}</td><td style="text-align:right">${paqCount}</td><td style="text-align:right">${uds}</td><td style="text-align:right">${esc(p.peso_g) || '—'}</td></tr>`;
                    }).join('')}</tbody>
                </table>
            </div>`;
        }).join('');

        const win = window.open('', '_blank', 'width=800,height=700');
        win.document.write(`<html><head><title>Producción por Masa ${esc(fecha)}</title>
            <style>body{font-family:sans-serif;padding:20px}th,td{border:1px solid #ddd;padding:5px 8px}th{background:#f0f4ff}@media print{.no-print{display:none}}</style></head>
            <body><h2>📦 Producción por Masa — ${esc(fecha)}</h2>${panHtml}
            <script>window.print()<\/script></body></html>`);
    } catch (e) { alert('Error: ' + e.message); }
}

async function imprimirProduccionPorCliente(fecha) {
    if (!fecha) { alert('Selecciona una fecha primero.'); return; }
    try {
        const res  = await apiFetch(`${API}/api/produccion/${fecha}/topings`);
        const rows = await res.json();

        // Agrupar por cliente
        const porCliente = {};
        rows.forEach(r => {
            if (!porCliente[r.cliente]) porCliente[r.cliente] = [];
            porCliente[r.cliente].push(r);
        });

        const html = Object.entries(porCliente).sort().map(([cli, items]) => `
            <div style="page-break-inside:avoid;margin-bottom:20px;border:1px solid #ddd;border-radius:8px;padding:14px">
                <h3 style="margin:0 0 10px">👤 ${esc(cli)}</h3>
                <table style="width:100%;border-collapse:collapse;font-size:13px">
                    <thead><tr><th>Producto</th><th>Toping</th><th style="text-align:right">Uds</th></tr></thead>
                    <tbody>${items.map(i => `
                        <tr><td>${esc(i.producto)}</td><td>${esc(i.toping)}</td><td style="text-align:right">${esc(i.total_unidades)}</td></tr>
                    `).join('')}</tbody>
                </table>
            </div>`).join('');

        const win = window.open('', '_blank', 'width=800,height=700');
        win.document.write(`<html><head><title>Producción por Cliente ${esc(fecha)}</title>
            <style>body{font-family:sans-serif;padding:20px}th,td{border:1px solid #ddd;padding:5px 8px}th{background:#f0f4ff}</style></head>
            <body><h2>👥 Producción por Cliente — ${esc(fecha)}</h2>${html}
            <script>window.print()<\/script></body></html>`);
    } catch (e) { alert('Error: ' + e.message); }
}

// ── Backup ────────────────────────────────────────────────────────────────────

async function descargarBackup() {
    const btn = document.querySelector('button[onclick="descargarBackup()"]');
    const textoOriginal = btn.textContent;
    btn.textContent = '⏳ Generando...';
    btn.disabled = true;
    try {
        const res = await apiFetch(`${API}/api/backup`);
        if (!res.ok) throw new Error('Error al generar backup');
        const blob = await res.blob();
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        const fecha = new Date().toISOString().slice(0,16).replace('T','_').replace(':','');
        a.href     = url;
        a.download = `backup_panificadora_${fecha}.sql`;
        a.click();
        URL.revokeObjectURL(url);
    } catch (e) {
        alert('Error al descargar backup: ' + e.message);
    } finally {
        btn.textContent = textoOriginal;
        btn.disabled = false;
    }
}

// ── Init ──────────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
    if (!localStorage.getItem('dashboard_token')) {
        window.location.href = '/';
        return;
    }
    seccionCargada.add('pedidos');
    cargarPedidos();
});
