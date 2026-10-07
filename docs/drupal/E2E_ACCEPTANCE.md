# Aceite E2E — Portal Drupal ↔ Tutor TDS

Refs #161 e #162. Base auditada: `d2da096fe13dd18641aa8b557b3702622baa3b34`.

Este documento é o plano de aceite do milestone, não evidência de execução: o
portal Drupal ainda não existe (TARGET de implementação). Cada cenário declara o
contrato OBSERVED que o sustenta e o estado do gate. Um cenário só pode ser
marcado TESTED-STAGING/ACCEPTED quando executado em staging Drupal isolado com
dados sintéticos, por PR com SHA — nunca inferido de teste unitário.

## 1. Escopo e ambientes

- Ambiente exigido: staging Drupal isolado + staging FastAPI existente
  (`https://tutor-tds-staging.fastapicloud.dev`, Supabase `lgtphbbpgqnzduhtyate`,
  dados sintéticos — `docs/CURRENT_STATE.md`). Provisionamento do Drupal staging
  é BLOCKED (G6) até Issue de infra.
- Flags necessárias por cenário: `LEARNING_CONTEXT_ENABLED`,
  `OPERATOR_OPERATIONS_ENABLED`, `CLASS_LIFECYCLE_ENABLED`,
  `JOURNEY_TRACEABILITY_ENABLED`, `CERTIFICATE_APPROVAL_REQUIRED`,
  `CPF_ACTIVATION_REQUIRED` — defaults `false` (`api/app/config.py`); staging pode
  ativá-las, produção não.
- Produção, DNS, secrets, billing e merge: HUMAN-GATE. `MERGE_ALLOWED=NO` para
  agentes.

## 2. Jornada participante

```text
login web → listar turmas → abrir contexto permitido → visualizar
certificado/referência → abrir suporte Chatwoot → logout → sessão/tokens
invalidados no portal
```

| # | Passo | Contrato OBSERVED | Gate E2E |
|---|---|---|---|
| P1 | Login com CPF/senha por formulário do portal | `POST /auth/login` (`test_auth`); tokens ficam server-side (`AUTH_SESSION_DECISION.md`) | cookie HttpOnly emitido; token ausente de DOM/storage/JS |
| P2 | Listar minhas turmas | `GET /classes?enrolled_only=true` (`test_classrooms`, `test_context_access_revocation`) | somente turmas com vínculo ativo; vazio renderiza estado vazio |
| P3 | Abrir contexto/edição da turma | `GET /classes/{id}/learning-context` (flag) + `GET /classes/{id}/course` (`test_learning_context`, `test_classroom_course_versions`) | snapshot da `CourseVersion` fixada; 403 de alheio bloqueia tela |
| P4 | Ver certificado/referência | `GET /certificates` (`test_certificates`); link abre `verification_url` oficial | referência oficial renderizada; candidatos `is_candidate` nunca exibidos |
| P5 | Pedir certificado (fluxo opcional) | `GET /certificate-requests/contexts` → `POST /certificate-requests` → `GET /certificate-requests` (`test_certificate_requests`) | pedido criado/reutilizado com `revision`; elegibilidade exibida como veio da API |
| P6 | Abrir suporte | `GET /support/identity` (`test_support`) + widget Chatwoot | `identifier`+hash repassados ao widget; `503` → fallback de contato; nada de CPF/token no widget |
| P7 | Logout | sessão Drupal destruída + tokens descartados (`AUTH_SESSION_DECISION.md` §2.2) | back/forward não reexibe área autenticada; nova request → login |
| P8 | Revogação server-side do refresh no logout | — | **BLOCKED (G1)**: sem `/auth/logout`; aceite parcial = sessão portal invalidada; revogação na autoridade aguarda Issue própria |

## 3. Jornada operador/coordenador

```text
login → listar scopes autorizados → localizar pessoa → inspect →
executar comando idempotente permitido → confirmar estado →
abrir suporte/contexto sem expor PII
```

| # | Passo | Contrato OBSERVED | Gate E2E |
|---|---|---|---|
| O1 | Listar scopes | `GET /operations/scopes` (flag) | só turmas do escopo, com edição fixada |
| O2 | Buscar pessoa | `POST /operations/{class_id}/search` | nome restrito ao programa; CPF exato fora do programa devolve `identity_proof` de 10 min |
| O3 | Inspecionar | `POST /operations/{class_id}/inspect` | fora do programa exige `identity_proof` válida; inválida → 403 |
| O4 | Comando permitido | `POST /operations/{class_id}/commands` `register/enroll/assign` | recibo + snapshot confirmados na resposta |
| O5 | Replay idêntico | mesmo `id`+payload | mesma resposta, sem efeito duplo |
| O6 | Replay divergente / CAS stale | mesmo `id` com corpo ou `expected_revision` divergente | `409` e nenhuma escrita parcial |
| O7 | Revogar vínculo | `action=revoke` com motivo | estado `inactive` confirmado em novo `inspect`; histórico preserva ator/motivo |
| O8 | Sem PII indevida | resposta contém `id/name`/flags/histórico | telas e logs do portal sem CPF/telefone/baseline |
| O9 | Lifecycle territorial (opcional no incremento) | `/operations/classes*` (flag `CLASS_LIFECYCLE_ENABLED`) | criar `planned` → plan/team → `active` → readiness com `open_sessions` bloqueando `closed` → `closed` após fechar sessões |

