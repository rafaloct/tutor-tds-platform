#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Prerequisites check
# ---------------------------------------------------------------------------
for cmd in curl jq; do
  command -v "${cmd}" &>/dev/null || { echo "ERROR: '${cmd}' is required but not installed." >&2; exit 1; }
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: .env file not found at ${ENV_FILE}" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

: "${DOKPLOY_API_TOKEN:?Variable DOKPLOY_API_TOKEN must be set in .env}"
: "${DOMAIN:?Variable DOMAIN must be set in .env}"

# Dokploy API is exposed on port 3000. Set DOKPLOY_HOST in .env to override.
# Default uses direct IP because the hostname may not resolve from deploy machines.
DOKPLOY_HOST="${DOKPLOY_HOST:-http://46.202.150.132:3000}"
DOKPLOY_BASE="${DOKPLOY_HOST}/api"
PROJECT_NAME="ead-wordpress"
COMPOSE_NAME="ead-wordpress-stack"
TARGET_DOMAIN="ead.${DOMAIN}"
COMPOSE_FILE="${SCRIPT_DIR}/../docker-compose.yml"

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "ERROR: docker-compose.yml not found at ${COMPOSE_FILE}" >&2
  exit 1
fi

# Named temp files with cleanup
TMPFILE=$(mktemp /tmp/dokploy_setup_XXXXXX.json)
trap 'rm -f "${TMPFILE}"' EXIT

# Helper: Dokploy GET
dokploy_get() {
  curl -sf -H "x-api-key: ${DOKPLOY_API_TOKEN}" "${DOKPLOY_BASE}/${1}" 2>/dev/null
}

# Helper: Dokploy POST (body as second arg)
dokploy_post() {
  curl -sf -X POST \
    -H "x-api-key: ${DOKPLOY_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${2}" \
    "${DOKPLOY_BASE}/${1}"
}

echo "=== TDS Dokploy Setup: ${TARGET_DOMAIN} ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Get or create project
# ---------------------------------------------------------------------------
echo "[1/6] Checking for existing project '${PROJECT_NAME}'..."

PROJECTS=$(dokploy_get "project.all")
PROJECT_ID=$(echo "${PROJECTS}" | jq -r --arg name "${PROJECT_NAME}" \
  '.[] | select(.name == $name) | .projectId' 2>/dev/null || true)
ENV_ID=$(echo "${PROJECTS}" | jq -r --arg name "${PROJECT_NAME}" \
  '.[] | select(.name == $name) | .environments[0].environmentId' 2>/dev/null || true)

if [ -n "${PROJECT_ID}" ] && [ "${PROJECT_ID}" != "null" ]; then
  echo "  Project already exists — ID: ${PROJECT_ID}, envId: ${ENV_ID}"
else
  echo "  Project not found — creating..."
  RESP=$(dokploy_post "project.create" \
    "{\"name\":\"${PROJECT_NAME}\",\"description\":\"TDS EAD LMS Platform\"}")
  PROJECT_ID=$(echo "${RESP}" | jq -r '.project.projectId')
  ENV_ID=$(echo "${RESP}" | jq -r '.environment.environmentId')
  echo "  Created project — ID: ${PROJECT_ID}, envId: ${ENV_ID}"
fi
echo ""

# ---------------------------------------------------------------------------
# 2. Get or create compose service
# ---------------------------------------------------------------------------
echo "[2/6] Checking for existing compose service '${COMPOSE_NAME}'..."

# Re-fetch project detail to find compose services in this environment
PROJECTS=$(dokploy_get "project.all")
COMPOSE_ID=$(echo "${PROJECTS}" | jq -r \
  --arg pid "${PROJECT_ID}" \
  --arg cname "${COMPOSE_NAME}" \
  '.[] | select(.projectId == $pid) | .environments[].compose[] | select(.name == $cname) | .composeId' \
  2>/dev/null || true)

if [ -n "${COMPOSE_ID}" ] && [ "${COMPOSE_ID}" != "null" ]; then
  echo "  Compose service already exists — ID: ${COMPOSE_ID}"
else
  echo "  Compose service not found — creating..."
  RESP=$(dokploy_post "compose.create" \
    "{\"name\":\"${COMPOSE_NAME}\",\"environmentId\":\"${ENV_ID}\",\"sourceType\":\"raw\"}")
  COMPOSE_ID=$(echo "${RESP}" | jq -r '.composeId')
  echo "  Created compose service — ID: ${COMPOSE_ID}"
fi
echo ""

# ---------------------------------------------------------------------------
# 3. Upload docker-compose.yml
# ---------------------------------------------------------------------------
echo "[3/6] Uploading docker-compose.yml..."

COMPOSE_CONTENT=$(cat "${COMPOSE_FILE}")
COMPOSE_JSON=$(echo "${COMPOSE_CONTENT}" | jq -Rs .)

