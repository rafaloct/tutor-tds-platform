#!/usr/bin/env bash
# Bootstrap local do portal Drupal Tutor TDS (Issue #163).
# A partir de um clone limpo: bash drupal/scripts/bootstrap.sh
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || cp .env.example .env
echo "[bootstrap] build das imagens"
docker compose build
echo "[bootstrap] subindo web + db (banco Drupal dedicado)"
docker compose up -d
echo "[bootstrap] instalando Drupal a partir de config/sync"
docker compose exec web bash scripts/install-site.sh
echo "[bootstrap] smoke"
docker compose exec web bash scripts/smoke.sh

echo "[bootstrap] portal disponivel em http://localhost:${DRUPAL_HTTP_PORT:-8080}"
