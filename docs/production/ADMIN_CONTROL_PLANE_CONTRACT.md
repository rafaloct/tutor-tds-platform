# Operação de participantes — contrato e candidato Flutter (#30)

Base auditada: `aa6fb88050aa864726e197187487819de303ac65`.
Dispatch: #37 comentário 5970062938. Branch exclusiva
`rafael_notebook/issue-30-operator-flow-20261003`. Escritor Codex #30;
backend/schema e navegação existente reservados ao integrador após #39.
Estado: IMPLEMENTED somente contrato/modelos/gateway/controller/tela injetável.
Não conclui #30, não está na navegação publicada e não constitui cadastro operacional.

## Auditoria de equivalentes (OBSERVED no código)

| Necessidade | Equivalente existente | Lacuna desta entrega |
|---|---|---|
| Identidade | User; AuthService; POST /auth/register e /admin/accounts | não há adapter real neste candidato; criação gerenciada precisa preservar autorização contextual e não conceder role global ao operador |
| Programa | ProgramMembership; POST /admin/programs/{id}/memberships; GET /admin/hierarchy | endpoints atuais são admin global; busca mínima contextual e grants de operador pendentes |
| Matrícula | Enrollment; POST /admin/enrollments | replay atual retorna conflito; comando administrativo auditado pendente |
| Turma/edição | Classroom, CourseVersion, ClassEnrollment, CohortMembership | não mudar edição ou recriar vínculos por conveniência |
| Inclusão | GET /classes/{id}/eligible-students e PUT /classes/{id}/students/{user_id} | exigem Enrollment ativa; reativação atual não é correção administrativa auditada |
| Equipe | teacher_id; POST /admin/classes/{id}/monitors/{user_id} | alteração/revogação de equipe não está implementada por esta tela |
| Flutter | Home → TeamCapabilityResolver → ClassroomDashboardScreen → ClassroomRosterScreen; repository e testes | reutilizar entrada/repository na integração posterior; não criar outra navegação produtiva nesta fatia |
| Baseline | StudentBaseline, BaselineSourceRecord, BaselineRevision; student_followup.py | exibir pendência, nunca criar ficha ou casar nome automaticamente |
| Importação | evidence-imports para evidências; export_tds_journey.py só exporta | nenhum importador administrativo de participantes foi comprovado; não converter export em cadastro |
| Auditoria | BaselineRevision, MentorshipRevision, presença e transições de certificado | estruturas específicas não são ledger genérico de matrícula/revogação |

## Fluxo mínimo completo TARGET

1. Carregar contextos autorizados e selecionar explicitamente instituição/programa/curso/turma/edição.
2. Buscar pessoa existente; escolher referência explícita. Nome é busca, não casamento de identidade.
3. Se inexistente, solicitar cadastro usando o contrato de identidade existente e vínculo autorizado ao programa. Backend verifica duplicidade, escopo e papel; não criar tabela de pessoa paralela.
4. Solicitar matrícula no curso do programa. Repetição não cria outra Enrollment.
5. Vincular à turma/edição autorizada. Backend confirma linhagem completa e vínculos ativos.
6. Consultar histórico e situação de baseline; ausência não bloqueia matrícula/estudo.
7. Corrigir turma mediante revogação explícita com motivo e nova associação autorizada. Não apagar pessoa, matrícula, evidência histórica ou vínculo de outra turma. A sequência é visível, não transferência atômica fingida.

O candidato permite exercitar todos os passos com gateway injetado, apenas nos
testes sintéticos. Não há HTTP, endpoint novo, banco local, seed real, cadastro
permanente, evento acadêmico ou plugin de provider. Fake fica exclusivamente em
test/features/operations. A tela identifica a simulação e não afirma envio real.

## Autoridade e autorização

