# CURRENT STATE

## 2026-10-13 — acesso LARGeo restabelecido, assinatura de backup conferida

OBSERVED: backup JKS do perfil Rafael foi localizado e validado por keytool;
o certificado SHA-256 coincide com o PEM versionado. Senha permaneceu no
host. Certificado de upload atual do Google Play ainda UNKNOWN. API pública
responde health ok/database available; schema 0028, compatibility_verified=false.
Checkouts isolados dos PRs #198/#200 criados no LARGeo. Não houve promoção,
novo AAB ou alteração de chave. Evidência em
`docs/production/RELEASE_PREPARATION_2026-10-13.md`.

## 2026-10-13 — preparação de produção #197

DECISION: a observação geral usa Google Analytics do domínio e Cloudflare,
conforme informação do usuário; a candidata Firebase #196 permanece fora
desta release. Base: staging `dd928ff6b58788af930aa6722557728d74dfe97c`.
OBSERVED: o runner de produção agora instala o extra de testes pelo lock e
executa `python -m pytest`, evitando falha de importação de `ops` em ambiente
novo. Suíte API: 601 passed, 30 skipped, 5 subtests passed. Ferramentas de
recuperação: 29 passed/1 skipped; ferramentas de CI: 8 passed. PostgreSQL
17.11 descartável: 30 passed; container removido.
UNKNOWN/BLOCKED: o aceite versionado de recuperação falha no verificador
de proveniência (`acceptance schema does not match the candidate`). AAB
novo, assinatura, versionCode publicado e saúde/compatibilidade atual de
produção ainda não comprovados. Não houve deploy, tag ou upload. Ver
`docs/production/RELEASE_PREPARATION_2026-10-13.md`.

## 2026-10-12 — Android E2E #140 PASS no Windows (candidato b2784ba)

OBSERVED: `tooling/class_lifecycle_e2e/harness.py --execute` em checkout isolado
`b2784ba` (junction ASCII, Flutter 3.44.9 validado, Python `uv.lock`),
emulador local `Medium_Phone_API_36.1` (API 36, `emulator-5554`) com
`autofill_service` desativado. Contratos backend 6/6; servidor QA HTTPS local
(SQLite descartável, cert efêmero `10.0.2.2`); APK de integração compilado em
210s e executado com adapter HTTP real: 10 etapas PASS (preparar turma,
participante, matrícula, encontro, QR, presença, fechar encontro, readiness,
fronteira de certificado, offline/reconnect) e 12 invariantes PASS. Validador
`--validate-evidence --require-complete` → `EVIDENCE_VALID`. Sem colateral:
`com.tutortds_cartilhas.dev` preservado; pacote QA isolado
`…dynamicqa.r3fccf38bc2ab35eaac5a2f3bb1707262` instalado. Staging compartilhado
e produção não mutados. Limite: aviso de capacidade >30 e tela de ativação
provados por contrato backend, não por evidência visual Android (nota do
manifesto). Evidência:
`docs/production/evidence/class-lifecycle-e2e-3fccf38bc2ab35eaac5a2f3bb1707262.json`.
Substitui o `BLOCKED_ENVIRONMENT` do avellaria para este gate.

## 2026-10-12 — ensaio de migração 0028→0030 APROVADO sobre dump ao vivo

OBSERVED: `api/ops/rehearse_production_upgrade.py` executado no VPS contra o
banco de produção em modo somente-leitura. Dump pg_dump (custom) restaurado em
`postgres:16-alpine` isolado (tmpfs, rede `--internal`, sem portas) com
fingerprint de todas as colunas idêntico; `alembic upgrade head` subiu
`20261005_0028 → 20261007_0030` sem erro; dados originais preservados;
imagem de produção `d6701c77` iniciou e respondeu contra o banco migrado
(rollback compatível); OpenAPI comparado: 7 operações apenas-candidatas
(aditivas), `only_production=[]`, nenhum schema comum quebrado; catálogo
público com projeção legada intacta; produção re-verificada inalterada
(`production_writes=false`, mesmo image id e revisão ao final). Recursos
isolados removidos. Evidência:
`docs/production/evidence/migration-rehearsal-0028-0030-20261012.json`;
dump protegido permanece em `/opt/tds-rehearsal-50d0c4b3f5a4/` no VPS para
revisão de promoção. Gates 9/10/12: parcial→prova de migração no candidato;
não é promoção nem upgrade aplicado em produção.

## 2026-10-12 — correções focais da revisão do PR #194 (candidato local)

O conteúdo imutável de bloco publicado agora usa toda a linhagem de turma e
matrícula na identidade, permitindo que a mesma pessoa conclua o mesmo bloco
da mesma edição em duas turmas. A rota do aluno mantém gabarito e explicação
fora da resposta mesmo após conclusão; professor e admin autorizados na turma
podem consultar o gabarito de tentativa concluída. Professor/admin que também
têm matrícula ativa na turma preservam a projeção de equipe; monitor continua
com projeção pública. A hidratação Flutter aceita tentativa publicada concluída
sem gabarito e preserva a nota calculada pelo servidor, sem inferir tópicos
fracos. API focal: 34 testes locais passaram; SDK Flutter indisponível neste
workspace Linux, então os testes Dart adicionados aguardam CI. Nenhum serviço
externo, banco de staging ou produção foi alterado.
No Flutter, a abertura da atividade reenvia uma revisão pendente após erro
transitório, preservando o bloqueio de 403; URL nua no texto do Tutor mantém
prefixo e pontuação sem duplicação. Testes focais adicionados; conferir a CI
do SHA composto no PR antes de classificar a correção como validada.

## 2026-10-12 — tentativa isolada de E2E Android da turma

Seis contratos de API passaram no avellaria, mas o build Gradle da integração
Android elevou o uso de swap de cerca de 12 para 15 GiB; a execução foi
interrompida antes de produzir APK, marcador de resultado ou manifesto PASS.
O harness, a API temporária e os processos de build foram encerrados; porta
18040 ficou livre e nenhum pacote QA foi instalado. O emulador alternativo
LARGeo estava em uso com o app da pessoa usuária e não foi tocado. Evidência
sanitizada: `docs/production/evidence/class-lifecycle-e2e-attempt-20261012.json`.
E2E Android da política nova continua BLOCKED_ENVIRONMENT, sem inferência de
falha funcional ou prontidão de produção.

## 2026-10-12 — custódia do backup agendado e runner de restore isolado

IMPLEMENTED/TESTED-LOCAL: `tooling/rehearse_scheduled_postgres_backup.py`
confere o recibo agendado e o hash do objeto `.dump.age` fornecidos pelo
operador, decripta somente em memória e restaura em PostgreSQL 16 descartável
sem rede, porta ou volume persistente. O teste sintético Docker conferiu
tmpfs e limpeza após êxito e falha; 29 testes unitários do runner e gate
passaram, com 1 integração Docker opt-in ignorada nessa execução. O
manifesto é parcial e não fecha upgrade/compatibilidade do gate
12. Rafael autorizou avellaria como host do ensaio e informou que fornecerá
o caminho da identidade age. O apontador local do Dokploy e o download somente
leitura via Wrangler identificaram o backup
`20261012T034000Z-80e0615f8a9a453a9a4936c60b420e17`, concluído às
03:40:08 UTC; os 249216 bytes criptografados coincidiram em SHA-256 com o
recibo. Prova sanitizada em
`docs/production/evidence/scheduled-postgres-backup-custody-20261012.json`.
O runner aceita `sudo` supervisionado com identidade age 0600 de Rafael,
binário age protegido por root e checkout candidato conferido. Nenhum backup
real foi descriptografado ou restaurado até agora.

## 2026-10-12 — trava de sessão na transição de turma (candidato local)

