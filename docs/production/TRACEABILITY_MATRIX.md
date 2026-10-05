# Traceability matrix

Base `fb50a57`, auditoria 2026-09-23. IDs/títulos Stitch informados pelo usuário;
screenshot e HTML Classroom inspecionados e armazenados com hashes. Nenhuma
equivalência visual foi aprovada. Composição 9731628404551462355 também inspecionada; outras telas não auditadas.
`—` significa ausente ou não verificado (nunca N/A implícito).
Derivado Home-Aluno criado e verificado por novo download de screenshot/HTML;
demais linhas sem derivado usam N/A.
Release alvo das mudanças: candidata posterior a `1.4.0+13`, ainda não definida.
Paths Flutter abaixo são relativos a `cartilhas_app/lib/`.

| Feature / Stitch screenId | Derivative | Persona | Jornada | Flutter route | Flutter screen/widget | ViewModel/controller | Domain entity | Repository | API endpoint | Database table | Permission | Analytics event | Offline policy | Test | Feature flag | Release | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Context Core / — | N/A | aluno | student_learning_path | home → classroom_course | HomeScreen; LearnerClassroomsScreen; ChatExperienceScreen | LearningContextController; State legado preservado | LearningContext cohort-enrollment-v2; User; ClassEnrollment; Enrollment; CourseVersion | LearningContextRepository real/Fake; ClassroomRepository; LearnerOfflineRepository; StudyProgressRepository | GET /classes?enrolled_only=true; GET /classes/{id}/learning-context; GET /classes/{id}/course; POST /events | users; program_memberships; classes; cohort_memberships; class_enrollments; enrollments; course_versions; learning_events | vínculo ativo; lacuna de revogação corrigida localmente | lesson_started; lesson_completed; study_activity | CACHE_READ + OFFLINE_WRITE_SYNC parcial | learning_context_test; learner_classrooms_screen_test; chat_experience_progress_test; test_context_golden_path; test_course_version_events | LEARNING_CONTEXT_ENABLED=false | candidata | STAGING |
| Persistência Context Core / N/A, migração interna | N/A | aluno/equipe | student_learning_path + instructor_observation_path | N/A, schema | N/A | LearningContextController | CohortMembership; ClassEnrollment contextual; Enrollment legado | context_memberships; LearningContextRepository | contrato v2; comandos de turma integrados | cohort_memberships; class_enrollments; enrollments | constraints; checks canônicos e legados; revogação preservada | N/A, migração não cria LearningEvent | ONLINE_ONLY operação; eventos offline preservados | test_context_memberships; test_migrations; context-physical-postgres-gate.json | LEARNING_CONTEXT_ENABLED=false padrão/true staging cloud | candidata | STAGING |
| Observação / 389e412e620c4c49841a5e9508cf6bfb — TDS Classroom - Professor | N/A | professor | instructor_observation_path | classroom_dashboard; screenshot comparado, paridade pendente | ClassroomDashboardScreen | State local | Classroom; Enrollment; LearningEvent | ClassroomRepository | GET /classes/{id}/dashboard; GET /classes/{id}/students/{user_id}/learning-context | classes; class_enrollments; enrollments; learning_events | _staff, programa ativo | page_viewed | ONLINE_ONLY | classroom_dashboard_screen_test; test_classroom_followup_dashboard; test_context_golden_path | LEARNING_CONTEXT_ENABLED=false para novo resolver | candidata | STAGING |
| Classroom integral / 389e412e620c4c49841a5e9508cf6bfb — TDS Classroom - Professor | N/A | professor/monitor | gestão por exceção e sessão; escopo posterior | classroom_dashboard; demais ações a auditar na Wave 3 | ClassroomDashboardScreen existente; composição integral pendente | State local; demais comandos a auditar | Cohort; Membership; Enrollment; Progress; ClassSession | ClassroomRepository; EvidenceRepository existentes; comandos restantes a auditar | dashboard existente; demais comandos em STITCH_CLASSROOM_COMPARISON.md | tabelas existentes; mapeamento integral pendente | equipe no escopo; ações restantes a auditar | page_viewed; demais ações a verificar | ONLINE_ONLY para acompanhamento | STITCH_CLASSROOM_COMPARISON.md; aceite integral ausente | nenhuma ativação integral | Wave 3; Pergunta ao Vivo Wave 4 | PARTIAL |
| Home contextual / 9731628404551462355 — composição, região 7 | 75ac62c1bb3241aba1b3092f908b7c5f, derivado do design system 389e412e620c4c49841a5e9508cf6bfb | aluno, inclusive identidade global de equipe | student_learning_path | home → classroom_course | HomeScreen; LearningHomeCard | LearningHomeController; LearningContextController | LearningContext; Membership; Enrollment; CourseVersion; Progress | LearnerClassroomGateway; LearningContextRepository; HomeSelectionRepository real/Fake | GET /classes?enrolled_only=true; /classes/{id}/learning-context; /classes/{id}/course | cohort_memberships; class_enrollments; course_versions; learning_events; preferência local | vínculo ativo; escolha local não autoriza | page_viewed; feature_used (contextual_home_continue); lesson_started; study_activity | CACHE_READ e outbox existente | learning_home_test; home_next_action_test | LEARNING_CONTEXT_ENABLED=false | candidata | STAGING |
| Estado de entrega / 75ac62c1bb3241aba1b3092f908b7c5f — Home Aluno | 9d6e0e93f2c448058d3f4afac70a7c4a | aluno | offline_sync_path | home; classroom_course | features/learning_events/learning_delivery_status.dart em LearningHomeCard e ChatExperienceScreen | features/learning_events/learning_delivery_controller.dart | LearningEvent; LearningContext; LearningDeliveryScope; LearningDeliverySnapshot | LearningEventQueue; LearningOutbox; SqliteLearningOutbox; LearningEventSyncService | POST /events; GET /classes/{id}/learning-context; N/A para projeção local | SQLite learning_outbox existente; learning_events; sem schema paralelo | dono + API + turma + curso + edição; estado local não autoriza | N/A, sem novos eventos | OFFLINE_WRITE_SYNC | learning_delivery_outbox_test; learning_delivery_controller_test; learning_delivery_status_test; learning_delivery_reader_test; LEARNING_DELIVERY_CONTRACT.md | DURABLE_LEARNING_OUTBOX_ENABLED=false por padrão | candidata Wave 1 | STAGING |
| 9731628404551461273 — Classroom Professor, sessão ativa | N/A, imagem importada sem HTML exportável | professor | encontro: presença, atividades, ações e encerramento | mapear na Wave 3 | screenshot inspecionado; integração ainda não auditada | — | Cohort; Membership; Progress | — | — | — | equipe da turma, a validar | — | política a definir na Wave 3 | ausente para esta composição | — | Wave 3/4 | STITCH_ONLY |
| c3f1ab69d3cc4539ba72db0e5041a81d — Ver no Conteúdo (Ponto Exato) | N/A | aluno | live_question_path → conteúdo | guided_lesson existente; ligação exata ausente | ChatExperienceScreen candidato | — | CourseVersion; ContentBlock alvo | CourseRepository existente | GET /courses/{course_id} não resolve vínculo da pergunta | course_versions | acesso à edição da pergunta, não implementado | — | — | teste específico ausente | — | Wave 4 | MISSING |
| c7a2b0ee0b1e4bb4807f3097c7098986 — Tutor IA / Dúvida ao Vivo | N/A | aluno | live_question_path → tutor | — | Tutor existente não comprova integração ao vivo | — | AIThread; LiveQuestion alvo | AnythingLlmService existente | contrato contextual ao vivo ausente | — | contexto da pergunta autorizado | — | ONLINE_ONLY alvo | ausente | — | Wave 4/6 | MISSING |
| 2eca8d72d4674a62a4edd4a9c7a29a89 — Gabarito/Pontuação | N/A | aluno | live_question_path | — | — | — | LiveQuestionResponse alvo | — | — | — | matrícula elegível | — | — | ausente | — | Wave 4 | MISSING |
| 710d78133ac5418e8a851bc4fb51e58c — Modal Pergunta ao Vivo | N/A | professor, confirmar | live_question_path | — | — | — | LiveQuestion alvo | — | — | — | equipe autorizada | — | — | ausente | — | Wave 4 | MISSING |
| 97a084d7bb0e4186881827f945a7269e — Respostas em Tempo Real | N/A | professor | live_question_path | — | — | — | LiveQuestionSession alvo | — | — | — | equipe da turma | — | ONLINE_ONLY alvo | ausente | — | Wave 4 | MISSING |
| 9a2a68ce8fbd4123936e987c8d2d738e — Visão do Aluno | N/A | aluno | live_question_path | — | — | — | LiveQuestionResponse alvo | — | — | — | matrícula elegível | — | ONLINE_ONLY alvo | ausente | — | Wave 4 | MISSING |
| 31da4ef94daf43efaf35dab2a2b239a5 — Votação Encerrada | N/A | professor | live_question_path | — | — | — | LiveQuestionSession alvo | — | — | — | equipe da turma | — | — | ausente | — | Wave 4 | MISSING |
| Outbox contextual / — | N/A | aluno | offline_sync_path | N/A, serviço | N/A, serviço | LearningEventSyncLifecycle; LearningDeliveryController | LearningEvent; LearningDeliveryScope; LearningDeliverySnapshot | LearningEventQueue; SqliteLearningOutbox; LearningEventSyncService | POST /events | learning_events; sync_log; SQLite learning_outbox | sessão autenticada; envelope local dono/ambiente; legado sem escopo preservado | tipos existentes | OFFLINE_WRITE_SYNC | learning_delivery_outbox_test; sqlite_learning_outbox_test; outbox_persistence_test; learning_event_sync_service_test; settings_logout_test; test_context_golden_path | DURABLE_LEARNING_OUTBOX_ENABLED=false; LEARNING_CONTEXT_ENABLED=false | candidata | STAGING |
| Dynamic Learning / 9731628404551462355, região 11 como referência de entrada | N/A; editor existente preservado, redesign futuro exige fonte própria | aluno/autor/coordenador | course_publication_path | course_editor_catalog; course_editor; course_editor_preview | CourseEditorCatalogScreen; CourseStructureEditor; MessageEditorDialog | State existente + CourseEditorGateway/Fake | Course; CourseVersion; sections/messages no snapshot existente | CourseEditorRepository; CourseRepository; repositories de contexto | /editor/context; /editor/courses; /courses/{id}/publish e matriz Wave 2A | courses; course_versions; course_version_transitions; program_courses; program_memberships | programa ativo; autor/gestor; publicação coordenador/admin; exceção admin legada explícita | page_viewed/feature_used existentes; auditoria CourseVersionTransition | edição ONLINE_ONLY; catálogo CACHE_READ; estudo contextual mantém outbox | test_course_editor; course_editor_screen_test; dynamic_learning_path_test; WAVE2A_ACCEPTANCE.md | N/A, fluxo existente; contexto novo segue flags da Wave 1 | Wave 2A | STAGING |
| Catálogo atualizável / 75ac62c1bb3241aba1b3092f908b7c5f | N/A, comando utilitário no menu existente | aluno/editor | course_publication_path | home; study_hub | HomeScreen | State/Future e courseLoader injetável | Course; CourseVersion; contexto da turma preservado | CourseRepository; cache remoto v2 por API | GET /courses | courses; course_versions; SharedPreferences v2 local | catálogo público não autoriza matrícula | page_viewed existente; atualização não é LearningEvent | CACHE_READ por URL; QA opt-in une cache remoto e nove assets offline; v1 sem origem não é inferido | course_repository_test; home_catalog_refresh_test; test_course_editor; dynamic_learning_path_test; evidence/remote-catalog-qa-2026-10-02.json; WAVE2A_ACCEPTANCE.md | REMOTE_CATALOG_ENABLED=false padrão; true só APK debug staging deste QA, independente de LEARNING_CONTEXT_ENABLED | Wave 2A; QA isolado 02/10 | STAGING, sem release |
| Tutor IA contextual / Issue #134 | N/A | aluno | cartilha → edição → módulo → Tutor/experiência | ChatExperienceScreen → GenUIAssistantScreen | TutorLearningContext; GenUIAssistantScreen | nenhum state persistido | course_id; course_version_id; module_id; experience_id/type | AnythingLLMService | POST /v1/chat; workspace `vector-search`/`chat` | N/A | somente seleção de conteúdo; não autoriza vínculo acadêmico | sem nova telemetria | ONLINE_ONLY; `mode=query`, sem sessionId ou histórico estruturado | anything_llm_service_test; chat_experience_progress_test; gateway.test.js A/B; test_course_promotion.py; AI_RAG_CONTEXT_BINDING_AUDIT_2026-10-05.md | mapa temporário CourseVersion ausente = fail-closed; legado permanece | Wave 2, recorte parcial | TESTED-LOCAL: gateway e promoção; caller #135 integrado; isolamento real de módulo/experiência BLOCKED; staging sentinel NO |
| Certificates / — | N/A | aluno/revisor | certificate_eligibility_path | certificate_wallet | CertificateWalletScreen; CertificateRequestsScreen | State local | CertificateRequest; CertificateReference | CertificateRequestRepository; CertificateRepository | /certificate-requests, conferir contrato completo na wave | certificate_requests; certificate_references; KV legado | revisão humana + matrícula | — | cache carteira; emissão online | test_certificate_requests; certificate_requests_screen_test | — | Wave 5 | PARTIAL |
| Media/Vídeo / — | N/A | aluno | aprendizagem mídia | videos | MediaCatalogScreen; MediaPlayerScreen | State local | MediaAsset | MediaRepository | /media, conferir na wave | media_assets; media_events | grant de playback | video_started; video_checkpoint | CACHE_READ catálogo | media_catalog_screen_test; test_media_commercial | — | Wave 7 | PARTIAL |
| Creator / — | N/A | creator | publicação | course_editor | CourseEditorScreen | State local | CourseVersion; MediaAsset | CourseEditorRepository | /editor/context | course_versions | papel de programa | — | ONLINE_ONLY | test_course_editor | — | Wave 8 | PARTIAL |
| Evidence/Reporting / — | N/A | equipe/aluno | evidência/presença | — | EvidenceStaffScreen; SessionPresenceScreen | State local | EvidenceItem; SessionPresence | EvidenceRepository | conferir contrato específico na wave | evidence_items; session_presence | equipe autorizada, decisão humana | — | política por comando | test_presence; evidence_screens_test | — | Wave 9 | PARTIAL |
| Commercial/Entitlements / — | N/A | equipe | direitos | — | — | — | RevenueLedgerEntry | — | API comercial existente, auditar na wave | revenue_ledger | — | — | — | test_media_commercial | pagamentos desligados (histórico) | Wave 10 | PARTIAL |
| Production hardening / N/A, operação | N/A | operador | release | N/A | N/A | N/A | N/A | N/A | health/live | migrations | operador autorizado | logs operacionais | N/A, operação | test_migrations; test_database; release_readiness_verifier_test; ENVIRONMENT_CONTRACT.md; PRODUCTION_READINESS.md | release_build_allowed=false; PRODUCTION_RELEASE_READY=false; production flags false | Wave 11 | BLOCKED — GitHub, restore, schema e upgrade pendentes |

