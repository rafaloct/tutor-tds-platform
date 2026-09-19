class AppConfig {
  const AppConfig._();

  /// Endereço público e estável do gateway. Em produção, o app nunca recebe
  /// a credencial usada para acessar o AnythingLLM ou o provedor do modelo.
  static const tutorGatewayUrl = String.fromEnvironment('TUTOR_GATEWAY_URL');

  static const analyticsWebhookUrl = String.fromEnvironment(
    'TDS_ANALYTICS_WEBHOOK_URL',
  );

  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tutortds_cartilhas';
}
