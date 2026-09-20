class AppConfig {
  const AppConfig._();

  /// Endereço público e estável do gateway. Em produção, o app nunca recebe
  /// a credencial usada para acessar o AnythingLLM ou o provedor do modelo.
  static const tutorGatewayUrl = String.fromEnvironment('TUTOR_GATEWAY_URL');

  /// API transacional do Tutor TDS. Enquanto não estiver configurada, o
  /// catálogo continua vindo integralmente dos assets do aplicativo.
  static const tutorApiUrl = String.fromEnvironment('TUTOR_API_URL');

  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://cartilhas.ipexdesenvolvimento.cloud/privacy.html',
  );

  static const accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
    defaultValue:
        'https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html',
  );

  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tutortds_cartilhas';
}
