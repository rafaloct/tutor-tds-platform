# Drupal ↔ Tutor TDS — arquitetura e ADR do contrato de integração

Refs #161 (epic) e #162 (este contrato). Base auditada: `d2da096fe13dd18641aa8b557b3702622baa3b34`
(`origin/staging`). Este documento é DECISION/TARGET de contrato; nada aqui declara
runtime Drupal implementado. O que existe no código está marcado OBSERVED com a
fonte; o que é desenho está marcado TARGET; o que depende de trabalho ou decisão
externa está marcado BLOCKED.

Linguagem de status segue `docs/program/AGENT_EXECUTION_PLAYBOOK.md` §18; a matriz
da Issue #162 usa OBSERVED/TARGET/BLOCKED.

## 1. Contexto

O epic #161 pede um portal Drupal que consuma o núcleo Tutor TDS sem modificar o
Flutter e sem criar um segundo backend acadêmico. O histórico WordPress
(`docs/portal/`, `docs/program/PORTAL_AND_CONTENT.md`) prova apenas conteúdo
editorial e a projeção pública `/public/courses*`; permanece como
alternativa/histórico até prova técnica do Drupal, por decisão registrada no epic.

## 2. Decisão

```text
Participante ── browser ──► Drupal (web/CMS/BFF) ── HTTPS JSON ──► FastAPI Tutor TDS ──► PostgreSQL
                                │                                     │
                                ├── DB Drupal: conteúdo editorial,    ├── autoridade acadêmica,
                                │   configuração web, sessão portal   │   transacional e auditoria
                                └── tokens TDS: server-side apenas    └── RBAC/idempotência por request
Flutter ────────────────────────────────────────────────────────────► FastAPI (inalterado)
Chatwoot ── conversa/suporte; verificação pública de certificado segue a URL oficial emitida
```

Decisões fixadas por esta ADR:

1. **Drupal é web/CMS/BFF, não autoridade acadêmica.** Não decide matrícula,
   presença, progresso, certificado, capacitação, elegibilidade ou autorização.
   Toda decisão sensível é do FastAPI, validada por request.
2. **FastAPI/PostgreSQL é a autoridade.** O Drupal chama somente endpoints HTTP
   existentes ou aditivos futuros; nunca as tabelas.
3. **Sessão TDS é server-side no Drupal.** Access/refresh tokens vivem no
   backend do portal; o browser recebe apenas o cookie de sessão do Drupal
   (HttpOnly). Nenhum token em JS, `localStorage`, `sessionStorage`, URL,
   analytics ou log. Detalhes em `AUTH_SESSION_DECISION.md`.
4. **Contas editoriais Drupal são separadas da identidade acadêmica.** Editor,
   revisor, publicador e administrador técnico do site são contas Drupal com
   papéis editoriais, sem vínculo com `users`/matrícula do Tutor TDS.
5. **Usuário TDS não depende de conta Drupal acadêmica paralela.** Participante
   e equipe autenticam com CPF/senha contra `/auth/login` via BFF. Se um dia
   existir projeção técnica (ex.: `externalauth` Drupal ↔ `user.id`), ela é
   referência opaca de sessão, não autoridade de identidade — decisão separada.
6. **Nenhum acesso direto ao PostgreSQL Tutor.** Nem leitura. O banco do Drupal
   guarda somente conteúdo editorial, configuração e sessões do portal.
7. **Nenhum arquivo Flutter é alterado.** O app continua consumindo os mesmos
   contratos; o portal é um consumidor adicional.
8. **Endpoint ausente vira gap explícito/nova Issue, não mock permanente.**
   Onde a jornada exige contrato inexistente, este documento marca BLOCKED e
   propõe a Issue; nenhum adapter pode simular autoridade.

## 3. Responsabilidades por componente

| Componente | Pode | Não pode |
|---|---|---|
| Drupal (portal) | servir páginas/notícias; autenticar via BFF; cachear projeções públicas; renderizar dados do usuário autenticado obtidos via API; embedar widget Chatwoot; encaminhar verificação de certificado | decidir autorização acadêmica; persistir CPF/senha/tokens fora da sessão server-side; acessar PostgreSQL Tutor; emitir/validar certificado por conta própria |
| FastAPI | autorizar cada request; manter RBAC, idempotência, CAS e auditoria existentes | servir CMS; confiar em identidade declarada pelo portal |
| PostgreSQL Tutor | persistência transacional da autoridade | ser lido/escrito pelo Drupal |
| Banco Drupal | conteúdo editorial, config, sessão do portal | cadastro acadêmico, espelho de `users`/`enrollments`, PII acadêmica |
| Chatwoot | conversa/atendimento | alterar jornada acadêmica; receber CPF/tokens |
| Worker/KV de certificados | verificação pública via `verification_url` oficial | ser substituído por lógica de verificação no Drupal |

