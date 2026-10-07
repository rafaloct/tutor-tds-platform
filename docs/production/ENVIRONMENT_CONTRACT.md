# Tutor TDS — contrato de ambientes (02/10/2026)

Estado: contrato de proteção, não promoção de release. `PRODUCTION_RELEASE_READY=false`.
Produção publicada `1.2.0+11` e fonte de manutenção `1.4.0+13` não são o
mesmo estado. O Git local (`codex/onda-0-consolidacao`, HEAD `f3ee6f4`) ainda
não tem remote/tags e contém mudanças/evidências não commitadas. Nenhum AAB ou
deploy é autorizado por este documento.

## Snapshot de compatibilidade — 07/10/2026

O candidato Dynamic Learning 2B está somente local sobre `fbb4b6a`, com head
Alembic `20261007_0030` e `DYNAMIC_ACTIVITY_ENABLED=false`. API, Flutter e runner
foram verificados localmente. A migration passou 8/8 cenários opt-in em uma
instância descartável PostgreSQL 17.11 do LARGeo no commit `de9ec577415b`.
Não houve push, merge, deploy, alteração de secret, staging ou produção.

| Backend observado | Revisão | compatibility_verified | SHA exato implantado | Consequência |
| --- | --- | --- | --- | --- |
| Cloud canônico | `20261003_0024` | `false` | ausente | não executar 2B; schema anterior a 0030 |
| VPS IPEX | `20261006_0029` | `false` | ausente | não executar 2B; schema anterior a 0030 |

Snapshot direto do Supabase em `2026-10-07T21:46:50Z`: RLS ativo em 46/46
tabelas, zero policies, zero grants diretos para `anon`/`authenticated` e grants
para `service_role`. Default ACLs amplas para objetos futuros são risco pendente;
o toggle da Data API não foi verificado. Um aviso inicial do connector foi
inconsistente com essa leitura direta e não deve ser usado como evidência.

O gate `dynamic_activity_contextual_android_e2e` é obrigatório antes de ativar
a flag, porém não bloqueia geração produtiva enquanto ela permanecer false. O
runner depende de fixture sintética pré-provisionada e identidades sintéticas
student/teacher/admin/monitor/outsider. Somente a conta outsider pode precisar
ser criada ou confirmada, caso ausente; nenhum secret de produção é necessário.

| Ambiente | Cliente | API e dados | Permitido | Proibido |
| --- | --- | --- | --- | --- |
| DEVELOPMENT | Flutter tests/mocks e API local; APK debug `.dev` ainda possui gate legado restrito a staging | localhost, `10.0.2.2`, PostgreSQL local Docker, SQLite temporário da API, outbox/cache no sandbox do app | iterar localmente onde permitido | usar em AAB/Play ou afirmar persistência produtiva |
| STAGING | APK debug `.dev`/QA isolado | `https://tutor-tds-staging.fastapicloud.dev` → PostgreSQL do projeto Supabase `lgtphbbpgqnzduhtyate` | contas/cursos sintéticos e flags experimentais, somente após gates | compartilhar DB de produção, empacotar credenciais de QA em release |
| PRODUCTION | `com.tutortds_cartilhas`, release assinado | `https://ead.ipexdesenvolvimento.cloud/tutor-api` → PostgreSQL dedicado na VPS IPEX | somente destinos/flags aprovados e backups comprovados | localhost, `.local`, staging, Supabase staging, SQLite transacional, disco do desenvolvedor |

A rota produtiva acima vem de `api/docker-compose.production.yml` (Traefik
HTTPS, PathPrefix `/tutor-api`, strip prefix) e de `config/production.example.json`.
GET `/tutor-api/health` respondeu HTTP 200 com `database=available` e TLS
válido em 02/10; isso comprova conectividade, **não** identidade do volume,
revision Alembic, backup ou compatibilidade do backend. GET `/tutor-api/live`
e `/tutor-api/version` responderam 404: o servidor implantado não deve ser
presumido idêntico à fonte local. Projeto gerenciado staging e VPS produzem
estados diferentes; nunca inferir deploy a partir do Git local.

## Bancos e persistência

| Armazenamento | Destino/seleção | Persistência | Limite |
| --- | --- | --- | --- |
| API development | `Settings.from_environment`, `DATABASE_URL` explícita ou `sqlite+pysqlite:///./tutor_tds_local.db` somente fora de production; testes usam SQLite em tmp/memória | arquivo local descartável | jamais promover como DB principal |
| Compose dev | `api/docker-compose.yml`: PostgreSQL 16, volume local `tutor_tds_api_db`, `DATABASE_URL` interna | volume Docker no computador de desenvolvimento | não é produção |
| Gate PostgreSQL Wave 2B | PostgreSQL 17.11 descartável, loopback `127.0.0.1:15439`, role exclusiva de QA | cluster temporário no LARGeo; cada teste cria e remove seu próprio banco | 8/8 no commit `de9ec577415b`; não é staging nem fonte persistente |
| Flutter em cada aparelho | `getDatabasesPath()/tds_learning_outbox.db`, SharedPreferences e secure storage | sandbox do dispositivo; outbox/retomada/cache | fila não autoriza matrícula; sincronizar quando feature e consentimento permitirem |
| Staging Cloud | FastAPI Cloud com `DATABASE_URL` do PostgreSQL Supabase isolado; revisão canônica observada `0024`; exposição Data API não verificada no snapshot direto de 07/10 | gerenciada pelo provedor; backup QA verificado em 01/10 | somente dados sintéticos; 0030 não implantada |
| Produção VPS | compose define `DATABASE_URL=postgresql+psycopg://...@db:5432/tutor_tds`; revisão observada `0029`; PostgreSQL 16 em volume nomeado `tutor_tds_api_db` | volume da VPS; SHA implantado/compatibilidade não comprovados nesta rodada | backup fora da VPS e restore drill bloqueantes; 0030 não implantada |
| Legado | PostgreSQL/pgvector compartilhado, Sheets, Cloudflare KV de certificados, acervo Drive | provedores distintos | não migrar/inferir equivalências automaticamente |

