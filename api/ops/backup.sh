#!/usr/bin/env sh
set -eu

APP_DIR=${APP_DIR:-/opt/tutor-tds-api}
BACKUP_DIR=${BACKUP_DIR:-"$APP_DIR/backups"}
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-14}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUTPUT="$BACKUP_DIR/tutor_tds_$STAMP.sql.gz"

case "$RETENTION_DAYS" in
  ''|*[!0-9]*)
    printf 'BACKUP_RETENTION_DAYS deve ser um inteiro positivo.\n' >&2
    exit 1
    ;;
esac
[ "$RETENTION_DAYS" -gt 0 ] || {
  printf 'BACKUP_RETENTION_DAYS deve ser maior que zero.\n' >&2
  exit 1
}

if [ -n "${BACKUP_AGE_RECIPIENT:-}" ]; then
  command -v age >/dev/null 2>&1 || {
    printf 'age não instalado; backup não será criado sem criptografia.\n' >&2
    exit 1
  }
fi

umask 077
mkdir -p "$BACKUP_DIR"
cd "$APP_DIR"

test ! -e "$OUTPUT" && test ! -e "$OUTPUT.age" || {
  printf 'Backup para este timestamp já existe: %s\n' "$OUTPUT" >&2
  exit 1
}

RAW_DUMP=$(mktemp "$BACKUP_DIR/.tutor_tds_${STAMP}.XXXXXX.sql")
COMPRESSED_TMP=$(mktemp "$BACKUP_DIR/.tutor_tds_${STAMP}.XXXXXX.sql.gz")
ENCRYPTED_TMP=""

cleanup() {
  rm -f "$RAW_DUMP" "$COMPRESSED_TMP"
  if [ -n "$ENCRYPTED_TMP" ]; then
    rm -f "$ENCRYPTED_TMP"
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 1' HUP INT TERM

docker compose -f docker-compose.production.yml exec -T db \
  pg_dump --clean --if-exists --no-owner --no-privileges \
  -U tutor_tds -d tutor_tds > "$RAW_DUMP"

test -s "$RAW_DUMP" || {
  printf 'pg_dump não produziu conteúdo; backup abortado.\n' >&2
  exit 1
}

gzip -9 -c "$RAW_DUMP" > "$COMPRESSED_TMP"
test -s "$COMPRESSED_TMP"
gzip -t "$COMPRESSED_TMP"
mv "$COMPRESSED_TMP" "$OUTPUT"

ARTIFACT="$OUTPUT"
if [ -n "${BACKUP_AGE_RECIPIENT:-}" ]; then
  ENCRYPTED_TMP=$(mktemp "$BACKUP_DIR/.tutor_tds_${STAMP}.XXXXXX.sql.gz.age")
  if ! age -r "$BACKUP_AGE_RECIPIENT" "$OUTPUT" > "$ENCRYPTED_TMP"; then
    rm -f "$OUTPUT"
    printf 'Falha ao criptografar; cópia sem criptografia removida.\n' >&2
    exit 1
  fi
  test -s "$ENCRYPTED_TMP" || {
    rm -f "$OUTPUT"
    printf 'Criptografia não produziu conteúdo; cópia sem criptografia removida.\n' >&2
    exit 1
  }
  mv "$ENCRYPTED_TMP" "$OUTPUT.age"
  ENCRYPTED_TMP=""
  ARTIFACT="$OUTPUT.age"
  rm -f "$OUTPUT"
fi

sha256sum "$ARTIFACT" > "$ARTIFACT.sha256"

if [ -n "${BACKUP_OFFSITE_DIR:-}" ]; then
  test -d "$BACKUP_OFFSITE_DIR" || {
    printf 'BACKUP_OFFSITE_DIR não está montado: %s\n' "$BACKUP_OFFSITE_DIR" >&2
    exit 1
  }
  cp "$ARTIFACT" "$ARTIFACT.sha256" "$BACKUP_OFFSITE_DIR/"
  cmp "$ARTIFACT" "$BACKUP_OFFSITE_DIR/$(basename "$ARTIFACT")"
fi

find "$BACKUP_DIR" -type f -name 'tutor_tds_*.sql.gz*' -mtime +"$RETENTION_DAYS" -delete
trap - EXIT HUP INT TERM
cleanup
printf 'Backup concluído e verificado: %s\n' "$(basename "$ARTIFACT")"
