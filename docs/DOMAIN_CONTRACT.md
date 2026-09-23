# Domínio central — alvo e compatibilidade

Este contrato é alvo de migração, não declaração de implementação concluída.

| Conceito único | Implementação encontrada | Tratamento na Wave 1 |
| --- | --- | --- |
| User | users / User, contém role global | identidade preservada; migrar autorização pedagógica ao vínculo; não remover role antes de migrar consumidores |
| Organization | institutions / Institution | adaptar nomenclatura; não criar organização paralela |
| Program | programs / Program | preservar IDs e relação institucional |
| Cohort | classes / Classroom | preservar IDs/rotas /classes |
| Membership | cohort_memberships; linhagem program_memberships/class_monitors/classes.teacher_id | migration 0019; vínculo User+Cohort+Role persistido; checks canônicos e legados na transição |
| Course | courses / Course | preservar catálogo |
| CourseVersion | course_versions / CourseVersion | publicada imutável; turma fixa edição |
| Enrollment | class_enrollments.context_id + membership_id + course_version_id; enrollments legado | matrícula contextual persistida; legacy_enrollment_id explícito no novo contexto; endpoints antigos preservados |
| Progress | StudyProgress local; projeção de learning_events compartilhada pelo resolver/dashboard | projeção canônica por matrícula/versão aprovada na Wave 1, separada da posição local de leitura |
| ActivityAttempt | assessment_attempts / AssessmentAttemptRecord | reutilizar; avaliar vínculo contextual antes de ampliar |
| LearningEvent | learning_events / LearningEventRecord | evidência append-only; event_id idempotente; jamais autorização |
| Evidence | evidence_items / EvidenceItem | preservar evidência e revisão humana |
| Certificate | certificate_references, certificate_requests e legado KV | não reemitir/migrar chaves nesta wave |
| AIThread | não encontrado como entidade transacional canônica no recorte | fora da Wave 1; não criar paralelismo com chat sem auditoria específica |

LearningContext obrigatório: userId, organizationId, programId, cohortId,
membershipId, role, courseId, courseVersionId, enrollmentId, permissions.
Contrato atual: `cohort-enrollment-v2`, somente aluno, com membershipId e
enrollmentId persistidos e legacy_enrollment_id explícito. Adapter anterior
`legacy-lineage-v1` é aceito no cache Flutter para transição; não é emitido pela API.
Servidor resolve relações e permissões; cliente recebe contexto validado,
não infere papel a partir de UI, IA, eventos ou seleção local. Professor e monitor
usam vínculo próprio e consultam matrícula do aluno com permissão explícita;
não recebem uma matrícula de aluno fictícia.

Progresso oficial deve ter a mesma definição, chave e projeção para aluno e
instrutor. Posição de leitura local não é frequência, carga horária validada
nem critério autônomo de certificado. Evidências devem ser validadas por comandos
determinísticos antes de produzir atualização oficial.

Offline: snapshot não cria autorização nova. Revogação conhecida invalida cache;
fila preserva dono, ambiente, contexto, chave idempotente e timestamp. Retry
idêntico não duplica; retry divergente gera conflito. Não atribuir registros
legados ambíguos a uma turma por conveniência.
