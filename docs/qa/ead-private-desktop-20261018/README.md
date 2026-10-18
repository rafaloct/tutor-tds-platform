# Tutor TDS × LearnPress | Replay E2E privado no DESKTOP-8T5DRBS

**Data:** 18/10/2026 (UTC)
**Escopo:** Issue #241; PR #242 (ponte Android privada) e plugin PR #238;
alinhamento de evidências com PR #278 (resiliência UIAutomator).
**Resultado:** TESTED-EMULATOR-ANDROID35 / **PASS somente para
conteúdo editorial público, anônimo e read-only do WordPress sintético**.
Não é homologação institucional, Play Store, presença, matrícula, quiz ou certificação.

## Proveniência inspecionada

- Fonte do APK previamente construído: `b58fffbe43d2b2ab12685749237584a20a543964`,
  branch que originou o PR #242. A worktree desta repetição partiu do PR #242,
  `18fd9b97f825badc5cd7bc481f35e07a4687b989`, sem modificar Flutter.
- APK: `TutorTDS-PrivateWP-Android35-QA.apk`, SHA256
  `181b743e3249c56a75eec7faabd43bbdcffa5b9cca4a846b4f918136fa825e47`.
  `aapt dump badging`: `1.4.0-dev`, pacote exclusivamente debug
  `com.tutortds_cartilhas.dev.dynamicqa.r00ad5b420ca34272893828e84024326c`.
  O app instalado via Play anteriormente auditado como `1.4.1+14` não foi tocado.
- Emulador `tutor_tds_remote_catalog_qa`, Android API 35, imagem
  Pixel Tablet Google Play `x86_64`, WHPX utilizável, `emulator-5554`,
  perfil QA temporário 1.536 MB, dois núcleos, resolução 720 × 1280,
  density 320, sem alteração permanente do AVD (`-read-only`).
- WordPress sintético **6.7.2**, LearnPress **4.3.6**, contêiner Docker de
  laboratório sem PortBindings públicos. Adaptador editorial instalado:
  classe `class-tds-learnpress-editorial.php` com SHA256
  `064c350c544f60c02526b774c96b56d4e3a77e28cf1e279346999d9d489b632c`,
  equivalente ao hash verificado do código do **PR #238**.
- Curso `12`, lição `13` e opt-in de material/YouTube são **100%
  sintéticos**, sem licença de vídeo real comprovada.

## Rede de QA e isolamento

```text
APK QA (emulador-5554)
  → adb reverse tcp:18731 tcp:18733 [ADB server exclusivo 5038]
  → proxy Python 127.0.0.1:18733 (somente GET e allowlist curso 12/aula 13)
  → túnel SSH preexistente 127.0.0.1:18731 no desktop
  → WordPress + LearnPress sintéticos, contêiner na rede Docker privada
```

O proxy descarta Authorization/Cookie, não envia POST/PUT/PATCH/DELETE,
rejeita caminhos fora da allowlist e registra **somente** rota autorizada,
HTTP, presença de ETag, revalidação e quantidade de bytes. Nenhum corpo
HTML, token, CPF, senha, cookie, gabarito ou nome real foi gravado. O
catálogo de 11 ofertas do site permanece HTTPS no código do aplicativo;
o laboratório é um cartão separado e rotulado como fictício.

## Execução e HTTP realmente verificados

Teste offline do harness: `python -m unittest discover -s
tooling/qa/ead_desktop_private_bridge -p 'test_*.py'`:
**7/7 PASS**; `py_compile` PASS. Casos incluem XML completo/truncado,
espera sem clique cego e allowlist que exclui outros cursos.

Testes Android na sessão **final**, sem rebuild:

| Passo Android observado | Evidência | Resultado |
| --- | --- | --- |
| Entrada sem cadastro | `01-welcome.png` | PASS |
| Cartão `LABORATÓRIO INTERNO · DADOS FICTÍCIOS` | `02-lab-catalog.png` | PASS |
| Percurso SAF QA (1 seção, 2 itens) | `03-private-path.png` | PASS |
| Aula QA autorizada com texto do LearnPress | `04-authorized-lesson.png` | PASS |
| Atualização da aula no mesmo APK | `05-lesson-refreshed.png` | PASS |
| Revalidação do percurso no mesmo APK | `06-curriculum-refreshed.png` | PASS |

`http-app-audit.json` foi derivado do proxy **exclusivamente entre
`started_utc` e `finished_utc` do recibo final**, excluindo provas
independentes anteriores feitas diretamente do desktop:

| Rota do aplicativo | HTTP | Condição |
| --- | --- | --- |
| `curriculum_12` | **200** | Primeiro carregamento |
| `lesson_13` | **200** | Aula autorizada |
| `lesson_13` | **200** | Atualização de aula |
| `curriculum_12` | **304** | `If-None-Match` enviado pelo próprio APK |

Portanto **o aparelho consultou o WordPress sintético via rede privada e
revalidou o ETag sem instalar novo APK**. Nenhuma escrita acadêmica foi
feita: o adaptador do PR #238 é um leitor, não um serviço de matrícula,
progresso, SSO ou certificados.

## Capturas e integridade

