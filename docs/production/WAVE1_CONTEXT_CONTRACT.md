# Wave 1 — Context Core / contrato de aceitação

Status: STAGING — recorte funcional da Wave 1 aceito. Migração física 0019,
resolver v2, Home contextual, leitor e
outbox durável com feedback/recuperação implementados. Flags desligadas por padrão
em API/Flutter e ativas somente no candidato QA. Staging FastAPI Cloud/Supabase
implantado; suíte Flutter de 344 testes e análise global aprovadas. Implementação
e limites em `CONTEXT_CORE_SLICE.md`; evidência local em
`evidence/wave1-flutter-local-gate.json`. Android completo e isolamento entre
turmas via HTTPS aprovados; resultados atuais e limites em `WAVE1_ACCEPTANCE.md`.
Não equivale a PRODUCTION_READY, release ou paridade visual integral do Classroom.

## Screen contract — jornada contextual existente

| Campo | Contrato |
| --- | --- |
| Purpose | abrir edição da matrícula, realizar atividade e retomar progresso compartilhado |
| Actor | aluno autenticado; instrutor autorizado da mesma turma observa |
| Required Context | LearningContext resolvido pelo servidor; seleção explícita quando houver várias turmas |
| Reads | vínculo ativo, matrícula, edição imutável, progresso canônico, posição local e outbox |
| Displays | curso/edição/turma corretos; progresso oficial separado de envio pendente e posição local |
| Commands | selecionar contexto, abrir conteúdo, registrar atividade, sincronizar, consultar progresso |
| Writes | comando idempotente → evidência validada → projeção; posição local não concede progresso oficial |
| Repositories | LearningContextRepository real/Fake com progresso; adapters dos repositories existentes |
| Endpoints | /classes, /classes/{id}/course, /events, /classes/{id}/dashboard; novos /classes/{id}/learning-context e /classes/{id}/students/{user_id}/learning-context no OpenAPI |
| Events | lesson_started, lesson_completed, study_activity, page_viewed; reutilizar esquema existente |
| Loading State | indicador existente; manter conteúdo identificado sem exibir dados de outra matrícula |
| Ready State | contexto íntegro e edição correta; ação habilitada conforme permissão |
| Empty State | sem matrícula/turma; catálogo público preservado sem inventar vínculo |
| Offline State | CACHE_READ do contexto validado; OFFLINE_WRITE_SYNC somente atividades permitidas |
| Error State | erro de rede recuperável; 401/403 revoga snapshot; conflito não sobrescreve silenciosamente |
| Permissions | ler própria matrícula; registrar atividade própria; instrutor lê aluno somente no escopo autorizado |
| Acceptance Criteria | três golden paths abaixo e negações de acesso, com evidência local e staging |
| Must Not | inferir identidade/papel; escolher matrícula ambígua; misturar ambientes/turmas; emitir certificado; descartar evidência pendente |

## Ordem alvo e adaptação incremental

A decisão 8 permite adapter de leitura antes da migração física para provar
linhagem e projeção sem duplicar tabelas. Isso não elimina a etapa 2 abaixo.
Screenshot e HTML Classroom inspecionados; paridade Flutter continua pendente.

1. Contrato executável do resolver e projeção com casos de ambiguidade/revogação.
2. Migração aditiva Membership/Enrollment com constraints, FKs, índices,
   timestamps, auditoria de backfill e recuperação. Preservar IDs legados em
   linhagem explícita; não criar um segundo sistema permanente.
3. Resolver único com autorização contextual; FakeRepository e ViewModel.
4. Consumir contexto nas telas existentes e eventos; repository real; cache
   privado por conta+ambiente+matrícula+edição. Derivados visuais só se necessários.
5. Projeção compartilhada aluno/instrutor; outbox durável com dono, local id,
   idempotency key, timestamp, sync status, backoff limitado e conflito explícito.
6. Gate local completo; migration PostgreSQL do zero e staging isolado;
   somente então avaliar avanço da wave.

## Acceptance gate funcional validado em staging

- `student_learning_path`: login real → vínculo → matrícula → edição → Home →
  conteúdo → atividade → evidência/progresso → morte/reabertura → mesmo progresso.
- `instructor_observation_path`: instrutor da mesma turma lê exatamente a projeção
  da matrícula anterior; outro instrutor/turma não lê; duas matrículas não vazam.
- `offline_sync_path`: conexão inicial → atividade permitida offline → fila →
  morte/reabertura → reconexão/retry → uma evidência e uma atualização; revogação,
  troca de conta e fila cheia não atribuem nem descartam silenciosamente dados.

Os três caminhos passaram nas seis fases Android da mesma execução; isolamento
entre instrutores/turmas foi verificado por HTTPS. Testes locais complementam
essas jornadas nos casos de revogação, troca de conta e falhas de armazenamento.
Fontes, hashes, resultados e limites em `WAVE1_ACCEPTANCE.md`; histórico físico
antigo não substitui o QA exigido para release.
