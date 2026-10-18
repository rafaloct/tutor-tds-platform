#!/usr/bin/env bash
# Sonda read-only da ACL de section-items (Issue #270).
# Mede se itens não-publish vazam metadados (id/type/post_status/locked) para
# audiências sem privilégio editorial. NUNCA grava name/conteúdo — apenas
# flags booleanas (name_present) para não republicar título de rascunho.
#
#   EXPECT=leak       — valida a reprodução da vulnerabilidade (draft visível)
#   EXPECT=protected  — valida a proteção (draft invisível p/ não-moderadores,
#                       visível p/ moderadores do curso)
#
# Sai !=0 em qualquer asserção quebrada. Somente GET; nenhum permalink de
# lição é chamado (GET muta estado). Credenciais nunca vão para a evidência.
set -u

EV="${1:?uso: section_items_acl.sh <evidence_dir>}"
EXPECT="${EXPECT:?EXPECT=leak|protected}"
PYDIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$EV"

: "${BASE_URL:?ex.: http://127.0.0.1:18732}"
: "${QA_USER_B:?}" "${QA_PASS_B:?}"
: "${QA_USER_C:?}" "${QA_PASS_C:?}"
: "${QA_USER_I:?}" "${QA_PASS_I:?}"       # editor + autor do curso
: "${QA_USER_ADM:?}" "${QA_PASS_ADM:?}"   # administrator
: "${SECTION_ID:?}"
: "${DRAFT_ITEM_ID:?}"                    # id do item draft da seção

# --- URL restrita a loopback (urlparse real, não prefixo) ---
BASE_URL=$(BASE_URL="$BASE_URL" python3 - <<'PY'
import os, sys
from urllib.parse import urlparse
u = urlparse(os.environ["BASE_URL"])
if u.scheme != "http" or u.hostname not in ("127.0.0.1", "localhost") \
   or not (u.port and 0 < u.port < 65536) or u.path not in ("", "/") \
   or u.params or u.query or u.fragment or u.username or u.password:
    sys.exit("BASE_URL inválida — somente http://127.0.0.1|localhost:<porta>")
print(f"{u.scheme}://{u.hostname}:{u.port}")
PY
) || exit 1

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "$1|PASS"; }
bad() { FAIL=$((FAIL+1)); echo "$1|FAIL|$2"; }

get_token() { # <user> <pass> -> JWT só em memória
  local u="$1" p="$2" payload resp
  payload=$(python3 -c 'import json,sys;print(json.dumps({"username":sys.argv[1],"password":sys.argv[2]}))' "$u" "$p")
  resp=$(curl -s --noproxy '*' --max-time 20 -X POST "$BASE_URL/wp-json/learnpress/v1/token" \
    -H 'Content-Type: application/json' --data "$payload")
  printf '%s' "$resp" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("token") or "")'
}

rget() { # <id> <jwt|""> <expect_draft:visible|hidden> <label>
  local id="$1" jwt="$2" want="$3" label="$4" resp code
  local a=(-s --noproxy '*' --max-time 20 --max-filesize 262144 -w $'\n%{http_code}')
  [[ -n "$jwt" ]] && a+=(-H "Authorization: Bearer $jwt")
  resp=$(curl "${a[@]}" "$BASE_URL/wp-json/learnpress/v1/section-items/items/$SECTION_ID")
  code="${resp##*$'\n'}"; resp="${resp%$'\n'*}"
  [[ "$code" == 200 ]] || { bad "$id" "HTTP=$code exp=200"; return; }
  printf '%s' "$resp" | DRAFT_ITEM_ID="$DRAFT_ITEM_ID" python3 "$PYDIR/section_items_acl_extract.py" > "$EV/$id.body" \
    || { bad "$id" "extrator falhou"; return; }
  local vis
  vis=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["draft_item_visible"])' "$EV/$id.body")
  if [[ "$want" == visible && "$vis" == True ]] || [[ "$want" == hidden && "$vis" == False ]]; then
    ok "$id|GET|$label|draft=$vis"
  else
    bad "$id|GET|$label" "draft=$vis esperado=$want"
  fi
}

echo "== section-items ACL — EXPECT=$EXPECT SECTION=$SECTION_ID DRAFT=$DRAFT_ITEM_ID =="

T_B=$(get_token "$QA_USER_B" "$QA_PASS_B");   [[ -n "$T_B" ]]   || { bad "J-B" "token vazio"; exit 1; }
T_C=$(get_token "$QA_USER_C" "$QA_PASS_C");   [[ -n "$T_C" ]]   || { bad "J-C" "token vazio"; exit 1; }
T_I=$(get_token "$QA_USER_I" "$QA_PASS_I");   [[ -n "$T_I" ]]   || { bad "J-I" "token vazio"; exit 1; }
T_ADM=$(get_token "$QA_USER_ADM" "$QA_PASS_ADM"); [[ -n "$T_ADM" ]] || { bad "J-A" "token vazio"; exit 1; }
echo '{"receipt":"auth bodies nao gravados","tokens":"REDACTED"}' > "$EV/J00.body"

if [[ "$EXPECT" == leak ]]; then
  # Sem guarda: todo mundo vê o draft — reprodução documentada da falha.
  rget A01 ""       visible "guest"
  rget A02 "$T_B"   visible "aluno inscrito (subscriber)"
  rget A03 "$T_C"   visible "aluno nao-inscrito"
  rget A04 "$T_I"   visible "instrutor/editor"
  rget A05 "$T_ADM" visible "administrador"
else
  # Com guarda: não-moderadores só veem publish; moderadores veem draft.
  rget A01 ""       hidden  "guest"
  rget A02 "$T_B"   hidden  "aluno inscrito (subscriber)"
  rget A03 "$T_C"   hidden  "aluno nao-inscrito"
  rget A04 "$T_I"   visible "instrutor/editor"
  rget A05 "$T_ADM" visible "administrador"
  # Catálogo público preservado: itens publish continuam listados.
  cnt=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["visible_items"])' "$EV/A01.body")
  [[ "$cnt" -ge 1 ]] && ok "A06|catálogo público preservado|publish=$cnt" || bad "A06" "publish=$cnt exp>=1"
fi

echo "== fim: PASS=$PASS FAIL=$FAIL =="
[[ "$FAIL" -eq 0 ]]