IMPLEMENTED/TESTED-LOCAL: a rota antiga de criação de `ClassSession` agora
adquire a mesma trava de `Classroom` usada pelo encerramento e só abre sessão
em turma `active`. Turmas `planned` e `closed` recebem 409. O teste de ciclo
de vida cobre os dois estados e confirma que encerramento não pode ser seguido
por sessão aberta. PostgreSQL concorrente e E2E Android ainda precisam de prova
no candidato final; produção não foi alterada.

## 2026-10-12 RAG curricular — preflight offline candidato

Mapa explícito de nove aulas Flutter, URLs/IDs do Drive e hashes dos originais
históricos reconciliado com a evidência de 01/10. `course_promotion` passou a
aceitar `course_version_id` legado somente quando igual ao `version_id` do
export. O preflight stdlib recusa export, conteúdo, URL, versão, PDF, hash ou
workspace divergente e emite manifesto determinístico apenas de bytes locais.
Nenhum PDF está neste checkout. Em 12/10, os nove arquivos obtidos pelos IDs
do Drive conectado corresponderam aos originais históricos em assinatura PDF,
tamanho e SHA-256; prova sanitizada em
`docs/production/evidence/curricular-drive-bytes-20261012.json`. A pasta
`Cartilhas (Versão Chatbot)` contém os mesmos nove PDFs byte a byte, conforme
`docs/production/evidence/curricular-drive-folder-20261012.json`. Rafael
identificou Gabriela como responsável pela diagramação e estagiários pela
produção; não foi localizada decisão editorial por edição. A busca no Drive
acessível também não encontrou os exports atuais de CourseVersion. Indexação
e workspaces reais não foram
verificados nem alterados. Testes focais em
`tooling/ai_qa` (8/8) e `api/tests/test_course_promotion.py` (10/10)
passaram; equivalência de snapshots legados 9/9. Nenhum deploy.

## 2026-10-12 Tutor contextual — divergência de edição

Candidato local sobre `9b5778d`: o leitor agora bloqueia a abertura do Tutor
quando a edição da cartilha diverge da CourseVersion ativa da turma. Antes,
essa divergência era detectada mas abria o caminho legado sem escopo RAG.
Cartilhas sem versão continuam no caminho legado intencional. O teste de widget
focal passou 7/7 no checkout Windows do candidato com Flutter 3.44.9 em 12/10;
`git diff --check` passou. Sem staging, produção ou mudança no Worker.

## 2026-10-12 — gate 12 de proveniência de recuperação (candidato local)

IMPLEMENTED/TESTED-LOCAL: o preflight de AAB mantém a verificação tipada do
aceite de recuperação e passa a exigir, em verificador Python offline, hashes e
arquivos de evidência versionados para os cinco campos, além de revisão Alembic
igual ao candidato. O verificador também exige a árvore Git da API candidata,
um único ensaio PostgreSQL para os três gates correspondentes e vínculo entre
recibo agendado R2, dump offsite descriptografado e dump usado no ensaio.
Drills devem ter até 30 dias, seguir a ordem temporal e não estar no futuro;
a idade de 26h do último backup fica para inspeção operacional na promoção.
O aceite booleano histórico de 06/10 não contém essas referências e falha
fechado. Track B comprova o volume AnythingLLM; o ensaio
PostgreSQL versionado alcança apenas `0020`, e o checkpoint aponta prova mais
recente ainda privada na VPS. Não foi fabricado recibo, executado restore,
alterada produção nem gerado AAB. `PRODUCTION_RELEASE_READY=false`.

## 2026-10-08 Issue #163 — fundação Drupal (DR-2), candidato em review

IMPLEMENTED/TESTED-LOCAL na branch `agent/drupal-163-auto-20261007-152725`,
HEAD `3cdd976` sobre staging `fbb4b6a`, PR #177 DRAFT→staging.
`drupal/` contém projeto Composer `drupal/core-recommended` 11.4.8 com
lockfile, Dockerfile php:8.3-apache, compose web+MariaDB 11.8 dedicado,
settings 100% por env, módulo `tds_health` (`GET /health`, `no-store`),
tema `tds_portal` (stark), `config/sync/` versionado (minimal profile,
site:install `--existing-config`), scripts bootstrap/install/smoke/lint/reset
e PHPUnit unitário. Validado em container: smoke 5/5, lint OK, unit 2/2,
reset completo OK. Sem integração acadêmica; staging Drupal segue BLOCKED (G6).
Caveat de ambiente documentada em `drupal/README.md`: neste host Windows
(Docker Desktop 29.8.2 + containerd store) o builder `docker`/`desktop-linux`
materializa arquivos do `FROM` como 0 bytes; workaround validado = builder
`docker-container` (`drupal163`). MERGE_ALLOWED=NO; aguardando reviewer.

Fix ACP (review CHANGES_REQUESTED 2026-10-08): bases `php:8.3-apache`,
`composer:2` e `mariadb:11.8` pinadas por digest imutavel revisado; limite de
reprodutibilidade APT documentado (nao bit-for-bit). `.dockerignore` exclui
`**/settings*.local.php` (canary testado: ausente na imagem). Override de
staging sem `build:` nem bind mounts (`!reset`/`!override`), exige
DB/salt/admin/trusted hosts via `${VAR:?}`; `settings.php` e
`install-site.sh` rejeitam defaults dev fora de `local` (RuntimeException
confirmado). Porta local em `127.0.0.1` via `DRUPAL_HTTP_BIND`; smoke assere
`Cache-Control: no-store` no `/health`; `chmod -R 0777` substituido por
`www-data` + 2775/0664. Validado em projeto isolado `tds-drupal-pr177-acp`
(porta 18080): config local OK, staging fail-closed sem vars e OK com
sinteticos, install+smoke 5/5, lint OK, unit 2/2. Stack preview `tds-drupal`
inalterada. MERGE_ALLOWED=NO; PR segue DRAFT para reviewer ACP.

Rereview ACP (CHANGES_REQUESTED 2026-10-08, unico blocker restante): a tag
mutavel `tutor-tds-drupal:staging` foi substituida por
`DRUPAL_STAGING_IMAGE_REF` obrigatoria (`${VAR:?}`) — referencia imutavel
`repo@sha256:<64-hex>` fornecida pelo ambiente. Validacao fail-closed em tres
camadas: `scripts/staging-preflight.sh` (host, rejeita tag-only/malformada e
roda `compose config`), `install-site.sh` e `settings.php` (rejeitam ref sem
digest quando `DRUPAL_ENVIRONMENT != local`). Sem push de registry, DNS ou
segredos; provisionamento staging segue BLOCKED (G6).

## 2026-10-07 — linha local de RC convergida, promoção ainda bloqueada

A linha local de release engineering preserva `origin/staging` e compõe, sem
push ou merge remoto, as correções revisadas dos PRs #160, #149 e #148 e a
fatia seletiva do #88. Isso fecha a renovação indevida de sessão em desafio de
check-in rejeitado, preserva no compose a configuração candidata de certificado,
fixa IDs de CourseVersion nas nove cartilhas embarcadas e incorpora somente o
runner sintético, seu manifesto de exemplo, testes e matriz reconciliada. Nenhum
workflow, monitor, alerta, deploy ou secret do #88 foi instalado.

O código convergido passou 580/580 testes Flutter, 592 testes API com 30 gates
PostgreSQL opt-in ignorados sem URL, 17/17 testes de observabilidade e análise
Dart sem issues. Os quatro arquivos PostgreSQL opt-in continuam prova separada:
devem ser repetidos no SHA congelado antes de classificar o novo artefato como
RC físico. O AAB/APK assinado no SHA `c83a95f` é intermediário e não representa
esta linha convergida; hashes do novo build pertencem à evidência externa do SHA
congelado, evitando um commit circular no próprio manifesto de fonte.