RESP=$(dokploy_post "compose.update" \
  "{\"composeId\":\"${COMPOSE_ID}\",\"sourceType\":\"raw\",\"composeFile\":${COMPOSE_JSON}}")

if echo "${RESP}" | jq -e '.composeId' > /dev/null 2>&1; then
  echo "  docker-compose.yml uploaded successfully."
else
  echo "ERROR: Failed to upload docker-compose.yml" >&2
  echo "${RESP}" >&2
  exit 1
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Set environment variables
# ---------------------------------------------------------------------------
echo "[4/6] Setting environment variables..."

ENV_CONTENT=$(grep -v '^#' "${ENV_FILE}" | grep -v '^[[:space:]]*$' || true)
ENV_JSON=$(echo "${ENV_CONTENT}" | jq -Rs .)

RESP=$(dokploy_post "compose.update" \
  "{\"composeId\":\"${COMPOSE_ID}\",\"env\":${ENV_JSON}}")

if echo "${RESP}" | jq -e '.composeId' > /dev/null 2>&1; then
  echo "  Environment variables set successfully."
else
  echo "ERROR: Failed to set environment variables" >&2
  echo "${RESP}" >&2
  exit 1
fi
echo ""

# ---------------------------------------------------------------------------
# 5. Configure domain with SSL
# ---------------------------------------------------------------------------
echo "[5/6] Configuring domain ${TARGET_DOMAIN} with Let's Encrypt SSL..."

# Check if domain already exists
COMPOSE_DETAIL=$(dokploy_get "compose.one?composeId=${COMPOSE_ID}")
EXISTING_DOMAIN=$(echo "${COMPOSE_DETAIL}" | jq -r \
  --arg host "${TARGET_DOMAIN}" \
  '(.domains // []) | .[] | select(.host == $host) | .domainId' 2>/dev/null || true)

if [ -n "${EXISTING_DOMAIN}" ] && [ "${EXISTING_DOMAIN}" != "null" ]; then
  echo "  Domain ${TARGET_DOMAIN} already configured — domainId: ${EXISTING_DOMAIN}"
else
  RESP=$(dokploy_post "domain.create" \
    "{\"host\":\"${TARGET_DOMAIN}\",\"composeId\":\"${COMPOSE_ID}\",\"port\":80,\"https\":true,\"certificateType\":\"letsencrypt\",\"serviceName\":\"wordpress\"}")

  DOMAIN_ID=$(echo "${RESP}" | jq -r '.domainId' 2>/dev/null || true)
  if [ -n "${DOMAIN_ID}" ] && [ "${DOMAIN_ID}" != "null" ]; then
    echo "  Domain configured — domainId: ${DOMAIN_ID}"
  else
    echo "WARNING: Domain creation response unexpected:" >&2
    echo "${RESP}" >&2
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# 6. Trigger deploy
# ---------------------------------------------------------------------------
echo "[6/6] Triggering deploy..."

RESP=$(dokploy_post "compose.deploy" \
  "{\"composeId\":\"${COMPOSE_ID}\"}")

if [ -n "${RESP}" ] && [ "${RESP}" != "null" ] && [ "${RESP}" != "" ]; then
  echo "  Deploy triggered."
  echo "  Response: ${RESP}"
else
  echo "ERROR: Failed to trigger deploy — empty response" >&2
  exit 1
fi
echo ""

# ---------------------------------------------------------------------------
# Wait and verify
# ---------------------------------------------------------------------------
echo "Waiting 90 seconds for containers to start..."
sleep 90

echo ""
echo "Checking https://${TARGET_DOMAIN} ..."

HTTP_STATUS=$(curl -skL --connect-timeout 15 --max-time 30 \
  -o /dev/null -w "%{http_code}" \
  "https://${TARGET_DOMAIN}" 2>/dev/null || echo "000")

if [ "${HTTP_STATUS}" = "200" ] || [ "${HTTP_STATUS}" = "302" ] || [ "${HTTP_STATUS}" = "301" ]; then
  echo "  Site is up! HTTP ${HTTP_STATUS}"
elif [ "${HTTP_STATUS}" = "000" ]; then
  echo "WARNING: Could not connect to https://${TARGET_DOMAIN} (timeout or no route). Deploy may still be in progress."
else
  echo "WARNING: https://${TARGET_DOMAIN} returned HTTP ${HTTP_STATUS}. Deploy may still be in progress."
fi

echo ""
echo "=== Summary ==="
echo "  Project ID  : ${PROJECT_ID}"
echo "  Compose ID  : ${COMPOSE_ID}"
echo "  Domain      : ${TARGET_DOMAIN} (HTTPS, Let's Encrypt)"
echo "  HTTP check  : ${HTTP_STATUS}"
echo ""
echo "Dokploy setup complete."
