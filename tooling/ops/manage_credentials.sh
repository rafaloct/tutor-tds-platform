#!/usr/bin/env bash
set -euo pipefail
CONTAINER="${TUTOR_API_CONTAINER:-tutor-tds-api-api-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
docker cp "$SCRIPT_DIR/manage_credentials.py" "$CONTAINER:/tmp/manage_credentials.py"
docker exec -e PYTHONPATH=/app "$CONTAINER" python3 /tmp/manage_credentials.py "$@"
