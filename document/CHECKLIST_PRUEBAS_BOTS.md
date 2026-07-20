# ✅ CHECKLIST DE PRUEBAS - SISTEMA PANIFICADORA

## 🤖 BOT CLIENTE (@panificadora_pedidos_bot)

### 1️⃣ INICIO Y AUTENTICACION
- [ ] `/start` — responde con bienvenida
- [ ] Si NO estoy registrado → dice "No estás registrado"
- [ ] Si SÍ estoy registrado → muestra "Bienvenido [nombre_negocio]"
- [ ] Muestra fecha de entrega correcta (día siguiente)
- [ ] Botón "🍞 Realizar Pedido" es clickeable

### 2️⃣ FORMULARIO DE PEDIDO
- [ ] Click en "🍞 Realizar Pedido" → muestra lista de tipos de pan
- [ ] Puedo seleccionar un tipo de pan
- [ ] Después de seleccionar → muestra pesos disponibles para ese pan
- [ ] Puedo seleccionar un peso
- [ ] Después → me pide cantidad (escrito a mano)
- [ ] Ingreso cantidad → muestra resumen del artículo

### 3️⃣ CARRITO Y CONFIRMACION
- [ ] Después de agregar item → muestra resumen con:
  - Tipo de pan
  - Peso
  - Cantidad
  - Precio unitario
  - Subtotal
- [ ] Total acumulado es correcto
- [ ] Botón "➕ Agregar otro" funciona → vuelvo a paso 2
- [ ] Botón "✅ Confirmar pedido" funciona
- [ ] Botón "❌ Cancelar todo" funciona → cancela todo y vuelve al inicio

### 4️⃣ CONFIRMACION FINAL
- [ ] Después de confirmar → muestra:
  - ✅ PEDIDO CONFIRMADO
  - Número de recibo
  - Fecha de entrega
  - Monto total
- [ ] Dice "Tu recibo llegará en breve"
- [ ] **Recibo PDF se envía por Telegram** ← CRÍTICO
- [ ] PDF es descargable y abre correctamente

### 5️⃣ MULTIPLES PEDIDOS
- [ ] Puedo hacer un segundo pedido sin reiniciar bot
- [ ] Cada pedido genera número de recibo diferente
- [ ] Los números son consecutivos (2639, 2640, 2641...)

---

## 👨‍💼 BOT ADMIN (@panificadora_admin_bot)

### 1️⃣ MENU PRINCIPAL
- [ ] `/admin` → muestra panel administrativo
- [ ] Panel tiene opciones:
  - [ ] 👥 Clientes
  - [ ] 📊 Deudas
  - [ ] 💰 Registrar Pago
  - [ ] 📦 Producción Hoy
  - [ ] 📈 Reportes
  - [ ] ⚙️ Empleados (solo visible para dueño)

### 2️⃣ GESTION DE CLIENTES

#### 2A - Agregar Cliente
- [ ] Click "➕ Agregar Cliente"
- [ ] Pregunta: "¿Cuál es el nombre del negocio?"
- [ ] Ingreso nombre → confirma con checkmark ✅
- [ ] Pregunta: "¿Usuario de Telegram?"
- [ ] Ingreso @usuario o escrito "no"
- [ ] Pregunta: "¿Teléfono?"
- [ ] Ingreso teléfono o escrito "no"
- [ ] Muestra 4 botones de categoría (Restaurante, Cafetería, Market, Otro)
- [ ] Selecciono categoría
- [ ] **Muestra confirmación: "✅ Cliente agregado: [nombre]"** ← CRÍTICO
- [ ] Botón "🔙 Volver" o "🏠 Menú" aparece
- [ ] Vuelve a menú sin quedar atrapado

#### 2B - Listar Clientes
- [ ] Click "📋 Listar Activos"
- [ ] Muestra primeros 20 clientes activos con:
  - [ ] Nombre
  - [ ] Estado (✅ o ❌)
  - [ ] Categoría
