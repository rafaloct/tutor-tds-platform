# Portal Drupal — Tutor TDS (DR-2 / Issue #163)

Fundação reproduzível e isolada do portal Drupal do Tutor TDS. Escopo desta
Issue: scaffold Composer, lockfile, settings por ambiente, banco Drupal
exclusivo, health endpoint, config sync, testes, lint e stack local em
container. **Nenhuma integração acadêmica real ainda.**

Contrato de integração (o que este portal pode/não pode):
`docs/drupal/ARCHITECTURE.md`, `docs/drupal/API_CONTRACT_MATRIX.md`,
`docs/drupal/AUTH_SESSION_DECISION.md`, `docs/drupal/E2E_ACCEPTANCE.md`.

## Regras duras

- Drupal é **web/CMS/BFF**, nunca autoridade acadêmica (FastAPI/PostgreSQL é).
- O banco do Drupal é o MariaDB dedicado do serviço `db`. **Proibido apontar
  para o PostgreSQL do Tutor TDS** — o smoke test falha se isso acontecer.
- Tokens TDS ficam server-side (ver AUTH_SESSION_DECISION); nada disso está
  implementado ainda — esta Issue só entrega a fundação.
- Segredos por ambiente via `.env` (gitignored) ou gerenciador do ambiente;
  nunca no Git. `settings*.local.php` é excluído do build context via
  `.dockerignore` — override local só por bind mount explícito em runtime,
  nunca dentro da imagem.
- Fora de `DRUPAL_ENVIRONMENT=local`, `settings.php` e `install-site.sh`
  falham fechado: senhas, hash salt, admin e trusted hosts são obrigatórios e
  os defaults inseguros de dev são rejeitados.
- Nenhuma dependência de WordPress/LearnPress.
- MERGE_ALLOWED=NO, PRODUCTION_ALLOWED=NO para agentes.

## Stack

| Item | Versão |
|---|---|
| Drupal | 11.4.8 (`drupal/core-recommended`, pin no `composer.lock`) |
| PHP | 8.3 (apache) — imagem pinada por digest no `Dockerfile` |
| Composer | 2 — imagem pinada por digest no `Dockerfile` |
| Banco Drupal | MariaDB 11.8 (serviço `db`, isolado; digest pinado no compose) |
| Webroot | `web/` (drupal/recommended-project) |
| CLI | Drush 13 |

Reprodutibilidade: bases Docker e dependências PHP são pinadas (digest +
`composer.lock`). **Limite declarado:** pacotes APT são resolvidos do
repositório Debian corrente no momento do build e não são bit-for-bit
reproduzíveis — o digest fixa apenas o snapshot da imagem base.

## Estrutura

```text
drupal/
├── composer.json / composer.lock   # projeto Composer (lockfile obrigatório)
├── Dockerfile                      # imagem php:8.3-apache + composer install
├── docker-compose.yml              # web + db (MariaDB dedicado)
├── docker-compose.staging.yml      # override declarativo de staging (G6 BLOCKED)
├── .env.example                    # variáveis de ambiente (sem segredos reais)
├── phpunit.xml.dist                # PHPUnit sobre web/core/tests/bootstrap.php
├── phpcs.xml.dist                  # PHPCS padrões Drupal/DrupalPractice
├── config/sync/                    # config exportada (drush cex) versionada
├── scripts/
│   ├── bootstrap.sh                # clone limpo → build → install → smoke
│   ├── install-site.sh             # drush site:install --existing-config
│   ├── reset.sh                    # down -v → rebuild → reinstall → smoke
│   ├── smoke.sh                    # home, /health, bootstrap, DB só-Drupal
│   ├── lint.sh                     # php -l + phpcs + yaml + twig
│   ├── lint-php.sh / lint-yaml.php / lint-twig.php
├── web/
│   ├── modules/custom/tds_health/  # GET /health (JSON, no-store, verifica DB)
│   ├── themes/custom/tds_portal/   # tema base (stark) do portal
│   └── sites/default/settings.php  # settings 100% dirigidas por env
```

## Bootstrap (a partir de clone limpo)

Pré-requisito: Docker + Docker Compose. Nada de PHP/Composer no host.

```bash
cd drupal
cp .env.example .env        # só na primeira vez; ajuste se precisar
bash scripts/bootstrap.sh   # build + up + site:install + smoke
```

