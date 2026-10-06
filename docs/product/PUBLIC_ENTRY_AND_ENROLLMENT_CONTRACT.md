# Entrada pública e jornada até matrícula — contrato de produto

Status: proposta arquitetural. Nenhuma linha deste documento é implementação
observada; cada afirmação está marcada como `OBSERVED` (comprovado em
código/teste hoje), `TARGET` (desejado) ou `DECISION-NEEDED` (exige escolha
humana). Base auditada: `staging@6bc4548a4725bfe48b6e53b6b8b6e34cd1fe1a3c`.

## 1. Problema atual

`OBSERVED` — o app assume que a pessoa já está matriculada ou que só precisa
de conta para tudo:

- A Home contextual consulta `GET /classes?enrolled_only=true`
  (`classroom_repository.dart`) e não oferece descoberta de turmas.
- `GET /public/courses` e `GET /public/courses/{slug}` já existem na API
  (`app/public_api.py`), sem autenticação, com projeção segura
  (slug, título, status `published`, `v{n}`, `updated_at`, `summary`,
  `cover_public_url`, `public_workload_text`, `public_audience_text`) e
  `Cache-Control` público — porém **nenhum cliente Flutter consome esses
  endpoints**. O único catálogo visível hoje são as 9 cartilhas bundled em
  `assets/data/lessons/` + `CourseRepository` (fallback remote→cache→bundled,
  remoto hoje `REMOTE_CATALOG_ENABLED=false` em produção).
- Não existe nenhum endpoint público de turmas.
- Não existe pré-cadastro nem interesse declarado: a única entrada para o
  backend é `POST /auth/register`, que exige **CPF** (`users.cpf_digest`
  NOT NULL), telefone, nome e senha ≥12, opcionalmente gated por
  `cpf_activation_required` (token de ativação, hoje desligado).
- Não existe entidade de "quero participar": clicar em qualquer caminho de
  participação só produz vínculo formal via
  `ProgramMembership`/`Enrollment`/`CohortMembership`/`ClassEnrollment`.
