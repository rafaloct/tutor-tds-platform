#!/usr/bin/env bash
# Reset completo do ambiente local (Issue #163): derruba containers, remove
# volume do banco Drupal, rebuilda a imagem e reinstala a partir do Git.
# Uso host: bash drupal/scripts/reset.sh
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose down -v --remove-orphans
docker compose build
docker compose up -d
docker compose exec web bash scripts/install-site.sh
docker compose exec web bash scripts/smoke.sh
echo "[reset] ambiente recriado"
