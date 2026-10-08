#!/usr/bin/env bash
# php -l em todo PHP customizado do portal (executar dentro do container web).
set -euo pipefail
cd "$(dirname "$0")/.."

targets=(web/modules/custom web/themes/custom)
files=()
for dir in "${targets[@]}"; do
  [ -d "$dir" ] || continue
  while IFS= read -r -d '' f; do files+=("$f"); done \
    < <(find "$dir" \( -name '*.php' -o -name '*.module' -o -name '*.inc' -o -name '*.install' -o -name '*.theme' \) -print0)
done
[ -f web/sites/default/settings.php ] && files+=(web/sites/default/settings.php)

if [ "${#files[@]}" -eq 0 ]; then
  echo "lint-php: nenhum arquivo PHP customizado"
  exit 0
fi

for f in "${files[@]}"; do
  php -l "$f" > /dev/null
done
echo "lint-php: ${#files[@]} arquivo(s) OK"
