class AppConfig {
  const AppConfig._();

  /// Endereço público e estável do gateway. Em produção, o app nunca recebe
  /// a credencial usada para acessar o AnythingLLM ou o provedor do modelo.
  static const tutorGatewayUrl = String.fromEnvironment('TUTOR_GATEWAY_URL');

  /// API transacional do Tutor TDS. Enquanto não estiver configurada, o
  /// catálogo continua vindo integralmente dos assets do aplicativo.
  static const tutorApiUrl = String.fromEnvironment('TUTOR_API_URL');

  /// Enable with the matching API flag only after the Context Core staging gate.
  static const learningContextEnabled = bool.fromEnvironment(
    'LEARNING_CONTEXT_ENABLED',
  );
  static const durableLearningOutboxEnabled = bool.fromEnvironment(
    'DURABLE_LEARNING_OUTBOX_ENABLED',
  );
  static const journeyTraceabilityEnabled = bool.fromEnvironment(
    'JOURNEY_TRACEABILITY_ENABLED',
  );
  // Enable only after the inbox signature and account-switch QA are configured.
  static const signedSupportIdentity = bool.fromEnvironment(
    'SIGNED_SUPPORT_IDENTITY',
  );

  /// Enables the remote course catalog via [tutorApiUrl].
  /// Defaults to [false] (safe). Does NOT activate login, classrooms,
  /// journey traceability, or the durable outbox.
  ///
  /// When [false], the app only shows the 9 bundled local courses.
  /// When [true] and [tutorApiUrl] is set, the app fetches the published
  /// catalog from the API; on failure it falls back to local cache and
  /// then to bundled assets — the screen is never left empty.
  static const remoteCatalogEnabled = bool.fromEnvironment(
    'REMOTE_CATALOG_ENABLED',
    defaultValue: false,
  );

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
