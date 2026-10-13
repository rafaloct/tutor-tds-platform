# Preparação de produção — 2026-10-13 (#197)

## Escopo e decisão

Base: staging `dd928ff6b58788af930aa6722557728d74dfe97c` (PR #194 já
integrado). O usuário informou que Google Analytics do domínio e Cloudflare
bastam para observação geral. A configuração externa não foi verificada nesta
sessão. Firebase do draft #196 fica fora desta candidata.

## OBSERVED

- `tooling/build_production.ps1` usa agora `uv run --locked --extra test
  python -m pytest -q`. A invocação anterior falhou em ambiente novo com
  `ModuleNotFoundError: ops`; a nova instala dependências de teste do lock e
  mantém o diretório da API no caminho de importação.
- API: `uv run --frozen --extra test python -m pytest`: 601 passed,
  30 skipped, 5 subtests passed, três avisos de depreciação.
- Ferramentas de recuperação: 29 testes aprovados, um opt-in não executado.
  Seleção de ambiente/bindings: oito aprovados.
- PostgreSQL descartável 17.11: 30 testes aprovados (lifecycle, certificados,
  presença e operador). Primeira execução em 16.15: 28 passaram e dois
  rejeitaram a versão do servidor; repetição com 17.11 passou integralmente.
  Container com tmpfs e bancos sintéticos removido ao concluir.
- Configuração gerada por `tools/ci/tds_env.py` para `refs/tags/v1.4.0`
  fora do repositório: `ENVIRONMENT_SELECTION=PASS`, sem credenciais,
  endpoints de produção e flags novas desligadas. Não criou uma tag.
- Nenhuma alteração de runtime, migração ou dependência nesta candidata.

## UNKNOWN/BLOCKED — promoção

O verificador real de recuperação, com schema `20261007_0030` e árvore Git
da API candidata, retorna `RECOVERY_EVIDENCE_PROVENANCE=FAIL: acceptance
schema does not match the candidate`. O ensaio histórico de migração de dump
ao vivo não substitui a restauração comprovada do backup agendado offsite.
Não alterar recibos ou booleanos para contornar o gate.

Acesso HTTP ao domínio de produção e download do Dart foram recusados pelo
proxy do workspace (`CONNECT 403`); isso não demonstra indisponibilidade do
serviço. O LARGeo respondeu ao ping e depois retornou ENOENT para o caminho
histórico de Flutter; a descoberta de diretórios também expirou em
2026-10-13T13:13:04Z (`Timeout - no response from device`). Comandos
remotos anteriores expiraram. O SDK local não ficou utilizável.

Permanecem necessários: restauração offsite com proveniência e volumes
críticos, compatibilidade/schema atual de produção, Flutter 3.44.9 com testes,
versionCode publicado verificado, novo AAB com assinatura preservada e
manifesto vinculado ao commit/tag. O artefato histórico está superseded.
Nenhum AAB, tag, deploy, migração de produção ou upload Play foi realizado.

## Continuação operacional

Reason: a promoção depende de evidência real de recuperação e de um ambiente
de build/acesso a produção funcional.
Exact human action: disponibilizar ao operador autorizado o local da identidade
age já custodiada para o restore, sem copiar a chave para chat/Git; confirmar
que comandos do Desktop Commander executam no LARGeo, além do status online.
What remains unblocked: revisão da correção do runner e CI da candidata;
os testes locais não alteram produção nem a assinatura Android.

## Localização histórica da assinatura — informação do operador

Em 2026-10-13 o operador informou os caminhos abaixo, explicitamente sem
confirmação ao vivo nem comprovação de uso na última publicação:

| Recurso | Máquina | Caminho histórico |
| --- | --- | --- |
| Checkout principal | avellaria | `/home/rafael/StudioProjects/tutor-tds-platform` |
| Checkout do último AAB assinado | DESKTOP-8T5DRBS | `C:\Temp\tutor-tds-build-prep` |
| Keystore desse checkout | DESKTOP-8T5DRBS | `C:\Temp\tutor-tds-build-prep\cartilhas_app\android\upload-keystore.jks` |
| Backup da chave | LARGeo | `C:\Users\Rafael\Documents\TutorTDS-signing-backup-20260810\upload-keystore.jks` |

