#!/usr/bin/env bash
# F3c (Issue #268) — sonda READ-ONLY autenticada do contrato Minha Área LP
# para EadMyAreaReader / EadAccountReadSnapshot (PR #266).
# Sandbox: WordPress/LearnPress MariaDB sintético (dfd627, 127.0.0.1:18732).
#
# REGRAS DURAS:
#   - Somente GET autenticado comprovadamente sem side-effects.
#   - PROIBIDO GET de permalink de lição/página de aprendizado (muda estado).
#   - Nenhum POST além de /token (sessão efêmera sintética).
#   - Nunca gravar/imprimir JWT, cookie, senha, CPF, HTML autenticado,
#     headers de resposta ou campos pessoais. Evidência = projeção allowlist.
#   - Página autenticada nunca é armazenada (só campos mapeados).
#
# Uso:
#   export BASE_URL=http://127.0.0.1:18732
#   export QA_USER_A=student-A QA_PASS_A='...' QA_USER_B=student-B QA_PASS_B='...'
#   export QA_USER_C=student-C QA_PASS_C='...'
#   export COURSE_ID=11 LESSON_ID=12 LESSON_DRAFT_ID=13 QUIZ_ID=14 QUESTION_ID=15
#   export USER_A_ID=2 USER_B_ID=3 USER_C_ID=5 SECTION_ID=1
#   ./f3_readonly.sh <evidence_dir> [fixture_out_dir]
set -u

BASE_URL="${BASE_URL:-}"
EV="${1:-./f3c-evidence-$(date +%Y%m%d-%H%M%S)}"
FIXTURE_OUT="${2:-}"
mkdir -p "$EV"

# --- URL alvo: parse real; host literal loopback, porta numérica, sem path ---
url_parts() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
if u.scheme not in ("http", "https") or not u.hostname or u.username or u.password:
    sys.exit(1)
try:
    port = u.port or (443 if u.scheme == "https" else 80)
except ValueError:
    sys.exit(1)
print(u.scheme); print(u.hostname); print(port); print(u.path or "/")
PY
}
mapfile -t U < <(url_parts "$BASE_URL") \
  || { echo "ERRO: BASE_URL malformada" >&2; exit 2; }
SCHEME="${U[0]}" HOST="${U[1]}" PORT="${U[2]}" URLPATH="${U[3]}"
case "$HOST" in
  127.0.0.1|localhost) ;;
  *) echo "ERRO: host '$HOST' não é loopback/sandbox — abortado" >&2; exit 2 ;;
esac
[[ "$URLPATH" == "/" ]] || { echo "ERRO: path inesperado em BASE_URL ('$URLPATH')" >&2; exit 2; }

for v in QA_USER_A QA_USER_B QA_USER_C QA_PASS_A QA_PASS_B QA_PASS_C \
         COURSE_ID LESSON_ID LESSON_DRAFT_ID QUIZ_ID QUESTION_ID \
         USER_A_ID USER_B_ID USER_C_ID SECTION_ID; do
  eval "val=\${$v:-}"
  if [[ -z "$val" ]]; then echo "ERRO: $v não definido/vazio" >&2; exit 2; fi
done
case "$COURSE_ID$LESSON_ID$LESSON_DRAFT_ID$QUIZ_ID$QUESTION_ID$USER_A_ID$USER_B_ID$USER_C_ID$SECTION_ID" in
  *[!0-9]*) echo "ERRO: IDs devem ser numéricos" >&2; exit 2 ;;
esac

PASS=0; FAIL=0

# get_token <user> <pass> <receipt_id> — token em variável; evidência = stub.
get_token() {
  local u="$1" p="$2" rid="$3" resp t payload
  payload=$(python3 -c 'import json,sys;print(json.dumps({"username":sys.argv[1],"password":sys.argv[2]}))' "$u" "$p")
  resp=$(curl -s --noproxy '*' --max-time 20 -X POST -H 'Content-Type: application/json' \
    -d "$payload" \
    --max-filesize 262144 \
    "$BASE_URL/wp-json/learnpress/v1/token")
  printf '{"receipt":"auth body not stored","token":"REDACTED"}' > "$EV/$rid.body"
  t=$(printf '%s' "$resp" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("token") or "")' 2>/dev/null) || t=""
  printf '%s' "$t"
}

