# Matriz de contrato Drupal ↔ FastAPI Tutor TDS

Refs #161 e #162. Base auditada: `d2da096fe13dd18641aa8b557b3702622baa3b34`
(`origin/staging`). Toda linha OBSERVED foi conferida no arquivo-fonte citado;
TARGET descreve comportamento exigido do portal/BFF (não prova de endpoint);
BLOCKED marca dependência de Issue nova (gaps G1–G6 de `ARCHITECTURE.md` §7).

"Campos permitidos" resume o contrato Pydantic observado — o portal não envia nem
expõe campos fora do schema. "Erro/fallback" é a regra de apresentação do portal:
a API continua autoridade; o portal nunca resolve o erro com dado inventado.

Status por linha:

- **OBSERVED** — endpoint existe e foi auditado nesta base; portal pode consumir.
- **TARGET** — comportamento/endpoint desejado, ainda não implementado; exige
  Issue antes de uso.
- **BLOCKED** — dependência explicitamente ausente nesta base; proibido mockar.

## Jornada 1 — Público anônimo (editorial, catálogo, verificação)

| Endpoint | Método | Auth | Persona | Campos permitidos | Cache | Idempotência | Erro/fallback do portal | PII | Teste existente | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| `/public/courses` | GET | nenhuma | visitante | query `offset`, `limit`≤100 → `courses[]{slug,title,status,published_version_label,updated_at,summary?,cover_public_url?,public_workload_text?,public_audience_text?}`, `offset/limit/total` | API emite `Cache-Control: public, max-age=60, stale-while-revalidate=300`; portal pode cachear curto período | GET seguro | API indisponível → "indisponível temporariamente", sem matrícula/progresso fictício | nenhuma; projeção é allowlist | `api/tests/test_public_api.py` | OBSERVED |
| `/public/courses/{slug}` | GET | nenhuma | visitante | path `slug` → mesma projeção | idem | GET seguro | 404 → página "curso não encontrado" útil; falha → indisponível | nenhuma | `api/tests/test_public_api.py` | OBSERVED |
| `/version` | GET | nenhuma | visitante/operador técnico | → `api_version, schema_version, minimum_supported_app_version, environment, compatibility_verified` | no-cache recomendado no portal | GET seguro | 503 → banner técnico "API indisponível" | nenhuma | `api/tests/test_version_contract.py` | OBSERVED |
| `/live`, `/health` | GET | nenhuma | monitoramento | → `{status,...}` | sem cache | GET seguro | falha → health do portal marca dependência down | nenhuma | `api/tests/test_api.py` | OBSERVED |
| `/courses`, `/courses/{course_id}` | GET | nenhuma | (contrato Flutter) | conteúdo integral da edição publicada | — | GET seguro | portal NÃO usa como projeção editorial; conteúdo pedagógico integral não é página pública por padrão | conteúdo editorial do curso | `api/tests/test_api.py`, `api/tests/test_classroom_course_versions.py` | OBSERVED (uso no portal: TARGET restrito a página de curso autorizada; decisão de conteúdo aberto pendente) |
| `/public/program` | GET | nenhuma | visitante | — | — | — | — | — | — | BLOCKED (G2 — gap já registrado em `docs/production/PUBLIC_API_PORTAL_V1.md`) |
| `/public/materials` | GET | nenhuma | visitante | — | — | — | — | — | — | BLOCKED (G2) |
| verificação de certificado | — | nenhuma | visitante | portal encaminha/embutir o verificador oficial da `verification_url` emitida (Worker/KV); portal não recalcula hash | conforme verificador oficial | consulta read-only | verificador fora → mensagem de indisponibilidade; certificado inexistente → resposta do verificador, sem soft-success | nenhuma no portal; documento oficial expõe nome/curso/hash conforme contrato do Worker | verificação consumida server-side em `api/app/certificates.py::_verify_public_certificate`; portal não tem teste nesta base | OBSERVED como dependência externa; página Drupal nativa de verificação é BLOCKED (G3) até contrato próprio |
| conteúdo editorial (notícias, páginas, agenda, FAQ) | — | nenhuma | visitante | entidades Drupal de conteúdo | cache Drupal normal com invalidação editorial | n/a | fallback editorial local | proibidos: CPF, NIS, renda, baseline, matrícula, presença, nota, telefone, tokens (`docs/program/PORTAL_AND_CONTENT.md` §11) | n/a (Drupal) | TARGET (site editorial Drupal é entrega da implementação) |