OBSERVED local: `openssl x509 -in cartilhas_app/android/upload_certificate.pem
-noout -fingerprint -sha256` confirmou o fingerprint público versionado:
`16:44:39:F5:EF:57:F6:E9:C7:B8:58:A3:4F:59:2C:26:1D:CC:EC:AD:B3:B3:59:98:F0:7C:40:1F:6C:34:3F:50`.
Isso prova apenas o certificado PEM do repositório. Não comprova existência
ou correspondência dos keystores históricos, nem o certificado de upload
atualmente aceito no Google Play. Comparar com o certificado de **upload**,
que pode ser diferente do certificado de **assinatura do app** do Play App Signing.
Não gerar chave nova, sobrescrever backup ou solicitar reset de assinatura
para resolver a falta de evidência. Senhas e material privado permanecem no host.


OBSERVED remoto posterior: no LARGeo, `get_file_info` confirmou o backup JKS
(2.253 bytes). `keytool -list -v` com senha lida apenas no host, passada por
variável de ambiente temporária e removida ao final, concluiu com código zero.
O SHA-256 do certificado do keystore e do PEM adjacente coincide com o PEM
versionado acima. Nenhuma senha ou chave privada foi retornada. Flutter foi
localizado em `D:\flutter-3.44.9\bin\flutter.bat`; versão e gates ainda por
verificar. A correspondência com o certificado de upload atual do Play segue
UNKNOWN; o checkout do DESKTOP-8T5DRBS não foi validado.


OBSERVED remoto: API pública consultada pelo LARGeo em 2026-10-13:
`/health` → `status=ok`, `database=available`; `/version` →
`environment=production`, `api_version=0.1.0`,
`schema_version=20261005_0028`, `minimum_supported_app_version=1.2.0+11`,
`compatibility_verified=false`. Portanto a produção está acessível, mas não
comprova o contrato de promoção da candidata `20261007_0030`.
Checkouts isolados criados no LARGeo, sem modificar o checkout principal:
`C:\Temp\tds-release-198-20261013` em `34186ae` e
`C:\Temp\tds-mcp-200-20261013` em `74f84ce`.

Flutter `--version --machine` executado no LARGeo confirmou 3.44.9, revisão
`6b182d2c7585eba26d4edce0f97630effd256c33`, Dart 3.12.2. O comando agregado
terminou com exit 1; a saída do Flutter forneceu os metadados acima,
mas isso não representa aprovação da suíte ou build. MCP #200: dependências
instaladas pelo lock em worktree isolada; testes Windows 19 passed/1 skipped
(checagem de permissões POSIX, inaplicável ao Windows). Clientes ainda não
configurados, nenhuma credencial administrativa ou conta real provisionada.


Resposta posterior do operador: o caminho esperado da identidade age é
`/home/rafael/tds-restore-private-20261012/inputs/age-identity` no avellaria,
mas a identidade privada **não foi localizada**. O fingerprint informado
coincide com o PEM, porém foi validado historicamente contra certificado local,
**não reconfirmado diretamente na Play Console**. Esses dados não satisfazem
os respectivos gates. O alias SSH `tutor-tds-vps` no LARGeo retornou 255 em
duas consultas somente leitura, sem diagnóstico útil; sem alterações no VPS.


## Validação Flutter no LARGeo concluída

Checkout `34186ae` do PR #198, Flutter 3.44.9: `pub get --enforce-lockfile`
PASS; `analyze --no-pub` PASS; `test --no-pub --reporter expanded` **625 passed**,
exit 0, 94s reportados pela suíte. `pubspec.lock` preservado por comparação
SHA-256; `git status --short` vazio ao final. A primeira tentativa de testes
parou antes da suíte por `ProgramFiles(x86)` ausente no ambiente remoto. Na
repetição, a variável foi preenchida apenas no processo com a pasta existente
do Windows; nenhuma configuração global foi alterada. Logs locais:
`C:\Temp\tds-release-198-validation-20261013.log` e
`C:\Temp\tds-release-198-tests-20261013.log`.

Configuração produtiva foi gerada no checkout isolado por `tds_env.py` e
validada por `validate_production_config.dart`: PASS, sem credenciais,
checkout limpo. As alterações posteriores do PR são documentação; não mudam
a árvore do app testada. Não houve build AAB, migração ou publicação.
