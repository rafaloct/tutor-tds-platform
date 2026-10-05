# Operação de participantes — candidato integrado (#30)

Base: merge normal de `873962afb613f183a7f1d81e97d5d77979278fd6`.
Ownership ampliado pelo packet #37 / 5970142905, config / 5970229954.

## Estado atual

OBSERVED: backend `/operations`, adapter HTTP autenticado, controller e entrada
Flutter implementados; candidato local ainda sujeito a revisão e staging.
Não equivale a produção aprovada nem ao encerramento integral de #30.
A seção histórica abaixo descreve somente o checkpoint inicial, substituído
por este contrato atual quanto a escopo e implementação.

Fluxo: selecionar programa/curso/turma/edição; localizar pessoa; cadastrar se
inexistente; matricular; vincular à turma; consultar baseline/histórico; corrigir
mediante revogação motivada e associação a outra turma. Correção tem dois comandos
visíveis; não é transferência atômica. Nenhuma duplicação de User/Enrollment,
importação Sheets ou autoridade acadêmica criada por telemetria.

## Contrato HTTP e autoridade

- GET `/operations/scopes`: contextos com edição fixada e vínculo de programa ativo.
- POST `/operations/{class_id}/search`: nome restrito ao programa ou CPF exato;
  retorna somente id/nome e prova assinada temporária de identidade.
- POST `/operations/{class_id}/inspect`: pessoa/contexto/revisão/vínculos/baseline/histórico.
- POST `/operations/{class_id}/commands`: register, enroll, assign ou revoke,
  com chave única, contexto completo, revisão esperada, motivo e identidade.

Toda operação exige usuário existente e ProgramMembership ativo com papel
program_operator, coordinator ou admin. Admin global sem vínculo não passa.
Professor/monitor não recebe poder novo. Provisionamento de equipe usa os meios
administrativos existentes; não há concessão de papel no cliente. Criar pessoa
reutiliza AuthService e concede apenas vínculo student. Vincular turma reutiliza
bind_student e preserva edição/Enrollment existentes. Não altera emissão,
presença, follow-up ou exportações.

Lookup externo exige CPF exato: prova assinada vincula ator/programa/pessoa por
10 minutos. O adapter transporta a prova em bodies, nunca na URL. Essa prova não
substitui autorização. Busca por nome não faz casamento automático nem consulta
pessoas fora do programa. Baseline ausente não impede matrícula ou estudo.

## Consistência e privacidade

Migration aditiva 20261003_0023 após 0022 cria OperatorCommandReceipt. Comando e
recibo confirmam na mesma transação. Lock de Program serializa comandos entre
turmas; revisão é por pessoa/programa. Chave idêntica devolve o resultado confirmado,
inclusive depois do fechamento da turma; comando novo em turma fechada falha.
Ator/corpo/contexto divergente falha. Revogação de permissão bloqueia inclusive replay.

Hash HMAC usa o secret JWT existente e não persiste CPF/senha. Troca desse secret
pode invalidar replay antigo; nesses casos exige reconciliação por leitura, nunca
reenvio de cadastro com chave nova presumindo falha. Histórico guarda referências,
sem duplicar actor_id no snapshot. Exclusão de titular remove seus recibos;
exclusão permitida de antigo ator anonimiza referência, inclusive no SQLite sem
cascata. Motivos não devem conter dados sensíveis. Nenhum dado sintético é real.

Flutter usa AuthRepository e chave local conta/ambiente/geração. Valida sessão antes
e depois da requisição; watcher limpa tela ociosa quando a geração muda. Sem fila
offline: resultado desconhecido mantém somente o comando em memória para retry.
Erros brutos não aparecem na UI. Sair não desfaz comando já confirmado no servidor.

## Flags e limites de release

Backend `OPERATOR_OPERATIONS_ENABLED=false` e Dart define de mesmo nome false por
padrão. Habilitar ambos somente em ambiente de aceite autorizado. Não exige secret
novo nem altera preflight produtivo. Navegação fica oculta com flag desligada.
Rollback atual: desligar as flags e preservar o ledger criado pela migração
20261003_0023. O downgrade para 0022 é recusado quando existem recibos;
forward recovery preserva o histórico. Remover arquivos não reverte comandos
já confirmados nem autoriza apagar seus registros.