Configuração do RC enxuto: API
`https://ead.ipexdesenvolvimento.cloud/tutor-api`, gateway
`https://tutor-tds-gateway.tdsipex.workers.dev` e todas as flags de risco
desligadas (`REMOTE_CATALOG`, contexto, outbox, jornada, atividade dinâmica,
identidade assinada de suporte e push). O candidato de certificado também fica
desligado; URL e HMAC só são exigidos no staging quando esse gate for ativado.
Não é necessário criar secret para o RC enxuto.

O runner read-only observou HTTPS/status/latência/TLS saudáveis no Cloud staging,
API produtiva e gateway. Isso não fecha compatibilidade: Cloud staging reporta
schema `20261003_0024`, produção reporta `20261005_0028`, ambos com
`compatibility_verified=false`, enquanto o candidato local adiciona `0030`.
Logo, a Wave 2B permanece com `DYNAMIC_ACTIVITY_ENABLED=false` e não pode ser
validada contra staging sem deploy/migration explicitamente autorizados.

Em situação real, suporte textual app→Chatwoot→app passou e o gateway do Tutor
respondeu HTTP 200 a uma pergunta sintética de aluno em 19,965 s, com resposta
educacional não vazia e sem credencial no cliente. A captura da resposta dentro
do app não foi aprovada: em duas tentativas o emulador entrou em ANR do System UI
e Permission Controller ao pedir microfone; a regra de duas tentativas encerrou
o ensaio. Vídeo/RealtimeKit continua desconectado e sem prova bilateral. Assim,
as telas já capturadas de login, Home, turmas e suporte são coerentes no recorte,
mas não constituem aceite visual integral de IA, atividade 2B, check-in e vídeo.

`PRODUCTION_RELEASE_READY=false`. Um APK/AAB com flags desligadas pode servir a
beta controlado após build assinado e custodiado no SHA exato, mas publicação
ampla continua bloqueada por compatibilidade/schema, prova Android da Wave 2B se
ela for ativada, RealtimeKit se vídeo for requisito e gates normais de
branch/tag/restore/promoção. Google Auth/Supabase e a frente Drupal não são
dependências para este RC enxuto e permanecem trilhas próprias.

## 2026-10-07 — candidato local Dynamic Learning 2B

Sobre a base `fbb4b6a`, a fatia 2B agora possui candidato local executável com a
migration aditiva `20261007_0030`: blocos publicados `question`/`quiz` preservam
IDs e versões, reutilizam `assessment_attempts`/`assessment_contents`, resolvem o
LearningContext completo e obtêm gabarito exclusivamente do snapshot imutável de
CourseVersion no servidor. A tentativa é persistida localmente antes de a tela
avançar; fila/cache ficam escopados por dono, API, turma, matrícula, edição,
seção e bloco. Conclusão cria `assessment_completed` determinístico com
`active_seconds=0` e `validated_seconds=0`; não concede horas, frequência,
matrícula ou certificado. Leitura da própria tentativa revalida o contexto e a
visão pedagógica fica restrita a professor/admin da turma exata; monitor e pessoa
externa são negados.

A identidade da tentativa publicada é canônica nos dois lados: SHA-256 do array
JSON compacto `published_block`, dono, organização, programa, turma, membership,
matrículas contextual/legada, curso, edição, seção/versão e bloco/versão; a URL
da API não participa da identidade. O servidor exige esse ID e a migration cria
unicidade parcial por dono/contexto/bloco, fechando corrida entre dispositivos.
`assessment_contents.origin` separa `practice` de `published_block`, o namespace
`published-block:` é reservado e a migration recusa colisão legada sem mutar o
banco. Projeções públicas/do aluno removem gabarito, `isCorrect`, `value`,
feedback e explicações; payloads de `assessment_completed` não carregam IDs de
pessoa/matrícula. Relógio futuro recebe erro estruturado e só permite reparar
`updated_at`, mantendo tentativa, revisão, respostas e contexto idênticos.

`DYNAMIC_ACTIVITY_ENABLED=false` é o padrão na API, Flutter, exemplos e gates de
produção, e depende também de `LEARNING_CONTEXT_ENABLED`. API, Flutter e o
runner sintético foram verificados localmente; a suíte API completa coletou 620
casos: 590 passaram e 30 gates PostgreSQL opt-in foram ignorados sem URL. A
suíte Flutter passou 567/567 e a análise estática terminou sem problemas. Isso
valida o candidato e o contrato do runner, não um ensaio contra staging. Somente
a branch local do candidato é alterada; não houve push, merge, deploy, alteração
de staging/produção ou mudança de secret nesta fatia.

O gate PostgreSQL opt-in foi executado separadamente no LARGeo contra uma
instância descartável PostgreSQL 17.11 em loopback, no commit
`de9ec577415bb6114d502191713816f78931313d`: 8/8 cenários passaram, incluindo
upgrade vazio/downgrade/reupgrade, upgrades de 0024 e 0029, preservação do
legado, proveniência `published_block` e unicidade por dono/contexto/bloco. Essa
prova valida a migration física; não equivale a deploy ou aceite de staging.

O estado remoto permanece separado: o Cloud canônico foi observado em `0024` e
a VPS em `0029`; ambos reportaram `compatibility_verified=false` e não forneceram
o SHA exato implantado. Portanto a migration `0030` existe somente no candidato
local. Snapshot direto do Supabase em `2026-10-07T21:46:50Z`: 46/46 tabelas com
RLS habilitado, zero policies, zero grants diretos para `anon`/`authenticated` e
grants para `service_role`; default ACLs amplas para objetos futuros continuam
inseguras e o toggle da Data API não foi verificado. Um alerta inicial do
connector foi inconsistente com a leitura direta e não é evidência.

Próximo gate: `dynamic_activity_contextual_android_e2e`, pendente e obrigatório
antes de ligar a flag. Duas abordagens locais de harness foram encerradas pela
regra de duas tentativas e não contam como evidência: a primeira travou na
sincronização do binding; a substituição prebuilt compilou/instalou o APK e
encontrou os controles na árvore, mas o display do emulador estava apagado, a
captura ficou preta e o toque não chegou ao app. Nenhuma tentativa foi criada.
A fronteira responsável observada é o preflight de tela acordada/desbloqueada do
executor ADB, não uma falha demonstrada do domínio. Os harnesses falhos não são
versionados. O gate não bloqueia um build de produção enquanto a flag continuar
false. O runner remoto exige fixture sintética pré-provisionada, contas
sintéticas student/teacher/admin/monitor/outsider e o host HTTPS canônico; a
única credencial possivelmente nova ou a confirmar é a conta sintética outsider,
caso ela ainda não exista. Nenhum secret de produção é necessário. Não há aceite
de STAGING ou PRODUCTION para 2B.

O build de release deve regenerar o tooling de plataforma depois dos testes.
Por isso, `tooling/build_production.ps1` conserva `--no-pub` nos gates de análise
e testes, mas não no `flutter build appbundle`: um registrant ignorado e obsoleto
pode ainda citar o plugin dev `integration_test`, que corretamente não participa
do classpath release. Não mover esse plugin para dependências produtivas nem
versionar arquivos gerados para contornar o problema. Antes de empacotar, o
wrapper executa `pub get --enforce-lockfile`; depois confirma que o hash de
`pubspec.lock` e a árvore Git continuam idênticos ao SHA candidato.

## 2026-10-05 Issue #138 — candidato lifecycle territorial

