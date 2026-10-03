# API matrix — Wave 1 aceita e Wave 2 ativa

| Issue #5 candidate (2026-10-03) | Authorization / behavior | Evidence / limit |
| --- | --- | --- |
| POST `/certificate-requests/{id}/emission-candidate` | Owner + approved request + current canonical enrollment/edition/baseline; development opt-in only; authenticated local transport | Actual API/transport/Worker tests with simulated HTTP/KV; no installed E2E |
| POST `/certificate-requests/{id}/reconcile-candidate` | Owner/context; authenticated lookup only, no resend after timeout/absent lookup | Durable SQL reservation, one logical reference, synthetic data only |
| POST `/certificate-requests/{id}/emit` | Final issuance always blocked; institutional combined evidence unrepresented | 80h formation/exceptions, Jotform/wallet evidence and final issuer gates remain |

Protocol/persistence/activation limits: `ISSUE5_AUTHENTICATED_EMISSION_CANDIDATE.md`.

Contratos reais em FastAPI/Pydantic; OpenAPI gerado em `/openapi.json`.
Esta matriz cobre as jornadas auditadas; expandir a cada wave, sem inventar
endpoints de Pergunta ao Vivo. LearningContext real está descrito abaixo.
Status STAGING aplica-se somente ao recorte funcional da Wave 1 exercitado pelas
jornadas, não a todos os consumidores legados da rota. Resultados atuais em
`WAVE1_ACCEPTANCE.md`; nenhum endpoint recebe PRODUCTION_READY nesta etapa.

| Method | Path | Authentication | Permission | Request | Response | Consumer | Repository | Tables | Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| POST | /auth/login | CPF/senha | credenciais válidas | LoginRequest | TokenResponse | login Flutter | AuthRepository | users; sessions | test_auth | STAGING |
| POST | /auth/refresh | refresh token | sessão válida | RefreshRequest | TokenResponse | sessão Flutter | AuthRepository | sessions; users | test_auth | IMPLEMENTED |
| GET | /auth/me | Bearer | própria identidade | sem body | PublicUser (role legado) | Flutter | AuthRepository | users; sessions | test_auth | STAGING |
| GET | /courses | público | catálogo publicado | sem body | courses[] com edição publicada | Home | CourseRepository | courses; course_versions | test_api; course_repository_test | STAGING |
| GET | /courses/{course_id} | público | curso ativo | course_id | conteúdo da edição pública | leitor público | CourseRepository | courses; course_versions | test_classroom_course_versions | STAGING |
| GET | /classes | Bearer | escopo legado; enrolled_only exige vínculos ativos após correção | enrolled_only bool | ClassroomPage | Minhas turmas/equipe | ClassroomRepository | classes; cohort_memberships; class_enrollments; enrollments; program_memberships; class_monitors | test_context_access_revocation; test_classrooms | STAGING |
| GET | /classes/{class_id}/course | Bearer | _active_student ou _staff; programa ativo após correção | class_id | conteúdo snapshot + course_version_id/version_id/version_number/class_id | leitor da turma | ClassroomRepository; LearnerOfflineRepository | classes; cohort_memberships; class_enrollments; enrollments; program_memberships; course_versions | test_context_access_revocation; test_classroom_course_versions | STAGING |
| POST | /events | Bearer; flag ativa dispensa role global em atividade com turma+edição | matrícula contextual ativa; vínculo programa revalidado após correção | EventCreate: event_id, event_type, course_id, session_id, occurred_at, payload; active_seconds somente study_activity | EventResponse; 201 novo/200 retry idêntico/409 divergente | outbox | LearningEventSyncService | learning_events; enrollments; class_enrollments; classes; course_versions; program_memberships | test_course_version_events; learning_event_sync_service_test | STAGING |
| GET | /events | Bearer, student_claims | próprio usuário | paginação | EventPage | auditoria cliente | N/A, teste/consulta | learning_events | test_course_version_events | STAGING |
| GET | /classes/{class_id}/dashboard | Bearer | _staff no escopo | class_id | ClassroomDashboard com StudentProgress | professor/monitor | ClassroomRepository | classes; cohort_memberships; class_enrollments; enrollments; program_memberships; learning_events; student_baselines; session_presence; mentorship_cases | test_classroom_followup_dashboard; classroom_dashboard_screen_test | STAGING |
| GET | /classes/{class_id}/learning-context | Bearer access_claims | próprio aluno com turma/matrícula/programa ativos e flag habilitada | class_id | LearningContextSnapshot cohort-enrollment-v2 | leitor contextual | LearningContextRepository | classes; cohort_memberships; class_enrollments; enrollments; program_memberships; programs; program_courses; course_versions; learning_events | test_learning_context; test_context_golden_path; learning_context_test | STAGING |
| GET | /classes/{class_id}/students/{user_id}/learning-context | Bearer access_claims | _staff monitor=True; vínculo do aluno ativo; flag habilitada | class_id; user_id | mesma projeção do aluno | observação API; dashboard existente usa mesma função | N/A, cliente Flutter específico não necessário ao dashboard existente | mesmas tabelas do contexto próprio | test_learning_context; test_context_golden_path | STAGING |

