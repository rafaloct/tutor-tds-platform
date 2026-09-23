# Migração física Context Core — contrato

Reutilizar `class_enrollments` como matrícula contextual, acrescentando identidade
estável, Membership e CourseVersion. `enrollments` permanece como vínculo legado
User+Program+Course para compatibilidade e linhagem; não criar terceira matrícula.

`cohort_memberships` representa User+Cohort+Role com unicidade; student, teacher e
monitor vêm dos vínculos atuais, nunca de User.role. IDs student preservam UUID5
do adapter existente. ClassEnrollment contextual liga Membership(student) à edição
fixada, com FK composta para impedir troca de usuário/turma/papel/curso.

Backfill antes da ativação: rejeitar turma matriculada sem edição publicada ou
arquivada; copiar status do vínculo sem reativá-lo; preservar IDs legados e eventos.
Não reescrever LearningEvent. Progresso continua derivado dos mesmos eventos com
turma+edição explícitas. Evidência ambígua permanece legada, sem duplicação.

Compatibilidade: colunas contextuais inicialmente permitem conjunto totalmente
nulo para gravações de servidores antigos durante rollback. Nunca aceitar vínculo
parcial. Comandos atuais passam a gravar vínculo canônico na mesma transação.
Backfill idempotente reconcilia gravações legadas antes de reativar a flag.

LearningContext passa a usar matrícula contextual persistida; respostas mantêm
`legacy_enrollment_id` para mapear histórico. Projeção de progresso contextual
precisa ser idêntica no leitor e no dashboard do instrutor. Migração do cache é
explícita e não deve atribuir posição antiga a uma turma diferente.

Recuperação: desativar flag, manter tabelas/colunas e continuar APIs legadas;
preferir forward recovery. Downgrade só em banco descartável de QA ou após
verificar que não há consumidor dos novos IDs; não executar em produção.

## Estado verificado

Migration `20260923_0019` e modelos implementados. Testes locais cobrem backfill
idempotente, múltiplas turmas, vínculos inativos, edição imutável, rollback e
exclusão de conta. Teste com schema 0018 populado comprova preservação, constraints
e downgrade/upgrade em SQLite e PostgreSQL 16 descartável. Evidência:
`evidence/context-physical-postgres-gate.json`, source SHA
`a1b3f6ae819a3cda39b5e02c89b57af597f676e3373402dc1efd0e1042c0e502`.
O teste de exclusão foi acrescentado depois desse pacote e validado localmente.

Comandos de criação/inclusão gravam os vínculos na mesma transação. Vínculos
sem edição mantêm compatibilidade apenas com flag desligada; a jornada contextual
recusa inconsistência. Seed sintético cria edição explícita e vínculos, de forma
idempotente. Reconciliador preserva revogação canônica existente.

Resolver agora emite cohort-enrollment-v2 com enrollment_id contextual e
legacy_enrollment_id. StudentProgress mantém ID legado e adiciona
context_enrollment_id; aluno e instrutor usam a projeção inteira compartilhada.
Flutter valida ambos, aceita cache v1 e mantém posição local do contexto exato.
Testes negam acesso após revogação, exigem backfill explícito e verificam comandos.

Status STAGING para o recorte funcional: migration 0019 e candidato no staging isolado
FastAPI Cloud/Supabase; Home contextual implementada e validada localmente.
Evidências em `evidence/cloud-staging-seed.json`,
`evidence/cloud-locked-deployment.json` e `evidence/wave1-flutter-local-gate.json`.
Aceite Android completo e isolamento entre turmas via HTTPS aprovados; resultados
atuais em `WAVE1_ACCEPTANCE.md`. Nenhum dado de produção migrado; promoção e
release continuam sujeitos a seus próprios gates.