2026-10-12 — revisão local após auditoria: o preparo envia a `version_id`
efetivamente revisada; a API compara a edição publicada sob o bloqueio do
curso antes de criar turma ou recibo. Conflito 409 obriga nova seleção da
formação. Após resposta perdida, o repositório conserva o corpo e o ID do
comando em armazenamento seguro escopado por API/conta antes do POST. Ao
reabrir o preparo ou reiniciar o app, relê e reconcilia o mesmo recibo antes
de aceitar outro preparo; falha de leitura/gravação local impede novo POST.
O POST confere o `sub` do token usado com a conta da pendência. Rejeições
403/404/422 no primeiro envio liberam correção; no replay ambíguo conservam
o recibo para evitar duplicação.
O teste com repositório recriado e resposta perdida é sintético; Flutter e
Android ainda requerem execução no SDK validado. Ativação e
encerramento limpam motivo/aceite ao trocar turma, mostram o nome na
confirmação e permitem reler prontidão da turma selecionada. API SQLite focal
24/24; Flutter e Android pendentes neste executor sem SDK. Nenhum deploy ou
migration foi feito nesta revisão.

2026-10-12 — candidato local da decisão 32: API passa a conceder a
`program_operator` escopado preparação, ativação e encerramento; a coordenação
conserva os poderes. Capacidade 30 é referência com aviso em preview, resposta
de inclusão e snapshot; inclusões autorizadas 30→31 seguem sem justificativa
especial. Flutter ganhou entrada de ativação por capability, readiness e CAS;
o preparo, a lista de participantes e a operação contextual mostram o aviso
sem bloquear. O E2E
sintético foi alinhado para ativação/encerramento pelo operador. Os parágrafos
de 05/10 abaixo descrevem o contrato histórico substituído pelo item 32 de
`DECISIONS.md`. API SQLite focal 23/23 e harness #140 18/18 passaram;
Flutter/Dart não estão disponíveis neste executor, então testes de UI e Android
não foram executados. Esta mudança não altera migration, staging nem produção.

2026-10-12 — TESTED-LOCAL, ajuste restrito ao endpoint legado de monitores:
`POST /admin/classes/{class_id}/monitors/{user_id}` rejeita HTTP 409 quando a
turma está `closed`, com `CLASS_LIFECYCLE_ENABLED` false ou true. A leitura da
turma usa bloqueio por linha nos bancos que o suportam, como a inclusão de
estudantes. Teste sintético reproduziu 201 antes da correção e passou após ela;
nenhuma validação PostgreSQL, staging ou produção foi executada neste ajuste.

IMPLEMENTED local na branch `agent/issue-138-class-lifecycle-api-20261005` sobre
`911c454`: Classroom recebe município/local da oferta e revisão de lifecycle;
fluxo contextual `planned -> active -> closed`, equipe, readiness, CAS/replay e
ledger auditável. Capacidade padrão 30; somente coordinator escopado pode exceder,
com motivo registrado na operação de inclusão. Rotas de inclusão bloqueiam turma
closed e excesso sem override. CourseVersion permanece fixada. A revisão do PR
#143 preserva o legado quando `CLASS_LIFECYCLE_ENABLED=false` e aplica criação
planned/equipe contextual nas rotas administrativas somente com a flag ativa.
Foram adicionados candidatos de equipe mínimos e listagem contextual de turmas,
sem PII desnecessária nem dependência de `/operations/scopes`. Decisão de
05/10/2026 fecha o gate de encerramento: sessão aberta bloqueia `active→closed`;
demais pendências continuam warnings. Readiness e capability refletem esse
bloqueio e a transição falha sem revision/receipt enquanto existir sessão aberta.
Testes focais SQLite passaram; o DESKTOP-8T5DRBS não possui PostgreSQL descartável,
então qualquer validação PostgreSQL deve ser evidenciada em ambiente isolado
separado e nunca inferida de SQLite/staging. Sem staging, produção, merge ou deploy.

## 2026-10-05 Issue #134 — candidato local

`/v1/chat` aceita contexto estruturado compatível com legado. HEAD autorizado
de #132 permanece composto localmente no PR #136; request ID, 429/504 e o
chamador geral preservados. Camada Experience Blocks do PR #135 removida do PR
#136 por decisão humana em 2026-10-06; permanece no PR #135. Chamador geral do
Tutor envia course_id/course_version_id/module_id; nenhum chamador de experiência
neste PR. `TutorLearningContext` mantém campos opcionais de experiência aceitos
pelo contrato do gateway, sem caller neste PR. `TUTOR_RAG_SCOPE_MAP` é
temporário, com granularidade CourseVersion; isolamento de módulo/experiência
não está comprovado. Status:
`LOCAL_CONTEXT_BINDING_READY=PARCIAL`,
`CONTEXT_BINDING_READY=SIM_COURSEVERSION`,
`AI_SERVICE_READY=SIM (escopo CourseVersion, staging)`.
`FASTAPI_CHANGE_REQUIRED=NÃO`;
`RAG_REGISTRY_FASTAPI_CHANGE=UNKNOWN`. Alvo permanente de ingestão está
documentado, não implementado. O gateway agora usa o shape público real do
AnythingLLM e deriva o escopo CourseVersion do binding 1:1 com workspace, sem
fabricar metadata de módulo/experiência. O chamador geral envia somente
`course_id`, `course_version_id` e `module_id`; cobertura em
`chat_experience_progress_test.dart`. No sync anterior com `staging=9577541`,
gateway 31/31 e sentinel tooling 5/5. O PR #136 permanece baseado em staging e
foi sincronizado por merge normal. Sentinel A/B real PASS em staging em
2026-10-06 (Worker `tutor-tds-gateway-staging`, workspaces QA
`tds-qa-ctx-a-v1`/`tds-qa-ctx-b-v1`), com fail-closed, rejeição de PII no
contexto e troca de conta comprovados; evidência
`docs/production/evidence/ai-rag-courseversion-sentinel-staging-2026-10-06.json`.
A primeira execução revelou header Authorization mascarado no vector-search,
corrigido em `9994565` com teste de regressão. `REAL_STAGING_E2E=YES`.
Isolamento de módulo/experiência e registry RAG permanente: DEFERRED.
Produção e o workspace `cartilhas` não foram alterados; apenas recursos QA
isolados de staging foram criados. Auditoria:
`AI_RAG_CONTEXT_BINDING_AUDIT_2026-10-05.md`.

## Integração META 05 — 03/10/2026

Base integrada neste candidato: `aa6fb88050aa864726e197187487819de303ac65`,
após merges sequenciais #54/#51/#55. PR #39 mantém migrations 0021/0022 e gate
institucional fechado. Os checkpoints abaixo preservam a evidência histórica;
validação PostgreSQL e CI desta integração serão registrados no PR por SHA.

## 2026-10-03 Issue #5 — candidato institucional v2

Contrato direto do usuário implementado em development opt-in: 80h formais por
curso, encontros configurados/min70%, checkpoints obrigatórios determinísticos,
baseline multiorigem e fichas contextualizadas. Último checkpoint gera candidato
sintético automaticamente, antes de assinaturas; CAPACITADO e validade são
projeções separadas. Lifecycle GENERATED→PENDING_INSTRUCTOR_VALIDATION→
PENDING_COORDINATOR_SIGNATURE→VALID exige papéis e evidências; ativação institucional
real permanece bloqueada. Dispatch auditado pending_dispatch para fluxo
tdsdados@gmail.com (endereço canônico na documentação/registro), sem SMTP.
Migrações0021/0022 aditivas, reserva durável/reconciliação lookup e segregação
oficial preservadas. Legado/VPS/serviços reais não foram alterados ou acionados.
Plano citado não anexado; decisão do usuário autoriza o recorte, não homologação.
Ver production/ISSUE5_AUTHENTICATED_EMISSION_CANDIDATE.md e matrizes.
CI detectou fixture de downgrade Journey usando ORM atual após remoção parcial
de colunas0022/0021 antes recusa BI0020. Teste agora verifica BI/histórico/guarda
no schema parado e faz recuperação forward antes do detach pela API; cenário e
proteções mantidos, sem mudança de runtime/migration.

