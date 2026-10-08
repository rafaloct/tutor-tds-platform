# Dynamic Learning 2B — candidato local implementado, aceite remoto pendente

Estado em 2026-10-07: implementação local sobre a base `fbb4b6a`, com migration
aditiva `20261007_0030` e `DYNAMIC_ACTIVITY_ENABLED=false` por padrão. API,
Flutter e runner sintético foram verificados localmente. Nenhum push, merge,
deploy, staging, produção ou secret foi alterado. O candidato fica restrito a
uma branch local até autorização posterior; portanto este documento não declara
aceite STAGING/PRODUCTION.

## Linha de base histórica da auditoria de 23/09

O quadro abaixo preserva as lacunas observadas antes desta implementação. Ele é
histórico e não descreve o estado do candidato de 07/10.

| Fronteira | Implementação e lacuna |
| --- | --- |
| Conteúdo | `course_editor.py:snapshot_content` gera IDs/versões de módulos e blocos. `cartilha.dart` perde versão da Section e ID/versão da Message; `toJson` perde também no cache privado. |
| Leitor | `ChatExperienceScreen._applyOption` mantém resposta/feedback/posição locais; não cria tentativa persistida. Preservar seleção única: qualquer alternativa marcada correta é aceitável. |
| Tentativa | `AssessmentAttemptRecord` / `assessment_attempts`, migration 0012; reutilizar, sem segunda tabela ActivityAttempt. PUT idempotente e CAS já existem. Não possui matrícula/turma/edição/bloco. |
| Gabarito | `AssessmentContentRecord`, migration 0014, congela deck enviado pelo próprio cliente. Adequado à prática pessoal; não comprova avaliação oficial de bloco publicado. |
| Autorização | API legada exige User.role=student e Enrollment por curso; GET/list são do dono, sem contexto/revalidação de matrícula. |
| Dispositivo | AssessmentAttemptRepository tem chave curso/modo global; fila não tem owner/API. Logout apaga fila e conserva tentativa que pode voltar a sincronizar sob outra conta. |
| Progresso | `_student_progress` deriva horas de LearningEvents contextuais; notas não alteram essa projeção. Manter essa regra. |

## Implementação do candidato local

A menor evolução auditada foi implementada: origem explícita prática/bloco
publicado no registro existente; linhagem contextual completa ou toda nula no
legado, FKs e índice; permissão/contexto e gabarito resolvidos no servidor pela
CourseVersion imutável. O Flutter preserva IDs/versões de seção e bloco no
round-trip e constrói uma tentativa estável com escopo de dono, API, turma,
matrícula, edição, seção e bloco. A UI só avança depois da persistência local;
falha conserva tentativa/revisão para retry. Logout não transfere dados entre
contas e o legado de prática continua compatível.

O `attempt_id` publicado é derivado nos dois lados pelo SHA-256 do array JSON
compacto `["published_block", owner_id, organization_id, program_id, class_id,
membership_id, enrollment_id, legacy_enrollment_id, course_id,
course_version_id, section_id, section_version_id, block_id,
block_version_id]`; usa os primeiros 48 hexadecimais com prefixo
`attempt:published:` e não inclui a URL. A API recusa outro ID e o banco impõe
unicidade parcial por dono/contexto/bloco. Proveniência também é persistida em
`assessment_contents`: conteúdo publicado só nasce do snapshot imutável e o
namespace `published-block:` não pode ser registrado pelo fluxo de prática.

Índice da alternativa só vale com identidade/versão do bloco; `Option.value` não
é identificador único. Question sem gabarito persiste resposta sem nota. Quiz
preserva o conjunto de alternativas aceitáveis, sem achatá-lo em correct_index.

