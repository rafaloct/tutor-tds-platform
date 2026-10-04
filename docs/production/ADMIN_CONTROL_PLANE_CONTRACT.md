# Control plane administrativo do Tutor TDS — contrato canônico da Issue #30

Estado: **CONTRATO DOCUMENTAL — implementação parcial já canônica; ciclo administrativo de papéis/equipe ainda BLOCKED**.

Base auditada: `d06b1c95ec09035c7ebd8855af34704a85566b0b` em 04/10/2026.

Este documento consolida a auditoria read-only da Issue #30. Ele descreve somente
entidades, rotas e telas observadas na base acima. Não autoriza novas permissões,
não substitui RBAC e não transforma operações ainda inexistentes em requisitos
implícitos de API.

## 1. Objetivo e limites

O control plane deve permitir operar o Programa TDS sem editar PostgreSQL ou
Sheets manualmente e **sem criar um segundo cadastro de pessoas, matrículas,
turmas ou contexto acadêmico**.

A autoridade continua nas entidades de domínio existentes. Sheets, BI, evidências,
baseline e telemetria podem fornecer referências ou projeções, mas não substituem
`User`, `ProgramMembership`, `Enrollment`, `Classroom` ou
`LearningContext`.

Escopo já funcional desta fatia:

`pessoa → vínculo de programa → matrícula → turma/edição → revogação do vínculo da turma → histórico`

Escopo ainda não completo:

`provisionamento/revogação de program_operator → gestão integral de professor/monitor → ciclo administrativo de equipe`

Não fazem parte deste contrato: frequência, certificado, mentoria, migração
massiva de baseline, escrita em Sheets como origem mestre, deploy ou produção.

## 2. Entidades reutilizadas

| Necessidade operacional | Entidade canônica | Regra |
| --- | --- | --- |
| Pessoa/conta | `User` | identidade única; não duplicar cadastro para cada programa |
| Vínculo institucional | `ProgramMembership` | papel e status no escopo do programa |
| Matrícula em curso | `Enrollment` | depende de membership ativa e oferta válida |
| Instituição | `Institution` | origem da hierarquia institucional |
| Programa | `Program` | escopo operacional principal |
| Oferta | `ProgramCourse` | liga programa ao curso e carga planejada |
| Curso | `Course` | catálogo canônico |
| Edição | `CourseVersion` | turma deve apontar para versão publicada/arquivada válida |
| Turma/coorte | `Classroom` | programa, curso, edição, professor e período |
| Papel contextual | `CohortMembership` | student/teacher/monitor ativo ou inativo na turma |
| Matrícula contextual | `ClassEnrollment` | liga Enrollment à turma e edição |
| Monitor da turma | `ClassMonitor` | atribuição explícita no contexto da turma |
| Contexto de estudo | `LearningContext` | projeção resolvida da linhagem consistente |
| Baseline | `StudentBaseline` + `BaselineSourceRecord` | referência humana revisada, nunca identidade mestre |
| Auditoria operacional | `OperatorCommandReceipt` | recibo idempotente de comandos do operador |

Referências de implementação:
[models.py](../../api/app/models.py),
[operator_operations.py](../../api/app/operator_operations.py),
[classrooms.py](../../api/app/classrooms.py),
[learning_context.py](../../api/app/learning_context.py) e
[student_followup.py](../../api/app/student_followup.py).

## 3. Superfícies existentes

### 3.1 Operação contextual de participantes

Rotas observadas em [operator_operations.py](../../api/app/operator_operations.py):

- `GET /operations/scopes`
- `POST /operations/{class_id}/search`
- `POST /operations/{class_id}/inspect`
- `POST /operations/{class_id}/commands`

Ações aceitas por `commands`:

- `register`
- `enroll`
- `assign`
- `revoke`

Essas ações formam o caminho suportado para pessoa, matrícula, associação à turma
e revogação do vínculo **do estudante naquela turma**. `revoke` não desativa
conta, membership de programa, professor ou monitor.

### 3.2 Administração global já existente

Rotas observadas em
[organizations.py](../../api/app/organizations.py) e
[classrooms.py](../../api/app/classrooms.py):

