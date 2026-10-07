# ADR — sessão Tutor TDS no portal Drupal

Refs #161 e #162. Base auditada: `d2da096fe13dd18641aa8b557b3702622baa3b34`
(`origin/staging`), `api/app/auth.py` e `api/app/config.py`.

Status: DECISION de contrato (TARGET de implementação Drupal). Fatos da API são
OBSERVED e citados com arquivo.

## 1. Contexto

A API emite `access_token` JWT HS256 (~15 min, configurável por
`ACCESS_TOKEN_MINUTES`) e `refresh_token` opaco persistido como digest SHA-256 em
`session_tokens` (~30 dias, `REFRESH_TOKEN_DAYS`), com rotação que revoga o token
anterior (`AuthService.rotate_refresh`). O Flutter guarda tokens em storage
seguro do dispositivo; o portal Drupal não tem equivalente confiável no browser —
qualquer token acessível a JS vira alvo de XSS.

## 2. Decisão

**A sessão acadêmica do portal é uma sessão Drupal server-side que encapsula os
tokens Tutor. O browser só conhece o cookie de sessão do Drupal.**

```text
browser ── cookie de sessão Drupal (HttpOnly, Secure, SameSite) ──► Drupal/BFF
                                                                     │ servidor guarda
                                                                     │ access_token + refresh_token
                                                                     ▼
                                                          FastAPI (Bearer) ──► PostgreSQL
```

### 2.1 Regras fixas

1. **Token nunca no cliente.** Proibido persistir ou expor `access_token`,
   `refresh_token`, `identity_proof`, CPF ou hash de suporte em JS,
   `localStorage`, `sessionStorage`, cookie legível por JS, URL, fragmento,
   analytics, log ou HTML. Respostas do BFF ao browser contêm apenas dados de
   apresentação.
2. **Cookie de sessão do portal:** `HttpOnly; Secure; SameSite=Lax` (mínimo;
   `Strict` preferível onde não quebrar fluxo), `Path=/`, sem `Domain` amplo, TTL
   alinhado à sessão, rotação de ID no login/logout (proteção de fixação).
3. **Armazenamento dos tokens:** server-side, ligado à sessão autenticada do
   portal — módulo de sessão Drupal com store de backend (DB do portal ou
   equivalente) e criptografia em repouso via gerenciamento de chaves do Drupal
   (TARGET; módulo/Key concreto é decisão da Issue de implementação). Tokens
   jamais em tabela de conteúdo, cache público ou `$_SESSION` serializado em
   storage compartilhado sem criptografia.
4. **CPF/senha** existem somente na request POST de login/cadastro: browser →
   Drupal (TLS) → `POST /auth/login`/`/auth/register` (TLS). Nunca persistidos,
   logados ou reenviados a terceiros.
5. **Refresh único e serializado.** `POST /auth/refresh` revoga o token anterior;
   o BFF deve serializar refresh por sessão (lock/mutex server-side) para que
   abas concorrentes não façam replay de refresh revogado. Falha de refresh →
   destruir sessão do portal → redirecionar ao login.
6. **Logout sem endpoint de revogação (gap G1).** OBSERVED: a API não expõe
   `/auth/logout` nem revogação de `SessionToken` nesta base — a única revogação
   existente é a rotação do refresh. O portal DEVE, no logout: destruir a sessão
   Drupal, apagar os tokens do store e invalidar o cookie. O refresh token
   permanece tecnicamente válido até expirar caso tenha sido exfiltrado; aceitar
   esse limite só é permitido porque os tokens nunca saem do servidor. Revogação
   explícita fica **BLOCKED** na Issue de endpoint de logout (ver
   `ARCHITECTURE.md` §7).
7. **Conta Drupal editorial ≠ identidade acadêmica.** Papéis Drupal (autor,
   revisor, publicador, administrador técnico) administram o site e não concedem
   nada no Tutor TDS. Um editor que também é participante autentica na área
   acadêmica com suas credenciais TDS, em sessão separada do login editorial.
8. **Usuário TDS sem conta Drupal.** Participante/equipe não precisa de `users`
   Drupal. Se uma Issue futura optar por projeção técnica (`externalauth` ou
   campo de referência opaca ↔ `user.id`), ela é detalhe de sessão — não cria
   autoridade de identidade nem vínculo acadêmico.
