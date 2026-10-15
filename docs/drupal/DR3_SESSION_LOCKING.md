# DR-3 / DR-7 — mutex da sessão antes da leitura (#168, PR #207)

## Auditoria e fronteira

Base da fatia: `6f6f6d4` (PR #207), derivada de staging `207e2128`.
Arquivos compartilhados de #166/PR #180 e #167/PR #181 não foram importados.
O novo registro é aditivo em `tds_tutor_gateway.services.yml`; esses PRs precisam
reconciliar o registro do middleware quando forem integrados.

OBSERVED: `Drupal\Core\StackMiddleware\Session` inicia/lê a sessão antes do
controller e persiste depois. O lock do adapter DR-7, adquirido no controller,
não evita que outra request carregue o refresh antigo antes de esperar pelo lock.
A segunda request pode reutilizar refresh já revogado ou salvar tokens depois de
um logout. A correção precisa abranger **leitura → refresh → persistência**.

IMPLEMENTED: `TutorSessionLock`, prioridade 60, envolve o middleware de sessão
Drupal (50). Abrange toda request principal com cookie de sessão do site,
inclusive conteúdo editorial: qualquer gravação do mesmo snapshot pode reverter
um logout. Rotas ainda não foram resolvidas nessa fronteira; limitar por rota
acadêmica deixaria a corrida aberta. Subrequests usam o dono da request principal.
Sem cookie, o serviço de mutex nem é construído (`!service_closure`). Falhas de
construção/conexão ocorrem dentro da fronteira sanitizada de erro.

## Mutex e falhas

- Backend explícito: MySQL/MariaDB, `GET_LOCK(key, 0)` / `RELEASE_LOCK(key)`.
  Sem TTL, lease ou stealing: uma request lenta não perde a exclusão por relógio.
- Usa a **mesma conexão primária pinada** do `SessionHandler` Drupal padrão;
  não abre conexão dedicada. Se o PDO cair, a gravação da sessão também falha
  nessa conexão; não existe uma conexão separada ainda capaz de gravar snapshot
  obsoleto. Named locks sobrevivem commit/rollback das transações MySQL.
- PDO persistente é recusado. O backend aceita somente a classe exata do handler
  padrão; Redis, decorators de sessão/contrib e armazenamento customizado exigem
  revisão própria. PostgreSQL e SQLite são recusados em requests com cookie.
  Requests públicas sem cookie continuam disponíveis. A comparação de classe não
  detecta rewire da mesma classe para outro DB nem proxies personalizados em
  `session_handler`. O aceite exige wiring core padrão (incluindo somente seus
  proxies padrão), sem reconnect automático e sem storage externo.
- Chave SHA-256 de namespace + nome do cookie Drupal + ID da sessão. O nome já
  incorpora o escopo do site/domínio configurado. Não acrescentar o Host: aliases
  que compartilham cookie precisam do mesmo lock. Nenhum cookie/token aparece
  no nome do lock ou no erro público.
- Contenção retorna `503`, `Retry-After: 1`, `no-store`, antes de ler a sessão ou
  chamar a API. O navegador pode tentar novamente; nenhum POST é reenviado pelo
  middleware. Outra sessão permanece independente.
- O lock só é liberado depois do save normal ou do save do `finally`. Se ocorrer
  erro após rotação, o token já rotacionado é persistido antes da liberação.
  Falha de save/release não devolve conteúdo autenticado, apenas erro sanitizado.
- Morte do processo/fechamento da conexão libera o named lock no servidor.
  Queda entre rotação upstream e persistência pode exigir novo login; não há
  transação distribuída FastAPI→Drupal nem promessa de recuperar token perdido.
- `ResponseKeepSessionOpenInterface`, incluindo **BigPipe**, é recusada com 503
  em request com cookie: saves diferidos não podem escapar do mutex. Não habilitar
  BigPipe nessa configuração sem desenhar outra fronteira e testar sua segurança.
- Login que regenera ID começa sob lock do cookie de entrada; a nova identidade
  só chega ao browser depois do save. Requests ainda usando o cookie antigo devem
  ler a sessão antiga removida, não copiar seu snapshot. A prova de rotação nativa
  core passou no complemento abaixo; rotação do login TDS e reconciliação com
  #180/#181 permanecem no gate integrado.

## TESTED-LOCAL

Ambiente descartável: PHP 8.3.29, Drupal 11.4.8, MySQL **8.4.11**, banco
`tds_lock_qa`, Unix socket e rede Docker desabilitada. API e contas sintéticas.
Esse ensaio inicial não comprova MariaDB, serviços reais ou produção. A prova
MariaDB posterior está registrada no complemento abaixo.

Após reconciliar staging `b0c39b2` (PR #211), o candidato `5a76db5` passou
novamente em fixture isolada no VPS, sem rede e sem volumes de produção:
**Drupal 11.4.10 / PHP 8.3.35, 68 testes / 250 assertions e 43 verificações
de configuração de produção PASS**. A imagem PHP foi a mesma usada no portal;
nenhum serviço publicado foi alterado. Essa execução unitária não substitui a
homologação concorrente em MariaDB.

- Suíte unitária Drupal: **67 testes / 234 assertions PASS**. Lint completo:
  PHP syntax, PHPCS, 121 YAML e 6 Twig PASS.
- 7 testes unitários novos / 33 assertions: exclusão antes do snapshot,
  persistência da rotação/logout, aliases compartilhados, exceção, backend
  indisponível e construção lazy sem cookie.
- `test-dr3-session-concurrency.php`: **15 verificações PASS**, subprocessos PHP
  independentes, mutex real MySQL, armazenamento de sessão controlado:
  B não lê snapshot durante A; retry vê token novo; uma rotação; logout sem
  ressurreição; save após exceção; perda do PDO por `KILL` não retorna conteúdo
  autenticado nem grava snapshot; outra sessão independente; `kill -9` do dono
  libera o lock sem aguardar TTL.
- Modo `http`: **5 verificações PASS** com Drupal instalado, middleware de sessão
  e `SessionHandler` reais, quatro workers HTTP e API fake loopback. A chega ao
  refresh, B recebe 503 antes da leitura, A persiste e retorna 200, retry de B
  retorna 200 com token novo, upstream aceita somente uma rotação. Executado após
  a versão final com `service_closure` e conexão primária compartilhada.

### Reproduzir a prova de processos

Provisionar somente fixture local descartável MySQL 8.4, banco `tds_lock_qa`, root
sem senha, Unix socket montado no runner PHP. Não apontar para banco existente.
O script cria/remove apenas tabelas `qa_session`, `qa_refresh` e `qa_events` nesse
banco fixo; recusa execução sem opt-in.

```sh
TDS_SESSION_MUTEX_QA=1 \
TDS_SESSION_MUTEX_SOCKET=/socket/mysqld.sock \
php scripts/test-dr3-session-concurrency.php
```

### Reproduzir a prova HTTP

No mesmo banco descartável, instalar Drupal minimal; habilitar somente gateway.
Configurar socket e `tutor_api_base_url=http://127.0.0.1:8872` em settings local
ignorado. Instalação pode alterar `settings.php`: preservar/restaurar somente o
scaffold produzido pelo instalador, nunca settings de outro ambiente.

```sh
# Servidor Drupal com concorrência real, cwd=web:
PHP_CLI_SERVER_WORKERS=4 php -S 127.0.0.1:8871 .ht.router.php
# API fake, cwd=drupal, mesmas envs opt-in/socket:
php -S 127.0.0.1:8872 scripts/fixtures/session-lock-api.php
```

Criar uma única sessão editorial sintética pelo login JSON Drupal, guardando cookie
em `/tmp/tds168-session-cookie` (ou `TDS_SESSION_MUTEX_COOKIE_JAR`). Essa conta não
concede autorização acadêmica: a fixture injeta tokens sintéticos exclusivamente
no banco descartável. Não usar credenciais reais.

```sh
# Com as envs QA/socket definidas:
php scripts/fixtures/session-lock-api.php seed
php scripts/test-dr3-session-concurrency.php http
```

O seed exige exatamente uma sessão; endpoint fake aceita um único refresh antigo
com atraso de 1,2s e rejeita replay. Depois, parar/remover apenas os runners desta
fixture e seus settings locais. Não deixar serviços ou volumes permanentes.

## Gates e rollback

IMPLEMENTED/TESTED-LOCAL fecha a lacuna de ordering no recorte comprovado. Ainda
BLOCKED: implantação autenticada, custom backends/BigPipe, serviços acadêmicos
reais, prova real de sinalização de logout entre abas, SDK Chatwoot real e
aceite #170. Nenhum deploy, API, Worker, Flutter, secret ou conta real foi alterado.

Reverter middleware restaura a corrida conhecida; portanto rollback exige manter
as superfícies TDS autenticadas indisponíveis até outra correção. Não remover o
mutex e declarar a sessão segura. Mudança não cria schema persistente nem migração.

## Continuação — MariaDB e rotação nativa comprovadas em fixture

TESTED-LOCAL em fixture isolada no VPS (sem serviço produtivo): 15 verificações
concorrentes passaram em **MariaDB 11.8.9**, usando a mesma imagem do banco do
portal (`sha256:6422478cb8e159f080fb1d8ccf65101e26fe51385787fde7d16c3b165a331f15`),
PHP 8.3.35 e Drupal 11.4.10. Banco `tds_lock_qa` em tmpfs, containers sem rede e
sem portas publicadas; removidos após execução. A primeira preparação detectou
socket ausente porque o ping havia atingido o servidor temporário de init.
Readiness corrigido: exigir PID1 final `mariadbd` e `SELECT 1` no banco QA, antes
de iniciar PHP. Não foi falha do mutex nem houve alteração no banco produtivo.

TESTED-LOCAL: candidato `1c26451` executado na mesma fixture isolada no VPS,
Drupal 11.4.10/PHP 8.3.35/MariaDB 11.8.9, quatro workers PHP e API fake loopback.
**5 checks HTTP + 11 checks de rotação/logout PASS** (exit 0). A fixture transforma a única sessão sintética em
anônima editorial preservando tokens acadêmicos sintéticos; refresh concorrente
bloqueou login core; retry do login core regenerou ID. O cookie antigo recebeu
401, o novo manteve contexto, e o logout core invalidou tanto o cookie antigo
quanto uma **cópia imutável do cookie regenerado**, além de limpar o browser.

**Esta prova é do login/logout editorial Drupal e SessionHandler nativo. O login
TDS atual não chama regenerate/invalidate; portanto sua proteção específica contra
fixação e rotação obrigatória continua BLOCKED em #164/#166. Não considerar a
prova editorial como aceite desse contrato.**

Runner repetível, somente em cópia descartável de código/vendor e banco QA vazio:

```sh
TDS_SESSION_MUTEX_QA=1 \
TDS_SESSION_MUTEX_FIXTURE_ROOT=/copia/descartavel/drupal \
TDS_SESSION_MUTEX_SOCKET=/socket/mysqld.sock \
bash scripts/test-dr3-http-fixture.sh
```

O root deve corresponder exatamente ao diretório Drupal real da cópia. O runner
recusa settings locais existentes, banco não vazio e portas 8871/8872 ocupadas;
instala Drupal minimal e conta editorial sintética fixa, inicia workers somente
em loopback e verifica que ambos os listeners continuam vivos antes do login.
Executa os 5 checks HTTP existentes e os 11 checks novos, encerra grupos dos
processos e restaura settings. Não cria containers; o chamador garante rede
`none`, tmpfs e cleanup dos containers/cópia. Em falha registra a etapa e preserva
somente logs sintéticos em `.tds-session-http-failure` dentro da própria cópia.
Cookie jars e respostas de login não são impressos nem mantidos nesse recibo.

Revisão independente do candidato `1c26451`: preflight de portas, filhos vivos,
timeouts e replay do cookie revogado conferidos, sem bloqueador adicional nesse
recorte. Não houve alteração de serviço produtivo nem aceite E2E #170.


## Candidato — rotação no login e logout TDS

IMPLEMENTED/TESTED-LOCAL no descendente integrado abaixo: `DrupalTutorSessionLifecycle` usa
`migrate(TRUE)` para destruir o ID anterior mantendo os atributos editoriais.
Login descarta primeiro os tokens TDS anteriores, autentica na API, rotaciona o
ID e só então salva novos tokens. Credenciais recusadas deixam contexto TDS vazio.
Falha de migração retorna 503 sanitizado e nunca salva novos tokens no ID antigo.
Logout remove tokens e rotaciona o ID, preservando o login CMS independente.

A fixture acrescenta 21 checks específicos via rotas TDS reais: CSRF obrigatório,
login, troca de conta, replay do cookie anterior, tentativa inválida, recuperação,
logout/replay revogado e preservação editorial. A API é exclusivamente sintética.
O helper CSRF lê apenas o banco QA fixo e captura o token em memória; não altera a
política CSRF das rotas nem imprime cookies ou tokens. Os 11 checks anteriores
continuam exclusivamente core; os 21 TDS passaram no descendente integrado
`72e97d6` (PR #212), que concilia #180/#181. Gate de produção permanece pendente.

Validação focal deste candidato: 32 testes gateway/115 assertions em PHP 8.3.29,
PHPCS (21 arquivos) e sintaxe dos scripts PHP/shell PASS; CLI efêmera sem rede.

Revisão independente sem bloqueador para ensaio: os 21 checks iniciam com sessão
editorial existente. NÃO comprovam bootstrap/primeiro login de participante sem
conta CMS: sessão lazy sem cookie não permite regenerate; obtenção de cookie e
CSRF anônimo exige prova integrada própria antes de ativação.

## Recibo do descendente integrado — PR #212

TESTED-LOCAL: `72e97d6`, executado pelo coordenador em fixture VPS isolada
`network none`, PHP 8.3.35/Drupal 11.4.10/MariaDB 11.8.9. PASS: **112 testes/467
assertions + 69 checks de settings + 15 concorrentes MariaDB + 5 HTTP refresh +
11 core cookie + 21 TDS login/logout**. A flag de integração habilitou módulos
participante, operador e suporte exclusivamente na fixture; API/contas sintéticas.

Esse recibo pertence ao descendente integrado, não ao SHA isolado `0cfa05c`, cuja
prova focal foi 32 testes/115 assertions em PHP 8.3.29. Bootstrap anônimo sem conta
CMS continuava pendente nesse recibo; a prova posterior abaixo fecha o recorte
sintético. Não houve deploy nem aceite de produção a partir da prova.

## Candidato — primeiro acesso sem conta editorial

IMPLEMENTED/TESTED-ISOLATED: `/entrar` entrega formulário sem credenciais nem
CSRF no HTML. JS externo solicita `POST /tds/session/bootstrap`, restrito à mesma
origem e ao header não simples `X-TDS-Bootstrap: 1`. O bootstrap grava somente
um marcador booleano na sessão anônima: metadata CSRF isolada não garante que o
Drupal persista a sessão. Retorna tokens Drupal específicos para login/logout,
em JSON privado `no-store`, sem CORS. Login/logout mantêm `_csrf_token`, recebem
verificação adicional de Origin (Referer somente se Origin ausente), e mantêm
rotação destrutiva do ID. Nenhum usuário Drupal é criado. As URLs para POST são
construídas sem o processador de rotas CSRF, para não antecipar tokens no HTML.

A UI pede bootstrap antes de cada operação, não guarda tokens/credenciais em
storage, envia CPF/senha apenas no POST e limpa senha após falha. A sessão CMS
existente continua independente. `/entrar` e bootstrap seguem bloqueados pelo
gate de produção; nenhuma ativação está implícita neste candidato.

Prova preparada em `scripts/test-dr3-browser-login.cjs`: Chromium com contexto
vazio, cookie anônimo, Origin/CSRF ausente/incorreto/de outra sessão, login pela
UI, contexto acadêmico com uid editorial zero, cookie antigo inutilizável e
logout pela UI com replay revogado. API e contas somente sintéticas; execução
runtime comprovada no recibo abaixo. O runner HTTP aceita bind QA allowlisted e hold de até
120 segundos com sentinelas `.tds-browser-ready`/`.tds-browser-done`, para o
coordenador testar via porta local 18871 em rede isolada. Nenhum container é
criado pelo script. Sem TLS nessa fixture: `Secure` permanece gate do deployment.

Validação estática/unitária do candidato: 127 testes/488 assertions em PHP 8.3.29,
lint PHP65/PHPCS64/YAML130/Twig8 e 69 checks de settings PASS.


### Recibo de primeiro acesso anônimo — 15/10/2026

**24 checks Chromium 151.0.7922.173 PASS em `7279bed`**, PHP 8.3.29/Drupal 11.4.8/MySQL 8.4.11.
Browser começa sem cookies, entra pelo formulário e permanece com uid editorial
zero. Foram observados: bootstrap `no-store`, ausência de CORS e CSRF no HTML,
HttpOnly/SameSite=Lax, recusas de CSRF ausente/incorreto/de outra sessão e origem
estrangeira, senha limpa após falha, contexto persistido, storage vazio, rotação
com cookie antigo401, logout pela UI e replay do cookie autenticado401. O mesmo
runner passou 5 HTTP refresh + 11 core + 21 TDS. API e identidades sintéticas.

A primeira execução não atingiu o produto: Docker em rede interna não publicou
a porta solicitada. Investigação confirmou conexão recusada; o coordenador
validou transporte com PHP sintético e usou forwarder restrito ao loopback para
IP privado da fixture, mantendo isolamento. Não houve correção de produto por
esse erro. Recibos locais: `/tmp/tds-browser-bootstrap.eosimM/browser.log` e
`web-runner.log`; cleanup exit 0.

**VPS `146e67c` PASS:** PHP 8.3.35/Drupal 11.4.10/MariaDB 11.8.9, 127 testes/488
assertions + 69 settings + 15 concorrentes + 5 HTTP + 11 core + 21 TDS. Rede
`none`, API sintética, cleanup exit 0. `e53905a`/`7279bed` alteraram apenas o
script browser, sem código de produto; a prova anônima Chromium ocorreu localmente, não no VPS.
O gap sintético anônimo dos recibos anteriores está fechado. Serviços reais,
TLS/Secure de deployment, WCAG/performance e aceite de produção seguem pendentes.
