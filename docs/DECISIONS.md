# Decisões vigentes

1. 2026-09-23: contrato do usuário redefine Wave 1 como Context Core. Números
   de ondas em documentos de 19–21/09 são históricos; não significam gate atual.
2. Reusar `Institution` como Organization e `Classroom` como Cohort; não duplicar
   entidades por diferença de nome. Não remover `User.role` global de uma vez.
3. A matrícula existente não satisfaz Membership+CourseVersion. Backfill deve
   considerar aluno em várias turmas no mesmo programa/curso; não há mapeamento
   garantido de uma matrícula antiga para uma única nova matrícula.
4. `StudyProgress` é retomada local, enquanto dashboard calcula horas validadas.
   O gate exige projeção compartilhada, além da retomada; não comparar essas duas
   métricas como se fossem equivalentes.
5. Não usar documentação antiga como prova de staging atual. Produção e assinatura
   preservadas; nenhuma promoção até gate completo e checklist da release.
6. Stitch autenticado no navegador integrado: HTML original Classroom exportado
   e validado. Cache completo não comprova paridade visual do Flutter.
7. Skill Flutter expert lida da fonte pública sickn33/antigravity-awesome-skills
   e instalada em `.agents/skills/flutter-expert/SKILL.md` do usuário.
8. Primeira fatia usa adapter `legacy-lineage-v1` sobre relações existentes, atrás
   de flag desligada. Membership UUID5 identifica chave natural existente, sem
   nova concessão de acesso. Migração física continua pendente.
9. Aluno e instrutor usam `_student_progress`. Retomada local é separada por
   contexto; evidências contextuais preservam dono/ambiente no logout.
10. PostgreSQL 16 isolado na VPS passou no golden path da API. Isso não equivale
    a staging público ou teste Android; nenhum gate foi aprovado.

11. Com flag contextual ativa, atividade com turma+edição é autorizada pela
    matrícula ativa mesmo quando User.role é teacher/monitor/admin. Catálogo,
    mídia e listagem legados mantêm política anterior até migração específica.

12. Fila SQLite atrás de DURABLE_LEARNING_OUTBOX_ENABLED=false; importar legado
    em transação e manter recibo para replay. Nunca inferir dono de evento legado.
    Falha definitiva fica pendente bloqueada; não interrompe demais envios válidos.
13. Preflight físico somente leitura antes do backfill; preservar ambiguidade
    histórica explicitamente. Staging auditado sem alteração de dados.
14. Reusar class_enrollments para matrícula Membership+CourseVersion; manter
    enrollments como linhagem legada e adicionar cohort_memberships. Migration
    0019 validada em PostgreSQL descartável; resolver v2 integrado e testado.
    Colunas contextuais aceitam todas nulas para rollback de servidor antigo,
    nunca preenchimento parcial. Reconciliar antes de reativar consumidores.
15. Contrato v2 usa enrollment_id contextual + legacy_enrollment_id explícito.
    Progress mantém semântica antiga e acrescenta context_enrollment_id; mesma
    projeção completa em aluno/instrutor. Flutter lê cache v1/v2, preservando
    posição com linhagem exata, sem transferir dados entre contextos.

16. 2026-09-23: usuário autorizou staging FastAPI Cloud + Supabase. Preservar
    FastAPI/Auth/contratos/Flutter; Supabase fornece PostgreSQL inicialmente.
    Projeto staging isolado lgtphbbpgqnzduhtyate; Data API e exposição automática
    de tabelas desabilitadas. Somente seed sintético; Auth/Realtime/Storage
    não migrados nesta etapa. Gate Wave 1 continua obrigatório.

17. 2026-09-23: gate funcional Wave 1 aprovado em staging, sem promoção de
    produção. WAVE1_ACCEPTANCE e hashes de evidências comprovam seis fases Android,
    aluno/professor com projeção idêntica, offline sem duplicata e isolamento HTTPS.
    Atualiza as pendências históricas dos itens 8/10/16; próxima wave autorizada
    pelo contrato é Dynamic Learning. Manter Course/CourseVersion/editor existentes;
    não duplicar domínio nem remover os limites de release/QA físico.
