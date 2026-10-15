#!/usr/bin/env bash
# Backup operacional do portal Drupal (Issue #169): dump do banco Drupal
# (MariaDB dedicado do servico "db", NUNCA o PostgreSQL do Tutor TDS),
# arquivos do site e snapshot de config/sync, com manifesto e SHA256SUMS.
#
# Saida: drupal/backups/<UTC-ts>/ — gitignored. ATENCAO: o artefato contem o
# banco do portal (conteudo editorial + sessoes). Trate como dado sensivel:
# nunca comitar, nunca enviar a servicos externos sem autorizacao (HUMAN-GATE).
#
# Uso host (em drupal/):  bash scripts/ops/backup.sh [dir-de-saida]
#   DRUPAL_COMPOSE_PROJECT  projeto Compose alvo (default: tds-drupal)
#
# stdout: ultima linha e o path do backup (para encadear com
# scripts/ops/restore-rehearsal.sh). Logs vao para stderr.
set -euo pipefail
cd "$(dirname "$0")/../.."

PROJECT="${DRUPAL_COMPOSE_PROJECT:-tds-drupal}"
COMPOSE=(docker compose -p "$PROJECT" -f docker-compose.yml)
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${1:-backups/$TS}"

log() { echo "[backup] $*" >&2; }
fail() { echo "[backup] FAIL: $*" >&2; exit 1; }

"${COMPOSE[@]}" ps --status running --services 2>/dev/null | grep -qx db \
  || fail "servico db nao esta rodando no projeto '$PROJECT'"
"${COMPOSE[@]}" ps --status running --services 2>/dev/null | grep -qx web \
  || fail "servico web nao esta rodando no projeto '$PROJECT'"

mkdir -p "$OUT"

log "dump do banco Drupal (mariadb-dump no container db; credenciais nunca saem para o host)"
"${COMPOSE[@]}" exec -T db sh -c \
  'mariadb-dump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --single-transaction --routines --events "$MYSQL_DATABASE"' \
  | gzip -9 > "$OUT/db.sql.gz"
[ -s "$OUT/db.sql.gz" ] || fail "dump vazio"

log "arquivos do site (web/sites/default/files)"
if "${COMPOSE[@]}" exec -T web test -d /var/www/html/web/sites/default/files; then
  "${COMPOSE[@]}" exec -T web tar -C /var/www/html/web/sites/default -czf - files > "$OUT/files.tar.gz"
else
  tar -czf "$OUT/files.tar.gz" -T /dev/null
fi

log "snapshot de config/sync"
tar -C . -czf "$OUT/config.tar.gz" config

drupal_version="$("${COMPOSE[@]}" exec -T web vendor/bin/drush status --field=drupal-version 2>/dev/null | tr -d '[:space:]' || true)"
{
  echo "# Backup portal Drupal Tutor TDS — contem dados sensiveis do portal."
  echo "# Nunca comitar nem enviar a servicos externos (HUMAN-GATE)."
  echo "backup_version=1"
  echo "created_utc=$TS"
  echo "compose_project=$PROJECT"
  echo "git_head=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "git_branch=$(git branch --show-current 2>/dev/null || echo unknown)"
  echo "drupal_version=${drupal_version:-unknown}"
} > "$OUT/manifest.env"

(cd "$OUT" && sha256sum db.sql.gz files.tar.gz config.tar.gz > SHA256SUMS)

log "concluido: $OUT ($(du -sh "$OUT" | cut -f1))"
echo "$OUT"
