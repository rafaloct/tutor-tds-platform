# CURRENT STATE

- CURRENT RELEASE: código `1.4.0+13`; produção histórica `1.2.0+11`, não revalidada na Play. Checkpoint Wave 1 `0081ab0`.
- CURRENT WAVE: 2A — publicação/consumo remoto; Wave 1 concluída funcionalmente em staging.
- CURRENT ACCEPTANCE GATE: WAVE 1 APROVADA; três golden paths Android e isolamento HTTPS reais. Produção não promovida.
- STABLE: MVP, produção e assinatura preservados; API Cloud/Supabase staging saudável.
- IN PROGRESS: gate 2A com APK único; cache público por API, refresh e layout StudyHub corrigidos e verificados em testes locais.
- BLOCKED: nenhuma intervenção humana necessária no recorte atual; release mantém gates próprios.
- DO NOT TOUCH: produção, keystore, KV/certificados antigos, baseline e secrets.
- LAST VERIFIED: 2026-09-23; Flutter 344 + analyze; API locked 281; isolamento runner 15; Android 16 seis fases; HTTPS 13 checks/4 negações. Hashes conferidos.
- NEXT ACTION: executar oito fases editoriais no mesmo APK e provar publicação/edição fixa sem rebuild; harness de reinício já aprovado.

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
Preview debug normal sem credenciais QA compilado/instalado; não é release.
Auditoria Wave 2 e contrato 2A concluídos; editor/snapshots existentes serão reutilizados.
Fixture 2A aplicada: quatro identidades e programa isolado, curso ainda ausente;
76 eventos preservados. Preparação passou 23 testes locais e guardas reais de staging.
Preflight HTTPS editorial passou 10 checks; aluno sem acesso ao editor. Analyze
dos oito arquivos alterados sem problemas; StudyHub 5/5 após correção. Harness
Android comprovou dois processos com APK idêntico, uma compilação/instalação.

## Changed contracts
LearningContext `cohort-enrollment-v2`: identidade física de Membership/Enrollment
contextual; `legacy_enrollment_id` preserva linhagem e retomada. Progresso oficial
compartilhado, separado da posição local. GET não faz backfill. Eventos mantêm API.
`LEARNING_CONTEXT_ENABLED` e `DURABLE_LEARNING_OUTBOX_ENABLED`: false por padrão,
true apenas no candidato QA. Contrato de entrega acrescenta projeção local e retry
escopados, sem tabela/endpoint novo; implementação verificada localmente e no Android.
2A isola cache público por API e permite recarga; nenhuma migration/API nova.
Correções locais de catálogo/layout registradas no checkpoint `14aaf27`.

## Known issues
Retenção de recibos antes da promoção final. Ack global atualiza entrega, mas
progresso/data podem esperar a próxima revalidação. Role global permanece no legado.
Overflow StudyHub corrigido sem altura fixa; Home e quatro cenários de largura/fonte
verificados. Teste de fonte 200% precisou rolar até o sliver ser construído; caso passou.
Quiz embutido ainda não é ActivityAttempt contextual: fatia posterior da Wave 2 obrigatória.
Logout ainda limpa filas legadas de avaliação/check-in; QA 2A recusa essa perda,
e a próxima fatia deve resolver a fronteira antes de ampliar atividades oficiais.
Paridade visual integral, QA físico, build release e Play ainda não aprovados.
Cloud: https://tutor-tds-staging.fastapicloud.dev; Supabase lgtphbbpgqnzduhtyate.
Deploy b67f0921-d2c4-400d-a28e-c8832eb268fb; somente dados sintéticos.

## Next gate
Wave 2: course_publication_path, aproveitando editor/versões existentes; nenhuma
expansão simultânea de contrato central. Wave 1: ver production/WAVE1_ACCEPTANCE.md.

## Relevant files
`production/WAVE1_ACCEPTANCE.md`, `production/LEARNING_DELIVERY_CONTRACT.md`,
`production/DYNAMIC_LEARNING_CONTRACT.md`, `production/TRACEABILITY_MATRIX.md`,
`production/API_MATRIX.md`, `production/CLOUD_STAGING.md`, `production/evidence/`.
