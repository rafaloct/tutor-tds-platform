# Decisão de autenticação e sessão do portal Drupal

Status: **TARGET**, apoiado nos contratos **OBSERVED** de [`api/app/auth.py`](../../api/app/auth.py).

Base auditada: `staging@d2da096fe13dd18641aa8b557b3702622baa3b34`.

## Decisão resumida

O Drupal atua como BFF. O navegador mantém somente um identificador opaco de sessão Drupal. Access token e refresh token do Tutor TDS permanecem no servidor, nunca são entregues ao JavaScript e nunca são usados como cookie de autenticação direto.

Contas editoriais Drupal e identidades acadêmicas TDS permanecem separadas. Autenticar no portal TDS não cria conta Drupal; autenticar no Drupal administrativo não concede acesso acadêmico.

## Evidência observada

| Contrato | Evidência | Estado |
| --- | --- | --- |
| `POST /auth/login` autentica e devolve access/refresh tokens e usuário público | [`auth.py`](../../api/app/auth.py), [`test_auth.py`](../../api/tests/test_auth.py) | OBSERVED |
| `POST /auth/refresh` rotaciona o refresh token | [`auth.py`](../../api/app/auth.py), [`test_auth.py`](../../api/tests/test_auth.py) | OBSERVED |
| `GET /auth/me` valida access token e devolve usuário público | [`auth.py`](../../api/app/auth.py), [`test_auth.py`](../../api/tests/test_auth.py) | OBSERVED |
| Login é protegido por limitação de taxa | [`auth.py`](../../api/app/auth.py), [`test_auth.py`](../../api/tests/test_auth.py) | OBSERVED |
| Não foi observada rota `/auth/logout` ou revogação explícita de refresh token | [`auth.py`](../../api/app/auth.py) | BLOCKED |

## Estado da sessão no servidor

**TARGET** — Cada sessão mantém, em armazenamento servidor-side:

- identificador aleatório e não derivado de CPF, e-mail ou `user_id`;
- access token e sua expiração;
- refresh token atual e sua expiração;
- projeção mínima de `/auth/me` necessária ao portal;
- instante da última rotação e versão monotônica da sessão;
- `request_id` da autenticação, sem credenciais;
- sinal de revogação local/encerramento.

Tokens persistidos devem ser cifrados em repouso com chave externa ao banco e acesso restrito ao processo do BFF. O armazenamento não contém senha. A senha existe somente durante a chamada de login e é descartada imediatamente.

## Cookie

**TARGET** — O cookie carrega somente o identificador opaco da sessão e aplica:

- `Secure` e `HttpOnly` obrigatórios;
- `SameSite=Lax` por padrão; exceção exige ameaça documentada e aprovação;
- domínio host-only e `Path=/` ou caminho mais restrito possível;
- expiração igual ou menor à sessão servidor-side;
- rotação do identificador após login, renovação relevante, mudança de privilégio e suspeita de fixação;
- prefixo `__Host-` quando a topologia permitir.

Nenhum token, CPF, telefone, e-mail, papel ou identificador acadêmico entra no cookie.

## Ciclo de vida

### Login

1. O navegador envia credenciais ao endpoint Drupal protegido por TLS e CSRF.
2. O BFF valida origem e tamanho, chama `POST /auth/login` e não registra o corpo.
3. Em sucesso, cria nova sessão e descarta qualquer sessão anônima anterior.
4. Antes de liberar página autenticada, chama `GET /auth/me` ou usa a projeção assinada devolvida pelo contrato, sem ampliar papel.
5. O navegador recebe apenas o cookie opaco e resposta `no-store`.

**TARGET** — Mensagens ao usuário não distinguem CPF inexistente de senha incorreta. `429` respeita `Retry-After`. Não há repetição automática de login.

### Requisição autenticada

1. Drupal resolve a sessão pelo cookie.
2. Se o access token estiver válido, envia-o somente ao host allowlisted da API.
3. Se estiver expirado ou próximo da margem configurada, executa refresh coordenado.
4. Resposta acadêmica é minimizada e devolvida com cache privado/desligado.

### Refresh coordenado

**TARGET** — Apenas uma renovação pode ocorrer por sessão de cada vez. Requisições concorrentes aguardam o mesmo resultado. O BFF substitui access e refresh tokens atomicamente; o token antigo não volta a ser usado.

- sucesso: atualiza tokens, versão e expirações e tenta novamente a requisição original uma única vez;
- `401`, refresh inválido ou resposta incompatível: apaga tokens, encerra sessão e pede novo login;
- timeout/`503`: não expõe token e mostra indisponibilidade; não cria sessão parcial;
- repetição de `401` após refresh: encerra a sessão, sem loop.