- [ ] Botón "🔙 Volver" funciona

#### 2C - Buscar Cliente
- [ ] Click "🔍 Buscar Cliente"
- [ ] Escribo nombre de cliente
- [ ] Si existe → muestra detalles
- [ ] Si NO existe → **dice "❌ Cliente no encontrado"** + **botón "Reintentar" o "🔙 Volver"** ← CRÍTICO
- [ ] No me queda atrapado

### 3️⃣ GESTION DE DEUDAS

#### 3A - Resumen General
- [ ] Click "📊 Deudas"
- [ ] Muestra:
  - [ ] Número de clientes con deuda
  - [ ] Deuda total general
  - [ ] Número de clientes al día
  - [ ] Top 5 deudores con montos

#### 3B - Buscar Deuda de Cliente
- [ ] Click "🔍 Ver deuda de cliente"
- [ ] Escribo nombre del cliente
- [ ] Si existe → muestra:
  - [ ] Nombre
  - [ ] Deuda total
  - [ ] Número de pedidos pendientes
  - [ ] Último pedido (fecha)
- [ ] Si NO existe → **dice "❌ Cliente no encontrado"** + **botón "Reintentar"** ← CRÍTICO
- [ ] Botón "🔙 Volver" aparece en todo momento

### 4️⃣ REGISTRAR PAGO

#### 4A - Buscar Cliente
- [ ] Click "💰 Registrar Pago"
- [ ] Escribo nombre del cliente
- [ ] Si existe CON DEUDA → continúa
- [ ] Si existe SIN DEUDA → dice "sin deuda" + volver
- [ ] Si NO existe → **dice "❌ No encontrado"** + **reintentar**

#### 4B - Ver Deuda
- [ ] Muestra datos del cliente:
  - [ ] Nombre
  - [ ] Deuda total
  - [ ] Pedidos pendientes
  - [ ] Último pedido
- [ ] Pregunta: "¿Cuánto paga?"

#### 4C - Ingresar Monto
- [ ] Escribo monto (ej: 50.00)
- [ ] Si es 0 o negativo → dice "❌ Inválido, reintentar"
- [ ] Si es válido → muestra 3 botones de método:
  - [ ] 💵 Efectivo
  - [ ] 🏦 Transferencia
  - [ ] 📋 Otro

#### 4D - Confirmacion de Pago
- [ ] Selecciono método
- [ ] **Muestra confirmación: "✅ Pago Registrado"** ← CRÍTICO
- [ ] Muestra:
  - [ ] Cliente
  - [ ] Monto abonado
  - [ ] Método
  - [ ] Saldo pendiente actualizado
  - [ ] Quién registró (usuario admin)
- [ ] Botón "🔙 Menú Principal" funciona

### 5️⃣ PRODUCCION DEL DIA

- [ ] Click "📦 Producción Hoy"
- [ ] Muestra lista de items a producir para MAÑANA:
  - [ ] Tipo de pan
  - [ ] Producto
  - [ ] Peso
  - [ ] Total unidades
  - [ ] Peso total
  - [ ] Clientes que pidieron
- [ ] Si NO hay pedidos → dice "⚠️ Sin pedidos confirmados aún"
- [ ] Botón "🔙 Volver" funciona

### 6️⃣ REPORTES

- [ ] Click "📈 Reportes"
- [ ] Muestra:
  - [ ] **HOY:** número de pedidos y total ventas
  - [ ] **ESTE MES:** número de pedidos y total ventas
  - [ ] **TOP DEUDORES:** nombres con montos

### 7️⃣ EMPLEADOS (solo Dueño)

#### 7A - Listar Empleados
- [ ] Click "⚙️ Empleados"
- [ ] Muestra lista con:
  - [ ] Nombre
  - [ ] Usuario Telegram
  - [ ] Rol (DUENO o EMPLEADO)
  - [ ] Estado (✅ o ❌)

