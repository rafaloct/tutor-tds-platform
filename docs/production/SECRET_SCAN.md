# Secret scan incremental (gitleaks)

Workflow: `.github/workflows/secret-scan.yml`. Config: `.gitleaks.toml`.

- Escopo: somente os commits novos — PR (`base.sha..head.sha`), push em
  `codex/onda-0-consolidacao` (`before..after`) ou intervalo manual
  (`workflow_dispatch`, input `log_opts`). Não varre o histórico inteiro.
- gitleaks 8.28.0, tarball oficial conferido por SHA-256; `contents: read`,
  `persist-credentials: false`, sem secrets, sem token, sem artefato/relatório.
- Saída sempre com `--redact`: o log mostra regra/arquivo/commit, nunca o valor.
- O intervalo é validado por `git rev-list` antes do scan; intervalo inválido
  falha explicitamente em vez de seguir como sucesso aparente.
- As regressões sintéticas rodam antes do scan incremental e não publicam
  relatórios brutos. Runner: `tooling/security/test_gitleaks_config.py`.

## Config (`.gitleaks.toml`)

As regras padrão continuam ativas. As exceções são contextuais:

1. Em `docs/production/evidence/*.json`, somente o Match de um campo JSON cujo nome
   termina em `_sha256` e cujo valor é um SHA-256 hexadecimal de 64 caracteres
   é tratada como digest. Campos revisados no repositório incluem
   `apk_sha256`, `defines_sha256`, `parent_evidence_sha256` e
   `uv_lock_sha256`. O sufixo de um mapa pai não dispensa automaticamente
   seus valores internos: a exceção exige o próprio campo e um valor escalar. Um valor de 64 hex em
   `secret_access_key` não recebe essa exceção.
2. Para `generic-api-key`, fixtures só são dispensadas dentro de
   `api/tests/`, `cartilhas_app/test/` ou `cartilhas_app/integration_test/`
   quando a mesma linha combina o nome de fixture aprovado
   (`synthetic_fixture_api_key` ou `syntheticFixtureApiKey`), o prefixo
   literal `tds_gitleaks_fixture_`, 24 caracteres sintéticos e o marcador
   `gitleaks:synthetic-fixture`. Caminho sozinho não concede dispensa.
3. Regras específicas como `github-pat`, AWS e `private-key` não são
   desativadas nem substituídas.

Não usar `gitleaks:allow` indiscriminadamente. Falso positivo novo exige
contexto revisado e regressão; valor real exige remoção, rotação e nova revisão.

## Regressões executáveis

Com gitleaks 8.28.0:

`python tooling/security/test_gitleaks_config.py --gitleaks <gitleaks-8.28.0> --config .gitleaks.toml --tmp-root <diretorio-temporario>`

O runner cria somente repositórios Git descartáveis com dados fictícios e prova:
`secret_access_key` em evidence JSON (inclusive vizinho de um digest na mesma
linha), teste API e teste Flutter continua
detectável; segredo genérico em código normal, PAT fictício e marcador de chave
privada continuam detectáveis; campo `*_sha256` e fixtures explicitamente
marcadas não geram ruído; texto parecido com fixture sem o contexto completo
continua detectável; range Git inválido falha. A saída contém apenas caso, regra,
path, contagem e status.

## Triagem técnica reaproveitada da revisão do PR #21

A revisão do coordenador conferiu, nos commits originais, os oito achados que
permaneciam visíveis com a configuração anterior. Esta tabela registra essa
triagem sem reclassificar por nome:

