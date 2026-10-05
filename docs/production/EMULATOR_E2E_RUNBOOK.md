# Emulator E2E Runbook (harness only)

Status: **harness preparado; REAL_E2E_RUN=NO; MERGE_ALLOWED=NO.** Nenhum PASS
de E2E pode ser declarado sem execução real posterior, após reconciliação de
#79/#80. Não altera `cartilhas_app/lib/**`, `api/**`, migrations, staging ou
produção.

## Arquivos
- `tooling/mobile_qa/emulator/e2e_harness.py` — validação fail-closed, dry-run, execução opt-in.
- `tooling/mobile_qa/emulator/test_e2e_harness.py` — testes do harness.
- `cartilhas_app/integration_test/emulator_e2e/emulator_e2e_scenarios_test.dart` — esqueleto dos cenários (falha por design até serem implementados).

## Configuração (argumento ou env; nada versionado)
| Variável | Regra |
|---|---|
| `EMULATOR_E2E_BASE_URL` | https de staging (ou loopback do emulador); host de produção recusado |
| `EMULATOR_E2E_QA_PACKAGE` | pacote QA isolado do Gradle (`DYNAMIC_QA_ISOLATED_PACKAGE=true`, `DYNAMIC_QA_RUN_ID` `^[a-f0-9]{32}$`): `com.tutortds_cartilhas.dev.dynamicqa.r<32-hex>`. O `.dev` legado e produção são recusados |
| `EMULATOR_E2E_DEVICE` | `emulator-<porta>`; dispositivo físico recusado |
| `QA_ACCOUNT_A_ID/_SECRET`, `QA_ACCOUNT_B_ID/_SECRET` | credenciais QA, só via env; nunca impressas |
| `EMULATOR_E2E_CERTIFICATE_CONTEXT_ID` | exigido só para `certificate` (quando backend/contexto existir) |

Configuração ausente ou inválida encerra com código 2 (`CONFIG_REJECTED`).

## Cenários
`login_activation`, `account_switch`, `participant_flow`, `offline_reconnect`,
`certificate` (excluído por padrão; só com `--scenario certificate`).

## Uso
Dry-run / validação estática (sem emulador, sem SDK):

    python3 tooling/mobile_qa/emulator/e2e_harness.py --base-url <staging> \
      --package com.tutortds_cartilhas.dev.dynamicqa.r<32-hex> --device emulator-5556

Testes do harness:

    cd tooling/mobile_qa/emulator && python3 -m unittest

Execução real (somente após gate humano e #79/#80 reconciliados):
adicionar `--execute`. A saída é sanitizada (tokens, Bearer, JWT, CPF, senhas e
valores de credenciais QA são redigidos).

## Gate humano
Rafael autoriza: reconciliação de #79/#80, uso exclusivo do emulador/SDK e
credenciais QA de staging. Até lá os cenários Dart falham deliberadamente.

## Perfil E2E da candidata #122 / Issue #123

Este perfil substitui o skeleton anterior por cenários reais, mas continua
fail-closed: não existe PASS sem interação Android e credenciais sintéticas já
provisionadas no host.

Cenários executáveis por padrão:

- `login_activation`: comprova o campo de código de ativação na UI e login real
  da conta sintética de participante;
- `account_switch`: participante → logout pela UI → professor, com troca real
  da sessão local;
- `participant_flow`: login → Minhas turmas → edição vinculada à turma;
- `teacher_dashboard`: Gestão → Turmas e equipe → dashboard completo;
- `monitor_projection`: Gestão → Acompanhamento da turma, valida a projeção
  mínima e confirma 403 no dashboard completo;
- `creator_surface`: Gestão → Conteúdos → Meus conteúdos/Criar curso;
- `offline_reconnect`: prime online → airplane mode → conteúdo salvo offline →
  reconexão dentro da mesma execução de `flutter test`, preservando o mesmo
  processo/package e o cache local.

`operator_flow` permanece explicitamente bloqueado pela Issue #120. A conta
admin/creator não deve ser usada como substituição de `program_operator`.
`certificate` é um gate opcional e exige contexto de certificado explícito.

Credenciais nunca entram no repositório ou no comando em claro. O host fornece:

- `STAGING_SEED_STUDENT_CPF` / `STAGING_SEED_STUDENT_PASSWORD`;
- `STAGING_SEED_TEACHER_CPF` / `STAGING_SEED_TEACHER_PASSWORD`;
- `STAGING_SEED_MONITOR_CPF` / `STAGING_SEED_MONITOR_PASSWORD`;
- `STAGING_SEED_ADMIN_CPF` / `STAGING_SEED_ADMIN_PASSWORD`.

O harness grava esses valores num JSON temporário para `--dart-define-from-file`,
redige CPF/token/senha dos logs e apaga o arquivo no `finally`.

## Coordenação host ↔ teste em execução

Para preservar o estado offline e capturar evidência visual válida, o teste
Flutter emite apenas sinais fixos e não sensíveis com prefixo
`TDS_E2E_HOST:`. O harness lê stdout em streaming e reage no host:

- `NETWORK_OFFLINE`: ativa airplane mode no emulador;
- `NETWORK_ONLINE`: desativa airplane mode;
- `SCREENSHOT_OFFLINE`: captura a tela ainda no estado offline;
- `SCREENSHOT`: captura a tela validada antes do término do teste.

Sinal desconhecido falha fechado. A ausência das screenshots obrigatórias também
faz o cenário falhar. O harness restaura a rede no `finally`. Não usar screenshot
tirado após o encerramento do `flutter test` como evidência de UI.

Para a candidata atual, o run id é derivado do SHA:

`6c26bfb653d03a5e308d614fbab92cea`

e o package esperado é:

`com.tutortds_cartilhas.dev.dynamicqa.r6c26bfb653d03a5e308d614fbab92cea`

O endpoint de runtime é o staging canônico
`https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`. O build isolado
depende da correção QA-only rastreada em #124/#125, porque o guard anterior
hardcodava somente o endpoint FastAPI Cloud direto.

Exemplo de planejamento sem executar:

```bash
EMULATOR_E2E_BASE_URL=https://ead.ipexdesenvolvimento.cloud/tutor-staging-api \
EMULATOR_E2E_QA_PACKAGE=com.tutortds_cartilhas.dev.dynamicqa.r6c26bfb653d03a5e308d614fbab92cea \
EMULATOR_E2E_DEVICE=emulator-5556 \
EMULATOR_E2E_RUN_ID=6c26bfb653d03a5e308d614fbab92cea \
python3 tooling/mobile_qa/emulator/e2e_harness.py
```

Sem `--execute`, o resultado deve permanecer `NOT_RUN` e listar apenas os
nomes das credenciais ausentes. Com `--execute`, ausência de qualquer
credencial exigida é `CONFIG_REJECTED`.