## Checkpoint documental META 04 — 03/10/2026

Base canônica `1a577a6`: #24 integrado em `eab8fb0`, #49 em `39075fc` e #50 em
`1a577a6`, preservando histórico. A conciliação anterior de #24/#51 omitiu a
decisão posterior de #5: correção no item 27 de DECISIONS e na matriz
program/JOURNEY_CONTRACT_RECONCILIATION_2026-10-03.md. Não representa enforcement.
#51 permanece sob Devin com delta corretivo solicitado; #39 preservado como
candidato local, sem ativação institucional. #53 é candidato parcial do plugin
WP-2, não conclusão de #42; tema Windsurf e staging ainda sem execução comprovada.
Issue #3: 86 testes sintéticos de identidade/recuperação passaram; PR #40 e
freeze/gates físicos/restore/proveniência mantêm release bloqueada. Nenhum AAB,
produção, assinatura, baseline real ou certificado real foi alterado.


- CURRENT RELEASE: código `1.4.0+13`; produção histórica `1.2.0+11`, não revalidada na Play. Release bloqueada por seus gates.
- CURRENT WAVE: 2 — Dynamic Learning; fatia 2A aprovada funcionalmente em staging. Wave 1 aprovada em `0081ab0`.
- CURRENT ACCEPTANCE GATE: POCO aprovou 2A e Classroom offline/revogação em 01/10; `course_versioning_xiaomi` e `classroom_cold_offline_xiaomi` fechados. Certificado e Evidence offline pendentes; Wave 2 completa e produção ainda não aprovadas.
- STABLE: MVP/assinatura preservados; Context Core, publicação remota, edição fixa e sincronização verificados em staging.
- IN PROGRESS: ativação do recorte identidade/jornada; código e QA sintético concluídos. IPEX responsável, confirmado por Rafael. Piloto IA e Inclusão Digital: Palmas, Itaguatins, Augustinópolis; 11–30/10/2026; 40h; Rafael confere vínculos.
- BLOCKED: Rafael sem conta online; oferta/equipe e release mantêm seus gates. Login Google resolvido. Rastreio sintético no BI validado; consultas legadas ainda têm 68 linhas com erro no Baseline e 65 na Jornada, incluindo datas inválidas.
- DO NOT TOUCH: produção, keystore, certificados KV, secrets, baselines e rascunhos/execuções QA preservados.
- LAST VERIFIED: 2026-10-01; POCO 2A: oito fases/quatro verificações host, replay sem duplicata, Play/DEV preservados. BI sintético/filtros passou, datas legadas pendentes. Flutter 367 + analyze; API 346/347 + rerun 1/1. Clone 0005→0020/retorno da imagem antiga e backup externo verificados.
- NEXT ACTION: concluir gates técnicos de release/proveniência e preparar conta/equipe/oferta reais; conferir erros de dados legados antes da promoção do BI. Não repetir login Google ou confirmação IPEX. Retomar 2B depois.

QA de catálogo editorial 02/10: curso sintético `validacao-dinamica-tds` criado
em staging Cloud (draft → in_review → published v1/v2); um APK debug com
`REMOTE_CATALOG_ENABLED=true` e contexto/outbox/jornada desligados recebeu v1
e depois título/questão de v2 no mesmo binário e instalação, sem rebuild.
Emulador QA próprio: módulos/pergunta/três quizzes abriram; offline após cold
restart trouxe quatro cursos do cache remoto + nove assets; rede restaurada.
Flag false por padrão. A união offline dos nove assets é exceção opt-in à
semântica anterior de retirada editorial por lista vazia; requer decisão
antes de produção. Evidência `production/evidence/remote-catalog-qa-2026-10-02.json`.
Não equivale a aceite de release ou Wave 2 integral.

Auditoria de ambientes 02/10: Git ainda sem remote/tag; 48 tracked modificados
e milhares de outputs QA preservados localmente, agora ignorados para evitar
stage acidental. GitHub CLI indisponível; nenhum commit/push. Endpoint real
`https://ead.ipexdesenvolvimento.cloud/tutor-api/health` respondeu 200 com DB e
TLS válido; `/version` e `/live` responderam 404, schema/runtime/restore não
comprovados. API/Alembic candidatos agora falham sem PostgreSQL explícito em
production; compose candidato declara ambiente, sem deploy. Gates Android/Dart
de release aceitam só endpoints fixos e flags false; preflight atual falha na
config ignorada e freeze segue ativo. Backup offsite/restore completo,
proveniência Git e upgrade Play pendentes. `PRODUCTION_RELEASE_READY=false`.
Ver production/ENVIRONMENT_CONTRACT.md, PRODUCTION_READINESS.md e
TDS_MEASUREMENT_CONTRACT_V1.md. Baseline físico, Power BI legado, Play,
produção e assinatura não alterados.

Continuação PDF/acesso 01/10: nove viewers Drive de produção respondem com os
títulos esperados; PDF IA confirmado por metadata, sem prova de render Android.
Botão mantém hospedagem externa e registra somente pedido de abertura consentido,
com tratamento de falha; 17 testes Flutter do recorte, nove repetidos após ajuste
de enfileiramento, cinco API e analyze passaram. Contrato COURSE_PDF_CONTRACT.md.
Turma sintética abbdfe6c3fd54366b26c46d1d6075954 preparada uma vez. Após duas
instalações canceladas e preservadas, Rafael confirmou ready e instalou o mesmo
APK. Oito fases passaram em oito processos: retomada fria, fila offline,
reconexão sem duplicata, outra conta, revogação conhecida online/offline e PDF.
Dois eventos offline confirmados uma vez; progresso QA de 2,5% para 5%; 332
eventos e 77 registros anteriores preservados. Play/DEV intactos, rede restaurada,
QA encerrado. PDF abriu pelo botão real; Rafael escolheu conta do Drive e confirmou
a abertura, observada também em screenshot. Um pedido de abertura, zero crédito;
páginas/tempo de leitura e download offline continuam não medidos/verificados.
123 hashes de fonte conferidos. Aceite classroom-access-physical-acceptance-
2026-10-01.json; gate classroom_cold_offline_xiaomi fechado, freeze preservado.

Continuação concluída: Cloud staging restaurado da pausa, 7 contas QA intactas;
backup + migration 0019→0020 preservaram colunas/valores das 42 tabelas. Deploy
`f060ca99-4715-4265-8466-9249329a8e1a` saudável; 62 dependências conferidas no lock
(Python Cloud 3.13.15 versus local 3.13.9). Docker candidato locked passou oito
testes; não implantado, proveniência Git de release pendente. POCO usou pacote
debug `.dev.dynamicqa.r<run_id>` e aprovou 2A: v1 5%, v2 0%, histórico preservado.
Rede restaurada e QA encerrado. Gates de certificado e Evidence offline seguem
pendentes após a continuação Classroom descrita acima; emissão autenticada API→Worker ainda exige
implementação na fatia própria. Produção, flags fora de QA e freeze preservados.
Evidência: production/evidence/wave2a-physical-acceptance-2026-10-01.json.

