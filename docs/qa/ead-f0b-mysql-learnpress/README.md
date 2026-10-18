# F0b — Contrato LearnPress EAD em MySQL sintético

**Status:** TESTED-LOCAL (sandbox dfd627, MariaDB 10.11.14, sem dados reais)
**Data:** 2026-10-18 · **Complementa:** F0 SQLite (`docs/qa/ead-f0-authenticated-learnpress/`, PR #254, Issue #252)

## Ambiente

- Host: dfd627 (mesma VM do F0); segunda instância WP isolada em
  `/workspace/tds-wp-sandbox-20261017/wordpress-mysql`, servida por
  `php -S 127.0.0.1:18732` + `router-mysql.php`.
- **MariaDB 10.11.14** (apt `mariadb-server`), banco `tdsqam`, usuário
  `tdsqa`/`synthetic-only` — credenciais sintéticas efêmeras, sem bind externo.
- Mesmos plugins/tema do F0: LearnPress, tds-learnpress-editorial,
  tds-portal-core, tds-child-theme. Sem plugin sqlite-database-integration.
- Mesmas contas sintéticas: student-A/B (subscriber), instructor-QA (editor),
  qa-admin. Currículo sintético recriado: course=11, lesson=12, quiz=14,
  question=15.

## Resultado — paridade com o contrato F0 (SQLite)

| comportamento | SQLite F0 | MySQL F0b | paridade |
|---|---|---|---|
| `token` emite JWT; senha errada 403 | ✔ | ✔ | igual |
| `token/validate` 200 exp 7d | ✔ | ✔ | igual |
| JWT LP não cobre `/wp/v2/users/me` → 401 | ✔ | ✔ | igual |
| `/learnpress/v1` sem header → 401 | ✔ | ✔ | igual |
| `/learnpress/v1/users` público 200 | ✔ | ✔ | igual |
| enroll param `course_id` → "Invalid course!" | ✔ | ✔ | igual |
| enroll `id:11` → success; 2ª vez → "already enrolled" (não-idempotente) | ✔ | ✔ | igual |
| `lessons/finish` sem start → "You have not started lesson" | ✔ | ✔ | igual |
| finish sem token → 401 `no_auth_header` | ✔ | ✔ | igual |
| lesson/quiz de item sem matrícula → 403 `cannot_view` | ✔ | ✔ | igual |
| `courses/finish` sem avaliação → "Course not pass" | ✔ | ✔ | igual |
| usuário A ler perfil LP de B → 200 (diretório público) | ✔ | ✔ | igual |
| WP login UI → 302 + cookie `wordpress_logged_in` | ✔ | ✔ | igual |
| páginas UI `/minha-area/...` com cookie | ✔ | ✔ (W01–W04) | igual |

**Conclusão F0b:** o contrato homologado no F0 (matrícula não-idempotente,
JWT separado do WP core, ACL de itens, negações 401/403, diretório público)
**se mantém em MySQL** — a camada de política do app (PR #260) não precisa
de branches por backend.

## Diferenças observadas (novo vs F0)

1. **DDL das respostas de quiz:** `learnpress_question_answers` em MySQL usa
   coluna `order`; na instalação via sqlite-database-integration a coluna era
   `ordering`. Scripts de fixture precisam detectar o dialeto (o F0b inseriu
   com `order`).
2. **`quiz/start` retornou `question_ids:[]`** apesar da questão 15 linkada ao
   quiz 14 (mesma técnica do F0). Não investigado a fundo — possível diferença
   de join/ordenação ou meta ausente em MySQL. `quiz/finish` completou com 0
   questões. Registrar como UNKNOWN: revisar linking de questões em fixture
   MySQL antes de usar quiz como gate de avaliação.
3. `courses/finish` retornou "Course not pass" (quiz sem questões) — mesmo
   código de erro, mas por causa diferente da cadeia do F0.

## Execução

```bash
# MariaDB já instalada; banco tdsqam criado; instância clonada sem SQLite.
BASE=http://127.0.0.1:18732 bash f0_run_mysql.sh   # ids remapeados 23→11, 24→12, 26→14, 27→15
# caminho feliz manual (paridade de contrato):
enroll id=11 → success / already-enrolled
lessons/finish id=12 → "You have not started lesson"
quiz/start id=14 → started (question_ids vazio)
quiz/finish id=14 answered={15:"true"} → completed, 0 questões
courses/finish id=11 → "Course not pass"
```

Evidência: `http-evidence/f0-20261018-150036/` no dfd627 (bodies sanitizados,
tokens nunca persistidos — `*.tok` apenas temporários, `.raw` com token não
commitado).

## Limites / fora de escopo

- `check_answer` não re-testado em MySQL (permanece UNKNOWN do F0).
- Retake/attempts, tempo decorrido, certificado EAD — fora de escopo.
- Nenhum merge, nenhuma escrita em produção; credenciais efêmeras do sandbox.