### Logout

**TARGET** — O logout sempre invalida o registro servidor-side, expira o cookie e remove tokens do armazenamento.

**BLOCKED** — Como não há revogação remota observada, o logout não pode prometer invalidar imediatamente um refresh token já copiado fora do BFF. Uma Issue de API deve definir revogação/rotação global antes dessa garantia. Até lá, a arquitetura reduz o risco mantendo o token somente no servidor e com TTL do contrato.

### Expiração, bloqueio e remoção

**TARGET** — `401` ou usuário não retornado por `/auth/me` encerra a sessão. `403` numa rota acadêmica não destrói necessariamente a sessão: remove o acesso à ação e preserva a distinção entre autenticação e autorização. Exclusão de conta em `DELETE /auth/me` é operação destrutiva fora do escopo do portal desta etapa e requer fluxo/gate humano específico.

## CSRF, origem e redirects

- **TARGET** — Toda requisição Drupal que cause mutação exige token CSRF ligado à sessão e validação de `Origin`/`Referer` dentro da origem aprovada.
- **TARGET** — Login também recebe proteção contra login CSRF e fixação de sessão.
- **TARGET** — Métodos `GET` nunca causam mutação local ou remota.
- **TARGET** — Redirects pós-login usam destinos internos allowlisted; parâmetro de retorno não aceita URL absoluta.
- **TARGET** — O cliente HTTP não encaminha `Authorization`, cookie ou cabeçalho sensível após redirect de host.
- **TARGET** — CORS do FastAPI não substitui CSRF do portal, pois a chamada acadêmica é servidor a servidor.

## Cache e renderização

- **TARGET** — Login, refresh, `/auth/me` e toda página autenticada usam `Cache-Control: private, no-store` e são excluídos do page cache, reverse proxy e CDN.
- **TARGET** — Variação por cookie não torna seguro um cache compartilhado; conteúdo autenticado não é cacheado.
- **TARGET** — Twig/HTML não recebe tokens. JavaScript não lê sessão TDS.
- **TARGET** — Mensagens de erro não incluem corpo bruto da API, stack trace, credencial ou identificador sensível.

## Logs, analytics e suporte

É permitido registrar: horário, `request_id`, operação lógica, status HTTP, duração, classificação do erro e identificador interno não reversível de sessão. É proibido registrar: senha, token, cookie, CPF, telefone, e-mail, nome completo, corpo de login, resposta acadêmica completa ou URL com dado pessoal.

**OBSERVED** — `GET /support/identity` devolve um identificador opaco/HMAC e falha com `503` quando a configuração não existe; ele é o identificador preferido para suporte. Evidência: [`support.py`](../../api/app/support.py) e [`test_support.py`](../../api/tests/test_support.py).

## Separação de contas

| Situação | Decisão |
| --- | --- |
| Participante acessa portal | Sessão TDS mediada; nenhuma conta Drupal necessária |
| Editor acessa administração Drupal | Sessão editorial Drupal; não concede dados acadêmicos |
| Mesma pessoa exerce os dois papéis | Duas autenticações e sessões logicamente separadas |
| Vínculo entre contas | BLOCKED até contrato explícito, consentimento, auditoria e regra de desvinculação |
| Identificação automática por CPF/e-mail/telefone | Proibida |

## Testes obrigatórios para a implementação

1. Token não aparece em HTML, cookie, JavaScript, URL, cache, log ou analytics.
2. Fixação de sessão falha: o identificador muda após login.
3. Duas requisições com access expirado resultam em um único refresh e rotação atômica.
4. Refresh inválido encerra sessão e não entra em loop.
5. CSRF e origem inválidos bloqueiam login e mutações antes da chamada à API.
6. Redirect externo não recebe `Authorization`.
7. `403` acadêmico não é convertido em `404` nem em dado editorial.
8. Logout local remove cookie e armazenamento servidor-side; a limitação de revogação remota fica visível na evidência técnica, não ao usuário final como falsa garantia.
9. Conta editorial isolada não acessa dados TDS sem autenticação TDS válida.
10. Respostas autenticadas não sobrevivem em cache compartilhado entre duas sessões.

Os roteiros completos estão em [`E2E_ACCEPTANCE.md`](E2E_ACCEPTANCE.md). Ativação produtiva, secrets, OAuth e permissões externas permanecem fora desta decisão e exigem gate humano.
