# Issue #241: correção do runner Android de acessibilidade (18/10/2026)

**Status: TESTED-EMULATOR para navegação pública até o percurso.**
Ambiente e código de prova são QA isolado, não homologação institucional.
Branch: `agent/issue-241-android-qa-runner-v2-20261018`.
Fonte APK existente: PR #240 `846a2c41d83cd3c4ca3161fd575f698d6618883d`, sem recompilação.
Package validado por `aapt`: `com.tutortds_cartilhas.dev.dynamicqa.r846a2c41d83cd3c4ca3161fd575f698d`,
versão `1.4.0-dev`. APK oficial Play não foi modificado.

## Causa observada e correção

Na primeira execução, `01-welcome.png` mostrava apenas o **splash azul**
e `99-blocked.png` ainda estava numa transição de animação. O runner
tentava `uiautomator dump` após espera fixa de 7 s; tratar seu XML
parcial como defeito do widget Flutter seria uma inferência indevida.

No novo runner `tooling/qa/ead_visual/capture_story.py`:

- parse do XML apenas quando uma hierarquia completa é encontrada, sem
  persistir/publicar o corpo do dump;
- retentativas limitadas para UI Automator e espera até o botão realmente
  aparecer; primeiro tenta `resource-id`/Semantics identificável, depois
  `content-desc`/texto; nunca usa tap arbitrário em coordenadas fixas;
- não inicia os screenshots de navegação antes da primeira renderização;
- valida pelo nome da tela a transição para catálogo e percurso nativo;
- grava tela Android via `screenrecord` e recupera o MP4 por `adb pull`
  ou fluxo `exec-out cat`, com verificação de assinatura `ftyp`;
- captura/parâmetros de exibição restaurados, apenas no emulador de QA.

Não foi necessário editar os widgets `Semantics` do app para liberar
esta execução. Um `ValueKey` Flutter não é, por si só, um recurso de
acessibilidade Android.

## Testes executados, não simulados

**Unitários offline:** `python -m unittest discover -s
tooling/qa/ead_visual -p 'test_*.py' -v`: **8/8 PASS**.
`python -m py_compile`: PASS.

**Android:** LARGeo, Pixel_8_Pro Android API 35, WHPX, pacote QA isolado.
`run_profiles.ps1` com `android35-compact` e 75 segundos
executou e concluiu com **exit 0**, `CAPTURED` e quatro artefatos.

Diretório exato:

`D:\AI-Shared\android-qa\results\pr240-20261018-v2\ead-first-20261018T223556Z-android35-compact\capture\`

| Artefato | Observação |
| --- | --- |
| `01-welcome.png` | Botão público EAD visível |
| `02-ead-catalog.png` | Catálogo EAD com 11 ofertas |
| `03-learning-path.png` | Percurso Agricultura Sustentável: 8 seções, 13 itens, 6 aulas em seções de vídeo |
| `raw-android-screenrecord.mp4` | Gravação original Android, sem áudio, `screenrecord_exit=0` |

SHA256 do MP4: `a41c63dc36789d09dd757b6d0961e827c13b92dc2592f134ee94e2c0c6469ec8`.
O comprovante `receipt.json` contém hashes e eventos, sem credenciais.
Os PNGs são capturas Android reais, **não golden sintético**. O clipe
não comprova reprodução de vídeos didáticos ou YouTube incorporado.

## Isolamento e limites do E2E

**Esta nova execução usa o catálogo público configurado no APK e
não foi direcionada ao WordPress sintético do PR #238.** A navegação
até o percurso foi comprovada; HTTP 200/304 do adaptador não foram
capturados pelo app nesta execução. Não declarar integração E2E
nova com o plugin apenas a partir do screenshot.

Referências verificáveis independentes:

- PR #277 / Issue #276: 18/18 testes HTTP no WordPress + LearnPress +
  MariaDB sintéticos, com ETag, opt-in, revogação e rollback.
- PR #242 / Issue #241: evidência anterior de E2E Android com
  **curso fictício** id=12 e lição id=13, conexão privada ao WP,
  atualização do HTML, ETag/revogação no mesmo APK;
  `docs/qa/ead-private-android-20261018/README.md`.

O adaptador público do PR #238 é **read-only**. Ele não implementa
autenticação federada, matrícula, tentativa de quiz, nota, progresso
acadêmico, frequência ou certificados. Nenhum desses estados pode ser
fabricado a partir da navegação ou de uma reprodução de mídia.

**UNKNOWN/BLOCKED:** regressão nova combinada com o plugin do PR #238,
homologação do WP institucional, RBAC real de edição de lição (bloqueio
LearnPress PostModel.php:333 na fixture de QA), direitos reais de
vídeos/YouTube, Tutor/RAG contextual por aula, Android 36 e Play.
Nenhuma alteração de dados institucionais, merge, deploy ou release.

## Reprodução restrita

```powershell
$repo = 'D:\AI-Shared\work\tds-pr240-android-qa-20261018'
$apk = "$repo\cartilhas_app\build\app\outputs\flutter-apk\app-debug.apk"
& "$repo\tooling\qa\ead_visual\run_profiles.ps1" `
  -Profile android35-compact -ApkPath $apk `
  -Package 'com.tutortds_cartilhas.dev.dynamicqa.r846a2c41d83cd3c4ca3161fd575f698d' `
  -Seconds 75 -OutputRoot 'D:\AI-Shared\android-qa\results\pr240-20261018-v2'
```

**HUMAN_GATE=NO** para este recorte de QA. **HUMAN_GATE=YES**
para instalar plugin no ambiente institucional, autenticar usuários
reais, migrar identidade/notas ou publicar direitos de mídia.
`MERGE_ALLOWED=NO`, `PRODUCTION_ALLOWED=NO`.
