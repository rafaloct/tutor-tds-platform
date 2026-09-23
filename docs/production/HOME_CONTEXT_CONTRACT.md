# Home contextual — Wave 1

Status: STAGING para a jornada funcional; resultados atuais em
`WAVE1_ACCEPTANCE.md`. Paridade visual integral e release não aprovados.

Purpose: tornar a matrícula real a entrada principal do aluno, preservando catálogo.
Actor: pessoa autenticada com Membership student, independente de User.role global.
Required Context: identidade atual; turma escolhida; LearningContext v2 validado.
Reads: turmas elegíveis, última escolha por conta/ambiente, contexto e edição.
Displays: turma, curso, edição, progresso confirmado e data de sincronização.
Commands: escolher/trocar turma, continuar estudo, tentar novamente.
Writes: somente preferência de turma; atividade continua usando outbox existente.
Repositories: LearnerClassroomGateway, LearningContextRepository,
HomeSelectionRepository (SharedPreferences/Fake nos testes).
Endpoints: GET /classes?enrolled_only=true; /classes/{id}/learning-context;
/classes/{id}/course; AuthRepository existente. Nenhum endpoint novo.
Events: rotas home/classroom_course e atividade existentes; escolha não é evidência.
Loading State: indicador + texto mantendo identificação da operação.
Ready State: card da matrícula autorizada e botão Continuar estudo.
Empty State: sem turma; explorar catálogo sem inventar matrícula.
Offline State: contexto/conteúdo previamente autorizados; progresso com data
da última confirmação; outbox existente. Política CACHE_READ/OFFLINE_WRITE_SYNC.
Error State: erro explícito e retry; nunca abrir edição pública como substituta.
Permissions: mesmas da API contextual; escolha local não concede acesso.
Acceptance Criteria: seleção única automática; múltiplas turmas exigem escolha
explícita ou preferência ainda válida; reabertura preserva escolha; conta/ambiente
isolados; versão/contexto divergente e revogação impedem abertura.
Must Not: usar primeiro curso do catálogo como matrícula; inferir papel; misturar
percentual confirmado com posição local; copiar dados entre turmas; gerar IA no loading.

Referência: composição importada 9731628404551462355, região 7 Home–Aluno.
É imagem sem HTML exportável, ver metadata do cache (HTML N/A, nenhum fabricado).
Variante funcional mobile 75ac62c1bb3241aba1b3092f908b7c5f gerada a partir de
389e412e620c4c49841a5e9508cf6bfb. Screenshot e HTML baixados novamente após
geração, inspecionados e salvos com digest/metadados em derivatives; os exemplos
de módulo e contagem do design não são simulados no Flutter.

Implementação: HomeScreen exibe LearningHomeCard antes do catálogo com flag
ativa e sessão presente. Continuação revalida vínculo/edição; falha do catálogo
não bloqueia a jornada matriculada. Conteúdo público e atalhos existentes
permanecem; retomada pública não é apresentada como progresso da turma.
Estado pronto segue cartão da variante; loading/error/empty/choice reutilizam
componentes compactos. Em fontes ampliadas, cabeçalho quebra linha. Navegação
inferior existente preservada; paridade visual integral não declarada.

Testes cobrem escolha, reabertura, conta/ambiente, edição divergente, papel
global de equipe, falha do catálogo e 320px com fonte 200%. Jornada Android com
API/PostgreSQL reais aprovada, incluindo reabertura online/offline, edição fixada
e progresso confirmado. Evidência: `evidence/context-android-gate.json`.
