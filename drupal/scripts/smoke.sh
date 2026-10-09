#!/usr/bin/env bash
# Smoke do portal Drupal (Issue #163): executar dentro do container web.
# Uso host: docker compose exec web bash scripts/smoke.sh
set -euo pipefail
cd /var/www/html

BASE_URL="${BASE_URL:-http://localhost}"
EXPECTED_DB="${DRUPAL_DB_NAME:-drupal}"

fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }

echo "[smoke] 1/5 pagina inicial responde"
code=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/")
[ "$code" = "200" ] || fail "home retornou HTTP $code"

echo "[smoke] 2/5 endpoint /health (JSON ok + Cache-Control: no-store)"
health_headers=$(mktemp)
body=$(curl -fsS -D "$health_headers" "$BASE_URL/health") || { rm -f "$health_headers"; fail "/health inacessivel"; }
echo "$body" | grep -q '"status":"ok"' || { rm -f "$health_headers"; fail "health inesperado: $body"; }
grep -qiE '^Cache-Control:[^\r\n]*no-store' "$health_headers" \
  || { rm -f "$health_headers"; fail "/health sem Cache-Control: no-store"; }
rm -f "$health_headers"

echo "[smoke] 3/5 bootstrap Drupal"
vendor/bin/drush status --field=bootstrap | grep -qi 'Successful' \
  || fail "drush status bootstrap != Successful"

echo "[smoke] 4/5 banco Drupal isolado e contem apenas schema Drupal"
db_name=$(vendor/bin/drush sql:query "SELECT DATABASE()" | tr -d '[:space:]')
[ "$db_name" = "$EXPECTED_DB" ] || fail "banco conectado: '$db_name' (esperado '$EXPECTED_DB')"
tables=$(vendor/bin/drush sql:query "SHOW TABLES")
count=$(echo "$tables" | grep -c .)
[ "$count" -gt 30 ] || fail "apenas $count tabelas no banco Drupal"
for marker in config key_value users router watchdog; do
  echo "$tables" | grep -qx "$marker" || fail "tabela Drupal '$marker' ausente"
done
dbs=$(vendor/bin/drush sql:query "SHOW DATABASES" | grep -vE '^(information_schema|mysql|performance_schema|sys)$' || true)
[ "$dbs" = "$EXPECTED_DB" ] || fail "bancos extras no servidor Drupal: $dbs"

echo "[smoke] 5/5 nenhuma referencia ao PostgreSQL Tutor"
# Ignora linhas de comentario/docblock e comentarios inline "//": documentar a
# proibicao no docblock nao configura conexao alguma.
stripped=$(sed -e 's://.*$::' -e '/^[[:space:]]*[*#]/d' web/sites/default/settings.php)
if echo "$stripped" | grep -iEq 'pgsql|postgres|tutor.*db'; then
  fail "settings.php referencia PostgreSQL/Tutor"
fi
[ -z "${TUTOR_DATABASE_URL:-}" ] || fail "TUTOR_DATABASE_URL nao deve existir no portal"

echo "SMOKE OK — home 200, /health ok, banco '$db_name' com $count tabelas Drupal"
