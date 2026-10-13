# Preparação Play — Tutor TDS 1.4.1+14

Candidata da Issue#205/PR#206. Não é recibo de upload ou publicação.

| Campo | Valor / evidência |
| --- | --- |
| Package | com.tutortds_cartilhas |
| versionName / versionCode preparados | 1.4.1 / 14 |
| Android | min24, compile36, target36; conferir também no bundle real |
| Certificado de upload | 16:44:39:F5:EF:57:F6:E9:C7:B8:58:A3:4F:59:2C:26:1D:CC:EC:AD:B3:B3:59:98:F0:7C:40:1F:6C:34:3F:50 |
| Produção informada pelo operador | code11, version1.2.0 |
| Maior código entre todos os tracks/rascunhos | Ainda não observado |
| AAB/hash desta candidata | Ainda não gerado; upload bloqueado |
| Configuração Chatwoot | GET/support/config, recarga fresca; rotação pelas duas variáveis da API |
| API/schema/mínimo | Nova imagem com recibo próprio; manter0030/1.2.0+11/flagsfalse |

Antes do envio, ligar os comprovantes originais de recuperação, smoke físico,
build e verificação nativa à fonte/tag aprovadas. Verificar assinatura completa,
Bundletool, target36 e alinhamento16KB; esses controles não comprovam execução
em hardware16KB ou ZIP alignment dos APKs gerados pela loja.

O arquivo de status externo pós-build deve usar o SHA real e passar o mesmo
verificador com `--intent=upload --status-file=<ABSOLUTO>`; nenhuma edição do
checkout congelado ou permissão antecipada de upload é necessária.

Na Console, conferir códigos/rascunhos, processamento do bundle, App Content,
Segurança dos dados e o resumo antes do lançamento autorizado. Registrar a
distinção entre arquivo enviado, versão enviada para análise e produção ativa.
Uma aprovação da Google não é inferida do upload.

Notas preparadas, idioma pt-BR:

> Melhorias no suporte do aplicativo, com recarga e tratamento de falhas de conexão.

O [inventário de dados](DATA_SAFETY.md) delimita o delta desta candidata.
MCP#200 e Firebase#196 não estão incluídos.
