#!/usr/bin/env bash
set -euo pipefail

for cmd in curl jq dig; do
  command -v "${cmd}" &>/dev/null || { echo "ERROR: '${cmd}' is required but not installed." >&2; exit 1; }
done

ENV_FILE="$(dirname "$0")/../.env"
if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: .env file not found at ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${DOMAIN:?Variable DOMAIN must be set in .env}"
: "${HOSTINGER_API_TOKEN:?Variable HOSTINGER_API_TOKEN must be set in .env}"
: "${DOKPLOY_API_TOKEN:?Variable DOKPLOY_API_TOKEN must be set in .env}"

TMPFILE1=$(mktemp /tmp/hostinger_dns_XXXXXX.json)
TMPFILE2=$(mktemp /tmp/hostinger_dns_XXXXXX.json)
trap 'rm -f "${TMPFILE1}" "${TMPFILE2}"' EXIT

HOSTINGER_BASE="https://developers.hostinger.com"
RECORD_NAME="ead"
RECORD_TTL=300

echo "=== TDS DNS Setup: ${RECORD_NAME}.${DOMAIN} ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Get server IP
# ---------------------------------------------------------------------------
echo "[1/4] Resolving server IP..."

# Try Dokploy API first
SERVER_IP=""
if command -v curl &>/dev/null; then
  DOKPLOY_RESP=$(curl -sf \
    -H "x-api-key: ${DOKPLOY_API_TOKEN}" \
    "https://dokploy.${DOMAIN}/api/server.getAll" 2>/dev/null || true)

  if [ -n "${DOKPLOY_RESP}" ]; then
    SERVER_IP=$(echo "${DOKPLOY_RESP}" | jq -r '.[0].ipAddress // empty' 2>/dev/null || true)
  fi

  # Fallback: settings.getServerIp
  if [ -z "${SERVER_IP}" ]; then
    SETTINGS_RESP=$(curl -sf \
      -H "x-api-key: ${DOKPLOY_API_TOKEN}" \
      "https://dokploy.${DOMAIN}/api/settings.getServerIp" 2>/dev/null || true)
    if [ -n "${SETTINGS_RESP}" ]; then
      SERVER_IP=$(echo "${SETTINGS_RESP}" | jq -r '.serverIp // empty' 2>/dev/null || true)
    fi
  fi
fi

# Fallback: resolve the root domain via DNS
if [ -z "${SERVER_IP}" ]; then
  echo "  Dokploy API unreachable — falling back to DNS resolution of ${DOMAIN}..."
  SERVER_IP=$(dig +short "${DOMAIN}" 2>/dev/null | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)
fi

if [ -z "${SERVER_IP}" ]; then
  echo "ERROR: Could not determine server IP. Set SERVER_IP manually in .env or ensure Dokploy is reachable." >&2
  exit 1
fi

