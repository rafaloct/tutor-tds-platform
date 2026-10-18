#!/usr/bin/env bash
# b0_selftest.sh — testes sintéticos do runner F3d (Issue #274 rev.2).
# Cenários exigidos pela revisão:
#  T0 falha antes de snapshot → WORK limpo sem mutação;
#  T1 BASE_URL maliciosa rejeitada antes de qualquer curl;
#  T2 falha injetada após criação de página → trap limpa tudo;
#  T3 execução completa → 33 sinais PASS, zero material persistente em /tmp.
# Rodar no sandbox (cwd = raiz com wp-cli.phar e wordpress-mysql/).
set -u
PASS=0; FAIL=0
[ -n "${THEME_DIR:-}" ] || { echo "ERRO: THEME_DIR obrigatório para T2/T3"; exit 2; }
t() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 ($2 != $3)"; FAIL=$((FAIL+1)); fi; }
SBX="${SBX_ROOT:-$(pwd)}"
WP="php $SBX/wp-cli.phar --allow-root --path=$SBX/wordpress-mysql"
TD="$SBX/wordpress-mysql/wp-content/themes/tds-child-theme"
RUNNER="$(dirname "$0")/b0_run.sh"
GOOD_THEME="$(cd "$TD" && find . -type f | sort | xargs sha256sum | sha256sum)"

# ---------- T0: falha antes de snapshot -> elimina WORK sem tocar no WP ----------
before=$(ls -d /tmp/b0qa.* 2>/dev/null | wc -l)
out=$(BASE_URL=http://127.0.0.1:18732 THEME_DIR="$THEME_DIR" \
      B0_INJECT_FAIL_BEFORE_SNAPSHOT=1 bash "$RUNNER" 2>&1)
rc=$?
t 'T0 early exit' "$rc" 8
t 'T0 injected flag' "$(echo "$out" | grep -c 'INJECTED FAILURE before snapshot')" 1
t 'T0 early cleanup' "$(echo "$out" | grep -c 'ROLLBACK_VERIFY pre-snapshot no mutation')" 1
WORK_DIR=$(echo "$out" | grep -o 'WORK=/tmp/b0qa\.[^ ]*' | cut -d= -f2)
t 'T0 workdir registrado' "$(test -n "$WORK_DIR" && echo yes || echo no)" yes
t 'T0 workdir removido' "$([ -d "$WORK_DIR" ] && echo exists || echo gone)" gone
after=$(ls -d /tmp/b0qa.* 2>/dev/null | wc -l)
t 'T0 zero WORK residual' "$after" "$before"
h=$(cd "$TD" && find . -type f | sort | xargs sha256sum | sha256sum)
t 'T0 tema sem mutação' "$h" "$GOOD_THEME"

# ---------- T1: BASE_URL maliciosa — rejeita antes de qualquer curl ----------
for bad in \
  'https://example.invalid/path/127.0.0.1' \
  'http://127.0.0.1.evil.invalid' \
  'http://127.0.0.1:18732@evil.invalid' \
  'http://user@127.0.0.1:18732' \
  'http://127.0.0.1:18732/' \
  'http://127.0.0.1:18732/x' \
  'https://127.0.0.1:18732' \
  'http://localhost:18732/extra'; do
  out=$(BASE_URL="$bad" THEME_DIR=/nonexistent bash "$RUNNER" 2>&1)
  rc=$?
  t "T1 reject $bad" "$rc|$(echo "$out" | grep -c 'BASE_URL deve ser')" "2|1"
done

# ---------- T2: falha injetada após páginas → trap limpa ----------
source "$SBX/f0_env.sh"
# The QA env may declare shell variables without export. Child bash running
# b0_run.sh must explicitly receive the two synthetic learner credentials.
export QA_PASS_A QA_PASS_B
out=$(BASE_URL=http://127.0.0.1:18732 THEME_DIR="$THEME_DIR" \
      B0_INJECT_FAIL_AFTER_PAGES=1 bash "$RUNNER" 2>&1)
rc=$?
t 'T2 inject-fail exit' "$rc" 9
t 'T2 injected flag' "$(echo "$out" | grep -c 'INJECTED FAILURE')" 1
t 'T2 rollback ok line' "$(echo "$out" | grep -c 'ROLLBACK_VERIFY ok')" 1
WORK_DIR=$(echo "$out" | grep -o 'WORK=/tmp/b0qa\.[^ ]*' | cut -d= -f2)
t 'T2 workdir registrado' "$(test -n "$WORK_DIR" && echo yes || echo no)" yes
t 'T2 workdir removido' "$([ -d "$WORK_DIR" ] && echo exists || echo gone)" gone
m=$($WP db query "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key='tds_qa_b0'" | awk 'NF {last=$0} END {print last}')
t 'T2 meta tds_qa_b0=0' "$m" 0
for slug in minha-area meus-cursos certificados; do
  x=$($WP eval "var_export(get_page_by_path('$slug'));" 2>/dev/null)
  t "T2 slug $slug ausente" "$x" NULL
done
h=$(cd "$TD" && find . -type f | sort | xargs sha256sum | sha256sum)
t 'T2 tema hash restaurado' "$h" "$GOOD_THEME"

# ---------- T3: run completo → 33 PASS + zero remanescente ----------
before=$(ls -d /tmp/b0qa.* 2>/dev/null | wc -l)
out=$(BASE_URL=http://127.0.0.1:18732 THEME_DIR="$THEME_DIR" bash "$RUNNER" 2>&1)
rc=$?
t 'T3 exit 0' "$rc" 0
t 'T3 33 automated assertions' "$(echo "$out" | grep -c '^PASS')" 33
t 'T3 0 fail' "$(echo "$out" | grep -c '^FAIL')" 0
t 'T3 rollback ok' "$(echo "$out" | grep -c 'ROLLBACK_VERIFY ok')" 1
WORK_DIR=$(echo "$out" | grep -o 'WORK=/tmp/b0qa\.[^ ]*' | cut -d= -f2)
t 'T3 workdir registrado' "$(test -n "$WORK_DIR" && echo yes || echo no)" yes
t 'T3 workdir removido' "$([ -d "$WORK_DIR" ] && echo exists || echo gone)" gone
after=$(ls -d /tmp/b0qa.* 2>/dev/null | wc -l)
t 'T3 zero b0qa.* remanescente' "$after" "$before"
h=$(cd "$TD" && find . -type f | sort | xargs sha256sum | sha256sum)
t 'T3 tema hash restaurado' "$h" "$GOOD_THEME"

echo "RESULT b0_selftest PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
