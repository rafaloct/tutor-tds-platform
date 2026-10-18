# Auditoria ACL — `learnpress/v1/section-items/items/{id}` (Issue #270)

Auditoria e correção, no sandbox sintético MariaDB `127.0.0.1:18732` (dfd627),
do vazamento de metadados de itens **não-publicados** pela rota pública do
LearnPress. Nada em produção; nenhuma conclusão sobre o site público.

## Causa-raiz (LearnPress 4.3.6, vendor — OBSERVED no código)

`inc/jwt/rest-api/version1/class-lp-rest-section-items-v1-controller.php`:

1. `get_items_permissions_check` exige apenas `section_id` válido + **curso
   público** — retorna `true` para guest, aluno, qualquer um.
2. `get_section_items` → `LP_Section_DB::get_section_items_by_section_id`
   (`inc/Databases/class-lp-section-db.php`): a query **não filtra
   `post_status`** — itens `draft`/`pending`/`private` voltam na lista.
3. `get_sections_data` emite `name`, `slug`, `status`, `type`, `preview`,
   `duration`, `locked` para todos; `permalink`/`content`/`user_status`/
   `graduation` já são gated por `can_view_item` (saem vazios p/ guest).

Resultado OBSERVED (reprodução `EXPECT=leak`, 5/5 audiências): guest, aluno
inscrito, aluno não-inscrito, instrutor/editor e administrador recebem
`id`, `type`, `post_status` e `name` (mascarado na evidência como
`name_present`) de um item `draft` da seção pública. O endpoint
`courses/{id}` **não** tem o mesmo defeito — suas `sections[].items[]`
já omitem itens não-publish.

## Correção — camada de extensão (não-vendor)

`wordpress/tds-lp-section-items-acl/tds-lp-section-items-acl.php` — plugin
single-file, hook `rest_request_after_callbacks` restrito ao
route `^/learnpress/v1/section-items/items/\d+$`:

- Para cada item da resposta, confere `get_post($id)->post_status`.
  Não-`publish` é removido da resposta **a menos que** o chamador possa
  moderar os itens do curso:
  `manage_options` (admin) ∨ `edit_others_posts` (editor) ∨
  `post_author` do curso pai (instrutor) ∨ `edit_post(curso)`.
- **Fail-closed ×2** (revisão de coordenação):
  1. o curso pai precisa resolver como `$course_id > 0` + `WP_Post` real com
     `post_type === 'lp_course'` **antes** de qualquer exceção de privilégio
     — `get_post(0)` cairia no post global do WP; id inválido nunca concede
     acesso editorial (nem para admin — seção órfã ⇒ tudo oculto);
  2. payload não-array em `get_data()` → resposta negada com conjunto vazio
     explícito para não-moderadores (corpo bruto nunca é repassado).
- Recalcula `X-WP-Total`/`X-WP-TotalPages` após a filtragem.
- Não registra rotas, não toca matrícula/progresso, não altera outros
  endpoints — reversível por desativação.

Nota de caps: `lp_lesson`/`lp_quiz` usam `capability_type=lp_lesson` com
`map_meta_cap=true` — nenhum papel WP do sandbox possui `edit_lp_lesson`
(nem admin). Por isso a escada de privilégio usa caps **de posts/core** e
autoria do curso, não a cap customizada do item.

## Matriz de audiência (assertiva — `tooling/qa/learnpress_section_items_acl/`)

| audiência | sem guarda (`EXPECT=leak`) | com guarda (`EXPECT=protected`) |
|---|---|---|
| guest | draft visível | **oculto** |
| aluno inscrito (subscriber) | draft visível | **oculto** |
| aluno não-inscrito | draft visível | **oculto** |
| instrutor (editor + autor do curso) | visível | visível |
| administrador | visível | visível |

Re-execuções no sandbox:

- `acl-leak2`: **5 PASS / 0 FAIL** (vulnerabilidade reproduzida — teste falha
  quando a proteção está ausente, conforme exigido)
- `acl-protected2`: **8 PASS / 0 FAIL** (draft oculto p/ não-moderadores,
  visível p/ moderadores, `X-WP-Total` recalculado, catálogo público com
  2 itens `publish` preservado, **seção órfã fail-closed** — draft oculto
  até para admin quando o curso pai não resolve como `lp_course`)
- `acl_unit_tests.php` via `wp eval-file`: **14 PASS / 0 FAIL** —
  course_id≤0/não-lp_course/inexistente nega até admin; payload string/
  objeto → `[]` + `X-WP-Total=0`; lista mista → só publish; moderador
  passthrough; rota não-relacionada intocada
- Regressão: `courses/{id}` guest 200, `lessons/{id}` guest 401,
  `users/{id}` guest 401 — inalterados; `wp_learnpress_user_items` sem
  mudança (somente GETs, nenhum permalink de lição chamado)

## Rollback

`wp plugin deactivate tds-lp-section-items-acl` — restaura 100% o
comportamento upstream. Nenhuma migração/DB/opção persistida pelo plugin.

## Sobreposição e limites

- PR #238 (`wordpress/tds-learnpress-editorial/`): sem sobreposição de
  arquivos; o guard é diretório próprio `wordpress/tds-lp-section-items-acl/`.
- PR #251 (`wordpress/tds-child-theme/`): sem sobreposição; o guard é
  plugin, não tema — tema continua sem depender dele.
- F3c (#269): os achados de `section-items` lá documentados eram do
  comportamento **upstream**; com o guard ativo o draft deixa de aparecer
  (mudança intencional — fixtures F3c não dependem do draft).
- **UNKNOWN**: se o site público tem a mesma exposição — o achado é do
  sandbox sintético. Decisão de instalar na produção é human gate.
- Vendor não modificado; report upstream recomendado ao coordenador.

## Execução (sandbox)

```bash
# reprodução (plugin inativo) — deve PASS=5 documentando o vazamento
EXPECT=leak BASE_URL=http://127.0.0.1:18732 \
  QA_USER_B=.. QA_PASS_B=.. QA_USER_C=.. QA_PASS_C=.. \
  QA_USER_I=.. QA_PASS_I=.. QA_USER_ADM=.. QA_PASS_ADM=.. \
  SECTION_ID=1 DRAFT_ITEM_ID=13 \
  bash tooling/qa/learnpress_section_items_acl/section_items_acl.sh <dir>

# proteção (plugin ativo) — deve PASS=6
EXPECT=protected <mesmas vars> bash section_items_acl.sh <dir>
```

Credenciais apenas via env; evidência = projeção allowlist
(`id/type/post_status/locked/name_present`) — título de rascunho nunca
persistido.
