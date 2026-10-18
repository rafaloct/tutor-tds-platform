#!/usr/bin/env bash
# F0 (Issue #252) — runner de recibos sanitizados para WordPress/LearnPress sintético.
# Requisitos: curl, sqlite3 opcional. Nenhum secret é commitado: credenciais vêm de f0_env.sh
# (arquivo local, gitignored) ou de variáveis de ambiente.
#
# Uso:
#   cp f0_env.example.sh f0_env.sh   # preencher credenciais sintéticas locais
#   BASE_URL=http://127.0.0.1:18731 ./f0_run.sh <evidence_dir>
set -u
BASE_URL="${BASE_URL:-http://127.0.0.1:18731}"
EV="${1:-./f0-evidence-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$EV"
: "${QA_USER_A:?defina QA_USER_A}"; : "${QA_USER_B:?defina QA_USER_B}"
: "${QA_PASS_A:?defina QA_PASS_A}"; : "${QA_PASS_B:?defina QA_PASS_B}"

# req <id> <method> <path> [json] [tokenfile] — grava body sanitizado e imprime recibo 1-linha
req() {
  local id="$1" m="$2" path="$3" data="${4:-}" tf="${5:-}"
  local a=(-s --max-time 25 -o "$EV/$id.body" -w '%{http_code}' -X "$m")
  [[ -n "$tf" ]] && a+=(-H "Authorization: Bearer $(cat "$EV/$tf.tok")")
  [[ -n "$data" ]] && a+=(-H 'Content-Type: application/json' -d "$data")
  local c; c=$(curl "${a[@]}" "$BASE_URL$path")
  # sanitização: nunca imprimir token nem senha; body gravado já é truncado
  sed -i -E 's/"token":"[^"]+"/"token":"REDACTED"/g; s/(Qa#[A-Za-z0-9_]+|QaSynth[A-Za-z0-9_]+)/REDACTED/g' "$EV/$id.body" 2>/dev/null || true
  echo "$id|$m|$path|HTTP=$c|body=$(head -c 300 "$EV/$id.body" | tr -d '\n')"
}

tok() { php -r '$j=json_decode(file_get_contents($argv[1]),true);echo $j["token"]??"";' "$1" 2>/dev/null || python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('token',''))" "$1"; }

echo "== F0 recibos $EV base=$BASE_URL =="
req J01 POST /wp-json/learnpress/v1/token "{\"username\":\"$QA_USER_A\",\"password\":\"$QA_PASS_A\"}"
tok "$EV/J01.body" > "$EV/A.tok"
req J02 POST /wp-json/learnpress/v1/token "{\"username\":\"$QA_USER_B\",\"password\":\"$QA_PASS_B\"}"
tok "$EV/J02.body" > "$EV/B.tok"
req J03 POST /wp-json/learnpress/v1/token/validate '' A
req J04 GET  /wp-json/wp/v2/users/me '' A          # esperado: JWT LP não autentica WP core
req J05 GET  /wp-json/learnpress/v1/users           # diretório público? (documentar)
req E01 POST /wp-json/learnpress/v1/courses/enroll '{"id":COURSE_ID}' A
req E02 POST /wp-json/learnpress/v1/courses/enroll '{"id":COURSE_ID}' A  # duplicata
req L01 POST /wp-json/learnpress/v1/lessons/finish '{"id":LESSON_ID}' A
req L02 POST /wp-json/learnpress/v1/lessons/finish '{"id":LESSON_ID}' B  # não inscrito
req L03 POST /wp-json/learnpress/v1/lessons/finish '{"id":LESSON_ID}'     # guest
req P01 GET  "/wp-json/learnpress/v1/users/USER_A_ID" '' A
req P02 GET  "/wp-json/learnpress/v1/users/USER_B_ID" '' B
req P03 GET  "/wp-json/learnpress/v1/users/USER_A_ID" '' B               # IDOR
req Q01 POST /wp-json/learnpress/v1/quiz/start '{"id":QUIZ_ID}' A
req Q02 POST /wp-json/learnpress/v1/quiz/check_answer '{"id":QUIZ_ID,"question_id":QUESTION_ID,"answered":{"QID":"true"}}' A
req Q03 POST /wp-json/learnpress/v1/quiz/finish '{"id":QUIZ_ID,"answered":{"QID":"true"}}' A
req Q04 POST /wp-json/learnpress/v1/quiz/start '{"id":QUIZ_ID}' B        # não inscrito
req Q05 POST /wp-json/learnpress/v1/quiz/start '{"id":QUIZ_ID}'           # guest
req C01 POST /wp-json/learnpress/v1/courses/finish '{"id":COURSE_ID}' A
req Q06 POST /wp-json/learnpress/v1/quiz/start '{"id":QUIZ_ID}' A        # pós-finish (bloqueio?)
req D01 GET  /wp-json/learnpress/v1/lessons/LESSON_DRAFT_ID '' A          # rascunho
echo "== fim =="