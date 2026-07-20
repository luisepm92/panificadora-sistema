#!/bin/bash
# Backup diario de la BD panificadora
# Cron sugerido (cada día a las 3am):
#   0 3 * * * /Users/blackrave/panificadora_sistema/backup_diario.sh >> /Users/blackrave/panificadora_sistema/backups/backup.log 2>&1

BACKUP_DIR="/Users/blackrave/panificadora_sistema/backups"
FECHA=$(date +%Y%m%d_%H%M)
ARCHIVO="$BACKUP_DIR/backup_panificadora_$FECHA.sql"
RETENER_DIAS=30

mkdir -p "$BACKUP_DIR"

echo "[$FECHA] Iniciando backup..."

docker exec panificadora_db pg_dump \
    -U panif_user \
    -d panificadora \
    -F p \
    > "$ARCHIVO"

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$ARCHIVO" | cut -f1)
    echo "[$FECHA] Backup OK → $ARCHIVO ($SIZE)"
else
    echo "[$FECHA] ERROR al generar backup"
    rm -f "$ARCHIVO"
    exit 1
fi

# Borrar backups más viejos que RETENER_DIAS días
find "$BACKUP_DIR" -name "backup_panificadora_*.sql" -mtime +$RETENER_DIAS -delete
echo "[$FECHA] Limpieza: eliminados backups > $RETENER_DIAS días"
