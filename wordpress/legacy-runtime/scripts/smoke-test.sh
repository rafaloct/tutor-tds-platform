#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${DOMAIN:?ERROR: DOMAIN must be set in .env}"
: "${TDS_API_KEY:?ERROR: TDS_API_KEY must be set in .env}"

BASE="https://ead.${DOMAIN}"
API="${BASE}/wp-json/tds/v1"
PASS=0; FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  OK  $desc"
    PASS=$((PASS+1))
  else
    echo "  FAIL $desc (got: $actual, want: $expected)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== TDS LMS Smoke Tests ==="
echo "Base URL: $BASE"
echo ""

# Site up
check "Site responds 200" "200" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE" || echo "000")"

# WP REST API reachable
check "WP REST API up" "200" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE/wp-json" || echo "000")"

# Auth — no key returns 403
check "API rejects no key" "403" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$API/courses" || echo "000")"

# Auth — correct key returns 200
check "API accepts correct key" "200" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "X-API-Key: ${TDS_API_KEY}" "$API/courses" || echo "000")"

# Verify endpoint public (no auth), 404 = cert not found = endpoint is working
check "Verify endpoint public (no auth needed)" "404" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$API/verify/0000000000000000000000000000000000000000000000000000000000000000" || echo "000")"

# Key pages load
check "/minha-area loads" "200" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE/minha-area/" || echo "000")"
check "/cursos loads" "200" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE/cursos/" || echo "000")"
check "/certificados loads" "200" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE/certificados/" || echo "000")"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
