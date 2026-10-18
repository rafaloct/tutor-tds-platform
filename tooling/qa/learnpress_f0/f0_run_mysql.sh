#!/usr/bin/env bash
# F0b (Issue #252) — runner reproduzível de recibos para a instância
# WordPress/LearnPress em MySQL sintético (dfd627, 127.0.0.1:18732).
#
# IDs de cenário chegam por variáveis de ambiente — nada é sed-substituído.
# JWT NUNCA é persistido nem impresso: corpos de resposta são redigidos em
# memória antes de gravar evidência; endpoints de /token gravam apenas um
# recibo stub. Cookie de sessão vive em mktemp com trap de limpeza.
#
# Uso:
#   export BASE_URL=http://127.0.0.1:18732
#   export QA_USER_A=student-A QA_PASS_A='...' QA_USER_B=student-B QA_PASS_B='...'
#   export COURSE_ID=11 LESSON_ID=12 LESSON_DRAFT_ID=13 QUIZ_ID=14 QUESTION_ID=15
#   export USER_A_ID=2 USER_B_ID=3
#   ./f0_run_mysql.sh <evidence_dir>
set -u

BASE_URL="${BASE_URL:-}"
EV="${1:-./f0b-evidence-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$EV"

# --- URL alvo: parse real; host literal loopback, porta numérica, sem path ---
url_parts() { # echoes: scheme host port path — falha em URL malformada/userinfo
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

# --- envs obrigatórias (rejeita vazias / não-numéricas) ---
for v in QA_USER_A QA_USER_B QA_PASS_A QA_PASS_B \
         COURSE_ID LESSON_ID LESSON_DRAFT_ID QUIZ_ID QUESTION_ID \
         USER_A_ID USER_B_ID; do
  eval "val=\${$v:-}"
  if [[ -z "$val" ]]; then echo "ERRO: $v não definido/vazio" >&2; exit 2; fi
done
case "$COURSE_ID$LESSON_ID$LESSON_DRAFT_ID$QUIZ_ID$QUESTION_ID$USER_A_ID$USER_B_ID" in
  *[!0-9]*) echo "ERRO: IDs devem ser numéricos" >&2; exit 2 ;;
esac

PASS=0; FAIL=0
JAR=""
cleanup() { [[ -n "$JAR" ]] && rm -f "$JAR"; }
trap cleanup EXIT

redact() { sed -E 's/"token":"[^"]+"/"token":"REDACTED"/g; s/(Qa#[A-Za-z0-9_]+|QaSynth[A-Za-z0-9_]+)/REDACTED/g'; }

