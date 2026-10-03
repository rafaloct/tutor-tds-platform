enum SupportTopic {
  appHelp,
  courseQuestion,
  attendanceCertificate,
  mentorshipInterest,
  dataPrivacy,
  unsure,
}

extension SupportTopicCopy on SupportTopic {
  String get label => switch (this) {
    SupportTopic.appHelp => 'Ajuda com o aplicativo',
    SupportTopic.courseQuestion => 'Dúvida sobre o curso',
    SupportTopic.attendanceCertificate => 'Frequência/certificado',
    SupportTopic.mentorshipInterest => 'Interesse em mentoria',
    SupportTopic.dataPrivacy => 'Dados/conta/privacidade',
    SupportTopic.unsure => 'Ainda não sei',
  };

  String get help => switch (this) {
    SupportTopic.appHelp =>
      'Descreva onde travou ou o que esperava encontrar. Nenhum diagnóstico extra é coletado.',
    SupportTopic.courseQuestion =>
      'Escolha o contexto correto e escreva sua dúvida sobre conteúdo ou atividade.',
    SupportTopic.attendanceCertificate =>
      'Escolha o contexto correto e descreva a pendência. Esta demonstração não altera frequência nem certificado.',
    SupportTopic.mentorshipInterest =>
      'Conte brevemente seu interesse. A demonstração não cria vaga, caso ou elegibilidade.',
    SupportTopic.dataPrivacy =>
      'Explique o tipo de pedido. Não informe CPF, senha, token ou dados de terceiros.',
    SupportTopic.unsure =>
      'Escreva, se quiser, o que precisa. A triagem é apenas demonstrativa.',
  };

  bool get requiresContext =>
      this == SupportTopic.courseQuestion ||
      this == SupportTopic.attendanceCertificate;
}

class SupportContextOption {
  const SupportContextOption({
    required this.id,
    required this.cohortLabel,
    required this.courseLabel,
  });

  final String id;
  final String cohortLabel;
  final String courseLabel;

  String get summary => '$cohortLabel • $courseLabel';
}

class SupportSession {
  const SupportSession({
    required this.sessionId,
    required this.ownerId,
    required this.displayLabel,
    this.contexts = const [],
    this.preselectedContextId,
    this.isVisitor = false,
    this.optionalConsentGranted = false,
  });

  final String sessionId;
  final String ownerId;
  final String displayLabel;
  final List<SupportContextOption> contexts;
  final String? preselectedContextId;
  final bool isVisitor;
  final bool optionalConsentGranted;
}

enum SupportViewState {
  loading,
  ready,
  draft,
  sending,
  simulatedConfirmation,
  error,
  unavailable,
}

class SupportCommand {
  const SupportCommand({
    required this.commandId,
    required this.sessionId,
    required this.ownerId,
    required this.topic,
    required this.message,
    this.contextId,
  });

  final String commandId;
  final String sessionId;
  final String ownerId;
  final SupportTopic topic;
  final String message;
  final String? contextId;
}

class SupportReceipt {
  const SupportReceipt({required this.commandId});

  final String commandId;
}

class SupportUnavailableException implements Exception {
  const SupportUnavailableException();
}

class SupportSendException implements Exception {
  const SupportSendException();
}
