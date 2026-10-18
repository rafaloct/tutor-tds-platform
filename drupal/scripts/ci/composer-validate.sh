#!/usr/bin/env bash
# composer validate --strict + composer audit em container composer:2 pinnado
# por digest — a MESMA referencia que o Dockerfile usa (fonte unica do pin).
# Roda no host: nao precisa de PHP/Composer locais nem do build da imagem da
# aplicacao. Sem acesso a recursos externos alem do Packagist (audit).
#
# Uso host (em drupal/):  bash scripts/ci/composer-validate.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "[ci:composer] FAIL: $*" >&2; exit 1; }

COMPOSER_IMAGE="${COMPOSER_IMAGE:-$(grep -oE 'composer:2@sha256:[0-9a-f]{64}' Dockerfile | head -1)}"
[ -n "$COMPOSER_IMAGE" ] || fail "digest composer:2 nao encontrado no Dockerfile"

# pwd -W devolve o path Windows no Git Bash/MSYS2; em Linux equivale a pwd.
MOUNT_SRC="$(pwd -W 2>/dev/null || pwd)"
export MSYS_NO_PATHCONV=1

run_composer() {
  docker run --rm \
    -v "${MOUNT_SRC}:/app" -w /app \
    -e COMPOSER_ALLOW_SUPERUSER=1 \
    "$COMPOSER_IMAGE" "$@"
}

echo "[ci:composer] imagem pinnada: $COMPOSER_IMAGE"
echo "[ci:composer] composer validate --strict"
run_composer validate --strict --no-check-publish

echo "[ci:composer] composer audit (lockfile)"
run_composer audit --locked --no-interaction

echo "[ci:composer] OK"
