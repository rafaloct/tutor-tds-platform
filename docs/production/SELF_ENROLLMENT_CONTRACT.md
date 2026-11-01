# Self-Enrollment — matrícula espontânea em turma aberta (contrato)

Fatia aprovada pelo usuário em 31/10/2026: matrícula não depende mais apenas da
equipe. O catálogo continua exposto; o primeiro toque do aluno autenticado em um
curso com turma aberta executa um comando explícito de matrícula e, quando a flag
de sincronização estiver ativa, projeta a matrícula no LearnPress legado.

Escopo desta fatia: contrato + implementação atrás de flags desligadas por
padrão, testes locais. Não autoriza staging, produção nem PRODUCTION_READY.

## Decisões humanas registradas

- Sempre deve existir turma válida aberta por curso elegível: se nenhuma turma
  com `enrollment_policy='open'` e status != `closed` existir, o próprio comando
  de auto-matrícula provisiona uma (idempotente, determinística).
- O aluno do app pode não ter conta WordPress: a sincronização provisiona a
  conta WP via novo endpoint `tds/v1/register` (decisão explícita que supera o
  congelamento do tds-lms-core registrado na auditoria WP-1, somente para este
  endpoint operacional; nenhuma regra acadêmica nova é adicionada ao legado).
- A matrícula espontânea cai em turma aberta dedicada por curso (autoestudo),
  nunca em turma tutorada da equipe.

## OBSERVED (base desta fatia)

- `POST /auth/register` já é público e cria User `role=student` sem vínculos.
- Matrícula formal exige hoje ProgramMembership → Enrollment → ClassEnrollment
  → CohortMembership/contexto, criáveis só por admin (`/admin/organizations`)
  ou operador de programa (`/operations/{class}/commands`, flag própria).
- `GET /classes?enrolled_only=true` lista só turmas do aluno; mídia protegida
  responde 403 sem matrícula ativa; LearningContext v2 exige a cadeia completa.
- Runtime WP: `tds/v1/enroll` (X-API-Key, idempotente), `tds/v1/user-by-phone`
  e `EnrollmentGate::maybe_auto_enroll` (auto-matrícula no site para curso
  gratuito) já existem e são reutilizados; `tds/v1/register` é o único acréscimo.
- Outbox com claim/lease/backoff já existe em `sync_worker.py` (Sheets); o
  mesmo padrão é aplicado à fila de sincronização externa.

## Contrato implementado

### Modelo (migração aditiva 0025)

- `classes.enrollment_policy`: `'managed'` (default, comportamento atual) ou
  `'open'`. Turmas tutoradas permanecem `managed` — a equipe continua sendo a
  única fonte de matrícula nelas.
- Índice único parcial garante no máximo **uma** turma aberta não encerrada por
  curso (`enrollment_policy='open' AND status != 'closed'`). Turma aberta
  encerrada não bloqueia novo provisionamento.
- Nova tabela `external_sync_requests`: fila transacional para projeções
  externas (`kind='learnpress_enroll'`), única por (kind, user_id, course_id),
  com status/attempts/next_attempt_at/claimed_at/last_error — mesmo desenho de
  reivindicação do sync worker existente.

### Provisioning da turma aberta (determinístico, na transação do comando)

1. Curso precisa estar ativo e possuir CourseVersion `published`; caso
   contrário o comando falha explicitamente (409/404).
2. Programa dono da turma: a oferta `program_courses` mais antiga em ordem de
   `program_id` (determinística); sem oferta → 409 "curso sem oferta".
3. Responsável (`teacher_id`): primeiro ProgramMembership ativo do programa,
   prioridade de papel `teacher` → `coordinator` → `admin` → `program_operator`,
   desempate por `user_id`. Nenhum elegível → 409 "turma aberta não provisionável".
4. Turma criada: nome `Turma Aberta — {título do curso}` (truncado 240),
   `start_date` = dia do provisionamento, `end_date` = 2100-12-31 (autoestudo
   contínuo; progresso esperado tende a zero por contrato — não é turma com
   prazo), `status='active'`, `enrollment_policy='open'`, `course_version_id` =
   versão publicada vigente no momento. Conflito de índice (corrida) → relê a
   turma existente.

### Comando `POST /courses/{course_id}/self-enroll`

- Requer access token; flag `SELF_ENROLLMENT_ENABLED=false` responde 404.
- Na mesma transação: ProgramMembership(role=student) se ausente → Enrollment
  se ausente (status `inactive` existente → 409, não reativa revogação) →
  ClassEnrollment + `bind_student` (contexto v2, edição fixada da turma) →
  OperatorCommandReceipt com `actor_id=subject_id=aluno`, `action='enroll'`,
  `reason='self_enroll_open_class'` (mesma trilha de auditoria dos operadores) →
  `external_sync_requests(kind='learnpress_enroll')` quando a flag de sync
  estiver ativa.
- Idempotente: matrícula ativa existente retorna o contexto vigente (200) sem
  duplicar vínculos, recibo ou item de fila.