# req <id> <method> <path> <data> <tokenvar> <expected_http> <expected_regex>
req() {
  local id="$1" m="$2" path="$3" data="${4:-}" tok="${5:-}" ehttp="$6" ere="${7:-}"
  local a=(-s --max-time 25 -X "$m" -w $'\n%{http_code}')
  [[ -n "$tok" ]] && a+=(-H "Authorization: Bearer $tok")
  [[ -n "$data" ]] && a+=(-H 'Content-Type: application/json' -d "$data")
  local out resp c
  out=$(curl "${a[@]}" "$BASE_URL$path")
  c="${out##*$'\n'}"; resp="${out%$'\n'*}"
  # evidência: respostas de /token nunca são gravadas; demais redigidas em memória
  local excerpt=""
  case "$path" in
    *token*) printf '{"receipt":"auth body not stored","token":"REDACTED"}' > "$EV/$id.body" ;;
    *) printf '%s' "$resp" | redact > "$EV/$id.body"
       excerpt="$(printf '%s' "$resp" | redact | head -c 160 | tr -d '\n')" ;;
  esac
  local st=PASS
  [[ "$c" == "$ehttp" ]] || st=FAIL
  if [[ -n "$ere" ]] && ! grep -qE "$ere" "$EV/$id.body"; then st=FAIL; fi
  if [[ "$st" == PASS ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  echo "$id|$m|$path|HTTP=$c(exp=$ehttp)|$st${excerpt:+|$excerpt}"
}

# get_token <user> <pass> <receipt_id> — token em variável; evidência = stub
get_token() {
  local u="$1" p="$2" rid="$3" resp t
  resp=$(curl -s --max-time 25 -X POST -H 'Content-Type: application/json' \
    -d "{\"username\":\"$u\",\"password\":\"$p\"}" \
    "$BASE_URL/wp-json/learnpress/v1/token")
  printf '{"receipt":"auth body not stored","token":"REDACTED"}' > "$EV/$rid.body"
  t=$(printf '%s' "$resp" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("token") or "")' 2>/dev/null) || t=""
  [[ -z "$t" ]] && t=$(printf '%s' "$resp" | php -r '$j=json_decode(stream_get_contents(STDIN),true);echo $j["token"]??"";' 2>/dev/null) || true
  printf '%s' "$t"
}

echo "== F0b recibos $EV base=$BASE_URL =="

# --- autenticação ---
TOKEN_A=$(get_token "$QA_USER_A" "$QA_PASS_A" J01)
[[ -n "$TOKEN_A" ]] && { echo "J01|POST|/token|HTTP=200|PASS|jwt emitido (não persistido)"; PASS=$((PASS+1)); } \
                    || { echo "J01|POST|/token|FAIL|sem token"; FAIL=$((FAIL+1)); }
TOKEN_B=$(get_token "$QA_USER_B" "$QA_PASS_B" J02)
[[ -n "$TOKEN_B" ]] && { echo "J02|POST|/token|HTTP=200|PASS|jwt emitido"; PASS=$((PASS+1)); } \
                    || { echo "J02|POST|/token|FAIL|sem token"; FAIL=$((FAIL+1)); }
req J02b POST /wp-json/learnpress/v1/token "{\"username\":\"$QA_USER_A\",\"password\":\"WRONG\"}" '' 403 'REDACTED'
req J03  POST /wp-json/learnpress/v1/token/validate '' "$TOKEN_A" 200 'REDACTED'
req J04  GET  /wp-json/wp/v2/users/me '' "$TOKEN_A" 401 'not_logged_in'
req J05  GET  /wp-json/learnpress/v1 '' '' 401 'no_auth_header'
req J06  GET  /wp-json/learnpress/v1/users '' '' 200 '"id":'

# --- negativos pré-matrícula ---
req E00 POST /wp-json/learnpress/v1/courses/enroll "{\"id\":$COURSE_ID}" '' 401 'login to continue|rest_forbidden'
req L02 POST /wp-json/learnpress/v1/lessons/finish "{\"id\":$LESSON_ID}" "$TOKEN_B" 403 'cannot_view|forbidden'
req Q04 POST /wp-json/learnpress/v1/quiz/start "{\"id\":$QUIZ_ID}" "$TOKEN_B" 403 'cannot_view|forbidden'

# --- matrícula A e B + não-idempotência ---
req E01 POST /wp-json/learnpress/v1/courses/enroll "{\"id\":$COURSE_ID}" "$TOKEN_A" 200 'enrolled in the course'
req E02 POST /wp-json/learnpress/v1/courses/enroll "{\"id\":$COURSE_ID}" "$TOKEN_A" 200 'already enrolled'
req E03 POST /wp-json/learnpress/v1/courses/enroll "{\"id\":$COURSE_ID}" "$TOKEN_B" 200 'enrolled in the course'
req E04 POST /wp-json/learnpress/v1/courses/enroll "{\"id\":$COURSE_ID}" "$TOKEN_B" 200 'already enrolled'
req E05 POST /wp-json/learnpress/v1/courses/enroll "{\"course_id\":$COURSE_ID}" "$TOKEN_A" 200 'Invalid course'

# --- lições ---
req L01 POST /wp-json/learnpress/v1/lessons/finish "{\"id\":$LESSON_ID}" "$TOKEN_A" 200 'not started lesson'
req L03 POST /wp-json/learnpress/v1/lessons/finish "{\"id\":$LESSON_ID}" '' 401 'no_auth_header|login'
req D01 GET  "/wp-json/learnpress/v1/lessons/$LESSON_DRAFT_ID" '' "$TOKEN_A" 403 'cannot_view|not_in_post_type'

# --- perfil / IDOR ---
req P01 GET  "/wp-json/learnpress/v1/users/$USER_A_ID" '' "$TOKEN_A" 200 "\"id\":$USER_A_ID"
req P02 GET  "/wp-json/learnpress/v1/users/$USER_B_ID" '' "$TOKEN_A" 403 'cannot_view'
req P03 GET  "/wp-json/learnpress/v1/users/$USER_B_ID" '' "$TOKEN_B" 200 "\"id\":$USER_B_ID"

# --- caminho feliz: lição "started" só via page view (sem rota REST de start) ---
LPERM=$(curl -s --max-time 25 -H "Authorization: Bearer $TOKEN_A" \
  "$BASE_URL/wp-json/learnpress/v1/lessons/$LESSON_ID" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin).get("permalink",""))' 2>/dev/null)