Candidato implantado em staging gerenciado: [verificações HTTP iniciais](evidence/cloud-staging-http.json)
e [deployment com dependências fixadas](evidence/cloud-locked-deployment.json),
`b67f0921-d2c4-400d-a28e-c8832eb268fb`.
Gate Android de seis fases e isolamento HTTPS aprovados: ver
[jornadas Android](evidence/context-android-gate.json) e
[isolamento entre turmas](evidence/cloud-context-isolation.json).
Listagem e leitura revalidam vínculos; revogação canônica não recorre ao vínculo
legado. Role global permanece em GET /events e comandos legados; POST contextual
com flag ativa valida matrícula independentemente de role global.
Retry de evento já persistido continua retornando o mesmo registro após revogação,
sem criar evidência nova. Curso público continua acessível sem matrícula.

Contrato v2: context.enrollment_id é contextual; legacy_enrollment_id explicita
a linhagem. StudentProgress.enrollment_id mantém semântica legada e adiciona
context_enrollment_id. Comandos /admin/classes, inclusão de aluno/monitor e
PUT /classes/{id}/students/{user_id} gravam vínculo físico na mesma transação;
test_learning_context cobre escrita/retry e negação de equipe revogada.

## Publicação dinâmica — Wave 2A

Rotas/editor existentes; gate integrado no mesmo APK aprovado em staging conforme
`WAVE2A_ACCEPTANCE.md`. Contrato: `DYNAMIC_LEARNING_CONTRACT.md`. Preview é local
e estático, sem endpoint novo. Snapshots mantêm sections/messages existentes.
Arquivamento manual continua PARTIAL: o gate exercitou somente o arquivamento
automático da edição anterior ao publicar a seguinte.

