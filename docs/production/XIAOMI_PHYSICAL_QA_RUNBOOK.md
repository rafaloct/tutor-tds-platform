# Runbook — QA físico Xiaomi (harness ADB seguro)

TASK_ID=XIAOMI_QA_HARNESS · REAL_DEVICE_RUN=NO · MERGE_ALLOWED=NO

Tooling: `tooling/mobile_qa/xiaomi/harness.py` (Python stdlib, somente leitura).

## Garantias (fail-closed)
- Dry-run por padrão; leitura real só com `--execute`.
- Aceita apenas package QA isolado explícito `com.tutortds_cartilhas.dev.dynamicqa.r<32 hex>`;
  `com.tutortds_cartilhas` e `.dev` (legado) são rejeitados.
- Allowlist de comandos adb: `devices`, `getprop`, `dumpsys package`, `pidof`, `pm path`,
  `logcat -d`. Uninstall, install, `pm clear`, push/pull, screencap, input etc. são bloqueados.
- Screenshot desabilitada. Serial mascarado (`***xx#hash`). Logs sanitizados
  (senha, token, Bearer/JWT, CPF, e-mail).

## Dry-run (sem device)
```
python tooling/mobile_qa/xiaomi/harness.py --package com.tutortds_cartilhas.dev.dynamicqa.r0123456789abcdef0123456789abcdef
```
Imprime JSON com os comandos planejados, sem executar adb.

## Execução local posterior (human gate)
Ação humana exata: no PC autorizado, com o Xiaomi QA conectado e autorizado, rodar o
comando acima com `--execute [--serial <serial>]` e anexar o JSON sanitizado como evidência.
Exige exatamente um device em estado `device`.

## Testes
```
python -m unittest discover -s tooling/mobile_qa/xiaomi/tests
```
