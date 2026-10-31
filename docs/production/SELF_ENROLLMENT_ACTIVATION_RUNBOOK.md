# Runbook de ativação — self-enrollment + sync LearnPress

Escopo: ativação controlada de `SELF_ENROLLMENT_ENABLED` e
`LEARNPRESS_SYNC_ENABLED` em staging, depois produção. Cada gate exige
evidência e ação humana explícita. **Concluir este runbook não autoriza
release do app** — os gates físicos de `release_status.json` são trilha
separada.

Estado base auditado (2026-10-31, `agent/web-1.4.0-c07 @ 45e5417`):

- Flags `false` em código/config/testes — endpoints respondem 404.
- Migration `20261031_0025`: head único, upgrade de base vazia OK (47
  tabelas), downgrade com guarda de dados.
- Worker: claim `FOR UPDATE SKIP LOCKED`, lease, backoff
  `min(600, 2^attempts*5)`, esgotado → `failed` permanente.
- Contratos de payload Flutter↔API↔WP compatíveis.

## Gate 1 — re-pin da migração staging (humano/ops)

`staging-alembic-migrate.yml` está pinado em `EXPECTED_ALEMBIC_HEAD:
20261003_0024` e ref fixo `89624132…` — por construção, não aplica 0025.

Ação humana:
1. Revisar e promover um commit candidato contendo `0025` (sugestão: HEAD
   aprovado pós-auditoria).
2. Atualizar no workflow: `ref` do checkout → commit aprovado;
   `EXPECTED_ALEMBIC_HEAD` → `20261031_0025`; nome do job.
3. Disparar `workflow_dispatch`; exigir job verde e capturar output de
   `alembic current`/`alembic heads` como evidência.

## Gate 2 — mapeamento `courses.id` ↔ `post_name` LearnPress

O worker envia `course_slug = courses.id` canônico; o WP resolve via
`get_page_by_path($slug, OBJECT, 'lp_course')`. Divergência → 404 →
retry → `failed` → reconciliação (seguro, mas funcionalmente quebrado).

Ação humana (read-only no EAD):
1. Listar `courses.id` canônicos elegíveis a turma aberta.
2. No WP: `wp post list --post_type=lp_course --field=post_name` ou SQL
   `SELECT post_name FROM wp_posts WHERE post_type='lp_course' AND
   post_status='publish'`.
3. Conferir 1:1 por curso; divergências exigem ajuste de slug ou mapa
   explícito **antes** de ligar o sync.

## Gate 3 — deploy do `POST /tds/v1/register` no runtime WP (humano/Dokploy)

O código está no snapshot canônico do monorepo; a publicação no servidor
EAD é ação humana. Verificar pós-deploy: `401` sem `X-API-Key`, `200/201`
com chave, idempotência por telefone/`tds_user_id`.

## Gate 4 — ordem de ativação das flags

`SELF_ENROLLMENT_ENABLED` ligado com `LEARNPRESS_SYNC_ENABLED` desligado
produz matrículas **sem** item na outbox (`_enqueue_sync` retorna cedo).

Ação humana — escolher:
- **(a) Ativação simultânea** das duas flags, ou
- **(b) Backfill** após ligar o sync: inserir em
  `external_sync_requests` os pares `kind='learnpress_enroll',
  user_id, course_id, class_id, payload={'course_slug': <id>}` para
  matrículas criadas na janela (dedup por `uq_external_sync_subject`).

## Gate 5 — smoke em staging

Com flags on em staging:
1. `GET /open-classes` sem token → 401; com token → lista com
   `viewer_enrolled` correto.
2. `POST /courses/{id}/self-enroll` → contexto v2 resolvível;
   replay → mesmo contexto, sem duplicatas; recibo em
   `operator_command_receipts`.
3. `external_sync_requests`: item `pending` → `done` com `completed_at`.
4. Simular WP indisponível → item vai a `failed` com `last_error` e
   `next_attempt_at` crescente; matrícula canônica intacta.
5. Segunda execução do worker após WP voltar → item conclui (lease +
   backoff).

## Rollback

`SELF_ENROLLMENT_ENABLED=false` → endpoints voltam a 404 (matrículas já
criadas permanecem válidas). `LEARNPRESS_SYNC_ENABLED=false` → worker
para de processar; itens `pending`/`failed` permanecem para retomada ou
reconciliação — nada reverte matrícula canônica.

## Evidência por gate

Registrar JSON por gate (ver modelo em
`RELEASE_EVIDENCE_RUNBOOKS_2026-10-31.md` §C): gate, ambiente,
executor, resultado observado, artefatos (logs, outputs, queries),
critério e veredito. Sem evidência → `blocked`/`inconclusivo`, nunca
`passed`.
