#!/usr/bin/env bash
# Preflight fail-closed do staging Drupal (Issue #163 / rereview ACP PR #177).
#
# Staging NUNCA sobe com tag mutavel: DRUPAL_STAGING_IMAGE_REF deve ser uma
# referencia imutavel de imagem pinnada por digest no formato
#   <repo>[:porta][/path]@sha256:<64-hex>
# Tag-only ("repo:staging"), digest truncado/maiusculo ou ref malformada sao
# rejeitados aqui e tambem em settings.php/install-site.sh dentro do container.
#
# Uso host (em drupal/), antes de qualquer "up" do staging:
#   export DRUPAL_STAGING_IMAGE_REF=registry.exemplo/tutor-tds-drupal@sha256:<64-hex>
#   bash scripts/staging-preflight.sh
#   docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d
#
# Provisionamento real de staging segue BLOCKED (G6): este script so valida a
# forma declarativa; nao faz push/pull de registry, DNS ou segredos.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "[staging-preflight] FAIL: $*" >&2; exit 1; }

image_ref="${DRUPAL_STAGING_IMAGE_REF:-}"
[ -n "$image_ref" ] \
  || fail "DRUPAL_STAGING_IMAGE_REF ausente; staging exige ref imutavel repo@sha256:<64-hex>"

# Exige sufixo digest sha256 canonico: 64 hex minusculos apos "@sha256:".
# A parte do repositorio nao pode ter espaco nem "@" (tag opcional e aceita,
# pois o digest torna a referencia imutavel mesmo com tag presente).
ref_re='^[^[:space:]@]+@sha256:[0-9a-f]{64}$'
[[ "$image_ref" =~ $ref_re ]] \
  || fail "DRUPAL_STAGING_IMAGE_REF='$image_ref' nao e ref imutavel pinnada por digest (esperado repo@sha256:<64-hex>; tag mutavel proibida)"

docker compose -f docker-compose.yml -f docker-compose.staging.yml config --quiet \
  || fail "docker compose config do staging falhou (vars obrigatorias ausentes?)"

echo "[staging-preflight] OK — imagem pinnada '$image_ref'; config de staging valida"