## 4. Contratos OBSERVED na base (auditoria `api/app/`)

Autenticação e identidade (`api/app/auth.py`):

- `POST /auth/register` — público; `RegisterRequest{name, cpf, phone, password,
  activation_token?}`; senha 12–128 caracteres; CPF validado e persistido só como
  digest HMAC (`cpf_pepper`); `409` duplicado; `403` quando
  `CPF_ACTIVATION_REQUIRED` e convite ausente/inválido. Sem rate limit na rota
  nesta revisão — risco registrado em `API_CONTRACT_MATRIX.md`.
- `POST /auth/login` — público; rate limit fixo por janela
  (`auth_login_attempt_limit`, default 10 por `auth_rate_limit_window_seconds`
  =900s, escopo `login` por IP+CPF normalizado, bucket em
  `auth_rate_limit_buckets`); `401` credenciais inválidas; `403` conta não
  ativada; `429` com `Retry-After`.
- `POST /auth/refresh` — público; rotação com revogação do refresh anterior
  (`SessionToken.revoked_at`); `401` inválido/expirado/revogado.
- `POST /auth/activation-invites` — `require_roles("admin")`; emite token de
  ativação por CPF, expiração 1–168h.
- `GET /auth/me` — Bearer; retorna `{id, name, role}`.
- `DELETE /auth/me` — `require_roles("student")`; remove conta e dados
  transacionais do estudante; `409` se a conta tem vínculo de equipe.
- TokenResponse: `access_token` JWT HS256 (`sub`, `role`, `type=access`, `iat`,
  `exp`; `access_token_minutes` default 15), `refresh_token` opaco persistido
  como digest SHA-256 (`refresh_token_days` default 30), `token_type=bearer`,
  `expires_in`, `user`.
- Roles de token aceitas: `student, teacher, monitor, program_operator,
  coordinator, admin` (`decode_access`).
- **Não existe endpoint de logout/revogação de sessão** — gap, ver §7.

Catálogo e público (`api/app/public_api.py`, `api/app/main.py`):

- `GET /public/courses` e `GET /public/courses/{slug}` — públicos, projeção
  read-only com `Cache-Control: public, max-age=60, stale-while-revalidate=300`;
  campos e gaps em `docs/production/PUBLIC_API_PORTAL_V1.md`.
- `GET /courses`, `GET /courses/{course_id}` — públicos; contrato Flutter,
  conteúdo completo da edição publicada. O portal não deve assumir este shape
  como projeção pública (ver `PUBLIC_API_PORTAL_V1.md`).
- `GET /live`, `GET /health`, `GET /version` — públicos; `/version` exige schema
  Alembic único e expõe `api_version`, `schema_version`,
  `minimum_supported_app_version`, `environment`, `compatibility_verified`.

Turmas e contexto (`api/app/classrooms.py`, `learning_context.py`):

- `GET /classes` — Bearer; `enrolled_only=true` limita a vínculos ativos do
  contrato contextual; escopo por papel sem expor lista de participantes.
- `GET /classes/{class_id}` — Bearer; equipe da turma (`_require_staff_access`,
  inclui monitor).
- `GET /classes/{class_id}/course` — Bearer; aluno ativo ou equipe; devolve
  snapshot da `CourseVersion` fixada, nunca a edição pública corrente.
- `GET /classes/{class_id}/dashboard` — Bearer; teacher/admin (`_require_teacher_or_admin`);
  `ClassroomDashboard` com `StudentProgress`.
- `GET /classes/{class_id}/monitor-exceptions` — Bearer; equipe incl. monitor;
  somente alertas acionáveis.
- `GET /classes/{class_id}/eligible-students` — Bearer; teacher/admin; busca por
  nome restrita à oferta da turma, paginada.
- `PUT /classes/{class_id}/students/{user_id}` — Bearer; teacher/admin; inclusão
  idempotente por estado (`200` quando já ativo), capacidade via
  `require_available_seat`, bloqueio em turma `closed`.
- `GET /classes/{class_id}/learning-context` — Bearer; próprio aluno; flag
  `LEARNING_CONTEXT_ENABLED`; contrato `cohort-enrollment-v2`.
- `GET /classes/{class_id}/students/{user_id}/learning-context` — Bearer; equipe
  (incl. monitor) observando aluno da turma; mesma flag.
