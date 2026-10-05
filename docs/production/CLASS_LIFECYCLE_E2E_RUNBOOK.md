# Issue #140 — Runbook E2E da jornada operacional da turma

## Status deste documento

**FRONT:** `CLASS_LIFECYCLE_E2E`
**TARGET_MACHINE:** avellaria
**BASE:** `staging@911c4545076da7cb6e70f57d70dccbe1fbe3b446`
**MERGE_ALLOWED:** NO
**PRODUCTION_ALLOWED:** NO
**STAGING_MUTATION:** NO

Este runbook prova a integração. Ele não redefine regra de negócio. A autoridade de
lifecycle/capabilities vem do backend da #138; a experiência Flutter vem da #139.
Enquanto os dois HEADs não estiverem compostos, qualquer etapa dependente deles
permanece **BLOCKED**, nunca PASS por mock.

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
| Instituição A | `IPEX QA <run_id>` ou fixture isolada equivalente |
| Programa A | `Programa QA Turma <run_id>` |
| Programa B | programa estrangeiro para teste de negação |
| Curso | curso QA com versão publicada v1 |
| CourseVersion v1 | versão fixada na turma |
| CourseVersion v2 | publicada **depois** da turma, só para testar imutabilidade |
| Município da oferta | Palmas |
| Local físico | `Laboratório QA Avellaria <run_id>` |
| Município de residência do participante A | Itaguatins |
| Participante A | aluno da jornada positiva |
| Participante B | aluno usado para pendência explícita |
| Participante estrangeiro | programa/instituição diferente |
| Coordenador | capability completa da turma |
| Program operator | prepara e opera vínculos, sem fechar |
| Professor | conduz encontro/presença/evidência |
| Monitor | projeção de exceções/acompanhamento |

**Prova obrigatória de territorialidade:** município da oferta = Palmas e município
de residência do Participante A = Itaguatins. Um não pode ser copiado para o outro.

## 4. Composição dos HEADs

A worktree da #140 é a única que compõe os dois fronts.

Registrar antes da composição:

```text
API_HEAD=<40-char SHA da #138>
APP_HEAD=<40-char SHA da #139>
BASE_HEAD=911c4545076da7cb6e70f57d70dccbe1fbe3b446
```

Regras:

- não rebasear nem force-pushar branches dos outros fronts;
- não editar arquivos da #138/#139 para “fazer o teste passar”;
- integrar os HEADs em branch/worktree da #140 preservando histórico;
- conflito semântico vira BLOCKED;
- após composição registrar `COMPOSE_HEAD`.

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

1. Usar fluxo existente de Participantes.
2. Localizar Participante A.
3. Confirmar residência = Itaguatins.
4. Criar/usar matrícula ativa no programa/curso.
5. Vincular à turma.
6. Repetir a mesma operação.

**PASS quando:**

- não existe segundo cadastro de participante;
- vínculo aponta para matrícula canônica;
- replay é idempotente ou conflito explícito, nunca duplicata;
- turma continua com oferta em Palmas;
- Participante A continua com residência Itaguatins.

### E04 — Cross-program e cross-institution

Tentar vincular participante estrangeiro.

**PASS quando:** resposta fail-closed e nenhum vínculo é criado.

### E05 — Capacidade 30 / exceção 31

1. Preencher turma até 30 com participantes sintéticos.
2. Tentar 31º como program_operator.
3. Repetir como coordinator sem motivo.
4. Repetir como coordinator com motivo.

**PASS quando:**

- program_operator é bloqueado em 30;
- coordinator sem motivo é bloqueado;
- coordinator com motivo explícito consegue apenas se capability autorizar;
- auditoria registra ator/motivo;
- ocupação/capacidade aparecem corretamente no app.

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

1. Confirmar presença oficial do Participante A.
2. Deixar Participante B pendente.
3. Registrar evidência da atividade.
4. Monitor consulta sua superfície.

**PASS quando:**

- Participante A = `confirmed_present`;
- Participante B = `pending`;
- decisão tem ator, revisão e chave idempotente;
- professor vê dashboard operacional;
- monitor vê projeção reduzida/de exceções, sem dados indevidos;
- superfícies são diferentes.

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

Depois de a turma estar ativa, publicar v2 do mesmo curso.

**PASS quando:**

- turma permanece em v1;
- participante vê conteúdo/contexto v1;
- readiness/projeções continuam referenciando v1;
- nenhuma troca silenciosa de versão ocorre.

### E11 — Offline/reconnect

1. Com participante autenticado, ir offline.
2. Registrar exatamente uma ação que use a fila autorizada do fluxo.
3. Reiniciar processo/app conforme cenário.
4. Restaurar rede.
5. Aguardar flush.
6. Repetir reconnect.

**PASS quando:**

- mesmo dono/ambiente/contexto são preservados;
- backend recebe a operação uma vez;
- presença oficial não duplica;
- replay divergente não é aceito como duplicata válida.

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

Capturar no mínimo:

1. preparar turma;
2. ocupação/capacidade;
3. QR/check-in;
4. roster antes da decisão humana;
5. roster depois da decisão;
6. projeção professor;
7. projeção monitor;
8. readiness de encerramento;
9. turma fechada;
10. pedido de certificado aprovado com emissão bloqueada.

Nunca incluir CPF, senha, token, JWT ou secret nas screenshots.

## 8. Evidência estruturada

Arquivo final:

`docs/production/evidence/class-lifecycle-e2e-<run_id>.json`

Validar com:

```bash
python3 tooling/class_lifecycle_e2e/harness.py \
  --api-head <API_HEAD> \
  --app-head <APP_HEAD> \
  --compose-head <COMPOSE_HEAD> \
  --base-url http://10.0.2.2:<porta> \
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