- Não existe modelo para os ~500 participantes históricos de listas de
  frequência. `BaselineSourceRecord` é precedente relevante
  ("referência reservada por humano, nunca respostas nem palpite de
  identidade"), mas é vinculada a um `user_id` existente — não cobre
  registros ainda não reivindicados.

`TARGET` — Tutor TDS também funciona como vitrine pública das cartilhas,
canal de pré-cadastro, descoberta de turmas abertas, inscrição espontânea,
acesso independente sem turma e reconciliação controlada de histórico.

Princípio central (obrigatório em qualquer implementação):

    ACESSO AO CONTEÚDO ≠ INTERESSE ≠ INSCRIÇÃO ≠ MATRÍCULA FORMAL
    ≠ PRESENÇA ≠ CAPACITAÇÃO ≠ CERTIFICADO

Nenhuma ação exploratória cria vínculo acadêmico implícito.

## 2. Personas

| Persona | Necessidade | Estado alvo |
| --- | --- | --- |
| Visitante sem conta | Entender o programa, ver cartilhas e turmas sem login | Home pública; pode virar pré-cadastro |
| Interessada | Avisar que quer participar sem criar conta ainda | `PreRegistration` |
| Conta sem turma | Explorar conteúdo, guardar progresso pessoal, achar turma ou instrutor | `ACESSO_ESPONTANEO` |
| Candidata | Pedir entrada numa turma aberta | `ClassApplication` |
| Participante matriculado | Fluxo atual de turma/presença/estudo | inalterado |
| Equipe/instrutor | Workspace operacional próprio | inalterado; nada vaza para Home pública |
| Histórica (~500) | Ser encontrada, não virar conta automática | `HistoricalParticipationRecord` |

## 3. Estados da Home (TARGET)

O app tem no mínimo quatro homes distintas, decididas por estado real —
nunca por inferência de UI:

**A. Visitante (sem conta)**

    Tutor TDS
    Aprenda, participe e acompanhe sua formação.

    [ Explorar cartilhas ]  [ Ver turmas abertas ]  [ Entrar ]

    Cartilhas em destaque          (GET /public/courses)
    Turmas com inscrições abertas  (GET /public/classes, Wave C)
    Como funciona o programa
    Já participou do TDS?          (entrada discreta → Wave E)

**B. Conta sem turma (ACESSO_ESPONTANEO)**

    Continuar explorando
    Turmas abertas para você
    Encontrar meu histórico
    Tenho um instrutor
    Acesso espontâneo → cartilhas e progresso pessoal

**C. Participante matriculado** — prioridade: Minha turma, Próximo
encontro, Registrar presença, Continuar estudo, Atividades, Progresso
(modelo atual preservado).

**D. Equipe/instrutor** — workspace operacional próprio; nenhuma ação de
instrutor aparece na Home pública/aluno.

`OBSERVED` — hoje só existem C/D; `_hasSession` decide entre "sem sessão"
e "com sessão" e `_hasManagementAccess` abre Gestão. A/B exigem estados
novos derivados do servidor, não de flags locais.

## 4. Pré-cadastro (PreRegistration)

`TARGET` — formulário mínimo; **sem CPF** (CPF segue restrito aos fluxos
que exigem identificação/autenticação — hoje: registro de conta e
certificado).

Campos propostos (todos `DECISION-NEEDED` em privacidade, ver §10):

| Campo | Obrigatório | Observação |
| --- | --- | --- |
| nome | sim | como a pessoa quer ser chamada |
| município | sim | casa com `offer_municipality` |
| telefone/WhatsApp | sim | único canal de retorno |
| área/cartilha de interesse | sim | referência a Course público |
| instrutor (busca em instrutores autorizados) | não | preferência declarada, não vínculo |
| turma específica | não | opcional; pode só entrar na lista |
| origem da indicação | não | texto curto |

Pergunta central: "Você já participa ou recebeu orientação de algum
instrutor do TDS?" → Sim (abre busca de instrutores autorizados) / Não /
Não sei. Instrutor **nunca** é obrigatório para começar.

Saídas possíveis ao final: Ver turmas disponíveis / Entrar na lista de
interesse / Criar conta para acesso espontâneo.

`TARGET` — nova entidade `pre_registrations`: não é `users`, não é
`Enrollment`, não é presença. Apenas um lead com consentimento explícito,
retenção declarada e expiração. Não pode ser promovida a conta
automaticamente; a criação de conta continua exigindo CPF + senha (ou o
fluxo de ativação vigente).

## 5. Acesso espontâneo (`ACESSO_ESPONTANEO`)

`TARGET` — conceito explícito: a pessoa **tem conta** (CPF+senha pelo
fluxo atual de registro) mas **não tem** matrícula formal, turma,
instrutor, presença oficial nem elegibilidade a `capacitado`/certificado
institucional por esse caminho. Pode consumir conteúdo permitido, guardar
progresso pessoal local e usar funcionalidades abertas.

Decisão de modelagem recomendada (TARGET): **estado derivado, não
entidade**. `spontaneous = user exists AND nenhuma ClassEnrollment ativa`.
Não criar "Turma Acesso espontâneo" — isso poluiria `classes`, dashboards,
presença e métricas. Se no futuro for preciso trilha pessoal persistente
no servidor, avaliar `ProgramMembership(role='self_directed')` como
evolução separada — `DECISION-NEEDED`, não assumir agora.

Invariantes obrigatórias:
- `SPONTANEOUS_ACCESS_CERTIFICATE_ELIGIBLE = NO`
- `SPONTANEOUS_ACCESS_ATTENDANCE_ELIGIBLE = NO`
- progresso pessoal ≠ frequência ≠ carga validada ≠ critério de
  certificado (alinhado a `DOMAIN_CONTRACT.md`: posição local de leitura
  não é autoridade).

## 6. Turmas com inscrição aberta

`OBSERVED` — `classes` já carrega `program_id`, `course_id`,
`course_version_id`, `teacher_id`, `name`, `offer_municipality`,
`offer_location`, `start_date`, `end_date`, `status
(planned|active|closed)`, `lifecycle_revision`, e capacidade implícita 30
com exceção coordenada auditável (`classroom_policy.require_available_seat`).
`status` acadêmico já é checado separado de lifecycle — reutilizar, **não
criar entidade paralela de turma**.

`TARGET` — estado de inscrição **distinto** de `classroom.status`:

    registration_status ∈ { registration_closed, registration_open,
                            registration_waitlist, registration_invite_only }
    registration_policy ∈ { AUTO_ENROLL, INSTRUCTOR_APPROVAL,
                            STAFF_APPROVAL, WAITLIST, INVITE_ONLY }

Combinações válidas incluem `planned + registration_open` (turma futura
com inscrição aberta) e `active + registration_closed`. Política é por
turma, nunca global. Sugestão: colunas aditivas em `classes` ou tabela
`class_registration` — `DECISION-NEEDED` na modelagem final (colunas
bastam se a política for escalar; tabela se histórico de política for
requisito).

`TARGET` — `GET /public/classes` (Wave C): projeção pública segura, mesmo
padrão de `public_api.py` (cache curto, sem auth, campos mínimos):

    { name, course_title, offer_municipality, offer_location,
      period {start,end}, instructor_display_name?,
      seats_available, registration_status }

`DECISION-NEEDED` — exibir nome do instrutor em endpoint público exige
decisão editorial/privacidade (hoje `teacher_id` nunca vaza; sugerir
`instructor_display_name` só quando o instrutor optar por vitrine). Nunca
expor: lista de participantes, IDs, dados acadêmicos, presença, contatos.

Card público (TARGET):

    Gestão Financeira para Empreendimentos Rurais
    Palmas · 12/11 a 18/12
    Instrutora: Maria Silva
    18 vagas disponíveis
    [ Quero participar ]

## 7. Solicitação de participação (ClassApplication)

`TARGET` — `Quero participar` **nunca** cria `Enrollment` direto. Nova
entidade `class_applications`:

    id, user_id, class_id (+ lineage program_id, course_id),
    status ∈ { interested, applied, waitlisted, accepted,
               declined, withdrawn, enrolled },
    declared_instructor_preference_id?, note?, created/decided audit

Transições: `interested→applied`, `applied→{waitlisted,accepted,declined,
withdrawn}`, `waitlisted→{accepted,withdrawn}`,
`accepted→enrolled` **somente** pelo caminho autorizado que hoje cria
`ProgramMembership`/`Enrollment`/`CohortMembership`/`ClassEnrollment`.
`accepted` ainda não é matrícula; `enrolled` só existe após o vínculo
formal. Política da turma decide quem aprova (`INSTRUCTOR_APPROVAL` →
instrutor; `STAFF_APPROVAL` → coordenação; `AUTO_ENROLL` → transição
direta respeitando `require_available_seat`; `WAITLIST` → fila;
`INVITE_ONLY` → só por convite).

`OBSERVED` — não existe estrutura equivalente que possa ser reutilizada
sem violar semântica (`Enrollment`/`ClassEnrollment` são vínculo formal;
`CertificateRequest`/`SyncDeletionRequest` são precedentes de
máquina-de-estado auditável para copiar, não para estender).

## 8. Vínculo opcional com instrutor

`TARGET` — a pessoa pode declarar preferência por um instrutor conhecido
(`declared_instructor_preference`) no pré-cadastro ou na aplicação. Isso
é **declaração**, nunca autoridade: não cria `ProgramMembership`, não cria
`teacher relationship`, não concede `attendance authority` nem matrícula.
O vínculo formal continua saindo só de processo autorizado
(`bind_membership`/admin). A lista pública de "instrutores autorizados" é
projeção mínima (nome público + município/área), decidida em §10.

## 9. Base histórica (~500 participantes)

`TARGET` — importação como dados, nunca como contas. Nova entidade
`historical_participation_records` (padrão `BaselineSourceRecord`):

    id, source ("attendance_list:<edição>"), external_ref,
    display_name_as_listed, municipality?, historical_class_or_event,
    course?, instructor_ref?, occurred_period,
    reconciliation_status ∈ { unmatched, possible_match, claimed,
                              verified, rejected_match },
    claimed_user_id?, decided_by?, decided_at?, provenance_json

Regras duras:
- Nunca criar `users` a partir destes registros.
- Nome igual ≠ mesma pessoa; matching por nome é só `possible_match`.
- Fluxo: pessoa cria conta → sistema pode sugerir "encontramos uma
  participação anterior que pode ser sua" → `claimed` com evidência
  suficiente **ou revisão humana** → `verified`. `rejected_match` fecha
  falsos positivos.
- Histórico reivindicado **não** vira presença retroativa, capacitação
  nem certificado automaticamente — alimenta no máximo baseline/contexto
  com revisão, alinhado ao contrato institucional vigente.

## 10. Privacidade e Data Safety

`TARGET` — itens novos que exigem revisão de `release/DATA_SAFETY.md`,
política de privacidade e retenção antes da implementação (não alterar
agora):

- `pre_registrations`: nome, município, telefone/WhatsApp, interesse,
  preferência de instrutor, origem — novo grupo de coleta **antes** da
  conta; exige consentimento, finalidade declarada, prazo de expiração e
  canal de exclusão compatível com o fluxo "excluir conta" existente
  (que hoje cobre `users`; lead sem conta precisa de expiração/cleanup).
- `class_applications`: vínculo user→turma desejada (dado acadêmico
  embrionário).
- `historical_participation_records`: nome como consta em lista
  histórica + contexto — PII de terceiros importada; retenção e base
  legal explícitas.
- `GET /public/classes`: exposição de `instructor_display_name`,
  município e vagas — dado sobre equipe, decisão editorial.
- Telemetria de funil anônima (VISITOR→CONTENT_VIEW): definir se conta
  como "analytics" no Data Safety.
- CPF: **fora** do pré-cadastro; mantido só em registro/certificado.

## 11. Modelo de domínio (TARGET)

    Visitor
      ↓ (voluntário)
    PreRegistration            ← sem CPF, expira, não é conta
      ↓
    User (conta real; CPF+senha pelo fluxo atual)
      ├── ACESSO_ESPONTANEO    ← estado derivado, sem turma
      │      + progresso pessoal local
      └── ClassApplication     ← intenção por turma
                ↓ accepted + processo autorizado
            ProgramMembership / Enrollment / CohortMembership /
            ClassEnrollment    ← vínculo formal (inalterado)
                ↓
            Classroom          ← status acadêmico + registration_status

    HistoricalParticipationRecord —→ possible_match —→ claimed/verified
                                  (revisão humana; nunca conta)

Reutilização: `User`, `Classroom`, `Program`, `Course`, `CourseVersion`,
`Enrollment`, `ClassEnrollment`, `CohortMembership`, `ProgramMembership`,
`require_available_seat`, `BaselineSourceRecord` (como padrão de
proveniência), `learning_events` (funil append-only). Novas entidades só
onde a semântica não cabe: `pre_registrations`, `class_applications`,
`historical_participation_records`, e o estado `registration_status`/
`registration_policy` em `classes`.

Endpoints futuros (TARGET, todos novos — hoje nenhum existe):

    GET  /public/classes              lista de turmas registration_open/waitlist
    GET  /public/classes/{id}         card público da turma
    GET  /public/instructors          projeção mínima (opt-in)
    POST /pre-registrations           lead sem conta
    POST /class-applications          "Quero participar" (autenticado)
    GET  /me/applications             Minhas inscrições
    POST /class-applications/{id}/decision   aprovação por política
    POST /me/historical-claims        iniciar reivindicação de histórico
    (admin) import/reconcile de historical_participation_records

## 12. Funil de aquisição

    VISITOR → CONTENT_VIEW → PRE_REGISTRATION → ACCOUNT_CREATED
        → SPONTANEOUS_ACCESS
        OU
        → CLASS_APPLICATION → ACCEPTED → ENROLLED → ACTIVE_PARTICIPANT

`TARGET` — eventos append-only no stream de telemetria existente, escopo
`acquisition`, nunca como evidência acadêmica. Proibido interpretar:
`VISITOR` ≠ aluno; `PRE_REGISTRATION` ≠ matrícula; `CONTENT_VIEW` ≠
aprendizagem validada. Métricas: visitantes→leads, leads→contas,
contas→aplicações, aplicações→matrículas, tempo por etapa, município.

## 13. UX mínima (guidelines, não redesign)

Material 3, Poppins, azul `#093AF4`, vermelho `#FF341B`, amarelo
`#F6D846` (existentes). Regras para a superfície pública:

- Fundo neutro, cards claros e consistentes; azul reservado a CTA
  primário e identidade; nunca tela inteira azul/preto.
- Hierarquia: título curto orientado a benefício > subtítulo humano >
  CTA > cards. Zero linguagem técnica na superfície (sem "token",
  "v2", "sessão", IDs).
- Cartilha pública: capa + título + resumo + carga/público (já servidos
  por `/public/courses`).
- Estado vazio sempre com próximo passo ("Nenhuma turma aberta em
  Palmas → Entrar na lista de interesse").
- Operação ≠ ação principal: ferramentas de equipe fora desta Home.

Wireframes textuais (TARGET):

**Home pública**

    ┌──────────────────────────────┐
    │ Tutor TDS                    │
    │ Aprenda, participe e         │
    │ acompanhe sua formação.      │
    │ [Explorar cartilhas]         │
    │ [Ver turmas abertas] [Entrar]│
    │ ── Cartilhas em destaque ──  │
    │ (cards horizontais)          │
    │ ── Turmas abertas ──         │
    │ (cards com cidade/período)   │
    │ Como funciona · Já participei│
    └──────────────────────────────┘

**Cartilha pública** → capa, título, resumo, carga horária, público,
CTA "Quero aprender isso" (→ turmas ou pré-cadastro).

**Turmas abertas** → lista de cards do §6; filtro por município.

**Pré-cadastro** → 1 tela, campos do §4, pergunta do instrutor com
busca quando "Sim", CTA final com as 3 saídas.

**Escolha de instrutor** → lista pesquisável: nome público, município,
área; "Não tenho / prefiro não dizer" sempre disponível.

**Acesso espontâneo** → Home B: cartilhas, progresso pessoal local,
"Turmas abertas para você", aviso discreto "modo explorador — sem
vínculo acadêmico".

**Minha inscrição** → status humano por etapa ("Recebemos seu pedido" /
"Na lista de espera" / "Aprovado — finalize sua matrícula"), nunca
status interno.

## 14. Critérios de aceite (por wave)

- Visitante abre o app e vê cartilhas + turmas abertas sem login; nada
  de dado privado em payload público (teste de contrato).
- Pré-cadastro sem CPF persiste lead com consentimento; nenhum `users`,
  `Enrollment` ou presença é criado (teste de invariante).
- `ACESSO_ESPONTANEO`: conta sem turma consome conteúdo, e relatórios de
  frequência/capacitação/certificado **ignoram** esse caminho (teste).
- `Quero participar` cria `class_applications.applied`; `enrolled` só
  via transição autorizada; vagas respeitam `require_available_seat`.
- Importação histórica cria só `unmatched`; `verified` exige evidência
  ou humano; nenhum `users` nasce do import.
- Data Safety revisado antes de Wave B ir a staging.

## 15. Riscos e dependências

- **CPF obrigatório em `users`** força entidade separada para lead —
  aceito; não relaxar `cpf_digest` sem decisão.
- `REMOTE_CATALOG_ENABLED=false` hoje: Home pública pode começar com as
  9 cartilhas bundled antes de ligar catálogo remoto.
- `/public/*` sem auth: rate-limit/abuso precisam de decisão (hoje só
  cache 60s).
- Deep link `tutortds://` do #157 (não mergeado) pode ser reaproveitado
  depois para convites (`tutortds://class/{id}`), sem dependência dura.
- Overlap: PR #157 (check-in, aberto), #156 (metadata release, aberto),
  #146 (superseded). Nenhum conflito de arquivo com este doc.
- Instrutor em endpoint público: decisão de exposição pendente.

## 16. Rollout em waves (plano de implementação futuro)

| Wave | Escopo | Backend | Flutter | Migration | Staging | Human gate | Testes | Overlap |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A — Home pública | visitante vê cartilhas (`/public/courses` ou bundled) + shell público | nenhum | `welcome_screen`, `home_screen`, novo `public_catalog` repo | não | preview em staging | aprovar hierarquia/visual | widget: estados A vs C/D | nenhum |
| B — Pré-cadastro + acesso espontâneo | `pre_registrations`, tela + consentimento; Home B derivada | `public_api.py` ou novo `pre_registrations.py`, endpoints POST/GET | fluxo de cadastro, estado `ACESSO_ESPONTANEO` | sim (nova tabela) | seed de leads fake | Data Safety + retenção | API: lead não cria user/enrollment; widget: form + estados | baixo |
| C — Turmas públicas | `registration_status/policy` em classes + `GET /public/classes*` | `public_api.py`, admin de registration | listagem + card + filtro município | sim (colunas/tabela) | turmas planned+open | exposição de instrutor | contrato sem dados privados; vagas vs `require_available_seat` | baixo |
| D — Candidatura → matrícula | `class_applications` + decisões por política | novo `class_applications.py`, transições auditáveis | "Quero participar", "Minha inscrição", decisão instrutor/staff | sim (nova tabela) | E2E aplicação→enrolled | quem aprova por política | máquina de estados completa, idempotência, vagas | médio (toca enrollment) |
| E — Históricos ~500 | `historical_participation_records` + import + reconcile | import job + endpoints de claim/decisão | "Encontramos histórico", confirmação, revisão staff | sim (nova tabela) | subset importado | base legal + evidência mínima de match | import só cria unmatched; zero users auto; claim/reject | médio (dados reais) |
| F — Visual QA | polish geral das superfícies públicas | nenhum | telas A/B + presença aluno/instrutor | não | revisão em staging | aceite visual | golden/a11y | baixo |

Ordem sugerida: A→B→C→D→E, F transversal após C. B e C são
independentes entre si; D depende de C; E é independente (pode ir em
paralelo com D se houver revisão humana de dados).

`DECISION-NEEDED` (consolidado, para o gate humano):
1. Política editorial por cartilha: `PUBLIC_PREVIEW`/`PUBLIC_FULL`/
   `AUTHENTICATED_ONLY`/`ENROLLED_ONLY` (hoje tudo bundled é full).
2. `instructor_display_name` em API pública: opt-in por instrutor?
3. `ACESSO_ESPONTANEO` como estado derivado vs `ProgramMembership`
   futuro — recomendado derivado.
4. `registration_*` como colunas em `classes` vs tabela própria.
5. Rate limit/abuso nos endpoints `/public/*`.
6. Base legal/retenção dos leads e dos registros históricos.
