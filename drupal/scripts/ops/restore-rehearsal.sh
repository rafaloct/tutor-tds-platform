#!/usr/bin/env bash
# Ensaio de restore descartavel (Issue #169): restaura um backup gerado por
# scripts/ops/backup.sh em um projeto Compose EFEMERO — novo volume, novo nome,
# porta propria — e prova que o mesmo portal sobe: smoke 5/5 + drift limpo.
# Criterio de aceite da Issue #169 sem depender do WordPress.
#
# Uso host (em drupal/):  bash scripts/ops/restore-rehearsal.sh <backup-dir> [--keep]
#   DRUPAL_RESTORE_PORT      porta HTTP do projeto descartavel (default: 18081)
#   DRUPAL_RESTORE_PROJECT   nome do projeto; SOMENTE 'tds-drupal-restore-<suffix>'
#                            e aceito — 'tds-drupal' (stack de dev) e
#                            'tds-drupal-ci*' sao rejeitados antes de qualquer
#                            chamada docker (default: tds-drupal-restore-<pid>)
#   COMPOSE_BUILDER          builder buildx caso a imagem precise ser buildada
#                            (hosts Windows/Docker Desktop com o bug containerd
#                            exigem builder docker-container, ex.: drupal163)
#
# O backup-dir DEVE conter db.sql.gz, files.tar.gz, config.tar.gz,
# manifest.env e SHA256SUMS cobrindo os tres arquivos — qualquer peca ausente
# ou checksum invalido aborta ANTES de qualquer mutacao Docker (fail-closed).
#
# Fronteira de confianca: SHA256SUMS prova deteccao de CORRUPCAO, nao
# autenticidade — um backup adulterado pode chegar com checksum recomputado
# pelo autor da adulteracao. Por isso este script aceita SOMENTE diretorio
# sob ./backups/ local (saida de scripts/ops/backup.sh neste checkout) e
# valida os membros dos tarballs antes de extrair no host ou injetar no
# container. Backup de origem externa/off-host exige integridade autenticada
# out-of-band (assinatura/MAC ou digest de manifesto confiavel) + HUMAN-GATE
# — este fluxo nao aceita entrada nao confiavel.
set -euo pipefail
cd "$(dirname "$0")/../.."

BACKUP_DIR="${1:?uso: restore-rehearsal.sh <backup-dir> [--keep]}"
KEEP=0
[ "${2:-}" = "--keep" ] && KEEP=1

log() { echo "[restore] $*"; }
fail() { echo "[restore] FAIL: $*" >&2; exit 1; }