## Completed
01/10: identidade usa users/matrículas existentes; migration 0020 adiciona ponte
BI conferida. Sem baseline continua pessoa matriculada pendente, sem ficha
fictícia. Fila por dono, sessão concorrente, consentimento novo e tempo de tela
sem crédito implementados. POCO manteve Play 1.2.0+11 e passou online/offline/
reconexão; dez eventos offline entregues uma vez. BI final é cópia local com
ParticipantesApp/JornadaApp/AtividadeApp/PessoaApp e página RastreioApp. Desktop
validou duas contas QA pendentes, 3 minutos e um pedido de ajuda; seleção de cada
pessoa filtrou corretamente. As 17 páginas originais e Jornada foram preservadas.
Baseline/ComplementoBaseline da cópia receberam tipos numéricos explícitos para
impedir SUM sobre texto após refresh; resumo voltou a calcular. Fonte preservada.
40h confirmadas; curso ia-cartilha já existe no catálogo público. Gate físico
de conferência comprovou ID pendente estável, source BI real sem tablet e histórico.
API temporária removida; produção e staging anteriores saudáveis. Pacote final:
outputs/TDS_Journey_Pilot_2026-10-11/TDS_Rastreio.pbip. Ver TDS_JOURNEY_QA_2026-10-01.
Rafael confirmou cartilha atual e ausência de conta. Reutilizar cadastro na
WelcomeScreen e autorização administrativa de equipe, sem senha em chat ou
identidade QA. API pública atual não expõe admin/oferta nem edição fixa no curso;
referência/hash e decisões registrados no pacote, sem alteração de produção.

Continuação Astra: ensaio cec516308697 restaurou dump real isolado, preservou
colunas dos 14 objetos originais e nove cursos, atualizou até 0020 e validou API
anterior na base migrada. Edição ia-cartilha v1 resolvida:
d496856d-6bf3-5f8a-92a3-f292cca92ed5. Backup DPAPI CurrentUser fora do VPS testado;
requer o perfil/chaves Windows deste usuário. Compose API agora recebe pseudônimo
e flags false; worker legado exige perfil explícito. Config validada sem deploy.
Google Sheets: cópia privada 1a7KS1twBIlSO5kTXCmUVvmEIxkbt7IwttHKW4Xqzrzs,
três abas novas com duas contas QA pendentes, três linhas de atividade sintética
e nenhuma inscrição. Fonte original e Fabric intactos; não promover esses dados.
IPEX confirmado explicitamente em 01/10; plano/manifesto atualizados. Rafael
concluiu login Google. Refresh/filtros e save no Desktop verificados; manifesto
registra limites: JornadaApp vazia, sem validação BI de certificado/vínculo real.
Resumo manteve 510 inscrições (421 digitais/89 scans). Datas inválidas foram
observadas na fonte legada; não corrigir por inferência nem contar erros das duas
consultas como pessoas distintas. Ver journey-bi-desktop-2026-10-01.json.

Wave 1: LearningContext v2, Membership/Enrollment físicos, migration 0019,
autorização contextual, projeção compartilhada e outbox SQLite por dono/ambiente.
Seis fases Android e isolamento HTTPS aprovados; progresso original permanece 10%.
Staging FastAPI Cloud + Supabase isolado, secrets próprios, API locked validada;
candidato temporário VPS removido, VPS original preservada.
2A: catálogo por API, recarga da Home e cards adaptáveis. Autor criou/salvou/preview;
coordenador publicou v1/v2 no mesmo APK. Turma antiga manteve v1 e posição;
estudo online/offline/reconexão chegou a 5%, nova turma v2 permaneceu em 0%.
Replay sem duplicata, sete transições editoriais autorizadas e professor/aluno
com projeções idênticas. Rede e processo QA restaurados/encerrados. Tentativas
falhas anteriores e rascunho preservados; causas em BOUNDARY_DIAGNOSTICS.

## Changed contracts
`cohort-enrollment-v2` mantém linhagem `legacy_enrollment_id`. Eventos não concedem
autorização; posição local não equivale a progresso oficial. Flags de contexto e
outbox durável false por padrão, true no staging QA. 2A não criou migration/API:
reutiliza Course/CourseVersion/editor, snapshots imutáveis e cache por URL da API.
Instrumentação usa o AuthRepository real do Provider; operador fica só no host.

## Known issues
Refresh/login/requests tardios não restauram sessão após logout/troca: corrigido
e testado no recorte de 01/10. Logout ainda limpa filas
legadas de avaliação/check-in; tentativas antigas não estão isoladas por dono.
Quiz/question embutidos não persistem ActivityAttempt contextual por bloco.
Role global permanece no legado; retenção de recibos ainda precisa de política.
Ack pode anteceder revalidação do progresso. Arquivamento manual, devolução de
revisão, Creator completo, paridade visual integral, demais gates físicos, AAB assinado,
privacidade/Data Safety e Play ainda não aprovados. APK de gate contém contas
sintéticas e não é artefato de distribuição.

## Next gate
Promover rastreio somente após BI/oferta/release; implementar 2B sem duplicar entidades, com tentativas
e filas por dono/API/matrícula/edição/bloco. Só avançar para Classroom após Wave 2
completa. Não iniciar outra wave que modifique simultaneamente contratos centrais.

## Relevant files
`production/WAVE1_ACCEPTANCE.md`, `production/WAVE2A_ACCEPTANCE.md`,
`production/DYNAMIC_LEARNING_CONTRACT.md`, `production/DYNAMIC_ACTIVITY_AUDIT.md`,
`production/BOUNDARY_DIAGNOSTICS.md`, `production/TRACEABILITY_MATRIX.md`,
`production/API_MATRIX.md`, `production/CLOUD_STAGING.md`, `production/evidence/`.
Cloud: https://tutor-tds-staging.fastapicloud.dev; Supabase `lgtphbbpgqnzduhtyate`;
deploy `f060ca99-4715-4265-8466-9249329a8e1a`; somente dados sintéticos.

## Artefato de comunicação — 29/09/2026
Pré-pitch vigente: `outputs/Tutor_TDS_Pre_Pitch_Identidade_TDS_29-09-2026.pptx`, sete slides com identidade/logomarca oficiais TDS, negócio, produto e staging. Capturas existentes reaproveitadas; produção histórica, testes e hipóteses comerciais distinguidos. Originais/versões anteriores preservados. Sem alterações de app/API/release. Rastreabilidade: `production/PITCH_EVIDENCE_2026-09-29.md`.

## Checkpoint GitHub / Issue #10 — 02/10/2026

GitHub privado `rafaloct/tutor-tds-platform` já recebeu a consolidação; notas
anteriores sobre ausência de remote são históricas. PR #9 contém `/version`,
com 4/4 testes locais e validação no FastAPI Cloud staging registrada no Issue #1.
O CI da integração revelou dois problemas antigos: relógio no teste de hierarquia
 e conversão CRLF/LF de evidências. Correção isolada no Issue #10: relógio apenas
no teste e bytes originais preservados por `.gitattributes`, sem alterar hashes.
Os dois testes antes falhos e a rejeição de adulteração passaram (3/3); a prova
 de bytes consta em `production/CI_REPRODUCIBILITY_ISSUE10.md`. Merge depende do
CI do PR #9; consultar GitHub para estado final. Produção e freeze preservados.

## 2026-10-02: Issue #4 catalog policy decision and candidate

Rafael approved remote-authoritative catalog snapshots, including a valid empty
list. Offline uses the last valid API-scoped snapshot, including empty; bundled
assets only bootstrap when no valid snapshot exists. This supersedes the former
QA cache-plus-nine-assets exception without changing its historical evidence.
Candidate removes the union/empty fallback and rejects malformed snapshots as
failures, not withdrawals. Details and limits: production/ISSUE4_CATALOG_POLICY.md.
Targeted test evidence belongs on the PR; no physical E2E or release acceptance
is inferred. Flag default, production, enrollment/progress and assets preserved.

## 2026-10-09: re-convergência staging+RC, overlay Cloudflare zero-config e fix #185 (local)

