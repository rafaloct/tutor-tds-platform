# Secret scan incremental (gitleaks)

Workflow: `.github/workflows/secret-scan.yml`. Config: `.gitleaks.toml`.

- Escopo: somente os commits novos — PR (`base.sha..head.sha`), push em
  `codex/onda-0-consolidacao` (`before..after`) ou intervalo manual
  (`workflow_dispatch`, input `log_opts`). Não varre o histórico inteiro.
- gitleaks 8.28.0, tarball oficial conferido por SHA-256; `contents: read`,
  `persist-credentials: false`, sem secrets, sem token, sem artefato/relatório.
- Saída sempre com `--redact`: o log mostra regra/arquivo/commit, nunca o valor.
- Falha (exit 1) se houver achado.

## Config (`.gitleaks.toml`)

Estende as regras padrão do gitleaks com duas exceções estreitas:

1. Em `docs/production/evidence/*.json`, valores que são exatamente um SHA-256
   hex (mapas arquivo → hash). Qualquer outro valor nesses arquivos continua
   sendo verificado.
2. Em `api/tests/`, `cartilhas_app/test/` e `cartilhas_app/integration_test/`,
   somente a heurística `generic-api-key` (senhas/chaves de fixture). Regras
   específicas (`github-pat`, AWS, chave privada etc.) continuam valendo.

Falso positivo pontual: preferir `gitleaks:allow` no comentário da linha a
ampliar o allowlist; valor real: remover, **rotacionar** e só então reenviar
(remover do commit não invalida a credencial).

## Triagem do histórico (pendente, humana)

Varredura local do histórico completo em 02/10/2026 (base `f1b88d5`):
76 achados `generic-api-key` com a config padrão; 8 com esta config. Restantes,
por arquivo (valores não exibidos): `cartilhas_app/lib/services/privacy_preferences.dart` (2,
nomes de chave de preferência), `cartilhas_app/lib/screens/chatwoot_screen.dart`
(1, website token Chatwoot já citado em PRODUCTION_READINESS), `api/ops/smoke_followup_staging.py`
(2, `idempotency_key`), `docs/production/evidence/wave1-*.json` (2, `api_deployment_id`),
`docs/CURRENT_STATE.md` (1). Parecem não ser credenciais, mas o gate 13
continua PENDING até revisão humana por path. O scan incremental não
substitui essa triagem.
