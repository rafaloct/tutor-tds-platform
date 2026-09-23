# Wave 1 — auditoria do repositório real

Auditoria histórica. Estado atual em `docs/CURRENT_STATE.md` e
`docs/production/evidence/`; bloqueios de credenciais e etapas registrados abaixo
descrevem suas respectivas rodadas, não pendências atuais.

Data: 2026-09-23. Base limpa `fb50a57` antes desta rodada. Versão fonte
`1.4.0+13`; `release_status.json` proíbe build/upload e marca AAB superseded.
Não foi consultada Play Console nem alterado qualquer ambiente remoto.

## Fontes e limites

Inspecionados: pubspec, modelos SQLAlchemy, rotas FastAPI, migrações Alembic,
Home/leitor/turmas Flutter, repositories de turma/cache/progresso/eventos,
integrações registradas em main, testes do recorte e documentação de versões.
Os cinco arquivos de contexto obrigatório não existiam na raiz/caminhos pedidos;
foram criados a partir do código e da intenção explícita do usuário.

Stitch: nenhum conector disponível e variáveis ausentes. Busca local não encontrou
cache/export com os IDs. A documentação do SDK confirma `getScreen`, `getHtml`
e `getImage`, mas isso não comprova acesso ao projeto. Referência técnica:
[README oficial](https://github.com/google-labs-code/stitch-sdk/blob/main/README.md).
Não baixado nenhum HTML/screenshot; não criado digest fictício. Comparação
mockup/implementação permanece pendente, inclusive para imagens de nome genérico.

Skill Flutter solicitada ainda não localizada; não houve implementação Flutter.

## Achados que impedem o gate

| ID | Evidência concreta | Consequência | Menor ação |
| --- | --- | --- | --- |
| W1-01 | models.py: User.role, ProgramMembership, ClassEnrollment, ClassMonitor, Classroom.teacher_id | múltiplas representações de papel/escopo | adaptar vínculos ao Membership contextual com backfill, sem apagar legado |
| W1-02 | Enrollment único por user/program/course; versão em Classroom | não satisfaz matrícula por Membership+CourseVersion; possível 1:N entre matrícula antiga e turmas | definir linhagem explícita antes da migration |
| W1-03 | StudyProgressRepository._courseKey usa course/version/owner | duas turmas da mesma edição compartilham retomada; ambiente não consta na chave | nova chave contextual e preservação do legado ambíguo |
| W1-04 | leitor usa posição local; classrooms._student_progress usa validated_seconds/planned_seconds | aluno e instrutor não leem a mesma projeção | separar posição de leitura da projeção oficial compartilhada |
| W1-05 | LearningEventQueue.enqueue remove índice 0 quando cheia sem telemetria removível | pode perder evidência offline antes de persistir no servidor | outbox durável sem descarte silencioso, capacidade/erro explícitos |
| W1-06 | eventos não têm dono/ambiente no envelope; sync usa conta atual; logout da tela limpa fila | perda de pendências no logout; segurança depende do fluxo de logout | vincular outbox à conta/ambiente e decidir retenção por contrato |
| W1-07 | classroom_course e resolver de eventos não verificavam ProgramMembership ativo | vínculo revogado ainda lia conteúdo e criava evidência | correção mínima aplicada nesta rodada; staging pendente |
| W1-08 | ausência de LearningContext nos símbolos pesquisados | relações são remontadas em features | resolver único e contrato/FakeRepository antes de UI |
| W1-09 | integration_test contém app_test/genui_test, sem os três golden paths | testes isolados não aprovam gate | integração real dos caminhos student/instructor/offline |
| W1-10 | nenhuma entidade/rota LiveQuestion encontrada | mockups ao vivo não estão implementados | registrar MISSING e aguardar Wave 4 |

## Reprodutor e correção de W1-07

Em banco SQLite sintético em memória, fixture `version_events`:
desativar `ProgramMembership(student,p1)` mantendo os vínculos de turma/matrícula.
Antes da correção: GET `/classes/class-p1/course` = **200** e POST `/events`
com essa turma/edição = **201**, quando ambos deveriam negar com **403**.

Correção reaproveita `_active_student`/`_staff` existentes para curso, restringe
listagem `enrolled_only` a programa ativo e acrescenta o mesmo requisito ao
resolver de eventos versionados. Não cria tabela, endpoint, flag ou mecanismo
de papéis paralelo. Catálogo público e retry idêntico já persistido preservados.
Novos testes cobrem revogação e reativação sem novo login, professor com papel
global student, isolamento entre programas e ausência de nova linha no replay
revogado. A listagem geral e demais permissões seguem pendentes de auditoria.

## Evidência de validação local

- Base: 37 testes API passaram (`test_course_version_events`,
  `test_classroom_course_versions`, `test_classroom_followup_dashboard`,
  `test_migrations`). Migrations testadas do zero/up/down em SQLite; isso não
  demonstra PostgreSQL/staging. Duas advertências de depreciação das dependências.
- Flutter 3.44.9: 44 testes passaram em `study_progress_repository_test`,
  `learner_offline_repository_test`, `learner_classrooms_screen_test`,
  `learning_event_queue_test`, `learning_event_sync_service_test`.
- Regressão após correção: **42 testes passaram** em
  `test_context_access_revocation`, `test_course_version_events`,
  `test_classroom_course_versions`, `test_classrooms` e
  `test_classroom_followup_dashboard` (16,87s; duas advertências de depreciação).
  `git diff --check` sem erros de whitespace; avisos de conversão LF/CRLF.
- Não executados nesta rodada: suíte completa, flutter analyze, build release,
  testes físicos, migração PostgreSQL, deploy/staging, Play Store.

## Menor migração e gate

Ver `WAVE1_CONTEXT_CONTRACT.md`: adaptação aditiva do núcleo, resolver único,
projeção compartilhada, migração contextual do cache/outbox e integração de uma
jornada. Preservar dados/assinatura e contratos antigos. Não avançar Wave 2.
Auditoria visual e skill dependem das ações em `ACTION_REQUIRED.md`.

## Validação da fatia Context Core — 2026-09-23

Atualiza o estado inicial acima; não substitui o acceptance gate.

- 44 testes API passaram: test_learning_context, test_context_golden_path,
  test_context_access_revocation, test_course_version_events,
  test_classroom_followup_dashboard. Duas advertências de dependências.
- 59 testes Flutter passaram: learning_context, learner_classrooms_screen,
  study_progress_repository, chat_experience_progress, learning_event_queue,
  learning_event_sync_service, settings_logout, learner_offline_repository.
- `flutter analyze --no-pub`: sem apontamentos pelo junction ASCII documentado
  em CONTEXT_CORE_SLICE.md. No caminho Unicode original o analisador falhou
  no framing JSON/LSP; nenhum código de produto foi alterado para esconder isso.
- Golden path com autenticação real, migrations do zero, PostgreSQL 16 isolado,
  persistência após recriar API, projeção aluno/instrutor igual e replay sem
  duplicata: passou. Evidência `evidence/context-postgres-gate.json` inclui hash
  do fonte e imagem. Containers/rede de QA removidos; serviços existentes intactos.
- Não é teste mobile contra HTTP público. Não houve deploy do candidato,
  migration física nova, build release, Play Console ou aprovação da Wave 1.
- Skill Flutter expert aplicada. Stitch Classroom tem screenshot, metadata e
  digest; HTML ainda bloqueado. Outras telas não foram baixadas sem necessidade.

W1-04/08 avançaram com resolver e progresso comum; W1-05/06 com retenção e dono
no envelope. Permanecem PARTIAL: outbox ainda não transacional, papéis globais
legados, migração física e integração Android completas pendentes.

## Continuação com sessão Stitch autenticada

- Classroom: HTML original copiado pelo editor Stitch, validado e salvo junto
  ao screenshot existente. Cache completo e hashes verificados sem nova consulta
  da API. Comparação em `STITCH_CLASSROOM_COMPARISON.md`; paridade não aprovada.
- Corrigida inconsistência do adapter: a permissão activity.record agora é
  cumprida por POST /events contextual com flag ativa independentemente do papel
  global. Matrícula/programa/turma/edição seguem obrigatórios. Um professor sem
  matrícula de aluno não pode registrar atividade de estudo nesse caminho.
- **55 testes API passaram**: os 45 do recorte contextual/revogação/dashboard
  e os 10 de eventos legados. Estes últimos preservam negação para papéis não
  student fora do fluxo contextual. Sem alteração Flutter nesta continuação.
- Golden path reexecutado com JWT real de usuário global teacher matriculado
  como aluno, migrations do zero e PostgreSQL 16 isolado: passou. Persistência,
  observação pelo professor e replay sem duplicata confirmados. Evidência em
  `evidence/context-multirole-postgres-gate.json` com novo hash do candidato.
- Sem deploy no staging público, release build, teste físico ou mudança de gate.
  Login/HTML não exigem mais intervenção humana. Seguir migração física/outbox.

## Continuação — outbox transacional e preflight físico

- LearningOutbox/SqliteLearningOutbox implementados atrás de flag false;
  constraints, índices, transação de importação, corpo imutável, backoff,
  conflito persistente e recibos de sucesso. Nenhuma migration remota aplicada.
- 36 testes Flutter direcionados passaram (SQLite, fila/sync legado, exclusão,
  telemetria, mídia, leitor e logout); análise Flutter sem issues.
- Build debug .dev passou e teste nativo SQLite passou no Android 15/API 35,
  Pixel Tablet emulator-5556. Não é build release nem QA em aparelho físico.
- Primeiro ensaio de persistência entre duas execuções falhou porque o runner
  desinstala o app por padrão. Diagnóstico registrado; protocolo corrigido com
  --no-uninstall. Não alterar persistência para esconder o problema do runner.
- Preflight da migração física tem dois testes passando; staging auditado em
  READ ONLY retornou 2 contextos, sem bloqueios ou evidências ambíguas. Nenhum
  dado de produção foi consultado/alterado. Preparar schema/backfill a seguir.

- Ensaio Android corrigido passou: seed --no-uninstall → force-stop do .dev →
  verify em nova execução. Atividade conservada e idempotência confirmada.
  Evidência com hashes em `evidence/outbox-android-persistence.json`. Este teste
  não usa API remota nem UI do professor e não aprova o gate inteiro.