## Jornada 2 — Participante (login web TDS → área do participante)

| Endpoint | Método | Auth | Persona | Campos permitidos | Cache | Idempotência | Erro/fallback do portal | PII | Teste existente | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| `/auth/register` | POST | pública | visitante→participante | `name, cpf, phone, password, activation_token?` → `TokenResponse{access_token, refresh_token, token_type, expires_in, user{id,name,role}}` | nenhuma | `409` duplicado não cria; retry seguro após erro | 409 → "já cadastrado"; 403 → fluxo de convite quando `CPF_ACTIVATION_REQUIRED`; 422 → validação | CPF/senha só na request; nunca persistir no portal | `api/tests/test_auth.py`, `api/tests/test_auth_activation_recovery.py` | OBSERVED; risco: rota sem rate limit próprio nesta base → throttle/captcha no formulário portal é TARGET, mitigação server-side é BLOCKED (G4) |
| `/auth/login` | POST | pública | participante/equipe | `cpf, password` → `TokenResponse` | nenhuma | login repetido cria nova sessão (válido); 429 com `Retry-After` | 401 → "credenciais inválidas"; 403 → conta não ativada; 429 → backoff do BFF | CPF/senha só na request; tokens só server-side | `api/tests/test_auth.py` | OBSERVED |
| `/auth/refresh` | POST | refresh token | participante/equipe | `refresh_token` → `TokenResponse` (rotação revoga o anterior) | nenhuma | replay do mesmo refresh após rotação → 401; BFF serializa refresh por sessão | 401 → encerrar sessão portal → login | refresh token server-side apenas | `api/tests/test_auth.py` | OBSERVED |
| `/auth/me` | GET | Bearer | participante/equipe | → `PublicUser{id,name,role}` | no-store no portal | GET seguro | 401 → refresh→login; 403 não aplicável | `name` é PII mínima exibida | `api/tests/test_auth.py` | OBSERVED |
| `DELETE /auth/me` | DELETE | Bearer role `student` | participante | sem body → 204 | nenhuma | 204 idempotente; 409 quando vínculo de equipe | 409 → orientar atendimento à equipe TDS; **após `204`, o BFF destrói imediatamente a sessão Drupal, apaga access/refresh do store e invalida o cookie — proibido back/forward/reuso ou apenas aguardar a sessão expirar** | apaga PII transacional do estudante na autoridade (`User`+`SessionToken` removidos; Bearer seguinte → `401` em `access_claims`) | `api/tests/test_auth.py` | OBSERVED (portal: expor como "excluir conta" é TARGET de UX, confirmando por reautenticação; encerramento imediato da sessão é obrigatório) |
| logout | — | — | participante/equipe | — | — | — | portal destrói sessão Drupal e descarta tokens | — | — | BLOCKED (G1: API não revoga `SessionToken`; Issue de `/auth/logout` necessária para invalidação server-side) |
| `/classes?enrolled_only=true` | GET | Bearer | participante | → `ClassroomPage{classes[]}` com `id, program_id, course_id, course_version_id, teacher_id, name, offer_municipality, offer_location, start_date, end_date, status` | cache por sessão, curto; revalidar após mutação conhecida | GET seguro | 401 → refresh; lista vazia ≠ erro | IDs de programa/curso/turma; sem lista de participantes | `api/tests/test_classrooms.py`, `api/tests/test_context_access_revocation.py` | OBSERVED |
| `/classes/{class_id}/course` | GET | Bearer | participante (aluno ativo) | path `class_id` → snapshot `CourseVersion` fixada + `course_version_id, version_number, class_id` | por sessão; snapshot imutável por versão | GET seguro | 403 → "sem vínculo"; 409 → edição sob conferência | conteúdo pedagógico do aluno | `api/tests/test_classroom_course_versions.py`, `api/tests/test_context_access_revocation.py` | OBSERVED |
| `/classes/{class_id}/learning-context` | GET | Bearer + `LEARNING_CONTEXT_ENABLED` | participante | path `class_id` → `LearningContextSnapshot` (`context{user_id…permissions}`, `progress`, `resolved_at`, `contract_version=cohort-enrollment-v2`) | por sessão, revalidar a cada abertura de jornada | GET seguro | 404 → flag off/ambiente; 403 → vínculo inativo; 409 → reconciliação pendente | contexto do próprio usuário | `api/tests/test_learning_context.py`, `api/tests/test_context_golden_path.py` | OBSERVED (consumo pelo portal: TARGET; depende da flag ativa no ambiente de destino) |
| `/certificates` | GET | Bearer role `student` | participante | → `certificates[]{id,user_id,program_id,course_id,class_id,holder_name,course_title,institution_name,planned_hours,issued_at,verification_url,content_hash}` | por sessão | GET seguro | lista vazia ≠ erro; 401 → refresh | `holder_name`, instituição: PII mínima do próprio titular | `api/tests/test_certificates.py` | OBSERVED |
| `/certificate-requests` | POST | Bearer | participante | `{enrollment_id, course_version_id, class_id?}` → view do pedido (`status, revision, eligibility{}`); `201` novo / `200` pedido existente mesmo contexto / `409` contexto divergente | nenhuma | unicidade por (enrollment_id, course_version_id); replay retorna existente | 404 → matrícula inexistente; 422 → edição/contexto inválido; 409 → recarregar | pedido carrega `holder_name` do próprio | `api/tests/test_certificate_requests.py`, `api/tests/test_certificate_approval_gate.py` | OBSERVED |
| `/certificate-requests` | GET | Bearer | participante | → `requests[]` próprios com `status, revision, eligibility, requested_at, reviewed_at, review_reason` | por sessão | GET seguro | vazio ≠ erro | dados do próprio | `api/tests/test_certificate_requests.py` | OBSERVED |
| `/certificate-requests/contexts?course_id&course_version_id` | GET | Bearer | participante | → `contexts[]{enrollment_id, program_name, class_id, class_name, course_version_id, course_title, eligibility{required_seconds,validated_seconds,completed,eligible}}` | por sessão | GET seguro | vazio → sem contexto elegível | nomes de programa/turma do próprio | `api/tests/test_certificate_requests.py` | OBSERVED |
| `/certificate-requests/{id}` | GET | Bearer | autor ou revisor | → view do pedido | por sessão | GET seguro | 404 quando sem visibilidade | próprio | `api/tests/test_certificate_requests.py` | OBSERVED |
| `/certificate-requests/{id}/resubmit` | POST | Bearer | autor | `{expected_revision}` → pedido volta a `pending` | nenhuma | CAS por `expected_revision`; 409 stale | 403 → só o autor; 409 → revisão divergente | próprio | `api/tests/test_certificate_requests.py` | OBSERVED |
| `/certificates/references` | POST | Bearer role `student` | participante | `{id, program_id, course_id, class_id?, issued_at(tz), verification_url, content_hash}` → referência oficial; API confere o documento no verificador | nenhuma | replay idêntico → `200`; código divergente → `409` | 422 → URL fora do prefixo/elegibilidade insuficiente/aprovação ausente; 503 → verificador indisponível (retry depois) | `holder_name`; nunca enviar hash de documento alheio | `api/tests/test_certificates.py`, `api/tests/test_certificate_reference_context.py` | OBSERVED (emissão autenticada fim-a-fim é TARGET da fatia Certificates, fora deste portal) |
| `/support/identity` | GET | Bearer | participante autenticado | → `{identifier, identifier_hash}` para widget Chatwoot; `Cache-Control: no-store` | proibido cache; `no-store` ponta a ponta BFF→browser | GET seguro | 503 → suporte indisponível → ocultar widget/mostrar contato alternativo | `identifier` opaco `namespace:user_id`; `identifier_hash` é assinatura HMAC do widget, **não token TDS** — entrega efêmera ao runtime do widget autenticado (`AUTH_SESSION_DECISION.md` regra 12), nunca em storage, URL, log, analytics ou HTML estático | `api/tests/test_support.py` | OBSERVED |

