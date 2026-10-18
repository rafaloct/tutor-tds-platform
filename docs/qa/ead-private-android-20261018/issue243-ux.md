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
