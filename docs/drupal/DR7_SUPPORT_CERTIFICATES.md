# DR-7 — certificados e suporte contextual (#168)

## Contrato e auditoria

- Base: `207e2128dcbcedec70bf5132b05a7081501480ed`, `staging`.
- Branch: `agent/issue-168-support-certificates-20261015`.
- Objetivo único: consulta privada de referências de certificado e integração
  efêmera de identidade do suporte, sem criar autoridade no CMS.
- OBSERVED: `/certificates` retorna referências da conta TDS;
  `/support/identity` retorna `identifier` + HMAC em `api/app/support.py`.
  `AUTH_SESSION_DECISION.md` regra 12 permite somente entrega efêmera ao widget.
- DECISION: Drupal adotado; FastAPI permanece autoridade acadêmica. G3 de
  `API_CONTRACT_MATRIX.md` impede inventar API pública de verificação.
- IMPLEMENTED: módulo opt-in `tds_support_certificates`; nenhuma alteração em
  gateway, `core.extension`, Flutter, API, Worker/KV, banco ou infraestrutura.
- Dependências: #164/#165 existentes; integração de navegação da área do
  participante (#166/PR #180) e aceite ponta a ponta (#170) permanecem pendentes.
- Risco: identidade assinada e origem externa; URLs exatas por ambiente, sandbox
  opaco, ausência de cache e limpeza de lifecycle limitam a exposição.
- HUMAN_GATE: não necessário para adapters/fakes. Credenciais/Chatwoot real,
  merge e produção permanecem fora desta execução.

## Rotas e estados

| Rota | Contrato |
| --- | --- |
| `/verificar-certificado` | Página pública com handoff para URL oficial configurada. Não recebe código/hash e não interpreta validade. |
| `/meus-certificados` | Sessão TDS server-side → `/certificates`; só título, data e URL oficial aprovada são projetados. Lista vazia, sessão ausente, acesso negado e indisponibilidade são distintos. |
| `/suporte` | Entrada pública com botão explícito para atendimento autenticado e fallback público separado. Nenhum widget é carregado automaticamente. |
| `/tds/support/identity` | GET no-store autenticado pelo adapter; retorna assinatura mínima e configuração pública da inbox. Desativado por padrão. |
| `/tds/support/frame` | Documento sem identidade em HTML, sandbox opaco com CSP própria, inicializado por postMessage. |

A consulta de certificado confere o `user_id` da referência contra `/auth/me`.
Divergência falha a lista inteira; não publica registro de outra pessoa. URL fora
allowlist é omitida; nenhuma tentativa de corrigir/reconstruir código é feita.
`content_hash`, holder, CPF, e-mail e IDs acadêmicos não entram na projeção.
Nenhum status "válido" é calculado no Drupal. Código inexistente, discrepância
ou Worker indisponível devem ser informados pelo verificador oficial; sem G3 não
há consulta nativa nem teste de disponibilidade do Worker neste módulo.

## Configuração por ambiente (TARGET, sem segredos)

Instalar explicitamente somente em ambiente de testes autorizado:

```sh
vendor/bin/drush en tds_support_certificates -y
```

Configurar em settings do ambiente, não no conteúdo editorial; exemplos sintéticos:

```php
$settings['tds_certificate_allowed_origins'] = ['https://verify.example.test'];
$settings['tds_certificate_verifier_url'] = 'https://verify.example.test/';
$settings['tds_support_allowed_origins'] = ['https://support.example.test'];
$settings['tds_support_public_url'] = 'https://support.example.test/contato';
$settings['tds_chatwoot_allowed_origins'] = ['https://chat.example.test'];
$settings['tds_chatwoot_origin'] = 'https://chat.example.test';
$settings['tds_chatwoot_website_token'] = 'public-inbox-token';
$settings['tds_chatwoot_enabled'] = FALSE;
```

O website token é identificador público da inbox, **não** o segredo HMAC. O segredo
permanece apenas na API. Não compartilhar token/inbox entre ambientes. Não ativar
com Chatwoot real antes da prova de compatibilidade abaixo.

URLs exigem HTTPS e origem exata (host e porta), sem usuário, senha, fragmento,
controle ou barra invertida. A base da API vem somente do settings do gateway;
HTTP é permitido exclusivamente em loopback e ambiente `local`. O adapter não
segue redirects, não grava cache e não repete GETs após erro upstream. Ele chama
`context()` antes de ler o access token atualizado pelo gateway. O lock local
reduz sobreposição durante a chamada, mas **não garante refresh serializado**,
nem entre duas chamadas deste mesmo módulo: Drupal lê a sessão antes do acquire
e persiste depois do release. Outra request pode carregar snapshot antigo e
reutilizar refresh já revogado.
401 do recurso após essa revalidação encerra a sessão local, sem loop de refresh.
429 não causa retry imediato; usuário deve tentar mais tarde. Respostas upstream
não são ecoadas nem encadeadas em exceções que possam reter bearer.

## Privacidade, CSP e lifecycle

- Todas as respostas (inclusive erro, reforçadas por subscriber após o cálculo final Drupal) são `Cache-Control: no-store, private`,
  `Pragma: no-cache`, `Referrer-Policy: no-referrer` e `nosniff`; render cache zero.
- O par assinado não existe em SSR, atributo HTML, URL, log, analytics ou storage
  do módulo. A entrega começa só após clique e resposta autenticada.
- O SDK é executado em iframe `sandbox="allow-scripts allow-forms"`, sem
  `allow-same-origin`. Scripts terceiros não leem DOM/cookies/storage do portal;
  a sandbox é também imposta pelo header CSP, inclusive na abertura direta.
- postMessage verifica `source`, origem e nonce aleatório de 128 bits. O destino
  opaco exige `*` somente na entrega parent→frame; o nonce não é uma credencial
  e o payload não é enviado antes de o frame correto confirmar prontidão.
- CSP do frame: default none; script self + origem Chatwoot; connect HTTPS/WSS
  somente Chatwoot; frame/image/font/style limitados ao provedor (imagem data e
  style inline apenas pela necessidade do SDK); frame-ancestors self; base none.
  A CSP do portal hospedeiro precisa permitir frame self e JS local; não incluir
  Chatwoot em script-src do documento principal. Não ampliar CORS da API.
- O iframe não abre antes de setUser. Timeout de 15s/erro remove o iframe e oferece
  fallback manual. O fallback não envia POST nem cria caso/conversa automaticamente.
- `pagehide`, retorno bfcache, aba oculta, botão de fechar e evento
  `tds:session-ended` removem iframe/identidade e abortam requests; respostas
  tardias são ignoradas. Heartbeat revalida identidade a cada 15s e remove o widget
  ao detectar conta trocada ou sessão encerrada. Requests têm timeout de 10s.
- A página privada remove o DOM de certificados em pagehide/session-ended e
  refaz a consulta ao retornar pelo bfcache; não restaura snapshot privado.
- Não instrumentar estas rotas com analytics, session replay ou captura de links:
  URLs oficiais de verificação contêm códigos. O módulo não registra telemetria.

## Limites explícitos antes do aceite #170

1. **BLOCKED: SDK Chatwoot real.** A sandbox proíbe storage. Se o SDK exigir
   cookies/localStorage/same-origin, ele falha com fallback; não relaxar sandbox
   para "fazer funcionar". É necessário comprovar inbox/HMAC e ausência de
   persistência no navegador em staging ou definir adapter compatível mantendo
   ADR12. Fake não prova SDK externo.
2. **BLOCKED: implantação de todas as integrações autenticadas, inclusive
   certificados, até correção da concorrência de sessão.** O middleware Drupal
   lê a sessão antes do acquire do adapter e grava depois do release. Duas
   requests deste mesmo módulo podem carregar o mesmo refresh, então a segunda
   pode fazer replay de token rotacionado mesmo sem overlap dentro do adapter.
   O gateway também não publica evento de logout nem compartilha lock com
   #166/#167/login/logout. A correção pertence ao gateway/middleware reservado:
   coordenar o lifecycle completo leitura→refresh→persistência, com prova
   concorrente, antes de qualquer deployment autenticado. Lock local não fecha
   esse gate. Logout em outra aba pode levar até heartbeat + timeout para remover
   o widget; sair desta página/ocultar a aba remove imediatamente. Padronizar
   sinalização de sessão também é necessário para aceite E2E.
3. **BLOCKED: G3/verificador nativo.** Teste real válido/inválido/Worker
   indisponível pertence ao handoff oficial até contrato público aprovado.
4. **UNKNOWN: navegação #166, CSP do deployment, accessibility/performance e
   isolamento browser com serviços reais.** Não inferir aceite a partir de mocks.
5. **Offline:** nenhum snapshot privado; apresentar falha e fallback. Sem emissão,
   alteração, aprovação, fila de conversa ou autorizações locais.

## Testes focais

```sh
vendor/bin/phpunit --configuration phpunit.xml.dist web/modules/custom/tds_support_certificates/tests
vendor/bin/phpcs --standard=phpcs.xml.dist web/modules/custom/tds_support_certificates
```

TESTED-LOCAL (PHP 8.3.29, dependências do `composer.lock`): 35 testes, 107 assertions,
PASS. PHPCS do módulo: PASS. Contratos positivos, vazio, proprietário divergente,
URL indevida, identidade ausente/inválida/trocada, 401/403/429/503/redirect, sessão
ausente, no-store e módulo desativado cobertos. Evidência browser fake deve ser
registrada separadamente; não confundir com prova de Worker/Chatwoot reais.

Rollback: manter `tds_chatwoot_enabled=FALSE` e desabilitar o módulo se necessário;
nenhuma migration, entidade ou escrita acadêmica foi adicionada.

### Evidência de integração local — 2026-10-15

- PHP 8.3.29, Drupal 11.4.8 e dependências exatas do `composer.lock`.
- Suíte custom completa: **60 testes / 201 assertions PASS** (baseline 25/94;
  DR7 35/107). `bash scripts/lint.sh`: PHP, PHPCS, 121 YAML e 6 Twig PASS.
- Drupal minimal instalado em SQLite 3.46.1 isolado, módulo habilitado somente
  neste fixture; nenhuma base externa. Chromium 151.0.7922.173:
  **20 verificações PASS**, script `drupal/scripts/test-dr7-browser.cjs`.
- Rotas HTML reais e identity anônimo401; cabeçalhos no-store reais; limpeza de
  DOM privado; SDK e identidade interceptados por fixtures sintéticos. Sandbox
  bloqueia storage e DOM pai; identidade ausente em SSR/storage; início explícito;
  falhas401/SDK com fallback; mensagens forjadas ignoradas; fechar/reabrir,
  evento de logout e heartbeat com sessão rejeitada removem iframe.
- O teste detectou/corrigiu sobrescrita no-store pelo Drupal e timer de heartbeat
  não reiniciado depois de fechar. Não substitui concorrência real, Chatwoot,
  Worker, contas reais, staging nem auditoria WCAG/performance.

Para repetir o browser: instalar Drupal minimal em fixture local descartável
com SQLite, habilitar módulo e configurar settings sintéticos acima usando
`tds_chatwoot_origin=https://chatwoot.example.test` (e allowlist igual), website
 token `synthetic_inbox` e `tds_chatwoot_enabled=TRUE`. Executar servidor PHP
**a partir de `web/`**; settings locais e DB não devem ser commitados.
Drush site:install pode reescrever settings.php: preservar/restaurar a versão
versionada e manter overrides somente em settings.local.php.

```sh
# Shell na pasta drupal; Playwright instalado no ambiente de QA.
DR7_BASE_URL=http://127.0.0.1:8770 \
CHROMIUM_PATH=/usr/bin/chromium \
node scripts/test-dr7-browser.cjs
```

`PLAYWRIGHT_MODULE` aceita caminho absoluto da instalação do Playwright.
O script aceita apenas destinos locais predefinidos e usa exclusivamente
`*.example.test` para interceptações; não aponta ao atendimento real.
Revisão independente local: sem bypass identificado em URL/postMessage;
gate P1 de sessão compartilhada registrado acima, ainda **não resolvido**.
