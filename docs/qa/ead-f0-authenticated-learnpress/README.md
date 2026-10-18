# F0 — Evidência autenticada LearnPress EAD (Issue #252)

Data da execução: 2026-10-18 · Ambiente: sandbox WP/LearnPress 100% sintético em dfd627
(`/workspace/tds-wp-sandbox-20261017`, `php -S 127.0.0.1:18731`, SQLite, WP 7.1.3,
LearnPress + `tds-portal-core` + `tds-learnpress-editorial` + child theme 0.2.1).
Escopo: somente leitura/escrita sintética. `MERGE_ALLOWED=NO PRODUCTION_ALLOWED=NO`.
Nenhum dado real, token, cookie ou senha aparece neste documento nem nos artefatos.

## Inventário de configuração (OBSERVED)

| Item | Valor observado |
|---|---|
| Servidor | `php -S` CLI built-in, single-thread (curl exige `--max-time`) |
| Banco | SQLite via plugin sqlite-database-integration (`wp_` prefix), DB `tdsqa` |
| WP | 7.1.3; LearnPress REST v1 em `/wp-json/learnpress/v1` |
| JWT | exige `LP_SECURE_AUTH_KEY` ou `SECURE_AUTH_KEY` definida; sem ela → 403 `lp_jwt_auth_bad_config` |
| Páginas | `learn_press_profile_page_id`=16 (`/minha-area/`); courses page=6; 16/17/18/19 existem |
| Usuários sintéticos | student-a (id 3), student-b (id 4), instructor-QA (id 5, role editor — LP não tem `lp_teacher` neste install) |
| Curso | 23 (publish), lição 24 (publish), lição 25 (draft), quiz 26 (publish) + questão 27 `true_or_false` |

## Matriz OBSERVED / TARGET / UNKNOWN / BLOCKED

| # | Rota/ação | OBSERVED | Recibo |
|---|---|---|---|
| J01 | `POST learnpress/v1/token` | 200, campo `token` **top-level** (não `data.token`); HS256, `exp` ≈ iat+604800 (7d) | J01/J02 |
| J03 | `POST .../token/validate` | 200; devolve `exp` | J03 |
| J04 | `GET wp/v2/users/me` com JWT LP | **401** — JWT LP não autentica WP core REST | J04 |
| J05 | `GET learnpress/v1/users` sem token | **200** diretório público (campos limitados; email ausente na amostra — confirmar em prod) | J05 |
| — | sem `Authorization` | 401 `lp_jwt_auth_no_auth_header` | Q05 |
| E01 | `POST courses/enroll {"id":23}` | 200 `Congrats! You have enrolled…` + `redirect` para próxima lição | E01/E06 |
| E02 | re-enroll mesmo usuário | erro `This course is already enrolled!` — **não idempotente**; prevenção server-side via erro | E02 |
| E03 | enroll com `user_id` explícito | parâmetro **ignorado** (matricula o dono do token) | E03 |
| L01 | `POST lessons/finish` inscrito | 200; user_item lesson → `completed/passed` | L01 |
| L02 | lessons/finish não inscrito | **403** `lp_jwt_rest_cannot_view` | L02 |
| L03 | lessons/finish guest | **401** | L03 |
| P01/P02 | `GET users/{id}` próprio | 200 | P01/P02 |
| P03 | `GET users/{id}` de outro | **403** — IDOR bloqueado | P03 |
| Q01 | `POST quiz/start` inscrito | 200; cria user_item `started`; payload traz `question_ids`, `questions[].options[]` com `value`+`uid` | Q01/Q06 |
| Q02 | `POST quiz/check_answer` | HTTP 200 mas `status:"error" "Cannot check the answer…"` em todos os shapes testados (string e objeto) — **parcial/UNKNOWN** | Q02* |
| Q03 | `POST quiz/finish {"id":26,"answered":{"27":"true"}}` | 200 `results`: `questions.27.correct=true, mark=1, user_mark=1, result=100, pass=1, status:"completed"`; user_item → `completed/passed` | Q08 |
| Q04 | quiz/start não inscrito | **403** | Q04* |
| Q05 | quiz/start guest | **401** | Q05 |
| C01 | `POST courses/finish` | 200; user_item curso → `finished/passed` | C01 |
| Q06 | quiz/start **após** course finish | **403** — finalizar o curso trava mutações subsequentes dos itens via REST | Q02b-Q03b |
| D01 | `GET lessons/25` (draft) autenticado | **403** | D01 |
| W01 | login UI (form WP) | 302 + cookies; guest vê CTA "conta EAD" | W01/W02 |
| W03 | `/certificados/` logada | 200; conteúdo separa "Certificado oficial do Programa TDS" de "Conclusão de curso no EAD" | W03b |
| W04 | `/minha-area/student-a/` como B | **200** — shell de perfil LP é público/visível; edição segue restrita ao dono | W04 |
| W05 | logout UI + reuso do JWT | JWT é stateless (HS256+exp); logout WP não revoga — sem endpoint de revogação na API | UNKNOWN→OBSERVED (código) |
| CERT | emissão de certificado | Sem addon de certificado LP instalado → **BLOCKED** por design (ADR: certificado oficial é FastAPI/TDS) | — |

