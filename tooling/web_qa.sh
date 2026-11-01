#!/usr/bin/env bash
# MACRO QA WEB — um comando faz tudo:
#   build release -> sobe app+proxy em :9090 -> roda TODOS os e2e web
#   -> resumo PASS/FAIL. Nenhum passo manual.
#
# Uso:
#   ./tooling/web_qa.sh              # pipeline completo
#   SKIP_BUILD=1 ./tooling/web_qa.sh # pula o flutter build (reusa build/web)
#
# Resultado: exit 0 se todos os arquivos de teste passarem.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO/cartilhas_app"
FLUTTER="${FLUTTER:-/opt/flutter/bin/flutter}"
CONFIG="${CONFIG:-config/staging.qa.json}"
WEB_CONFIG="${WEB_CONFIG:-config/staging.qa.web.json}"
WEB_PORT="${WEB_PORT:-9090}"
DRIVER_PORT="${DRIVER_PORT:-4444}"
CONTAINER="${CONTAINER:-cartilhas-web-qa}"

# Arquivos e2e compativeis com web (restante e Android-only por design).
# Rodam com staging.qa.json: autologin DESLIGADO, login manual real testado.
TESTS=(
  integration_test/app_test.dart
  integration_test/genui_test.dart
  integration_test/account_qa_test.dart
  integration_test/learning_qa_test.dart
  integration_test/wallet_qa_test.dart
  integration_test/web_postman_test.dart
)
# Rodam com staging.qa.web.json: mesmo config do app servido em :9090.
WEB_TESTS=(
  integration_test/qa_autologin_test.dart
)

export PATH="/usr/local/bin:$PATH"
PASS=(); FAIL=()

say() { echo ""; echo "==> $*"; }

# ── 1. Build ──────────────────────────────────────────────────────────
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  say "1/4 build web release ($WEB_CONFIG)"
  (cd "$APP_DIR" && "$FLUTTER" build web --release --base-href / \
    --dart-define-from-file="$WEB_CONFIG") || { echo "BUILD FALHOU"; exit 1; }
else
  say "1/4 build pulado (SKIP_BUILD=1)"
fi

# ── 2. App + proxy em :$WEB_PORT ──────────────────────────────────────
say "2/4 sobe app+proxy :$WEB_PORT"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" --restart unless-stopped -p "$WEB_PORT":80 \
  -v "$APP_DIR/build/web:/usr/share/nginx/html:ro" \
  -v "$REPO/tooling/web_proxy.nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
  nginx:alpine >/dev/null || { echo "DOCKER FALHOU"; exit 1; }

for _ in $(seq 1 20); do
  curl -sf -o /dev/null "http://localhost:$WEB_PORT/" && break
  sleep 0.5
done
curl -sf "http://localhost:$WEB_PORT/tutor-staging-api/health" >/dev/null \
  && echo "    app+api proxy OK" || echo "    AVISO: proxy api nao respondeu"

# ── 3. chromedriver ───────────────────────────────────────────────────
say "3/4 chromedriver :$DRIVER_PORT"
pkill -f "chromedriver --port=$DRIVER_PORT" 2>/dev/null || true
CHROME_LOG="$(mktemp -t chromedriver-qa-XXXX.log)"
chromedriver --port="$DRIVER_PORT" --allowed-origins='*' >"$CHROME_LOG" 2>&1 &
CHROME_PID=$!
cleanup() { kill "$CHROME_PID" 2>/dev/null; }
trap cleanup EXIT
for _ in $(seq 1 30); do
  curl -sf "http://localhost:$DRIVER_PORT/status" >/dev/null 2>&1 && break
  sleep 0.5
done

# ── 4. Suite ──────────────────────────────────────────────────────────
say "4/4 rodando $(( ${#TESTS[@]} + ${#WEB_TESTS[@]} )) arquivo(s) e2e"
run_drive() {
  local target="$1" cfg="$2"
  echo ""; echo "---- $target  [$cfg]"
  (cd "$APP_DIR" && "$FLUTTER" drive \
    --driver=test_driver/integration_test.dart \
    --target="$target" \
    -d web-server \
    --browser-name=chrome \
    --chrome-binary=/usr/local/bin/chromium-nosandbox \
    --headless \
    --web-port=8484 \
    --driver-port="$DRIVER_PORT" \
    --browser-dimension=1600x1024 \
    --dart-define-from-file="$cfg") \
    && PASS+=("$target") || FAIL+=("$target")
}
for t in "${TESTS[@]}"; do run_drive "$t" "$CONFIG"; done
for t in "${WEB_TESTS[@]}"; do run_drive "$t" "$WEB_CONFIG"; done

# ── Resumo ────────────────────────────────────────────────────────────
echo ""; echo "════════════════ RESULTADO ════════════════"
for t in "${PASS[@]}"; do echo "  PASS  $t"; done
for t in "${FAIL[@]}"; do echo "  FAIL  $t"; done
echo "  app em: http://46.202.150.132:$WEB_PORT  (local: http://localhost:$WEB_PORT)"
echo "═══════════════════════════════════════════"
[ ${#FAIL[@]} -eq 0 ]