# rget <id> <path> <token> <expected_http> <extractor> — GET read-only;
# <extractor> = nome de script python embutido que recebe o corpo em stdin e
# emite projeção allowlist JSON (única coisa persistida em evidência).
rget() {
  local id="$1" path="$2" tok="${3:-}" ehttp="$4" ext="$5"
  local a=(-s --noproxy '*' --max-time 20 --max-filesize 262144 -w $'\n%{http_code}\t%{redirect_url}')
  [[ -n "$tok" ]] && a+=(-H "Authorization: Bearer $tok")
  local out resp meta c redir extfail=0
  out=$(curl "${a[@]}" "$BASE_URL$path")
  meta="${out##*$'\n'}"; resp="${out%$'\n'*}"
  c="${meta%%$'\t'*}"; redir="${meta#*$'\t'}"
  printf '%s' "$resp" | python3 "$PYDIR/$ext.py" > "$EV/$id.body" 2>"$EV/$id.err" \
    || { extfail=1; printf '{"extraction_error":true}' > "$EV/$id.body"; }
  local st=PASS
  [[ "$c" == "$ehttp" ]] || st=FAIL
  [[ -n "$redir" ]] && st=FAIL   # leitura não deve redirectar
  [[ "$extfail" == 1 ]] && st=FAIL   # resposta que não extrai não é evidência válida
  if [[ "$st" == PASS ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  echo "$id|GET|$path|HTTP=$c(exp=$ehttp)|$st"
}

PYDIR="$(cd "$(dirname "$0")" && pwd)"

echo "== F3c leitura autenticada $EV base=$BASE_URL =="

# --- sessões efêmeras A/B/C (stub de recibo, token só em variável) ---
TOKEN_A=$(get_token "$QA_USER_A" "$QA_PASS_A" J01)
[[ -n "$TOKEN_A" ]] && { echo "J01|POST|/token|PASS|jwt A emitido (não persistido)"; PASS=$((PASS+1)); } \
                    || { echo "J01|POST|/token|FAIL|sem token A"; FAIL=$((FAIL+1)); }
TOKEN_B=$(get_token "$QA_USER_B" "$QA_PASS_B" J02)
[[ -n "$TOKEN_B" ]] && { echo "J02|POST|/token|PASS|jwt B emitido"; PASS=$((PASS+1)); } \
                    || { echo "J02|POST|/token|FAIL|sem token B"; FAIL=$((FAIL+1)); }
TOKEN_C=$(get_token "$QA_USER_C" "$QA_PASS_C" J03)
[[ -n "$TOKEN_C" ]] && { echo "J03|POST|/token|PASS|jwt C emitido"; PASS=$((PASS+1)); } \
                    || { echo "J03|POST|/token|FAIL|sem token C"; FAIL=$((FAIL+1)); }

# TTL do token (claims decodificados — apenas números persistidos)
echo "$TOKEN_A" | python3 -c '
import json,sys,base64
p=sys.stdin.read().strip().split(".")[1]; p+="="*(-len(p)%4)
d=json.loads(base64.urlsafe_b64decode(p))
json.dump({"exp":d.get("exp"),"iat":d.get("iat"),
  "ttl_hours":round((d.get("exp",0)-d.get("iat",0))/3600,1)},
  open("'"$EV"'/T01.body","w"))' \
  && { echo "T01|token claims|PASS|ttl extraído (valor não persistido)"; PASS=$((PASS+1)); } \
  || { echo "T01|token claims|FAIL"; FAIL=$((FAIL+1)); }

# --- índice de rotas (nomes apenas) ---
rget R01 /wp-json/learnpress/v1 "$TOKEN_A" 200 extract_routes

# --- /users/{id} — escopo próprio vs IDOR vs anônimo vs inexistente ---
rget R02 "/wp-json/learnpress/v1/users/$USER_A_ID" "$TOKEN_A" 200 extract_user_scope
rget R02b "/wp-json/learnpress/v1/users/$USER_B_ID" "$TOKEN_B" 200 extract_user_scope
rget R03 "/wp-json/learnpress/v1/users/$USER_B_ID" "$TOKEN_A" 403 extract_error
rget R04 "/wp-json/learnpress/v1/users/$USER_A_ID" "" 401 extract_error
rget R05 /wp-json/learnpress/v1/users/99999 "$TOKEN_A" 404 extract_error
rget R06 "/wp-json/learnpress/v1/users/$USER_A_ID" "invalid.token.here" 401 extract_error
rget R07 "/wp-json/learnpress/v1/users/$USER_C_ID" "$TOKEN_C" 200 extract_user_scope

# --- /courses/{id} — leitura por usuário: A finished / B enrolled / C none / guest ---
rget R08 "/wp-json/learnpress/v1/courses/$COURSE_ID" "$TOKEN_A" 200 extract_course_scope
rget R09 "/wp-json/learnpress/v1/courses/$COURSE_ID" "$TOKEN_B" 200 extract_course_scope
rget R10 "/wp-json/learnpress/v1/courses/$COURSE_ID" "$TOKEN_C" 200 extract_course_scope
rget R11 "/wp-json/learnpress/v1/courses/$COURSE_ID" "" 200 extract_course_scope
rget R12 /wp-json/learnpress/v1/courses/99999 "$TOKEN_A" 403 extract_error
rget R13 /wp-json/learnpress/v1/courses "" 200 extract_catalog

# --- itens do curso ---
rget R14 "/wp-json/learnpress/v1/lessons/$LESSON_ID" "$TOKEN_B" 200 extract_lesson_scope
rget R15 "/wp-json/learnpress/v1/lessons/$LESSON_ID" "" 401 extract_error
rget R16 "/wp-json/learnpress/v1/lessons/$LESSON_ID" "$TOKEN_A" 403 extract_error
rget R17 "/wp-json/learnpress/v1/lessons/$LESSON_DRAFT_ID" "$TOKEN_A" 403 extract_error
rget R18 "/wp-json/learnpress/v1/quiz/$QUIZ_ID" "$TOKEN_B" 200 extract_quiz_scope
rget R19 "/wp-json/learnpress/v1/quiz/$QUIZ_ID" "$TOKEN_A" 403 extract_error
rget R20 "/wp-json/learnpress/v1/quiz/$QUIZ_ID" "" 401 extract_error
rget R21 "/wp-json/learnpress/v1/questions/$QUESTION_ID" "$TOKEN_B" 403 extract_error

# --- section-items (currículo por seção) ---
rget R22 "/wp-json/learnpress/v1/section-items/items/$SECTION_ID" "$TOKEN_A" 200 extract_section_items
rget R23 "/wp-json/learnpress/v1/section-items/items/$SECTION_ID" "" 200 extract_section_items

# --- isolamento por usuário: mesma URL, escopos diferentes ---
rget R24 "/wp-json/learnpress/v1/courses/$COURSE_ID" "$TOKEN_B" 200 extract_course_scope

# --- typed fixtures (só quando OBSERVED) ---
if [[ -n "$FIXTURE_OUT" ]]; then
  mkdir -p "$FIXTURE_OUT"
  python3 "$PYDIR/emit_fixtures.py" "$EV" "$FIXTURE_OUT" "$USER_A_ID" "$USER_B_ID" "$USER_C_ID" \
    && { echo "FIX|fixtures emitidos em $FIXTURE_OUT|PASS"; PASS=$((PASS+1)); } \
    || { echo "FIX|fixtures|FAIL"; FAIL=$((FAIL+1)); }
fi

echo "== fim: PASS=$PASS FAIL=$FAIL =="
[[ "$FAIL" -eq 0 ]]
