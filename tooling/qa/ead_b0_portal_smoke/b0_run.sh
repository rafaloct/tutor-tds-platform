#!/usr/bin/env bash
# b0_run.sh — F3d / Issue #274 rev.2: smoke B0 das páginas do tema candidato
# (PR #251) no WordPress MariaDB sintético dfd627, com rollback transacional.
#
# Rodar DENTRO do sandbox (cwd = raiz com wp-cli.phar e wordpress-mysql/).
# Requisitos: THEME_DIR=<dir extraído de wordpress/tds-child-theme @ 9905580>
#             source f0_env.sh (QA_PASS_A / QA_PASS_B)
#             BASE_URL=http://127.0.0.1:18732
# Saída: sinais booleanos + códigos HTTP. Cookies/HTML só em diretório
# efêmero privado (mktemp -d, umask 077) removido no trap — nada persiste.
set -uo pipefail
umask 077

EXPECTED_THEME_SHA="7917f40c5ad4738f32c45509c89327123779da84eb910245ab88ce533f8f9081" # PR#251@9905580
B="${BASE_URL:-}"
SBX="${SBX_ROOT:-$(pwd)}"
WP="php $SBX/wp-cli.phar --allow-root --path=$SBX/wordpress-mysql"
THEME_SRC="${THEME_DIR:-}"
TD="$SBX/wordpress-mysql/wp-content/themes/tds-child-theme"
PASS=0; FAIL=0
t() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 (esperado '$3', obtido '$2')"; FAIL=$((FAIL+1)); fi; }
fatal() { echo "FATAL $1"; exit "${2:-4}"; }

# ---------- pré-condições (fail antes de qualquer mutação) ----------
# BASE_URL: allowlist de string exata — sem userinfo, path, query, fragment,
# subdomain prefixo ou TLD sufixo.
case "$B" in
  http://127.0.0.1:18732|http://localhost:18732) ;;
  *) fatal "BASE_URL deve ser exatamente http://127.0.0.1:18732 ou http://localhost:18732" 2 ;;
esac
[ -n "$THEME_SRC" ] || fatal "THEME_DIR não definido" 2
h=$(cd "$THEME_SRC" && find . -type f | sort | xargs sha256sum | sha256sum | awk '{print $1}') \
  || fatal "falha ao hashear THEME_DIR" 2
[ "$h" = "$EXPECTED_THEME_SHA" ] \
  || fatal "THEME_DIR não é o candidato PR#251@9905580 (hash diverge: $h)" 2
[ -f "$SBX/wp-cli.phar" ] || fatal "wp-cli.phar ausente em $SBX" 2

# isolamento: DB, URLs loopback, tema instalado, slugs ausentes
[ "$($WP eval 'echo DB_NAME;' 2>/dev/null)" = "tdsqam" ] || fatal "DB_NAME != tdsqam" 2
for opt in siteurl home; do
  v=$($WP option get "$opt" 2>/dev/null)
  case "$v" in http://127.0.0.1:18732|http://localhost:18732) ;; *) fatal "$opt não é loopback: $v" 2 ;; esac
done
for slug in minha-area meus-cursos certificados; do
  x=$($WP eval "var_export(get_page_by_path('$slug'));" 2>/dev/null)
  [ "$x" = "NULL" ] || fatal "slug $slug já existe — pré-condição violada" 2
done

# Uma única QA de páginas/tema por sandbox para evitar concorrência.
# Lock mode 0600 não contém material de sessão nem dados do aluno.
exec 9>/tmp/tds-b0-sandbox-18732.lock || fatal "lock indisponível" 2
flock -n 9 || fatal "sandbox ocupado por outra QA" 2

# diretório efêmero privado desta execução — trap instalado IMEDIATAMENTE
# para que nenhum fatal posterior deixe WORK residual.
WORK=$(mktemp -d /tmp/b0qa.XXXXXXXX) || fatal "mktemp falhou" 2
chmod 700 "$WORK"; echo "WORK=$WORK"
SNAP="$WORK/snapshot"
PAGE_IDS=""
THEME_SWAPPED=0
ROLLBACK_OK=0
SNAP_READY=0