if ! [[ "${SERVER_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Resolved IP '${SERVER_IP}' is not a valid IPv4 address." >&2
  exit 1
fi

echo "  Server IP: ${SERVER_IP}"
echo ""

# ---------------------------------------------------------------------------
# 2. Fetch current DNS zone records
# ---------------------------------------------------------------------------
echo "[2/4] Fetching current DNS records for ${DOMAIN}..."

ZONE_JSON=$(curl -sf \
  -H "Authorization: Bearer ${HOSTINGER_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "${HOSTINGER_BASE}/api/dns/v1/zones/${DOMAIN}" 2>/dev/null)

if [ -z "${ZONE_JSON}" ]; then
  echo "ERROR: Failed to fetch DNS zone for ${DOMAIN}. Check HOSTINGER_API_TOKEN." >&2
  exit 1
fi

echo "  Zone loaded. Total records: $(echo "${ZONE_JSON}" | jq 'length')"
echo ""

# ---------------------------------------------------------------------------
# 3. Check if the ead A record already exists (with correct IP)
# ---------------------------------------------------------------------------
echo "[3/4] Checking if '${RECORD_NAME}' A record exists..."

EXISTING=$(echo "${ZONE_JSON}" | jq -r \
  --arg name "${RECORD_NAME}" \
  '.[] | select(.name == $name and .type == "A") | .records[0].content' 2>/dev/null || true)

if [ "${EXISTING}" = "${SERVER_IP}" ]; then
  echo "  Record already up-to-date: ${RECORD_NAME}.${DOMAIN} → ${SERVER_IP} (TTL ${RECORD_TTL})"
  echo "  Nothing to do."
  echo ""
  echo "DNS setup complete: ${RECORD_NAME}.${DOMAIN} → ${SERVER_IP}"
  exit 0
elif [ -n "${EXISTING}" ]; then
  echo "  Record exists but points to ${EXISTING} — will update to ${SERVER_IP}"
else
  echo "  Record not found — will create it"
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Build full records array (preserving all existing records) and PUT
# ---------------------------------------------------------------------------
echo "[4/4] Applying DNS update..."

# Hostinger DNS API requires a full zone PUT (replace all records).
# Build the new records array: keep everything, upsert the ead A record.
NEW_RECORDS=$(echo "${ZONE_JSON}" | jq \
  --arg name "${RECORD_NAME}" \
  --arg ip   "${SERVER_IP}" \
  --argjson ttl "${RECORD_TTL}" \
  '
  # Remove existing ead A record if present, then append the new one
  [ .[] | select(not (.name == $name and .type == "A")) ]
  + [{
      "type": "A",
      "name": $name,
      "content": $ip,
      "ttl": $ttl
    }]
  ')

PUT_BODY=$(jq -n --argjson records "${NEW_RECORDS}" '{"overwrite": true, "records": $records}')

HTTP_STATUS=$(curl -s -o "${TMPFILE1}" -w "%{http_code}" \
  -X PUT \
  -H "Authorization: Bearer ${HOSTINGER_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${PUT_BODY}" \
  "${HOSTINGER_BASE}/api/dns/v1/zones/${DOMAIN}")

RESPONSE_BODY=$(cat "${TMPFILE1}" 2>/dev/null || echo "")

if [ "${HTTP_STATUS}" -ge 200 ] && [ "${HTTP_STATUS}" -lt 300 ]; then
  echo "  Success (HTTP ${HTTP_STATUS})"
elif [ "${HTTP_STATUS}" -eq 422 ]; then
  # Hostinger may return 422 when using the full-zone overwrite format.
  # Fall back to single-record POST/PUT approach.
  echo "  Full-zone PUT returned 422 — trying single-record upsert..."

  # Try POST to create a new record
  SINGLE_BODY=$(jq -n \
    --arg type "A" \
    --arg name "${RECORD_NAME}" \
    --arg content "${SERVER_IP}" \
    --argjson ttl "${RECORD_TTL}" \
    '{"type":$type,"name":$name,"content":$content,"ttl":$ttl}')

  HTTP_STATUS2=$(curl -s -o "${TMPFILE2}" -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${HOSTINGER_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${SINGLE_BODY}" \
    "${HOSTINGER_BASE}/api/dns/v1/zones/${DOMAIN}/records")

  RESPONSE_BODY2=$(cat "${TMPFILE2}" 2>/dev/null || echo "")

  if [ "${HTTP_STATUS2}" -ge 200 ] && [ "${HTTP_STATUS2}" -lt 300 ]; then
    echo "  Success (HTTP ${HTTP_STATUS2})"
  else
    echo "ERROR: DNS update failed (HTTP ${HTTP_STATUS2})." >&2
    echo "Response: ${RESPONSE_BODY2}" >&2
    exit 1
  fi
else
  echo "ERROR: DNS update failed (HTTP ${HTTP_STATUS})." >&2
  echo "Response: ${RESPONSE_BODY}" >&2
  exit 1
fi

echo ""
echo "DNS setup complete: ${RECORD_NAME}.${DOMAIN} → ${SERVER_IP}"
