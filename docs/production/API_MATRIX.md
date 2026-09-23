# API matrix — Wave 1 aceita e Wave 2 ativa

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
| GET | /courses | público | catálogo publicado | sem body | courses[] com edição publicada | Home | CourseRepository | courses; course_versions | test_api; course_repository_test | IMPLEMENTED |
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

Rotas/editor existentes, auditados em `0081ab0`; gate integrado de publicação no
mesmo APK ainda pendente. Contrato: `DYNAMIC_LEARNING_CONTRACT.md`. Preview é local
e estático, sem endpoint novo. Os snapshots mantêm sections/messages existentes.

| Method | Path | Authentication | Permission | Request | Response | Consumer | Repository | Tables | Test | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GET | /editor/context | Bearer access_claims | ProgramMembership editorial ativa; admin legado preservado | sem body | programs com capacidade editorial | catálogo editorial | CourseEditorRepository | programs; program_memberships | test_course_editor; course_editor_repository_test | PARTIAL |
| GET | /editor/courses | Bearer access_claims | autor/equipe no programa permitido | program_id | courses editáveis com versão/revisão/permissões | catálogo editorial | CourseEditorRepository | courses; course_versions; program_courses; program_memberships | test_course_editor; course_editor_screen_test | PARTIAL |
| GET | /editor/courses/{course_id} | Bearer access_claims | escopo editorial e ownership quando exigido | course_id; version_id opcional | edição, conteúdo e permissões | editor | CourseEditorRepository | courses; course_versions; program_courses; program_memberships | test_course_editor; course_editor_repository_test | PARTIAL |
| POST | /courses | Bearer access_claims | editor ativo no programa | CourseCreate: program_id, course_id, title, author | rascunho criado | editor | CourseEditorRepository | courses; course_versions; program_courses | test_course_editor; course_editor_repository_test | PARTIAL |
| PATCH | /courses/{course_id} | Bearer access_claims | rascunho editável do autor/gestor autorizado | DraftUpdate: version_id, expected_revision, title, author, sections, links opcionais | edição/revisão atualizadas; 409 obsoleta | editor | CourseEditorRepository | courses; course_versions | test_course_editor; course_editor_repository_test | PARTIAL |
| POST | /courses/{course_id}/submit | Bearer access_claims | autor/gestor autorizado; conteúdo válido | VersionAction: version_id, expected_revision | in_review e permissões atualizadas | editor | CourseEditorRepository | course_versions; course_version_transitions | test_course_editor; course_editor_screen_test | PARTIAL |
| POST | /courses/{course_id}/publish | Bearer access_claims | coordenador/admin no escopo; compartilhamento exige todos os programas | VersionAction | published; projeção pública e histórico | editor; catálogo; app matriculado por snapshot | CourseEditorRepository; CourseRepository | courses; course_versions; course_version_transitions; program_courses | test_course_editor; test_classroom_course_versions | PARTIAL |
| POST | /courses/{course_id}/archive | Bearer access_claims | gestor autorizado | VersionAction | archived; turmas mantêm snapshot autorizado | editor | CourseEditorRepository | courses; course_versions; course_version_transitions | test_course_editor; test_classroom_course_versions | PARTIAL |
| POST | /courses/{course_id}/versions | Bearer access_claims | editor autorizado para nova edição | VersionFork: source_version_id | novo rascunho ligado à versão anterior | editor | CourseEditorRepository | course_versions | test_course_editor; course_editor_repository_test | PARTIAL |

Os comandos legados de preparação de programa/matrícula/turma continuam exigindo
admin global; sua migração não foi implicitamente declarada pelo gate editorial.
Nenhuma operação de IA ou LearningEvent cria esses vínculos.