Nomes sem `.py`/`.dart` são nomes-base dos testes em `api/tests/` ou
`cartilhas_app/test/`. Linhas posteriores à Wave 1 são inventário, não execução
de waves. PARTIAL nunca significa aceite de staging ou aprovação visual.
STAGING nas seis linhas da Wave 1 significa somente aceite funcional do recorte;
Classroom integral e paridade visual permanecem PARTIAL na Wave 3. Os três
caminhos usam também `integration_test/context_learning_path_test.dart`.

Staging gerenciado da Wave 1 implantado em 2026-09-23: ver CLOUD_STAGING.md,
evidence/cloud-staging-http.json e evidence/cloud-locked-deployment.json.
Contexto e migração verificados por HTTPS. A variante de entrega
9d6e0e93f2c448058d3f4afac70a7c4a está ligada ao componente real na Home e no
leitor; contrato em LEARNING_DELIVERY_CONTRACT.md. Projeção/retry: 42 testes
passaram (evidence/learning-delivery-repository.json); controller/UI e regressões:
31 passaram (evidence/learning-delivery-local-verification.json). Suíte Flutter:
344 passaram em 2026-09-23; análise global concluída sem problemas (exit 0),
evidência evidence/wave1-flutter-local-gate.json. Aceite Android das seis fases
aprovado em evidence/context-android-gate.json; isolamento HTTPS aprovado em
evidence/cloud-context-isolation.json. Linhas funcionais da Wave 1 e os digests
Home/entrega passam a STAGING. Resultados e limites atuais em WAVE1_ACCEPTANCE.md;
retenção de recibos e gates de release permanecem necessários para promoção.
Nenhum aceite visual integral ou PRODUCTION_READY.