# 0) Confianca da origem — fail-closed ANTES de inspecionar o payload:
# somente diretorio real sob ./backups/ deste checkout (gitignored, saida de
# scripts/ops/backup.sh). Rejeita symlink do backup-dir inteiro e qualquer
# path externo — sem confiar silenciosamente em entrada externa.
[ -d "$BACKUP_DIR" ] || fail "backup-dir '$BACKUP_DIR' nao existe"
mkdir -p backups
backups_root="$(cd backups && pwd -P)"
backup_real="$(cd "$BACKUP_DIR" && pwd -P)"
case "$backup_real" in
  "$backups_root"/*) ;;
  *) fail "backup-dir '$BACKUP_DIR' fora de backups/ local ($backups_root); origem externa exige integridade autenticada out-of-band + HUMAN-GATE" ;;
esac
BACKUP_DIR="$backup_real"

# Validacao fail-closed dos membros de um tar.gz ANTES de qualquer extracao
# (host) ou injecao (container). Somente arquivos regulares ('-') e
# diretorios ('d') sob <prefix>/; rejeita caminho absoluto, '..', '.',
# componente vazio, '\', ':', symlink, hardlink, device/fifo/especial.
# Nao confiamos na sanitizacao de extracao do tar — o listing e validado por
# completo primeiro. $1=arquivo.tar.gz $2=prefixo exigido $3=1 se vazio ok.
# Retorna 0 (ok) ou imprime o motivo e retorna 1.
check_archive() {
  local archive="$1" prefix="$2" allow_empty="${3:-0}"
  local names types n_names n_types
  names="$(mktemp)"; types="$(mktemp)"
  # --quoting-style=escape: um membro por linha mesmo com chars de controle
  # (newline vira "\n" literal — que o filtro de '\' rejeita adiante).
  tar --quoting-style=escape -tzf "$archive" >"$names" 2>/dev/null \
    || { rm -f "$names" "$types"; echo "arquivo ilegivel/corrompido"; return 1; }
  tar --quoting-style=escape -tzvf "$archive" 2>/dev/null | cut -c1 >"$types" \
    || { rm -f "$names" "$types"; echo "arquivo ilegivel/corrompido"; return 1; }
  n_names="$(wc -l <"$names")"; n_types="$(wc -l <"$types")"
  if [ "$n_names" -ne "$n_types" ]; then
    rm -f "$names" "$types"; echo "listagem inconsistente"; return 1
  fi
  if [ "$n_names" -eq 0 ] && [ "$allow_empty" != "1" ]; then
    rm -f "$names" "$types"; echo "arquivo vazio"; return 1
  fi
  local bad="" m_name m_type rest p
  local -a parts
  while IFS=$'\t' read -r m_name m_type; do
    case "$m_type" in
      -|d) ;;
      *) bad="membro '$m_name' com tipo proibido '$m_type'"; break ;;
    esac
    case "$m_name" in
      "$prefix"|"$prefix"/*) ;;
      *) bad="membro '$m_name' fora de $prefix/"; break ;;
    esac
    rest="${m_name#"$prefix"}"; rest="${rest#/}"
    if [ -n "$rest" ]; then
      IFS='/' read -ra parts <<< "$rest"
      for p in "${parts[@]}"; do
        case "$p" in
          ''|.|..|*\\*|*:*) bad="membro '$m_name' com componente proibido '$p'"; break 2 ;;
        esac
      done
    fi
  done < <(paste -d$'\t' "$names" "$types")
  rm -f "$names" "$types"
  [ -z "$bad" ] || { echo "$bad"; return 1; }
  return 0
}

# 1) Payload completo + integridade — antes de qualquer chamada docker.
for f in db.sql.gz files.tar.gz config.tar.gz manifest.env SHA256SUMS; do
  [ -f "$BACKUP_DIR/$f" ] || fail "$f ausente em $BACKUP_DIR"
done
diff <(printf '%s\n' config.tar.gz db.sql.gz files.tar.gz | LC_ALL=C sort) \
     <(awk '{print $NF}' "$BACKUP_DIR/SHA256SUMS" | sed 's/^\*//' | LC_ALL=C sort) \
  >/dev/null || fail "SHA256SUMS nao cobre exatamente db.sql.gz, files.tar.gz e config.tar.gz"
(cd "$BACKUP_DIR" && sha256sum --check SHA256SUMS >/dev/null) \
  || fail "checksum SHA256SUMS nao confere em $BACKUP_DIR"

# 2) Projeto estritamente descartavel — ANTES de instalar o trap EXIT (que
# roda `compose down -v`). Um override para "tds-drupal" derrubaria a stack
# de dev e seu volume; "tds-drupal-ci*" e a lane do verify-stack. Sem alias.
PROJECT="${DRUPAL_RESTORE_PROJECT:-tds-drupal-restore-$$}"
case "$PROJECT" in
  tds-drupal-restore-?*) ;;
  *) fail "DRUPAL_RESTORE_PROJECT='$PROJECT' invalido — exige 'tds-drupal-restore-<suffix>'; 'tds-drupal' e 'tds-drupal-ci*' sao proibidos" ;;
esac
[[ "$PROJECT" =~ ^[a-z0-9][a-z0-9_-]*$ ]] \
  || fail "nome de projeto Compose invalido: '$PROJECT'"
export DRUPAL_HTTP_PORT="${DRUPAL_RESTORE_PORT:-18081}"

# 3) Snapshot de config do backup extraido em area descartavel do host
# (backups/ e gitignored) e montado POR CIMA do bind-mount de dev ./config
# somente neste projeto efemero, via compose override gerado — assim
# config-drift.sh valida o config RESTAURADO, nao o checkout corrente.
#
# ANTES de extrair no host: validacao fail-closed dos membros — um tarball
# adulterado com traversal, caminho absoluto, symlink ou hardlink escaparia
# do stage ou faria o bind-mount referenciar path nao pretendido, mesmo com
# SHA256SUMS legitimo (checksum recomputado pelo autor). files.tar.gz e
# validado do mesmo jeito antes de ser injetado no container (pode ser um
# tar vazio — backup.sh gera assim quando files/ nao existe).
STAGE="$(mktemp -d backups/.restore-XXXXXXXX)"
if ! reason="$(check_archive "$BACKUP_DIR/config.tar.gz" config 0)"; then
  rm -rf "$STAGE"; fail "config.tar.gz rejeitado: $reason"
