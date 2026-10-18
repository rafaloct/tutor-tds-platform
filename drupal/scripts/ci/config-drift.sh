#!/usr/bin/env bash
# Drift check de config (Issue #169): compara config/sync com a configuracao
# ativa do banco Drupal. Zero drift esperado apos site:install --existing-config.
#
# Uso host:    docker compose exec web bash scripts/ci/config-drift.sh
# Uso CI:      chamado por scripts/ci/verify-stack.sh no projeto isolado
# Dentro do container web (vendor/ + site instalado necessarios).
#
# DRUPAL_DRIFT_ALLOW="a.b,c.d"  allowlist explicita de configs cujo drift e
# documentado/aceito (default vazio = tolerancia zero). Use so com justificativa
# registrada em docs/drupal/DR8_OPERATIONS.md.
set -euo pipefail
cd /var/www/html

fail() { echo "[ci:drift] FAIL: $*" >&2; exit 1; }

json="$(vendor/bin/drush config:status --format=json 2>/dev/null)" \
  || fail "drush config:status falhou (site instalado?)"

# Normaliza: array/objeto vazio = sem drift. Cada entrada restante e um item
# com estado diferente entre sync dir e banco (Different, Only in DB,
# Only in sync dir).
drift="$(php -r '
  $d = json_decode(stream_get_contents(STDIN), TRUE);
  if (!is_array($d)) { fwrite(STDERR, "json invalido\n"); exit(2); }
  foreach ($d as $name => $row) {
    $state = is_array($row) && isset($row["state"]) ? $row["state"] : "?";
    echo $name, "\t", $state, "\n";
  }
' <<< "$json")" || fail "nao consegui interpretar config:status --format=json"

[ -n "$drift" ] || { echo "[ci:drift] OK — config/sync identico a config ativa"; exit 0; }

allow="${DRUPAL_DRIFT_ALLOW:-}"
unexpected=""
while IFS=$'\t' read -r name state; do
  [ -n "$name" ] || continue
  case ",$allow," in
    *,"$name",*) echo "[ci:drift] allowlist: $name ($state)" >&2 ;;
    *) unexpected+="$name"$'\t'"$state"$'\n' ;;
  esac
done <<< "$drift"

if [ -n "$unexpected" ]; then
  echo "[ci:drift] drift de config detectado:" >&2
  printf '%s' "$unexpected" >&2
  fail "config ativa diverge de config/sync"
fi

echo "[ci:drift] OK — drift somente em itens allowlisted"
