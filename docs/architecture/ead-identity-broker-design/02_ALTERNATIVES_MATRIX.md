# 02 — Matriz de alternativas de vínculo

Avaliação das abordagens realistas contra os requisitos da ADR #249:
voluntário, único por ambiente, auditável, revogável, sem match por
CPF/nome/email/telefone, sem SSO caseiro.

## Alternativas

### A — Provider OIDC/OAuth2 dedicado no WordPress (TARGET ideal, hoje BLOCKED)

Fluxo OAuth2 Authorization Code + PKCE com o WP como IdP. O usuário
autentica no browser do sistema, consente, e o broker troca `code` por token.

- **Pré-requisito ausente:** nenhum provider OIDC/OAuth2 instalado no WP —
  exige plugin de terceiro (ex.: miniOrange/oauth-server), homologação de
  segurança e **instalação por humano** em staging→produção.
- **Status: UNKNOWN/BLOCKED.** Não implementável agora sem gate de provider.

### B — Dois logins + vínculo por introspecção LP (RECOMENDADO)

O usuário faz login TDS (FastAPI, já existe) e login EAD **direto no EAD**
(Flutter → `ead…/wp-json/learnpress/v1/token` via TLS, senha nunca toca o
FastAPI). Para criar o vínculo, o app envia ao broker **apenas** o JWT LP
recém-emitido; o broker verifica uma vez (`token/validate` + `users/{id}`) e
grava o par `tds↔wp`. O JWT é descartado.

- ✅ Zero plugin novo; usa só endpoints OBSERVED.
- ✅ Prova de controle das **duas** contas em janela curta.
- ✅ Credencial WP nunca persiste no TDS (só o id vinculado).
- ⚠️ Re-autenticação LP a cada 7 dias quando o JWT morre (sem refresh) —
  UX de "relogin EAD" explícito, não oculto.
- ⚠️ O broker ainda processa um JWT LP em memória — mitigado por validação
  imediata + descarte + log sanitizado.

### C — Application Password WP (fallback manual)

Usuário cria Application Password em wp-admin, cola uma vez numa tela de
consentimento; broker chama `/wp/v2/users/me` com Basic auth, vincula e
descarta.

- ❌ `wp_is_application_passwords_available()=no` no sandbox (HTTP).
- ❌ UX ruim: passos manuais no wp-admin.
- ✅ Credencial revogável por nome, auditável (last_used/last_ip no usermeta).
- **Status: fallback documentado**, não recomendado como caminho principal.

## Matriz comparativa

| Critério | A: OIDC/OAuth | **B: dois logins + introspecção** | C: App Password |
|---|---|---|---|
| Implementável hoje | ❌ plugin ausente | ✅ endpoints existem | ⚠️ degradado (HTTP) |
| Prova das 2 contas | ✅ | ✅ | ✅ |
| Consentimento explícito | ✅ tela provider | ✅ tela TDS dedicada | ✅ parcial |
| Sem segredo WP no app | ✅ | ✅ JWT LP fica no device | ⚠️ senha de app colada |
| Sem segredo WP no FastAPI | ✅ | ✅ (só JWT transitório) | ⚠️ app-password transitório |
| Revogação | ✅ | ✅ link + relogin | ✅ por app-password |
| UX de matrícula | melhor | dois logins claros | pior (manual) |
| Mobile deep-link | ✅ redirect | ✅ fluxo in-app + browser | ❌ frágil |
| Custo operacional | alto (provider) | baixo | médio |
| Risco de SSO caseiro | nenhum | nenhum (sem re-emissão WP) | nenhum |
| LGPD | consentimento provider | consentimento próprio + descarte | idem |

## Recomendação

**B** como caminho curto, mantendo **A** como evolução futura se um provider
for homologado. C permanece documentado como contingência. Nenhuma opção
autoriza SSO improvisado nem captura de senha WP no Flutter/FastAPI.
