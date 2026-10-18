# Issue #243 — checkpoint local de texto do percurso

[Issue #243](https://github.com/rafaloct/tutor-tds-platform/issues/243),
TASK_ID `CODEX-L4-UX-20261018`, BASE_SHA
`18fd9b97f825badc5cd7bc481f35e07a4687b989`.

OBSERVED: baseline Android35 registra título truncado e plurais incorretos.
IMPLEMENTED: AppBar “Percurso”; singular somente para 1 seção/item/aula,
plural para 0 e 2. Contagens, AppTheme azul/Poppins e política offline preservados.
DECISION: somente edição/commit local; MERGE_ALLOWED=NO.

| Recorte / memória compacta | Evidência local | Gate restante |
| --- | --- | --- |
| Título e contagens pt-BR | 48 cenários widget adicionados: 4 currículos (vazio, seção vazia, 1 e 2 itens) × 360/390/450 px × escala 1.0/1.5 × AppTheme claro/escuro; Poppins, botão Voltar, truncamento e exceções | Flutter/Dart ausentes; testes e analyze NÃO executados |
| Baseline QA preservada | SHA256 e tamanho dos 8 artefatos conferidos por Python: PASS; `git diff --check`: PASS | Comparação visual da candidata pendente |

TARGET: validar a candidata no desktop com Flutter 3.44.9 conferido. No junction
ASCII autorizado que aponte para um checkout deste commit, executar em
`cartilhas_app` (PowerShell):

```powershell
$flutter = 'C:/Users/Usuario/flutter-3.44.9/bin/flutter.bat'
& $flutter --version
& 'C:/Users/Usuario/flutter-3.44.9/bin/dart.bat' format --output=none --set-exit-if-changed lib/features/ead_catalog/learning_path/ead_learning_path_screen.dart test/ead_learning_path_screen_test.dart
& $flutter test --no-pub test/ead_learning_path_screen_test.dart test/ead_learning_path_live_refresh_test.dart
& $flutter analyze --no-pub lib/features/ead_catalog/learning_path/ead_learning_path_screen.dart test/ead_learning_path_screen_test.dart
& $flutter test --no-pub --update-goldens test/ead_learning_path_golden_test.dart
# Revisar o diff PNG antes de aceitar a nova referência.
& $flutter test --no-pub test/ead_learning_path_golden_test.dart
```

UNKNOWN/BLOCKED: renderização/overflow ainda não comprovados em runtime.
O golden versionado é anterior à correção e precisará de atualização/revisão;
nesta VM nenhuma captura nova foi gerada. O golden é fixture sintética,
não screenshot Android. Reason: SDK ausente. Exact human action: coordenador
executar os comandos no desktop e revisar comparação antes de publicar.
What remains unblocked: revisão do diff e do commit local. Rollback: reverter
somente o commit desta issue. Sem promoção de prontidão de produção.


## Validação posterior no DESKTOP-8T5DRBS — 18/10/2026

**TESTED-FLUTTER, não TESTED-ANDROID da alteração #243.**
O commit original Codex `3131913e02e0596e5e9f4da5af10f4582f1ab1d5` foi transferido
da VM para o desktop como *Git bundle*; SHA256 do bundle
`8b8d70b7d984e1d5c136aeb2f16878c736e6dc6cf723d32a73f5dbbb9b850ee7`
PASS, e o SHA Git original foi preservado integralmente.

- Flutter **3.44.9**: `flutter pub get --offline` PASS.
- `flutter analyze --no-pub` da tela e testes alterados: **PASS, zero issues**.
- `flutter test --no-pub test/ead_learning_path_screen_test.dart`:
  **51/51 PASS**, incluindo os 48 cenários de tema/fonte/largura.
- Regressão envolvendo 7 arquivos de tela/currículo/catálogo:
  **75/75 PASS**, código de saída 0, incluindo leitura e atualização de quiz.
- `dart format --output=none --set-exit-if-changed`:
  PASS após formatação de teste.
- Golden anterior apresentou diferença visual de **0,53% / 2.020 pixels**,
  como esperado pela troca do título e da pluralização.
  O golden foi regenerado com `AppTheme.light()` e Poppins, revisado visualmente
  e seu teste específico passou. SHA256 do novo PNG:
  `4111BD2530085261A368FD20EAE37701C3B0E87FD0F71C94D750EF81878AF6E0`.
- Observado na imagem nova: AppBar apresenta **“Percurso”** inteiro;
  quadro “2 seções · 3 itens de aula · 2 aulas em seções de vídeo”,
  subtítulos “1 item” e “2 itens”. Azul institucional preservado.
- **Limitação da imagem golden:** ícones podem parecer quadrados pelo
  ambiente de testes/fontes; isso não demonstra falha do APK.
  A imagem foi produzida com fixture sintética, e não é captura do
  novo build instalado em emulador.

**Resultado para a Issue #243:** código e regressões Flutter aprovados
tecnicamente; continuar em draft até QA Android e revisão de integração.
Não usar esta aprovação isolada para emitir novo AAB de produção.
`MERGE_ALLOWED=NO; PRODUCTION_ALLOWED=NO`.
