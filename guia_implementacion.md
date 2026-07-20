# GUÍA DE IMPLEMENTACIÓN - Sistema Panificadora v1.0
## Bot Telegram + PostgreSQL + Google Drive + n8n

---

## ARCHIVOS DEL PROYECTO

| Archivo | Descripción |
|---|---|
| 1_schemas_completo.json | Estructura completa de la BD (referencia) |
| 2_queries_postgresql.sql | Script SQL: tablas, vistas, funciones |
| 3_docker_compose.yml | Servicios Docker: DB + n8n + Bot |
| 3b_env_example.txt | Variables de entorno (copiar como .env) |
| 4_telegram_bot_cliente.py | Bot clientes B2B (solo pedidos) |
| 5_telegram_bot_dueno.py | Bot admin interno (gestión completa) |
| 6_generador_recibos_pdf.py | PDF automático + subida a Drive |
| 7_requirements.txt | Dependencias Python |
| 8_guia_implementacion.md | Este archivo |

---

## PASO 1: INSTALAR DOCKER EN MAC

```bash
# Descargar Docker Desktop desde:
# https://www.docker.com/products/docker-desktop/

# Verificar instalación:
docker --version
docker compose version
```

---

## PASO 2: CREAR BOTS EN TELEGRAM

```
1. Abre Telegram → busca @BotFather
2. Escribe /newbot
3. Nombre: Panificadora Pedidos
4. Username: panificadora_pedidos_bot
5. Copia el TOKEN → lo usas en TELEGRAM_TOKEN

6. Repite para bot admin:
   Nombre: Panificadora Admin
   Username: panificadora_admin_bot
   Copia el TOKEN → lo usas en ADMIN_TELEGRAM_TOKEN
```

---

## PASO 3: CONFIGURAR VARIABLES DE ENTORNO

```bash
# Copiar el archivo de ejemplo
cp 3b_env_example.txt .env

# Editar con tus valores reales
nano .env
```

Valores que debes completar:
- DB_PASSWORD: elige un password seguro
- TELEGRAM_TOKEN: token del bot clientes
- ADMIN_TELEGRAM_TOKEN: token del bot admin
- ANTHROPIC_API_KEY: tu API key de Anthropic
- GOOGLE_DRIVE_FOLDER_ID: ID de la carpeta en Drive
- N8N_ENCRYPTION_KEY: genera 32 caracteres random

---

## PASO 4: LEVANTAR SERVICIOS EN MAC (Desarrollo)

```bash
# Crear carpeta del proyecto
mkdir panificadora_sistema
cd panificadora_sistema

# Copiar todos los archivos descargados aquí
# Crear archivo .env con tus valores

# Levantar con pgAdmin (para ver BD visualmente):
docker compose --profile dev up -d

# Verificar que todo corre:
docker compose ps

# Ver logs del bot:
docker compose logs -f telegram_bot
```

### Acceder a servicios:
| Servicio | URL | Credenciales |
|---|---|---|
| pgAdmin | http://localhost:5050 | Email y password del .env |
| n8n | http://localhost:5678 | Crear cuenta la primera vez |
| PostgreSQL | localhost:5432 | panif_user / DB_PASSWORD |

---

## PASO 5: BASE DE DATOS

El script SQL se ejecuta automáticamente al levantar Docker.
Para verificar:

```bash
docker exec -it panificadora_db psql -U panif_user -d panificadora

# Dentro de psql:
\dt                     # Ver todas las tablas
SELECT * FROM usuarios; # Ver el dueño registrado (@luisepm92)
\q                      # Salir
```

### Migrar clientes existentes:
El archivo 2_queries_postgresql.sql ya incluye los clientes visibles
en el listado. Agregar el resto directamente en pgAdmin:

```sql
INSERT INTO clientes (nombre_negocio, categoria, telegram_id) VALUES
('NOMBRE_CLIENTE', 'restaurante', '@telegram_cliente');
```

---

## PASO 6: CONFIGURAR GOOGLE DRIVE

```
1. Ir a: https://console.cloud.google.com/
2. Crear proyecto: "Panificadora"
3. Habilitar APIs:
   - Google Drive API
   - Google Sheets API
4. IAM & Admin → Service Accounts → Crear cuenta de servicio
5. Descargar JSON de credenciales
6. Guardar como: ./credentials/service_account.json
7. En Google Drive:
   - Crear carpeta "Recibos_Panificadora"
   - Compartir con el email de la cuenta de servicio
   - Copiar el ID de la URL → GOOGLE_DRIVE_FOLDER_ID en .env
```

