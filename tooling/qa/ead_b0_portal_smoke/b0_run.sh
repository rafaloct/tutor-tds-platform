#!/usr/bin/env bash
# b0_run.sh — F3d / Issue #274: homologação das páginas B0 do tema candidato
# (PR #251) no WordPress MariaDB sintético do dfd627, com snapshot + rollback.
#
# Execução: DENTRO do sandbox (cwd = raiz do sandbox, onde há wp-cli.phar e
# wordpress-mysql/). Requer:
#   - THEME_DIR=<dir com o tema candidato já extraído>  (obrigatório)
#   - f0_env.sh sourced com QA_PASS_A / QA_PASS_B      (obrigatório)
#   - BASE_URL=http://127.0.0.1:18732                  (loopback only)
# Proibições: nenhum GET de permalink de lição; nenhum segredo/HTML autenticado
# em evidência; saída = sinais booleanos + códigos HTTP apenas.
set -u
B="${BASE_URL:-http://127.0.0.1:18732}"
SBX="${SBX_ROOT:-$(pwd)}"
WP="php $SBX/wp-cli.phar --allow-root --path=$SBX/wordpress-mysql"
THEME_SRC="${THEME_DIR:?defina THEME_DIR com o tema candidato extraído}"
TD="$SBX/wordpress-mysql/wp-content/themes/tds-child-theme"
SNAP="$SBX/b0qa-snapshot"
PASS=0; FAIL=0
t() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 (esperado '$3', obtido '$2')"; FAIL=$((FAIL+1)); fi; }

[ "${B#*127.0.0.1}" = "$B" ] && { echo "ERRO: BASE_URL não é loopback"; exit 2; }

# ---------- snapshot ----------
mkdir -p "$SNAP/theme-backup"
( cd "$TD" && find . -type f | sort | xargs sha256sum | sha256sum ) > "$SNAP/theme-before.sha"
cp -a "$TD/." "$SNAP/theme-backup/"
POSTS0=$($WP db query "SELECT COUNT(*) FROM wp_posts WHERE post_status IN ('publish','draft','private','pending')" | tail -1)
PAGES0=$($WP db query "SELECT COUNT(*) FROM wp_posts WHERE post_type='page' AND post_status='publish'" | tail -1)

