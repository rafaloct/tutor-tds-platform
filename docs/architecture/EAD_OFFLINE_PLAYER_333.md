# Issue #333 — player offline nativo e QA sintético

## Contrato e estado

**OBSERVED:** O pacote v1 da Issue #329 valida URL, direitos declarados,
revisão, tamanho e SHA-256, grava em diretório privado por revisão e nega leitura
corrompida. A ponte editorial pública existente fornece URL/revisão de conteúdo,
mas não fornece byte count/SHA-256 verificados nem decisão independente de
direitos para cada mídia. Portanto, não é autoridade para instalar pacote real.

**DECISION:** Os direitos de mídias próprias TDS foram confirmados em
`docs/DECISIONS.md`, item 36. Publicação de cada aula e release continuam
condicionadas aos gates próprios. Nenhum evento offline cria matrícula,
frequência, nota ou certificado.

**IMPLEMENTED:** `video_player: 2.14.1` toca arquivo MP4 privado retornado pelo
store com `VideoPlayerController.file`, lê VTT em `WebVTTCaptionFile`, oferece
play/pause, seek, legendas, semântica e pausa ao perder foco. O downloader HTTP
anônimo aceita apenas HTTPS no host e caminho IPEX estritos, sem redirect,
cookies ou Authorization; possui timeouts e exige Content-Length limitado.
O store confere tamanho e SHA-256 exatos e elimina staging parcial na falha.
`applicationOfflinePackageStore` usa `getApplicationSupportDirectory` e uma
autoridade de produção que nega todas as instalações até haver adaptador
servidor verificável. O botão de produção fica desativado.

**IMPLEMENTED QA:** Entrada no catálogo somente com `kDebugMode`,
`DYNAMIC_QA_ISOLATED_PACKAGE=true`, run ID hexadecimal de 32 caracteres e
`TDS_EDITORIAL_QA_HTTP_BASE=http://127.0.0.1:18731`. A tela QA usa namespace
privado por run ID e bytes *incluídos no próprio app*, nunca baixa esses bytes
do host indicado no manifesto sintético. O MP4 é 3 s, fundo azul e tom gerado
por FFmpeg; VTT pt-BR é fictício. A preparação passa pelo mesmo store, valida
comprimento/hash e mostra estado. Remover revoga curso/aula QA. A entrada não
pode ser ativada em profile/release. A marca de QA não representa publicação de
curso, licença de mídia real ou aceite institucional.

**TARGET:** Adaptador FastAPI/servidor que emita manifesto e release check a
partir de `mobile_content`, direitos por asset, revisão editorial e hash/tamanho
medidos dos bytes exatos, vinculados à aula/curso. Revalidar na instalação,
definir revogação no retorno da rede, escopo por usuário/ambiente para material
futuramente protegido, limite físico de armazenamento e política de expiração.

**UNKNOWN/BLOCKED:** API de autoridade, proveniência assinada de direitos,
Android em modo avião, áudio físico, TalkBack falado, revisão de UX, build exato,
CI e gates de distribuição. `MERGE_ALLOWED=NO`, `PRODUCTION_ALLOWED=NO`; sem
assinatura, upload Play ou liberação das 48 mídias bloqueadas.

**TESTED-LOCAL:** `flutter pub get` PASS, 29/29 testes de manifesto/store/HTTP
PASS e `flutter analyze --no-pub` sem issues no LARGeo com Flutter 3.44.9.
O widget QA não passou; ver STOP abaixo.

## Procedimento QA Android

1. Compilar/instalar **debug** com os três `--dart-define` acima e um run ID novo.
2. Abrir Cursos do EAD → QA offline sintético → **Preparar offline**. Conferir
   estado “Pronto para modo avião” e **Assistir offline**, áudio, play/pause,
   seek, legenda pt-BR e retorno.
3. Fechar o app, ativar modo avião por ADB, reabrir o mesmo build/run ID e a
   mesma tela. Conferir que o pacote continua verificado, que o player reproduz
   o mesmo arquivo privado e que não há request de rede.
4. Em modo avião, tocar **Remover offline** e confirmar ausência do botão de
   reprodução; desativar modo avião somente após a prova. Registrar APK SHA,
   dispositivo/API, logcat sanitizado, horários e resultado. Não usar mídia real.

## Recuperação

Desativar os defines de QA ou distribuir profile/release remove a entrada QA;
nenhuma migração, dado acadêmico ou endpoint produtivo é alterado. Pacote
preparado pode ser removido pelo botão QA, que revoga todas as revisões dessa
aula sintética no namespace do run ID.

## STOP — teste de widget QA, 2026-10-22

- **Observed:** tentativa 1: `pumpAndSettle` expirou antes do estado inicial;
  tentativa 2: estado inicial chegou, mas após “Preparar offline” o texto
  “Pronto para modo avião” não apareceu em 40 observações. Teardown registrou
  `PathAccessException` ao excluir diretório temporário em uso. As duas
  execuções falharam; nenhuma prova de player Android foi produzida.
- **Expected:** instalação sintética termina com SHA/tamanho conferidos,
  botão de reprodução habilitado e diretório temporário liberado no teardown.
- **Responsible Boundary:** integração de I/O assíncrono, asset bundle e ciclo
  de vida do teste de widget com `OfflinePackageStore`.
- **Evidence:** `flutter test --no-pub --concurrency 1
  test/ead_offline_qa_widget_test.dart` no LARGeo/Flutter 3.44.9, duas rodadas;
  pacote/HTTP focal 29/29 PASS independentemente.
- **Likely Root Cause:** ainda não isolada. A segunda rodada não registrou o
  texto de erro da tela, portanto pode ser falha de leitura da fixture,
  verificação do manifesto ou sincronização do teste. A falha de exclusão sugere
  I/O ainda pendente no teardown; não atribuir a um hash sem evidência.
- **Affected Files:** `synthetic_offline_qa_screen.dart`,
  `ead_offline_qa_widget_test.dart` e a fixture em `assets/qa/offline/`.
- **Structural Fix:** instrumentar o estado/erro da instalação em teste,
  tornar o ciclo assíncrono observável e aguardar fechamento das operações
  antes do teardown; só então repetir o widget test e o QA Android.