## Pitch público — 29/09/2026

| Entrega | Evidência | Estado | Limite |
| --- | --- | --- | --- |
| Atualização do pitch Startups UFT | PITCH_EVIDENCE_2026-09-29.md; PPTX em outputs | DOCUMENTAÇÃO VERIFICADA | Não altera estado funcional, flags nem aprovação de produção; capturas históricas |

| Revisão concisa do pré-pitch | PITCH_EVIDENCE_2026-09-29.md; Tutor_TDS_Pre_Pitch_Identidade_TDS_29-09-2026.pptx | DOCUMENTAÇÃO VERIFICADA | Sete slides; identidade/logomarca TDS; modelo proposto, produção histórica e staging identificados; sem promoção funcional |

## Identidade e jornada — recorte priorizado em 01/10/2026

QA sintético local, PostgreSQL e POCO concluído. Flags false fora do QA; stack
temporária removida. STAGING é aceite funcional deste recorte isolado, sem
aprovação de release/visual integral/BI. Piloto 11–30/10/2026, 40h, três cidades;
Rafael confere vínculos. Sem execução paralela de migrations centrais.

| Feature / Stitch screenId | Derivative | Persona | Jornada | Flutter route | Flutter screen/widget | ViewModel/controller | Domain entity | Repository | API endpoint | Database table | Permission | Analytics event | Offline policy | Test | Feature flag | Release | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PDF complementar / Home já inspecionada | 75ac62c1bb3241aba1b3092f908b7c5f, botão existente | aluno | catálogo → PDF externo | home | CoursePdfButton | CoursePdfController | Cartilha.downloadUrl; LearningEvent existente | CourseRepository; AppTelemetryService; LearningEventQueue | catálogo existente; POST /events; launcher HTTPS externo | learning_events; outbox existente | PDF público; rastreio exige conta e consentimento de jornada | feature_used/course_pdf_open_requested; zero crédito | PDF externo sem cache no Tutor; pedido OFFLINE_WRITE_SYNC | course_pdf_test 9; home_catalog_refresh_test 5; screen_engagement_test 3; test_journey_traceability 5; classroom_access_path_test físico + renderização observada | JOURNEY_TRACEABILITY_ENABLED=false padrão | candidata | STAGING, sem medir leitura externa |
| Sessão e dono / — | N/A, correção interna | aluno/equipe | entrada e troca de conta | login; logout | telas existentes | AuthRepository sessionGeneration | User; session | AuthRepository | /auth/login; /auth/refresh; requests autenticados | sessions; secure storage existente | conta atual; resultado tardio descartado | nenhum novo | ONLINE_ONLY autenticação; outbox preserva dono | auth_repository_test; journey_traceability_test | N/A, correção de sessão | candidata não numerada | STAGING |
| Conferência baseline / — | N/A, formulário existente incremental; paridade não promovida | Rafael/equipe | instructor_observation_path | acompanhamento do aluno na turma | StudentFollowupScreen | State/controller existente | StudentBaseline; BaselineSourceRecord; BaselineRevision | ClassroomRepository | GET/PUT baseline; GET journey-export | student_baselines + coluna BI 0020; reservas/histórico existentes | equipe no escopo; revisão humana | nenhum novo; revisão é auditoria | ONLINE_ONLY | test_journey_traceability; test_journey_migration; student_followup_screen_test; journey_baseline_control_test | JOURNEY_TRACEABILITY_ENABLED=false | candidata não numerada | STAGING |
| Telemetria consentida / — | N/A, rotas e aviso existentes incrementais | aluno/equipe | jornada de uso e ajuda | Home; Tutor; estudo; modais | CartilhasApp; PrivacyScreen; GuideScreen; GenUIAssistantScreen | AppTelemetryService; ScreenEngagementClock | LearningEvent; fila por dono/API | LearningEventSyncService; SqliteLearningOutbox | POST /events | learning_events; SQLite learning_outbox existente | sessão atual; nova escolha de consentimento; sem pergunta/PII no export | page_viewed; screen_engagement; tutor_help_requested; human_help_requested; tutor_feedback_not_useful | OFFLINE_WRITE_SYNC; foreground/idle/modal; legado sem dono não reassociado | screen_engagement_test; journey_privacy_preferences_test; journey_traceability_test | JOURNEY_TRACEABILITY_ENABLED=false + DURABLE_LEARNING_OUTBOX_ENABLED=false | candidata não numerada | STAGING |
| Overlay BI / N/A, artefato separado | N/A, cópia do PBIP original inspecionado | Rafael/equipe | identidade, pendência, uso e resultado oficial | N/A, BI | RastreioApp no PBIP candidato | export_tds_journey; consultas PQ/medidas | Pessoa; Participação; Baseline; eventos | export autorizado | GET journey-export; GET journey-activity | tabelas canônicas; snapshot CSV em três destinos separados | equipe e workspace restritos; não concede direitos | agrega eventos existentes; dedup event_id entre turmas | ONLINE_ONLY snapshot; BI não autoriza matrícula | test_journey_export_tools; HTTP sintético; Desktop com 2 contas e filtros aprovados; qualidade legada/vínculo confirmado pendentes | JOURNEY_TRACEABILITY_ENABLED=false | candidata BI não publicada | PARTIAL |