## Jornada 3 — Operador / coordenador (área operacional do portal)

Pré-condição OBSERVED: flags `OPERATOR_OPERATIONS_ENABLED` e
`CLASS_LIFECYCLE_ENABLED` ativas no ambiente (ambas `false` por padrão e rotas
respondem `404` desligadas). Autorização é por `ProgramMembership` ativa
(`program_operator`, `coordinator`, `admin`) — admin global sem vínculo não passa
(`api/app/operator_operations.py::authorized`).

| Endpoint | Método | Auth | Persona | Campos permitidos | Cache | Idempotência | Erro/fallback do portal | PII | Teste existente | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| `/operations/scopes` | GET | Bearer | operador/coord. | → `scopes[]{institution_id, program_id, course_id, class_id, version_id, label}` (máx. 100) | por sessão; revalidar a cada comando | GET seguro | 404 → feature off; vazio → sem escopo | nomes de programa/turma | `api/tests/test_operator_operations.py` | OBSERVED |
| `/operations/{class_id}/search` | POST | Bearer escopado | operador/coord. | `{query}`: nome (no programa) ou CPF de 11 dígitos (exato) → `people[]{id, name, identity_proof}` | nenhuma | POST de leitura; seguro repetir | 403 → fora do escopo; 404 → turma/flag | `name` + prova assinada 10 min; CPF só na query | `api/tests/test_operator_operations.py`, `api/tests/test_operator_postgres.py` | OBSERVED |
| `/operations/{class_id}/inspect` | POST | Bearer escopado | operador/coord. | `{person_id, identity_proof?}` → pessoa, `scope`, `revision`, `enrolled`, `assigned`, `baseline_linked`, `history[]` | nenhuma | leitura | 403 → prova necessária/inválida; 404 → pessoa | dados mínimos de vínculo; histórico sem PII extra | `api/tests/test_operator_operations.py` | OBSERVED |
| `/operations/{class_id}/commands` | POST | Bearer escopado | operador/coord. | `{id, action∈register|enroll|assign|revoke, reason, institution_id, program_id, course_id, version_id, person_id?, expected_revision?, identity_proof?, registration?}` → snapshot + `history` | nenhuma | `id` é chave; replay idêntico → mesmo recibo; divergente → `409`; CAS por `expected_revision` | 409 → reconsultar (`inspect`) antes de reenviar; 422 → payload inválido | `registration` carrega CPF/senha somente na request; recibo guarda hash HMAC | `api/tests/test_operator_operations.py`, `api/tests/test_operator_postgres.py` | OBSERVED |
| `/operations/classes/options` | GET | Bearer | operador/coord. | → opções de preparo (programas/cursos/professores elegíveis) | por sessão | GET seguro | 404 → flag off | nomes de catálogo/programa | `api/tests/test_class_lifecycle.py` | OBSERVED |
| `/operations/classes/team-candidates?program_id=…` | GET | Bearer escopado | operador/coord. | → `user_id, display_name, role` (teacher/monitor) | por sessão | GET seguro | 403 → sem escopo | display_name mínimo | `api/tests/test_class_lifecycle.py` | OBSERVED |
| `/operations/classes` | GET | Bearer | operador/coord.; professor só a própria turma | → turmas do escopo | por sessão | GET seguro | 404 → flag off | nomes de turma | `api/tests/test_class_lifecycle.py`, `api/tests/test_class_lifecycle_postgres.py` | OBSERVED |
| `/operations/classes` | POST | Bearer escopado | operador/coord. | `PrepareClassCommand{id, reason, institution_id, program_id, course_id, teacher_id, monitor_ids[], name, offer_municipality, offer_location, start_date, end_date}` → turma `planned` | nenhuma | `id`+receipt `ClassroomCommandReceipt` | 404 flag off; 409 → contexto divergente; 422 validação | município/local da oferta ≠ residência do participante | `api/tests/test_class_lifecycle.py` | OBSERVED |
| `/operations/classes/{id}/plan` | POST | Bearer escopado | operador/coord. (em `planned`) | `PlanClassCommand` (ScopedClassCommand + campos de plano) | nenhuma | idempotency `id` + `expected_revision` CAS | 409 → revisão/contexto divergente | mesmas do plano | `api/tests/test_class_lifecycle.py` | OBSERVED |
| `/operations/classes/{id}/team` | POST | Bearer escopado | coord. (pós-ativação); operador em `planned` | `TeamClassCommand{…, teacher_id, monitor_ids[]}` | nenhuma | idem | 409/403 conforme papel/estado | IDs de equipe | `api/tests/test_class_lifecycle.py` | OBSERVED |
| `/operations/classes/{id}/transition` | POST | Bearer escopado | coordenação | `TransitionClassCommand{…, target_status∈active|closed}` | nenhuma | idem; sessão aberta bloqueia `active→closed` com `409` (`close_open_session_policy=BLOCK_CLOSE_WITH_OPEN_SESSION`) | 409 → sessão aberta/revisão divergente | — | `api/tests/test_class_lifecycle.py`, `api/tests/test_class_lifecycle_postgres.py` | OBSERVED |
| `/operations/classes/{id}/readiness` | GET | Bearer escopado | equipe autorizada (professor: própria turma) | → readiness com `closure_warnings`, `closure_blockers`, `can_close` | por sessão | GET seguro | 404 flag off | contagens, sem narrativa | `api/tests/test_class_lifecycle.py` | OBSERVED |