| Method | Path | Authentication | Permission | Request | Response | Consumer | Repository | Tables | Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET | /editor/context | Bearer access_claims | ProgramMembership editorial ativa; admin legado preservado | sem body | programs com capacidade editorial | catálogo editorial | CourseEditorRepository | programs; program_memberships | test_course_editor; course_editor_repository_test | STAGING |
| GET | /editor/courses | Bearer access_claims | autor/equipe no programa permitido | program_id | courses editáveis com versão/revisão/permissões | catálogo editorial | CourseEditorRepository | courses; course_versions; program_courses; program_memberships | test_course_editor; course_editor_screen_test | STAGING |
| GET | /editor/courses/{course_id} | Bearer access_claims | escopo editorial e ownership quando exigido | course_id; version_id opcional | edição, conteúdo e permissões | editor | CourseEditorRepository | courses; course_versions; program_courses; program_memberships | test_course_editor; course_editor_repository_test | STAGING |
| POST | /courses | Bearer access_claims | editor ativo no programa | CourseCreate: program_id, course_id, title, author | rascunho criado | editor | CourseEditorRepository | courses; course_versions; program_courses | test_course_editor; course_editor_repository_test | STAGING |
| PATCH | /courses/{course_id} | Bearer access_claims | rascunho editável do autor/gestor autorizado | DraftUpdate: version_id, expected_revision, title, author, sections, links opcionais | edição/revisão atualizadas; 409 obsoleta | editor | CourseEditorRepository | courses; course_versions | test_course_editor; course_editor_repository_test | STAGING |
| POST | /courses/{course_id}/submit | Bearer access_claims | autor/gestor autorizado; conteúdo válido | VersionAction: version_id, expected_revision | in_review e permissões atualizadas | editor | CourseEditorRepository | course_versions; course_version_transitions | test_course_editor; course_editor_screen_test | STAGING |
| POST | /courses/{course_id}/publish | Bearer access_claims | coordenador/admin no escopo; compartilhamento exige todos os programas | VersionAction | published; projeção pública e histórico | editor; catálogo; app matriculado por snapshot | CourseEditorRepository; CourseRepository | courses; course_versions; course_version_transitions; program_courses | test_course_editor; test_classroom_course_versions | STAGING |
| POST | /courses/{course_id}/archive | Bearer access_claims | gestor autorizado | VersionAction | archived; turmas mantêm snapshot autorizado | editor | CourseEditorRepository | courses; course_versions; course_version_transitions | test_course_editor; test_classroom_course_versions | PARTIAL |
| POST | /courses/{course_id}/versions | Bearer access_claims | editor autorizado para nova edição | VersionFork: source_version_id | novo rascunho ligado à versão anterior | editor | CourseEditorRepository | course_versions | test_course_editor; course_editor_repository_test | STAGING |

Os comandos legados de preparação de programa/matrícula/turma continuam exigindo
admin global; sua migração não foi implicitamente declarada pelo gate editorial.
Nenhuma operação de IA ou LearningEvent cria esses vínculos.

## Identidade e jornada — QA isolado, 01/10/2026

Recorte priorizado pelo usuário; `JOURNEY_TRACEABILITY_ENABLED=false` por padrão
na API e Flutter. STAGING abaixo registra apenas QA sintético isolado, removido
após os gates; não modifica a aprovação da produção ou do BI. Contrato em
`TDS_JOURNEY_TRACEABILITY_CONTRACT.md`, evidências em `TDS_JOURNEY_QA_2026-10-01.md`.

| Method | Path | Authentication | Permission | Request | Response | Consumer | Repository | Tables | Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET | /classes/{class_id}/students/{user_id}/baseline | Bearer access_claims | equipe no escopo, aluno/vínculos ativos | class_id; user_id | baseline/histórico existentes; pessoa_id HMAC opcional com flag/segredo, inclusive sem ficha | acompanhamento Rafael | ClassroomRepository | users; class_enrollments; student_baselines; baseline_source_records; baseline_revisions | test_student_followup; test_journey_traceability; journey_baseline_control_test | STAGING |
| PUT | /classes/{class_id}/students/{user_id}/baseline | Bearer access_claims | equipe atual; confirmação humana; flag para bi_record_id | revisão esperada, data real, motivo, idempotência; bi_record_id opcional | snapshot auditado; replay exato; 409 conflito; omissão preserva ponte; null explícito desvincula com auditoria | acompanhamento Rafael | ClassroomRepository | student_baselines; baseline_source_records; baseline_revisions | test_journey_traceability; test_journey_migration; student_followup_screen_test; journey_baseline_control_test | STAGING |
| POST | /events | Bearer access_claims | conta autenticada; flag para screen_engagement; consentimento no cliente | screen_engagement com page_id estável e 1–60 active_seconds; tipos analíticos existentes | recibo idempotente; validated_seconds=0 para tempo de tela | telemetria consentida | AppTelemetryService; LearningEventSyncService; SqliteLearningOutbox | learning_events; SQLite learning_outbox existente | test_journey_traceability; screen_engagement_test; journey_privacy_preferences_test; journey_traceability_test | STAGING |
| GET | /classes/{class_id}/journey-export | Bearer access_claims | equipe da turma; flag e HMAC configurados | limit 1–100; offset | tds-journey-v1; ponte conferida/projeção canônica; pendências explícitas; sem PII; resultados não comprovados null | exportador BI | ops/export_tds_journey.py | users; class_enrollments; student_baselines; baseline_source_records; learning_events; certificate_references; program_courses | test_journey_traceability; test_journey_export_tools; journey_baseline_control_test | STAGING |
| GET | /classes/{class_id}/journey-activity | Bearer access_claims | equipe da turma; vínculos ativos; flag e HMAC configurados | since/until com timezone; limit 1–500; offset | tds-activity-v1; eventos sanitizados por pessoa, inclusive baseline pendente; sem atribuição automática de turma | exportador BI | ops/export_tds_journey.py | users; class_enrollments; learning_events; vínculos existentes | test_journey_traceability; test_journey_export_tools; journey_traceability_test | STAGING |