- `POST /admin/classes`, `POST /admin/classes/{class_id}/students/{user_id}`,
  `POST /admin/classes/{class_id}/monitors/{user_id}` — `require_roles("admin")`.

Operações escopadas (`api/app/operator_operations.py`, flag
`OPERATOR_OPERATIONS_ENABLED`; contrato em
`docs/production/ADMIN_CONTROL_PLANE_CONTRACT.md`):

- `GET /operations/scopes` — Bearer; membership ativo `program_operator`,
  `coordinator` ou `admin` no programa; turmas com edição fixada.
- `POST /operations/{class_id}/search` — Bearer escopado; nome (programa) ou CPF
  exato; retorna `id`, `name` e `identity_proof` JWT de 10 minutos.
- `POST /operations/{class_id}/inspect` — Bearer escopado; `person_id` +
  `identity_proof` quando a pessoa não participa do programa.
- `POST /operations/{class_id}/commands` — Bearer escopado; `id` (chave de
  idempotência), `action ∈ {register, enroll, assign, revoke}`, `reason`,
  contexto completo, `expected_revision` CAS; replay idêntico devolve o recibo;
  divergente → `409`; hash HMAC do pedido em `OperatorCommandReceipt`.

Lifecycle territorial (`api/app/class_lifecycle.py`, flag
`CLASS_LIFECYCLE_ENABLED`, todas as rotas bloqueadas com `404` quando off):

- `GET /operations/classes/options`, `GET /operations/classes/team-candidates`,
  `GET /operations/classes`, `POST /operations/classes`,
  `POST /operations/classes/{id}/plan`, `POST /operations/classes/{id}/team`,
  `POST /operations/classes/{id}/transition`,
  `GET /operations/classes/{id}/readiness` — RBAC contextual
  (program_operator/coordinator; transições e equipe pós-ativação restritas à
  coordenação), idempotência por `id` + `expected_revision` + receipt
  (`ClassroomCommandReceipt`).

Certificados (`api/app/certificates.py`, `certificate_requests.py`):

- `GET /certificates` — `require_roles("student")`; referências oficiais do
  próprio usuário.
- `POST /certificates/references` — student; valida `verification_url` contra o
  prefixo configurado (`certificate_verification_url_prefix`), confere o
  documento público no verificador (Worker/KV) e a elegibilidade
  (carga/conclusão; aprovação humana quando `CERTIFICATE_APPROVAL_REQUIRED`);
  `200` em replay idêntico, `409` em conflito.
- `POST /certificate-requests`, `GET /certificate-requests`,
  `GET /certificate-requests/contexts`, `GET /certificate-requests/review-queue`,
  `GET /certificate-requests/{id}`, `POST /certificate-requests/{id}/review`,
  `POST /certificate-requests/{id}/resubmit` — Bearer; fluxo
  pending→approved/rejected com `expected_revision` CAS; revisão exige papel de
  revisor no programa/turma e nunca emite certificado.

Suporte (`api/app/support.py`):

- `GET /support/identity` — Bearer; devolve `{identifier, identifier_hash}` HMAC
  para o widget Chatwoot, `Cache-Control: no-store`; `503` quando
  `CHATWOOT_IDENTITY_SECRET`/`CHATWOOT_IDENTITY_NAMESPACE` não configurados.
  Contrato funcional em `docs/production/CHATWOOT_TDS_SUPPORT_CONTRACT.md`.

Rastreio (`api/app/journey_export.py`, flag `JOURNEY_TRACEABILITY_ENABLED`):

- `GET /classes/{class_id}/journey-export` e
  `GET /classes/{class_id}/journey-activity` — Bearer; equipe da turma;
  pseudonimização HMAC (`SHEETS_PSEUDONYM_SECRET`); `contract:
  tds-journey-v1`/`tds-activity-v1`. É superfície para equipe autorizada/BI, não
  para o portal público.

Organizações (`api/app/organizations.py`, `require_roles("admin")`):

- `POST /admin/institutions`, `POST /admin/programs`,
  `POST /admin/programs/{id}/courses/{course_id}`,
  `PUT /admin/programs/{id}/courses/{course_id}/workload`,
  `POST /admin/programs/{id}/memberships`, `POST /admin/accounts`,
  `POST /admin/enrollments`, `GET /admin/hierarchy`.

## 5. Fronteiras de segurança (TARGET salvo OBSERVED indicado)

- TLS obrigatório em browser↔Drupal e Drupal↔FastAPI.
- O browser nunca recebe `access_token`/`refresh_token`: o BFF responde somente
  HTML/JSON de apresentação. Ver `AUTH_SESSION_DECISION.md`.
