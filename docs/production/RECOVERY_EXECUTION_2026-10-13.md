# Recuperação de produção executada — 13/10/2026 (#197)

## OBSERVED

O backup agendado nativo, a restauração isolada e o upgrade da API foram
executados na VPS `srv1533541`, autenticada pelo acesso administrativo existente.
O acesso público SSH expirou; o acesso administrativo pela VPN existente foi
validado contra a mesma VPS do Hostinger. Não foram alterados firewall, DNS,
conta Hostinger ou serviços de aplicações não relacionadas.

| Prova real | Registro versionado |
| --- | --- |
| Recibo agendado R2, download e restore do mesmo cipher | `evidence/scheduled-postgres-offsite-20261013T141953Z-f5948745ff6593fe.json` |
| PostgreSQL 16 isolado: restore 0028, upgrade 0030, dados originais preservados, imagem antiga e catálogo compatíveis | `evidence/postgres-upgrade-20261013T141953Z-f5948745ff6593fe.json` |
| AnythingLLM/LanceDB: snapshot, R2, decriptação, restore, SQLite e buscas por workspace | `evidence/critical-volume-restore-20261013T151344Z-5a4bc102.json` |
| Configurações privadas da API, compose, backup e provider: R2 e restore byte a byte isolado | `evidence/config-recovery-20261013T144355Z-05aaf1d1.json` |
| Inspeção anterior da promoção: imagem, redes, mounts, catálogo e preservação de JWT/CPF/banco | `evidence/production-before-promotion-20261013.json` |

Os três primeiros registros têm hashes ligados pelo aceite
`evidence/production-restore-acceptance.json`. O verificador original retornou
`RECOVERY_EVIDENCE_PROVENANCE=PASS`, schema `20261007_0030` e árvore API
`dc32d081dffd4d778e51871a85ae4077eb75f6ce`. O teste offline verifica referências;
a execução externa foi também observada e auditada, não inferida de booleanos.

O backup agendado `20261013T140846Z-84914ff4cb9648a6afad19cff311caa1` teve
251.528 bytes e SHA-256
`bb75db7fec1db23ecf02de23d4268b506bbb85c4d615da5c25b1a1d6cce4ecb4`.
O dump decriptado conferiu com a mesma origem do ensaio. Produção permaneceu
inalterada durante os drills; containers, redes, tmpfs e identidade temporária
da VPS foram removidos. Nenhuma senha ou chave privada integra estes registros.

O clone AnythingLLM preservou 13 workspaces, 21 documentos e 1.255 vetores.
Integridade SQLite, baseline antes/depois, cartilhas e contextos A/B passaram.
Cada trecho retornado foi ligado a um documento do workspace pela relação
`document_vectors` no banco restaurado; título compartilhado não serviu como
prova de isolamento. Duas falhas estruturais do programa de ensaio foram
diagnosticadas antes do novo aceite: permissão do script público no clone e
leitura incorreta do ID de trecho como ID de documento. Os gates foram
preservados e a exigência de proveniência foi reforçada. Tentativas falhas
continuam privadas na VPS e não são referenciadas pelo aceite aprovado.

## DECISION — custódia e retenção

A identidade antiga esperada no avellaria não foi localizada. Foi criada uma
nova identidade custodiada no DESKTOP-8T5DRBS, em
`C:\Users\Usuario\Documents\TutorTDS-recovery-20261013\age-identity`, com ACL
restrita ao operador e SYSTEM. Seu recipient público é
`age149wxfjmq7su0ykejc6fu8wpmqndy06uv3wn622mvvrq7sxwgdyxsa98vss`.
O arquivo privado não foi retornado ao chat, Git ou workspace; na VPS, esteve
somente em tmpfs com modo 0600 durante os ensaios e foi removido ao concluir.
Cipher e recibo PostgreSQL foram também preservados na pasta privada do desktop.

Os backups novos usam esse recipient. Os archives antigos e a configuração
anterior foram preservados. Isso não recupera a identidade antiga nem comprova
decriptação dos archives antigos. A retenção automática ficou desativada para
evitar a remoção desses archives; o agendamento e o transporte nativos seguem
configurados. Não reativar expurgo sem resolver a custódia histórica.

## Limites

O aceite cobre PostgreSQL e o volume AnythingLLM ativo com LanceDB, além da
prova separada de configurações. Não cobre Weaviate legado separado, certificados
KV, restauração do ZIP completo do Dokploy, Drive/Sheets, WordPress ou Chatwoot.
Não houve inferência LLM no clone nem uso de fontes externas para autorização.

A compatibilidade HTTP é condicional aos apps suportados e às flags false;
ver `API_COMPATIBILITY_REVIEW_2026-10-13.md`. O prepare antigo de turma sem
`version_id` recebe 422 no candidato; não existe aceite de aditividade global.
Rollback da imagem antiga sobre DB0030 exige uvicorn direto, sem o bootstrap
Alembic antigo e sem downgrade do banco.

Esta prova fecha recuperação da candidata. Promoção da API, novo AAB e upload
Play são operações distintas, com seus próprios registros de execução.