#### 7B - Agregar Empleado
- [ ] Click "➕ Agregar Empleado"
- [ ] Pregunta: "¿Nombre del empleado?"
- [ ] Ingreso nombre
- [ ] Pregunta: "¿Usuario de Telegram?"
- [ ] Ingreso @usuario
- [ ] **Muestra confirmación: "✅ Empleado agregado"** ← CRÍTICO
- [ ] Botón "🔙 Volver" funciona

### 8️⃣ FLUJOS GENERALES

#### 8A - Sin quedarse atrapado
- [ ] En CADA búsqueda sin resultado → botón "Reintentar" + "🔙 Volver"
- [ ] En CADA acción completada → confirmación + "🔙 Volver"
- [ ] NUNCA el bot se queda esperando sin opciones

#### 8B - Mensajes de Error
- [ ] Error de conexión BD → dice "❌ Error de conexión"
- [ ] Usuario no autorizado → dice "❌ Acceso no autorizado"
- [ ] Dato inválido → dice "❌ Por favor ingresa [formato correcto]"

#### 8C - Dinamismo
- [ ] Puedo hacer múltiples búsquedas sin reiniciar
- [ ] Puedo ir y venir entre menús sin problemas
- [ ] Los datos se actualizan en tiempo real
- [ ] `/admin` siempre te devuelve al menú principal

---

## 📊 BASE DE DATOS

### Verificar datos guardados:
```bash
docker exec -it panificadora_db psql -U panif_user -d panificadora
```

- [ ] Clientes creados aparecen en tabla `clientes`
- [ ] Pedidos creados aparecen en tabla `pedidos`
- [ ] Detalles de pedidos aparecen en tabla `detalle_pedidos`
- [ ] Deudas se crean automáticamente cuando confirmo pedido
- [ ] Pagos se registran en tabla `pagos`

---

## 📄 RECIBOS PDF

- [ ] PDF se genera automáticamente después de confirmar pedido
- [ ] PDF tiene:
  - [ ] Número de recibo
  - [ ] Fecha y hora
  - [ ] Nombre del cliente
  - [ ] Tabla con items (tipo pan, peso, cantidad, precio, subtotal)
  - [ ] Total final
  - [ ] Logo/nombre de la panificadora
- [ ] PDF se envía por Telegram al cliente
- [ ] PDF es descargable desde Telegram
- [ ] PDF se sube a Google Drive (si está configurado)

---

## 🚨 CASOS DE ERROR

Prueba estos escenarios para asegurar robustez:

### Bot Cliente:
- [ ] Escribir `/start` nuevamente sin terminar pedido → permite nuevo pedido
- [ ] Escribir número inválido en cantidad → dice "❌ Inválido"
- [ ] Escribir letra en cantidad → dice "❌ Inválido"
- [ ] Presionar botones fuera de orden → muestra error

### Bot Admin:
- [ ] Escribir nombre con caracteres especiales → funciona igual
- [ ] Escribir teléfono con letras → lo guarda igual
- [ ] Buscar cliente con nombre incompleto (ej "BURGER" en vez de "BURGER GRILL") → encuentra si contiene
- [ ] Registrar pago mayor a la deuda → lo registra pero actualiza estado a "pagado"

---

## ✅ RESUMEN FINAL

Cuando **todos** los puntos estén ✅:

1. **Bot Cliente:** ✅ Funciona sin errores
2. **Bot Admin:** ✅ Dinámico y sin quedarse atrapado
3. **Mensajes:** ✅ Confirmación en cada acción
4. **BD:** ✅ Los datos se guardan correctamente
5. **PDFs:** ✅ Se generan y envían a Telegram

**🎉 SISTEMA LISTO PARA PRODUCCIÓN**

---

**Imprime este checklist o úsalo en Telegram.**
**Marca cada punto conforme los pruebes.**
**Si algo falla, anótalo y avísame.**

¡Que te diviertas probando, Luis! 🚀
