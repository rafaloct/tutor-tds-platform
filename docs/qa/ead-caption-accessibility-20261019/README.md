# Issue #294 — legendas acessíveis no MP4 IPEX

Data: 19/10/2026. Base: `91c5934eb071d8decc8d26e12eeb50e63bd72846`.
HEAD homologado: `b05eaa058fb4b0c86c5569215652b893c55b517d`.
Branch: `agent/issue-294-caption-accessibility-20261019`.

## Estado final deste recorte

- **OBSERVED:** a cadeia local é #284 `7112d098…` → #287 `b9a7fab6…` →
  #289 `1de5e9e6…` → #293 `91c5934e…` → #295 `b05eaa05…`. O SHA
  conhecido do PR #292 (`e8b60569…`) não existe neste clone e parte de #289.
- **TESTED:** APK QA construído exatamente do HEAD acima e homologado no Android
  15/API 35. MP4 IPEX, play/pause, retorno, cues VTT, painel separado,
  mostrar/ocultar, caso sem VTT e provedor YouTube passaram. A árvore de
  acessibilidade expôs controles, botão e texto da legenda.
- **DECISION:** assistir mídia não concede matrícula, presença, progresso,
  conclusão ou certificado. YouTube continua alternativa editorial, não
  fallback automático de falha do MP4. Nenhuma produção, Play ou assinatura
  real foi tocada.
- **UNKNOWN:** anúncio falado e acionamento completos pelo TalkBack não foram
  concluídos porque o Android Accessibility Suite abriu seu diálogo de
  notificação; audibilidade acústica não foi medida. O stream de áudio, por sua
  vez, apareceu iniciado e não silenciado no `dumpsys audio`.
- **OBSERVED-GITHUB:** autenticação restaurada em 19/10; o PR #295 continua
  draft/OPEN no mesmo HEAD `b05eaa0`, mergeável/CLEAN, sem reviews ou threads e
  com analyze-test, gitleaks e quarentena WordPress SUCCESS. Os HEADs dos PRs
  #238/#284/#287/#289/#292/#293 também não mudaram.
- **SUPERSEDED:** na worktree inicial, o AAB de inspeção não foi produzido: uma tentativa
  falhou pelo `GeneratedPluginRegistrant.java` ignorado contendo o plugin
  dev-only `integration_test`; a repetição pelo fluxo normal terminou em hang do
  `flutter.bat`, sem compilador-filho e sem artefato. Não repetir sem corrigir a
  fronteira de geração do registrant no runner. A reprodução posterior em
  worktree integrada limpa pelo `flutter_tools.snapshot` passou e está registrada
  em `../INTEGRATED_RELEASE_RECEIPT_20261019.md`.

## Segurança e contrato

A tela gera HTML local. MP4 e VTT só são aceitos sob
`https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/`, sem
userinfo, porta, query, fragmento ou traversal, e os atributos são escapados.
O script local lê `textTracks`/`cuechange`, mantém a trilha `hidden` para evitar
sobreposição nativa e escreve cues em `textContent`. O botão tem nome PT-BR,
`aria-pressed` e `aria-controls`; o painel usa `role=status`, `aria-live=polite`
e fica abaixo do vídeo 16:9.

No tráfego observado, a requisição MP4 foi `GET`/HTTP 206/h2 sem cabeçalho
`Cookie` ou `Authorization`; o cookie jar tinha zero entradas. Isso prova o caso
QA inspecionado, não uma garantia universal do Android WebView. Nenhum token,
PII ou dado acadêmico foi enviado ao documento.

## Matriz focal

| Caso | Resultado | Evidência |
| --- | --- | --- |
| MP4 IPEX e atualização de cues | **PASS** | imagens aos 9 s/22 s; CDP: duração 293,843 s, 35 cues, reprodução até 26,18 s |
| Painel fora da animação | **PASS** | `05-playing-09s.png`, `06-playing-22s.png` |
| Mostrar/ocultar | **PASS** | `aria-pressed=false/true`, texto vazio/restaurado, foco no `caption-toggle` |
| Play/pause e retorno | **PASS** | tempo pausado estável em 155,897787 s; retorno sem crash/ANR |
| TalkBack | **PARTIAL** | árvore expõe play/mute/fullscreen/seek, ToggleButton e cue; anúncio falado não comprovado |
| Sem VTT | **PASS** | `textTrackCount=0`, sem botão/painel |
| YouTube | **PASS** | alternativa editorial `youtube-nocookie.com` carregada |
| Cookies/credenciais | **PASS no caso observado** | zero cookies; sem Cookie/Authorization no GET do MP4 |
| Áudio | **PARTIAL** | sessão AAudio `USAGE_MEDIA`, `started`, não mutada, 24 kHz mono; som acústico UNKNOWN |
| Crédito acadêmico por playback | **PASS (ausência)** | fonte/teste confirmam que o player não registra conclusão, presença ou certificado |
| Offline do player | **NOT_RUN** | reprodução é online-only; abertura externa manual preservada |

## Artefato e ambiente Android

- APK:
  `D:\AI-Shared\builds\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d\tutor-tds-pr295-b05eaa0-qa-debug.apk`
- SHA-256: `F5BD7623521E7ACC115E68994F55497862DC78BE9525A3BDFD20E789F4C5596A`
- tamanho: 90.572.872 bytes; pacote QA exclusivo
  `com.tutortds_cartilhas.dev.dynamicqa.rb05eaa058fb4b0c86c5569215652b893`;
  versão `1.4.0-dev` (13), minSdk 24, target/compile 36; ABIs arm64-v8a,
  armeabi-v7a e x86_64.
- emulador: Pixel 8 Pro, Android 15/API 35, 1344×2992, density 480,
  fingerprint `google/sdk_gphone64_x86_64/emu64xa:15/AE3A.240806.036/12592187:user/release-keys`.
- evidências duráveis (74 arquivos; 6.599.511 bytes):
  `D:\AI-Shared\test-results\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d`.

Hashes representativos e relatório ampliado estão em
`ANDROID_ACCESSIBILITY_RECEIPT_20261019.md`.

## Gates locais

- Flutter focal do player: **9/9 PASS**; analyze dos arquivos afetados:
  **PASS**, zero issues.
- regressão acadêmica representativa no HEAD: **7/7 PASS** com `--basetemp`
  isolado. A primeira execução concluiu os sete testes, mas o cleanup encontrou
  um diretório pytest histórico sem permissão; o único rerun isolou essa falha
  de infraestrutura.
- preflight EAD/Android: **3/3 PASS**; `structural_pass=true`;
  `key.properties` ausente; nenhum candidato AAB atual.
- configuração `production.example.json`: **PASS** no validador; endpoints
  HTTPS aprovados e todas as flags de risco `false`.
- `pubspec.lock` permaneceu com SHA-256
  `3E044DE97EA5EABE70563B12D84345DC685192241185F64AC964A23186DE1BFE`.
- AAB do `b05eaa0`: **NOT_GENERATED** nesta worktree. O candidato integrado
  posterior `c853db0` gerou AAB não assinado para inspeção; o AAB histórico
  continua `superseded`, `upload_allowed=false` e `matches_current_source=false`.
- GitHub: PR #295 no HEAD acima, CI integral **PASS**, draft/mergeável; promoção
  continua dependente de revisão humana e da cadeia stacked.

Rollback: reverter apenas os commits do PR #295 na branch de integração. URLs,
aprovação editorial, dados, matrículas e serviços não foram alterados.