## Jornada 4 — Equipe de turma no portal (professor/monitor/coordenador)

| Endpoint | Método | Auth | Persona | Campos permitidos | Cache | Idempotência | Erro/fallback do portal | PII | Teste existente | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| `/classes` | GET | Bearer | professor/monitor | turmas onde leciona/monitora/estuda (escopo por vínculo) | por sessão | GET seguro | vazio ≠ erro | nomes de turma | `api/tests/test_classrooms.py` | OBSERVED |
| `/classes/{class_id}` | GET | Bearer | equipe da turma | `ClassroomDetail{…, student_ids[], monitor_ids[]}` | por sessão | GET seguro | 403 → fora da equipe; 404 → turma | IDs de participantes — não exibir como lista pública | `api/tests/test_classrooms.py` | OBSERVED |
| `/classes/{class_id}/dashboard` | GET | Bearer | teacher/admin (monitor: 403) | `ClassroomDashboard{classroom, generated_at, expected_progress_percent, summary{}, students[]{user_id,name,enrollment_id,context_enrollment_id,status,planned_hours,validated_hours,progress_percent,last_activity_at,inactive_days,alerts[],baseline_linked,confirmed_sessions,open_mentorship_cases}}` | por sessão | GET seguro | 403 → monitor/ocasional; 409 → oferta inconsistente | `name` + métricas por aluno: PII funcional, tela restrita | `api/tests/test_classroom_followup_dashboard.py`, `api/tests/test_classrooms.py` | OBSERVED |
| `/classes/{class_id}/monitor-exceptions` | GET | Bearer | equipe incl. monitor | `MonitorExceptionsResponse{generated_at,total_students,attention_students,students[]{user_id,name,alerts[]}}` | por sessão | GET seguro | 403 → fora da equipe | `name` + alertas mínimos | `api/tests/test_classroom_followup_dashboard.py` | OBSERVED |
| `/classes/{class_id}/students/{user_id}/learning-context` | GET | Bearer + flag | equipe observando aluno | mesma projeção do contexto próprio | por sessão | GET seguro | 403/404/409 conforme vínculo/flag | contexto de terceiro — uso restrito a equipe | `api/tests/test_learning_context.py` | OBSERVED |
| `/classes/{class_id}/eligible-students` | GET | Bearer | teacher/admin | `q`, `offset`, `limit`≤50 → `students[]{user_id,name}`, `next_offset` | nenhuma | GET seguro | 403 → monitor; 409 → turma fechada | nomes de elegíveis — busca restrita à oferta | `api/tests/test_classrooms.py` | OBSERVED |
| `/classes/{class_id}/students/{user_id}` | PUT | Bearer | teacher/admin | path apenas → `{class_id,user_id,status}` | nenhuma | idempotente por estado (`200` já ativo); capacidade 30 sem bypass; `closed` → 409 | 403 → papel; 409 → turma fechada/capacidade; 422 → sem matrícula ativa | IDs | `api/tests/test_classrooms.py`, `api/tests/test_context_access_revocation.py` | OBSERVED |
| `/classes/{class_id}/journey-export` | GET | Bearer + `JOURNEY_TRACEABILITY_ENABLED` | equipe autorizada | `limit`≤100, `offset` → `contract=tds-journey-v1`, `items[]`/`pending[]` pseudonimizados | nenhuma (analítico) | GET seguro | 404 → flag off; 403 → fora do escopo | `pessoa_id` é pseudônimo HMAC — ainda dado pessoal | `api/tests/test_journey_traceability.py`, `api/tests/test_journey_export_tools.py` | OBSERVED (uso no portal: TARGET restrito a painel autorizado; não é superfície pública) |
| `/classes/{class_id}/journey-activity` | GET | Bearer + flag | equipe autorizada | `limit`≤500, `offset`, `since/until`(tz) → `contract=tds-activity-v1`, `items[]{event_id,pessoa_id,evento,alvo_tipo,alvo_id,ocorreu_em,segundos_tela,escopo,atribuicao_turma:null}` | nenhuma | dedup por `event_id` obrigatório no consumidor | 422 → janela inválida; demais idem | pseudônimo + eventos de uso | `api/tests/test_journey_traceability.py` | OBSERVED (mesmo TARGET condicional) |

