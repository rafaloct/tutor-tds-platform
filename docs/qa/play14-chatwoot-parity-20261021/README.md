# Tutor TDS 1.4.2+15 — paridade Chatwoot/FAQ com v1.4.1

## Fonte e escopo

- Base: draft PR #317, `0cda01731b19dce479700770d51d262e94c7b7ab`, versão candidata `1.4.2+15`.
- Referência: tag Git `v1.4.1`, objeto commit `8eccbbbf9041bf229314c18922c25a71cd7ed861`, que declara `1.4.1+14`. A igualdade do versionamento com a Play Console não comprova, por si, que o AAB publicado é binariamente igual à tag.
- Motivo: a linha publicada tem implementação dinâmica de Chatwoot e FAQ; a linha integrada da #317 continha ainda o widget estático. A comparação Git mostrou 25 commits exclusivos da tag e 78 exclusivos do candidato.
- Worktree isolada no LARGeo: `D:/AI-Shared/work/tds-issue197-play14-support-parity-20261021`.
- Importação **seletiva** das implementações e testes de Chatwoot/FAQ da tag `v1.4.1`: configuração pública do widget via API; validação de URL/token; navegação de ajuda/FAQ; ciclo de vida do widget, isolamento de sessão, reabertura e logout; host de Chatwoot web e Android. Não houve merge automático das duas linhas.
- Componentes EAD do candidato, inclusive entradas em `home_screen.dart` e `welcome_screen.dart`, **não foram substituídos**. Texto de versão visível em `settings_screen.dart` alinhado ao candidato `1.4.2`.

## Evidência local da fonte restaurada

- `D:/flutter-3.44.9/bin/flutter.bat pub get --enforce-lockfile`: **PASS**, arquivo `pubspec.lock` não alterado.
- `flutter analyze --no-pub`: **PASS**, 0 problemas; Flutter **3.44.9**.
- Flutter focal, `flutter test --no-pub --concurrency 1 --reporter expanded`: **103/103 PASS**. Arquivos: `chatwoot_config_repository_test`, `chatwoot_host_html_test`, `chatwoot_screen_config_test`, `chatwoot_support_faq_test`, `chatwoot_web_lifecycle_test`, `support_controller_test`, `support_entry_test`, `support_identity_test`, `ead_home_entry_test` e `ead_welcome_entry_test`.
- API focal, `uv run --locked --extra test python -m pytest -q tests/test_support.py`: **PASS**, execução sintética local sem alteração em produção.
- Verificação GET anônimo de `/tutor-api/support/config` na API de produção: HTTP **200**; exatamente `base_url` e `website_token`; `Cache-Control: no-store`; URL pública apontando para `chat.ipexdesenvolvimento.cloud`. Nenhum valor de token foi registrado.
- `git diff --check`: sem erro. Revisão EAD: `home_screen.dart` e `welcome_screen.dart` idênticas à base #317.
- Ferramentas de QA disponíveis no LARGeo: emulador Android e Samsung SM-T835 em ADB; **Xiaomi ainda não conectado**.

## Limites e release gates

- A fonte de suporte recuperada está validada em teste Flutter/API, mas a reprodução física do Chatwoot/FAQ na nova integração e o teste Xiaomi pre-AAB ainda não foram realizados.
- Não mudar os estados do arquivo `cartilhas_app/release/release_status.json` automaticamente: `release_build_allowed=false`, `source_verification.status=pending`, `pre_aab_xiaomi_smoke=pending`, artefato antigo `superseded`. Estes valores continuam representando gates válidos.
- Atualização produtiva do backend/WordPress, release Android/AAB, merge dos PRs, assinatura de upload e envio Google Play não realizados nesta implementação.
- A aula editorial 1420, a aprovação pedagógica e a publicação progressiva de vídeos são gates independentes.
- Antes do build final, conferir a proveniência da tag v1.4.1 contra o AAB 14 efetivamente distribuído, o inventário `versionCode` de todos os tracks da Play e a identidade do certificado de upload no ambiente custodiante.

## Rollback

Descartar este draft PR e sua branch; nenhuma migração, dado acadêmico ou escrita produtiva foi aplicada.
