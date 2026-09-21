# Suporte: identidade autenticada — implementação local, não ativada

Reutiliza AuthRepository, API atual e widget Chatwoot. Sem migração de banco,
novo cadastro, bot ou alteração de produção.

- GET `/support/identity`: autenticação existente; identidade derivada somente
  do sujeito autenticado, namespace explícito por ambiente e HMAC SHA256.
- Configuração servidor: `CHATWOOT_IDENTITY_SECRET` (segredo da caixa Chatwoot)
  e `CHATWOOT_IDENTITY_NAMESPACE` (estável, distinto por ambiente). Ausência
  retorna 503. Segredo nunca enviado ao Flutter; resposta no-store.
- Flutter: `AuthRepository.supportIdentity()` valida sessão antes/depois de
  HTTP/refresh; sem cache. Tela envia identifier_hash quando
  `SIGNED_SUPPORT_IDENTITY=true`. Padrão false até homologação.
- Falha no caminho assinado não recorre ao identificador legado do aparelho.
- Codificação JSON segura para JavaScript/HTML preserva aspas, acentos e
  quebras de linha, bloqueando encerramento de script por texto de perfil.
- Web: abertura pendente cancelada no fechamento; callback usa pedido mais
  recente; reabertura atualiza identidade; fechamento chama reset do SDK.

Evidências locais: 1 teste API (login real em SQLite, dois usuários,
namespace, assinatura, ausência de configuração); 20 testes Flutter de
autenticação/identidade; 1 teste de codificação. Análise direcionada sem erros.
Isso NÃO comprova isolamento de conversas no serviço Chatwoot.

Pendências antes de ativar: configurar caixa de homologação/assinatura sem
quebrar widget publicado; validar reset assíncrono, cookies e reabertura no
SDK real; testar login/logout/troca de conta com widget aberto e durante carga;
validar isolamento da WebView móvel, consentimento e nomes do perfil atual;
tratar falha de carga do SDK; ticket/contexto/status e notificações ainda abertos.
Não habilitar a flag nem declarar concluída a Fatia E com análise estática.

Referência: https://www.chatwoot.com/hc/user-guide/articles/1677587234-how-to-send-additional-user-information-to-chatwoot-using-sdk
