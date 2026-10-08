#!/usr/bin/env bash
# Instala o Drupal dentro do container web (Issue #163).
# Uso host: docker compose exec web bash scripts/install-site.sh
set -euo pipefail
cd /var/www/html

DB_HOST="${DRUPAL_DB_HOST:-db}"
DB_PORT="${DRUPAL_DB_PORT:-3306}"
DB_USER="${DRUPAL_DB_USER:-drupal}"
DB_PASS="${DRUPAL_DB_PASSWORD:-drupal-dev-only}"

echo "[install] aguardando banco Drupal em ${DB_HOST}:${DB_PORT}..."
for _ in $(seq 1 60); do
  if mariadb-admin ping -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --silent 2>/dev/null; then
    break
  fi
  sleep 2
done
mariadb-admin ping -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --silent >/dev/null

if vendor/bin/drush status --field=bootstrap 2>/dev/null | grep -qi 'Successful'; then
  echo "[install] site ja instalado; nada a fazer"
  exit 0
fi

if [ -f config/sync/core.extension.yml ]; then
  echo "[install] site:install a partir de config/sync (--existing-config)"
  vendor/bin/drush site:install --existing-config -y \
    --account-name "${DRUPAL_ADMIN_USER:-admin}" \
    --account-pass "${DRUPAL_ADMIN_PASSWORD:-admin-dev-only}"
else
  echo "[install] config/sync vazio; site:install minimal + modulos/tema da fundacao"
  vendor/bin/drush site:install minimal -y \
    --account-name "${DRUPAL_ADMIN_USER:-admin}" \
    --account-pass "${DRUPAL_ADMIN_PASSWORD:-admin-dev-only}" \
    --site-name "Tutor TDS Portal"
  # Sem export em config/sync, garante a fundacao minima do portal:
  # endpoint /health e tema base (espelho do que o --existing-config faria).
  vendor/bin/drush pm:install tds_health -y
  vendor/bin/drush theme:install tds_portal -y
  vendor/bin/drush config:set system.theme default tds_portal -y
fi

vendor/bin/drush cache:rebuild
echo "[install] concluido"
