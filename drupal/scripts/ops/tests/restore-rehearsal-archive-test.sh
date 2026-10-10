#!/usr/bin/env bash
# Testes negativos deterministicos (Issue #169): prova que
# scripts/ops/restore-rehearsal.sh rejeita config.tar.gz / files.tar.gz
# maliciosos ANTES de qualquer chamada docker e sem escape no host — mesmo
# quando o "atacante" recomputa SHA256SUMS sobre o payload adulterado
# (SHA256SUMS prova deteccao de corrupcao, nao autenticidade).
#
# Docker e stubado via PATH — o teste NUNCA executa docker real e nenhum
# projeto/volume real e tocado. Roda em Git Bash e em CI com bash +
# coreutils + tar + gzip apenas. Os tarballs sao gerados byte a byte
# (ustar), sem depender de suporte a symlink/hardlink do filesystem —
# critico no Git Bash/Windows onde `ln -s` pode virar copia.
#
# Uso (em drupal/):  bash scripts/ops/tests/restore-rehearsal-archive-test.sh
set -uo pipefail
cd "$(dirname "$0")/../../.."

TAG="acp$$"
PASS=0; FAILED=0
t_ok()   { printf 'ok   - %s\n' "$1"; PASS=$((PASS+1)); }
t_fail() { printf 'FAIL - %s\n' "$1"; FAILED=$((FAILED+1)); }

# ---------- stub de docker -------------------------------------------------
# Registra cada invocacao em DOCKER_STUB_LOG e drena stdin (evita SIGPIPE em
# `gzip -dc | docker compose exec`). Exit code configuravel via
# DOCKER_STUB_EXIT — 0 deixa o rehearsal seguir o caminho feliz inteiro.
STUB_DIR="$(mktemp -d)"
DOCKER_STUB_LOG="$STUB_DIR/docker.log"
export DOCKER_STUB_LOG DOCKER_STUB_EXIT=0
cat > "$STUB_DIR/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$DOCKER_STUB_LOG"
cat >/dev/null 2>&1 || true
exit "${DOCKER_STUB_EXIT:-0}"
STUB
chmod +x "$STUB_DIR/docker"
export PATH="$STUB_DIR:$PATH"

