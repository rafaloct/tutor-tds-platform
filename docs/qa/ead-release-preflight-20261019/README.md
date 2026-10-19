# Issue #291 — gate Flutter/EAD e preflight Android

Data: 19/10/2026. Base `1de5e9e6f55c161e433cbf5882cb5e62a80eebc3`;
branch `agent/issue-291-android-preflight-20261019`. Este recibo é local e
sintético; não é aceite de produção, Play, plugin WordPress ou mídia Android.

## Contrato e limites

- **OBSERVED:** PR [#287](https://github.com/rafaloct/tutor-tds-platform/pull/287)
  adiciona a tela MP4/VTT e fallback manual; PR
  [#284](https://github.com/rafaloct/tutor-tds-platform/pull/284) documenta
  navegação Android de catálogo e fallback de aula sem opt-in, sem áudio/VTT MP4.
  O código do player não envia `MediaItem`, check-in, nota, progresso ou comando
  de certificado. Isso é inspeção de fonte, não prova de runtime Android.
- **TARGET:** gate do currículo vivo, aprovação/revogação editorial, URL HTTPS
  IPEX, VTT pt-BR, fallback YouTube, back navigation e contratos acadêmicos com
  dados sintéticos; AAB candidato somente após evidências e revisão humana.
- **DECISION:** WordPress é editorial; API/PostgreSQL decide matrícula, presença,
  progresso oficial e certificados. Reprodução de vídeo não concede nenhum
  desses estados. Emulador LARGeo `emulator-5554` reservado à outra sessão.
- **UNKNOWN/BLOCKED:** reprodução, áudio e seleção/legibilidade VTT pt-BR em
  Android 35 não têm recibo original verificável para este SHA. O executor do
  PR #287 recebeu [pedido objetivo](https://github.com/rafaloct/tutor-tds-platform/pull/287#issuecomment-6269915232).

## Evidência executada nesta worktree

| Gate | Estado | Evidência |
| --- | --- | --- |
| SHA/base/branch | OBSERVED | `git rev-parse HEAD` na abertura = base acima; branch exclusiva. |
| SDK | OBSERVED | Git tag exata `3.44.9`; `dart.exe --version` = Dart 3.12.2. |
| Novo preflight offline | TESTED-LOCAL | `python -B -m unittest discover -s tooling/mobile_qa -p test_ead_release_preflight.py -v`: **3/3 PASS**; `python tooling/mobile_qa/ead_release_preflight.py`: `structural_pass=true`. |
| Dart/Flutter analyze e testes focais | NOT_RUN | SDK 3.44.9 existe, mas o sandbox nega abertura de `bin/cache/lockfile`; invocação direta do analyzer também falha ao iniciar `dartaotruntime.exe` (`CreateFile failed 5`). `.dart_tool/package_config.json` ausente. Não inferir PASS de CI anterior. |
| API sintética focal | PARTIAL | `python -m pytest -q -p no:cacheprovider tests/test_certificate_approval_gate.py`: **1 PASS**. Sete testes selecionados de catálogo, turma, presença e certificado não foram coletados: faltam `pwdlib` e `alembic` no Python disponível; `uv` e o ambiente lockado não estão disponíveis nesta worktree. Nenhuma chamada de produção. |
| Player MP4/VTT Android | UNKNOWN | Sem ADB, instalação ou acesso ao emulador reservado. HTTP 200 e HTML carregado não comprovam playback, áudio ou legenda. |
| AAB | NOT_RUN | Sem bundle produzido, assinatura ou upload. `key.properties` ausente; ABI real do AAB permanece UNKNOWN. |

### Diagnóstico do bloqueio de teste

**Observed:** `flutter.bat --version` não iniciou pelo lock do SDK; a invocação
direta do snapshot retornou acesso negado ao `bin/cache/lockfile`. O analyzer
direto encontrou `CreateFile failed 5` ao criar o processo do analysis server.
**Expected:** Flutter 3.44.9 inicia no `cartilhas_app` desta worktree e executa
analyze e testes focais. **Responsible Boundary:** permissões do sandbox para
cache/processos do SDK instalado fora da raiz gravável. **Evidence:** comandos
acima; `dart.exe --version` funciona. **Likely Root Cause:** cache do SDK fora
da raiz gravável, com package config ainda ausente. **Affected Files:** nenhum
fonte de produção; comandos Flutter/analyzer/testes Dart. **Structural Fix:**
executar estes comandos em ambiente com cache SDK e Pub graváveis, sem alterar
o SDK/junction compartilhado, e anexar saída com SHA exato do candidato.

Os testes selecionados da API pararam uma vez na coleta por dependências
ausentes; não foram repetidos com instalação sem lock. O teste isolado de flag
de aprovação passou. Não houve alteração de dependência.

## Preflight somente leitura

Executar da raiz do repositório:

```powershell
python tooling/mobile_qa/ead_release_preflight.py
python -B -m unittest discover -s tooling/mobile_qa -p test_ead_release_preflight.py -v
```

O script compara `pubspec.yaml` com `release_status.json`, pin Gradle/AGP/Kotlin,
vínculo de `versionCode/versionName` ao Flutter, gates debug/release e presença
de `key.properties` **sem abrir essa chave**. Observado: `1.4.0+13`, min SDK 24,
target/compile SDK 36, Gradle 9.1.0, AGP 9.0.1, Kotlin 2.3.20. Os guardas de
`DYNAMIC_QA_ISOLATED_PACKAGE`, `TDS_EDITORIAL_QA_HTTP_BASE`, flags de risco e
freeze estão no script Gradle. O manifesto antigo declara
`release_build_allowed=true` e os gates históricos obrigatórios `passed`, mas
o artefato registrado é **superseded**, `matches_current_source=false` e
`upload_allowed=false`. Esses campos não aprovam o candidato MP4/VTT.

Não há filtro ABI explícito no `build.gradle.kts`; a ABI efetivamente empacotada
deve ser lida de um novo AAB. A ausência de `key.properties` aqui permitiria,
em princípio, um bundle local sem assinatura, mas o SDK/Gradle não puderam ser
executados neste sandbox. Não alterar `release_status.json` nem criar assinatura
para atravessar o gate.

## Matriz acadêmica por fixture

| Fluxo | Evidência existente no checkout | Resultado nesta sessão |
| --- | --- | --- |
| Entrada pública e caminho do curso | `ead_welcome_entry_test.dart`, `ead_home_entry_test.dart`, `ead_learning_path_screen_test.dart`, PR #284 Android | Flutter NOT_RUN; PR #284 tem recibo anterior apenas para navegação/fallback. |
| Currículo MP4, VTT, YouTube, revogação, volta | `ead_ipex_mp4_player_test.dart`, `ead_editorial_bridge_repository_test.dart`, `ead_youtube_player_screen_test.dart`; novos casos de revogação e back navigation | Novos casos adicionados, Flutter NOT_RUN. |
| Inscrição/matrícula e turma | `classroom_access_path_test.dart`, `learner_classrooms_screen_test.dart`, `test_class_lifecycle.py` | NOT_RUN nesta sessão; API não coletou por dependência ausente. |
| Check-in e frequência | `official_attendance_test.dart`, `test_official_attendance.py` | NOT_RUN nesta sessão; API não coletou. |
| Progresso e conclusão | `learning_delivery_reader_test.dart`, `test_certificate_policy_candidate.py` | NOT_RUN nesta sessão; não inferir crédito por play. |
| Pedido e aprovação humana de certificado | `certificate_request_repository_test.dart`, `test_certificate_requests.py`, `test_certificate_approval_gate.py` | Flag isolada 1 PASS; fluxo completo NOT_RUN. Emissão automática não comprovada nem autorizada. |

## Próximos gates e ação humana

1. Em executor com SDK/Pub graváveis, rodar `flutter analyze` e testes focais
   MP4/YouTube/currículo/navegação/academia no SHA do PR; publicar logs e CI.
2. Receber recibo Android original do #287 com SHA do código/APK, captura de
   playback real, método de verificação de áudio e legenda pt-BR; até lá UNKNOWN.
3. Preparar ambiente Python pelo `api/uv.lock` e repetir os sete testes
   selecionados, sem dados reais, antes de classificar a matriz acadêmica PASS.
4. Após os gates, produzir **somente** AAB isolado sem chaves reais se o ambiente
   permitir; registrar hash, versionCode e ABIs do artefato. Assinatura e Play
   exigem decisão humana separada.

Reason para ação humana: Android áudio/VTT e release dependem de evidência física
original e decisão de publicação. Exact human action: fornecer/validar recibo do
executor Android e aprovar uma release específica após revisão da cadeia de PRs.
What remains unblocked: revisão de código, fixtures, preflight e CI em ambiente
isolado com dependências travadas.
