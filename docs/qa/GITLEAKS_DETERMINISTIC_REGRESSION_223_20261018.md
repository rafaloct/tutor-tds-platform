# Issue #223 | Regressão determinística do Gitleaks

**Data:** 18/10/2026
**Escopo:** somente o gerador de fixtures sintéticas em `tooling/security/test_gitleaks_config.py`.
**Estado:** `TESTED-LOCAL`, publicação/merge dependem do gate humano e do CI.
**Motivo:** falha intermitente no teste de detecção de chave genérica que bloqueou a revisão de diferentes PRs do portal, incluindo #251.

## OBSERVED

O teste `normal_code_generic_api_key` usava `secrets.token_urlsafe(32)`. O valor aleatório podia não atingir a condição de entropia do detector `generic-api-key`, tornando o teste positivo não determinístico. Outros dois testes de exceção contextual (`approved_api_fixture` e `approved_flutter_fixture`) usavam sufixos aleatórios, com a possibilidade de não provocar a detecção inicial da regra padrão antes da aplicação da allowlist.

Falhas anteriores registradas no GitHub:
- Issue #223: `normal_code_generic_api_key: expected generic-api-key detection`;
- PR #251: `approved_api_fixture: fixture did not exercise default rule`;
- PR #263, tentativa inicial do CI: `normal_code_generic_api_key` falhou; o mesmo SHA passou em nova execução.

## DECISION / FIX

Substituir **somente as amostras de regressão afetadas** por valores não secretos reproduzíveis derivados de SHA-256 de textos públicos de teste e codificados em Base64 URL-safe. As duas fixtures autorizadas usam o mesmo sufixo alfanumérico determinístico de 24 caracteres, continuando obrigadas a **acionar primeiro a regra padrão** antes de validar sua exceção contextual.

A amostra completa com aparência de chave é montada em tempo de execução dentro de repositórios temporários sintéticos. Não existe uma nova chave verdadeira ou token gravado no Git.

**Não houve alteração em `.gitleaks.toml`, na versão do scanner, em regras de bloqueio, em paths autorizados, no workflow do GitHub ou na regra de redaction.** As fixtures positivas de AWS/PAT/private-key e os testes negativos originais continuam presentes.

## TESTED-LOCAL: prova objetiva

| Item | Resultado |
|---|---|
| Host | LARGeo / Windows |
| Interpretador | Python 3.13 |
| Scanner | Gitleaks oficial **8.28.0** |
| Arquivo Windows do release | `gitleaks_8.28.0_windows_x64.zip` |
| SHA-256 do arquivo do release | `DA6458E8864AF553807DE1C46A7A8EAC0880BD6B99BA56288E87E86A45AF884F` |
| Conferência | Igual ao manifesto publicado com o release |
| Execuções completas | **12/12 PASS** |
| Casos por execução | **86 PASS**, incluindo os positivos e negativos |
| Total de verificações individuais | **1.032** |
| Alteração do arquivo de regras | **Nenhuma** |

As 12 execuções foram divididas entre três processos de validação separados para reduzir o tempo de espera. Um processo foi encerrado intencionalmente depois de seis execuções completas, quando já havia 12 PASS totais; a interrupção de uma rodada extra não foi contabilizada como execução concluída ou aprovada.

Evidência sanitizada e hashes SHA-256 dos 12 logs ficam somente no computador autorizado:

`D:\AI-Shared\evidence\tds-issue223-gitleaks-20261018\regression-audit.json`

Os nomes e checksums dos logs estão no manifesto. Não foram commitados corpos de segredo de teste nem materiais temporários.

## Como reproduzir

No CI Linux, manter a versão e o SHA-256 já fixados no workflow `.github/workflows/secret-scan.yml`. Com `gitleaks 8.28.0` e Python disponíveis, da raiz do repositório:

```bash
python3 tooling/security/test_gitleaks_config.py \
  --gitleaks "$(command -v gitleaks)" \
  --config .gitleaks.toml \
  --tmp-root "$(mktemp -d)"
```

Esperado: saída termina com `PASS all_gitleaks_policy_regressions` e exit 0. Uma alteração na regra padrão ou nas exceções contextuais deve produzir falha, nunca sucesso falso.

Os logs locais documentam as repetições com o executável Windows verificado. **O CI Ubuntu ainda precisa passar no PR que contém esta correção**, pois o teste de plataforma local não substitui a validação no runner oficial.

## Impacto e gates

Esta correção elimina uma causa conhecida de falso bloqueio de CI, **não** libera automaticamente PRs de portal, LearnPress ou Flutter e **não** modifica runtime do aplicativo. Após revisão e merge autorizado, reexecutar o scanner dos PRs afetados no novo commit/base, sem desativar regras ou suprimir falhas reais.

`MERGE_ALLOWED=NO`; `PRODUCTION_ALLOWED=NO`; `FORCE_PUSH_ALLOWED=NO`. A autorização humana para merge deve ser solicitada separadamente.