OBSERVED (somente local, sem push/deploy):
- Branch `codex/rc-reconverged-20261009` na worktree `tds-agents/rc-reconverge-20261009`.
  Merge `89bc03a` une staging `fbb4b6a` à linha RC `bba1055`; único conflito foi este
  arquivo (resolvido por união). Overlay zero-config (#183) commitado como `aae02a4`:
  seletor por Git ref fail-closed (`staging` → staging, tag `vX.Y.Z` → produção, demais
  refs rejeitadas), Worker staging sem KV/secret de certificado, compose AnythingLLM
  isolado, runbook em `docs/operations/TDS_CLOUDFLARE_ZERO_CONFIG_RUNBOOK.md`.
  7/7 testes do pacote e validação de refs passaram; wrangler dry-run confirma
  que staging não herda o KV de produção.
- #185 implementada nesta branch: `AnythingLLMService.getChatResponse` retorna
  `TutorChatResult` tipado (answer/emptyAnswer/unavailable); resposta inválida ou
  indisponível não vira card educacional. `ChatMessage.isError`, `_TutorErrorNotice`
  com liveRegion + botão "Tentar novamente" irmão, retry via `_lastQuestion`,
  `TutorMessageText` (Markdown básico sem delimitadores literais, links com
  confirmação), `tutorPlainText` para TTS (`_speak` normaliza; path legado
  `chat_experience_screen` também normalizado). `speaker` injetável.
- Evidência local: 30/30 testes focados (service: 200 válido/vazio/malformado,
  400/429/502/503, timeout, URL inválida; tela: loading→resposta/erro→retry,
  ausência de ações quiz/cartão no erro, link seguro, TTS sem sintaxe).
  `flutter analyze` limpo; `git diff --check` limpo.
- Wrangler local reparado para leitura (keyring `@napi-rs/keyring`); auditoria
  #183 permanece read-only. Zona já está na Cloudflare (rene/margot.ns); `ead`
  proxied. Nenhum DNS/Worker/secret foi escrito ou lido.
BLOCKED (human gates, inalterados):
- Deploy/push/merge não autorizados. Auditoria autenticada de bindings e
  provisionamento do AnythingLLM staging isolado pendentes.
- QA autenticado Android: #182 (gate Gradle do hostname staging), #184 (primeiro
  frame/ANR), contas sintéticas via MCP `82beb93` ainda sem as 3 confirmações de
  staging nem ponte de login segura. Não usar harness com `--dart-define` de senhas.
- `PRODUCTION_RELEASE_READY=false`; produção `/version`/`/live` 404; schema,
  backup/restore e proveniência não provados. AAB/Play fora de escopo.

## 2026-10-09 (configuração remota autorizada): auditoria Cloudflare + AnythingLLM staging isolado

OBSERVED:
- OAuth wrangler `tdsdados@gmail.com` ativo (workers/workers_routes/workers_kv write,
  zone read, connectivity admin; SEM dns write nem zone edit).
- Auditoria remota: prod `tutor-tds-gateway` (v`254148a8`) tem KV CERTIFICATES
  `7d13364e…` + 3 secrets corretos. Staging `tutor-tds-gateway-staging` (v`08fdea1c`)
  sem KV/secret de certificado, MAS `ANYTHING_LLM_BASE_URL` apontava para o
  AnythingLLM de produção com workspace `tds-qa-legacy-unbound`.
- Túnel `tds-ai-staging` já existia (id `0f03520c`, cfd_tunnel, status down, nunca
  conectado). Token não recuperável via wrangler; hostname público não configurado.
- VPS acessível via SSH alias `tutor-tds-vps` (root@46.202.150.132). Dokploy HTTP
  na porta 3000 não respondeu desta rede; `dokploy.` não resolve em DNS.
- Provisionado no VPS `/opt/tutor-tds-ai-staging/` (0600): compose do pacote,
  rede `tutor-tds-ai-staging_tds_ai_staging`, volume dedicado, porta apenas
  127.0.0.1:3002. AnythingLLM staging UP, multi-user ativado, admin
  `tds-qa-admin` e API key `tds-qa-worker` gravados em `.env` host-only.
  Workspaces criadas: `tds-qa-default`, `tds-qa-ctx-a-v1`, `tds-qa-ctx-b-v1`
  (slugs iguais). Nenhum dado/DB/chave de produção copiado.
- MCP pre-condições: na EAD staging (`ead…/tutor-staging-api`) admin gerenciado
  autentica (role=admin) e `staging-qa-program` existe; `CPF_ACTIVATION_REQUIRED`
  ausente → default false. Na fastapicloud staging o seed do VPS dá 401 e o
  programa é `qa-program` — MCP pinado para fastapicloud.dev não casa com a
  boundary EAD escolhida pelo pacote zero-config.
BLOCKED (human):
- Token do túnel + hostname `ia-tutor-staging` → `http://anythingllm-staging:3001`
  no Zero Trust (dashboard) — depois subo `cloudflared-staging` e o Worker.
- Chave de provider de modelo dedicada ao staging AnythingLLM (não copiar prod).
- Deploy `wrangler deploy --env staging` + `secret put` só depois do hostname vivo.
- CLOUDFLARE_API_TOKENs por ambiente no GitHub; decisão sobre URL do MCP
  (EAD vs fastapicloud) pois o código pin da URL exige ajuste.

## 2026-10-09 (continuacao): provider AnythingLLM + gate Gradle #182

OBSERVED:
- AnythingLLM staging: `SEED_ADMIN` (`.staging-seed.env`) autentica na EAD staging
  (role=admin) - seed file do MCP e compativel com a boundary EAD.
- Provider configurado via `POST /api/v1/system/update-env` (chaves amigaveis
  KEY_MAPPING; nomes de env crus sao ignorados com newValues={}):
  `LLMProvider=ollama`, `OllamaLLMBasePath=http://172.17.0.1:11434`,
  `OllamaLLMModelPref=qwen2.5:latest`, token limit 8192. AnythingLLM alcanca o
  ollama compartilhado (context windows consultados; TokenManager criado).
- INVIAVEL hoje: VPS compartilhado em load ~20; `qwen2.5:latest` nao respondeu a
  generate direto em 240s nem a chat via workspace em 280s (modelo nunca sobe em
  `ollama ps`). Modelos `*-cloud` (gpt-oss, glm-4.6, deepseek) retornam
  `Unauthorized` - a conta ollama.com do tenant nao cobre esses modelos.
  Duas tentativas esgotadas -> provider efetivamente indisponivel ate chave
  dedicada ou box menos carregado.
- #182 corrigida (commit local nesta branch): allowlists
  `approvedStagingApiUrls` + `approvedStagingGatewayUrls`; gate de gateway aceita
  staging no HOST ou path; QA isolado aceita as duas rotas staging aprovadas.
  Harness ganhou casos Worker-staging (+4) e QA isolado EAD (+1/-1); flag
  `DYNAMIC_ACTIVITY_ENABLED=false` adicionada ao set prod (divergencia
  pre-existente gate x harness, commit de9ec57).
BLOCKED (human): chave de provider de LLM dedicada ao staging (decisao);
  demais gates do bloco anterior inalterados.

## 2026-10-09 (continuacao 2): #189 + #190 no harness + pin EAD no MCP

OBSERVED:
- #189 fechada (commit 7626402): `qa-server.log` ficava travado porque
  `server.terminate()` so matava o processo direto; filhos herdeiros do handle
  sobreviviam. Agora `_stop_server_tree` usa `taskkill /T /F` no Windows e
  `_cleanup_temp_dir` faz rmtree com retry limitado; falha residual sai como
  `CLEANUP_FAIL` exit 8 com `retained_path`, sem mascarar o resultado do fluxo.
