import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
import 'auth_repository.dart';
import '../models/external_auth_result.dart';

class ExternalIdentityService {
  ExternalIdentityService({required AuthRepository tutorAuth})
    : _tutorAuth = tutorAuth;

  final AuthRepository _tutorAuth;

  bool get isConfigured => AppConfig.externalAuthConfigured;

  SupabaseClient get _client {
    if (!isConfigured) {
      throw const AuthException(
        'Google e link por e-mail ainda não estão configurados.',
      );
    }
    return Supabase.instance.client;
  }

  Stream<void> get sessionChanges => isConfigured
      ? _client.auth.onAuthStateChange.map((_) {})
      : const Stream<void>.empty();

  Future<bool> signInWithGoogle() async {
    if (!isConfigured) {
      throw const AuthException(
        'Google ainda não está disponível neste ambiente.',
      );
    }
    await _tutorAuth.logout();
    await _client.auth.signOut();
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.supabaseAuthRedirectUrl,
    );
  }

  Future<void> requestMagicLink(String email) async {
    if (!isConfigured) {
      throw const AuthException(
        'Link por e-mail ainda não está disponível neste ambiente.',
      );
    }
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      throw const AuthException('Informe um e-mail válido.');
    }
    await _tutorAuth.logout();
    await _client.auth.signOut();
    await _client.auth.signInWithOtp(
      email: normalized,
      emailRedirectTo: AppConfig.supabaseAuthRedirectUrl,
      shouldCreateUser: true,
    );
  }

  Future<ExternalAuthResult?> exchangeCurrentSession() async {
    if (!isConfigured) return null;
    final session = _client.auth.currentSession;
    if (session == null || session.accessToken.isEmpty) return null;
    return _tutorAuth.exchangeExternal(
      externalAccessToken: session.accessToken,
    );
  }

  Future<void> signOut() async {
    if (isConfigured) {
      await _client.auth.signOut();
    }
    await _tutorAuth.logout();
  }
}