DECISION: operador amplo e revogável no escopo do programa (#30). TARGET:
permissões no backend, verificadas em cada leitura/comando; seleção de contexto,
papel global, flag UI ou lista previamente carregada nunca concedem autorização.
Professor/monitor mantém o escopo autorizado da turma; não ampliar poderes porque
o Flutter exibiu um botão. Admin global legado não deve virar atalho do operador.
Matriz específica de grants, lookup mínimo e limites de criação ainda requer
revisão de domínio antes do adapter real. Não criar usuários reais nesta fatia.

ProgramMembership permanece vínculo de programa; CohortMembership mantém os papéis
atuais de turma. Não acrescentar program_operator ao CHECK de turma por suposição.
Equipe, criação de oferta/turma e administração de instituições são próximas
ações autorizadas do mesmo domínio, não obrigatórias para a demonstração deste
fluxo em turma existente. A #30 inteira continua aberta.

## Gateway candidato, comandos e auditoria

OperationsGateway define métodos Dart, **não rotas HTTP aprovadas**: scopes,
search, inspect e execute. Modelos são projeções dos IDs existentes. Snapshot
retorna pessoa, contexto, revision, matrícula/vínculo, baseline nullable e histórico.
Não converter null em ausência comprovada; nenhum cálculo acadêmico deriva disso.

execute recebe chave opaca, sessão, contexto completo, ação, motivo, pessoa,
revision esperada e dados de cadastro quando necessários. As ações são register,
enroll, assign e revoke. A chave vem de factory injetada; o adapter real deve
fornecer IDs globalmente únicos e autenticação real, nunca enviar sessionKey
como prova de identidade. sessionKey é isolamento local por conta E ambiente.

TARGET backend após #39: ledger aditivo de comando/resultado/histórico, com chave
única, ator autenticado, contexto, hash canônico do pedido, motivo, revision e
resultado, confirmado na mesma transação que a mudança. Replay idêntico reconcilia
o mesmo resultado; corpo/ator/contexto divergente falha; perda de resposta não
autoriza novo cadastro. Hash e recibos não armazenam senha nem CPF em payload de
auditoria. Mutação concorrente usa revisão/lock e falha sem escrever parcialmente.
Uma migration nova só será desenhada após integrar/revalidar o head de #39, com
upgrade vazio/snapshot isolado e forward recovery. Não editar migrations agora.

Não reciclar LearningEventRecord como ledger: é telemetria com sync. Não pendurar
revogação em BaselineRevision ou em EvidenceItem sem contrato específico de
autoridade/retention/isolation. Nenhum destes atalhos está implementado.

## Falhas, offline, sessão e dados pessoais

- A tela só confirma após retorno do gateway; na simulação o texto declara ausência de efeitos reais.
- Sem rede não existe fila de mutação offline. Resultado desconhecido retém somente o comando em memória e bloqueia outro comando/contexto até retomar a mesma operação.
- Conflito/inválido exige nova consulta; acesso negado limpa dados/contexto. Erros brutos do provider nunca aparecem na UI.
- Logout, troca de conta ou ambiente: host chama replaceSession; controller descarta rascunho/comando/dados e ignora respostas tardias. A tela limpa campos, inclusive senha. Sair não cancela uma mutação já recebida no servidor: reconciliação após novo login é responsabilidade do backend futuro.
- Motivo não deve conter dados sensíveis. Cadastro usa campos necessários da identidade existente, em memória; sem logging, persistência, analytics ou Sheets. Testes só usam dados sintéticos.
- Não existe integração produtiva que garanta esses comportamentos de servidor nesta entrega. Comandos e tela precisam de API/RBAC reais antes de navegação/flag de release.

## Matriz de aceitação

| Escopo | Evidência nesta fatia | Gate seguinte |
|---|---|---|
| Busca/cadastro/matrícula/associação/correção | controller + tela + gateway fake em testes | adapter/API e ledger real |
| Replay/perda de resposta/duplo envio/conflito | testes focais de controller | concorrência/SQL/idempotência no servidor |
| Sessão e contexto | testes A→B e limpeza da tela | integração AuthRepository por conta/ambiente |
| Baseline/privacidade | pendência nullable, dados sintéticos e zero export | vínculo humano e política de retenção |
| Acessibilidade | scroll, labels e texto ampliado no teste widget | Android/TalkBack e operação real em staging |
| #30 integral | BLOCKED | API+UI+staging e aceite do contrato completo |

## Verificação e próxima fatia

Rodar somente analyze de lib/features/operations e test/features/operations,
e flutter test test/features/operations com SDK histórico 3.44.9. O junction
histórico aponta outra checkout; usar junction exclusivo tds-operator-flow-qa,
sem substituir o existente. Resultados exatos registrados no checkpoint abaixo.

Staging necessário após integração: contas sintéticas de duas instituições,
operador/turma válidos e outro contexto negado; pessoa existente e nova; cadastro,
matrícula, associação, correção com motivo e leitura do histórico pela UI;
replay/timeouts/conflito; revogação imediata; baseline ausente; edição preservada;
logout A→B; nenhuma escrita em Sheets. Sem produção/AAB/alteração de certificados.

Rollback desta fatia: retirar apenas os arquivos novos do candidato. Não existe
estado persistido nem navegação publicada para reverter. Backend, AuthRepository,
rotas existentes, schema, assinatura, flags e release permanecem fora do writer.

### Checkpoint inicial 03/10

Flutter 3.44.9, Windows, junction exclusivo: pub get --enforce-lockfile PASS;
analyze focal PASS após cinco ajustes de estilo; controller 10/10 PASS.
Widget: 1/3 PASS, 2 FAIL de harness (conteúdo lazy fora da viewport; correção de
scroll revelou seleção ambígua entre Scrollables de TextField e ListView).
Não equivale a falha comprovada do fluxo nem a aceite visual. Após diagnóstico
e rodada estrutural, teste pausado; correção proposta é selecionar explicitamente
o Scrollable vertical, mantendo viewport/asserts. Nenhuma captura/Android/staging.

Extensão autorizada #37 comentário 5970142905: após merge da base 873962a (#39),
este mesmo escritor assume backend, migration aditiva após0022, gateway real e
entrada Flutter. Não há outro escritor no contrato central. O plano e gates
acima continuam válidos; frontend inicial é checkpoint incompleto, não entrega final.