| Commit | Arquivo:linha | Justificativa conferida |
| --- | --- | --- |
| `bc6dd23` | `cartilhas_app/lib/services/privacy_preferences.dart:9` | `journeyConsentKey` é nome de preferência usado por `getBool/setBool`, não chave de autenticação. |
| `7c22045` | `cartilhas_app/lib/services/privacy_preferences.dart:6` | `consentKey` é nome de preferência usado por `getBool/setBool`. |
| `0081ab0` | `docs/CURRENT_STATE.md:9` | Prosa de instrução para não alterar produção/keystore/baseline/secrets; achado heurístico em texto. |
| `0081ab0` | `docs/production/evidence/wave1-acceptance.json:9` | `api_deployment_id` é UUID de deployment. |
| `0081ab0` | `docs/production/evidence/wave1-flutter-local-gate.json:21` | Mesmo tipo de metadado UUID de deployment. |
| `5327534` | `api/ops/smoke_followup_staging.py:33` | `idempotency_key` pertence a payload de cenário explicitamente sintético, não autenticação. |
| `5327534` | `api/ops/smoke_followup_staging.py:43` | `idempotency_key` pertence ao teste PATCH/conflito 409. |
| `7c22045` | `cartilhas_app/lib/screens/chatwoot_screen.dart:15` | `_websiteToken` é passado a `window.chatwootSDK.run`, identificador de widget exposto ao cliente, distinto de token administrativo/HMAC. |

Essa triagem não libera o restante do histórico. A revisão registrou 76 achados
`generic-api-key` com configuração padrão e 8 visíveis com a configuração
anterior; portanto, os outros 68 que eram suprimidos não foram individualmente
aprovados por contexto. Uma varredura histórica futura pode expor mais itens com
a política endurecida. Não declarar o histórico inteiro limpo, não inferir
permissões/identidade HMAC do Chatwoot e não fechar o gate 13 com base neste PR.

O scan incremental e suas regressões protegem commits novos; o gate 13 permanece
PENDING até a revisão humana exigida para o histórico.

## Diagnóstico local — 2026-10-03

- Observed: o runner focal não iniciou as regressões porque o sandbox negou a
  criação do repositório temporário, tanto no `tmp` do worktree quanto no
  diretório temporário do usuário.
- Expected: o runner deve poder criar somente seus repositórios Git descartáveis
  para executar as regressões sintéticas com Gitleaks 8.28.0.
- Responsible Boundary: permissões locais de filesystem/sandbox para diretórios
  temporários; não é achado, regra nem credencial do repositório.
- Evidence: `PermissionError [Errno 13]` no `tmp` do worktree e `WinError 5`
  no diretório temporário do usuário; ambos ocorreram antes do primeiro scan.
- Likely Root Cause: a política do ambiente impede as escritas temporárias
  solicitadas pelo runner.
- Affected Files: `tooling/security/test_gitleaks_config.py` (execução),
  `.gitleaks.toml` (ainda sem validação executada neste ambiente).
- Structural Fix: permitir escrita somente em um diretório temporário descartável
  autorizado e repetir o comando documentado; não ampliar allowlist nem alterar
  o scanner para contornar a política.

### Atualização — execução focal após acesso temporário autorizado

- Observed: com `C:\tmp` autorizado, 7 casos de detecção passaram, mas
  `reviewed_sha256_field` continuou com achado em duas execuções, antes dos
  demais cinco casos.
- Expected: somente a regra `generic-api-key` deve dispensar a linha JSON de
  um campo `*_sha256` com digest hexadecimal sintético de 64 caracteres.
- Responsible Boundary: semântica de `regexTarget`/allowlist do Gitleaks 8.28.0
  para esse achado; não há segredo real nem falha de permissão nesta etapa.
- Evidence: ambas as execuções reportaram 7 PASS e depois
  `AssertionError: reviewed_sha256_field: unexpected finding`.
- Likely Root Cause: o alvo configurado não corresponde ao texto efetivamente
  avaliado pelo achado da regra padrão, embora a expressão corresponda à linha.
- Affected Files: `.gitleaks.toml` e
  `tooling/security/test_gitleaks_config.py`.
- Structural Fix: inspecionar de forma redigida `Match` versus linha inteira da
  regra `generic-api-key` e ajustar somente o `regexTarget` contextual antes de
  nova execução; não ampliar paths, regex de 64 hex ou allowlist.

### Atualização — comparação redigida de Match

- Observed: o achado de `reviewed_sha256_field` inicia na coluna 3 e termina na
  coluna 95, mas `--redact` mascara o Match no relatório; ele não é a linha
  inteira e o alvo `match` com término estrito em hexadecimal também não casou.
