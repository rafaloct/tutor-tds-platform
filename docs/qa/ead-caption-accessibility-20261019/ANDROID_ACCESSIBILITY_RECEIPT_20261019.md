# Recibo Android — PR #295 / Issue #294

Data: 19/10/2026. Executor: LARGeo. Escopo: QA isolado, sem produção, Play,
assinatura real ou dados de alunos.

## Proveniência

| Campo | Valor |
| --- | --- |
| base | `91c5934eb071d8decc8d26e12eeb50e63bd72846` |
| HEAD/candidato local | `b05eaa058fb4b0c86c5569215652b893c55b517d` |
| branch | `agent/issue-294-caption-accessibility-20261019` |
| Flutter/Dart | 3.44.9 / 3.12.2 |
| Android | 15, API 35, Pixel 8 Pro AVD read-only |
| WebView observado | 153.0.8010.36 |
| APK SHA-256 | `F5BD7623521E7ACC115E68994F55497862DC78BE9525A3BDFD20E789F4C5596A` |
| APK bytes | 90.572.872 |
| evidências | `D:\AI-Shared\test-results\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d` |

O APK existente anteriormente na worktree de verificação tinha origem
`945f022…` e SHA-256 `509AF591…`; foi rejeitado como superseded e não foi usado
como evidência do HEAD final.

## Resultados

| Gate | Estado | Observação objetiva |
| --- | --- | --- |
| carga do MP4 | PASS | `readyState=4`, duração 293,843 s, HTTP 206/h2 |
| reprodução/cues | PASS | tempo 0→26,180375 s, cue ativa mudou; cenas aos 9 s/22 s |
| pause | PASS | `paused=true`; tempo 155,897787 s estável |
| painel separado | PASS | bounds do vídeo terminam em y=1201; painel começa em y=1201 |
| toggle | PASS | Mostrar/Ocultar; `aria-pressed`; cue esvaziada/restaurada |
| foco/semântica | PASS | `caption-toggle` focalizável; TalkBack expôs ToggleButton e texto |
| fala TalkBack | UNKNOWN | diálogo de permissão do Accessibility Suite impediu ciclo completo |
| sem VTT | PASS | zero tracks, sem botão ou texto de legenda |
| YouTube | PASS | caminho editorial alternativo preservado |
| retorno | PASS | volta à aula sem crash/ANR |
| áudio técnico | PASS | AAudio media `started`, não mutado, 24 kHz mono |
| áudio acústico | UNKNOWN | sem instrumento/observador confiável para ouvir |
| cookies/credenciais | PASS no caso | zero cookies e nenhum Cookie/Authorization na mídia |
| crash/ANR | PASS | buffer crash vazio; nenhum match fatal no log do app |

## Hashes representativos

| Arquivo | SHA-256 |
| --- | --- |
| `05-playing-09s.png` | `DCB0FCA51C041B9790E077ACC29CEE6CCCDD29EC17BA8E9272507D60AEA74E23` |
| `06-playing-22s.png` | `FDB861EA808BA5B2D68CF5FEAC0640168FF2D2654B74224C01A4FBF6C809EB75` |
| `12-captions-hidden.png` | `2C5C8983C5CF1D0770A14D7A70667121642EE05D51E1BEFF0B6A5D1D2BA0F929` |
| `13-captions-shown.png` | `11AA8C72FE0450DF7342866CEC4D9B1DF92567F191D1109A22100367F53C3D45` |
| `16-player-no-vtt.png` | `71296095145155E8629B45F1585EA13F53DF6696FFA1B2459FC092D9D0F293C6` |
| `18-player-youtube.png` | `048CAB7572D806225182CC5A7E9A83A34C7D3A9177A4197AA2EDB6179E809F47` |
| `cdp-playback.jsonl` | `6DFE61FD3E4EFABD77BF2FEFBE0AD099E9ADF8DC0B2FF7AE67222E9A666AB311` |
| `cdp-captions-hidden.jsonl` | `E511F33B18B2A17F2385B752004BF3AACECEF01A673799FDC72EC9A1CC36956B` |
| `cdp-captions-shown.jsonl` | `39BCC62C6FF035E9387D6865A51E6B6062F09B433A8BE683B8D402850D171A1A` |
| `cdp-no-vtt.jsonl` | `6AE02EF556D3ABC4525EFAD32A09DD679364DEB1F79D14C74D2A22C18EB6B358` |
| `ui-10-talkback.xml` | `F99D305BB4E0FAF85F35217316CE6CA29D6552AC40619D592525D2B92CF7B29B` |
| `pr295-app-logcat.txt` | `5BB0400A524D180EACBF9031171F4442508ED4E123F61B48AEFB570547D1440B` |
| `pr295-crash-logcat.txt` | `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` |