rollback() {
  set +e
  for id in $PAGE_IDS; do $WP post delete "$id" --force >/dev/null 2>&1; done
  rm -rf "$TD"/*; cp -a "$SNAP/theme-backup/." "$TD/"
  local h; h=$(cd "$TD" && find . -type f | sort | xargs sha256sum | sha256sum)
  if [ "$h" != "$(cat "$SNAP/theme-before.sha")" ]; then
    echo "FATAL: rollback do tema divergiu — intervenção manual"; exit 3
  fi
}
PAGE_IDS=""
trap rollback EXIT INT TERM

# ---------- troca reversível + fixtures ----------
rm -rf "$TD"/* && cp -a "$THEME_SRC/." "$TD/"
create_page() { # slug title tpl
  local id; id=$($WP post create --post_type=page --post_status=publish \
      --post_name="$1" --post_title="QA B0 $1" --post_author=1 --porcelain)
  $WP post meta update "$id" _wp_page_template "$3" >/dev/null
  $WP post meta update "$id" tds_qa_b0 1 >/dev/null
  PAGE_IDS="$PAGE_IDS $id"
}
create_page minha-area  x templates/minha-area.php
create_page meus-cursos x templates/meus-cursos.php
create_page certificados x templates/certificados.php

fetch() { # out jar path -> code (jar vazio = guest)
  curl --noproxy '*' -s ${2:+-b "$2"} -o "$1" -w '%{http_code}' --max-filesize 2000000 "$B$3"
}
has() { grep -c "$2" "$1"; }
for s in minha-area meus-cursos certificados; do
  t "guest $s http" "$(fetch /tmp/b0g_$s.html '' /$s/)" 200
done
t 'guest minha-area state' "$(has /tmp/b0g_minha-area.html 'data-tds-state="guest"' | sed 's/^0$/0/;s/^[1-9][0-9]*$/1/')" 1
t 'guest minha-area login CTA same-origin' \
  "$(grep -o 'redirect_to=[^"& ]*' /tmp/b0g_minha-area.html | grep -c 'redirect_to=http%3A%2F%2F127.0.0.1')" 1
t 'guest register opt-in' "$(has /tmp/b0g_minha-area.html 'Criar conta EAD' | sed 's/^[1-9][0-9]*$/1/')" 1
t 'guest cert separação oficial-vs-EAD' \
  "$(($(has /tmp/b0g_certificados.html 'Certificado oficial do Programa TDS') + $(has /tmp/b0g_certificados.html 'Conclusão de curso no EAD')))" 2
t 'guest cert CTA entrar' "$(has /tmp/b0g_certificados.html 'Entrar na conta EAD' | sed 's/^[1-9][0-9]*$/1/')" 1

# ---------- login WP (cookie) A e B ----------
login() { curl --noproxy '*' -s -o /dev/null -c "$3" -w '%{http_code}' \
    -d "log=$1&pwd=$2&wp-submit=Log+In" "$B/wp-login.php"; }
t 'login A 302' "$(login student-A "$QA_PASS_A" /tmp/jarA)" 302
t 'login B 302' "$(login student-B "$QA_PASS_B" /tmp/jarB)" 302
for who in A B; do
  for s in minha-area meus-cursos; do
    f="/tmp/b0${who}_$s.html"; code=$(fetch "$f" "/tmp/jar$who" "/$s/")
    t "$who $s http" "$code" 200
    t "$who $s connected" "$(has "$f" 'data-tds-state="connected"' | sed 's/^[1-9][0-9]*$/1/')" 1
    t "$who $s logout link" "$(has "$f" 'wp-login.php?action=logout' | sed 's/^[1-9][0-9]*$/1/')" 1
  done
  code=$(fetch /tmp/b0${who}_cert.html "/tmp/jar$who" /certificados/)
  t "$who cert http" "$code" 200
  t "$who cert separação" \
    "$(($(has /tmp/b0${who}_cert.html 'Certificado oficial do Programa TDS') + $(has /tmp/b0${who}_cert.html 'Conclusão de curso no EAD')))" 2
done
# isolamento A/B: página de A não pode exibir saudação de B
t 'A não vê B' "$(grep -c 'Olá, student-B' /tmp/b0A_minha-area.html)" 0
t 'B não vê A' "$(grep -c 'Olá, student-A' /tmp/b0B_minha-area.html)" 0
# sessão forjada -> guest (fail closed)
echo 'wordpress_logged_in_forged=1' > /tmp/jarbad
f=/tmp/b0bad.html; code=$(fetch "$f" /tmp/jarbad /minha-area/)
t 'cookie forjado http' "$code" 200
t 'cookie forjado -> guest' "$(has "$f" 'data-tds-state="guest"' | sed 's/^[1-9][0-9]*$/1/')" 1

# ---------- logout roundtrip (confirm interstitial WP core) ----------
L=$(python3 - <<'PY'
import re,html
h=open('/tmp/b0A_minha-area.html',encoding='utf-8').read()
m=re.findall(r'wp-login\.php\?action=logout[^"<\s]*',h)
print(html.unescape(m[0]).replace('&#038;','&') if m else '')
PY
)
code=$(curl --noproxy '*' -s -b /tmp/jarA -c /tmp/jarA -o /tmp/lo.html -w '%{http_code}' "$B/$L")
t 'logout interstitial' "$code" 403
C=$(grep -o 'wp-login.php?action=logout[^"<]*' /tmp/lo.html | head -1 | sed 's/&#038;/\&/g;s/&amp;/\&/g')
code=$(curl --noproxy '*' -s -b /tmp/jarA -c /tmp/jarA -o /dev/null -w '%{http_code}' "$B/$C")
t 'logout confirm' "$code" 302
code=$(fetch /tmp/b0post.html /tmp/jarA /minha-area/)
t 'pos-logout -> guest' "$(has /tmp/b0post.html 'data-tds-state="guest"' | sed 's/^[1-9][0-9]*$/1/')" 1

echo "RESULT b0_smoke PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
