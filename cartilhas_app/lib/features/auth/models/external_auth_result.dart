import 'auth_session.dart';

enum ExternalAuthStatus {
  authenticated,
  profileCompletionRequired,
  existingAccountLinkRequired,
}

class ExternalAuthResult {
  const ExternalAuthResult({
    required this.status,
    this.session,
    this.onboardingToken,
    this.verifiedEmail,
  });

  final ExternalAuthStatus status;
  final AuthSession? session;
  final String? onboardingToken;
  final String? verifiedEmail;

  bool get isAuthenticated =>
      status == ExternalAuthStatus.authenticated && session != null;

  factory ExternalAuthResult.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'authenticated' => ExternalAuthStatus.authenticated,
      'profile_completion_required' =>
        ExternalAuthStatus.profileCompletionRequired,
      'existing_account_link_required' =>
        ExternalAuthStatus.existingAccountLinkRequired,
      _ => throw const FormatException(
        'Estado de autenticação externa inválido.',
      ),
    };
    final rawSession = json['session'];
    final session = rawSession == null
        ? null
        : rawSession is Map<String, dynamic>
        ? AuthSession.fromJson(rawSession)
        : throw const FormatException('Sessão externa inválida.');
    final onboarding = json['onboarding_token'];
    final email = json['verified_email'];
    if (onboarding != null && onboarding is! String) {
      throw const FormatException('Onboarding externo inválido.');
    }
    if (email != null && email is! String) {
      throw const FormatException('E-mail externo inválido.');
    }
    if (status == ExternalAuthStatus.authenticated && session == null) {
      throw const FormatException('Sessão Tutor ausente.');
    }
    if (status != ExternalAuthStatus.authenticated &&
        (onboarding is! String || onboarding.isEmpty)) {
      throw const FormatException('Token de onboarding ausente.');
    }
    return ExternalAuthResult(
      status: status,
      session: session,
      onboardingToken: onboarding as String?,
      verifiedEmail: email as String?,
    );
  }
}