- Seis screenshots verdadeiros Android, não fixtures golden.
- `raw-android-screenrecord.mp4` é a gravação original Android
  (H.264, 720 × 1280, duração **69,096544 s**, 1.140.589 bytes,
  `screenrecord_exit=0`, áudio não gravado).
- SHA256 original do MP4:
  `195c12feae2b8ec89503f4ab176bde3ec97094cef7b2587890dfd515f9ae7acf`.
- O `receipt.json` registra as sete mídias, tamanhos e hashes SHA256
  conferidos após cópia; não contém credenciais ou HTML privado.

Os arquivos originais permanecem em
`C:\AI-Shared\evidence\tds-issue241-desktop-replay-20261018-v2\android35-private-replay-dedicated-adb\`.
As evidências deste diretório são cópias verificadas para revisão do PR.

## Duas tentativas anteriores e limites comprovados

1. AVD Android35 com 2 GB: memória livre do Windows caiu abaixo de 1 GB;
   captura real mostrou **“System UI isn't responding”**. Runner
   retornou BLOCKED, sem atribuir falha ao aplicativo.
2. AVD otimizado com 1.536 MB: navegação até aula passou e quatro GET
   chegaram ao proxy, mas `adb screenrecord` encerrou com código **255**:
   MP4 de 42 s foi classificado como parcial, não entrega completa.
3. AVD otimizado + **servidor ADB independente na porta 5038**:
   `NAVIGATION_PASS`, cinco etapas, HTTP 200/304, seis PNGs e MP4
   válido com `screenrecord_exit=0`.

Somente a **terceira** sessão foi selecionada como QA final.

## Limites para homologação institucional

- E2E **anônimo, read-only, um curso/uma aula fictícios**. Não avalia
  o catálogo completo dos nove cursos/48 videoaulas, títulos YouTube
  com direitos reais, legendas VTT, as 38 perguntas locais ou os
  29 quizzes/282 questões publicados no WordPress (sem vínculo público
  na auditoria original de 17/10).
- Sem autenticação institucional/SSO, sessão do aluno LearnPress,
  tentativa ou nota, progresso, frequência, certificado oficial,
  Chatwoot, Tutor/RAG contextual ou instalação no WP real.
- Testes de controle de matrícula, notas e certificados exigem os
  respectivos sistemas autorizativos, não podem ser derivados de GET.
- RBAC real de edição de `lp_lesson` continua pendente de fixture,
  conforme Issue #276 / erro `LearnPress PostModel.php:333`.
- Problemas de UX observados: título `Percurso de aprendizagem`
  truncado e plurais `1 seções`, `1 aulas`; merecem Issue específica,
  mas não alteram a leitura editorial.
- WordPress institucional/staging exige autorização específica,
  backup/rollback e validação de direitos de mídia; nenhum desses
  passos foi realizado aqui.

## Repetição segura (somente laboratório)

O roteiro requer **túnel privado pré-existente e validado**, sem novas
portas públicas, AVD Android35 `tutor_tds_remote_catalog_qa` ocioso,
APK debug com hash conferido e ao menos 3 GB livres antes do boot.

No PowerShell do DESKTOP-8T5DRBS, com caminho do SDK verificado:

```powershell
$adb = 'C:\Users\Usuario\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$emulator = 'C:\Users\Usuario\AppData\Local\Android\Sdk\emulator\emulator.exe'
$repo = 'C:\Users\Usuario\Projects\tds-issue241-desktop-replay-20261018'
# Antes de iniciar, garantir ausência de emulator-5554 e portas QA ocupadas.
Start-Process $emulator -ArgumentList @('-avd','tutor_tds_remote_catalog_qa',
  '-port','5554','-memory','1536','-cores','2','-gpu','host',
  '-no-window','-no-snapshot','-no-boot-anim','-noaudio','-read-only')
# Aguardar sys.boot_completed=1; nunca direcionar comandos ao Xiaomi.
& $adb -P 5038 start-server
& $adb -P 5038 -s emulator-5554 shell wm size 720x1280
& $adb -P 5038 -s emulator-5554 shell wm density 320
# Conferir pacote do APK isolado via aapt antes de instalar.
& $adb -P 5038 -s emulator-5554 install -r '<APK QA validado>'
& $adb -P 5038 -s emulator-5554 reverse tcp:18731 tcp:18733
# Janela PowerShell A: deixar este proxy rodando, até aparecer QA_PROXY_READY.
python "$repo\tooling\qa\ead_desktop_private_bridge\synthetic_http_audit_proxy.py" `
  --audit '<arquivo audit JSONL inédito>'
# Janela PowerShell B: após o proxy READY, executar separadamente:
python "$repo\tooling\qa\ead_desktop_private_bridge\replay_android.py" `
  --adb $adb --out '<diretório de evidência inédito>'
# Por fim: remover somente esse reverse, encerrar emulator-5554,
# parar somente o proxy 18733 e o ADB dedicado 5038.
```

**Ambiente após QA:** emulador, proxy temporário e ADB 5038 encerrados.
Túnel SSH existente em `127.0.0.1:18731` preservado. Nenhum merge,
deploy, build, alteração de produção/Play, dado de aluno ou mudança
do contêiner QA executado durante esta repetição.
`MERGE_ALLOWED=NO`; PR deve permanecer **draft**.