TARGET staging: fluxo completo com duas instituições, permissão revogada,
identidade nova/existente, replay/timeouts/conflitos, edição preservada, baseline
ausente, logout A→B e Android/TalkBack. Nenhum deploy/AAB/produção nesta execução.
Gestão integral de equipe/ofertas/instituições e aceite visual permanecem fora
deste incremento. #30 continua aberta até seus critérios integrais.

## Extensão #138 — lifecycle territorial da turma

O backend passa a expor o contrato contextual de turma em
`/operations/classes`, atrás de `CLASS_LIFECYCLE_ENABLED=false` por padrão.
A preparação fixa a CourseVersion publicada no servidor e persiste
`offer_municipality` e `offer_location` sem copiar residência do participante.

RBAC do candidato: program_operator/coordinator podem preparar e alterar
planejamento/equipe enquanto a turma está `planned`; somente coordinator pode
ativar, encerrar, alterar equipe após ativação ou autorizar exceção de capacidade.
Professor/monitor não recebem poder administrativo novo. Readiness do professor
fica limitado à própria turma.

Lifecycle canônico: `planned -> active -> closed`. Comandos exigem ator,
motivo, contexto completo, idempotency key e `expected_revision`; replay
divergente ou CAS stale falha. `classroom_command_receipts` preserva a trilha.
Encerramento apenas muda o lifecycle e projeta warnings; não cria presença,
frequência, capacitação ou certificado.

Capacidade padrão é 30 vínculos ativos. Todas as rotas HTTP canônicas de inclusão
bloqueiam o 31º vínculo. Exceção só existe pelo comando contextual de coordinator,
com motivo, registrada como `assign_capacity_override`; admin/teacher não
possuem bypass. Turma `closed` não aceita novos vínculos.

Endpoints: `GET /operations/classes/options`, `POST /operations/classes`,
`POST /operations/classes/{id}/plan`, `POST /operations/classes/{id}/team`,
`POST /operations/classes/{id}/transition` e
`GET /operations/classes/{id}/readiness`.

Migration 0028 é aditiva e recusa downgrade quando houver território/revisão ou
recibos novos. Prova local SQLite cobre a fatia; PostgreSQL permanece gate
explícito ainda não comprovado nesta execução. Sem staging/produção.

## Histórico — checkpoint inicial anterior ao backend
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

Rollback do checkpoint inicial, anterior ao backend (histórico): naquela fatia
bastava retirar os arquivos novos, pois ainda não existia estado persistido ou
navegação publicada. Backend, AuthRepository, rotas existentes, schema, assinatura,
flags e release ainda estavam fora do writer. Essa orientação foi substituída
pelo rollback atual com ledger e migração 0023 descrito acima.

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
## Evidência final do candidato local — 03/10/2026

| Gate | Resultado |
|---|---|
| Flutter analyze focal + Home | PASS, zero issues |
| Controller | 10/10 PASS |
| Widget | 3/3 PASS; falhas iniciais de harness corrigidas com scroll vertical/alinhamento explícitos, sem alterar viewport/asserts |
| Adapter HTTP | 1/1 PASS; proof em bodies, retry idêntico e invalidação da sessão |
| API SQLite | 10/10 PASS; fluxo, autorização, replay, privacidade, ausência de cascata e migration |
| PostgreSQL 17.11 isolado | 4/4 PASS; replay após fechamento, anonimização, upgrade/downgrade protegido e duas requisições concorrentes/um recibo |
| Android/visual/TalkBack/staging | PENDING; não executados |

PostgreSQL usa runtime já validado por #39, cluster exclusivo loopback15430,
role qa_operator e databases descartáveis com UUID; nenhum banco real utilizado.
Não há secret novo. Baseline é somente presença de vínculo; não é qualidade ou
conclusão acadêmica. Papel program_operator é reconhecido pelo servidor, mas o
provisionamento legado aceita coordinator/admin escopados; adicionar a concessão
específica e gestão de equipe requer a próxima fatia de #30.
`api/tests/test_certificate_postgres_integration.py`: ownership ampliado pelo integrador; quatro asserts de head atualizados para0023 explícito; focal PostgreSQL5/5 PASS. Checkpoint #37 comentário5970357270. Clusters locais encerrados após validação.