Leituras contextuais devem ficar separadas das legadas, incluindo projeção para
professor autorizado da mesma turma. Conclusão aceita grava evidência determinística
na mesma transação, com replay sem duplicata; cliente não fabrica esse evento
oficial por `/events`. Não gerar horas, frequência ou certificado por pontuação.
Projeções públicas/do aluno retiram `isCorrect`, `value`, feedback, explicações e
answer key, sem alterar o snapshot autoral. O evento persistido não contém
`owner_id`, membership ou IDs de matrícula; pseudonimização continua na fronteira
do worker. `updated_at` mais de cinco minutos no futuro falha sem persistir e
retorna `future_updated_at` com horário do servidor; o cliente pode repetir uma
vez corrigindo somente esse campo, monotônico em relação à revisão confirmada.

Cobertura local inclui contrato API, migration `0029→0030`, conteúdo publicado
controlado pelo servidor, CAS/replay, contexto divergente, duas turmas/edições,
revogação, papéis, múltiplas respostas corretas, question sem nota, marcação,
falha local, logout, escopo da fila, offline/reinício e sync. O runner validado
localmente cobre o protocolo, sanitização e falha fechada; ainda não é evidência
de execução remota.

A migration também passou 8/8 cenários opt-in no PostgreSQL 17.11 descartável
do LARGeo, commit `de9ec577415bb6114d502191713816f78931313d`. O gate inclui
upgrade a partir de 0024 e 0029, legado preservado, provenance e índice único.
O alvo foi loopback isolado criado para QA; nenhum banco remoto foi tocado.

## Gate e precondições remotas

`dynamic_activity_contextual_android_e2e` permanece pendente. O fluxo exigido é:
resposta de bloco publicada → tentativa/evidência persistida → marcação e
desmarcação → reinício/offline/sync → professor/admin da turma observam a mesma
tentativa → monitor/outsider são negados; edição antiga e horas anteriores ficam
preservadas. Esse gate é obrigatório antes de habilitar a flag, mas não é
obrigatório para gerar build de produção enquanto ela estiver false.

Duas abordagens locais não produziram aceite e seus harnesses foram retirados do
candidato. A primeira expirou após o gesto no binding de integração. A segunda
construiu e instalou um pacote debug isolado e encontrou os controles esperados
no XML, mas a captura inicial ficou preta porque o display do emulador estava
apagado; o gesto não foi entregue e nenhuma tentativa/fila foi criada. A regra
de duas tentativas encerrou a execução. A correção estrutural futura pertence ao
executor: exigir display interativo, acordado/desbloqueado e uma captura visível
antes de qualquer gesto. Nenhuma imagem parcial é evidência de funcionalidade.

O runner exige `WAVE2B_STAGING_LANE` explícito e aceita somente a combinação
exata entre lane e URL: `cloud` com
`https://tutor-tds-staging.fastapicloud.dev` é a aceitação canônica; `vps` com
`https://ead.ipexdesenvolvimento.cloud/tutor-staging-api` produz apenas
pré-aceitação. Não há default, fallback ou redirect. Ele também exige descriptor
de fixture `wave2b-staging-fixture-v1` previamente provisionado e credenciais
sintéticas student/teacher/admin/monitor/outsider via `STAGING_SEED_*`. Ele não
cria curso, edição, turma, matrícula ou vínculo. Mutação de revogação exige hook
descartável e guard explícito; saída contém apenas hashes/estado sanitizados. A
restauração não passa por receber HTTP 200: o runner relê a mesma tentativa e
exige ID, revisão e origem esperados, ou falha `revocation_restore_not_effective`.
Não deixa fixture silenciosamente revogada. A
única credencial possivelmente nova ou a confirmar é a conta sintética outsider,
se ausente. Nenhum secret de produção é necessário.

Ambientes não foram promovidos: Cloud canônico observado em `0024`, VPS em
`0029`, ambos com `compatibility_verified=false` e sem SHA exato implantado; a
migration `0030` é somente local. Snapshot Supabase direto de
`2026-10-07T21:46:50Z`: RLS 46/46, zero policies, zero grants diretos
`anon`/`authenticated`, grants `service_role`; default ACLs amplas para objetos
futuros são risco pendente e o toggle Data API não foi verificado. O primeiro
alerta do connector foi inconsistente e não é aceito como evidência.