# ---------- gerador minimalista de tar ustar --------------------------------
# hdr <name> <typeflag> <size> [linkname] [mode-octal] — emite header 512B.
# typeflag: 0=regular 1=hardlink 2=symlink 3=chardev 4=blockdev 5=dir 6=fifo
hdr() {
  local name="$1" type="$2" size="$3" link="${4:-}" mode="${5:-644}" tmp sum
  if [ "${#name}" -gt 100 ] || [ "${#link}" -gt 100 ]; then
    echo "hdr: campo >100 bytes" >&2; return 1
  fi
  tmp="$(mktemp)"
  {
    printf '%s' "$name"; head -c $((100 - ${#name})) /dev/zero
    printf '%07o' "$((8#$mode))"; head -c 1 /dev/zero
    printf '%07o' 0; head -c 1 /dev/zero
    printf '%07o' 0; head -c 1 /dev/zero
    printf '%011o' "$size"; head -c 1 /dev/zero
    printf '%011o' 0; head -c 1 /dev/zero
    printf '%8s' ''                          # checksum = 8 espacos no calculo
    printf '%s' "$type"
    printf '%s' "$link"; head -c $((100 - ${#link})) /dev/zero
    printf 'ustar\0'; printf '00'            # magic + version
    printf 'root'; head -c 28 /dev/zero      # uname
    printf 'root'; head -c 28 /dev/zero      # gname
    printf '%07o' 0; head -c 1 /dev/zero     # devmajor
    printf '%07o' 0; head -c 1 /dev/zero     # devminor
    head -c 155 /dev/zero                    # prefix
    head -c 12 /dev/zero                     # pad ate 512
  } > "$tmp"
  sum="$(od -An -v -tu1 "$tmp" | awk '{for(i=1;i<=NF;i++)s+=$i} END{print s}')"
  printf '%06o\0 ' "$sum" | dd of="$tmp" bs=1 seek=148 conv=notrunc status=none
  cat "$tmp"; rm -f "$tmp"
}
pad512()      { head -c $(( (512 - ($1 % 512)) % 512 )) /dev/zero; }
member_dir()  { hdr "$1" 5 0 '' 755; }
member_file() { local s="${#2}"; hdr "$1" 0 "$s" '' 644; printf '%s' "$2"; pad512 "$s"; }
member_sym()  { hdr "$1" 2 0 "$2"; }
member_hard() { hdr "$1" 1 0 "$2"; }
end_tar()     { head -c 1024 /dev/zero; }

# ---------- fixtures --------------------------------------------------------
valid_config_stream() {
  member_dir  'config/'
  member_dir  'config/sync/'
  member_file 'config/sync/core.extension.yml' 'profile: minimal'
  end_tar
}
valid_files_stream() { member_dir 'files/'; member_file 'files/readme.txt' 'x'; end_tar; }
empty_files_stream() { end_tar; }   # backup.sh gera tar vazio sem files/

# mk_backup <dir> [fn-config [fn-files]] — escreve os 5 artefatos e
# RECOMPUTA SHA256SUMS sobre o conteudo final (o que um atacante faria).
mk_backup() {
  local d="$1" cfg_fn="${2:-valid_config_stream}" files_fn="${3:-valid_files_stream}"
  mkdir -p "$d"
  "$cfg_fn"   | gzip -c > "$d/config.tar.gz"
  "$files_fn" | gzip -c > "$d/files.tar.gz"
  printf 'synthetic sql\n' | gzip -c > "$d/db.sql.gz"
  printf 'backup_version=1\ncreated_utc=test\n' > "$d/manifest.env"
  (cd "$d" && sha256sum db.sql.gz files.tar.gz config.tar.gz > SHA256SUMS)
}
resign() { (cd "$1" && sha256sum db.sql.gz files.tar.gz config.tar.gz > SHA256SUMS); }

# ---------- runner / assertions ---------------------------------------------
run_rehearsal() {
  rm -f "$DOCKER_STUB_LOG" "$STUB_DIR/out.log"
  bash scripts/ops/restore-rehearsal.sh "$1" </dev/null >"$STUB_DIR/out.log" 2>&1
}

# Rejeitado = exit != 0 E nenhuma chamada docker E sem "RESTORE REHEARSAL OK".
expect_reject() {
  local label="$1" dir="$2"
  if run_rehearsal "$dir"; then
    t_fail "$label — rehearsal ACEITOU backup malicioso"; return
  fi
  if [ -s "$DOCKER_STUB_LOG" ]; then
    t_fail "$label — docker invocado apos rejeicao: $(head -1 "$DOCKER_STUB_LOG")"; return
  fi
  if grep -q 'RESTORE REHEARSAL OK' "$STUB_DIR/out.log"; then
    t_fail "$label — saiu OK indevidamente"; return
  fi
  t_ok "$label"
}

# ---------- execucao ---------------------------------------------------------
mkdir -p backups
B="backups/.negtest-$TAG"
cleanup() { rm -rf "$B" "$STUB_DIR" "backups/evil-$TAG" "evil-$TAG" .negtest-out-"$TAG" backups/.restore-*; }
trap cleanup EXIT

# 1) Traversal: config/../../ sairia do stage para backups/
trav() { member_dir 'config/'; member_file "config/../../evil-$TAG" 'x'; member_dir 'config/sync/'; member_file 'config/sync/ok.yml' 'x'; end_tar; }
mk_backup "$B/trav" trav
expect_reject "traversal config/../../" "$B/trav"
[ ! -e "backups/evil-$TAG" ] || t_fail "traversal escapou para backups/"
[ ! -e "evil-$TAG" ]         || t_fail "traversal escapou para a raiz"

# 2) Traversal intermediario: config/sub/../../evil
trav2() { member_dir 'config/'; member_dir 'config/sub/'; member_file "config/sub/../../evil-$TAG" 'x'; end_tar; }
mk_backup "$B/trav2" trav2
expect_reject "traversal config/sub/../../" "$B/trav2"

# 3) Caminho absoluto + raiz './'
absdir() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/ok.yml' 'x'; member_file "/etc/evil-$TAG" 'x'; end_tar; }
mk_backup "$B/abs" absdir
expect_reject "caminho absoluto" "$B/abs"
reldir() { member_dir 'config/'; member_dir 'config/sync/'; member_file './config/sync/evil.yml' 'x'; end_tar; }
mk_backup "$B/rel" reldir
expect_reject "prefixo ./" "$B/rel"

# 4) symlink e hardlink (forjados byte a byte — nao dependem de ln -s)
sym() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/ok.yml' 'x'; member_sym 'config/sync/evil' '/etc/passwd'; end_tar; }
mk_backup "$B/sym" sym
expect_reject "symlink em config/sync" "$B/sym"
hrd() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/ok.yml' 'x'; member_hard 'config/sync/hard' 'config/sync/ok.yml'; end_tar; }
mk_backup "$B/hard" hrd
expect_reject "hardlink em config/sync" "$B/hard"
rootsym() { member_sym 'config' '/tmp'; member_dir 'config/sync/'; end_tar; }
mk_backup "$B/rootsym" rootsym
expect_reject "membro 'config' como symlink" "$B/rootsym"

# 5) Tipos especiais: char device e fifo
cdev() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/ok.yml' 'x'; hdr 'config/dev0' 3 0; end_tar; }
mk_backup "$B/cdev" cdev
expect_reject "char device" "$B/cdev"
fifo() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/ok.yml' 'x'; hdr 'config/pipe' 6 0; end_tar; }
mk_backup "$B/fifo" fifo
expect_reject "fifo" "$B/fifo"

# 6) Componentes proibidos: '.', '..', vazio, '\', ':'
dotc() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/./sync/evil.yml' 'x'; end_tar; }
mk_backup "$B/dotc" dotc
expect_reject "componente '.'" "$B/dotc"
bs() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/a\b.yml' 'x'; end_tar; }
mk_backup "$B/bs" bs
expect_reject "componente com backslash" "$B/bs"
colon() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/a:b.yml' 'x'; end_tar; }
mk_backup "$B/colon" colon
expect_reject "componente com ':'" "$B/colon"
emptycomp() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync//evil.yml' 'x'; end_tar; }
mk_backup "$B/emptycomp" emptycomp
expect_reject "componente vazio" "$B/emptycomp"
sibling() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/ok.yml' 'x'; member_file "evil-$TAG/x" 'x'; end_tar; }
mk_backup "$B/sibling" sibling
expect_reject "membro fora de config/" "$B/sibling"
prefix() { member_dir 'config/'; member_dir 'config/sync/'; member_file 'config/sync/ok.yml' 'x'; member_file 'config-evil/x.yml' 'x'; end_tar; }
mk_backup "$B/prefix" prefix
expect_reject "prefixo irmao config-evil/" "$B/prefix"

# 7) config.tar.gz corrompido (nem gzip) com SHA256SUMS recomputado
mk_backup "$B/corrupt"
printf 'nao sou gzip nem tar' > "$B/corrupt/config.tar.gz"
resign "$B/corrupt"
expect_reject "config.tar.gz corrompido" "$B/corrupt"

# 8) files.tar.gz malicioso (config valido): traversal dentro do payload de files
badfiles() { member_dir 'files/'; member_file "files/../evil-$TAG" 'x'; end_tar; }
mk_backup "$B/badfiles" valid_config_stream badfiles
expect_reject "files.tar.gz com traversal" "$B/badfiles"

# 9) Fronteira de confianca: backup VALIDO mas fora de backups/ local
OUT=".negtest-out-$TAG"
mk_backup "$OUT"
if run_rehearsal "$OUT"; then
  t_fail "backup fora de backups/ ACEITO"
elif [ -s "$DOCKER_STUB_LOG" ]; then
  t_fail "backup externo — docker invocado"
else
  grep -q 'backups/' "$STUB_DIR/out.log" \
    && t_ok "backup externo rejeitado antes do docker" \
    || t_fail "backup externo rejeitado sem motivo de fronteira"
fi
rm -rf "$OUT"

# 10) Controle positivo: backup legitimo atravessa a validacao e completa o
# rehearsal inteiro com docker stubado (exit 0) — inclusive files.tar.gz
# VAZIO (forma emitida por backup.sh quando files/ nao existe).
mk_backup "$B/valid" valid_config_stream empty_files_stream
if run_rehearsal "$B/valid" \
   && grep -q 'RESTORE REHEARSAL OK' "$STUB_DIR/out.log" \
   && grep -q 'compose' "$DOCKER_STUB_LOG" \
   && grep -q 'down -v' "$DOCKER_STUB_LOG"; then
  t_ok "backup valido — rehearsal completo + down -v isolado"
else
  t_fail "backup valido rejeitado/falhou: $(tail -3 "$STUB_DIR/out.log")"
fi
[ -z "$(find backups -maxdepth 1 -name '.restore-*' -print -quit)" ] \
  && t_ok "stage descartavel removido" \
  || t_fail "stage .restore-* vazou em backups/"

echo
echo "RESULT: $PASS ok, $FAILED falha(s)"
[ "$FAILED" -eq 0 ]
