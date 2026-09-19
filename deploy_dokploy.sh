#!/bin/bash
# deploy_dokploy.sh — Rebuild + rsync para VPS + redeploy via Dokploy API
# Uso: ./deploy_dokploy.sh [--skip-build]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env.deploy"

API="$DOKPLOY_URL/api"
H="x-api-key: $DOKPLOY_API_TOKEN"
APP_DIR="$SCRIPT_DIR/cartilhas_app"
SKIP_BUILD=false

for arg in "$@"; do
  [[ "$arg" == "--skip-build" ]] && SKIP_BUILD=true
done

echo "🚀 Deploy Cartilhas TDS"
echo "   VPS: $VPS_USER@$VPS_IP:$VPS_REMOTE_DIR"
echo "   Compose: $DOKPLOY_COMPOSE_ID"
echo ""

# ── 1. Build Flutter ─────────────────────────────────────────────────
if [ "$SKIP_BUILD" = false ]; then
  echo "📦 [1/3] Build Flutter web..."
  cd "$APP_DIR"
  flutter build web --base-href / --release 2>&1 | tail -3
  echo "   ✓ build/web pronto"
else
  echo "📦 [1/3] Build Flutter ignorado (--skip-build)"
fi

# ── 2. Rsync para VPS ────────────────────────────────────────────────
echo "📤 [2/3] Enviando para VPS..."
ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
  "$VPS_USER@$VPS_IP" "mkdir -p $VPS_REMOTE_DIR/web"

rsync -az --delete --progress \
  -e "ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no" \
  "$APP_DIR/build/web/" \
  "$VPS_USER@$VPS_IP:$VPS_REMOTE_DIR/web/"

scp -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
  "$APP_DIR/nginx.conf" \
  "$VPS_USER@$VPS_IP:$VPS_REMOTE_DIR/nginx.conf"

echo "   ✓ Arquivos enviados"

# ── 3. Redeploy via API ──────────────────────────────────────────────
echo "🐳 [3/3] Disparando deploy no Dokploy..."
RESULT=$(curl -s -X POST "$API/compose.deploy" \
  -H "$H" -H "Content-Type: application/json" \
  -d "{\"composeId\":\"$DOKPLOY_COMPOSE_ID\"}")

STATUS=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','?'))" 2>/dev/null)
echo "   $STATUS"

# Aguardar e verificar
sleep 10
COMPOSE_STATUS=$(curl -s "$API/compose.one?composeId=$DOKPLOY_COMPOSE_ID" \
  -H "$H" | python3 -c "import sys,json; print(json.load(sys.stdin).get('composeStatus','?'))" 2>/dev/null)

echo ""
if [ "$COMPOSE_STATUS" = "done" ]; then
  echo "╔═══════════════════════════════════════════╗"
  echo "║  ✅ Deploy concluído com sucesso!         ║"
  echo "╠═══════════════════════════════════════════╣"
  echo "║  http://$APP_DOMAIN"
  echo "║  Painel: $DOKPLOY_URL"
  echo "╚═══════════════════════════════════════════╝"
else
  echo "⚠️  Status: $COMPOSE_STATUS"
  echo "   Verifique os logs em: $DOKPLOY_URL"
  echo "   Compose ID: $DOKPLOY_COMPOSE_ID"
fi
