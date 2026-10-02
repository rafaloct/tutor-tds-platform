# CI Flutter: analyze + testes do `cartilhas_app` (Issue #15)

Workflow: `.github/workflows/flutter-app.yml`. Roda em PR/push que altere
`cartilhas_app/**` (push somente em `codex/onda-0-consolidacao`) e manualmente.

- SDK: Flutter 3.44.9 / Dart 3.12.2, mesmo SDK histórico validado no AGENTS.md,
  baixado do storage oficial e conferido pelo SHA-256 publicado em
  `releases_linux.json` antes do uso; a versão é verificada após a extração.
- Passos: `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test`.
- `permissions: contents: read`, `persist-credentials: false`, sem secrets,
  sem `--dart-define`, sem `config/production.json`.

Não executa: `integration_test/`, emulador ou aparelho físico, `flutter build`,
assinatura, AAB, Play, nem `tool/validate_production_config.dart` /
`tool/verify_release_readiness.dart` contra configuração real. Um check verde
aqui é evidência de regressão unitária/widget, **não** gate físico, aceite de
release ou alteração do freeze em `release_status.json`.

Linux (CI) complementa, não substitui, a execução histórica no Windows. Ao
trocar o SDK, atualizar `FLUTTER_VERSION` e `FLUTTER_ARCHIVE_SHA256` juntos.
