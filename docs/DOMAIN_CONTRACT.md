# Domínio central — alvo e compatibilidade

Este contrato é alvo de migração, não declaração de implementação concluída.

Jornada/certificados: aplicar a decisão posterior de #5 registrada no item 27 de
`DECISIONS.md` e na matriz `program/JOURNEY_CONTRACT_RECONCILIATION_2026-10-03.md`.
80h formais por curso não são tempo medido. Frequência mínima é 70% dos encontros
configurados por oferta. CAPACITADO exige baseline, frequência, trilha obrigatória
e certificado gerado; validade acrescenta fichas assinadas pelo instrutor e
assinatura da coordenação. Geração e validade são estados distintos. Referência
legada e telemetria não comprovam esses requisitos; desconhecidos permanecem null.

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


## 2026-10-03 — contrato institucional autorizado, candidato v2

Decisões diretas do usuário registradas na Issue #5, comentário 5965837795,
substituem o bloqueio por indefinição de negócio nesta fatia. O Plano de Trabalho
citado não foi anexado nem lido. Cada curso possui 80h formais; cronômetro não é
prova desse requisito. Duas unidades de 80h totalizam 160h, mas Classroom atual
vincula um curso/edição: este candidato projeta por curso/matrícula contextual,
sem inventar agregação de dois cursos ou atribuir créditos históricos ambíguos.

Política aditiva e congelada por oferta configura encontros (zero bloqueia),
checkpoints obrigatórios e responsável operacional autorizado. Apenas presença
confirmed_present conta: 10 × presentes >= 7 × encontros configurados.
Ausência justificada e exceção accepted não criam presença; exceções mantêm
pending_human_validation, justificativa e responsável até decisão humana.

EvidenceItem/ReviewDecision servem como EvidenceRecord contextual de tipo,
origem, status, participante, edição e hash da política. Baseline aceita origens
Google Forms, Jotform, app ou ficha digitalizada sem integração fictícia;
StudentBaseline contextual existente também é aceito. Fichas assinadas pelo
instrutor precisam cobrir todos os encontros configurados do participante.
Referências documentais privadas/hash são atestação humana auditável, não leitura
externa nem assinatura criptográfica de PDF.

Todos os checkpoints configurados são avaliados no backend. O adaptador inicial
suporta assessment editorial imutável, com todas as respostas determinísticas;
não impõe nota mínima nova. Tipos ainda sem representação determinística falham
explicitamente. Quiz não é requisito universal: o discriminador admite novos
adaptadores futuros sem alterar retroativamente a política. IDs configurados
são requisitos distintos; reutilizar uma fonte exige conclusão explícita de
cada ID, sem aproveitar evento agregado lesson_completed ou tentativa antiga.

O último checkpoint gera automaticamente pelo API→adaptador→Worker candidato,
antes de baseline, frequência ou assinaturas. O comando v2 fixa carga formal,
hash da política e prova dos checkpoints, sem depender da baseline posterior.
Preservados reserva durável, autenticação, idempotência e reconciliação somente
por lookup após timeout. Crash após reserva antes do primeiro envio conserva
estado indeterminado; ausência no KV não autoriza reenviar nem reset automático.

CAPACITADO = baseline registrada AND frequência >=70% AND trilha obrigatória
concluída AND certificado de trilha gerado. CERTIFICADO_VALIDO = CAPACITADO AND
fichas regularizadas/assinadas pelo instrutor AND assinatura da coordenação.
Estados: GENERATED → PENDING_INSTRUCTOR_VALIDATION →
PENDING_COORDINATOR_SIGNATURE → VALID. VALID aqui é projeção sintética do contrato;
institutional_release permanece blocked. Geração registra responsável operacional
configurado (rótulo da responsável Eliza separado do papel técnico, sem mapear identidade real) e evidência de fluxo para
tdsdados@gmail.com em pending_dispatch, sent=false, recibo=null. Nenhum SMTP/VPS
foi chamado e nenhum envio foi inventado. Comportamento legado é preservado.

Ativação exige development e opt-in; transporte HTTP isolado em loopback sem
proxy/redirecionamento, Worker com namespace/binding candidato separados. O novo
/emit permanece bloqueado por gate deliberado de homologação/ativação real, não
por falta de decisão sobre horas/Jotform. Rotas oficiais legadas seguem contrato
anterior; candidato nunca aparece em carteira/export oficial. Migração0022 apenas
adiciona política JSON/lifecycle nullable; recusa downgrade com dados novos.
SQLite descartável não homologa PostgreSQL, deploy, provedor instalado ou PDF.
