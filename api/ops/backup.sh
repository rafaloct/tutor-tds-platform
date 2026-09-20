#!/usr/bin/env sh
set -eu

APP_DIR=/opt/tutor-tds-api
BACKUP_DIR="$APP_DIR/backups"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUTPUT="$BACKUP_DIR/tutor_tds_$STAMP.sql.gz"

umask 077
mkdir -p "$BACKUP_DIR"
cd "$APP_DIR"

docker compose -f docker-compose.production.yml exec -T db \
  pg_dump --clean --if-exists --no-owner --no-privileges \
  -U tutor_tds -d tutor_tds | gzip -9 > "$OUTPUT"

gzip -t "$OUTPUT"
find "$BACKUP_DIR" -type f -name 'tutor_tds_*.sql.gz' -mtime +14 -delete
printf 'Backup concluído: %s\n' "$(basename "$OUTPUT")"
