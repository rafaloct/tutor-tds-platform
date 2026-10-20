# Issue #303 — retomada focal após STOP

Executor exclusivo: Devin Desktop / LARGeo.
Branch: `agent/issue-303-weak-etag-20261019`.
Worktree: `D:/AI-Shared/work/tds-issue303-weak-etag-20261019`.
Base: `f9260a6d118e7142b0c9ec7f11a14b09440c725a`.

OBSERVED: em 19/10/2026 local, GitHub confirmou PR #304 OPEN/draft nesse
HEAD, CI 3/3 SUCCESS. O comentário técnico mais recente da #303 foi lido:
<https://github.com/rafaloct/tutor-tds-platform/issues/303#issuecomment-6280785878>.
O recibo da base registra rollback concluído: plugin instalado/inativo,
rota editorial 404 e LearnPress nativo 200. Não é uma nova consulta produtiva.

DECISION: autorização direta nesta sessão para retomar somente ETag Flutter,
testes focais, novo APK QA e homologação Android isolada. A autorização anterior
de promoção não é reutilizada. Reativação produtiva exige aprovação específica
posterior ao STOP, com teste focal e rollback preparados.

TARGET: aceitar exclusivamente `"revision"` ou `W/"revision"` para a mesma
revisão lowercase hexadecimal/64 validada no JSON. Preservar o ETag recebido
literalmente para `If-None-Match`, o cache em memória por curso e toda validação
de autorização, origem/schema, mídia e fingerprint. Não há alteração de UI;
nenhum novo digest Stitch ou aceite visual é reivindicado.

Fronteira: cliente GET editorial; nenhuma mudança em LearnPress, PHP, banco,
fingerprint de direitos, assinatura de produção, versão Play ou flags release.
Dependência: cadeia #304; #297 permanece independente. #299 e #302 não são
reexecutadas. Risco focal: aceitar validador divergente ou reutilizar cache
não validado; testes negativos cobrem essa fronteira. Offline policy preservada:
falha de rede não concede conteúdo; 304 exige objeto previamente validado
do mesmo curso, sem cache persistente novo.

## Ambiente e testes

Os caminhos históricos `C:/Users/Usuario/...` não existem neste host.
SDK explicitamente verificado: `D:/flutter-3.44.9`, framework `6b182d2c75`,
Flutter 3.44.9 / Dart 3.12.2. Worktree exclusiva em caminho ASCII.
O SDK não foi inferido do PATH. Android SDK: `D:/DevTools/AndroidSDK`.
Dependências resolvidas offline, sem mudança do lockfile.

TESTED-LOCAL: 40/40 testes do repository/fixtures e 5/5 testes focais MP4
passaram; analyze dos três arquivos Dart alterados passou sem achados.
Cobertura: forte/fraco 200/304, envio literal de If-None-Match,
divergente/ausente/malformado, schema/origem/curso/revisão inválidos,
304 sem cache e de outro curso, transições forte/fraco com novo conteúdo,
conteúdo não autorizado, 404 sem permissão, 401/403 e HTTP real gzip/identity.
Teste Android usa a tela existente, repository e transporte padrão, com
servidor HTTP sintético no loopback e ponte privada QA existente.
Isso não comprova WordPress vivo, mídia produtiva, áudio ou TalkBack.

## Rollback preparado — execução depende do gate

Estado a preservar: adaptador 0.1.0 instalado e **inativo**. Após autorização
específica, primeiro conferir estado/hashes e disponibilidade do backup
`/opt/tds-institutional-backups/20261020T003715Z` conforme PR #304.
Se a rodada autorizada falhar, desativar somente o adaptador pela operação
nativa WP-CLI: `wp plugin deactivate tds-learnpress-editorial --allow-root`,
no container `compose-program-open-source-monitor-szkpni-wordpress-1`,
diretório `/var/www/html` (usar o binário WP-CLI conferido no ambiente).
Confirmar plugin inativo, rota editorial 404 e rota LearnPress nativa 200.
Manter arquivos do plugin e patch #299; não restaurar banco inteiro,
alterar LearnPress, direitos, permissões ou registros acadêmicos.
Rollback do cliente QA: encerrar/remover apenas o pacote exclusivo desta rodada;
preservar APKs anteriores e aplicativos DEV/Play existentes.

