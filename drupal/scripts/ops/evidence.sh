#!/usr/bin/env bash
# Evidencia operacional sanitizada do portal Drupal (Issue #169): saude
# (/health), versao (drush status, campos allowlisted), containers e imagem,
# em Markdown. NUNCA coleta env vars, segredos, CPF, tokens ou payload
# academico — somente campos de uma allowlist fixa.
#
# Uso host (em drupal/):  bash scripts/ops/evidence.sh [saida.md]
#   DRUPAL_COMPOSE_PROJECT  projeto Compose alvo (default: tds-drupal)
#   DRUPAL_HTTP_PORT        porta publicada do portal (default: 8080)
set -euo pipefail
cd "$(dirname "$0")/../.."

PROJECT="${DRUPAL_COMPOSE_PROJECT:-tds-drupal}"
COMPOSE=(docker compose -p "$PROJECT" -f docker-compose.yml)
BASE_URL="http://127.0.0.1:${DRUPAL_HTTP_PORT:-8080}"
OUT="${1:-}"

[ -n "$OUT" ] && : > "$OUT"
emit() { if [ -n "$OUT" ]; then printf '%s\n' "$*" >> "$OUT"; else printf '%s\n' "$*"; fi; }

# Campos permitidos do drush status — allowlist fixa, nada de db-name/user/host.
DRUSH_FIELDS='drupal-version bootstrap db-driver php-version drush-version'

status_json="$("${COMPOSE[@]}" exec -T web vendor/bin/drush status --format=json 2>/dev/null || echo '{}')"
status_kv="$("${COMPOSE[@]}" exec -T -e DRUSH_FIELDS="$DRUSH_FIELDS" web php -r '
  $fields = explode(" ", getenv("DRUSH_FIELDS") ?: "");
  $d = json_decode(stream_get_contents(STDIN), TRUE);
  if (!is_array($d)) { $d = []; }
  foreach ($fields as $f) { echo $f, "=", $d[$f] ?? "n/a", "\n"; }
' <<< "$status_json")" || status_kv=""

hdr="$(mktemp)"; body="$(mktemp)"
health_code="$(curl -sS -o "$body" -D "$hdr" -w '%{http_code}' "$BASE_URL/health" 2>/dev/null || echo 000)"
health_cc="$(grep -i '^Cache-Control:' "$hdr" 2>/dev/null | tr -d '\r' | sed 's/^Cache-Control: *//I' || true)"
health_body="$(tr -d '\r\n' < "$body")"
rm -f "$hdr" "$body"

image_id="$(docker image inspect tutor-tds-drupal:local --format '{{.Id}}' 2>/dev/null || echo 'unknown')"
ps_rows="$("${COMPOSE[@]}" ps --format '{{.Name}}|{{.Service}}|{{.Status}}' 2>/dev/null || echo 'unavailable')"
dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

emit "# Evidencia operacional — portal Drupal Tutor TDS"
emit ""
emit "- timestamp_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
emit "- git_head: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
emit "- git_branch: $(git branch --show-current 2>/dev/null || echo unknown)"
emit "- git_dirty_files: $dirty"
emit "- compose_project: $PROJECT"
emit "- image: tutor-tds-drupal:local ($image_id)"
emit ""
emit "## Containers"
emit ""
emit '```'
emit "$ps_rows"
emit '```'
emit ""
emit "## /health ($BASE_URL)"
emit ""
emit "- http_status: $health_code"
emit "- cache_control: ${health_cc:-ausente}"
emit '- body: `'"$health_body"'`'
emit ""
emit "## Versao (drush status — allowlist: $DRUSH_FIELDS)"
emit ""
emit '```'
emit "$status_kv"
emit '```'
emit ""
emit "Sanitizacao: allowlist fixa de campos; nenhum env, segredo, CPF, token ou"
emit "payload academico e coletado. Saida segura para anexar a PR/Issue."
