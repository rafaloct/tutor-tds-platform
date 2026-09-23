# Preflight da migração física

`api/app/context_migration_audit.py::audit_context_lineage` executa somente leitura.
Valida turma, matrícula legada, programa e versão fixada antes de propor backfill.
Matrícula legada em múltiplas turmas é uma relação 1:N válida, não um erro a
"corrigir" escolhendo a primeira turma. Vínculo inativo não pode ser reativado.

Evidência com turma/versão explícitas preserva contexto. Evidência ambígua fica
legada e identificada para reconciliação; nunca copiar um evento para várias
matrículas nem somar progresso várias vezes. Versão ausente bloqueia aquele
backfill; não escolher a publicação mais recente por conveniência.

2026-09-23: staging existente auditado dentro de transação PostgreSQL READ ONLY,
timeout de 20s, sem migration/deploy: 2 contextos, 0 matrículas paralelas,
0 bloqueios de linhagem, 0 evidências ambíguas. Isso permite preparar a migração
aditiva; não prova o estado da produção. Dois testes sintéticos cobrem o caso
paralelo com evidência ambígua e a versão ausente sem alterações no banco.

Schema, backfill, constraints e recuperação testados em banco descartável;
detalhes em PHYSICAL_CONTEXT_CONTRACT.md. Próxima etapa: escrita compatível nos
comandos existentes e integração do resolver/Flutter. Reexecutar preflight em
cópia isolada imediatamente antes de aplicar a migration, sem usar este relatório
como autorização para alterar produção.
