# CURRENT STATE

## 2026-10-31 — Solicitação de certificado em curso bundled (edição legada)

OBSERVED (defeito): em produção `REMOTE_CATALOG_ENABLED=false` → cursos
vêm dos assets bundled com `course_version_id: null` →
`CertificateRequestsScreen` só chamava `/certificate-requests/contexts`
com versão não-nula → aluno nunca via matrícula selecionável nem
conseguia criar o pedido. Caminho de turma/catálogo remoto não era
afetado (versão vem serializada).
IMPLEMENTED: `GET /certificate-requests/contexts` aceita
`course_version_id` ausente — contexto sem turma resolve a edição legada
determinística `legacy_version_id(course_id)` (para onde eventos sem
versão contam, conforme `_eligibility`); contexto de turma resolve a
edição fixada na `Classroom`. App envia o parâmetro só quando conhecido
(`contexts()` aceita versão nula; tela consulta contextos sempre que
`courseId` existe). `POST /certificate-requests` segue exigindo o ID
resolvido pelo servidor — cliente não inventa edição nem autorização.
TESTED-LOCAL: `api/tests/test_certificate_requests.py` 21 verdes
(novo teste cobre resolução legada + pin de turma `v2`);
`certificate_request_repository_test` + `certificate_requests_screen_test`
+ `certificate_screens_test` 40 verdes (novo teste de tela: bundled sem
versão consulta contextos). Analyzer limpo.
BLOCKED: validação em staging depende do container `staging-api`
crash-loopando por migration ausente `20261030_0033` (problema de
ambiente, fora deste recorte). Sem claims de staging/produção.

## 2026-10-31 — E2E web headless automatizado (alternativa ao Android)

