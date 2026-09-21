import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import 'auth_token_store.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.allowOfflineFallback = false});

  final String message;
  final bool allowOfflineFallback;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    required this.apiUrl,
    http.Client? client,
    AuthTokenStore? tokenStore,
  }) : _client = client ?? http.Client(),
       _tokenStore = tokenStore ?? SecureAuthTokenStore();

  final String apiUrl;
  final http.Client _client;
  final AuthTokenStore _tokenStore;
  Future<AuthSession>? _refreshInFlight;

  bool get isConfigured => apiUrl.trim().isNotEmpty;

  Future<bool> hasSession() async => (await _readTokens()) != null;

  /// Unverified subject used only to select previously API-validated local data.
  /// This is not authentication or authorization and grants no roles.
  Future<String?> localUserId() async {
    final tokens = await _readTokens();
    if (tokens == null) return null;
    try {
      final segments = tokens.accessToken.split('.');
      if (segments.length != 3 || segments.any((part) => part.isEmpty)) {
        return null;
      }
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      final subject = payload['sub'];
      return subject is String && subject.trim().isNotEmpty ? subject : null;
    } on FormatException {
      return null;
    }
  }

  Future<AuthSession> register({
    required String name,
    required String cpf,
    required String phone,
    required String password,
  }) => _authenticate(
    path: '/auth/register',
    body: {'name': name, 'cpf': cpf, 'phone': phone, 'password': password},
    expectedStatus: 201,
  );

  Future<AuthSession> login({required String cpf, required String password}) =>
      _authenticate(
        path: '/auth/login',
        body: {'cpf': cpf, 'password': password},
        expectedStatus: 200,
      );

  Future<AuthUser> currentUser() async {
    try {
      final response = await authorized(
        (accessToken) => _offlineAwareRequest(
          () => _client
              .get(
                _uri('/auth/me'),
                headers: {'Authorization': 'Bearer $accessToken'},
              )
              .timeout(const Duration(seconds: 12)),
          'Não foi possível validar sua conta agora.',
        ),
      );
      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          await _tokenStore.clear();
        }
        throw const AuthException('Não foi possível validar sua conta.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Usuário inválido.');
      }
      return AuthUser.fromJson(decoded);
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException('Não foi possível validar sua conta agora.');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final response = await authorized(
        (accessToken) => _client
            .delete(
              _uri('/auth/me'),
              headers: {'Authorization': 'Bearer $accessToken'},
            )
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode != 204) {
        if (response.statusCode == 409) {
          throw const AuthException(
            'Esta conta possui vínculos de equipe. Solicite a exclusão ao suporte TDS.',
          );
        }
        throw const AuthException('Não foi possível excluir sua conta agora.');
      }
      await _tokenStore.clear();
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException('Não foi possível excluir sua conta agora.');
    }
  }

  Future<AuthSession> refresh() {
    final current = _refreshInFlight;
    if (current != null) return current;
    final operation = _refresh();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<http.Response> authorized(
    Future<http.Response> Function(String accessToken) request,
  ) async {
    _requireConfigured();
    var tokens = await _readTokens();
    if (tokens == null) {
      throw const AuthException('Entre na sua conta para continuar.');
    }
    var response = await request(tokens.accessToken);
    if (response.statusCode != 401) return response;

    final session = await refresh();
    response = await request(session.tokens.accessToken);
    return response;
  }

  Future<void> logout() => _tokenStore.clear();

  Future<AuthSession> _authenticate({
    required String path,
    required Map<String, String> body,
    required int expectedStatus,
  }) async {
    _requireConfigured();
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != expectedStatus) {
        throw AuthException(_messageFor(response.statusCode));
      }
      final session = _decodeSession(response.body);
      await _tokenStore.write(session.tokens);
      return session;
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException('Não foi possível conectar à conta Tutor TDS.');
    }
  }

  Future<AuthSession> _refresh() async {
    _requireConfigured();
    final tokens = await _readTokens();
    if (tokens == null) {
      throw const AuthException('Entre na sua conta para continuar.');
    }
    try {
      final response = await _offlineAwareRequest(
        () => _client
            .post(
              _uri('/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': tokens.refreshToken}),
            )
            .timeout(const Duration(seconds: 12)),
        'Não foi possível renovar sua sessão agora.',
      );
      if (response.statusCode != 200) {
        await _tokenStore.clear();
        throw const AuthException('Sua sessão expirou. Entre novamente.');
      }
      final session = _decodeSession(response.body);
      await _tokenStore.write(session.tokens);
      return session;
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException('Não foi possível renovar sua sessão agora.');
    }
  }

  AuthSession _decodeSession(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta de autenticação inválida.');
    }
    return AuthSession.fromJson(decoded);
  }

  Future<http.Response> _offlineAwareRequest(
    Future<http.Response> Function() request,
    String message,
  ) async {
    // Limit fallback classification to transport failures. Secure-storage and
    // response-decoding failures outside this call must remain fail-closed.
    try {
      return await request();
    } on TimeoutException {
      throw AuthException(message, allowOfflineFallback: true);
    } on http.ClientException {
      throw AuthException(message, allowOfflineFallback: true);
    }
  }

  Future<AuthTokens?> _readTokens() async {
    try {
      return await _tokenStore.read();
    } on Object {
      throw const AuthException('Não foi possível acessar sua sessão segura.');
    }
  }

  Uri _uri(String path) {
    final base = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    return Uri.parse('$base$path');
  }

  void _requireConfigured() {
    if (!isConfigured) {
      throw const AuthException(
        'A conta online ainda não está disponível neste aplicativo.',
      );
    }
  }

  String _messageFor(int statusCode) {
    if (statusCode == 401) return 'CPF ou senha inválidos.';
    if (statusCode == 409) return 'Já existe uma conta para este CPF.';
    if (statusCode == 422) {
      return 'Confira os dados informados e tente novamente.';
    }
    return 'Não foi possível acessar sua conta agora.';
  }

  void dispose() => _client.close();
}