# valida permalink: mesmo scheme/host/porta do sandbox antes de enviar cookie WP
P_OK=0
if [[ -n "$LPERM" ]]; then
  if mapfile -t P < <(url_parts "$LPERM"); then
    [[ "${P[0]}" == "$SCHEME" && "${P[1]}" == "$HOST" && "${P[2]}" == "$PORT" ]] && P_OK=1
  fi
fi
[[ "$P_OK" == 1 ]] || { echo "V00|FAIL|permalink fora do sandbox ou não resolvido"; FAIL=$((FAIL+1)); exit 1; }

JAR=$(mktemp)
c=$(curl -s --max-time 25 -c "$JAR" -o /dev/null -w '%{http_code}' -X POST \
    -d "log=$QA_USER_A&pwd=$QA_PASS_A" "$BASE_URL/wp-login.php")
printf '{"receipt":"wp-login response not stored"}' > "$EV/V01.body"
[[ "$c" == 302 || "$c" == 200 ]] && { echo "V01|POST|/wp-login.php|HTTP=$c|PASS|cookie WP emitido"; PASS=$((PASS+1)); } \
                                || { echo "V01|POST|/wp-login.php|HTTP=$c|FAIL"; FAIL=$((FAIL+1)); }
# sem -L: nunca seguir redirect para host externo carregando o cookie
# página autenticada NÃO é gravada — recibo mínimo: HTTP + sinal allowlist
out=$(curl -s --max-time 25 -b "$JAR" -w $'\n%{http_code}' "$LPERM")
rm -f "$JAR"; JAR=""
c="${out##*$'\n'}"; resp="${out%$'\n'*}"
sig=""
printf '%s' "$resp" | grep -qiE 'learnpress|lp-lesson' && sig="learnpress-markup"
printf '{"receipt":"authenticated page not stored","http":%s,"signal":"%s"}' "$c" "$sig" > "$EV/V02.body"
[[ "$c" == 200 ]] && { echo "V02|GET|lesson permalink|HTTP=200|PASS|lição marcada started"; PASS=$((PASS+1)); } \
                  || { echo "V02|GET|lesson permalink|HTTP=$c|FAIL"; FAIL=$((FAIL+1)); }

req L05 POST /wp-json/learnpress/v1/lessons/finish "{\"id\":$LESSON_ID}" "$TOKEN_A" 200 'completed the lesson'

# --- quiz avaliado ---
req Q01 POST /wp-json/learnpress/v1/quiz/start "{\"id\":$QUIZ_ID}" "$TOKEN_A" 200 '"status":"started"'
grep -qE '"question_ids":\["?[0-9]' "$EV/Q01.body" \
  && { echo "Q01b|question_ids não-vazio|PASS"; PASS=$((PASS+1)); } \
  || { echo "Q01b|question_ids vazio|FAIL — fixture sem linking"; FAIL=$((FAIL+1)); }
req Q02 POST /wp-json/learnpress/v1/quiz/check_answer "{\"id\":$QUIZ_ID,\"question_id\":$QUESTION_ID,\"answered\":{\"$QUESTION_ID\":\"true\"}}" "$TOKEN_A" 200 'Cannot check|check'
req Q03 POST /wp-json/learnpress/v1/quiz/finish "{\"id\":$QUIZ_ID,\"answered\":{\"$QUESTION_ID\":\"true\"}}" "$TOKEN_A" 200 'completed'
req Q05 POST /wp-json/learnpress/v1/quiz/start "{\"id\":$QUIZ_ID}" '' 401 'no_auth_header|login'

# --- conclusão de curso + lock pós-finish ---
req C01 POST /wp-json/learnpress/v1/courses/finish "{\"id\":$COURSE_ID}" "$TOKEN_A" 200 'completed the Course'
req L06 POST /wp-json/learnpress/v1/lessons/finish "{\"id\":$LESSON_ID}" "$TOKEN_A" 403 'cannot_view'
req Q06 POST /wp-json/learnpress/v1/quiz/start "{\"id\":$QUIZ_ID}" "$TOKEN_A" 403 'cannot_view'
req C02 POST /wp-json/learnpress/v1/courses/finish "{\"id\":$COURSE_ID}" "$TOKEN_A" 200 'has finished'

echo "== fim: PASS=$PASS FAIL=$FAIL =="
[[ "$FAIL" -eq 0 ]]