Migration 0020 acrescenta coluna/índice/FK em student_baselines; reusa reservas e
histórico. Guards anteriores preservados em SQLite/PostgreSQL. Rastreio e IA
não concedem matrícula, frequência, carga horária ou certificado. Alteração de
sessão invalida requests pendentes antes de aceitar tokens/respostas no Flutter.

Continuação 01/10: ensaio cec516308697 restaurou produção 0005 em banco isolado,
migrou até 0020 e conservou todas as colunas anteriores. API antiga iniciou na
cópia atualizada e retornou catálogo com mesmos valores legados. Rotas antigas
presentes no OpenAPI candidato; mudanças de schema identificadas no relatório,
sem inferir cobertura total de compatibilidade. Flags mantidas false e segredo
de pseudônimo agora mapeado para API em ambos os composes; config validada sem
deploy. Os status funcionais acima não representam promoção de produção.

Continuação Cloud: projeto staging restaurado, backup custom copiado para fora
do VPS, migration 0019→0020 com fingerprints das colunas anteriores de 42 tabelas
iguais. Deployment f060ca99-4715-4265-8466-9249329a8e1a saudável; sete contas QA
preservadas. Flag de jornada ainda false nesse staging. Dockerfile candidato
passa a instalar uv.lock, com 62 dependências conferidas e oito testes do recorte
aprovados; imagem não implantada e proveniência Git de release ainda pendente.
Evidências cloud-staging-journey-migration, cloud-staging-journey-deploy e
journey-locked-api-candidate de 2026-10-01. Nenhuma nova API ou migração central.

PDF, 01/10: o botão reutiliza POST /events (feature_used, feature_id
course_pdf_open_requested) e a exportação sanitizada existente. Teste de API
confirma recibo/replay idempotente, validated_seconds=0, exportação por equipe e
403 para aluno exportador. Nenhuma rota, armazenamento ou coluna nova. O evento
não prova download, leitura nem conclusão; course_id permanece no evento interno,
sem nova dimensão/medida adicionada ao BI. Abertura usa o link HTTPS externo do
catálogo. Contrato: COURSE_PDF_CONTRACT.md; hospedagem auditada em
evidence/course-pdf-hosting-2026-10-01.json.

Físico 01/10: oito fases do run abbdfe6c3fd54366b26c46d1d6075954 aprovadas.
Classroom recusou outra conta e a matrícula sintética revogada; cache não abriu
após revogação conhecida e nova perda de rede. A sincronização confirmou dois
eventos offline uma vez; pedido de PDF também recebido uma vez com zero crédito.
Histórico prévio preservado (332 eventos/77 registros). Sem endpoint novo ou
deploy; ver evidence/classroom-access-physical-acceptance-2026-10-01.json.