## Resultado Android e artefatos

TESTED-LOCAL: Android 15/API35, `emulator-5554`, x86_64.
Fonte compilada: `f547720538bfd1024544a0c9bd731b325797fdeb`.
PR: <https://github.com/rafaloct/tutor-tds-platform/pull/305>, draft sobre #304.
CI desse commit: Flutter analyze/test, gitleaks e duas verificações de quarentena
PASS (4 checks). Não são somados aos 45 testes locais.

O teste de integração executou a tela `EadLearningPathScreen`, repository e
cliente HTTP padrão, sem injeção de response no cliente. Servidor loopback
dentro do Android retornou fraco/gzip200, 304, forte/identity200 com nova revisão
e 304. A tela manteve o conteúdo após 304 e exibiu a revisão nova após 200.
Todos os GETs enviaram Accept-Encoding:gzip; If-None-Match preservou literalmente
o validador anterior. Nenhum Cookie/Authorization. Um teste Android PASS;
`tearDownAll` não é contado como segundo teste.
[Readback dos quatro requests](android-requests.json).

Depois, o APK QA com entrada normal `lib/main.dart` foi compilado, instalado e
homologado no mesmo emulador. Welcome → explorar EAD → cartão de laboratório
→ percurso sintético exibiu 1 seção/2 itens. O refresh recebeu 304 e manteve
os dois itens. A lição permaneceu **não liberada para leitura no app**,
sem mídia autorizada. Fixture já existente do WordPress/MySQL, servida por
`serve_fixture.py` no desktop via ADB reverse, gzip200 de 393 bytes e 304 vazio.
[Readback HTTP](app-http.txt); [captura após 304](app-weak304.png).
Nenhum match focal de FATAL/Unhandled Exception/RenderFlex/ANR no log do APK.
O catálogo público foi apenas atravessado para acessar o laboratório;
isso não é uma nova homologação das onze ofertas nem das suítes #299/#302.

Pacote exclusivo dos dois APKs:
`com.tutortds_cartilhas.dev.dynamicqa.rf547720538bfd1024544a0c9bd731b32`.
O APK de integração foi arquivado antes de sua substituição pelo app normal.
Versão QA `1.4.0-dev+13`, minSdk24/targetSdk36. APK normal com ABIs arm64-v8a,
armeabi-v7a e x86_64. Somente certificado Android Debug, SHA256
`6af6c35e5ede92952c97861129900eabd297d006ca50db952cb60880deddc4f8`.
`android/key.properties` ausente; nenhuma assinatura de release ou AAB.
SHA256 do `base.apk` instalado conferiu com o APK normal abaixo.

Diretório dos APKs: `D:/AI-Shared/builds/tutor-tds/issue303-etag-20261019/`.

| Artefato | Bytes | SHA256 |
|---|---:|---|
| `issue303-f547720-qa-debug.apk` | 223761374 | `24A1DEF29608D204B9CE225CE7EB3159C11DA96B4677ADACD1C841C65B8D0C2D` |
| `issue303-f547720-integration-debug.apk` | 84550300 | `010A613447449B0872F3BD0155CF7AD89A10CEFC6B00B0906C7414A3ED3339EA` |

Evidências locais completas:
`D:/AI-Shared/test-results/tutor-tds/issue303-etag-20261019/`.

| Evidência | SHA256 |
|---|---|
| `flutter-tests.log` (40/40) | `B0121CFF11D99F948747F28CE4DBF8405A96D344DD133F17B92E45203EF7F2AE` |
| `media-tests.log` (5/5) | `874C60F79A7613FC02E11F0E7CDECDFB8062069ADB1FF43C5FFC7BE3B863FFFA` |
| `analyze.log` | `F277EF56259FE3838500062E69BA4AC6F5E7E5629529E78EB7DFF038366F2A37` |
| `android-requests.json` | `30D128B79F730D8ECF1CEFA58A4B22259C4BF60E5B4B9C951FD4E9E3D38177BD` |
| `app-http.log` (cópia `app-http.txt`) | `8DA3CC3706B2BDB5B086AEA0203A88A73A6EA26A0D2C10BF8A6EA9C6A3E82A2D` |
| `app-weak304.png` | `56D07EA7EAB4CA5C25FF58A83ACBD2039329461EBF7CF88135EABCD62EA49F71` |

