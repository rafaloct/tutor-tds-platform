#!/usr/bin/env bash
# Testes OFFLINE dos extratores F3c — payload sintético em stdin, sem HTTP.
# Regra: estrutura obrigatória ausente/inválida => exit != 0 (fail-closed);
# payload válido => exit 0. Nenhum corpo cru é impresso em erro.
#
# Uso: bash test_extractors.sh   (no diretório dos extratores ou com PYDIR)
set -u
cd "$(dirname "$0")"
PASS=0; FAIL=0

# t <nome> <extractor> <espera_fail:0|1> <payload>
t() {
  local name="$1" ext="$2" want_fail="$3" payload="$4"
  printf '%s' "$payload" | python3 "$ext.py" >/dev/null 2>&1
  local rc=$?
  local ok
  if [[ "$want_fail" == 1 ]]; then ok=$(( rc != 0 )); else ok=$(( rc == 0 )); fi
  if [[ "$ok" == 1 ]]; then PASS=$((PASS+1)); echo "PASS $name"
  else FAIL=$((FAIL+1)); echo "FAIL $name (rc=$rc)"; fi
}

ERR='{"code":"unexpected-public-error","message":"synthetic"}'

# --- rejeições reportadas na revisão (falsos PASS) ---
t routes-vazio-fecha        extract_routes        1 '{"routes":{}}'
t routes-sem-campo          extract_routes        1 "$ERR"
t catalog-objeto-fecha      extract_catalog       1 "$ERR"
t section-items-objeto      extract_section_items 1 "$ERR"
t user-sem-id               extract_user_scope    1 "$ERR"
t curso-sem-id              extract_course_scope  1 "$ERR"
t licao-sem-id              extract_lesson_scope  1 "$ERR"
t quiz-sem-id               extract_quiz_scope    1 "$ERR"
t erro-sem-code             extract_error         1 '{"data":{"status":403}}'

# --- aceites com payload sintético válido ---
t routes-ok                 extract_routes        0 '{"routes":{"/a":{},"/b":{}}}'
t catalog-ok                extract_catalog       0 '[{"id":11}]'
t catalog-vazio-ok          extract_catalog       0 '[]'
t section-items-ok          extract_section_items 0 '[{"id":"12","type":"lp_lesson","status":"publish","name":"x"}]'
t section-items-vazio       extract_section_items 0 '[]'
t user-ok                   extract_user_scope    0 '{"id":3,"tabs":{}}'
t curso-ok                  extract_course_scope  0 '{"id":11,"name":"c","course_data":{"status":"enrolled","result":{"result":0}},"sections":[{"items":[{"id":12,"type":"lp_lesson","title":"l","status":"","locked":false}]}]}'
t curso-escopo-vazio-ok     extract_course_scope  0 '{"id":11,"name":"c","course_data":{},"sections":[]}'
t licao-ok                  extract_lesson_scope  0 '{"id":12,"name":"l","status":"publish","permalink":"http://127.0.0.1/x"}'
t quiz-ok                   extract_quiz_scope    0 '{"id":14,"name":"q","questions":[{}]}'
t erro-ok                   extract_error         0 '{"code":"rest_forbidden","data":{"status":401}}'

echo "== extractors offline: PASS=$PASS FAIL=$FAIL =="
[[ "$FAIL" -eq 0 ]]