9. **RBAC sempre na API.** O papel do token (`role` no JWT + memberships no
   servidor) decide; o portal nunca conclui permissão por conta própria, por
   cache de papel ou por presença de menu.
10. **CSRF:** como o browser fala com o Drupal por cookie de sessão, toda rota
    BFF mutante exige POST + token CSRF do Drupal e validação de `Origin`/`Referer`.
11. **Ambientes:** a sessão referencia o `environment` da API de destino; trocar
    de ambiente exige nova sessão — nunca reaproveitar tokens entre staging e
    produção.

### 2.2 Ciclo de vida

| Evento | Comportamento do portal |
|---|---|
| Login | POST credenciais ao BFF → `/auth/login` → guardar `access_token`+`refresh_token`+`expires_in`+`user` no store server-side → emitir cookie de sessão → renderizar área autenticada |
| Request autenticada | BFF injeta `Authorization: Bearer <access_token>`; nunca expõe o header ao browser |
| `401` da API | uma tentativa de refresh serializado; se `/auth/refresh` também `401`, encerrar sessão e pedir novo login |
| `403` da API | não é problema de sessão: renderizar negação, sem retry nem refresh |
| `429` da API | respeitar `Retry-After`; backoff no BFF, sem retry imediato |
| Logout | destruir sessão + apagar tokens + cookie inválido; G1 documenta que a API ainda não revoga o refresh |
| Troca de conta | encerrar sessão anterior por completo antes de autenticar outra pessoa; nenhum dado da sessão A pode vazar à sessão B |
| Expiração de sessão Drupal com tokens válidos | destruir tokens junto com a sessão; não persistir "lembrar-me" com refresh token |

### 2.3 O que OBSERVED na API sustenta esta decisão

- Tokens curtos + refresh longo e rotativo já existem (`auth.py`).
- `decode_access` valida `type=access`, roles conhecidas, `exp/iat` exigidos.
- Rate limit de login existe server-side (`consume_rate_limit`), então o BFF não
  precisa inventar proteção de credenciais — mas deve propagar `429`.
- `GET /auth/me` permite ao BFF revalidar identidade/role sem decodificar JWT no
  portal.
- `GET /support/identity` entrega a assinatura HMAC do Chatwoot já calculada no
  servidor da API — o portal apenas a repassa ao widget na página autenticada,
  `no-store` respeitado.

### 2.4 Consequências

- XSS no portal não exfiltra tokens TDS (não estão no browser).
- Revogação real de sessão depende da Issue G1; até lá, logout é "esquecer" no
  portal, não revogação na autoridade — declarado ao usuário como encerramento de
  sessão web, não revogação global.
- Escala: store de sessão deve ser apagável por usuário (direito de exclusão já
  coberto por `DELETE /auth/me` na identidade; sessões residuais do portal expiram
  com a sessão Drupal).

## 3. Alternativas rejeitadas

| Alternativa | Motivo da rejeição |
|---|---|
| Token TDS em `localStorage`/cookie JS + chamadas diretas browser→API | exfiltração por XSS; quebra a regra "sem token no JS" do epic; CORS amplo desnecessário |
| Login Drupal como identidade acadêmica (tabela de usuários do portal) | cria autoridade paralela, duplica identidade e viola "uma entidade, uma autoridade" |
| OAuth/OIDC server-to-server próprio | não existe issuer Tutor; seria backend novo — fora do contrato |
| Salvar refresh token no banco Drupal em claro | segredo persistido sem necessidade; store criptografado é o mínimo |
| Mockar `/auth/*` no portal | mock permanente proibido; endpoint ausente vira Issue |

## 4. Critérios de verificação (para a Issue de implementação)

- Inspeção de browser: zero ocorrência de token em DOM, storage, cookies legíveis
  por JS e histórico de URL.
- Teste funcional: login → área do participante → refresh transparente → logout
  → back/forward não reexibe dados autenticados.
- Teste negativo: refresh revogado/expirado → login; `403` sem loop de refresh.
- Auditoria de logs do portal: sem CPF, senha, token ou `identity_proof`.
