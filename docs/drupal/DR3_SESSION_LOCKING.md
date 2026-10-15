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
  ler a sessão antiga removida, não copiar seu snapshot. Prova explícita de rotação
  de ID e reconciliação com #180/#181 permanecem no gate integrado.

## TESTED-LOCAL

Ambiente descartável: PHP 8.3.29, Drupal 11.4.8, MySQL **8.4.11**, banco
`tds_lock_qa`, Unix socket e rede Docker desabilitada. API e contas sintéticas.
Isso não comprova MariaDB 11.8, serviços reais ou produção.

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
BLOCKED: aceite MariaDB do deployment, custom backends/BigPipe, rotação de cookie,
integração #180/#181, sinalização imediata de logout entre abas, SDK Chatwoot real e
aceite #170. Nenhum deploy, API, Worker, Flutter, secret ou conta real foi alterado.

Reverter middleware restaura a corrida conhecida; portanto rollback exige manter
as superfícies TDS autenticadas indisponíveis até outra correção. Não remover o
mutex e declarar a sessão segura. Mudança não cria schema persistente nem migração.
