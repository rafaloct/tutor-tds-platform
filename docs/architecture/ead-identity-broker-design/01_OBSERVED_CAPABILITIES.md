# 01 — Capacidades de autenticação OBSERVADAS

Fatos verificados em código (staging `d4039ce`) e no sandbox sintético
`dfd627` (WP 7.1.3 + LP 4.3.6 + MariaDB 10.11, `127.0.0.1:18732`, contas
100% sintéticas). Nada de produção.

## 1. FastAPI Tutor TDS (`api/app/auth.py`)

| Capacidade | OBSERVED |
|---|---|
| Login | `POST /auth/register`, `POST /auth/login` → `TokenResponse{access_token, refresh_token, token_type=bearer, expires_in}` |
| Access token | JWT **HS256**, `sub=user.id`, `iat`/`exp`, TTL `ACCESS_TOKEN_MINUTES` (default **15 min**) |
| Refresh | Opaco `token_urlsafe(48)`, **digest armazenado em DB** (`refresh_token_digest`), rotação em `POST /auth/refresh`, TTL `REFRESH_TOKEN_DAYS` (default 30d) — **revogável** |
| Roles | `require_roles()` com `sub`/`role` do JWT |
| OIDC/OAuth2/PKCE | **Não existe** — sem endpoints authorize/token de terceiros, sem callback externo |
| Vínculo externo | **Não existe** — nenhuma tabela/rota de link de identidade |

**Conclusão:** o FastAPI tem sessões curtas + refresh revogável — a metade
"TDS" do proof-of-control já existe. Falta apenas o artefato de vínculo e a
verificação do outro lado.

## 2. WordPress / LearnPress (sandbox)

| Capacidade | OBSERVED | Consequência |
|---|---|---|
| Login web | `wp-login.php` → cookie de sessão | Só browser; inútil p/ app↔API |
| Nonce REST | `wpApiSettings.nonce` (cookie auth) | Idem — não é credencial portável |
| Application Passwords | `wp_is_application_passwords_available()` → **`no`** no sandbox | Variant C degradada: em HTTP loopback o core desativa; exigiria HTTPS + revisão em prod |
| `POST /learnpress/v1/token` | user+senha → JWT `{iss, iat, nbf, exp=iat+604800(7d), data.user.id}` | Único token user-scoped disponível |
| `POST /learnpress/v1/token/validate` | `Bearer` → `{code:lp_jwt_auth_valid_token, data:{status:200, exp}}`; inválido → `{status:401}` | **Introspecção server-side existe** — broker consegue validar sem guardar o JWT |
| `token/refresh` | **404** — não existe | LP JWT expira → re-login obrigatório |
| LP JWT no WP core | `GET /wp-json/wp/v2/users/me` com Bearer LP → **401** | JWT LP **não** autentica WP core |
| IDOR LP | `users/{id}` alheio → **403** | `users/{claimed_id}` com o JWT serve de prova de posse do id |
| Logout | Não revoga JWT LP emitido (stateless) | JWT de 7d permanece válido após logout — inaceitável como sessão do app |
| Provider OIDC/OAuth2 | Nenhum plugin instalado (`plugin list`: akismet, hello, learnpress, tds-*) | Alternativa A indisponível sem instalação humana |

## 3. Contratos Flutter já publicados (PR #266, branch `agent/issue-265`)

```dart
EadSessionProof { wpUserId:int, environmentId:String, verifiedAt, expiresAt,
                  brokerVerified:bool }   // curto, do broker; NUNCA contém
                                          // senha/JWT/cookie WP
EadAccountReadSnapshot { wpUserId, environmentId, observedAt,
                  authenticatedLearnPressOrigin:bool, courses }
interface EadMyAreaReader { read(EadSessionProof) }
```

O proof espera **verificação fresca do broker** (`brokerVerified`, TTL curto,
`signOutLocally()` zera a elegibilidade local). Nenhum artefato emitido pelo
WordPress hoje preenche isso — daí a necessidade do broker.

## 4. Por que JWT-LP-7dias ≠ EadSessionProof-15min

| Propriedade | JWT LP (OBSERVED) | EadSessionProof (TARGET) |
|---|---|---|
| TTL | 7 dias fixos | ~15 min, `expiresAt` verificado |
| Emissor/audiência | LearnPress, aud=LP REST | Broker TDS, aud=reader interno |
| Conteúdo | `data.user.id` apenas | `wpUserId + environmentId + brokerVerified` |
| Revogação | nenhuma (stateless, logout não revoga) | revogável via link/tabela + flag local |
| Escopo | qualquer rota LP autenticada | somente leitura autorizada pelo broker |
| Vínculo | nenhum (é credencial bruta WP) | prova de `tds↔wp` já verificada |

Aceitar o JWT LP como proof permitiria que um token roubado de 7 dias valha
como sessão "recém-verificada" — viola `brokerVerified`, `expiresAt` e o
requisito de comprovação recente das duas contas.