`api/app/config.py` agora exige `DATABASE_URL` PostgreSQL explícita em staging
e production, rejeita SQLite/loopback e proíbe banco staging conhecido em
production; `create_app` também verifica eventual override. `api/migrations/env.py`
impede que Alembic dos dois ambientes recaia na URL local do `alembic.ini`.
Os composes candidatos da API e dos workers declaram seus ambientes respectivos.
Esses guards **não
estão implantados** e não provam o ambiente VPS atualmente em execução.
O `alembic.ini` ainda tem exemplo localhost de desenvolvimento; produção usa
obrigatoriamente URL do ambiente. Não inferir que `db` da rede interna é um
servidor externo: é o serviço PostgreSQL persistente do compose, não notebook.
Senha, JWT/CPF pepper e credenciais Google vêm de secrets do ambiente; jamais
entrar no Git ou em `--dart-define`.

## Conexões que podem afetar o app

| Destino | Origem | Política de release |
| --- | --- | --- |
| FastAPI | `TUTOR_API_URL` compile-time; courses/eventos/auth/turmas/evidências/mídia | base produtiva exata, HTTPS; nenhum fallback a localhost/staging |
| Gateway IA/Worker e KV legado | `TUTOR_GATEWAY_URL` compile-time | URL Cloudflare produtiva exata; segredos IA/KV permanecem no Worker |
| Chatwoot/WhatsApp | host de suporte no `chatwoot_screen.dart`, widget público e deep link wa.me | conexão existente auditada; não confundir website token de widget com segredo de servidor; revisão de escopo/privacidade pendente |
| Certificados | gateway Worker legado + referências/pedidos FastAPI e PDF local | KV/referências são fontes diferentes; pedido aprovado não é emissão |
| Nove PDFs de cartilhas | `assets/data/lessons/*.json` → links Google Drive existentes | links públicos de conteúdo; bytes e disponibilidade no Drive fora do AAB não estão congelados |
| Mídia opcional | YouTube-nocookie, Cloudflare Stream SDK e metadados via API | hosts externos no WebView; `tutor-tds.invalid` é origem interna reservada do HTML do player, não API/DB. Substituiu `.local` compilado; paridade do player requer teste físico de release |
| Páginas de política/Play | AppConfig: domínios IPEX e Play | URLs públicas exatas/HTTPS |
| Apps Script/Sheets | integrações legadas/worker, não banco do Flutter | não enviar secrets ao APK nem substituir resultado humano por analytics |
| Jotform | não implementado | fora do release atual |

`cartilhas_app/config/production.example.json` é exemplo público, não prova
configuração real. `config/production.json` é ignorado e o preflight local
falhou para o estado presente; não abrir/editar secrets para forçar aprovação.
O validador Dart, o verificador de release e `preReleaseBuild` do Gradle aceitam
somente endpoints IPEX/Worker exatos e flags `REMOTE_CATALOG_ENABLED`,
`LEARNING_CONTEXT_ENABLED`, `DURABLE_LEARNING_OUTBOX_ENABLED`,
`JOURNEY_TRACEABILITY_ENABLED`, `DYNAMIC_ACTIVITY_ENABLED`,
`SIGNED_SUPPORT_IDENTITY` explicitamente false.
A política opt-in que une nove assets ao cache remoto pode ressuscitar itens
retirados editorialmente; até decisão, `REMOTE_CATALOG_ENABLED=true` bloqueia
produção mesmo após o PASS isolado em staging.

## Build, compatibilidade e rollback

Canal DEVELOPMENT permite servidor local para API/testes e deve ganhar uma
variante Android DEV própria, isolada da allowlist de staging. Hoje
`preDebugBuild` exige `TUTOR_ENVIRONMENT=staging` e host aprovado mesmo no APK
`.dev`; portanto apontar o APK existente para localhost **ainda não está
habilitado**. Não enfraquecer o gate staging para contornar essa lacuna nem
confundir o pacote debug instalado com um candidato Play. STAGING aponta só ao
host Cloud aprovado. O comando futuro único é `tooling/build_production.ps1`
com Flutter 3.44.9 explícito e `PublishedVersionCode` comprovado. Não o executar
sem checklist em `PRODUCTION_READINESS.md`; `-PreflightOnly` nunca cria AAB.
O passo final de `flutter build appbundle` não usa `--no-pub`: ele precisa
regenerar o registro de plugins depois dos testes, mantendo `integration_test`
somente como dependência dev e fora do classpath release. O lockfile continua
obrigatório; não versionar `GeneratedPluginRegistrant.java` nem promover plugin
de teste para dependência produtiva.

Contrato proposto de `GET /version` (ainda ausente na produção atual):
`api_version`, `schema_version` (revision Alembic aplicada ao DB conectado),
`minimum_supported_app_version`, `environment=production` e
`compatibility_verified` somente após teste do APK publicado com schema novo.
Não retornar URL de banco, secrets ou permissões. O script bloqueia caso o
endpoint esteja ausente/incompleto ou revisão/compatibilidade não comprovadas.
Flutter futuro compara versão mínima **apenas online** e apresenta atualização
amigável; cache/offline e acesso já autorizado não devem ser bloqueados por
falha transitória do endpoint. Fallback operacional: desligar flags aditivas,
restaurar imagem compatível, preservar migrações/dados; nunca downgrade destrutivo.
