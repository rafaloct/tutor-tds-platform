#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT=/opt/tds-labs/authentik-oidc-20261022
PROJECT=tds_authentik_lab_20261022
if [ -e "$ROOT" ]; then echo STOP_EXISTING_LAB; exit 27; fi
if ss -tln | grep -Eq ':(19200|19443)[[:space:]]'; then echo STOP_PORT_ALREADY_USED; exit 28; fi
mkdir -p "$ROOT"
chmod 700 "$ROOT"
cd "$ROOT"
curl -fsSL --retry 2 --max-time 40 https://docs.goauthentik.io/compose.yml -o compose.yml
python3 - <<'PY'
from pathlib import Path
p=Path("compose.yml")
text=p.read_text()
needle="- /var/run/docker.sock:/var/run/docker.sock"
assert text.count(needle)==1, "STOP_UNEXPECTED_DOCKER_SOCK_MOUNT"
assert "2026.8.5" in text, "STOP_UNEXPECTED_AUTHENTIK_VERSION"
assert "${COMPOSE_PORT_HTTP:-9000}:9000" in text
assert "${COMPOSE_PORT_HTTPS:-9443}:9443" in text
p.write_text(text.replace(needle, "# TDS LAB: docker socket disabled"))
PY
chmod 600 compose.yml
if ! command -v openssl >/dev/null; then echo STOP_NO_OPENSSL; exit 29; fi
{
  printf 'PG_PASS=%s\n' "$(openssl rand -hex 30)"
  printf 'AUTHENTIK_SECRET_KEY=%s\n' "$(openssl rand -hex 48)"
  printf '%s\n' 'AUTHENTIK_TAG=2026.8.5' 'COMPOSE_PORT_HTTP=127.0.0.1:19200' 'COMPOSE_PORT_HTTPS=127.0.0.1:19443' 'AUTHENTIK_ERROR_REPORTING__ENABLED=false'
} > .env
chmod 600 .env
cat > compose.override.yml <<'YAML'
services:
  postgresql:
    mem_limit: 1g
  server:
    mem_limit: 3g
  worker:
    mem_limit: 2g
YAML
chmod 600 compose.override.yml
docker compose -p "$PROJECT" -f compose.yml -f compose.override.yml config -q
python3 - <<'PY'
import json,subprocess
obj=json.loads(subprocess.check_output(["docker","compose","-p","tds_authentik_lab_20261022","-f","compose.yml","-f","compose.override.yml","config","--format","json"]))
assert set(obj["services"])=={"postgresql","server","worker"},obj["services"].keys()
for name,service in obj["services"].items():
 for mount in service.get("volumes",[]):
  assert "/var/run/docker.sock" not in str(mount), "STOP_DOCKER_SOCKET_EXPOSED"
 for port in service.get("ports",[]):
  assert port.get("host_ip")=="127.0.0.1", "STOP_PUBLIC_PORT"
  assert str(port.get("published")) in ("19200","19443"), "STOP_WRONG_PORT"
print("TDS_AUTHENTIK_LAB_CONFIG_PASS loopback_only isolated_db no_docker_sock pinned_version")
PY
printf 'LAB_DIRECTORY_PREPARED=YES\n'
printf 'SECRETS_CREATED_LOCAL_MODE_600=YES\n'
printf 'PRODUCTION_CONTAINERS_STOPPED=NO\n'
printf 'AUTHENTIK_PULL_BEGIN\n'
docker compose -p "$PROJECT" -f compose.yml -f compose.override.yml pull -q
printf 'AUTHENTIK_PULL_PASS\n'
docker compose -p "$PROJECT" -f compose.yml -f compose.override.yml up -d --no-build
printf 'AUTHENTIK_LAB_STARTED\n'
docker compose -p "$PROJECT" -f compose.yml -f compose.override.yml ps
printf 'LISTEN_CHECK\n'
ss -tln | grep -E ':(19200|19443)[[:space:]]' || true
printf 'PRODUCTION_WP_UNTOUCHED=YES\n'