## Jornada 5 — Administração institucional (`/admin/*`, fora do MVP do portal)

OBSERVED na base (`api/app/organizations.py`, `api/app/classrooms.py` admin
router). Todas exigem `role=admin` global no token — superfície de backoffice, não
de operador escopado. Para o portal, consumo é **TARGET/adiado**: a epic #161
cobre operador/coordenador; painel admin completo exige Issue própria.

| Endpoint | Método | Auth | Persona | Campos permitidos | Cache | Idempotência | Erro/fallback do portal | PII | Teste existente | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| `/admin/institutions` | POST | Bearer role `admin` | admin | `{name}` → `{id,name}`; `409` duplicada | nenhuma | `409` existente | 409 → "já cadastrada" | nome institucional | `api/tests/test_organizations.py` | OBSERVED (portal: TARGET adiado) |
| `/admin/programs` | POST | admin | admin | `{institution_id,name}` → `{id,institution_id,name}`; `404` instituição; `409` duplicado | nenhuma | `409` existente | idem | nomes | `api/tests/test_organizations.py` | OBSERVED (idem) |
| `/admin/programs/{id}/courses/{course_id}` | POST | admin | admin | path apenas → `{program_id,course_id}`; `409` já ofertado | nenhuma | `409` existente | idem | — | `api/tests/test_organizations.py` | OBSERVED (idem) |
| `/admin/programs/{id}/courses/{course_id}/workload` | PUT | admin | admin | `{planned_hours>0,≤10000}` → `planned_hours` | nenhuma | PUT de estado; reenvio idêntico converge | 404 → oferta inexistente | — | `api/tests/test_organizations.py` | OBSERVED (idem) |
| `/admin/programs/{id}/memberships` | POST | admin | admin | `{user_id,role∈ProgramRole}` → membership `active`; `409` existente | nenhuma | `409` existente | 404 → programa/usuário | `user_id` | `api/tests/test_organizations.py` | OBSERVED (idem) |
| `/admin/accounts` | POST | admin | admin | `{name,cpf,phone,password,role,program_id}` → conta+membership atômicos | nenhuma | `409` CPF já cadastrado | 404 → programa; 409 → conflito | CPF/senha só na request | `api/tests/test_organizations.py`, `api/tests/test_auth.py` | OBSERVED (idem) |
| `/admin/enrollments` | POST | admin | admin | `{user_id,program_id,course_id}` → `EnrollmentResponse`; `422` sem membership/oferta; `409` matrícula existente | nenhuma | `409` existente | idem | `user_id` | `api/tests/test_organizations.py` | OBSERVED (idem) |
| `/admin/hierarchy` | GET | admin | admin | `institution_id?` → árvore instituição→programas→memberships | por sessão | GET seguro | vazio → sem instituições | `user_id`+roles | `api/tests/test_organizations.py` | OBSERVED (idem) |
| `/admin/classes` | POST | admin | admin | `ClassroomCreate{program_id,course_id,teacher_id,name,offer_municipality?,offer_location?,start_date,end_date,status}`; com `CLASS_LIFECYCLE_ENABLED` status deve ser `planned` | nenhuma | `409` integridade | 422 → oferta/vínculo de professor inválido; 409 → curso sem versão publicada | `teacher_id` | `api/tests/test_classrooms.py`, `api/tests/test_class_lifecycle.py` | OBSERVED (idem) |
| `/admin/classes/{id}/students/{uid}` | POST | admin | admin | path apenas → `{class_id,user_id,status}`; `409` já na turma; `422` sem matrícula; `409` turma fechada/capacidade | nenhuma | `409` já incluído | idem | `user_id` | `api/tests/test_classrooms.py` | OBSERVED (idem) |
| `/admin/classes/{id}/monitors/{uid}` | POST | admin | admin | path apenas → `{class_id,user_id}`; com flag, só em `planned` | nenhuma | `409` já monitor | 422 → monitor sem vínculo; 409 → pós-ativação/duplicado | `user_id` | `api/tests/test_classrooms.py` | OBSERVED (idem) |
| `/auth/activation-invites` | POST | admin | admin | `{cpf,expires_in_hours 1–168}` → `{activation_token,expires_in_hours}` | nenhuma | cada emissão cria token novo | 401/403 → não admin | CPF só na request; token exibido uma vez | `api/tests/test_auth_activation_recovery.py` | OBSERVED (idem) |