### Comportamentos relevantes para o contrato F1/F2

1. **Param de matrícula é `id`** (`courses/enroll {"id":23}`), não `course_id` — erro "Invalid course!" com o nome errado.
2. **Enroll não é idempotente**: a duplicata retorna erro legível; o app precisa checar estado antes ou tratar o erro como "já inscrito".
3. **`user_id` no enroll é ignorado** — sempre o dono do token; não existe matrícula delegada via JWT.
4. **Ordem importa**: `courses/finish` antes do quiz torna quiz/start|check_answer|finish 403 para aquele usuário. O app deve oferecer quiz antes de concluir o curso.
5. **`check_answer` retorna erro funcional** mesmo autenticado/inscrito nos shapes testados → usar `quiz/finish` com `answered:{qid:valor}` como caminho suportado (UNKNOWN se há shape alternativo).
6. **JWT não cobre WP core REST** (`/wp/v2/*`) — F1 não pode assumir que o token LP autentica endpoints WP genéricos.
7. **Diretório `/learnpress/v1/users` é público** (200 sem token, campos limitados) — revisar exposição antes de produção; perfil LP via UI também é visível a outros logados (`/minha-area/<user>/` 200).
8. **Logout WP não revoga JWT** — token segue válido até `exp` (7d). Para F1/F2: considerar TTL curto + refresh ou blacklist própria.
9. **Sem lp_teacher neste install**: instrutor QA usou role `editor` — a capacidade de gestão de curso via REST para "professor" fica UNKNOWN.
10. **Certificado EAD inexistente** sem addon LP — conclusão de curso ≠ certificado TDS (ADR #249 mantém autoridade no FastAPI).

## Reproduzir

```bash
cd tooling/qa/learnpress_f0
cp f0_env.example.sh f0_env.sh   # preencher credenciais/IDs sintéticos
source f0_env.sh
BASE_URL=http://127.0.0.1:18731 ./f0_run.sh <dir_evidencia>
```

Substitua `COURSE_ID/LESSON_ID/QUIZ_ID/QUESTION_ID/USER_*_ID` no runner pelos IDs do
cenário sintético (23/24/26/27/3/4 no sandbox de referência). Saída: recibos
`ID|METHOD|PATH|HTTP|body≤300c` + arquivos `*.body` sanitizados (token/senha redigidos).

## Limites da evidência

- `php -S` single-thread: requests concorrentes/keep-alive podem travar; evidência é de contrato de rota, não de performance.
- Child theme no sandbox = 0.2.1 (repo = 0.3.0, PR #251) — diferença apenas de apresentação, não de contrato REST.
- `check_answer` UNKNOWN; emissão de certificado BLOCKED por ausência de addon (decisão, não defeito).