- Resposta: `LearningContextSnapshot` (`cohort-enrollment-v2`) via
  `resolve_student_context` — mesma forma que o app já consome.

### Leitura `GET /open-classes`

- Lista turmas `enrollment_policy='open'` e `status != 'closed'`, com
  `course_id`, `course_title`, `course_version_id`, `name`, datas e
  `viewer_enrolled` (o aluno já possui vínculo ativo naquela turma).
- Requer token; não expõe roster nem identidades de outros participantes.

### Sincronização LearnPress (projeção, nunca autoridade)

- Flag `LEARNPRESS_SYNC_ENABLED=false`; config `WORDPRESS_BASE_URL`,
  `WORDPRESS_TDS_API_KEY` (secret de ambiente, nunca no app).
- Worker `learnpress_sync` (CLI `--once`/loop): reivindica itens pendentes com
  lease/backoff → `GET /tds/v1/user-by-phone/{phone}` → se 404,
  `POST /tds/v1/register {name, phone, tds_user_id}` → `POST /tds/v1/enroll
  {user_id, course_slug}` (course_slug = `courses.id` canônico, que deve
  coincidir com o `post_name` LearnPress — verificação por curso é gate de
  ativação).
- Falha de transporte/HTTP → retry com backoff; esgotado permanece `failed`
  para reconciliação. Matrícula canônica jamais é revertida por falha de
  projeção. Item concluído → `done` + `completed_at`.
- `tds/v1/register` (WP): idempotente por telefone (mesmas chaves de meta que
  `user-by-phone` consulta: `billing_phone`, `_tds_phone`, `tds_telefone`),
  cria subscriber com senha aleatória desconhecida do aluno, grava meta
  `tds_user_id` para linhagem e retorna `user_id`. Sem e-mail (o app não
  coleta); reset de senha WP fica fora de escopo.

### Flutter

- Flag `SELF_ENROLLMENT_ENABLED` (dart-define, default false) — o app só exibe
  a seção quando a flag local está ativa; a API responde 404 quando a dela
  estiver desligada (dupla proteção).
- `LearnerClassroomsScreen` ganha seção "Turmas abertas" (via `GET
  /open-classes`): primeiro toque → `POST self-enroll` → `LearningContext`
  real → abre a edição fixada exatamente pelo mesmo caminho de `_open`
  (context controller + `gateway.course(classId)`), sem atalho de autorização.
- Já matriculado (`viewer_enrolled`) → entra direto pelo caminho de turmas.
- Offline: listagem e matrícula exigem rede; turma aberta não entra no cache de
  conteúdo salvo até ser aberta uma vez online (mesma regra das demais turmas).
  O catálogo público e as cartilhas locais continuam navegáveis offline.

## Limites e não-escopo

- Turma aberta com zero encontros configurados não produz CAPACITADO pela
  política de certificado (encontros configurados obrigatórios): autoestudo dá
  acesso a conteúdo e projeção de progresso, não certificação tutorada.
- Nenhuma autorização nova é criada fora da cadeia membership→enrollment→
  class_enrollment→cohort_membership persistida; eventos/telemetria continuam
  sem conceder direitos.
- `enrollment_key` (código de convite por turma) é fase futura registrada como
  opção; não implementada nesta fatia.
- Sincronização é apenas FastAPI → WP. WordPress nunca autoriza matrícula no
  núcleo; `learnpress_user_items` recebe projeção para manter o legado e os
  webhooks n8n (`learnpress_user_enrolled_course`) coerentes.
- Deploy do `tds/v1/register` no runtime WP de produção é ação humana/Dokploy
  fora desta fatia; o código fica no snapshot canônico do monorepo.
- Reconciliação de matrículas pré-existentes (alunos já matriculados pela
  equipe) não muda: continuam válidas, incluindo as que não têm contexto v2.

## Testes (locais, SQLite)

- Flag desligada → 404 nos dois endpoints.
- Self-enroll cria a cadeia completa + contexto v2 resolvível + recibo de
  auditoria; replay retorna mesmo contexto sem duplicatas.
- Provisioning cria turma aberta uma vez por curso, reutiliza em chamadas
  seguintes e falha explicitamente sem oferta/responsável/versão publicada.
- `open-classes` lista política correta e `viewer_enrolled` por conta.
- Worker LearnPress: fake sink cobre caminho feliz (register→enroll),
  idempotência, retry e esgotamento.
- Flutter: repository/controller/Widget da seção de turmas abertas com fakes.

## Gates de ativação (futuros, fora desta fatia)

- `SELF_ENROLLMENT_ENABLED=true` exige staging com seed de turma aberta real.
- `LEARNPRESS_SYNC_ENABLED=true` exige: `tds/v1/register` implantado no WP,
  `WORDPRESS_TDS_API_KEY` provisionada como secret e conferência slug↔post_name
  por curso. Verificação antes da primeira ativação.