| Measurement Contract v1 / N/A | N/A | participante/equipe/mentor | etapas 01–12, sem novo fluxo no app | N/A, contrato | N/A | revisão humana + projeção autorizada existentes | User; Enrollment; CourseVersion; StudentBaseline; MentorshipCase; EvidenceItem; CertificateReference | journey_export; fontes externas preservadas | GET journey-export/journey-activity existentes; futuras etapas sem endpoint aprovado | tabelas existentes e ficha/Sheets externa; sem nova migration | equipe/coordenação validam resultado, eventos não concedem | atividade consentida é evidência, não conclusão | export ONLINE_ONLY; fila existente só para eventos consentidos | test_journey_traceability existente; TDS_MEASUREMENT_CONTRACT_V1.md delimita gaps sem aceite funcional | JOURNEY_TRACEABILITY_ENABLED=false | futura fatia | CONTRACT_ONLY, produção bloqueada |

Evidências e limites em TDS_JOURNEY_QA_2026-10-01.md; método de conferência e
intervenções humanas em TDS_JOURNEY_PILOT.md. Artefato final:
outputs/TDS_Journey_Pilot_2026-10-11/TDS_Rastreio.pbip. Fontes originais preservadas;
tipos numéricos corrigidos apenas na cópia Baseline/ComplementoBaseline. Jornada
e 17 páginas idênticas; histórico de certificados KV sem ligação automática.
Confirmação posterior: cartilha atual, Rafael sem conta. Cadastro existente na
WelcomeScreen, sem nova UI nesta tarefa; vínculo de equipe/edição e promoção
continuam pendentes. Plano e referência/hash do conteúdo atualizados localmente.

