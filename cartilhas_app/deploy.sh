#!/bin/bash
# deploy.sh — Envia o app para a VPS e sobe via Docker
# Uso: ./deploy.sh usuario@ip-da-vps

set -e

VPS="${1:-usuario@sua-vps.com}"
REMOTE_DIR="/opt/cartilhas-tds"
IMAGE="cartilhas-tds:latest"

echo "=== Build Flutter web ==="
flutter build web --base-href /

echo "=== Build Docker image ==="
docker build -t "$IMAGE" .

echo "=== Enviando imagem para a VPS ==="
docker save "$IMAGE" | ssh "$VPS" "docker load"

echo "=== Subindo na VPS ==="
ssh "$VPS" "
  mkdir -p $REMOTE_DIR
  docker stop cartilhas-tds 2>/dev/null || true
  docker rm cartilhas-tds 2>/dev/null || true
  docker run -d \
    --name cartilhas-tds \
    --restart unless-stopped \
    -p 80:80 \
    $IMAGE
  echo 'App rodando!'
  docker ps | grep cartilhas-tds
"

echo "=== Deploy concluído ==="
echo "Acesse: http://$VPS"
