#!/usr/bin/env bash
# E2E automatizado do app web (sem emulador Android).
# Sobe chromedriver + app em web-server + Chrome headless e roda
# os testes de integration_test/. Ao final derruba tudo.
#
# Uso:
#   ./tooling/test_web_e2e.sh                    # staging.qa.json + app_test.dart
#   TEST=integration_test/genui_test.dart ./tooling/test_web_e2e.sh
#   CONFIG=config/production.json ./tooling/test_web_e2e.sh
#   HEADLESS=--no-headless ./tooling/test_web_e2e.sh   # abre janela visivel
#
# Requisitos (ja provisionados neste host):
#   /opt/flutter/bin/flutter            SDK 3.44.9
#   /usr/local/bin/chromedriver         -> /snap/bin/chromium.chromedriver
#   /usr/local/bin/chromium-nosandbox   wrapper p/ rodar Chromium como root
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../cartilhas_app" && pwd)"
FLUTTER="${FLUTTER:-/opt/flutter/bin/flutter}"
CONFIG="${CONFIG:-config/staging.qa.json}"
TEST="${TEST:-integration_test/app_test.dart}"
DRIVER="${DRIVER:-test_driver/integration_test.dart}"
WEB_PORT="${WEB_PORT:-8484}"
DRIVER_PORT="${DRIVER_PORT:-4444}"
BROWSER_DIM="${BROWSER_DIM:-1600x1024}"
HEADLESS="${HEADLESS:---headless}"

export PATH="/usr/local/bin:$PATH"

CHROME_LOG="$(mktemp -t chromedriver-e2e-XXXX.log)"
chromedriver --port="$DRIVER_PORT" --allowed-origins='*' >"$CHROME_LOG" 2>&1 &
CHROME_PID=$!
cleanup() {
  kill "$CHROME_PID" 2>/dev/null || true
  if [ "${KEEP_CHROME_LOG:-0}" != "1" ]; then rm -f "$CHROME_LOG"; else echo "chromedriver log: $CHROME_LOG"; fi
}
trap cleanup EXIT

for _ in $(seq 1 30); do
  curl -sf "http://localhost:$DRIVER_PORT/status" >/dev/null 2>&1 && break
  sleep 0.5
done

cd "$APP_DIR"

echo "==> flutter drive web e2e"
echo "    config : $CONFIG"
echo "    test   : $TEST"
echo "    driver : $DRIVER"
echo "    port   : $WEB_PORT  webdriver: $DRIVER_PORT  dim: $BROWSER_DIM  headless: $HEADLESS"

exec "$FLUTTER" drive \
  --driver="$DRIVER" \
  --target="$TEST" \
  -d web-server \
  --browser-name=chrome \
  --chrome-binary=/usr/local/bin/chromium-nosandbox \
  "$HEADLESS" \
  --web-port="$WEB_PORT" \
  --driver-port="$DRIVER_PORT" \
  --browser-dimension="$BROWSER_DIM" \
  --dart-define-from-file="$CONFIG" \
  "$@"