- `POST /admin/institutions`
- `POST /admin/programs`
- `POST /admin/programs/{program_id}/courses/{course_id}`
- `PUT /admin/programs/{program_id}/courses/{course_id}/workload`
- `POST /admin/programs/{program_id}/memberships`
- `POST /admin/accounts`
- `POST /admin/enrollments`
- `GET /admin/hierarchy`
- `POST /admin/classes`
- `POST /admin/classes/{class_id}/students/{user_id}`
- `POST /admin/classes/{class_id}/monitors/{user_id}`

Também existem:

- `GET /classes/{class_id}/eligible-students`
- `PUT /classes/{class_id}/students/{user_id}`

Essas rotas não equivalem a um ciclo administrativo completo de equipe. Operações
de remoção/revogação de monitor, reatribuição de professor e revogação de
`ProgramMembership` não foram encontradas na base auditada e ficam **BLOCKED**.

### 3.3 Flutter já integrado

Superfícies observadas:

- [operations_repository.dart](../../cartilhas_app/lib/features/operations/operations_repository.dart):
  adapter HTTP real para `/operations`;
- [operations_controller.dart](../../cartilhas_app/lib/features/operations/operations_controller.dart):
  máquina de estado, retry e revisão;
- [operations_screen.dart](../../cartilhas_app/lib/features/operations/operations_screen.dart):
  localizar/cadastrar/matricular/vincular/revogar;
- [operations_entry.dart](../../cartilhas_app/lib/features/operations/operations_entry.dart):
  entrada condicionada por sessão e flag;
- [management_workspace_screen.dart](../../cartilhas_app/lib/features/management/presentation/management_workspace_screen.dart):
  hub Gestão;
- [classroom_roster_screen.dart](../../cartilhas_app/lib/features/classrooms/presentation/classroom_roster_screen.dart):
  inclusão de estudante já elegível na turma.

A Home só exibe Gestão quando o servidor confirma capacidades. Preferência local,
rótulo visual ou papel cacheado não concede autorização.

## 4. Modelo de fluxo operacional

### 4.1 Localizar pessoa existente

1. Operador seleciona um contexto retornado por `GET /operations/scopes`.
2. Busca por nome permanece restrita às pessoas já vinculadas ao programa.
3. Busca por CPF exato pode localizar uma pessoa existente fora do programa.
4. Nesse caso o servidor devolve uma prova de identidade temporária vinculada a
   ator, programa e pessoa.
5. A prova só permite continuar a revisão do vínculo; não substitui autorização.

**Proibido:** casar identidade automaticamente por nome, telefone, baseline ou BI.

### 4.2 Criar pessoa

`register` reutiliza `AuthService`, cria um único `User` e adiciona somente
`ProgramMembership(role=student, status=active)` no programa selecionado.

Repetição divergente deve falhar. CPF e senha não podem ser persistidos no ledger
de auditoria.

### 4.3 Vincular ao programa e matricular

`enroll`:

- exige contexto autorizado;
- cria `ProgramMembership student` quando ainda não existe;
- exige que o curso esteja ofertado no programa;
- cria ou reutiliza a única `Enrollment` correspondente;
- não reativa automaticamente membership ou matrícula previamente inativas.

Membership/matrícula inativa exige revisão administrativa específica. Como esse
ciclo ainda não possui endpoint completo, a correção é **BLOCKED**, não deve ser
contornada por SQL operacional.

### 4.4 Associar à turma/edição

`assign`:

- exige Enrollment ativa;
- usa a turma já selecionada;
- preserva programa, curso e edição pinada;
- cria/reativa `ClassEnrollment`;
- chama o binding contextual para `CohortMembership(student)`;
- não pode repontar uma matrícula contextual existente para outra edição.

A leitura canônica do aluno é
[LearningContext](../../api/app/learning_context.py). Contexto inconsistente,
edição ausente ou membership inativa falha de forma fechada.

### 4.5 Gestão de equipe

Já suportado:

- criação de conta gerenciada por admin;
- criação de turma com professor que possua membership `teacher` ativa;
- inclusão de monitor já vinculado ao programa;
- criação do binding contextual teacher/monitor.

Ainda **BLOCKED**:

- conceder `program_operator` pela API tipada atual;
- revogar/reactivar `ProgramMembership` por fluxo administrativo suportado;
- remover/revogar `ClassMonitor`;
- reatribuir professor com histórico e regra de integridade explícitos;
- UI Flutter para criar instituição/programa/oferta/turma/conta/equipe.

Nenhuma dessas lacunas autoriza editar banco diretamente como solução permanente.

