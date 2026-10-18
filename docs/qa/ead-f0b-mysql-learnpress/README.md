# F0b — Contrato LearnPress EAD em MySQL sintético

**Status:** RUNNER-REPRODUCIBLE — fluxo EAD completo homologado (enroll→lição→quiz avaliado→conclusão→lock)
**Data:** 2026-10-18 · **Complementa:** F0 SQLite (`docs/qa/ead-f0-authenticated-learnpress/`, PR #254, Issue #252)

## Ambiente

- Host: dfd627 (mesma VM do F0); segunda instância WP isolada em
  `/workspace/tds-wp-sandbox-20261017/wordpress-mysql`, servida por
  `php -S 127.0.0.1:18732` + `router-mysql.php`.
- **MariaDB 10.11.14**, banco `tdsqam`, usuário `tdsqa`/`synthetic-only` —
  credenciais sintéticas efêmeras, sem bind externo.
- Mesmos plugins/tema do F0: LearnPress, tds-learnpress-editorial,
  tds-portal-core, tds-child-theme. Sem sqlite-database-integration.
- Contas sintéticas: student-A=2, student-B=3 (subscriber), instructor-QA=4
  (editor), qa-admin=1. Currículo: course=11, lesson=12, hidden lesson=13,
  quiz=14, question=15.

## Paridade com o contrato F0 (SQLite) — homologada por runner

| comportamento | esperado | MySQL F0b | paridade |
|---|---|---|---|
| `token` emite JWT; senha errada | 200 / 403 `incorrect_password` | idem | igual |
| `token/validate` | 200 `valid_token` exp 7d | idem | igual |
| JWT LP não cobre `/wp/v2/users/me` | 401 `not_logged_in` | idem | igual |
| `/learnpress/v1` sem header | 401 `no_auth_header` | idem | igual |
| `/learnpress/v1/users` (lista) | 200 público | idem | igual |
| enroll sem token | 401 | idem | igual |
| enroll param `course_id` (nome errado) | 200 "Invalid course!" | idem | igual |
| enroll `id` A e B → sucesso | 200 "enrolled in the course" | idem | igual |
| re-enroll (não-idempotente) | 200 "already enrolled" | idem | igual |
| `lessons/finish` sem start | 200 "You have not started lesson" | idem | igual |
| `lessons/finish` sem token | 401 | idem | igual |
| `lessons/finish` aluno não inscrito | 403 `cannot_view` | idem | igual |
| lição oculta `GET lessons/{draft}` | 403 `cannot_view` | idem | igual |
| `GET users/{self}` | 200 | idem | igual |
| `GET users/{outro}` (IDOR) | 403 `rest_user_cannot_view` | idem | igual |
| `quiz/start` sem matrícula / sem token | 403 / 401 | idem | igual |
| lição "started" somente via page view | sem rota `lessons/start` (404) | idem | igual |
| `quiz/finish` com resposta correta | `result=100, pass=1` | idem | igual |
| `courses/finish` após avaliação | 200 "completed the Course" | idem | igual |
| lock pós-`courses/finish` (lição/quiz) | 403 `cannot_view` | idem | igual |
| `courses/finish` repetido | "The course has finished." | idem | igual |
| `courses/finish` sem avaliação aprovada | 200 "Course not pass" | idem | igual |
| WP login UI | 302 + `wordpress_logged_in` | idem | igual |

**Conclusão:** os comportamentos de autenticação, matrícula, ACL de itens,
avaliação e negações se mantêm em MySQL — a camada de política do app
(PR #260) não precisa de branches por backend.

## Diferenças observadas

1. **DDL das respostas:** `learnpress_question_answers` usa coluna `order`
   em MySQL vs `ordering` na instalação sqlite-integration. O fixture deve
   detectar o dialeto — helper `tooling/qa/learnpress_f0/lp_question_answers_col.php`
   (executar via `wp eval-file`, retorna `order` ou `ordering`).
2. **Linking quiz↔questão:** `learnpress_quiz_questions` exige colunas
   `quiz_id`, `question_id`, `question_order` — um INSERT com coluna
   `params` (schema antigo/SQLite) falha silenciosamente e deixa
   `question_ids:[]`. Corrigido no fixture MySQL (linha 14↔15 criada);
   após isso `quiz/start` retornou a questão e `quiz/finish` avaliou
   (result=100, pass=1, passing_grade=80%).
3. **Contrato novo homologado:** não existe rota REST `lessons/start` —
   a lição é marcada "started" ao visitar o permalink da lição autenticado
   (cookie WP). O app (PR #260) precisa tratar isso: `lessons/finish` sem
   page view prévio retorna "You have not started lesson".
4. `check_answer` responde "Cannot check the answer to the question."
   mesmo com quiz em progresso e payload correto — permanece UNKNOWN
   (mesmo status do F0).

## Execução (RUNNER-REPRODUCIBLE)

```bash
export BASE_URL=http://127.0.0.1:18732            # recusa host não-loopback
export QA_USER_A=student-A QA_PASS_A='...' QA_USER_B=student-B QA_PASS_B='...'
export COURSE_ID=11 LESSON_ID=12 LESSON_DRAFT_ID=13 QUIZ_ID=14 QUESTION_ID=15
export USER_A_ID=2 USER_B_ID=3
./tooling/qa/learnpress_f0/f0_run_mysql.sh <evidence_dir>
```

O runner parametriza IDs por env (rejeita vazios/não-numéricos), valida que
`BASE_URL` é loopback antes de qualquer POST, **nunca persiste JWT** (token
em variável de shell; evidência recebe body com `"token":"REDACTED"`), e
assertra HTTP + regex por caso com exit não-zero em falha. Credenciais
sintéticas via `f0_env.sh` local (gitignored) ou env.

Evidência da execução 2026-10-18: `http-evidence/f0b-run2/` no dfd627 —
**33 PASS / 0 FAIL**, incluindo caminho feliz E2E (enroll → page view →
`completed the lesson` → quiz `result=100 pass=1` → `completed the Course`
→ lock pós-finish) e negativos A/B (401 guest, 403 não-inscrito, 403 IDOR).

## Limites / fora de escopo

- `check_answer`: erro de aplicação em ambos os backends — UNKNOWN.
- Retake/attempts, certificado EAD, produção — fora de escopo.
- Nenhum merge, nenhuma escrita em produção.
