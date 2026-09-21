# Suporte: identidade autenticada — implementação local, não ativada

Reutiliza AuthRepository, API atual e widget Chatwoot. Sem migração de banco,
novo cadastro, bot ou alteração de produção.

- GET `/support/identity`: autenticação existente; identidade derivada somente
  do sujeito autenticado, namespace explícito por ambiente e HMAC SHA256.
- Configuração servidor: `CHATWOOT_IDENTITY_SECRET` e
  `CHATWOOT_IDENTITY_NAMESPACE`. Ausência retorna 503. Segredo nunca é enviado
  ao Flutter; resposta usa `no-store`.
- Flutter consulta sem cache e envia `identifier_hash` somente quando a flag
  está habilitada. Falha não recorre ao identificador legado do aparelho.
- Codificação JSON segura protege nomes, acentos, quebras de linha e tags HTML.
- Web cancela abertura pendente no fechamento e atualiza a identidade ao reabrir.

Evidências locais: testes API e Flutter direcionados, análise Dart sem erros e
regressão API completa. Em 21/09/2026, staging foi configurado com namespace
`tds-staging`, segredo fora do repositório e `SIGNED_SUPPORT_IDENTITY=true`;
o smoke autenticado retornou hash hexadecimal de 64 caracteres sem expor o
segredo. O APK de staging foi compilado em
`cartilhas_app/build/app/outputs/flutter-apk/app-debug.apk` (SHA-256
`8CECCDF33D42DBB60979ECA761AA680F92598CF5999508E2012CA9706563B349`). Isso
ainda não comprova isolamento de conversas no Chatwoot real nem teste físico.

Pendências: validar login/logout/troca de conta no SDK e WebView, ticket/status
e notificações no dispositivo Xiaomi. Produção permanece sem a flag.
