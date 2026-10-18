# 02 — Matriz de alternativas de vínculo (rev.2 — pós revisão de segurança)

Avaliação contra a ADR #249: voluntário, único por ambiente, auditável,
revogável, **prova recente das duas contas**, consentimento, sem match por
CPF/nome/email/telefone, **sem captura de senha WP no Flutter/FastAPI** e sem
SSO caseiro.

## Alternativas

### B0 — Dois logins separados, SEM vínculo (ÚNICO seguro hoje)

Usuário autentica TDS no app (JWT FastAPI existente) e EAD no **navegador do
sistema** (deep-link para `ead…`). Nenhum JWT/cookie/senha WP entra no
Flutter ou no FastAPI; nenhuma tabela de vínculo é criada.

- ✅ Única opção que hoje atende **todos** os requisitos da ADR.
- ✅ Zero superfície nova de autenticação.
- ❌ Não há Minha Área autenticada EAD no app — só deep-link para o site.
- **Status: IMPLEMENTÁVEL HOJE** (já é o comportamento atual).

### B1 — Broker FastAPI com proof WP recente (CONDICIONAL — BLOCKED)

Vínculo auditável `tds↔wp` que só pode existir quando o WP oferecer um
mecanismo de **confirmação recente de posse/consentimento** mediado por
browser e provider/endpoint **oficialmente auditado** — por exemplo um
Authorization Code + PKCE do próprio WP, ou fluxo de confirmação dedicado.

**Pré-requisitos ausentes (todos BLOCKED hoje):**

| Falta | Por que é necessária |
|---|---|
| Endpoint WP de consentimento recente | `token/validate` comprova validade, **não** autenticação fresca: um JWT de 6 dias roubado completaria um challenge novo |
| Provider auditável | sem ele, provar controle recente exige capturar senha WP no app — **proibido pela ADR** |
| Fluxo de consentimento browser | prova de posse voluntária, anti-phishing, origem controlada |

> ⚠️ **Revisão de segurança (PR #273):** a variante original desta alternativa
> — Flutter enviando senha EAD ao endpoint `/learnpress/v1/token` e o JWT LP ao
> broker — **viola a ADR #249** (captura de senha WP no cliente) e não prova
> frescor (JWT de 7 dias ≠ login recente). **Removida.** Checar `iat` do JWT é
> defesa parcial contra tokens velhos, **não** contra token já roubado — não
> deve ser apresentada como solução suficiente.

- **Status: BLOCKED** até decisão humana + mecanismo auditado de proof recente.

### A — Provider OIDC/OAuth2 dedicado no WordPress (TARGET ideal, BLOCKED)

Authorization Code + PKCE com o WP como IdP (plugin de terceiro homologado).

- ✅ Atende tudo, se o provider for auditado e instalado por humano.
- ❌ Nenhum provider instalado; exige plugin + homologação + instalação.
- **Status: BLOCKED** — depende de decisão + instalação humana.

### C — Application Password WP (fallback manual, degradado)

App-password criada em wp-admin, validada via `/wp/v2/users/me`, descartada.

- ❌ `wp_is_application_passwords_available()=no` no sandbox HTTP.
- ❌ UX manual fraca; senha de app ainda é credencial colada.
- **Status: fallback documentado**, não recomendado.

## Matriz comparativa

| Critério | **B0 dois logins (hoje)** | B1 broker (condicional) | A OIDC | C app-password |
|---|---|---|---|---|
| Atende ADR hoje | ✅ | ❌ falta proof recente | ❌ plugin ausente | ⚠️ degradado |
| Prova recente das 2 contas | n/a (sem vínculo) | ✅ se houver provider | ✅ | ⚠️ parcial |
| Sem senha WP no app | ✅ | ✅ por definição | ✅ | ❌ |
| Consentimento browser | n/a | ✅ requerido | ✅ | ❌ |
| Revogação | n/a | ✅ server-side por leitura | ✅ | ✅ |
| SSO caseiro | nenhum | nenhum (condicional) | nenhum | nenhum |
| Custo | zero | alto (provider+auditoria) | alto | médio |

## Recomendação rev.2

**B0 agora** — dois logins separados com sessão WP no navegador do sistema,
**sem vínculo nem verificação de identidade no Flutter**. B1 só volta à mesa
depois que existir um mecanismo WP auditado de proof/consentimento recente,
ou quando A/OIDC for homologado — ambos com **decisão humana explícita**,
pois mudariam a restrição atual da ADR.
