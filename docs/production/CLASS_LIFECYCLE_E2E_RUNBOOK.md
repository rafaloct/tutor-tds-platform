# Issue #140 — Runbook E2E da jornada operacional da turma

## Status deste documento

**FRONT:** `CLASS_LIFECYCLE_E2E`
**TARGET_MACHINE:** avellaria
**BASE:** `staging@3fc856c8adcd76378322d9de321084ce58c57e1b`
**API_HEAD:** `1dea14ae741bd0ba141f43b22296c7e297b6e320` (#143)
**APP_HEAD:** `1dc027ff2ad243c989db8d884453bc51e79f3021` (#144)
**MERGE_ALLOWED:** NO
**PRODUCTION_ALLOWED:** NO
**STAGING_MUTATION:** NO

Este runbook prova a integração. Ele não redefine regra de negócio. O backend da
#138/#143 e o Flutter da #139/#144 já estão compostos na `staging` acima. A
execução final da #140 usa API HTTPS e banco descartáveis no avellaria, dados
sintéticos e o adapter Flutter real no emulador. Nenhum PASS pode vir de mock,
staging compartilhado ou produção.

## 1. Contratos já observados que devem ser preservados

1. `Classroom` é a turma canônica e fixa `CourseVersion`.
2. QR/check-in é evidência/sugestão e **não** confirma presença oficial.
3. Presença oficial exige decisão humana contextual, auditável e idempotente.
4. Um encontro pode ser fechado com pendências, mas isso precisa ser explícito.
5. Turma fechada não aceita novo vínculo.
6. Professor e monitor não têm a mesma projeção operacional.
7. Pedido de certificado aprovado não significa emissão institucional.
8. Offline/reconnect não pode duplicar presença ou eventos.
9. Backend é autoridade para capacidade e permissões.
10. Produção, KV oficial e emissão institucional ficam fora deste E2E.

## 2. Decisões humanas vigentes consumidas

### Autoridade

| Papel | Preparar | Ativar | Encerrar | Equipe | Participantes |
|---|---:|---:|---:|---:|---:|
| `program_operator` | sim | não | não | limitado por capability | sim, no escopo |
| `coordinator` | sim | sim | sim | sim | sim |
| `teacher` | não | não | não | não | inclusão operacional elegível |
| `monitor` | não | não | não | não | acompanhamento/exceções |

### Capacidade

- padrão: 30;
- `program_operator` é bloqueado ao atingir 30;
- `coordinator` pode ultrapassar 30;
- exceção exige motivo, ator e auditoria;
- nenhuma exceção silenciosa;
- UI mostra ocupação/capacidade/estado da exceção;
- backend decide.

## 3. Dataset sintético canônico

O E2E deve criar dados novos por `run_id`; nunca reaproveitar participante/turma
real nem alterar fixtures aprovadas de outro gate.

| Entidade | Valor sintético |
|---|---|
| Instituição A | `qa-i1`, somente no banco descartável |
| Programa A | `qa-p1`, somente no banco descartável |
| Programa B | `qa-p2`, programa/instituição estrangeiros para negação |
| Curso | `qa-course` com versão publicada `qa-v1` |
| CourseVersion v1 | versão fixada na turma |
| CourseVersion v2 | cenário coberto pelo teste canônico de snapshot, não criado pelo Android |
| Município da oferta | Palmas |
| Local físico | `Laboratório QA Avellaria <run_id>` |
| Município de residência do participante A | Itaguatins, fixture externa sintética |
| Participante A | `qa-student` |
| Participante estrangeiro | `qa-outsider`, ligado ao programa/instituição B |
| Coordenador | `qa-coordinator` |
| Program operator | `qa-operator` |
| Professor | `qa-teacher` |
| Monitor | `qa-monitor` |

**Prova obrigatória de territorialidade:** o domínio atual não persiste município
de residência do participante. Portanto `Itaguatins` é referência sintética
externa do E2E, enquanto `Palmas` é persistido exclusivamente como município da
oferta da turma. O manifesto só pode marcar PASS se os valores forem distintos e
a residência externa não for copiada para o registro da turma.

## 4. Composição dos HEADs

A composição upstream já ocorreu em `staging`:

```text
API_HEAD=1dea14ae741bd0ba141f43b22296c7e297b6e320
APP_HEAD=1dc027ff2ad243c989db8d884453bc51e79f3021
BASE_HEAD=3fc856c8adcd76378322d9de321084ce58c57e1b
COMPOSE_HEAD=<commit da #140 efetivamente executado>
```

A branch da #140 recebe a staging por merge normal, preservando histórico. O
`COMPOSE_HEAD` deve identificar o commit que contém harness + servidor QA +
integration test executados. Nenhuma branch upstream é reescrita.

## 5. Jornada E2E principal

### E01 — Preparar turma

**Ator:** program_operator.

1. Abrir Gestão → Preparar turma.
2. Informar Palmas como município da oferta.
3. Informar `Laboratório QA Avellaria <run_id>` como local físico.
4. Selecionar programa/curso.
5. Confirmar que o servidor resolve a CourseVersion publicada.
6. Informar datas.
7. Definir professor/monitor conforme capabilities.
8. Revisar e preparar.

**PASS quando:**

- status inicial é `planned`;
- município/local persistem;
- nenhum campo residencial é inferido;
- CourseVersion v1 fica gravada;
- ator/motivo/auditoria são verificáveis;
- program_operator não recebe ação de ativar/encerrar.

**Evidência:**

- `01_prepare_class_operator.png`
- `01_prepare_class_api.json`
- `01_prepare_class_audit.json`

### E02 — Ativar turma

**Ator:** coordinator.

1. Abrir a turma preparada.
2. Ver readiness/capabilities.
3. Ativar.

**PASS quando:**

- `planned → active`;
- coordinator é ator auditado;
- program_operator/teacher/monitor não conseguem reproduzir a transição.

### E03 — Participante e matrícula

**Ator:** program_operator ou coordinator.

1. Usar o fluxo/repositório existente de Participantes.
2. Localizar Participante A já sintético no banco descartável.
3. Manter a referência externa de residência = Itaguatins fora do registro da turma.
4. Usar a matrícula ativa sintética no programa/curso.
5. Vincular à turma.
6. Repetir exatamente a mesma operação.

**PASS quando:**

- não existe segundo cadastro de participante;
- vínculo aponta para matrícula canônica;
- replay é idempotente, nunca duplicata;
- turma continua com oferta em Palmas;
- nenhuma propriedade residencial é criada/inferida no Classroom;
- o manifesto registra Itaguatins apenas como fixture externa de contraste.

### E04 — Cross-program e cross-institution

Tentar vincular participante estrangeiro.

**PASS quando:** resposta fail-closed e nenhum vínculo é criado.

### E05 — Capacidade 30 / exceção 31

Este caso de carga é executado pelo teste backend canônico
`test_capacity_30_blocks_operator_and_only_coordinator_override_is_audited`.
O Android consome a capacidade retornada pelo mesmo contrato, mas não cria 31
contas apenas para repetir uma prova já autoritativa.

**PASS quando o teste canônico comprovar:**

- program_operator é bloqueado em 30;
- coordinator sem motivo é bloqueado;
- coordinator com motivo explícito consegue apenas se capability autorizar;
- auditoria registra ator/motivo;
- backend continua autoridade da capacidade.

### E06 — Abrir encontro

**Ator:** teacher.

1. Abrir um encontro.
2. Gerar/rotacionar token de check-in.
3. Exibir QR.

**PASS quando:**

- encontro pertence à turma ativa;
- token tem validade/versão;
- monitor pode acompanhar conforme capability;
- participante estrangeiro não acessa.

### E07 — QR/check-in não é presença oficial

1. Participante A faz check-in por QR.
2. Ler roster/presença antes da conferência humana.

**PASS quando:**

- check-in existe;
- presença oficial **não** vira `confirmed_present` automaticamente;
- projeção pode indicar `suggested_present`, nunca presença oficial confirmada.

**Evidência:**

- `07_qr_participant.png`
- `07_roster_after_qr.json`

### E08 — Conferência humana + evidências

**Ator:** teacher.

1. Confirmar presença humana do Participante A.
2. Registrar também decisão oficial `VALID`.
3. Manter a evidência de QR pendente de revisão.
4. Monitor consulta sua superfície e tenta uma ação reservada ao professor.

**PASS quando:**

- Participante A = `confirmed_present` após decisão humana;
- decisão oficial = `VALID`;
- a evidência do QR permanece explicitamente pendente até o fechamento;
- decisão tem ator, revisão e chave idempotente;
- monitor consegue consultar a projeção permitida, mas não fechar encontro;
- superfícies/capabilities são distintas.

### E09 — Fechar encontro com pendência explícita

1. Tentar fechar sem confirmação de pendência.
2. Esperar bloqueio.
3. Repetir com confirmação explícita.

**PASS quando:**

- primeira tentativa = conflito/bloqueio;
- segunda fecha;
- relatório registra pendência explicitamente;
- presença não é fabricada;
- nova decisão mutável após fechamento é recusada, salvo replay exato permitido.

### E10 — Imutabilidade da CourseVersion

O Android prova que a mesma `qa-v1` permanece do preparo ao encerramento. O
cenário pesado de publicar v2 depois da criação é executado pelo teste canônico
`test_class_keeps_snapshot_after_new_publication_and_archive`.

**PASS quando ambas as provas concordarem:**

- turma permanece em v1 no live E2E;
- nova publicação não troca a versão de turma existente no teste canônico;
- nenhuma troca silenciosa de versão ocorre.

### E11 — Offline/reconnect

O fluxo de QR não usa fila offline acadêmica. O E2E simula indisponibilidade de
rede, descarta a sessão HTTP do participante, autentica novamente e reapresenta
**a mesma** chave idempotente de check-in.

**PASS quando:**

- a indisponibilidade é observada sem mutação;
- o reconnect usa o mesmo participante/contexto;
- replay exato retorna o mesmo check-in;
- roster continua com `checkin_count=1`;
- presença humana não duplica.

### E12 — Readiness de encerramento da turma

**Ator:** coordinator.

Abrir Encerrar turma.

**PASS quando a UI/readiness mostra de forma compreensível:**

- sessões abertas/fechadas;
- pendências de presença/evidência;
- ocupação;
- pedidos de certificado;
- boundary de emissão;
- ação de encerrar só aparece com capability.

Se readiness não permitir fechar, registrar exatamente a pendência; não contornar.

### E13 — Encerrar turma

Somente após readiness permitir, coordinator encerra.

**PASS quando:**

- `active → closed`;
- transição é auditada;
- nova matrícula/vínculo à turma fechada é recusado;
- consultas históricas continuam legíveis.

### E14 — Boundary do certificado

Para Participante A elegível:

1. criar pedido;
2. revisar/aprovar pelo papel autorizado;
3. reler como participante;
4. consultar referências/emissão institucional.

**PASS final da #140 quando:**

```json
{
  "request_status": "approved",
  "emitted": false,
  "institutional_release": "blocked"
}
```

Nenhum Worker/KV oficial é acionado neste E2E. “Aprovado” não pode aparecer como
“emitido”, “válido institucionalmente” ou equivalente.

## 6. Matriz negativa obrigatória

| Caso | Resultado |
|---|---|
| program_operator ativa turma | denied |
| program_operator encerra turma | denied |
| teacher encerra turma | denied |
| monitor prepara/ativa/encerra | denied |
| 31º aluno por program_operator | denied |
| 31º por coordinator sem motivo | denied |
| participante de outro programa | denied |
| participante de outra instituição | denied |
| QR sem revisão humana | não vira presença oficial |
| decisão de presença após sessão fechada | denied, salvo replay exato |
| nova inclusão após turma fechada | denied |
| CourseVersion v2 após ativação | turma permanece v1 |
| pedido aprovado com gate institucional fechado | não emitido |

## 7. Evidência visual

A apresentação do wizard já foi homologada no PR #144 e está versionada em
`docs/qa/class-lifecycle-2026-10-05/`. Como a composição da #140 não altera UI,
essas screenshots são reutilizadas para preparo/readiness/encerramento.

A #140 acrescenta evidência **estruturada** da integração real para QR, roster,
reconnect, presença e certificado. Não é permitido criar screenshots que
exponham token de QR, CPF, senha, JWT ou secret apenas para aumentar volume de
evidência.

## 8. Evidência estruturada

Arquivo final:

`docs/production/evidence/class-lifecycle-e2e-<run_id>.json`

Validar com:

```bash
python3 tooling/class_lifecycle_e2e/harness.py \
  --api-head <API_HEAD> \
  --app-head <APP_HEAD> \
  --compose-head <COMPOSE_HEAD> \
  --base-url https://10.0.2.2:<porta> \
  --package com.tutortds_cartilhas.dev.dynamicqa.r<32hex> \
  --device emulator-5556 \
  --api-python /home/rafael/TutorTDSWorker/.venv-api-a01/bin/python \
  --evidence-output docs/production/evidence/class-lifecycle-e2e-<run_id>.json \
  --execute

python3 tooling/class_lifecycle_e2e/harness.py \
  --api-head <API_HEAD> \
  --app-head <APP_HEAD> \
  --compose-head <COMPOSE_HEAD> \
  --base-url https://10.0.2.2:<porta> \
  --package com.tutortds_cartilhas.dev.dynamicqa.r<32hex> \
  --device emulator-5556 \
  --validate-evidence docs/production/evidence/class-lifecycle-e2e-<run_id>.json \
  --require-complete
```

O validador recusa PASS se qualquer etapa/invariante permanecer `NOT_RUN`,
`BLOCKED` ou `FAIL`.

## 9. Stop conditions

Parar e registrar `BLOCKED` se:

- API_HEAD ou APP_HEAD não estiver estável;
- contrato de #138 divergir da decisão humana aprovada;
- UI da #139 codificar autoridade/capacidade no cliente;
- algum passo exigir production/staging mutation;
- segredo for necessário;
- dado pessoal real for necessário;
- emissão institucional real for necessária;
- duas tentativas repetirem o mesmo erro estrutural.

Diagnóstico deve conter:

```text
Observed
Expected
Responsible Boundary
Evidence
Likely Root Cause
Affected Files
Structural Fix
```

## 10. Saída final da Issue #140

```text
FRONT=CLASS_LIFECYCLE_E2E
API_HEAD=
APP_HEAD=
COMPOSE_HEAD=
E2E_PREPARE_CLASS=
E2E_PARTICIPANT=
E2E_MEETING=
E2E_ATTENDANCE=
E2E_CLOSE_MEETING=
E2E_CLOSE_CLASS_READINESS=
CERTIFICATE_BOUNDARY=
OFFLINE_RECONNECT=
VISUAL_EVIDENCE=
BLOCKER=
NEXT=AGUARDAR_COORDENADOR
```