Servidor sintético encerrado, pacote QA parado, forward VM e reverse18731
removidos ao concluir. Aplicativos históricos/DEV/Play preservados.

## Comandos reproduzíveis e ocorrências de ambiente

Executados em `cartilhas_app` com Flutter3.44.9 explicitamente localizado:

```text
flutter test --no-pub test/ead_editorial_bridge_repository_test.dart test/ead_editorial_real_wp_fixture_test.dart --reporter expanded
flutter test --no-pub test/ead_ipex_mp4_player_test.dart --plain-name MP4 --reporter expanded
flutter analyze --no-pub lib/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart test/ead_editorial_bridge_repository_test.dart integration_test/ead_editorial_etag_test.dart
```

Builds/driver usaram diretamente `bin/cache/dart-sdk/bin/dart.exe`
com `bin/cache/flutter_tools.snapshot` do mesmo SDK, conforme prática verificada
nesse host. Configuração: `config/staging.example.json`, mais defines
`DYNAMIC_QA_ISOLATED_PACKAGE=true`,
`DYNAMIC_QA_RUN_ID=f547720538bfd1024544a0c9bd731b32`,
`TDS_EDITORIAL_QA_HTTP_BASE=http://127.0.0.1:18731`.
Integração: `flutter drive --no-pub -d emulator-5554
--driver=test_driver/integration_test.dart
--target=integration_test/ead_editorial_etag_test.dart` com os defines acima.
App normal: `flutter build apk --debug --no-pub --target=lib/main.dart`
com a mesma configuração. Os dois builds ocorreram depois dos testes Flutter.

Ocorrências preservadas, sem mascarar como PASS:

- Um primeiro preDebugBuild recusou run ID com 33 caracteres, antes de gerar
  APK/instalar. Corrigido o argumento para substring hexadecimal de 32 caracteres;
  nenhuma guarda Gradle foi alterada. Log `android-integration.log`.
- A instalação seguinte passou, mas o Android encerrou PID8342 por `start timeout`
  durante inicialização; não houve execução Dart do teste nesse processo.
  Runner ficou esperando serviço VM e foi encerrado. Log
  `first-launch-timeout.log`; sistema também registrava frames lentos em outros apps.
- Uma nova abertura do mesmo APK instalado iniciou PID8755. `am start -W`
  excedeu sua espera de20s, mas o processo permaneceu vivo, publicou VM Service e
  executou o teste. O driver anexou ao **mesmo PID**, sem rebuild/reinstalação ou
  terceira abertura; devolveu PASS. Logs `android-attach.log` e
  `android-integration-pid8755.log`. Causa exclusiva da lentidão não comprovada;
  fronteira observada é inicialização/emulador, não validação ETag.
- APK normal iniciou e completou o percurso/refresh. Avisos de KGP/Java legado
  não impediram build. Não houve mudança de dependências para silenciá-los.

## Gate específico de reativação — ainda não autorizado

Reason: a autorização desta sessão exige pedido específico pós-STOP. O teste
focal e o rollback estão preparados; Android sintético não prova a cadeia HTTP
institucional produtiva nem concede direitos de mídia.

Exact human action: aprovar a reativação controlada **somente** do adaptador
`tds-learnpress-editorial` 0.1.0 já instalado, com os três hashes de
`docs/production/portal-promotion-20261019/promotion.json` conferidos antes.
Conferir estado/backup preservado e executar smoke GET gzip200/304 + percurso1298
no APK QA novo; desativar nativamente em caso de falha, confirmar editorial404
e LearnPress200. Sem alterar patch299, LearnPress, direitos, publicação de aulas
ou dados acadêmicos. Sem repetir suítes #299/#302.

What remains unblocked: revisão do PR305 e inspeção dos artefatos/recibos.
O plugin produtivo não foi reativado nem consultado para inferir estado novo
nesta rodada; último estado comprovado continua o rollback do PR304.
UNKNOWN/BLOCKED: smoke institucional, Xiaomi/áudio/TalkBack, aliases,
direitos por aula, #297, declarações legais, certificado/versionCode Play,
merge, assinatura e publicação nos respectivos gates.
