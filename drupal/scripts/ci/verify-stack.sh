#!/usr/bin/env bash
# Verificacao isolada e deterministica da stack Drupal (Issue #169), num
# projeto Compose proprio: composer validate/audit -> build -> lint -> unit ->
# site:install -> smoke -> config drift -> backup -> restore rehearsal
# descartavel -> evidencia sanitizada. Nao toca o projeto local "tds-drupal"
# nem qualquer recurso externo (sem registry, DNS, staging ou producao).
#
# Uso host (em drupal/):  bash scripts/ci/verify-stack.sh
# Opcionais (env):
#   DRUPAL_CI_PROJECT=tds-drupal-ci    nome do projeto Compose de verificacao
#   DRUPAL_HTTP_PORT=18080             porta do stack de verificacao
#   DRUPAL_RESTORE_PORT=18081          porta do projeto de rehearsal
#   COMPOSE_BUILDER=drupal163          builder buildx (hosts Windows/Docker
#                                      Desktop com o bug containerd precisam de
#                                      um builder docker-container; omitido usa
#                                      o builder padrao, suficiente no CI)
#   SKIP_RESTORE_REHEARSAL=1           pula o ensaio de restore
set -euo pipefail
cd "$(dirname "$0")/../.."

PROJECT="${DRUPAL_CI_PROJECT:-tds-drupal-ci}"
export DRUPAL_HTTP_PORT="${DRUPAL_HTTP_PORT:-18080}"
export DRUPAL_RESTORE_PORT="${DRUPAL_RESTORE_PORT:-18081}"
COMPOSE=(docker compose -p "$PROJECT" -f docker-compose.yml)

cleanup() {
  "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

step() { printf '\n==== %s ====\n' "$*"; }

step "1/8 composer validate + audit"
bash scripts/ci/composer-validate.sh

step "2/8 docker build (projeto $PROJECT)"
if [ -n "${COMPOSE_BUILDER:-}" ]; then
  "${COMPOSE[@]}" build --builder "$COMPOSE_BUILDER" web
else
  "${COMPOSE[@]}" build web
fi

step "3/8 lint (php -l + phpcs + yaml + twig)"
"${COMPOSE[@]}" run --rm -T --no-deps web bash scripts/lint.sh

step "4/8 unit tests (phpunit)"
"${COMPOSE[@]}" run --rm -T --no-deps web vendor/bin/phpunit --configuration phpunit.xml.dist

step "5/8 up web+db + site:install a partir de config/sync"
"${COMPOSE[@]}" up -d
"${COMPOSE[@]}" exec -T web bash scripts/install-site.sh

step "6/8 smoke + config drift"
"${COMPOSE[@]}" exec -T web bash scripts/smoke.sh
"${COMPOSE[@]}" exec -T web bash scripts/ci/config-drift.sh

step "7/8 backup + restore rehearsal descartavel"
backup_dir="$(DRUPAL_COMPOSE_PROJECT="$PROJECT" bash scripts/ops/backup.sh | tail -1)"
log_line() { echo "[ci] $*"; }
log_line "backup gerado: $backup_dir"
if [ "${SKIP_RESTORE_REHEARSAL:-0}" != "1" ]; then
  bash scripts/ops/restore-rehearsal.sh "$backup_dir"
else
  log_line "SKIP_RESTORE_REHEARSAL=1 — ensaio de restore pulado"
fi

step "8/8 evidencia sanitizada"
DRUPAL_COMPOSE_PROJECT="$PROJECT" bash scripts/ops/evidence.sh "$backup_dir/evidence.md"
log_line "evidencia em $backup_dir/evidence.md"

echo
echo "VERIFY OK — composer, build, lint, unit, install, smoke, drift, backup+restore, evidencia"