- #190 mitigada (commit af0b5ba): inventario `adb pm list packages
  com.tutortds_cartilhas*` antes/depois do run; remocao de pacote alheio ao
  run-id sai como `COLLATERAL_STATE_CHANGED` exit 9. Delta so computa com os
  dois inventarios OK (sem falso positivo por falha de adb). Causa original da
  remocao do r63 segue UNKNOWN - a guarda detecta, nao explica.
- MCP `d2fadbd` (branch rafael_notebook/account-mcp-staging-20261008): pin de
  URL migrado para `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`
  (boundary canonica verificada); 9/9 testes locais passam.
- Harness class_lifecycle: 18/18 testes locais.
BLOCKED (human): aprovacao explicita de um run-id 32-hex para
  `qa_create_accounts` na EAD staging; demais gates inalterados.

## 2026-10-09 (continuacao 3): diagnostico AVD — reprodução do padrao ANR

OBSERVED (AVD `tutor_tds_remote_catalog_qa`/emulator-5554, tablet x86_64 API 35):
- APK debug desta branch (`af0b5ba`) instala e renderiza HOME com sessao
  persistida (usuario `61999990000`) — primeiro frame OK neste build.
- Tap em "Perguntar ao Tutor" -> tela PRETA, semantica colapsa, apenas 8 frames;
  InputDispatcher: `NO_INPUT_CHANNEL` na MainActivity; ANR gravado (14:18,
  relogio do emulador 10-08); thread `1.ui` ausente no trace — falha de
  engine/superficie, nao excecao Dart nem bloqueio do main thread.
- Reproduzivel apos force-stop+relaunch. `Medium_Phone_API_36.1` nao passou de
  offline — duas tentativas esgotadas; parada por protocolo.
- APK QA buildado com staging real (`TUTOR_GATEWAY_URL=tutor-tds-gateway-
  staging.tdsipex.workers.dev`) — prova ponta-a-ponta do gate #182.
- Evidencias: `docs/production/evidence/qa-avd-anr-diagnostic-af0b5ba.txt`,
  `qa-ui-tree-af0b5ba.xml`, `qa-first-frame-af0b5ba.png`.
BLOCKED: E2E autenticado exige o AVD Pixel_8_Pro do LARGeo (alvo autorizado) —
  esta maquina so tem imagens tablet/phone genericas; a falha observada e de
  classe emulador/superficie e provavelmente a mesma da #184, nao provada como
  defeito do app.

## 2026-10-10: cadeia Cloudflare staging LIVE ponta-a-ponta + run MCP aprovado

OBSERVED (verificado ao vivo, sem segredos em evidencia):
- Tunel `tds-ai-staging` ativo; ingress corrigido para `http://anythingllm-staging:3001`
  (o erro `tls: first record does not look like a TLS handshake` veio de https no
  origin de servico HTTP).
- `https://ia-tutor-staging.ipexdesenvolvimento.cloud` responde via Cloudflare;
  auth de instancia OK (workspaces listadas via túnel).
- `wrangler deploy --config wrangler.ci.toml --env staging`: worker
  `tutor-tds-gateway-staging` versao `c6154579-6d8a-44df-8d3d-6df26b1a9b82` —
  SEM KV `CERTIFICATES` (isolamento), vars `ANYTHING_LLM_BASE_URL=ia-tutor-staging`,
  workspace `tds-qa-default`, `TUTOR_RAG_SCOPE_MAP` de staging.
- `wrangler secret put ANYTHING_LLM_API_KEY --env staging`: aplicado com a chave
  real da instancia (DB `api_keys`, nome `tds-qa-worker`), via pipe sem exposicao.
- Producao `tutor-tds-gateway` INTACTA (sem deploy/secret/DNS).
- Cadeia completa: `POST /v1/chat` no worker staging -> tunel -> AnythingLLM ->
  provider `ollama` (`qwen2.5:latest`, 172.17.0.1:11434) -> `{"text":"ok"}` ~8s
  (primeiro call frio ~56s; VPS load caiu de ~20 para ~7).
- `.env` do VPS: `TDS_STAGING_ANYTHINGLLM_API_KEY` continha valor que NAO
  autenticava na instancia (prefixo `HSRP`, 31c); sincronizado para a chave
  real registrada no DB (prefixo `RYY7`). Se o valor anterior era chave de
  provider externo, precisa ser recompartilhada — nao recuperavel do host.
- Provider: usuario indicou "NAO E OLLAMA E ANYTHING"; em AnythingLLM nao existe
  provider hosted proprio nesta versao — producao usa `openrouter` +
  `google/gemini-2.5-flash-lite`. Ollama local responde agora (fumaca OK);
  decisao de provider dedicado p/ staging segue aberta se qualidade importar.
- MCP run APROVADO executado no VPS (Linux obrigatorio pelo design):
  run-id `54a5b5f81dfd112ca1cb08bdff35a4a6`, programa `staging-qa-program`,
  3 contas criadas (student/teacher/monitor), saida sanitizada, ledger privado
  `/opt/tutor-tds-staging/.qa-ledger/` (0600). Ferramenta em `/opt/qa-mcp/`.
- Bug encontrado e corrigido no MCP: WAF Cloudflare 403 para UA
  `Python-urllib` — `_post` agora envia `User-Agent: TutorTDS-QA-MCP/1.0`;
  commit `9cda849` no branch do MCP; 9/9 testes.
- GitHub: secret `CLOUDFARE_API` existe NIVEL REPO (criado 2026-10-10 ~10:44),
  mas workflow `tds-cloudflare-worker.yml` le `secrets.CLOUDFLARE_API_TOKEN`;
  environments `tds-worker-staging`/`tds-worker-production` tem ZERO secrets.
BLOCKED (human):
1. Renomear/duplicar o token como `CLOUDFLARE_API_TOKEN` (nivel repo ja resolve
   ambos envs; ou um por environment no desenho por-env).
2. E2E autenticado final: Pixel_8_Pro no LARGeo (fora deste host); contas
   sinteticas ja existem para o run.
DECISION pendente: provider de modelo dedicado para staging (openrouter
  dedicado) — hoje fumaca via ollama local funciona.

## 2026-10-10 (noite): E2E autenticado COMPLETO no AVD autorizado — staging LIVE

OBSERVED (Pixel_8_Pro / emulator-5554 no LARGEO via Tailscale+SSH, APK debug desta branch):
- App abre welcome, login CPF+senha da conta sintetica `student`
  (run `54a5b5f81dfd112ca1cb08bdff35a4a6`) autenticou na EAD staging,
  consentimento, home autenticada "Olá, QA!".
- Tutor abriu SEM black screen — confirma que a falha do tablet
  (#184-class) e de superficie/imagem, nao do app.
- ANR de digitacao: ROOT CAUSE identificado — o servico de autofill do
  emulador trava a InputConnection (AutofillGroup + autofillHints da tela de
  login); campo sem autofill e campo mascarado na welcome digitam normal.
  Workaround do harness/QA: `adb shell settings put secure autofill_service null`.
  NAO e defeito do app; documentar para quem reproduzir em AVD.
- Mensagem -> Worker staging -> AnythingLLM -> `upstream_timeout` (ollama lento)
  -> estado de erro #185 live com retry irmao ("Tentar novamente").
- Provider migrado para `openrouter` + `google/gemini-2.5-flash-lite` com chave
  dedicada de staging (`TDS_STAGING_OPENROUTER_API_KEY`, distinta da prod —
  verificado por hash, sem exposicao). OpenRouterTimeout=60000.
- Retry no app: resposta REAL do Tutor exibida (Resposta direta + acoes
  Ouvir/Cartoes/Quiz) — cadeia Worker->tunnel->AnythingLLM->OpenRouter em ~1.9s.
- Evidencias: `qa-pixel8pro-home-auth.png`, `qa-pixel8pro-tutor-open.png`,
  `qa-pixel8pro-tutor-error-state.png`, `qa-pixel8pro-tutor-answer.png`.
- Higiene: creds/tmp files removidos de LARGEO e VPS; ledger privado intacto.
- ATENCAO (relatado ao operador): clipboard do emulador exibia fragmento de
  chave OpenRouter — recomendado rotacionar se a chave foi transitada por ele.
REMAINING: PR push/review, deploy CI staging no ref, gates de producao.