- Expected: a expressão contextual deve incluir exatamente os delimitadores que
  fazem parte do Match, sem dispensar `secret_access_key` nem valor hex sem
  campo `*_sha256`.
- Responsible Boundary: formato de Match da regra padrão sob saída redigida do
  Gitleaks 8.28.0.
- Evidence: duas execuções após a troca de alvo falharam no mesmo caso, após
  sete PASS; o diagnóstico redigido foi `generic-api-key@column3-95`,
  `length=37`, `entire_line=False`.
- Likely Root Cause: o Match inclui delimitador JSON final que a expressão
  estrita não contempla, mas seu conteúdo não pode ser exposto para confirmar
  por causa do requisito de redação.
- Affected Files: `.gitleaks.toml` e
  `tooling/security/test_gitleaks_config.py`.
- Structural Fix: uma revisão autorizada deve confirmar a semântica de
  `regexTarget=match` contra a documentação/código do Gitleaks sem publicar o
  Match, então ajustar somente o delimitador final e repetir as 12 regressões.


### Resolução focal comprovada pelo coordenador — 2026-10-03

A causa foi reproduzida usando somente JSON sintético e relatório com
`--redact=100`. O Match começa na coluna 3 e termina na 95: ele não inclui
abertura de objeto/aspas iniciais da chave, mas INCLUI a aspa final do valor.
O trecho original tem 93 caracteres; o Match redigido tem 37. São representações
diferentes. A regex anterior terminava no hexadecimal e não consumia a aspa.
A correção mantém `regexTarget=match`, âncoras de início/fim e o path existente,
restringe o prefixo a identificador ASCII e exige a aspa final. Não há dispensa
por linha inteira nem exceção global de 64 hex. Nome de campo não comprova a
origem criptográfica do valor; falsos positivos novos ainda exigem revisão.

No código oficial v8.28.0, `detect/detect.go` verifica allowlists em detectRule
antes de chamar filter; `detect/utils.go` aplica Redact no filter. Portanto,
`REDACTED` é apresentação do relatório, não texto para criar a regex de dispensa.
Fontes: https://github.com/gitleaks/gitleaks/blob/v8.28.0/detect/detect.go
 e https://github.com/gitleaks/gitleaks/blob/v8.28.0/detect/utils.go.


O caso antes não alcançado de intervalo Git inválido também tinha uma suposição
incorreta: o binário retorna 0 enquanto registra erro de Git; o preflight
`git rev-list --count` retorna 128. O workflow já rejeita esse intervalo antes
do scanner. O runner agora reproduz essa barreira existente, exige código 2
e ausência de relatório do scanner quando o intervalo é inválido. O workflow
não foi alterado nesta continuação; não se aceitou o falso sucesso do binário.

Validação final: 20/20 cenários PASS, exit 0, em 20,72 segundos no
DESKTOP-8T5DRBS, Gitleaks 8.28.0, repositórios sintéticos em C:\tmp.
São os 12 casos originais (incluindo a barreira de intervalo) mais 8 negativos:
hash antes/depois de segredo, JSON multilinha, 63/65 hex, caractere não hex,
sufixo incorreto e campo de hash fora do path permitido. Os casos vizinhos
exigem exatamente um achado no campo de segredo, não apenas qualquer achado.
Nenhum cenário foi removido ou marcado como esperado-falhar.

A primeira execução após a correção passou 11 casos e parou no teste de
intervalo; a seguinte passou 14 e parou numa asserção adicional de coordenada
multilinha. Essa asserção foi corrigida para conferir o nome exato do campo
no Match redigido, preservando regra/path/contagem e sem alterar a política.
Os logs das tentativas anteriores foram preservados. Log aprovado:
`C:\tmp\tds-pr21-final-suite-v2-20261003.log`.

Este resultado é da suíte sintética local, não do histórico nem de produção.
O PR #21 permanece draft/CHANGES_REQUESTED e o gate 13 permanece pendente.