### Estructura de carpetas Drive:
```
/Recibos_Panificadora/
  Recibo_2639_BURGER_GRILL_20260425.pdf
  Recibo_2640_SILVANOS_20260425.pdf
  ...
```

---

## PASO 7: OPERACION DIARIA

```
NOCHE ANTERIOR:
  Clientes hacen pedidos por Telegram hasta las 11pm
  → Bot registra en PostgreSQL automáticamente
  → Deudas se crean automáticamente
  → Recibo PDF se genera y envía al cliente

6AM (automático via n8n):
  → Consolida pedidos del día
  → Genera Sheet "Producción del Día"
  → Envía resumen a @luisepm92 por Telegram

DURANTE EL DÍA:
  /admin → Producción Hoy   (ver qué producir)
  /admin → Registrar Pago   (cuando cliente paga)
  /admin → Deudas           (consultar saldos)
  /admin → Clientes         (agregar/editar clientes)
```

---

## PASO 8: DEPLOY EN VPS UBUNTU (Producción)

```bash
# En el VPS Ubuntu:

# 1. Instalar Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 2. Copiar archivos al VPS
scp -r ./panificadora_sistema usuario@IP_VPS:/home/usuario/

# 3. Configurar .env con dominio real del VPS
nano .env
# Cambiar: N8N_HOST=tu_dominio.com

# 4. Levantar (sin pgAdmin en producción)
docker compose up -d

# 5. Verificar
docker compose ps
docker compose logs -f
```

---

## COMANDOS BOT CLIENTE

```
/start  → Bienvenida y verificación de cliente
/pedir  → Formulario interactivo de pedido
```

## COMANDOS BOT ADMIN (@luisepm92 y empleados)

```
/admin  → Panel principal con opciones:

👥 Clientes:
  → Agregar nuevo cliente
  → Listar todos los activos
  → Buscar cliente

📊 Deudas:
  → Resumen general + top deudores
  → Ver deuda de cliente específico

💰 Registrar Pago:
  → Busca cliente por nombre
  → Ingresa monto y método
  → Registra y actualiza saldo

📦 Producción Hoy:
  → Consolidado del día siguiente
  → Por tipo, peso y clientes

📈 Reportes:
  → Ventas del día
  → Ventas del mes
  → Top 3 deudores

⚙️ Empleados (solo dueño):
  → Agregar empleado con Telegram
  → Ver listado de usuarios
```

---

## COMANDOS ÚTILES

```bash
# Ver logs en tiempo real
docker compose logs -f

# Reiniciar bot
docker compose restart telegram_bot

# Backup de base de datos
docker exec panificadora_db pg_dump -U panif_user panificadora > backup_$(date +%Y%m%d).sql

# Restaurar backup
docker exec -i panificadora_db psql -U panif_user panificadora < backup_20260425.sql

# Ver estado de servicios
docker compose ps

# Parar todo
docker compose down

# Parar y borrar datos (CUIDADO)
docker compose down -v
```

---

## SOLUCIÓN DE PROBLEMAS

| Problema | Causa | Solución |
|---|---|---|
| Bot no responde | Bot caído | docker compose restart telegram_bot |
| Error de conexión BD | PostgreSQL no listo | docker compose logs postgres |
| PDF no se genera | Credenciales Drive | Verificar service_account.json |
| n8n no sincroniza | Credenciales incorrectas | Revisar en n8n UI |
| Cliente no puede pedir | Sin telegram_id en BD | Agregar via /admin → Clientes |
| "Acceso no autorizado" admin | Usuario no en tabla usuarios | Insertar en BD manualmente |

---

## MODELO IA UTILIZADO

| Componente | Modelo | Razón |
|---|---|---|
| Bot cliente (pedidos) | claude-haiku-4-5-20251001 | Rápido, barato, suficiente para lógica simple |
| Bot admin (gestión) | claude-sonnet-4-6 | Lógica compleja, validaciones, reportes |

Costo estimado: $4-5 USD/mes con 1000 interacciones/día

---

Sistema Panificadora v1.0 — @luisepm92
