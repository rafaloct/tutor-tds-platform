# CURRENT STATE

- CURRENT RELEASE: código `1.4.0+13`; produção histórica `1.2.0+11`, não revalidada na Play. Base `fb50a57`.
- CURRENT WAVE: 1 — Context Core concluída funcionalmente em staging; transição à Wave 2.
- CURRENT ACCEPTANCE GATE: WAVE 1 APROVADA; três golden paths Android e isolamento HTTPS reais. Produção não promovida.
- STABLE: MVP, produção e assinatura preservados; API Cloud/Supabase staging saudável.
- IN PROGRESS: consolidar checkpoint e auditar a menor fatia Dynamic Learning existente.
- BLOCKED: nenhuma intervenção humana necessária no recorte atual; release mantém gates próprios.
- DO NOT TOUCH: produção, keystore, KV/certificados antigos, baseline e secrets.
- LAST VERIFIED: 2026-09-23; Flutter 344 + analyze; API locked 281; isolamento runner 15; Android 16 seis fases; HTTPS 13 checks/4 negações. Hashes conferidos.
- NEXT ACTION: Wave 2 contract-first: publicação dinâmica sem rebuild e versão da turma imutável; preservar gate Wave 1.

## Completed
Auditoria, cache Stitch, contrato/contexto v2, migração física 0019 e autorização
contextual integrados. PostgreSQL vazio/populado, downgrade/forward, revogação e
projeção compartilhada testados. Home resolve matrícula/edição, cache e retomada.
Outbox SQLite preserva dono/ambiente, corpo/ID, backoff e recibos; migração atômica.
Staging gerenciado criado com secrets exclusivos, Data API Supabase desativada,
Alembic/seed sintético e deploy locked validado. Candidato temporário VPS removido;
VPS original saudável. Android real passou seis fases: baseline 5% → 7,5% → 10%,
reinícios, pendência visível, replay sem duplicata e professor com projeção idêntica.
HTTPS negou acesso indevido e conservou segunda matrícula em 0%, sem alterar histórico.

## Changed contracts
LearningContext `cohort-enrollment-v2`: identidade física de Membership/Enrollment
contextual; `legacy_enrollment_id` preserva linhagem e retomada. Progresso oficial
compartilhado, separado da posição local. GET não faz backfill. Eventos mantêm API.
`LEARNING_CONTEXT_ENABLED` e `DURABLE_LEARNING_OUTBOX_ENABLED`: false por padrão,
true apenas no candidato QA. Contrato de entrega acrescenta projeção local e retry
escopados, sem tabela/endpoint novo; implementação verificada localmente e no Android.

## Known issues
Retenção de recibos antes da promoção final. Ack global atualiza entrega, mas
progresso/data podem esperar a próxima revalidação. Role global permanece no legado.
Paridade visual integral, QA físico, build release e Play ainda não aprovados.
Cloud: https://tutor-tds-staging.fastapicloud.dev; Supabase lgtphbbpgqnzduhtyate.
Deploy b67f0921-d2c4-400d-a28e-c8832eb268fb; somente dados sintéticos.

## Next gate
Wave 2: course_publication_path, aproveitando editor/versões existentes; nenhuma
expansão simultânea de contrato central. Wave 1: ver production/WAVE1_ACCEPTANCE.md.

## Relevant files
`production/WAVE1_ACCEPTANCE.md`, `production/LEARNING_DELIVERY_CONTRACT.md`,
`production/OUTBOX_CONTRACT.md`, `production/TRACEABILITY_MATRIX.md`,
`production/API_MATRIX.md`, `production/CLOUD_STAGING.md`, `production/evidence/`.
