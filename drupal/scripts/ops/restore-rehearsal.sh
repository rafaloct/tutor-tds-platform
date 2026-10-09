#!/usr/bin/env bash
# Ensaio de restore descartavel (Issue #169): restaura um backup gerado por
# scripts/ops/backup.sh em um projeto Compose EFEMERO — novo volume, novo nome,
# porta propria — e prova que o mesmo portal sobe: smoke 5/5 + drift limpo.
# Criterio de aceite da Issue #169 sem depender do WordPress.
#
# Uso host (em drupal/):  bash scripts/ops/restore-rehearsal.sh <backup-dir> [--keep]
#   DRUPAL_RESTORE_PORT      porta HTTP do projeto descartavel (default: 18081)
#   DRUPAL_RESTORE_PROJECT   nome do projeto (default: tds-drupal-restore-<pid>)
#   COMPOSE_BUILDER          builder buildx caso a imagem precise ser buildada
#                            (hosts Windows/Docker Desktop com o bug containerd
#                            exigem builder docker-container, ex.: drupal163)
set -euo pipefail
cd "$(dirname "$0")/../.."

BACKUP_DIR="${1:?uso: restore-rehearsal.sh <backup-dir> [--keep]}"
KEEP=0
[ "${2:-}" = "--keep" ] && KEEP=1

log() { echo "[restore] $*"; }
fail() { echo "[restore] FAIL: $*" >&2; exit 1; }

[ -f "$BACKUP_DIR/db.sql.gz" ] || fail "$BACKUP_DIR/db.sql.gz ausente"
[ -f "$BACKUP_DIR/manifest.env" ] || fail "$BACKUP_DIR/manifest.env ausente"

if [ -f "$BACKUP_DIR/SHA256SUMS" ]; then
  (cd "$BACKUP_DIR" && sha256sum --check SHA256SUMS >/dev/null) \
    || fail "checksum SHA256SUMS nao confere em $BACKUP_DIR"
fi

PROJECT="${DRUPAL_RESTORE_PROJECT:-tds-drupal-restore-$$}"
export DRUPAL_HTTP_PORT="${DRUPAL_RESTORE_PORT:-18081}"
COMPOSE=(docker compose -p "$PROJECT" -f docker-compose.yml)

cleanup() {
  if [ "$KEEP" = "1" ]; then
    log "--keep: projeto $PROJECT preservado (http://localhost:$DRUPAL_HTTP_PORT)"
  else
    "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# A imagem da aplicacao e a mesma do portal (tutor-tds-drupal:local); builda se
# ausente. Em CI ela ja existe no stage anterior do verify-stack.sh.
if ! docker image inspect tutor-tds-drupal:local >/dev/null 2>&1; then
  log "imagem tutor-tds-drupal:local ausente; buildando"
  if [ -n "${COMPOSE_BUILDER:-}" ]; then
    "${COMPOSE[@]}" build --builder "$COMPOSE_BUILDER" web
  else
    "${COMPOSE[@]}" build web
  fi
fi

log "subindo db descartavel (projeto $PROJECT, porta $DRUPAL_HTTP_PORT)"
"${COMPOSE[@]}" up -d --wait db

log "aplicando dump no banco descartavel"
gzip -dc "$BACKUP_DIR/db.sql.gz" | "${COMPOSE[@]}" exec -T db sh -c \
  'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"'

log "subindo web descartavel (mesma imagem do portal)"
"${COMPOSE[@]}" up -d web

if [ -f "$BACKUP_DIR/files.tar.gz" ]; then
  log "restaurando arquivos do site"
  "${COMPOSE[@]}" exec -T web mkdir -p /var/www/html/web/sites/default/files
  "${COMPOSE[@]}" exec -T web tar -C /var/www/html/web/sites/default -xzf - < "$BACKUP_DIR/files.tar.gz"
  "${COMPOSE[@]}" exec -T web chown -R www-data:www-data /var/www/html/web/sites/default/files
fi

log "cache rebuild + aguardando Apache"
"${COMPOSE[@]}" exec -T web vendor/bin/drush cache:rebuild
"${COMPOSE[@]}" exec -T web bash -c \
  'for _ in $(seq 1 30); do curl -fsS -o /dev/null http://localhost/ && exit 0; sleep 2; done; exit 1' \
  || fail "Apache do projeto descartavel nao respondeu"

log "smoke no portal restaurado"
"${COMPOSE[@]}" exec -T web bash scripts/smoke.sh

log "drift de config no portal restaurado"
"${COMPOSE[@]}" exec -T web bash scripts/ci/config-drift.sh

echo "RESTORE REHEARSAL OK — backup $BACKUP_DIR sobe o mesmo portal (smoke + drift limpos)"
