# 🐳 COMANDOS DOCKER ÚTILES - Sistema Panificadora

## 🚀 LEVANTAMIENTO Y PARADA

### Levantar todos los servicios (desarrollo con pgAdmin)
```bash
cd ~/panificadora_sistema
docker compose --profile dev up -d
```

### Levantar solo los servicios críticos (sin pgAdmin)
```bash
docker compose up -d
```

### Ver estado de todos los servicios
```bash
docker compose ps
```

### Parar todos los servicios (sin borrar datos)
```bash
docker compose down
```

### Parar y BORRAR TODOS LOS DATOS (cuidado!)
```bash
docker compose down -v
```

---

## 📊 VER LOGS

### Ver logs en tiempo real del bot
```bash
docker compose logs -f telegram_bot
```

### Ver últimos 50 logs del bot
```bash
docker compose logs --tail=50 telegram_bot
```

### Ver logs de PostgreSQL
```bash
docker compose logs -f postgres
```

### Ver logs de n8n
```bash
docker compose logs -f n8n
```

### Ver TODOS los logs de todos los servicios
```bash
docker compose logs -f
```

---

## 🗄️ BASE DE DATOS

### Entrar a la BD con psql
```bash
docker exec -it panificadora_db psql -U panif_user -d panificadora
```

### Ver todas las tablas
```bash
docker exec -it panificadora_db psql -U panif_user -d panificadora -c "\dt"
```

### Ver todos los usuarios (admin)
```bash
docker exec -it panificadora_db psql -U panif_user -d panificadora -c "SELECT * FROM usuarios;"
```

### Ver todos los clientes
```bash
docker exec -it panificadora_db psql -U panif_user -d panificadora -c "SELECT id_cliente, nombre_negocio, estado FROM clientes LIMIT 20;"
```

### Ver todos los pedidos de hoy
```bash
docker exec -it panificadora_db psql -U panif_user -d panificadora -c "SELECT * FROM pedidos WHERE DATE(fecha_pedido) = CURRENT_DATE;"
```

### Ver deuda total por cliente
```bash
docker exec -it panificadora_db psql -U panif_user -d panificadora -c "SELECT nombre_negocio, deuda_total FROM vista_deuda_clientes ORDER BY deuda_total DESC;"
```

### Hacer backup de la BD
```bash
docker exec panificadora_db pg_dump -U panif_user panificadora > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restaurar backup
```bash
docker exec -i panificadora_db psql -U panif_user panificadora < backup_20260426_105900.sql
```

---

## 🔄 REINICIAR SERVICIOS

### Reiniciar solo el bot
```bash
docker compose restart telegram_bot
```

### Reiniciar la BD
```bash
docker compose restart postgres
```

### Reiniciar n8n
```bash
docker compose restart n8n
```

### Reiniciar todo
```bash
docker compose restart
```

---

## 🧹 LIMPIEZA Y MANTENIMIENTO

### Ver uso de disco
```bash
docker system df
```

### Eliminar imágenes no usadas
```bash
docker image prune -a
```

### Eliminar volúmenes no usados
```bash
docker volume prune
```

### Ver todo lo que está corriendo
```bash
docker ps -a
```

---

## 🚨 TROUBLESHOOTING

### Si Docker no responde
```bash
# Verificar si el daemon está corriendo
docker ps

# Si no está, abre Docker Desktop o inicia el daemon
# En Mac: abre Docker.app desde Applications
```

### Si un servicio falla al levantarse
```bash
# Ver por qué falló
docker compose logs postgres  # o cualquier otro servicio

# Limpiar y reintentar
docker compose down -v
docker compose --profile dev up -d
```

### Si la BD está corrupta
```bash
# Parar todo
docker compose down -v

# Levantar nuevamente (se recreará la BD desde el SQL)
docker compose --profile dev up -d
```

---

## 📱 ACCESO A SERVICIOS

| Servicio | URL | Usuario |
|---|---|---|
| pgAdmin | http://localhost:5050 | luis.porras.1992@gmail.com / [password] |
| n8n | http://localhost:5678 | [Cualquiera, primera vez crea cuenta] |
| PostgreSQL | localhost:5432 | panif_user / [DB_PASSWORD] |

---

## ✅ CHECKLIST DIARIO

Cada mañana:
```bash
cd ~/panificadora_sistema

# 1. Ver si todo sigue corriendo
docker compose ps

# 2. Ver logs del bot (últimas horas)
docker compose logs --tail=100 telegram_bot

# 3. Verificar BD
docker exec -it panificadora_db psql -U panif_user -d panificadora -c \
  "SELECT COUNT(*) as total_pedidos FROM pedidos WHERE DATE(fecha_pedido) = CURRENT_DATE;"
```

