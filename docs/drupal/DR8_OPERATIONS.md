# DR-8 — CI e operação do portal Drupal

Status: candidato técnico da Issue #169. Sem staging, produção, registry, DNS
ou secret real — staging Drupal segue BLOCKED (G6, `ARCHITECTURE.md` §7).
MERGE_ALLOWED=NO, PRODUCTION_ALLOWED=NO.

## OBSERVED

- `drupal/` já entrega (DR-2/#163): imagem `php:8.3-apache` pinnada por digest,
  `composer.lock` obrigatório, compose `web`+`db` (MariaDB 11.8 dedicado),
  `settings.php` 100% por env com fail-closed fora de `local`,
  `tds_health` (`GET /health`, `no-store`), `config/sync` versionado,
  `install-site.sh`, `smoke.sh` (5/5), `lint.sh`, testes unitários PHPUnit.
- DR-3/#164 entrega o gateway BFF com testes unitários sintéticos.
- Secret scan de commits novos já existe: `.github/workflows/secret-scan.yml`
  (gitleaks pinnado, roda em todo PR) — não duplicado na lane Drupal.

## IMPLEMENTED (esta Issue)

### CI — `.github/workflows/drupal-ci.yml`

| Job | Conteúdo | Dependências reais |
|---|---|---|
| `composer` | `composer validate --strict` + `composer audit` no container `composer:2` pinnado por digest — a mesma ref lida do `Dockerfile` | Packagist (audit) |
| `stack` | `scripts/ci/verify-stack.sh`: build → lint (`php -l`+PHPCS+YAML+Twig) → unit (PHPUnit) → `site:install --existing-config` → smoke 5/5 → drift de config → backup → restore rehearsal descartável → evidência sanitizada | nenhuma (MariaDB é serviço Compose do próprio projeto) |

### Scripts

```text
drupal/scripts/ci/
  composer-validate.sh   # host: composer validate+audit via imagem pinnada
  config-drift.sh        # container web: drush config:status, tolerância zero
  verify-stack.sh        # host: orquestra o gate inteiro em projeto efêmero
drupal/scripts/ops/
  backup.sh              # host: dump MariaDB + files + config + manifesto
  restore-rehearsal.sh   # host: restaura backup em projeto descartável + smoke
  evidence.sh            # host: evidência sanitizada (health/versão/ops) em MD
```

- `composer-validate.sh` lê o digest `composer:2@sha256:…` do próprio
  `Dockerfile` — CI e imagem nunca divergem no pin.
- `config-drift.sh` falha com qualquer diferença entre `config/sync` e a
  config ativa; `DRUPAL_DRIFT_ALLOW` permite allowlist explícita e justificada.
- `verify-stack.sh` usa projeto `tds-drupal-ci` + porta `18080` e o rehearsal
  `tds-drupal-restore-<pid>` + `18081`: nunca toca o projeto `tds-drupal` do
  desenvolvedor. Ambos os overrides de nome (`DRUPAL_CI_PROJECT`,
  `DRUPAL_RESTORE_PROJECT`) são fail-closed por prefixo dedicado
  (`tds-drupal-ci[-*]` / `tds-drupal-restore-*`) validado ANTES do trap
  `down -v` — `tds-drupal` e aliases entre lanes são rejeitados sem qualquer
  chamada docker. Hosts Windows/Docker Desktop com o bug containerd precisam de
  `COMPOSE_BUILDER=drupal163` (builder `docker-container`) — ver
  `drupal/README.md`.
- `backup.sh` escreve em `drupal/backups/<UTC-ts>/` (gitignored) com
  `db.sql.gz` (mariadb-dump `--single-transaction`), `files.tar.gz`,
  `config.tar.gz`, `manifest.env` (SHA do commit, versão Drupal, timestamp) e
  `SHA256SUMS`. Credenciais nunca saem do container: usuário/senha são lidos
  do ambiente do serviço `db` dentro do próprio exec.
- `restore-rehearsal.sh` exige os 5 artefatos (`db.sql.gz`, `files.tar.gz`,
  `config.tar.gz`, `manifest.env`, `SHA256SUMS` cobrindo exatamente os 3
  arquivos) e confere os checksums ANTES de qualquer mutação Docker — payload
  ausente ou corrompido aborta fail-closed. Extrai `config.tar.gz` num stage
  descartável em `backups/` e o monta read-only por cima do bind-mount de dev
  `./config` via compose override gerado só no projeto efêmero: o drift check
  valida o config RESTAURADO, não o checkout corrente. Sobe `db` descartável,
  aplica o dump, sobe `web` com a mesma imagem, restaura `files/` como
  `www-data`, `cache:rebuild`, smoke 5/5 e drift limpo — prova do aceite da
  Issue ("restore descartável sobe o mesmo portal") sem depender do WordPress.
- **Fronteira de confiança do backup** (OBSERVED): `SHA256SUMS` prova
  detecção de CORRUPÇÃO, não autenticidade — um backup adulterado pode chegar
  com checksum recomputado pelo autor. Por isso o ensaio é fail-closed:
  aceita somente diretório real sob `backups/` local (saída de `backup.sh`
  neste checkout) e valida os membros de `config.tar.gz`/`files.tar.gz`
  ANTES de extrair/injetar — somente arquivos regulares e diretórios sob
  `config/`/`files/`, sem caminho absoluto, `..`, `.`, componente vazio,
  `\`, `:`, symlink, hardlink ou tipo especial, seguida de contenção
  canônica do stage (sem confiar na sanitização do `tar`). Backup de origem
  externa/off-host exige integridade autenticada out-of-band (assinatura/MAC
  ou digest de manifesto confiável) + HUMAN-GATE — este fluxo não aceita
  entrada não confiável e nenhuma chave de assinatura real é introduzida
  aqui. Rejeições provadas por
  `scripts/ops/tests/restore-rehearsal-archive-test.sh` (tarballs ustar
  forjados byte a byte + docker stubado — job `archive-validation` do CI,
  sem docker).
- `evidence.sh` emite Markdown somente com campos allowlisted (git SHA,
  branch, containers, `GET /health`+`Cache-Control`, `drush status` restrito a
  `drupal-version/bootstrap/db-driver/php-version/drush-version`). Nenhum env,
  segredo, CPF, token ou payload acadêmico.

## TARGET declarado, ainda não exercitado

- **Staging isolado real** (domínio próprio, DB próprio, cache próprio,
  `TUTOR_API_BASE_URL`→staging FastAPI, Chatwoot fake, sem analytics):
  `docker-compose.staging.yml` já declara a forma fail-closed, mas o
  provisionamento é G6/HUMAN-GATE — nada aqui cria recurso externo.
- **Backup agendado** (cron/CI recorrente): ferramenta pronta
  (`ops/backup.sh`); o agendador é decisão de infra, fora desta lane.
- **Rollback de imagem/config**: procedimento abaixo; staging exige ref
  imutável, então rollback = republicar a ref anterior.

## Rollback (procedimento)

1. **Imagem**: staging só sobe com `DRUPAL_STAGING_IMAGE_REF` pinnada por
   digest (`scripts/staging-preflight.sh` rejeita tag mutável). Rollback =
   apontar `DRUPAL_STAGING_IMAGE_REF` para o digest anterior aprovado e
   `compose -f docker-compose.yml -f docker-compose.staging.yml up -d`. Sem
   push/tag nova — o digest antigo continua imutável no registry.
2. **Config**: rollback de config = `git revert` do commit que alterou
   `config/sync` + `drush config:import` no ambiente; `config-drift.sh`
   valida convergência depois.
3. **Dados**: restore do último backup via `restore-rehearsal.sh` adaptado ao
   projeto alvo (staging real = HUMAN-GATE).

## BLOCKED / fora de escopo

- Provisionamento real de staging Drupal, DNS, secrets, registry push
  (G6 — HUMAN-GATE).
- Métricas de upstream/observabilidade externa: hoje evidência é o relatório
  sanitizado de `ops/evidence.sh`; exporter/APM é Issue própria.
- WordPress, `cartilhas_app/**`, `api/**`, `drupal/web/**`, `config/sync/**`:
  intocados nesta lane (PRs #179/#180/#181 abertos).
