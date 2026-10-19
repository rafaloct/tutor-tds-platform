# Issue #245 — player YouTube nativo: prova Android 35

**Data:** 19/10/2026 (Palmas). **Estado: TESTED-ANDROID-35** para vídeo
**exclusivamente sintético/autorizado na fixture**, sem homologação de direitos
institucionais ou publicação na Play.

## Ambiente e identidade do artefato

- DESKTOP-8T5DRBS, AVD `tutor_tds_remote_catalog_qa`, Android API 35,
  Pixel Tablet emulador `emulator-5554`, WHPX. Não foi usado o Xiaomi físico.
- APK original do PR #246, build QA `1.4.0-dev` / versionCode 13,
  package isolado
  `com.tutortds_cartilhas.dev.dynamicqa.rcd78c06298204eea9a0aa2e8d263614a`.
  SHA256 do APK **5B90913B9DFF2C369A7C6A9C4963BDB217485BE7F1A71B5770727BFF227EB452**,
  90.571.736 bytes. Reutilizado sem rebuild.
- Fonte Flutter do PR #246 HEAD `d2baed510b8affd12e45a64a9eb329490d89310b`.
  A branch de evidências é empilhada no PR #284 (HEAD-base
  `7112d098891aef357c47ab70707d0d5e8a686a47`), que já inclui o player.
- WordPress + LearnPress **sintéticos**, curso #12 / aula #13, somente
  GET público sem cookies ou identidade. O adaptador editorial retornou
  `media.provider=youtube`, `media.video_id=FG14ksTaMCE`
  com opt-in de teste, **não aprovação de direitos dos vídeos reais**.
  Túnel SSH já existente foi acessado por proxy HTTP local somente leitura
  `127.0.0.1:18744` e `adb reverse tcp:18731 tcp:18744`.
  O proxy aceita exclusivamente `curriculum_12` e `lesson_13`.

## QA OBSERVED: execução real

| Etapa | Resultado | Evidência |
| --- | --- | --- |
| Abrir aplicativo QA isolado | PASS | `01-qa-welcome.png` |
| Cartão LABORATÓRIO INTERNO · DADOS FICTÍCIOS | PASS | `02-lab-synthetic-catalog.png` |
| Abrir percurso sintético SAF QA | PASS | `03-private-curriculum.png` |
| Ler aula #13 autorizada pelo adaptador | PASS | `04-authorized-lesson.png` |
| Tocar «Assistir vídeo aprovado» e navegar no app | PASS | `05-native-player-after-load.png` |
| Miniatura YouTube + play **sem autoplay** | PASS | `05-native-player-after-load.png` |
| Toque **manual** no botão Play | PASS | `01-after-manual-play.png`, cronômetro **0:25 / 4:02** e ícone Pausa |
| Avanço de conteúdo/frames dentro do player | PASS visual | `02-playback-progress.png`, `05-player-current-after-clip.png` |
| Replay e vídeo nativo gravado | PASS | `06-actual-webview-replay-18s.mp4`, quadros derivados aos 2 e 14 s |
| Voltar à aula no Flutter | PASS | `07-return-to-lesson.png`, retornou a «Aula do EAD» |
| Solicitações HTTP no período da execução | PASS | `synthetic-http-during-app.json`: curso 200, aula 200 |

A captura dos quadros aos 2 e 14 segundos do replay mostra movimento
real de animação no WebView dentro do Tutor TDS. Os PNGs
`replay-frame-02s.png` e `replay-frame-14s.png` foram extraídos por
FFmpeg do arquivo original e são **derivados**, não capturas ADB independentes.
O MP4 original foi preservado sem edição ou concatenação.

## Gravação, hashes e proveniência

- `native-youtube-screenrecord.mp4`: gravação original Android do fluxo
  inicial até a tela interna; H.264 720×1280, **135,095 s**, 2.011.059 bytes,
  `screenrecord_exit=0`, SHA256
  `d35216b755c50151719fefa2ecade2d90bfb58a0b5b691a0be392a018717ecd1`.
  **Não** alegar que este vídeo inteiro comprova reprodução, pois o Play foi
  acionado manualmente depois de terminada a captura principal.
- `06-actual-webview-replay-18s.mp4`: captura Android original, independente,
  após tocar Replay manualmente, H.264 720×1280, **17,796 s**,
  1.438.453 bytes, exit 0, SHA256
  `f43b75cc381084b609e3b724ba687139de525af37b3bbde3fb91df10cefbd74a`.
  Os frames do início/fim são visualmente diferentes e mostram vídeo
  reproduzindo dentro do app. O vídeo **não contém áudio do sistema**.
- `android-navigation-receipt.json`: sete artefatos da navegação inicial,
  hashes SHA256 conferidos com os arquivos versionados.
- `replay-clip-receipt.json`: arquivo original e seu SHA256.
  `synthetic-http-during-app.json` é extraído **somente** da janela
  `2026-10-19T12:08:59Z` a `2026-10-19T12:11:51Z`.
  A chamada de consulta manual anterior à execução foi excluída.
  Nenhum corpo HTML privado, token, cookie, CPF, nome de aluno ou senha
  foi registrado.

## Limites obrigatórios e segurança

**COMPROVADO:** leitura da aula sintética autorizada, player WebView
YouTube dentro do Flutter, botão manual play/replay, progresso visível
da reprodução, CTA opcional «Abrir no YouTube» e retorno à mesma aula.
O botão de legendas CC apareceu na interface, **mas não comprova uma trilha
de legenda específica**, idioma, áudio ou requisitos TalkBack/fullscreen.

**NÃO COMPROVADO:** homologação dos direitos/opt-in de cada uma das
48 videoaulas reais, aulas protegidas sem autorização no WordPress
institucional, YouTube em outro país/dispositivo/rede, áudio audível,
legenda pt-BR real, reprodução offline, matrícula/SSO, presença,
avaliações, progresso oficial, certificados ou Tutor/RAG por aula.
Não inferir qualquer progresso acadêmico do vídeo.

O código do player não instancia `MediaItem`/trackers de conclusão;
a arquitetura de autorização requer opt-in editorial do WP. O proxy de
laboratório só encaminhou os dois GETs sintéticos. Isso não equivale
a monitoramento integral de tráfego para outros domínios.

O PR #284 tinha **736/736 testes Flutter e os checks de segurança verdes**
antes deste complemento de evidência. Uma nova execução de CI é necessária
no novo HEAD de QA para assegurar que a inclusão de arquivos não
introduziu regressão.

**MERGE_ALLOWED=NO**, **PRODUCTION_ALLOWED=NO**. Sem mudanças em
WordPress, YouTube uploads, chaves, Play, banco institucional ou dados
acadêmicos reais.
