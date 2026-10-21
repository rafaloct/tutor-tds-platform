# Samsung TalkBack — execução assistiva da Issue #308

Base `6f01ee4cb3f26aae039d2d0c6be5d348538843bc`, Samsung SM-T835/API 29. O player QA usa a mídia própria TDS já autorizada; o catálogo editorial permanece 0/48 e nenhuma flag de publicação ou dado acadêmico é alterado. Áudio ouvido diretamente e pausa/retomada por toque já foram atestados pelo responsável na Issue #308; não repetir esses gates.

## Fronteira observada

- TalkBack está instalado no Samsung, mas `accessibility_enabled=0` e nenhum serviço de fala está habilitado na inspeção ADB read-only de 20/10/2026.
- A árvore anterior no emulador expôs o botão de legenda, seu estado e o texto. Ela não prova anúncio falado ou acionamento no Samsung.
- A rota normal do app não abre uma aula de vídeo enquanto a aprovação editorial está 0/48. O teste `integration_test/ead_ipex_talkback_manual_test.dart` mantém a mídia autorizada aberta por sete minutos exclusivamente na variante debug QA isolada, para observação humana. Falha imediatamente em release ou pacote sem `DYNAMIC_QA_ISOLATED_PACKAGE`.

## Roteiro mínimo

1. Operador com o Samsung em mãos confirma a janela de sete minutos. Não iniciar esse runner sem a pessoa presente; ele instala um APK de teste temporário.
2. A partir de `cartilhas_app`, executar `flutter test --no-pub integration_test/ead_ipex_talkback_manual_test.dart -d <ID_DO_SAMSUNG> --dart-define-from-file=D:/AI-Shared/test-results/tutor-tds/issue308-transition-20261020/samsung-qa-defines.json --reporter expanded`. Usar o Flutter 3.44.9 validado no LARGeo e registrar o hash do APK de teste. Esperar `IPEX_QA_TALKBACK_READY` antes da avaliação.
3. A pessoa ativa TalkBack pelas configurações normais do Android, navega por título, player, botão de legendas e texto externo. Para cada controle, confirma foco, nome anunciado, estado anunciado e acionamento por gesto de toque duplo. Alterna Mostrar/Ocultar e confirma que o estado e a legenda são percebidos. Testa pausa/retomada nativas com TalkBack sem perder foco. Registra **PASS/FAIL por item e falas concretas ou falhas**; a árvore UI e `accessibility_enabled=1` são apenas evidência técnica, não atestação humana.
4. A pessoa desliga TalkBack se era essa a configuração inicial. Ao terminar o runner, reinstalar o APK QA exato `issue309-6f01ee4-qa-debug.apk` e conferir seu SHA-256 local e no `base.apk`: `2085B5844270E737073E1004D0238921FF9B97998F069522BDC1F79BF8339F7D`.

Estado: **PENDING_HUMAN_TALKBACK**. Se o serviço não anunciar ou não acionar um controle, preservar o texto do anúncio, foco/árvore sanitizada e passo de reprodução; classificar FAIL específico antes de alterar o player. Não inferir PASS por `uiautomator dump`, `aria-pressed` ou serviço habilitado.
