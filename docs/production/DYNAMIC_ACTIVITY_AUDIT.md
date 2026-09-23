# Dynamic Learning 2B — auditoria, sem implementação

Pré-condição: gate 2A verde. Leitura do código em 2026-09-23; nenhuma alteração
de domínio, migration ou interface autorizada por este documento isoladamente.

| Fronteira | Implementação e lacuna |
| --- | --- |
| Conteúdo | `course_editor.py:snapshot_content` gera IDs/versões de módulos e blocos. `cartilha.dart` perde versão da Section e ID/versão da Message; `toJson` perde também no cache privado. |
| Leitor | `ChatExperienceScreen._applyOption` mantém resposta/feedback/posição locais; não cria tentativa persistida. Preservar seleção única: qualquer alternativa marcada correta é aceitável. |
| Tentativa | `AssessmentAttemptRecord` / `assessment_attempts`, migration 0012; reutilizar, sem segunda tabela ActivityAttempt. PUT idempotente e CAS já existem. Não possui matrícula/turma/edição/bloco. |
| Gabarito | `AssessmentContentRecord`, migration 0014, congela deck enviado pelo próprio cliente. Adequado à prática pessoal; não comprova avaliação oficial de bloco publicado. |
| Autorização | API legada exige User.role=student e Enrollment por curso; GET/list são do dono, sem contexto/revalidação de matrícula. |
| Dispositivo | AssessmentAttemptRepository tem chave curso/modo global; fila não tem owner/API. Logout apaga fila e conserva tentativa que pode voltar a sincronizar sob outra conta. |
| Progresso | `_student_progress` deriva horas de LearningEvents contextuais; notas não alteram essa projeção. Manter essa regra. |

Menor evolução a contratar: origem explícita prática/bloco publicado no registro
existente; linhagem contextual completa ou toda nula no legado, FKs e índices;
resolver permissão/contexto e gabarito no servidor pela CourseVersion imutável.
Índice da alternativa só vale com identidade/versão do bloco; `Option.value` não
é identificador único. Question sem gabarito persiste resposta sem nota. Quiz
preserva o conjunto de alternativas aceitáveis, sem achatá-lo em correct_index.

Leituras contextuais devem ficar separadas das legadas, incluindo projeção para
professor autorizado da mesma turma. Conclusão aceita grava evidência determinística
na mesma transação, com replay sem duplicata; cliente não fabrica esse evento
oficial por `/events`. Não gerar horas, frequência ou certificado por pontuação.

No Flutter, conservar IDs no round-trip/cache e separar tentativa/fila por dono,
API, matrícula, edição e bloco. Não inferir dono de registros antigos nem apagá-los.
Controller só avança após persistência local confirmada; falha mantém a mesma
tentativa/revisão para retry. Usar os repositories e filas existentes.

Testes a estender: `assessment_attempt_repository_test`, `assessment_sync_service_test`,
`assessment_screen_test`, `settings_logout_test`, `chat_experience_progress_test`,
modelos/cache privado e contratos `assessment_sync.py`. Cobrir duas turmas/edições,
revogação, papel contextual, professor externo, bloco divergente, seleção correta
múltipla permitida, pergunta sem nota, falha local, logout, offline/reinício/replay.

Gate alvo posterior: resposta de bloco publicada → tentativa/evidência persistida
→ reinício/offline/sync → professor observa a mesma tentativa; edição antiga e
horas anteriores preservadas. Ainda requer contrato executável, implementação e QA.