Portal em `http://localhost:8080` (ou `DRUPAL_HTTP_PORT`). A porta é publicada
apenas em loopback por padrão (`DRUPAL_HTTP_BIND=127.0.0.1`); para teste
autorizado em LAN/Tailscale defina `DRUPAL_HTTP_BIND=0.0.0.0` ou o IP da
interface no `.env`. Admin local: `DRUPAL_ADMIN_USER` / `DRUPAL_ADMIN_PASSWORD`
do `.env` (somente dev).

Comandos úteis:

```bash
docker compose exec web drush status            # estado do site
docker compose exec web drush config:export -y  # exporta config para config/sync
docker compose exec web drush config:import -y  # importa config/sync
docker compose exec web bash scripts/smoke.sh   # smoke (5 checagens)
docker compose exec web bash scripts/lint.sh    # lint PHP/YAML/Twig
docker compose exec web composer test-unit      # PHPUnit (unit)
```

### Problemas conhecidos (Windows / Docker Desktop)

Com o "containerd image store" ativo, o builder padrao (`docker` driver,
`desktop-linux`) pode materializar arquivos do `FROM` como 0 bytes (ex.:
`/usr/src/php.tar.xz`, `docker-php-ext-install`), produzindo imagem sem as
extensoes PHP e com `composer install` silenciosamente vazio. Confirmado em
Docker Desktop 29.8.2 + BuildKit v0.33.1; `docker run` na mesma imagem ve os
arquivos corretos — o bug e exclusivo do snapshot de build.

Workaround validado (nao altera codigo nem compose):

```bash
docker buildx create --name drupal163 --driver docker-container
docker buildx build --builder drupal163 --load -t tutor-tds-drupal:local .
docker compose up -d   # usa a imagem correta carregada acima
```

Em engines saudaveis (Linux, CI) `docker compose build` funciona direto; esta
nota existe apenas para quem reproduzir neste host Windows.

## Reset

```bash
cd drupal
bash scripts/reset.sh    # derruba containers+volume, rebuilda, reinstala
```

## Config sync

`config/sync/` contém o export de um site minimal com `tds_health` habilitado
e `tds_portal` como tema padrão. O `install-site.sh` usa
`drush site:install --existing-config`, então o clone instala direto do Git.
Mudanças de config: editar no admin/drush, `drush cex`, commitar o diff.

## Ambientes

- **local**: compose acima, credenciais dev do `.env.example`.
- **staging**: `docker compose -f docker-compose.yml -f docker-compose.staging.yml`
  com `DRUPAL_ENVIRONMENT=staging` e segredos do ambiente. O override remove o
  `build:` local e os bind mounts de código e **exige**
  `DRUPAL_STAGING_IMAGE_REF` — referência imutável da imagem da aplicação
  pinnada por digest (`repo@sha256:<64-hex>`), fornecida pelo ambiente;
  tags mutáveis são rejeitadas por `scripts/staging-preflight.sh` (rodar
  antes de `up`) e por `settings.php`/`install-site.sh` no container. Também
  obrigatórios: `DRUPAL_DB_NAME`, `DRUPAL_DB_USER`, `DRUPAL_DB_PASSWORD`,
  `DRUPAL_DB_ROOT_PASSWORD`, `DRUPAL_HASH_SALT`, `DRUPAL_TRUSTED_HOSTS`,
  `DRUPAL_ADMIN_USER` e `DRUPAL_ADMIN_PASSWORD` — `docker compose config`
  falha se algum estiver ausente, e `settings.php`/`install-site.sh` rejeitam
  os defaults dev. Provisionamento real é BLOCKED (G6) até Issue de infra;
  este override apenas declara a forma.
- **produção**: fora de escopo para agentes (HUMAN-GATE).

## Testes

- `composer test-unit` — PHPUnit (UnitTestCase) do código customizado.
- `scripts/smoke.sh` — home 200, `/health` ok, bootstrap, banco só-Drupal,
  ausência de referência ao PostgreSQL Tutor.
- `scripts/lint.sh` — `php -l`, PHPCS (Drupal+DrupalPractice), YAML, Twig.

## Status

IMPLEMENTED/TESTED-LOCAL — fundação reproduzível em container local. Nada
desta pasta conversa com a API Tutor TDS ainda; integração BFF é Issue
posterior ao scaffold.
