#!/bin/bash
# setup_dns_hostinger.sh — Configura DNS no Hostinger via API
# Uso: ./setup_dns_hostinger.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/.env.deploy"

if [ -z "${HOSTINGER_API_TOKEN:-}" ]; then
  echo "❌ HOSTINGER_API_TOKEN não definido em .env.deploy"
  echo "   Adicione seu token da API Hostinger no arquivo .env.deploy"
  exit 1
fi

# Ex: APP_DOMAIN=cartilhas.ipexdesenvolvimento.cloud
# → SUBDOMAIN=cartilhas, ZONE=ipexdesenvolvimento.cloud
SUBDOMAIN=$(echo "$APP_DOMAIN" | cut -d. -f1)
ZONE=$(echo "$APP_DOMAIN" | cut -d. -f2-)

echo "🌐 Configurando DNS Hostinger"
echo "   Zona: $ZONE"
echo "   Subdomínio: $SUBDOMAIN → $VPS_IP"

HOSTINGER_API="https://api.hostinger.com/v1"

# ── Listar zonas para confirmar ────────────────────────────────────
echo ""
echo "Zonas disponíveis na conta:"
curl -s "$HOSTINGER_API/dns/zones" \
  -H "Authorization: Bearer $HOSTINGER_API_TOKEN" | \
  python3 -c "
import sys,json
d=json.load(sys.stdin)
zones = d.get('data',[]) if isinstance(d,dict) else d
for z in zones:
    print(f\"  {z.get('domain',z.get('name',str(z)))}\")
" 2>/dev/null || echo "  (verificar formato da API)"

# ── Criar/atualizar registro A ─────────────────────────────────────
echo ""
echo "Criando registro A: $SUBDOMAIN → $VPS_IP"

RESULT=$(curl -s -X POST "$HOSTINGER_API/dns/zones/$ZONE/records" \
  -H "Authorization: Bearer $HOSTINGER_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"A\",
    \"name\": \"$SUBDOMAIN\",
    \"content\": \"$VPS_IP\",
    \"ttl\": 300
  }")

echo "Resultado: $RESULT"

# ── Verificar propagação DNS ───────────────────────────────────────
echo ""
echo "Verificando propagação DNS (pode levar até 5 minutos)..."
for i in 1 2 3; do
  RESOLVED=$(dig +short "$APP_DOMAIN" A 2>/dev/null | head -1)
  if [ "$RESOLVED" = "$VPS_IP" ]; then
    echo "✅ DNS propagado! $APP_DOMAIN → $RESOLVED"
    break
  else
    echo "   Tentativa $i: $APP_DOMAIN → ${RESOLVED:-não resolvido} (aguardando...)"
    sleep 30
  fi
done

# ── Ativar HTTPS no Dokploy ────────────────────────────────────────
echo ""
echo "Ativando certificado SSL Let's Encrypt no Dokploy..."
if [ -n "${DOKPLOY_COMPOSE_ID:-}" ]; then
  # Atualizar domínio para HTTPS
  curl -s -X POST "$DOKPLOY_URL/api/domain.generateWildCard" \
    -H "x-api-key: $DOKPLOY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"composeId\":\"$DOKPLOY_COMPOSE_ID\"}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d)" 2>/dev/null
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ DNS configurado!                     ║"
echo "╠══════════════════════════════════════════╣"
echo "║  https://$APP_DOMAIN"
echo "╚══════════════════════════════════════════╝"