cleanup() {
  local rc=$?
  [ "$ROLLBACK_OK" = 1 ] && return
  ROLLBACK_OK=1
  trap - EXIT INT TERM
  set +e
  # An early failure precedes any mutation; the baseline may not yet exist.
  # Never dereference unset baseline variables or leave temporary files behind.
  if [ "$SNAP_READY" != 1 ]; then
    rm -rf -- "$WORK" || exit 3
    echo "ROLLBACK_VERIFY pre-snapshot no mutation"
    exit "$rc"
  fi
  local rb=0 id h2 m pcount pg ps opts slug x
  for id in $PAGE_IDS; do
    $WP post delete "$id" --force >/dev/null 2>&1 || rb=1
  done
  if [ "$THEME_SWAPPED" = 1 ]; then
    find "$TD" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + || rb=1
    cp -a "$SNAP/theme-backup/." "$TD/" || rb=1
  fi
  h2=$(cd "$TD" && find . -type f | sort | xargs sha256sum | sha256sum)
  [ "$h2" = "$(cat "$SNAP/theme-before.sha" 2>/dev/null)" ] || rb=1
  m=$($WP db query "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key='tds_qa_b0'" 2>/dev/null | awk 'NF {last=$0} END {print last}')
  [ "$m" = "$QAMETA0" ] || rb=1
  pcount=$($WP db query "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key='_wp_page_template' AND meta_value LIKE 'templates/%'" 2>/dev/null | awk 'NF {last=$0} END {print last}')
  [ "$pcount" = "$TPLMETA0" ] || rb=1
  pg=$($WP db query "SELECT COUNT(*) FROM wp_posts WHERE post_type='page' AND post_status='publish'" 2>/dev/null | awk 'NF {last=$0} END {print last}')
  [ "$pg" = "$PAGES0" ] || rb=1
  ps=$($WP db query "SELECT COUNT(*) FROM wp_posts WHERE post_status IN ('publish','draft','private','pending')" 2>/dev/null | awk 'NF {last=$0} END {print last}')
  [ "$ps" = "$POSTS0" ] || rb=1
  opts=$($WP db query "SELECT option_name, option_value FROM wp_options WHERE option_name IN ('home','siteurl','learn_press_profile_page_id') ORDER BY option_name" 2>/dev/null | sha256sum)
  [ "$opts" = "$OPTS0" ] || rb=1
  for slug in minha-area meus-cursos certificados; do
    x=$($WP eval "var_export(get_page_by_path('$slug'));" 2>/dev/null)
    [ "$x" = NULL ] || rb=1
  done
  if [ "$rb" = 1 ]; then
    # Preserve ONLY theme backup (no cookie/HTML) in private recovery dir.
    local rec
    rec=$(mktemp -d "$SBX/b0qa-recovery.XXXXXXXX") || rec=""
    if [ -n "$rec" ]; then
      chmod 700 "$rec"
      cp -a "$SNAP/theme-backup" "$rec/" 2>/dev/null
      cp "$SNAP/theme-before.sha" "$rec/" 2>/dev/null
    fi
    rm -rf -- "$WORK"  # always purge session material, even on rollback failure
    echo "FATAL rollback divergiu; tema backup: $rec; intervenção manual" >&2
    exit 3
  fi
  echo "ROLLBACK_VERIFY ok (meta=$m tpl=$pcount pages=$pg posts=$ps options=match hash=match slugs=404)"
  rm -rf -- "$WORK"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT; trap 'exit 143' TERM

# snapshot de estado (tema + contagens) antes de qualquer mutação
# Test-only injection proves cleanup before any baseline variable is available.
if [ "${B0_INJECT_FAIL_BEFORE_SNAPSHOT:-0}" = 1 ]; then
  echo "INJECTED FAILURE before snapshot"
  exit 8
fi
mkdir -p "$SNAP/theme-backup"
( cd "$TD" && find . -type f | sort | xargs sha256sum | sha256sum ) > "$SNAP/theme-before.sha" \
  || fatal "snapshot hash"
cp -a "$TD/." "$SNAP/theme-backup/" || fatal "backup tema"
POSTS0=$($WP db query "SELECT COUNT(*) FROM wp_posts WHERE post_status IN ('publish','draft','private','pending')" 2>/dev/null | awk 'NF {last=$0} END {print last}')
PAGES0=$($WP db query "SELECT COUNT(*) FROM wp_posts WHERE post_type='page' AND post_status='publish'" 2>/dev/null | awk 'NF {last=$0} END {print last}')
QAMETA0=$($WP db query "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key='tds_qa_b0'" 2>/dev/null | awk 'NF {last=$0} END {print last}')
TPLMETA0=$($WP db query "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key='_wp_page_template' AND meta_value LIKE 'templates/%'" 2>/dev/null | awk 'NF {last=$0} END {print last}')
OPTS0=$($WP db query "SELECT option_name, option_value FROM wp_options WHERE option_name IN ('home','siteurl','learn_press_profile_page_id') ORDER BY option_name" 2>/dev/null | sha256sum)
[ -n "$POSTS0" ] && [ -n "$PAGES0" ] && [ -n "$QAMETA0" ] && [ -n "$TPLMETA0" ] && [ -n "$OPTS0" ] || fatal "snapshot incompleto"
SNAP_READY=1

# ---------- troca reversível + fixtures ----------
THEME_SWAPPED=1   # a partir daqui o trap deve restaurar o tema
find "$TD" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + || fatal "limpeza tema"
cp -a "$THEME_SRC/." "$TD/" || fatal "cópia tema"
CREATED_PAGE_COUNT=0
create_page() { # slug tpl
  local id
  id=$($WP post create --post_type=page --post_status=publish \
      --post_name="$1" --post_title="QA B0 $1" --post_author=1 --porcelain) \
    || fatal "create $1"
  PAGE_IDS="$PAGE_IDS $id"   # checkpoint imediato ANTES de qualquer postmeta
  CREATED_PAGE_COUNT=$((CREATED_PAGE_COUNT + 1))
  # Partial-failure injection after the FIRST created page, before its meta.
  if [ "${B0_INJECT_FAIL_AFTER_PAGES:-0}" = "$CREATED_PAGE_COUNT" ]; then
    echo "INJECTED FAILURE after page checkpoint=$CREATED_PAGE_COUNT"
    exit 9
  fi
  $WP post meta update "$id" _wp_page_template "$2" >/dev/null || fatal "tpl $1"
  $WP post meta update "$id" tds_qa_b0 1 >/dev/null || fatal "meta $1"
}
create_page minha-area   templates/minha-area.php
create_page meus-cursos  templates/meus-cursos.php
create_page certificados templates/certificados.php

fetch() { # out jar path
  curl --noproxy '*' -s ${2:+-b "$2"} -o "$1" -w '%{http_code}' \
    --max-time 15 --max-filesize 2000000 "$B$3"
}
has() { grep -c "$2" "$1"; }
one() { sed 's/^[1-9][0-9]*$/1/'; }

for s in minha-area meus-cursos certificados; do
  t "guest $s http" "$(fetch "$WORK/g_$s.html" '' /$s/)" 200
done
t 'guest minha-area state' "$(has "$WORK/g_minha-area.html" 'data-tds-state="guest"' | one)" 1
t 'guest CTA same-origin' \
  "$(grep -o 'redirect_to=[^"& ]*' "$WORK/g_minha-area.html" | grep -c 'redirect_to=http%3A%2F%2F127.0.0.1')" 1
