# Direitos TDS e publicação piloto — 20/10/2026

Base: PR307 `184d7616a6ca2157f8977b1bb2f7052f387822d1`.
Branch: `agent/issue-308-media-rights-20261020`.
Issues: [308](https://github.com/rafaloct/tutor-tds-platform/issues/308),
[309](https://github.com/rafaloct/tutor-tds-platform/issues/309).

DECISION: responsável declarou nesta conversa: “se tiver funcional ta autorizado,
os direitos da midia são do proprio projeto tds”. Atestação institucional de
titularidade para as mídias próprias TDS; não representa medição técnica, direitos
de terceiros ou aceite das declarações Play. Não solicitar novamente essa decisão.

## Resultado efetivo

| Recorte | Estado | Prova/limite |
| --- | --- | --- |
| Inventário produtivo read-only | PASS |9 cursos,95 aulas,48 fingerprints MP4/VTT; zero pais múltiplos |
| Piloto aula1420, curso1298 | PASS temporário | Conteúdo revisado, fontes pinadas; direitos0→1/public1 |
| Currículo/aula HTTP200/304 | PASS |4 requisições |
| Aula1299 ainda negada404 | PASS |1 requisição |
| MP4 parcial206 / VTT200 | PASS |2 requisições,35 cues |
| Android primeira abertura | FAIL |“Vídeo indisponível”; player-fail.png |
| Android segunda abertura quente | PASS parcial | MP4206/VTT200, avanço4,712→14,750→43,418s, sem mediaError |
| Mostrar/ocultar e retorno | PASS | Toques reais, JSONL e return.xml |
| Pausa | PASS programático | video.pause via CDP; não confundir com toque no controle nativo |
| Áudio ouvido / TalkBack falado | UNKNOWN | Volume1/mutedfalse não comprovam audibilidade |
| Rollback | PASS | Sete metadados removidos, baseline restaurada, aula1420 volta404 |
| Publicação definitiva48 vídeos | BLOCKED | Inicialização precisa investigação #309 |
| Release/assinatura/Play | HUMAN_GATE | Não executados; direitos não substituem demais gates |

HTTP7/7 corresponde à execução com headers equivalentes ao Dart.
O primeiro runner sem User-Agent Dart falhou no primeiro status200 esperado;
não registrou o status recebido, portanto causa/status exatos UNKNOWN.
GET curl com UA Dart200 e runner corrigido7/7. Não mudar servidor/WAF para PASS.
Dois caminhos stdin do WP-CLI não foram suportados; interrompidos, substituídos
por arquivo explícito read-only em /tmp. Não foram falhas de salvamento de aula.
Aviso WP_DEBUG duplicado preexistente foi observado; não alterado.

## Método editorial e segurança

Arquivos do aplicativo/plugin/tema não mudaram. O runner administrativo WP-CLI
usou a conta1 somente após verificar papel administrator e capacidades legítimas
sobre aula1420/curso1298. Não concedeu privilégios, não alterou map_meta_cap,
não trocou usuários durante hooks nem tentou o bypass descartado da #297.
Invocou o validador do metabox instalado com nonces nativos em duas chamadas
explícitas: preparação com direitos0, confirmação/publicação1 da mesma fonte.
Isso é uma operação editorial administrativa CLI, **não POST HTTP de formulário**.
Não reexecutou hooks de salvar conteúdo/curso porque texto/currículo não mudaram;
apenas os sete metadados do próprio adaptador foram alterados.

Texto do piloto revisado: transcrição/atividade orientativa, sem dados pessoais,
registro acadêmico ou avaliação restrita. Post/content/status/author preservados.
Nenhuma aula fora do piloto foi autorizada. Dados retornados pelo inventário
limitados a cursos/aulas; nenhum usuário, matrícula ou segredo exportado.

Hash conteúdo1420:
`cb5e79c4bd6a9c4bae86664d3675e8cd3e1fa7ada769f602a2bf73122084f14d`.
Fingerprint do adaptador:
`0b2b5bfa36ba53b5b0c99cc8f8951ca99e70d76af7f131fc775998fed8e7f5c8`.
MP4 SHA256:
`8bfcae0f98cd18175399fe5861c96b23b0ad6d523891823adf87fd455d021431`.
VTT SHA256:
`515119b65c4e3c86b00345d075f40efcc54e114157320e1356b8e7254fb9fb42`.
Bytes conferidos no mount real contra inventário restaurado anterior.
Fingerprint é das fontes/URLs validadas pelo contrato existente, não um hash
criptográfico do conteúdo do arquivo; hashes de bytes são evidência adicional.

## Android e diagnóstico limitado

LARGeo, emulator5554/API35, package QA305 existente. Não reconstruído/reinstalado.
APK `D:/AI-Shared/builds/tutor-tds/issue303-etag-20261019/issue303-f547720-qa-debug.apk`.
SHA256 `24A1DEF29608D204B9CE225CE7EB3159C11DA96B4677ADACD1C841C65B8D0C2D`;
hash foi revalidado no turno anterior. Fonte Flutter `f547720538bfd1024544a0c9bd731b325797fdeb`.
UI real: entrada visitante→catálogo→Agricultura→aula1420→player.
Primeira transição teve dump null root, depois UI indisponível.
Logs indicam cold WebView e TimeoutException SafeBrowsing; o código inicia
timer20s antes dos awaits da inicialização nativa. Causa exclusiva UNKNOWN;
não aumentar timer nem atribuir somente à rede sem reproducer/instrumentar.
Rollback foi executado antes da segunda abertura. A segunda usou a aula já
carregada em memória e arquivos públicos, **não** uma nova leitura editorial
aprovada depois da revogação. Não apresentar isso como teste de revogação cliente.

Segundo player carregou e reproduziu com toque real,35 cues e captions abaixo
da imagem. JSONL com0 cookies do domínio; não é auditoria integral do tráfego.
Pausa via CDP e Back para aula; forward9222 removido, somente QA app encerrado.
Emulador e processos alheios preservados. Nenhuma nova tentativa fria após o FAIL.
Não alegar E2E produtivo inteiramente PASS ou conceder crédito acadêmico.

## Backup / comparação / rollback

Host1533541 confirmado por conector e SSH privado, WordPress6.7.2/LP4.3.6.
Backup completo anterior `20261020T003715Z` teve3 hashes revalidados.
Restore histórico preservado; nenhum novo restore completo alegado.
Backup focal privado root700:
`/opt/tds-institutional-backups/media-pilot-308-20261020`.
Antes: `f5cc323c0d0299e51e96942ea906e16bf47151bfe050cc7f6c60f58d2ffe937e`.
Após publicação: `6816e162903cdced3ee64b42a15ba7645756e5600784c729710af0d283d7860f`.
Após rollback: `7cd25bf9f74afd44bc3fe75e20b54786a5a378aea4efc2574afb246dc2cbe3f4`.
Antes/depois publicação só wp_postmeta mudou. Rollback restaura os sete campos
exatamente ausentes;30 blocos INSERT idênticos. Dump bruto diferente foi
investigado: uma única linha, somente valor AUTO_INCREMENT, sem normalizar/apagar
originais. WP/DB/Traefik IDs/imagens/StartedAt iguais.
Dumps/configurações permanecem privados, não incluídos no Git.
Plugin corrigido permanece ACTIVE e patch299 preservado.

Rollback executado pelo runner com comparação fail-closed dos valores antes
de remover somente as próprias sete metas. Não restaurou banco inteiro.
Arquivos temporários de operação não são plugins/MU-plugins nem fixtures.
Nenhuma conta, autoria, matrícula, curso, vídeo ou legenda criado/alterado.

## Continuidade

Direitos próprios: ACCEPTED como decisão institucional. Publicação definitiva:
BLOCKED por teste frio #309, não por falta de autorização de mídia.
Próxima fatia técnica: reproducer/instrumentação cold WebView, correção mínima
somente se causa comprovada, gates Flutter/Android e retomada progressiva #308.
#297 e contas/aliases/Play são independentes. Não solicitar novamente titularidade.
Sem contratação, novo build, assinatura, merge ou Play. Custo financeiro incremental
não medido; não há prazo confiável de lançamento com os gates técnicos abertos.