## 4. Jornada pública

```text
home/editorial → catálogo FastAPI → curso publicado → verificação de
certificado → suporte público/fallback
```

| # | Passo | Contrato OBSERVED | Gate E2E |
|---|---|---|---|
| PU1 | Home/editorial | conteúdo Drupal (TARGET) | página publicável por editor sem deploy; sem PII no HTML |
| PU2 | Catálogo | `GET /public/courses` | somente cursos published+active; campos fora da allowlist ausentes |
| PU3 | Página de curso | `GET /public/courses/{slug}` | 404 amigável para slug inexistente |
| PU4 | Verificar certificado | encaminho ao verificador oficial (`verification_url`; `certificates.py::_verify_public_certificate` é consumo server-side equivalente) | código válido → documento oficial; inexistente → negativa do verificador; Drupal não implementa verificação própria |
| PU5 | Suporte público | widget/Chatwoot anônimo ou contato institucional | sem identidade acadêmica exigida; nenhuma promessa de SLA não aprovada |
| PU6 | Programa/materiais públicos | — | **BLOCKED (G2)**: `/public/program`, `/public/materials` inexistem; portal mostra seção vazia/omite, nunca placeholder inventado |

## 5. Falhas obrigatórias

| # | Cenário | Comportamento exigido do portal | Contrato/base |
|---|---|---|---|
| F1 | API offline/timeout | "indisponível temporariamente"; nenhum estado acadêmico local; retry só em GET/idempotente | regra transversal `INTEROPERABILITY.md` §12/§14 |
| F2 | Access token expirado | um refresh serializado no BFF; falha → login | `POST /auth/refresh` OBSERVED |
| F3 | Refresh expirado/revogado | encerrar sessão portal → login; sem loop | `rotate_refresh` → 401 OBSERVED |
| F4 | Usuário sem permissão | `403` renderizado como negação; menu/ação não reaparece por cache | RBAC OBSERVED por endpoint |
| F5 | Replay divergente de comando | `409` → reconsultar `inspect`/estado antes de reenviar | `OperatorCommandReceipt`/`ClassroomCommandReceipt` OBSERVED |
| F6 | Outro programa/turma | `403`/`404` da API; portal não contorna | `authorized`/`_staff` OBSERVED |
| F7 | Chatwoot indisponível | `503` de `/support/identity` ou widget falho → fallback de contato; conversa nunca altera jornada | `test_support`; `CHATWOOT_TDS_SUPPORT_CONTRACT.md` |
| F8 | Certificado inexistente | verificador oficial responde inválido; portal não suaviza | PU4 |
| F9 | Cache stale de catálogo | `stale-while-revalidate` admitido só no público; área autenticada nunca serve resposta de outra sessão | `public_api.py` OBSERVED |
| F10 | Logout/troca de conta | sessão A destruída antes de autenticar B; zero vazamento de dados | §2.2 de `AUTH_SESSION_DECISION.md`; revogação server-side BLOCKED (G1) |
| F11 | Cadastro duplicado/convite inválido | `409`/`403` mapeados a mensagens claras | `test_auth`, `test_auth_activation_recovery` |
| F12 | Rate limit de login | portal respeita `429`+`Retry-After`; formulário não faz retry automático | `consume_rate_limit` OBSERVED |

## 6. Critérios de aceite do milestone

1. Todos os cenários P1–P7, O1–O8, PU1–PU5 e F1–F12 executados em staging
   Drupal isolado, com contas sintéticas, e evidência por PR (SHA base/head,
   ambiente, comandos, PASS/FAIL, o que não foi testado).
2. Nenhum arquivo `cartilhas_app/**` alterado; nenhum acesso direto ao
   PostgreSQL Tutor; nenhum token em JS/localStorage — verificado por inspeção.
3. Testes Drupal unit/kernel/functional + E2E browser cobrindo autorização
   negativa e PII; erros brutos da API nunca renderizados crus.
4. Backup/restore do Drupal comprovado em staging (DB editorial + arquivos).
5. Flags dependentes documentadas no PR; nada promovido a produção.
6. BLOCKED formais: G1 (logout/revogação), G2 (`/public/program`+`/public/materials`),
   G3 (verificação pública nativa, se exigida), G4 (rate limit de registro),
   G6 (hosting Drupal). Aceite do milestone admite esses gaps como Issues
   abertas linkadas — não como mocks.

## 7. Evidência mínima por PR de implementação

```text
BASE_SHA / HEAD_SHA / branch / issue
ambiente (staging isolado) + flags ativas
cenários executados × resultado × artefato sanitizado
testes Drupal: unidade/kernel/functional/E2E (quantidade e resultado)
PII/log audit: grep/captura provando ausência de token/CPF
rollback: desativar módulo; nada escrito no núcleo
```