## Regras transversais do portal (TARGET)

1. **Auth:** sempre `Authorization: Bearer` injetado pelo BFF; nunca bearer no
   browser (ver `AUTH_SESSION_DECISION.md`).
2. **Cache:** respeitar `Cache-Control` da API; autenticado = por sessão e
   no-store quando a API disser `no-store` (`/support/identity`); nunca cache
   público de rota autenticada.
3. **Idempotência:** comandos sempre com `id` único gerado pelo BFF + contexto
   completo + `expected_revision` quando o contrato exigir; `409` de replay
   divergente/CAS → reconsultar antes de reenviar, nunca reenviar cego.
4. **Erro/fallback:** `401`→refresh→login; `403`→negação explícita; `404`→recurso
   ou flag ausente; `422`→validação; `429`→`Retry-After`; `5xx`/timeout→"indisponível
   temporariamente"; API offline nunca é respondida com estado acadêmico local.
5. **PII:** mínimo necessário por tela; proibido CPF, telefone, tokens,
   `identity_proof` e transcrição de atendimento em HTML, JS, log, analytics ou
   URL; pseudônimos HMAC continuam dado pessoal (`INTEROPERABILITY.md` §7).
6. **Endpoints ausentes** (`/auth/logout`, `/public/program`,
   `/public/materials`, verificação pública nativa, rate limit de registro) estão
   em `ARCHITECTURE.md` §7 — **BLOCKED**, cada um com Issue própria; mock
   permanente é proibido.