Continuação Astra: edição legada v1 resolvida em clone da produção, migration
0005→0020 e retorno à imagem antiga validados para health/catálogo, backup fora
do VPS criptografado e verificado. Flutter completo 367; API 346 + fixture
temporal corrigida/rerun 1. Compose validado sem deploy. Overlay BI mantém PARTIAL:
TMDL abriu, carregou dados e filtros de contas pendentes passaram; faltam qualidade
legada e cenário BI com vínculo confirmado. Três abas de QA em
cópia Sheets privada, sem alterar fonte original. Evidências journey-expanded-
validation, journey-production-rehearsal, journey-bi-desktop, journey-compose-
config e journey-off-vps-backup de 2026-10-01.

Responsabilidade institucional confirmada por Rafael: IPEX, programa TDS, para
as três turmas do piloto. Plano e manifesto de ativação atualizados em 01/10;
IDs persistentes e conta de equipe continuam pendentes, sem promoção de status.
Power BI: login concluído pelo titular, rastreio de duas contas QA validado e
cópia salva. Cartões legados voltaram a calcular após correção de tipos; erros
de dados permanecem (68 Baseline/65 Jornada), incluindo data inválida. Sem aceite
integral do BI e sem publicação externa.

01/10, continuação física de Dynamic Learning 2A: POCO completou oito fases
no mesmo APK e quatro verificações host, com paridade de contexto/edição/progresso.
V1 5%, v2 0%; replay sem duplicata; 224 eventos e 57 registros anteriores
preservados. Play/DEV inalterados, rede restaurada. Somente course_versioning_xiaomi
passou em release_status.json; freeze e três gates restantes mantidos.
Evidência wave2a-physical-acceptance-2026-10-01.json, run 3c2d38851f024a1eb50667aa86dc7ce0.
Wave 2/STAGING não se tornam produção ou Wave 2 completa por este resultado.