fi
if ! reason="$(check_archive "$BACKUP_DIR/files.tar.gz" files 1)"; then
  rm -rf "$STAGE"; fail "files.tar.gz rejeitado: $reason"
fi
tar -xzf "$BACKUP_DIR/config.tar.gz" -C "$STAGE" \
  || { rm -rf "$STAGE"; fail "config.tar.gz corrompido em $BACKUP_DIR"; }
[ -d "$STAGE/config/sync" ] \
  || { rm -rf "$STAGE"; fail "config.tar.gz nao contem config/sync"; }

# Contencao canonica pos-extracao: config deve ser um diretorio real dentro
# do stage e o stage nao pode conter nada alem de arquivo/diretorio (um
# symlink que escapasse da validacao seria detectado aqui — fail-closed).
stage_real="$(cd "$STAGE" && pwd -P)"
cfg_real="$(cd "$STAGE/config" && pwd -P)"
[ "$cfg_real" = "$stage_real/config" ] \
  || { rm -rf "$STAGE"; fail "config extraido fora do stage descartavel"; }
strange="$(find "$STAGE" -mindepth 1 ! -type f ! -type d -print -quit)"
[ -z "$strange" ] \
  || { rm -rf "$STAGE"; fail "stage contem membro nao-regular: $strange"; }
cat > "$STAGE/compose.restore.yml" <<OVERRIDE
# Gerado por restore-rehearsal.sh: monta o snapshot de config RESTAURADO do
# backup (read-only) por cima do bind-mount de desenvolvimento ./config,
# apenas neste projeto efemero. O checkout do host nao e tocado.
services:
  web:
    volumes:
      - ./$STAGE/config:/var/www/html/config:ro
OVERRIDE

COMPOSE=(docker compose -p "$PROJECT" -f docker-compose.yml -f "$STAGE/compose.restore.yml")

cleanup() {
  if [ "$KEEP" = "1" ]; then
    log "--keep: projeto $PROJECT preservado (http://localhost:$DRUPAL_HTTP_PORT); stage $STAGE mantido"
  else
    "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
    rm -rf "$STAGE"
  fi
}
trap cleanup EXIT

# A imagem da aplicacao e a mesma do portal (tutor-tds-drupal:local); builda se
# ausente. Em CI ela ja existe no stage anterior do verify-stack.sh.
if ! docker image inspect tutor-tds-drupal:local >/dev/null 2>&1; then
  log "imagem tutor-tds-drupal:local ausente; buildando"
  if [ -n "${COMPOSE_BUILDER:-}" ]; then
    "${COMPOSE[@]}" build --builder "$COMPOSE_BUILDER" web
  else
    "${COMPOSE[@]}" build web
  fi
fi

log "subindo db descartavel (projeto $PROJECT, porta $DRUPAL_HTTP_PORT)"
"${COMPOSE[@]}" up -d --wait db

log "aplicando dump no banco descartavel"
gzip -dc "$BACKUP_DIR/db.sql.gz" | "${COMPOSE[@]}" exec -T db sh -c \
  'mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"'

log "subindo web descartavel (mesma imagem do portal; config do backup montado ro)"
"${COMPOSE[@]}" up -d web

log "restaurando arquivos do site"
"${COMPOSE[@]}" exec -T web mkdir -p /var/www/html/web/sites/default/files
"${COMPOSE[@]}" exec -T web tar -C /var/www/html/web/sites/default -xzf - < "$BACKUP_DIR/files.tar.gz"
"${COMPOSE[@]}" exec -T web chown -R www-data:www-data /var/www/html/web/sites/default/files

log "cache rebuild + aguardando Apache"
"${COMPOSE[@]}" exec -T web vendor/bin/drush cache:rebuild
"${COMPOSE[@]}" exec -T web bash -c \
  'for _ in $(seq 1 30); do curl -fsS -o /dev/null http://localhost/ && exit 0; sleep 2; done; exit 1' \
  || fail "Apache do projeto descartavel nao respondeu"

log "smoke no portal restaurado"
"${COMPOSE[@]}" exec -T web bash scripts/smoke.sh

log "drift de config no portal restaurado"
"${COMPOSE[@]}" exec -T web bash scripts/ci/config-drift.sh

echo "RESTORE REHEARSAL OK — backup $BACKUP_DIR sobe o mesmo portal (smoke + drift limpos)"
