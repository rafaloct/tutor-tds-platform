#!/usr/bin/env bash
# Lint completo: PHP (-l + PHPCS Drupal), YAML e Twig.
# Uso: dentro do container web, bash scripts/lint.sh
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/lint-php.sh
vendor/bin/phpcs --standard=phpcs.xml.dist
php scripts/lint-yaml.php
php scripts/lint-twig.php
echo "LINT OK"
