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
regressão API completa. Isso não comprova isolamento de conversas no Chatwoot
real.

Pendências: configurar chave de homologação, publicar somente em staging,
validar login/logout/troca de conta no SDK e WebView, ticket/status e
notificações. Não habilitar a flag sem esses testes.