t 'guest register opt-in' "$(has "$WORK/g_minha-area.html" 'Criar conta EAD' | one)" 1
t 'guest cert separação' \
  "$(($(has "$WORK/g_certificados.html" 'Certificado oficial do Programa TDS') + $(has "$WORK/g_certificados.html" 'Conclusão de curso no EAD')))" 2
t 'guest cert CTA entrar' "$(has "$WORK/g_certificados.html" 'Entrar na conta EAD' | one)" 1

login() { curl --noproxy '*' -s -o /dev/null -c "$3" -w '%{http_code}' --max-time 15 \
    --data-urlencode "log=$1" --data-urlencode "pwd=$2" -d 'wp-submit=Log+In' \
    "$B/wp-login.php"; }
t 'login A 302' "$(login student-A "$QA_PASS_A" "$WORK/jarA")" 302
t 'login B 302' "$(login student-B "$QA_PASS_B" "$WORK/jarB")" 302
for who in A B; do
  for s in minha-area meus-cursos; do
    f="$WORK/${who}_$s.html"; code=$(fetch "$f" "$WORK/jar$who" "/$s/")
    t "$who $s http" "$code" 200
    t "$who $s connected" "$(has "$f" 'data-tds-state="connected"' | one)" 1
    t "$who $s logout link" "$(has "$f" 'wp-login.php?action=logout' | one)" 1
  done
  code=$(fetch "$WORK/${who}_cert.html" "$WORK/jar$who" /certificados/)
  t "$who cert http" "$code" 200
  t "$who cert separação" \
    "$(($(has "$WORK/${who}_cert.html" 'Certificado oficial do Programa TDS') + $(has "$WORK/${who}_cert.html" 'Conclusão de curso no EAD')))" 2
done
t 'A não vê B' "$(grep -c 'Olá, student-B' "$WORK/A_minha-area.html")" 0
t 'B não vê A' "$(grep -c 'Olá, student-A' "$WORK/B_minha-area.html")" 0
echo 'wordpress_logged_in_forged=1' > "$WORK/jarbad"
code=$(fetch "$WORK/bad.html" "$WORK/jarbad" /minha-area/)
t 'cookie forjado http' "$code" 200
t 'cookie forjado -> guest' "$(has "$WORK/bad.html" 'data-tds-state="guest"' | one)" 1

L=$(python3 - "$WORK/A_minha-area.html" <<'PY'
import re,html,sys
h=open(sys.argv[1],encoding='utf-8').read()
m=re.findall(r'wp-login\.php\?action=logout[^"<\s]*',h)
print(html.unescape(m[0]).replace('&#038;','&') if m else '')
PY
)
code=$(curl --noproxy '*' -s -b "$WORK/jarA" -c "$WORK/jarA" -o "$WORK/lo.html" \
    -w '%{http_code}' --max-time 15 "$B/$L")
t 'logout interstitial' "$code" 403
C=$(grep -o 'wp-login.php?action=logout[^"<]*' "$WORK/lo.html" | head -1 | sed 's/&#038;/\&/g;s/&amp;/\&/g')
code=$(curl --noproxy '*' -s -b "$WORK/jarA" -c "$WORK/jarA" -o /dev/null \
    -w '%{http_code}' --max-time 15 "$B/$C")
t 'logout confirm' "$code" 302
code=$(fetch "$WORK/post.html" "$WORK/jarA" /minha-area/)
t 'pos-logout -> guest' "$(has "$WORK/post.html" 'data-tds-state="guest"' | one)" 1

echo "RESULT b0_smoke PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