Continuação física Classroom/PDF: run abbdfe6c3fd54366b26c46d1d6075954 passou
oito fases no mesmo APK, após instalação confirmada por Rafael. Reabertura fria
offline manteve conta/edição/posição/fila; dois eventos chegaram uma vez, progresso
QA 2,5%→5%. Conta sem vínculo recusada; revogação conhecida invalidou acesso
online e offline. Revogação restrita à fixture nova, não comando administrativo
de produto. Preservados 332 eventos e 77 registros anteriores; 123 hashes de
fonte conferidos, Play/DEV intactos, rede restaurada e QA encerrado. PDF real
abriu no Drive após escolha de conta, confirmado por Rafael e screenshot; um
pedido de abertura sem crédito, sem medição de páginas/tempo externo.
Aceite evidence/classroom-access-physical-acceptance-2026-10-01.json fecha somente
classroom_cold_offline_xiaomi. Certificado/Evidence offline e freeze continuam.
# Issue #5 local candidate — 2026-10-03

| Delivery | Writer / branch | Paths | Expected evidence / gate |
| --- | --- | --- | --- |
| Authenticated synthetic emission and read-only recovery | Sole Issue #5 implementer / `agent/issue-5-authenticated-emission-20261003` | API emission/transport, existing Worker, additive migration0021, focal tests | Actual producer/consumer signatures/context, timeout/concurrency, disposable DB preservation; independent review + exact-SHA CI required |
| Candidate isolation and owner privacy | Same writer | certificate references/list, journey export, auth erasure | Synthetic references never official; ledger erased with account; legacy refs preserved |
| Final institutional issuance | Blocked | No real service or release writes | Business formulas superseded by authorized v2 below; installed issuer/signature/physical activation gates remain |

Details: `ISSUE5_AUTHENTICATED_EMISSION_CANDIDATE.md`; no gate promoted.

| Issue #5 authorized v2 | Implementation | Evidence / gate |
| --- | --- | --- |
| Course80h formal, meetings70%, full configured trail | certificate_policy.py + immutable Classroom policy | New focal real API/Worker tests; no stopwatch or historical aggregate credit |
| Baseline any origin, instructor sheet coverage, CAP/VALID formulas | Existing EvidenceItem/ReviewDecision/StudentBaseline adapters | Synthetic private document attestations; no claimed institutional document read |
| Automatic generation + four lifecycle states + audit institutional flow | Last checkpoint→_run, candidate ref lifecycle, pending_dispatch evidence | No real SMTP/VPS; gate blocked, official wallet segregated |
| Additive policy/lifecycle schema | 20261003_0022 | Populated upgrade/empty rollback + populated downgrade refusal; SQLite only |