### 4.6 Revogação e correção do estudante

`revoke` do operador:

- inativa `ClassEnrollment`;
- inativa o `CohortMembership(student)` correspondente quando presente;
- preserva pessoa, matrícula do curso e histórico;
- não apaga dados acadêmicos;
- permite posterior `assign` em outro contexto autorizado, sujeito à revisão.

Correção de turma é uma sequência auditável `revoke → assign`, não transferência
atômica simulada.

### 4.7 Histórico

`OperatorCommandReceipt` registra:

- id do comando;
- ator referenciado;
- pessoa;
- programa;
- turma;
- revisão;
- ação;
- motivo;
- hash do pedido;
- resultado sanitizado;
- timestamp.

O snapshot de leitura retorna o histórico aplicável ao contexto selecionado.

## 5. Idempotência, replay e concorrência

Cada comando mutável deve carregar:

- id opaco único;
- contexto completo;
- ação;
- motivo;
- pessoa;
- revisão esperada;
- prova de identidade quando necessária.

Contrato observado:

1. mesmo id + mesmo ator + mesmo contexto + mesmo corpo retorna o mesmo resultado;
2. mesmo id com corpo/ator/contexto divergente retorna conflito;
3. revisão desatualizada retorna conflito;
4. perda de resposta permite repetir **o mesmo comando**, não criar outro;
5. operador cuja membership foi revogada não pode usar replay como bypass;
6. turma fechada pode reconciliar recibo já confirmado, mas não aceitar comando novo.

O Flutter mantém comando incerto somente em memória e bloqueia navegação até
reconciliação. Não existe fila offline de mutação administrativa.

## 6. Motivo e auditoria

Toda mutação operacional exige `reason` entre 3 e 500 caracteres.

O motivo deve explicar a decisão administrativa e **não** conter CPF, senha,
dados socioeconômicos, conteúdo integral de formulários ou outros dados sensíveis.

O histórico não é autorização. Permissões são reavaliadas em cada requisição.

## 7. Regras de isolamento entre instituições e programas

### Operação contextual

Para `/operations`:

- ator deve possuir `ProgramMembership` ativa no programa da turma;
- somente papéis admitidos pelo backend operacional podem carregar scopes;
- admin global sem membership ativa no programa não recebe bypass;
- contexto enviado pelo cliente deve coincidir com instituição, programa, curso e
  versão calculados pelo servidor;
- busca por nome não atravessa o programa;
- CPF exato pode identificar uma pessoa global, mas o vínculo ao novo programa
  exige prova assinada e comando autorizado;
- turma fora do escopo do programa deve resultar em negação, nunca fallback.

### Administração institucional

As rotas `/admin/**` atuais usam papel global `admin`. O contrato de escopo
institucional detalhado dessas rotas não deve ser ampliado por esta documentação.
Qualquer redução/redistribuição de privilégios administrativos depende da
reconciliação do RBAC do PR #81 e de uma fatia própria.

## 8. Baseline e referência humana

Baseline **não é identidade mestre** e **não é pré-requisito para criar a pessoa,
matricular ou iniciar estudo**.

Regras observadas em
[student_followup.py](../../api/app/student_followup.py):

- vínculo é feito por pessoa já resolvida e turma já autorizada;
- `BaselineSourceRecord` guarda somente referência de origem/registro;
- uma mesma referência não pode ser associada a duas pessoas;
- conflito exige revisão humana;
- BI usa referência opaca, não casamento automático por nome ou CPF;
- atualizações são versionadas por `BaselineRevision`;
- ausência retorna `baseline: null`;
- ausência não apaga pessoa, matrícula ou contexto;
- conteúdo socioeconômico integral não deve ser copiado para o Tutor.

O dashboard pode expor somente o estado de vínculo necessário à operação. O
baseline pode ser regularizado depois da matrícula, respeitando as regras
específicas de certificação fora desta issue.

## 9. RBAC e dependência do PR #81

Estado canônico auditado:

- `/operations` reconhece membership ativa com
  `program_operator | coordinator | admin`;
- professor e monitor não recebem automaticamente permissão de operador;
- escopo de professor/monitor é validado por turma e memberships existentes;
- a API administrativa tipada
  [organizations.py](../../api/app/organizations.py) **não inclui
  `program_operator` em `ProgramRole`**.

