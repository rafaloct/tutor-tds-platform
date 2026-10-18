# F3c — Contrato de leitura autenticada LearnPress (EadMyAreaReader / EadAccountReadSnapshot)

**Issue:** [#268](https://github.com/rafaloct/tutor-tds-platform/issues/268)
**Ambiente:** WordPress 6 + LearnPress sobre MariaDB 10.11, sintético, isolado — `http://127.0.0.1:18732` na VM dfd627 (instância `wordpress-mysql`). Nenhum dado real; usuários, curso e progresso são fixtures QA.
**Runner:** `tooling/qa/learnpress_f3_readonly/f3_readonly.sh` — 30 PASS / 0 FAIL (evidência `f3c-run3`, reproduzível).
**Contrato alvo:** `EadMyAreaReader` / `EadAccountReadSnapshot` do PR #266 (branch `agent/ead-account-read-contract`, HEAD `82da8f5`).

## Regras de execução respeitadas

- Somente `GET` comprovadamente sem side-effects + `POST /token` (sessão efêmera sintética).
- **PROIBIDO** GET de permalink de lição/página de aprendizado — muda estado para `started` (fato F0). Não executado.
- Nenhuma chamada enroll / finish / quiz-start / quiz-finish / upload / edição / certificado.
- Estado `wp_learnpress_user_items` **idêntico** antes/depois da sonda (prova de read-only).
- Nenhum JWT, cookie, senha, CPF, HTML autenticado ou header persistido — evidência é projeção allowlist (`extract_*.py`). Bodies de autenticação gravam stub `{"receipt":"auth body not stored"}`.
- `BASE_URL` validada por `urlparse` real (host literal `127.0.0.1`/`localhost`, sem userinfo/path); `--max-filesize 262144`, `--max-time 20`, sem `-L`; redirect não-vazio → FAIL.

## Matriz de endpoints (OBSERVED)

| # | Método | Path | Audiência | Comportamento por audiência | Mutação de estado | Confiança |
|---|--------|------|-----------|------------------------------|-------------------|-----------|
| R01 | GET | `/learnpress/v1` | authed | 200 — índice de 29 rotas | nenhuma | alta |
| J01–J03 | POST | `/learnpress/v1/token` | público | emite JWT (único POST permitido; evidência=stub) | nenhuma | alta |
| T01 | — | claims JWT | — | `exp−iat = 168h` (7d); sem revogação por logout | nenhuma | alta |
| R02/R02b/R07 | GET | `/users/{self}` | self | 200 — `tabs.courses.content.enrolled` **vazio mesmo com matrícula** (A finished e B enrolled → 0); `tabs.quizzes.content` carrega resultados reais (A `passed:[14]`) | nenhuma | alta |
| R03 | GET | `/users/{other}` | authed≠alvo | 403 `rest_user_cannot_view` | nenhuma | alta |
| R04 | GET | `/users/{self}` | guest | 401 `rest_forbidden` | nenhuma | alta |
| R05 | GET | `/users/99999` | authed | 404 `rest_user_invalid_id` | nenhuma | alta |
| R06 | GET | `/users/{id}` | token inválido | 401 `rest_forbidden` | nenhuma | alta |
| R08–R10 | GET | `/courses/{id}` | authed | 200 com `course_data` **por usuário** (ver mapeamento) | nenhuma | alta |
| R11 | GET | `/courses/{id}` | guest | 200 com `course_data` **vazio** (`status=''`, `count_items:0`) — não distingue "não inscrito" de "não autenticado" | nenhuma | alta |
| R12 | GET | `/courses/99999` | authed | 403 `lp_jwt_rest_not_in_post_type` (não 404) | nenhuma | alta |
| R13 | GET | `/courses` | guest | 200 — catálogo público `[{id:11}]`; não carrega escopo de usuário | nenhuma | alta |
| R14 | GET | `/lessons/{id}` | inscrito | 200 — objeto completo inclui `content` HTML, `results`, `assigned` | nenhuma | alta |
| R15 | GET | `/lessons/{id}` | guest | 401 | nenhuma | alta |
| R16 | GET | `/lessons/{id}` | authed não-inscrito | 403 | nenhuma | alta |
| R17 | GET | `/lessons/{draft_id}` | authed | 403 (draft invisível a aluno) | nenhuma | alta |
| R18 | GET | `/quiz/{id}` | inscrito | 200 — `questions[]` embutidas (`count=1`); **sem** `question_ids` no shape GET | nenhuma | alta |
| R19 | GET | `/quiz/{id}` | authed não-inscrito | 403 | nenhuma | alta |
| R20 | GET | `/quiz/{id}` | guest | 401 | nenhuma | alta |
| R21 | GET | `/questions/{id}` | inscrito | 403 (questão não é lida isoladamente) | nenhuma | alta |
| R22 | GET | `/section-items/items/{sec}` | authed | 200 — inclui `user_status` por item + itens em `draft` | nenhuma | alta |
| R23 | GET | `/section-items/items/{sec}` | guest | 200 — **vaza `name`/`post_status` de item draft** (ver achados) | nenhuma | alta |
| R24 | GET | `/courses/{id}` | authed (re-leitura) | 200 idêntico a R09 — sem vazamento de cache entre usuários | nenhuma | alta |

Nenhum endpoint observado redirecionou (`redirect_url` vazio em todos).

## Mapeamento `EadAccountReadSnapshot` (origem → contrato)

### Raiz do snapshot

| Campo do contrato | Origem OBSERVED | Classe | Nota |
|---|---|---|---|
| `wpUserId: int` | `users/{id}.id` (self) | OBSERVED | exige token válido do próprio usuário |
| `environmentId: String` | não existe no servidor | TARGET | constante do cliente/broker (`"wp-lp-mysql-qa-sandbox"` na fixture) |
| `observedAt: DateTime` | não existe no servidor | TARGET | timestamp da leitura gerado pelo reader |
| `authenticatedLearnPressOrigin: bool` | `users/{id}` 200 + `courses/{id}` com `course_data` não-vazio | OBSERVED (derivado) | guest recebe `course_data` vazio → **nunca** afirmar origem autenticada sem esse par de sinais |
| `courses: List<EadAreaCourse>` | ver abaixo | OBSERVED+derivado | fonte primária = `courses/{id}` por curso conhecido; **não existe** GET "meus cursos" (ver lacuna L1) |

### `EadAreaCourse` por curso

| Campo do contrato | Origem OBSERVED em `GET /courses/{id}` | Classe | Nota |
|---|---|---|---|
| `wpCourseId` | `id` | OBSERVED | |
| `title` | `name` | OBSERVED | |
| `enrollment.enrolled` | `course_data.status == "enrolled"` → true; `"finished"` → `completed` | OBSERVED→derivado | `status=''` ⇒ **excluir curso** (não afirmar "não inscrito" sem sinal positivo) |
| `enrollment.completed` | `course_data.status == "finished"` | OBSERVED→derivado | |
| `progressPercent` | `course_data.result.result` (int 0–100) | OBSERVED | só quando `status` não-vazio; `result=0` em "enrolled" é **progresso zero real** (B recém-inscrito), não "desconhecido" — ver UNKNOWN U2 |
| `nextLesson` | **derivado**: primeiro item de `sections[].items[]` com `status!="completed" && !locked`, na ordem do currículo | derivado | servidor não expõe "next" nativo; título do item está em `items[].title` |
| `resumeAuthorized` | **derivado**: `enrollment==enrolled && next_item existe && !next_item.locked` | derivado | `locked` é por usuário: A (finished) → `true` nos itens; B → `false`; C (não-inscrito authed) → `true`; guest → `false`. Exige broker confirmando vínculo — nunca derivar de catálogo |
| `start_time` / `end_time` | `course_data.start_time/end_time` | OBSERVED | ⚠ em respostas de escopo vazio `start_time` = timestamp da requisição (não confiável) |

### Estados de snapshot/link (contrato PR #266)

| Estado | Origem | Classe |
|---|---|---|
| `linked` + `current` | par `users/{id}` 200 + `course_data.status` não-vazio | OBSERVED |
| `linked-no-enrollments` | `users/{id}` 200 com `course_data.status==''` em todos os cursos | OBSERVED (C) |
| `loginRequired` | `401 rest_forbidden` (guest ou token inválido) | OBSERVED |
| `forbidden` | `403` em self-scoped (`rest_user_cannot_view`, `lp_jwt_rest_not_in_post_type`) | OBSERVED |
| `unknown` / `stale` / `offline` / `disconnected` | sem conceito no servidor — exclusivos do cliente | TARGET/synthetic |
| `unavailable`/`error` | não provocado (sem falha 5xx no sandbox) | TARGET |

## Lacunas e UNKNOWNs

- **L1 — "meus cursos" não existe:** nenhum GET retorna a lista de cursos do usuário. `users/{id}.tabs.courses.content.enrolled` é **vazio até para inscritos** (R02, R02b) — **não usar**. O reader precisa da lista de `course_id` conhecidos (catálogo/broker) e chamar `courses/{id}` por curso. ⚠ custo = N requests.
- **L2 — última lição visitada:** nenhum endpoint expõe "last visited". O sinal `started` só é gravado via page view autenticado (proibido ler aqui e mutante por natureza). `nextLesson` derivado ≠ "última visitada".
- **U1 — progresso por item:** `sections[].items[].status` ∈ `{"", "completed"}` — não há "in-progress" percentual por item. `user_status` em `section-items` tem mesma granularidade.
- **U2 — granularidade do percentual:** `result.result` é inteiro 0/100 observados; valores intermediários não foram gerados (B parou antes de completar itens → 0). Percentual parcial presume-se possível mas **não comprovado**.
- **U3 — `evaluate_type`:** observado `evaluate_lesson`; outras políticas (quiz-based) podem mudar o significado de `result` — derivar apenas com `evaluate_type` conhecido.
- **U4 — cache isolation entre usuários:** re-leituras idênticas (R09≡R24) sugerem sem vazamento; não provado sob cache de página/agressivo.
- **U5 — `has_results`/`has_assigned` em `lessons/{id}`:** campos presentes mas formato interno não mapeado (não extraído por allowlist). Potencial fonte de "resultado por item" — UNKNOWN.

## Achado de vazamento de dados (registrar)

`GET /learnpress/v1/section-items/items/{section_id}` retorna **200 para guests** e expõe `name`, `post_status`, `type` de itens **em rascunho** (item 13 "Aula privada QA não publicar" — draft — visível sem autenticação). Não bloqueia o contrato, mas deve entrar no relatório de segurança do site EAD: currículo rascunho vaza título estrutural para anônimos.

## Proposta de adapter (server-side `EadMyAreaReader`, após aprovação do broker)

```
read(link: EadAccountLink) -> EadAccountReadSnapshot
  1. GET users/{link.wpUserId}  (Bearer JWT LP)
       401/403  → throw EadAccountReadException(loginRequired|forbidden)
       404      → link inválido → exception(forbidden)
  2. para cada courseId do catálogo/broker:
       GET courses/{id}
         course_data.status == ''      → curso ausente (não listar)
         'enrolled' → enrollment=enrolled
         'finished' → enrollment=completed
         progressPercent = int(result.result) | null se ausente
         nextLesson      = primeiro sections.item com status!="completed" && !locked
         resumeAuthorized= enrolled && nextLesson!=null   [+ verificação do broker]
  3. authenticatedLearnPressOrigin = (passo 1 == 200)
  4. snapshotState=current | stale/offline derivado de observedAt pelo cliente
```

**Regras duras do adapter:** nunca chamar REST autenticado sem vínculo verificado; nunca inferir matrícula de `/courses` (catálogo) ou `/users` público; `progressPercent=null` quando `result` ausente — nunca 0 por convenção; guest `course_data` vazio ⇒ `loginRequired`, não "sem cursos".

## Reprodução

```bash
# no dfd627, /workspace/tds-wp-sandbox-20261017/f3_readonly/
source ../f0_env.sh   # credenciais sintéticas (não commitadas)
BASE_URL=http://127.0.0.1:18732 \
QA_USER_A=student-A QA_PASS_A="$QA_PASS_A" \
QA_USER_B=student-B QA_PASS_B="$QA_PASS_B" \
QA_USER_C=student-C QA_PASS_C='…' \
COURSE_ID=11 LESSON_ID=12 LESSON_DRAFT_ID=13 QUIZ_ID=14 QUESTION_ID=15 \
USER_A_ID=2 USER_B_ID=3 USER_C_ID=5 SECTION_ID=1 \
bash f3_readonly.sh <evidence_dir> <fixture_out_dir>
```

Estado de fixture esperado: `user_items` — A(2): course 11 `finished`, lesson 12 `completed`, quiz 14 `completed`; B(3): course 11 `enrolled`, lesson 12 linha vazia; C(5): sem linhas.

## Limites e fora de escopo

- Não implementa SSO, broker real ou integração Flutter — só contrato de leitura + fixtures.
- Não provoca falhas 5xx/timeout (estado `unavailable` permanece TARGET).
- Fixtures `disconnected/unknown/stale-offline/linked-enrolled-progress-unknown` são **synthetic targets** — marcados `_label:"synthetic target"` com observação de suporte; não promovidos a OBSERVED.
- Sandbox sintético MariaDB apenas; produção intocada.

**Próximo human gate:** aprovação do broker/protocolo de vínculo de identidade TDS↔EAD para que `authenticatedLearnPressOrigin` e `resumeAuthorized` possam ser preenchidos por uma implementação server-side real.