## Regressão acadêmica reutilizada

O PR #295 não altera a árvore `api/`. Foi reutilizado o gate do ancestral #293,
com 72 testes EAD + 6 testes do player (**78/78 PASS**) e sete testes acadêmicos
representativos (**7/7 PASS**): flag/escopo do lifecycle, hierarquia de papéis,
frequência exata de 70% e legado, pedido de certificado próprio/ativo/snapshot e
idempotência, ordem do último checkpoint, snapshot de CourseVersion e gate de
aprovação desligado por padrão. O mesmo conjunto de sete testes passou novamente
com ambiente lockado e `--basetemp` isolado; duas warnings de depreciação não
alteraram o resultado.

| Evidência preexistente | SHA-256 |
| --- | --- |
| `flutter-ipex-player-test.log` (6/6) | `E936139BAF1A932072E8D64CDB0536B0F0A40A76ADE693E8D956BC96686B52F9` |
| `flutter-ead-regression.log` (72/72) | `9E41DC03EEAB8D4900997C831A785D83F91AC3529706968F72FC48EB69BC901E` |
| `flutter-analyze.log` | `729241767170FB3C5F05E21F6E7A884767B853CDCA7118E249B4A7C71F9A5AEE` |
| `api-academic-seven-focal.log` | `78F328AFB05076E9F80088F4BFBDD9B4A3D21D344948FC6121328E1574D72C59` |
| `preflight-structural.json` | `A46DF7B8A37CA8A73A3EED3C4FB49C34F379A2376F4C41EA598B58A8A5CD45B3` |

Esses arquivos estão em
`D:\AI-Shared\work\android-qa\results\largeo-acceptance-20261019`. Fixture não é
homologação da integração LearnPress real: essa lacuna permanece explícita no
PR #292 e não foi promovida a PASS.

## AAB inicial e reprodução limpa posterior

**Observed:** `cartilhas_app/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
é ignorado pelo Git, permaneceu com referência a
`dev.flutter.plugins.integration_test.IntegrationTestPlugin` e a compilação
release exclui esse plugin dev-only. A tentativa `--no-pub` falhou na compilação
Java. A repetição sem `--no-pub`, conforme o comentário do runner oficial,
encerrou o compilador mas deixou o wrapper `flutter.bat` em loop, sem AAB; o
wrapper foi interrompido, sem encerrar o daemon Gradle compartilhado. Lockfile e
working tree ficaram intactos.

**Expected:** o runner deve regenerar deterministicamente o registrant release
sem plugins dev-only antes do Gradle e produzir AAB inspecionável sem chave real.

**Responsible boundary:** tooling Flutter/Android e `tooling/build_production.ps1`,
não o componente de legendas.

**Reprodução posterior:** a integração limpa #292+#295 em `c853db0…`, usando o
mesmo Flutter 3.44.9 diretamente pelo `flutter_tools.snapshot`, regenerou o
registrant e produziu o AAB sem erro. O wrapper `flutter.bat` também travou em
`pub get` sem filho Dart, confirmando a fronteira de ambiente. Nenhuma edição
manual no arquivo gerado foi necessária. Ver
`../INTEGRATED_RELEASE_RECEIPT_20261019.md`.

## Estado GitHub observado após reautenticação

O PR #295 permanece draft/OPEN, base #293 `91c5934e…`, HEAD `b05eaa0…`,
mergeável/CLEAN, sem reviews, pedidos de review ou threads. Analyze-test,
gitleaks e as duas verificações de quarentena WordPress concluíram SUCCESS. Os
demais HEADs conhecidos (#238, #284, #287, #289, #292 e #293) também foram
confirmados sem mudança e com seus checks verdes.

As Issues #3 e #197 já cobrem preflight/release; por isso nenhuma issue
duplicada foi aberta antes de reproduzir o problema do registrant em worktree
limpa pelo junction ASCII. O handoff deste recibo deve ser publicado na Issue
#294 e no PR #295; o bloqueio do AAB pertence à Issue #197 se persistir.
