#!/usr/bin/env sh
set -eu

IMAGE=${1:?immutable image reference required}
DEPLOY_DIR=${2:?absolute deploy directory required}
EXPECTED_REVISION=${3:?full Git revision required}
EXPECTED_SOURCE=${4:?public repository source required}

case "$DEPLOY_DIR" in
  /*) ;;
  *) printf 'Deploy directory must be absolute.\n' >&2; exit 2 ;;
esac
if [ "$DEPLOY_DIR" = "/" ]; then
  printf 'Refusing to deploy at filesystem root.\n' >&2
  exit 2
fi

COMPOSE_FILE="$DEPLOY_DIR/docker-compose.staging.yml"
cd "$DEPLOY_DIR"
test -f "$COMPOSE_FILE"
test -f "$DEPLOY_DIR/.env"

sheets_sync_enabled=$(
  python3 - "$DEPLOY_DIR/.env" <<'PY'
from pathlib import Path
import sys

value = "false"
for raw_line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, candidate = line.split("=", 1)
    if key.strip() == "STAGING_SHEETS_SYNC_ENABLED":
        value = candidate.strip().strip("\"'").lower()
print(value)
PY
)
case "$sheets_sync_enabled" in
  true) ;;
  false|'') sheets_sync_enabled=false ;;
  *) printf 'STAGING_SHEETS_SYNC_ENABLED must be true or false.\n' >&2; exit 2 ;;
esac

up_application() {
  if [ "$sheets_sync_enabled" = "true" ]; then
    docker compose -f "$COMPOSE_FILE" --profile sheets-sync up -d --no-build "$@" api-staging sync-worker-staging
  else
    docker compose -f "$COMPOSE_FILE" up -d --no-build "$@" api-staging
    docker compose -f "$COMPOSE_FILE" --profile sheets-sync stop sync-worker-staging >/dev/null 2>&1 || true
  fi
}

previous_image=""
container_id=$(docker compose -f "$COMPOSE_FILE" ps -q api-staging 2>/dev/null || true)
if [ -n "$container_id" ]; then
  previous_image=$(docker inspect --format '{{.Config.Image}}' "$container_id" 2>/dev/null || true)
fi
if [ -z "$previous_image" ] && [ -s "$DEPLOY_DIR/.deployed-image" ]; then
  IFS= read -r previous_image < "$DEPLOY_DIR/.deployed-image"
fi

rollback() {
  code=$?
  trap - EXIT HUP INT TERM
  if [ -n "$previous_image" ]; then
    printf 'Staging gate failed; rolling back to %s\n' "$previous_image" >&2
    export STAGING_API_IMAGE="$previous_image"
    up_application --no-deps || true
  else
    printf 'Staging gate failed and no previous image was found.\n' >&2
    docker compose -f "$COMPOSE_FILE" stop api-staging || true
    docker compose -f "$COMPOSE_FILE" --profile sheets-sync stop sync-worker-staging || true
  fi
  exit "$code"
}
export STAGING_API_IMAGE="$IMAGE"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker pull "$IMAGE"
fi
python3 "$DEPLOY_DIR/ops/verify_image_provenance.py" \
  "$IMAGE" --expected-revision "$EXPECTED_REVISION" \
  --expected-source "$EXPECTED_SOURCE"
docker compose -f "$COMPOSE_FILE" config --quiet
if [ "$sheets_sync_enabled" = "true" ]; then
  docker compose -f "$COMPOSE_FILE" --profile sheets-sync config --format json |
    python3 -c '
import json, sys
config = json.load(sys.stdin)
env = config["services"]["sync-worker-staging"]["environment"]
required = ("GOOGLE_SHEET_ID", "GOOGLE_SERVICE_ACCOUNT_JSON", "SHEETS_PSEUDONYM_SECRET")
missing = [name for name in required if not str(env.get(name, "")).strip()]
if missing:
    raise SystemExit("Sheets sync enabled but missing: " + ", ".join(missing))
if len(str(env["SHEETS_PSEUDONYM_SECRET"])) < 32:
    raise SystemExit("SHEETS_PSEUDONYM_SECRET must contain at least 32 characters")
credentials = json.loads(env["GOOGLE_SERVICE_ACCOUNT_JSON"])
if not isinstance(credentials, dict):
    raise SystemExit("GOOGLE_SERVICE_ACCOUNT_JSON must be a JSON object")
'
fi
trap rollback EXIT HUP INT TERM
docker compose -f "$COMPOSE_FILE" up -d db-staging
attempt=0
db_health=""
while [ "$attempt" -lt 30 ]; do
  db_id=$(docker compose -f "$COMPOSE_FILE" ps -q db-staging)
  db_health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$db_id" 2>/dev/null || true)
  if [ "$db_health" = "healthy" ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done
if [ "$db_health" != "healthy" ]; then
  printf 'Staging database did not become healthy.\n' >&2
  exit 1
fi
docker compose -f "$COMPOSE_FILE" run --rm --no-deps api-staging alembic upgrade head
up_application

attempt=0
while [ "$attempt" -lt 30 ]; do
  container_id=$(docker compose -f "$COMPOSE_FILE" ps -q api-staging)
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container_id" 2>/dev/null || true)
  if [ "$health" = "healthy" ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done
if [ "${health:-}" != "healthy" ]; then
  printf 'Staging API did not become healthy.\n' >&2
  exit 1
fi

running_api_image=$(docker inspect --format '{{.Image}}' "$container_id")

if [ "$sheets_sync_enabled" = "true" ]; then
  sleep 2
  worker_id=$(docker compose -f "$COMPOSE_FILE" --profile sheets-sync ps --status running -q sync-worker-staging)
  if [ -z "$worker_id" ]; then
    printf 'Staging sync worker is not running.\n' >&2
    exit 1
  fi
  running_worker_image=$(docker inspect --format '{{.Image}}' "$worker_id")
  python3 "$DEPLOY_DIR/ops/verify_image_provenance.py" \
    "$running_api_image" "$running_worker_image" \
    --expected-revision "$EXPECTED_REVISION" \
    --expected-source "$EXPECTED_SOURCE"
else
  python3 "$DEPLOY_DIR/ops/verify_image_provenance.py" \
    "$IMAGE" "$running_api_image" --expected-revision "$EXPECTED_REVISION" \
    --expected-source "$EXPECTED_SOURCE"
fi

published_port=$(docker compose -f "$COMPOSE_FILE" port api-staging 8000 | tail -n 1 | awk -F: '{print $NF}')
case "$published_port" in
  ''|*[!0-9]*) printf 'Could not resolve the staging API published port.\n' >&2; exit 1 ;;
esac
python3 "$DEPLOY_DIR/ops/smoke_test.py" "http://127.0.0.1:${published_port}/"
printf '%s\n' "$IMAGE" > "$DEPLOY_DIR/.deployed-image"
trap - EXIT HUP INT TERM
printf 'Staging deployed: %s\n' "$IMAGE"