- CPF e senha trafegam só browser→Drupal→FastAPI em TLS, na memória da request;
  proibidos em logs, sessão persistente, banco Drupal, analytics e URL.
- PII nas respostas é minimizada pelo que cada endpoint já devolve; o portal não
  agrega campos além do contrato nem os envia a analytics/cache público.
- CORS do FastAPI (`allowed_origins`, `allow_credentials=False`) não se aplica à
  chamada server-side do BFF; mesmo assim o portal nunca deve expor o token ao
  browser para chamada direta — a regra é de arquitetura, não de CORS.
- `identity_proof` de operador (JWT 10 min) trafega apenas em corpos HTTPS entre
  Drupal e API, nunca em URL.

## 6. Ambientes

| Ambiente | Drupal | FastAPI | Dados |
|---|---|---|---|
| Local | container/módulo em dev | `TUTOR_ENVIRONMENT=development` | sintéticos |
| Staging | instância isolada de homologação (TARGET; setup é Issue própria) | staging FastAPI Cloud + Supabase existente | sintéticos/contas QA |
| Produção | fora de escopo para agentes; HUMAN-GATE | produção existente | reais |

Nenhum compartilhamento de banco, secrets ou sessões entre ambientes.

## 7. Gaps BLOCKED registrados (cada um vira Issue própria)

| Gap | Impacto no portal | Encaminhamento |
|---|---|---|
| **G1 — sem endpoint de logout/revogação de refresh** | Logout do portal destrói a sessão Drupal e descarta tokens, mas o `SessionToken` permanece válido até expirar (default 30 dias) se exfiltrado | Issue nova: `POST /auth/logout` revogando o refresh token atual (e opcionalmente todas as sessões do usuário) |
| **G2 — `/public/program` e `/public/materials` inexistem** | Home/páginas institucionais não podem ser hidratadas pela API | Gap já registrado em `docs/production/PUBLIC_API_PORTAL_V1.md`; Issue própria quando houver metadata canônica |
| **G3 — verificação pública de certificado não é endpoint FastAPI** | A verificação ocorre no Worker/KV oficial (`verification_url`); o portal só embute/encaminha | Se o epic exigir página Drupal nativa de verificação, definir contrato público de consulta em Issue própria |
| **G4 — `/auth/register` sem rate limit na rota** | Formulário web público de cadastro amplifica brute force/enumeração | Issue própria no domínio auth (o portal mitiga parcialmente com throttle/captcha no formulário, sem substituir o servidor) |
| **G5 — sem projeção "minhas matrículas/contextos" agregada** | Área do participante precisa N chamadas (`/classes` + contexto por turma) | Aceitável no MVP; otimização é Issue aditiva, nunca endpoint que bypassa autorização por turma |
| **G6 — Drupal staging/hosting não provisionado** | Nenhuma evidência E2E é possível sem ambiente | HUMAN-GATE/infra: Issue de provisionamento, fora de `docs/drupal` |

## 8. Consequências

- Um segundo agente pode implementar o portal apenas com esta pasta +
  `docs/program/*` + contratos citados, sem chat anterior.
- Qualquer necessidade de endpoint novo deve abrir Issue na API com auth, schema,
  idempotência, testes negativos e OpenAPI coerentes (playbook §10).
- Rollback do portal = desativar módulo/rota no Drupal; nada foi escrito no
  núcleo, então não há migração reversa no Tutor TDS.

## 9. Fora de escopo (não implementar nesta epic sem Issue própria)

- SSO, login social ou unificação de identidade editorial×acadêmica.
- Admin web completo: a epic cobre operador/coordenador via `/operations*`;
  rotas `/admin/*` são admin global e ficam fora do MVP do portal.
- Webhooks Chatwoot→FastAPI, gamificação (só projeção futura da API), produção,
  DNS, secrets e qualquer escrita em `cartilhas_app/**`.

## 10. Implementacao DR-4

O modulo `drupal/web/modules/custom/tds_public_portal` implementa localmente a
superficie publica/editorial da Issue #165. O catalogo usa exclusivamente
`/public/courses*`, com allowlist de campos, cache curto isolado por ambiente e
fallback stale limitado. Drupal continua autoridade somente do conteudo
editorial. Detalhes, testes e limites estao em `DR4_PUBLIC_PORTAL.md`.

Isto nao altera os estados BLOCKED G2/G6, nao prova staging e nao autoriza
merge, DNS, analytics externo ou producao.