OBSERVED (host Linux): suíte `integration_test/app_test.dart` roda no
navegador sem emulador via `tooling/test_web_e2e.sh` — sobe chromedriver,
`flutter drive -d web-server` e Chrome headless, e derruba tudo ao sair.
Infra provisionada: Chrome for Testing 156.0.8078.80 + chromedriver casado
em `/opt/cft/` (Chromium do snap não serve — /tmp isolado quebra o
DevToolsActivePort), wrappers `/usr/local/bin/chromedriver` e
`chromium-nosandbox`. Resultado: **18/18 testes web-compatíveis** com
`config/staging.qa.json` (API staging saudável em /health) —
`app_test.dart` 17/17 + `genui_test.dart` 1/1 (faltava
`IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, drive travava
sem resposta). Configuração via env: `TEST`, `CONFIG`, `WEB_PORT`
(default 8484), `HEADLESS`. Dos demais arquivos em `integration_test/`,
seis têm guarda explícita `expect(Platform.isAndroid, isTrue)`
(classroom_access, context_learning, dynamic_learning, journey_baseline,
journey_traceability, prebuilt_apk_smoke) e `outbox_persistence_test`
exige sqflite nativo (sem factory web registrada). Cinco expectativas
desatualizadas foram corrigidas no `app_test.dart` (não no app): rótulo
do submit é 'Continuar neste dispositivo' quando `TUTOR_API_URL` está
configurada; CPF passa por checksum real (`isValidCpf`); ícone volume_up
migrou para `TutorResponseCard` e só aparece em respostas do bot
(saudação não exibe; "Perguntar à IA" não auto-envia mensagem).
UNKNOWN/BLOCKED: cobertura limitada ao que o integration_test web exercita
— offline nativo (sqflite), push, PDF/Drive e TTS/mic continuam exigindo
Android físico; falhas seriam as mesmas no Android (teste estava velho,
não era bug do web).

**CORS diagnosticado e resolvido na origem**: `tutor-staging-api` só
aceitava `cartilhas.ipexdesenvolvimento.cloud` em `ALLOWED_ORIGINS` →
browser bloqueava register/login antes de enviar ("não reconhece a
senha" era erro de rede; cadastro nunca existia no backend). Android não
tem CORS. Fix aplicado no staging local (`/opt/tutor-tds-staging`,
compose, não-Dokploy): `STAGING_ALLOWED_ORIGINS` agora inclui
`http://46.202.150.132:9090`, `localhost|127.0.0.1` nas portas
9090/8484/8080 e o preview `127.0.0.1:34203` — backup em
`.env.bak-cors-webqa-20261031`, `api-staging` recriado, preflight 200
nas novas origens, `/media` 200. Mudança aditiva e reversível.

App web em `http://46.202.150.132:9090` (nginx Docker `cartilhas-web-qa`
+ `tooling/web_proxy.nginx.conf` com proxy `/tutor-staging-api/`→ead,
mantido como redundância). Rebuild com `staging.qa.json` absoluta —
`MediaRepository._apiBase()` exige https absoluto, URL relativa quebrava
a tela Vídeos (cache vazio). LocalStorage é por origem: usar sempre :9090.

Conta QA dedicada criada no staging: **CPF `900.777.123-07`, senha
`qa-web-senha-2026!`** (student). Novo `integration_test/
account_qa_test.dart` **3/3**: [A1] registro atinge API (201 ou 409
"Já existe uma conta"), [A2] login com conta existente chega na Home,
[A3] senha errada → "CPF ou senha inválidos." — prova persistência
servidor real. CPFs clássicos (529.982.247-25, 111.444.777-35) já
existem no staging com senha desconhecida — usar a conta QA acima ou
CPF inédito.

## 2026-10-31 — fatia self-enrollment: contrato + implementação flag-off

OBSERVED (checkout `/root/tutor-tds-platform-1`): candidato de matrícula
espontânea implementado atrás de flags desligadas, cobrindo API + WP legado +
Flutter, com testes locais do recorte. API: migração aditiva
`20261031_0025` (`classes.enrollment_policy`, índice único parcial de uma
turma aberta não encerrada por curso, tabela `external_sync_requests`);
`POST /courses/{course_id}/self-enroll` cria membership→enrollment→
class_enrollment→bind_student(contexto v2)+OperatorCommandReceipt na mesma
transação e provisiona a turma aberta de forma determinística e idempotente;
`GET /open-classes` lista turmas abertas com `viewer_enrolled`. Worker
`learnpress_sync` (claim/lease/backoff) projeta no legado via
`user-by-phone`→`register`→`enroll` sem bloquear a matrícula canônica. WP:
`POST /tds/v1/register` adicionado ao `RestController.php` (X-API-Key,
idempotente por telefone, subscriber) — código no monorepo, **não
implantado**. Flutter: flag `SELF_ENROLLMENT_ENABLED` (dart-define, default
false), `SelfEnrollmentRepository` online-only, seção "Cursos abertos" em
`LearnerClassroomsScreen` e primeiro toque na Home que matricula e abre a
edição fixada; sem sessão oferece login e preserva acesso público; falha de
matrícula nunca bloqueia o catálogo. Evidência local: `test_self_enrollment`
11/11 + regressão do recorte 48/48 (SQLite, env travado), Flutter
`self_enrollment_test` 8/8 + suíte relacionada 59/59, `dart analyze` limpo
nos arquivos alterados. Pins de head de migration nos testes Postgres
atualizados para `20261031_0025`. UNKNOWN/BLOCKED: sem prova de staging,
produção ou integração WP real; reconciliação com a sessão irmã que trabalha
a raiz identidade-matrícula pendente (possível colisão de head de migração);
gates de ativação no contrato. Contrato:
`production/SELF_ENROLLMENT_CONTRACT.md`; decisão: item 29 de DECISIONS.
RECONCILE (đã xử): `/register` đã được merge lên bản `RestController.php`
prod-synced — 3 commit EAD của session filh (`bf1b24e`, `fd990fa`,
`ae6686f`) merge vào branch này qua ort không-conflict; file hiện có đủ
`/register` + `user-by-phone` PII-minimized + progress SQL + "Comprar
agora" + guard 403 mp-callback, `php -l` sạch.

## 2026-10-31 — sessão filha (EAD/WordPress): 3 commits locais em checkout separado

OBSERVED (checkout `/root/tutor-tds-platform`, branch
`codex/onda-0-consolidacao`, commits `bf1b24e`, `fd990fa`, `ae6686f` —
locais, **não empurrados**): sessão paralela sincronizou
`wordpress/legacy-runtime/tds-lms-core` **da produção EAD para o repo**
(produção era fonte viva; 5 arquivos divergiam por edição direta no
servidor). Mudanças já aplicadas ao vivo: guarda de rota
`mp-subscription-callback` (POST sem key → 403 verificado ao vivo),
minimização de PII em `/user-by-phone` (resposta padrão só
`found`+`user_id`; contato exige `?internal=1`; acesso logado) e rótulo
"Comprar agora" no botão externo LearnPress de cursos pagos. Auditoria
read-only das rotas `tds/v1` + frente comercial em
`docs/audit-2026-10-31-ead-apis-commercial.md` — mapa EAD com 12 cursos
(9 cartilhas + 2 IA + PRISMA comercial), coexistência de duas
implementações LMS (`tds-portal-core` repo × `tds-lms-core` EAD) e
mu-plugins não versionados como riscos declarados. Recorte disjunto de
Flutter/API: nenhum arquivo de `cartilhas_app/` ou `api/` tocado;
sintaxe `php -l` limpa nos 5 arquivos. UNKNOWN/BLOCKED: P0 pendente —
rotacionar `TDS_API_KEY` (hardcoded no loader mu-plugin de produção),
restringir escopo de `/user-by-phone`/`/progress`, versionar mu-plugins
EAD; push dos 3 commits aguarda credencial. Nota: diretriz SESSÃO-02 em
`/root/tds-diretrizes/` descreve auditoria de hook pós-commit → deploy
Dokploy (commit `c7c40f0`, branch `claude/brainstorm-debug-jfxk1`) —
relatório não localizado neste host; escopo de outra sessão.

## 2026-10-31 — suíte Flutter revalidada no Linux: 476/476 + analyze limpo

OBSERVED (host Linux, Flutter 3.44.9/Dart 3.12.2 — mesma versão pinada no CI e
no SDK histórico do desktop): `flutter pub get`, `flutter analyze` (0 issues) e
`flutter test` completos em `agent/web-1.4.0-c07` — **476/476 testes**. Sete
falhas iniciais corrigidas: 4 eram de ambiente (`dart` fora do PATH nos testes
`validate_production_config`); `media_catalog_screen` 200% rolava o Scrollable
errado (`.last` passou a resolver o TextField de busca de 7d600d5 — agora
`.first`); `secure_media_embed_test` e `learning_event_sync_service_test`
estavam desatualizados frente ao commit e72a557 (remoção deliberada do host
youtube-nocookie por quebra de postMessage em srcdoc; descarte de 422/404/409
da fila legada não-durável contra head-of-line blocking). Teste 5xx adicionado
preservando a garantia de parada do lote em falha transitória. `dart:html`
deprecado migrado para `package:web` + `dart:js_interop` em
`media_embed_view_web.dart` (`web` promovida a dep direta, lock 1.1.1
inalterado). `release_status.json` `source_verification` atualizado para
476/476 de hoje; `release_build_allowed` permanece **false** — os 2 gates
físicos (certificate_human_approval_e2e, evidence_offline_xiaomi) seguem
pendentes de execução no Xiaomi + host com ADB, roteiros em
`docs/production/RELEASE_EVIDENCE_RUNBOOKS_2026-10-31.md`. UNKNOWN/BLOCKED:
desktop Windows não alcançável por SSH a partir deste host (timeout); execução
dos gates físicos e geração do AAB continuam ação humana no desktop.

## 2026-10-31 — F3 operação de atendimento Chatwoot (funil CadÚnico)

Configuração observada em produção (`kreativ-chatwoot`, account "TDS Tocantins"),
aplicada via Rails console e reversível. OBSERVED: team `tds | bolsistas de
graduação` recebeu os 10 agentes não-admin; inbox `WhatsApp TDS` (id 1, ligada ao
Evolution `evolution.ipexdesenvolvimento.cloud`) passou de 3 para 12 membros;
inbox `Tutor TDS — Site` (id 7) saiu de 0 para 10 membros. Teams `coordenação
geral` e `coordenação técnica e supervisão` receberam `coordenacao@` e `rafael@`
como alvos de escalonamento (antes vazias — regras antigas caíam no vazio).
11 labels do funil criadas (42 total): `faq-resolvido`, `duvida-pedagogica`,
`duvida-tecnica-rural`, `embrapa-encaminhamento`, `suporte-app`,
`matricula-coordenacao`, `certificacao-coordenacao`, `retorno-pendente`,
`elegibilidade-cadunico`, `interesse-curso`, `lead-acesso-liberado`. Team
`bot-rag` criada vazia (aguarda F4/AnythingLLM+n8n). Automação id 10 ativa:
mensagem WhatsApp (inbox 1) contendo "quero" → label `interesse-curso` +
atribuição a `bolsistas`. Widget do app já aponta para inbox `TDS | Atendimento
UFT/IPEX` (13), monitorada por todos os agentes. UNKNOWN/BLOCKED: inbox WhatsApp
id 19 órfã (sem membros/webhook) — confirmar antes de remover; teams
`coordenação local`, `logística`, `apoio técnico`, `pesquisa e extensão`,
`mobilização local`, `apoio digital` vazias — regras antigas que atribuem a
elas ainda caem no vazio até o usuário indicar responsáveis; canned responses
bloqueadas na revisão pedagógica dos FAQs (`docs/operations/faq-rag/`,
status NÃO PUBLICAR). Chatwoot nunca concede matrícula/frequência/certificado —
estagiários fazem triagem e encaminham à coordenação. Proposta:
`docs/operations/funil-cadunico-chatwoot-rag.md`. Teste da automação
comprovado: conversa QA sintética na inbox 1 com "quero agricultura" recebeu
label `interesse-curso` e team `bolsistas de graduação` (contato/conversa
removidos após o teste).

## 2026-10-31 — camada SEO pública do portal de cursos

OBSERVED: `/cursos/` + 9 páginas estáticas `/cursos/<slug>/` publicadas em
produção (200 OK), com OG/Twitter meta, canonical, JSON-LD `Course` +
`ItemList` (oferta price=0 BRL, categoria CadÚnico), CTA "Quero participar"
via `wa.me/556393010823?text=quero%20<slug>` (mesmo número da instância
`whatsapp_chatwoot` ligada à inbox 1 — a automação id 10 roteia para
`bolsistas`), links para app web `/` e download `/app/`. `robots.txt` e
`sitemap.xml` criados. `index.html` do shell Flutter ganhou meta OG/Twitter,
canonical e JSON-LD `WebSite` — aplicado no deploy e no fonte
(`cartilhas_app/web/index.html`, commit `e2ee6db`). O app web 1.4.0+13 já
carrega todas as funcionalidades (catálogo, vídeo, progresso, avaliação,
suporte); as páginas estáticas são a camada indexável de descoberta.
UNKNOWN/BLOCKED: publicação na Play Store exige keystore + conta Play
Console — não disponível neste ambiente; permanece ação humana. Sitemap não
submetido ao Google Search Console — requer acesso à conta.

## 2026-10-31 — Play Store: keystore localizada e pipeline pronto; release congelado por gate próprio

OBSERVED (desktop `DESKTOP-8T5DRBS`): keystore real localizado em
`Downloads\Cartilhas (Versão Chatbot)\...\cartilhas_app\android\` —
`upload-keystore.jks` + `key.properties` funcional, cert SHA256
`16:44:39:F5…` idêntico ao `upload_certificate.pem` do repo (mesma chave
registrada no Play App Signing). Build pipeline verificado até o gate:
worktree em `tds-release-14013-build`, patch da release aplicado, pub get +
Gradle OK. BLOCKED: `build appbundle --release` falha no gate intencional do
projeto — `release_build_allowed: false` em `release/release_status.json`
com 2 evidências físicas pendentes (`certificate_human_approval_e2e`,
`evidence_offline_xiaomi`). O AAB antigo está `superseded/upload_allowed=false`.
Não contornável — é controle de governança. Roteiros E2E executáveis em
`docs/production/RELEASE_EVIDENCE_RUNBOOKS_2026-10-31.md`; script de build
pronto no desktop (`tds-build-aab.ps1`); senhas copiadas em runtime sem
exposição. Patch de release removido do diretório público após uso.
Search Console: página aberta no Chrome do desktop aguardando verificação
da propriedade (método arquivo HTML disponível).

## 2026-10-30 — republicação web do app em cartilhas.ipexdesenvolvimento.cloud

Domínio real é `cartilhas.ipexdesenvolvimento.cloud` (Cloudflare → Traefik →
container `compose-copy-redundant-alarm-18gsr7-cartilhas-web-1`, bind-mount
`/opt/cartilhas-tds/web`); `cartilhas.eadipexdesenvolvimento.cloud` não existe no
DNS e não recebeu deploy. A versão web Flutter 1.0.0+1 (junho) foi substituída
pela build 1.4.0+13 gerada com `flutter build web --release --base-href /
--dart-define-from-file=config/production.json` (gateway/API produtivos;
flags de risco desligadas conforme contrato). `/app/` (manual/APK) e
`privacy-policy.html` preservados; backup pré-deploy em
`/opt/cartilhas-tds/backups/web-v1.0.0-20261030-203755.tar.gz`. Correção de
identidade do shell PWA (verde → azul #093AF4, splash) e no-store para
entrypoints sem hash commitados em `agent/cartilhas-web-deploy-20261030`
(9adf55f), aguardando merge. Cloudflare servia `main.dart.js`/`flutter_bootstrap.js`
antigos por cache de 1 ano; contornado nesta publicação com nomes versionados
(`flutter_bootstrap-1.4.0.13.js`, `main-1.4.0.13.dart.js`). Três logos de
parceiros (cdr/fapto/ipex) permanecem obsoletos no edge até expiração ou purge
manual na conta Cloudflare — credencial de API não existe na VPS.

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

### Auditoria de integração pós-push (2026-10-31, agent/web-1.4.0-c07 @ b2ec4c9)

**GitHub Actions (observado):**
- `99b438c`: Tutor TDS API CI **success** (test+build 4m32s; `deploy-staging` skipped — exige `refs/heads/staging`, correto).
- `99b438c`: WP legacy quarantine **failure** — manifest stale vs 5 arquivos do sync EAD; rebaseline revisado em `b2ec4c9` → quarantine **success** (56/56, provenance no campo `rebaseline`).
- Flutter workflow não roda neste branch (paths: pull_request + codex/*) — suíte 484/484 é evidência local.

**Migration `20261031_0025` (verificado local):** head único, cadeia linear, upgrade base vazia OK (47 tabelas, `enrollment_policy` NOT NULL default `managed`, índice parcial `uq_classes_open_course`, `external_sync_requests` 13 colunas). Aplicação em staging: workflow `staging-alembic-migrate.yml` (guards: env=staging, sslmode, host aprovado) — **não executado**.

**Auditoria Flutter↔API↔WP↔LP:** contratos de payload compatíveis (`user_id` em user-by-phone/register; `course_slug` em enroll). UNKNOWN registrado: `courses.id` canônico deve coincidir com `post_name` LP por curso — gate de ativação explícito no contrato; falha 404 cairia em retry→`failed`→reconciliação (caminho seguro).

**Integridade histórico:** 6 commits verificados (8c0959b…99b438c), local≡remote, push b2ec4c9 limpo.

### Auditoria de integração — continuação (2026-10-31, HEAD c271e7e)

**Flutter CI (observado):** `workflow_dispatch` run 41202773069 no branch →
analyze-test **success**; log confirma `+484: All tests passed!` — suíte agora
tem evidência CI real (antes só local).

**Worker learnpress_sync (auditado):** claim `FOR UPDATE SKIP LOCKED`;
reclama pending + failed-com-backoff-vencido + processing-com-lease-vencido
(recuperação de crash); backoff `min(600, 2^attempts*5)`; attempts esgotados →
`failed` permanente p/ reconciliação. Detalhe: attempt é consumido no claim —
crash-loop pode esgotar 5 tentativas sem entrega real (bounded, por design).

**BLOCKED novo:** `staging-alembic-migrate.yml` está pinado em
`EXPECTED_ALEMBIC_HEAD: 20261003_0024` + ref fixo `89624132…` — não aplica
0025 por construção. Aplicar 0025 em staging exige re-pin revisado (ação
humana/governança, não automação).

**Gap de ativação (registrar):** se `SELF_ENROLLMENT_ENABLED` ligar antes de
`LEARNPRESS_SYNC_ENABLED`, matrículas nessa janela nunca entram na outbox
(`_enqueue_sync` retorna cedo). Ordem de ativação ou backfill deve entrar no
runbook de ativação das flags.

### Auditoria de integração — fechamento de lacunas (2026-10-31)

**PASS adicionais:** router self-enrollment wired em `main.py`;
`/open-classes` e `/self-enroll` exigem `access_claims` + flag (401 sem
token, 404 com flag off); WP `/register` coberto por `permission_callback`
X-API-Key igual às demais rotas (`/verify` é a única pública, por design);
modelo `ExternalSyncRequest` × migração 0025 consistentes (13 colunas,
`uq_external_sync_subject` dedup natural, `ix_external_sync_claim`).

**Entregável novo:** `docs/production/SELF_ENROLLMENT_ACTIVATION_RUNBOOK.md`
— 5 gates humanos (re-pin staging-migrate, mapeamento course_id↔post_name
LP, deploy register no WP, ordem das flags/backfill, smoke staging) +
rollback + template de evidência. Auditoria Flutter↔API↔WP↔LP fechada no
nível de código; lacunas restantes são todas de acesso/ambiente.

### Cloud staging fora / decisão EAD staging (2026-10-31)

**OBSERVED:** `tutor-tds-staging.fastapicloud.dev` UP mas todo endpoint com
DB → 500; `lgtphbbpgqnzduhtyate.supabase.co` → NXDOMAIN (projeto não
resolve; pausado ainda resolveria — provável exclusão). EAD staging
(`ead.ipexdesenvolvimento.cloud/tutor-staging-api`) saudável: /health ok,
/courses 200, `CERTIFICATE_CANDIDATE_ENABLED=true`, seeds preservados.

**DECISION (humana, 2026-10-31):** executar os gates físicos contra o EAD
staging aprovado. Implementação: guard Gradle de QA isolado relaxado para
aceitar qualquer URI em `approvedApiUris` (as duas rotas de staging seguem
pinadas; `DYNAMIC_QA_RUN_ID` continua obrigatório). Build do APK QA
reproduzível a partir deste commit.

### Macro QA web + autologin QA (2026-10-31)

**OBSERVED:** `tooling/web_qa.sh` roda 4 arquivos e2e web (23 testes) com
um comando: build release -> nginx app+proxy :9090 -> chromedriver -> PASS
por arquivo. `app_test` 17/17, `genui` 1/1, `account_qa` 4/4 (registro,
login, senha errada, tela Videos com catalogo real), `qa_autologin` 1/1.
Suites Android-only (6 arquivos com guarda `Platform.isAndroid`) fora por
design. Chrome for Testing 156 + chromedriver casado em uso (snap Chromium
falha por confinamento de /tmp).

**OBSERVED:** staging CORS ganhou origens de dev (`:9090`, `:8484`,
`:8080` em localhost/127.0.0.1 e 46.202.150.132) via
`STAGING_ALLOWED_ORIGINS` no compose local `/opt/tutor-tds-staging`
(backup `.env.bak-cors-webqa-20261031`, aditivo e reversivel). Sem isso o
browser bloqueia register/login antes de chegar na API.

**DECISION:** `config/staging.qa.web.json` (novo) = staging.qa.json +
`TUTOR_QA_AUTOLOGIN/CPF/PASSWORD/OPEN=videos`. O app servido em :9090
loga a conta QA sozinho e cai direto em Videos; flags ausentes em todo
outro config -> login manual intacto (producao inclusa). Testes e2e
continuam com `staging.qa.json` e cobrem o login manual real.
Conta QA: `900.777.123-07` (sintetica, staging apenas).

### Sincronizacao de conta app -> site WordPress (2026-10-31)

**OBSERVED (causa do sintoma):** conta criada no app nunca chegava ao site.
`/register` nao existia no plugin deployado (versao antiga; rota retornava
404) e o endpoint novo criava usuario `alunoXXXXXXXX` com senha aleatoria por
design ("student authenticates only in the app"). WP usa usermeta
billing_phone/_tds_phone/tds_telefone + tds_user_id para idempotencia.

**DECISION + implementado (staging):**
- `tds-lms-core` `register_user`: aceita `cpf` (vira user_login) e
  `password` (aplicada no create e re-aplicada no match -> senha do site
  converge com a do app). Lookup: tds_user_id -> phone metas -> login=CPF.
  Deployado no site EAD (mu-plugin, dir dokploy + /root/tds-wordpress;
  backup `.bak-wplogin-20261031`). POST /register: 404 -> 201 com chave.
- API (imagem `tutor-tds-api:staging-wplogin-20261031`, FROM
  `tutor-tds-candidate:c05-4976eb5` + auth.py/config.py/wp_account_sync.py):
  `_wordpress_login_provision` best-effort no register E no login —
  convergencia automatica a cada login bem-sucedido. Gate:
  `WORDPRESS_LOGIN_SYNC_ENABLED` + `WORDPRESS_BASE_URL` +
  `WORDPRESS_TDS_API_KEY` (envs do compose api-staging). UA customizado
  `TutorTDS-Sync/1.0`: Cloudflare bane `Python-urllib/*` (error 1010).
- Verificado: login QA via API -> WP user `90077712307` religado ao
  tds_user_id real; `wp_authenticate` no site -> LOGIN OK com a senha do app.

**UNKNOWN/BLOCKED:** producao exige as mesmas 3 envs + imagem equivalente
na linhagem prod (gate humano). Contas criadas antes convergem no proximo
login do app; nao ha backfill em massa (senha so existe em transito).
Repo api/ esta 40 commits atras da linhagem deployada
(`agent/integration-c01-c03-staging`); mesmas mudancas aplicadas ao repo
para quando houver merge.

### Certificado bundled — validacao em staging DESBLOQUEADA (2026-10-31)

O BLOCKED anterior (container api-staging crash-loop por migration
`20261030_0033` ausente) era drift de linhagem: a imagem deployada
(`tutor-tds-candidate:c05-4976eb5`, branch `agent/integration-c01-c03-staging`)
tem 33 migrations vs 25 do repo. Resolucao: imagem nova
`tutor-tds-api:staging-wplogin-20261031` = FROM c05 + patch minimo
(auth.py, config.py, wp_account_sync.py, certificate_requests.py) —
mesma linhagem do DB + fix do `contexts` portado identico ao do repo.

**TESTED-STAGING:** `GET /certificate-requests/contexts?course_id=saf`
sem `course_version_id` -> 200 com contexto resolvido na edicao legada
`9350c62e-14fd-5340-9408-c73a5b36b399` (enrollment QA `qa-cert-enroll-1`,
programa `staging-qa-program`, elegibilidade exposta). Regressao: com
versao explicita -> 200 inalterado; versao inexistente -> contexts vazio
sem erro. App :9090 rebuildado com o fix do lado Flutter.

### Grafo de cobertura web — caminho minimo EXECUTADO (2026-10-31)

`docs/qa/WEB_COVERAGE_GRAPH.md` modela o grafo Navigator completo
(vertices/arestas/categorias, Mermaid, DFS vs Carteiro Chines, arestas
condicionais web-vs-Android). OBSERVED: o app nao tem router de URL —
vertices sao rotas Navigator/dialogs; F5 e browser-back sao arestas de
ciclo de vida, nao de deep-link.

**TESTED-STAGING:** `integration_test/web_postman_test.dart` PASSOU no
web (chrome headless, staging.qa.json). Executa a cadeia de entrada +
todos os spokes student em uma sessao continua:
welcome->account_login->privacy_consent->home; home->videos->player->
catalog; nav Aprender->study_hub->flashcards->resumo; nav Conteudos->
media_catalog; home->certificate_wallet; home->user_guide; nav Perfil->
cadunico; menu->support; menu->settings->privacy_policy+onboarding
review; menu->about; F5->home (sessao persiste via SharedPreferences).
Defeitos do proprio teste corrigidos: login por keys
`account-login-cpf`/`account-password`; botoes 'Meus certificados' e
'Como usar' sao OutlinedButton (nao FilledButton); Home usa scroll lazy
(scrollUntilVisible); icone menu_book colide com nav Aprender.
Incluido na suite do `tooling/web_qa.sh` (agora 5 arquivos e2e).

**UNKNOWN/BLOCKED:** vertices de gestao (management_workspace,
operator_operations, course_editor, classroom_*, evidence_*, student_
followup, certificate_review) exigem claims de professor/operador —
nao executados com a conta student QA. Caminho do teste e o passeio
minimo pratico dos vertices student, nao um otimo formal do CPP
(pesos de aresta nao medidos). Deep-links de URL e gestao ficam
registrados como edges condicionais no grafo.

### account_qa_test reestruturado como DFS (2026-10-31)

`integration_test/account_qa_test.dart` virou uma unica travessia DFS do
grafo de auth (substitui os testes A1-A4 separados): V0 welcome/auth ->
e1 login-falha (senha errada -> `account-error` -> BackButton retorna
V0) -> e2 registro (`AlertDialog` -> 409 duplicata ou 201 -> Cancelar
retorna V0) -> e3 login-sucesso -> V1 privacy_consent -> e4 aceite ->
home -> e5 videos/catalogo (cards + affordance de midia Image/
play_circle). PASSOU em web headless contra staging real. Observacao
estrutural: `account_login` e rota empurrada (`AccountLoginScreen`),
registro e `AlertDialog` — back-edges distintas (BackButton vs Cancelar).

### learning_qa_test — DFS V2->V3->V4 EXECUTADO (2026-10-31)

`integration_test/learning_qa_test.dart` PASSOU em web headless contra
staging: catalogo -> Aula 01 -> player (e6) -> 'Salvar' estado+
persistencia (e7a) -> rating 5 estrelas `PUT /media/:id/rating` (e7b) ->
retorno (e8) -> Perfil/CadUnico campos Nome/WhatsApp/CPF (e9) -> wallet
certificados (e10). Adicionado a `tooling/web_qa.sh` (6 arquivos e2e).

**ANOMALIAS web-vs-Android documentadas:**
- Nao existe botao "Marcar como Concluida": conclusao e evento `ended`
  via postMessage do embed (iframe no web, webview no Android) — aresta
  nao dirigivel por UI em nenhuma plataforma; e7 usa arestas reais.
- e7b OBSERVED: API respondeu `403 Matricula ativa obrigatoria` — video
  `staging-qa-media` sem matricula QA; o app exibe issue corretamente.
  Escrita efetiva = aresta condicional de dados (matricula no curso).
- `shareCertificates` usa dart:io File + SharePlus — quebra no web
  (sem filesystem). `printCertificates` usa package printing — funciona
  (dialog de impressao do browser). Arestas de PDF inalcancaveis com QA
  (wallet vazia) — condicionais a certificado emitido.
- Player usa ListView lazy: conteudo abaixo da dobra so existe na
  arvore apos scroll (tecnica de teste, nao bug).

### Certificados no web — vertice condicional RESOLVIDO (2026-10-31)

**FIX IMPLEMENTADO** (recorte certificados, compatibilidade nativa
preservada):
- `certificate_repository.dart`: web usa SharedPreferences
  `certificate_index_v1` p/ o indice JSON (filePath nulo); nativo mantem
  filesystem inalterado. Antes: getApplicationDocumentsDirectory ->
  MissingPluginException -> wallet em estado de erro no web.
- `certificate_service.dart`: `shareCertificates` -> `if (kIsWeb)`
  `Printing.sharePdf` (download blob); `issue()` pula `pdfService.save`
  no web (PDF reconstruido sob demanda por build()).
- `certificate_pdf_service.dart`: `save()` guardado p/ nativo.

**TESTED-STAGING:** `integration_test/wallet_qa_test.dart` PASSOU —
semeia CertificateRecord (hash sha256 valido) via repository web,
wallet renderiza card (e11), details com holder+hash+QR (e11b),
'Compartilhar PDF' -> sharePdf sem excecao (e12a), 'Imprimir' ->
layoutPdf sem crash (e12b). Adicionado a `tooling/web_qa.sh`
(7 arquivos e2e). Grafo mermaid atualizado em WEB_COVERAGE_GRAPH.md
com arestas executadas + erro/retorno + fallbacks web.

**UNKNOWN/BLOCKED:** `Printing.layoutPdf` no headless pode suprimir o
dialog de impressao do browser — verificado "sem crash", nao "dialog
aberto". Android inalterado (filesystem + share_plus).
