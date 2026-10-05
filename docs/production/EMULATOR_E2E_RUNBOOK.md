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
| `EMULATOR_E2E_QA_PACKAGE` | pacote QA isolado `.dev` (nunca `com.tutortds_cartilhas`) |
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
      --package <pkg>.dev --device emulator-5556

Testes do harness:

    cd tooling/mobile_qa/emulator && python3 -m unittest

Execução real (somente após gate humano e #79/#80 reconciliados):
adicionar `--execute`. A saída é sanitizada (tokens, Bearer, JWT, CPF, senhas e
valores de credenciais QA são redigidos).

## Gate humano
Rafael autoriza: reconciliação de #79/#80, uso exclusivo do emulador/SDK e
credenciais QA de staging. Até lá os cenários Dart falham deliberadamente.