O PR #81 (`fix: restringe autorização de monitor`) está draft e ainda não faz
parte da base canônica deste contrato. Seu HEAD auditado é
`969386c08cb6953bf8b991624bf2f619b8ddf968`.

O #81 propõe restringir monitor em analytics, dashboard, eligible-students e
inclusão de alunos, além de preservar uma identidade multi-role quando ela for
monitor em um contexto e professor em outro. O PR também declara explicitamente
que não implementa revogação global de conta de equipe.

**Regra de dependência:** implementação de lifecycle de `program_operator`,
revogação de ProgramMembership, remoção de monitor ou reatribuição de professor
fica **BLOCKED até o caminho RBAC do #81 ser reconciliado com a canônica**.
Não implementar uma matriz concorrente de autorização nesta issue enquanto esse
gate estiver aberto.

## 10. Operações não suportadas

Estado `BLOCKED` na base auditada:

| Operação | Estado | Motivo |
| --- | --- | --- |
| Conceder `program_operator` pela API tipada | BLOCKED | papel reconhecido pelo backend operacional, ausente de `ProgramRole` |
| Revogar/reactivar ProgramMembership | BLOCKED | não há endpoint administrativo observado |
| Remover monitor da turma | BLOCKED | existe add monitor; remoção não observada |
| Reatribuir professor | BLOCKED | criação fixa teacher_id; lifecycle posterior não observado |
| Revogar conta de equipe globalmente | BLOCKED | `revoke` operacional é somente vínculo de estudante/turma |
| Importação massiva de participantes | BLOCKED | nenhum importador administrativo comprovado |
| Criar hierarquia/equipe pelo Flutter | BLOCKED | API existe parcialmente, UI dedicada não |
| Transferência atômica de turma | NÃO SUPORTADA | fluxo correto atual é revoke + assign auditáveis |

Não inventar endpoints para preencher essas linhas.

## 11. Importadores e fontes externas

Importadores observados no repositório tratam conteúdo, evidências e fixtures
sintéticas. Não foi comprovado importador administrativo de participantes.

Sheets, Drive, BI, baseline e evidências podem fornecer referências ou material de
apoio, mas não devem escrever ou substituir as entidades mestres deste contrato.

## 12. Modelo de fluxo disponível hoje

### Disponível sem SQL manual, dado um contexto já provisionado

1. operador autenticado recebe scopes autorizados;
2. seleciona instituição/programa/curso/turma/edição;
3. localiza pessoa existente ou cadastra nova;
4. cria/confirma vínculo student no programa;
5. cria matrícula no curso;
6. associa estudante à turma/edição;
7. consulta baseline como vinculado/pendente;
8. revoga vínculo da turma com motivo;
9. consulta histórico e reconcilia replay.

### Ainda não integral

O fluxo não é um control plane administrativo completo enquanto não houver
lifecycle suportado de operador/equipe. Portanto:

- **END_TO_END participante = disponível**
- **END_TO_END instituição/programa/equipe = incompleto**
- **SQL manual não deve ser usado para contornar operações BLOCKED**

## 13. Próxima fatia mínima após o gate RBAC

Somente depois de reconciliar #81:

1. alinhar o contrato de papéis para suportar `program_operator` sem criar papel
   paralelo;
2. definir mutação auditável/idempotente de status/papel em
   `ProgramMembership`;
3. definir remoção/revogação de `ClassMonitor`;
4. definir regra explícita de reatribuição de professor;
5. expor pequena superfície Flutter em Gestão para essas capacidades, sempre
   derivada do servidor;
6. testar cross-institution denial, multi-role, grant/revoke/replay e token antigo.

Nenhuma migration é presumida por este documento. A necessidade de schema deve ser
demonstrada pela implementação futura, não inferida antecipadamente.

## 14. Critérios de validação documental

Este contrato é válido quando:

- todos os caminhos de código referenciados existem;
- nenhuma rota é descrita como implementada sem existir na base;
- operações ausentes estão marcadas BLOCKED/NÃO SUPORTADA;
- a dependência do PR #81 está explícita;
- `git diff --check` passa;
- CI executa o secret scan do PR;
- nenhuma mudança fora de
  `docs/production/ADMIN_CONTROL_PLANE_CONTRACT.md` é necessária.

Rollback: reverter somente este documento. Não há efeito em runtime, banco,
staging ou produção.
