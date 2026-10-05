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
  int _sessionGeneration = 0;
  Future<void> _tokenOperations = Future<void>.value();

  void _checkGeneration(int generation) {
    if (generation != _sessionGeneration) {
      throw const AuthException(
        'A conta mudou. Entre novamente para continuar.',
      );
    }
  }

  // Serialize secure-storage mutations. A logout queued during a write must
  // finish after it; stale responses must never clear or overwrite a new account.
  Future<void> _mutateTokens(Future<void> Function() operation) {
    final result = _tokenOperations.then((_) => operation());
    _tokenOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _writeSession(AuthSession session, int generation) async {
    await _mutateTokens(() async {
      _checkGeneration(generation);
      await _tokenStore.write(session.tokens);
    });
    _checkGeneration(generation);
  }

  bool get isConfigured => apiUrl.trim().isNotEmpty;
  int get sessionGeneration => _sessionGeneration;

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
    required String activationCode,
  }) => _authenticate(
    path: '/auth/register',
    // The activation code is deliberately request-only. AuthSession and the
    // secure token store contain only server-issued session tokens.
    body: {
      'name': name,
      'cpf': cpf,
      'phone': phone,
      'password': password,
      'activation_token': activationCode,
    },
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
          await logout();
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
      await logout();
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
    final generation = _sessionGeneration;
    var tokens = await _readTokens();
    _checkGeneration(generation);
    if (tokens == null) {
      throw const AuthException('Entre na sua conta para continuar.');
    }
    var response = await request(tokens.accessToken);
    _checkGeneration(generation);
    if (response.statusCode != 401) return response;

    final session = await refresh();
    _checkGeneration(generation);
    response = await request(session.tokens.accessToken);
    _checkGeneration(generation);
    return response;
  }

  Future<void> logout() {
    _sessionGeneration++;
    _refreshInFlight = null;
    return _mutateTokens(_tokenStore.clear);
  }

  /// Fetches a server-signed support identity; never caches or signs locally.
  Future<Map<String, String>> supportIdentity() async {
    const failure = AuthException(
      'Não foi possível identificar sua conta no suporte.',
    );
    try {
      final owner = await localUserId();
      if (owner == null) throw failure;
      Future<void> checkOwner() async {
        if (await localUserId() != owner) throw failure;
      }

      final response = await authorized((token) async {
        await checkOwner();
        return _client
            .get(
              _uri('/support/identity'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 12));
      });
      await checkOwner();
      if (response.statusCode != 200) throw failure;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw failure;
      final identifier = data['identifier'];
      final signature = data['identifier_hash'];
      if (identifier is! String ||
          identifier.isEmpty ||
          signature is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(signature)) {
        throw failure;
      }
      return {'identifier': identifier, 'identifier_hash': signature};
    } on Object {
      throw failure;
    }
  }

  Future<AuthSession> _authenticate({
    required String path,
    required Map<String, String> body,
    required int expectedStatus,
  }) async {
    _requireConfigured();
    final generation = ++_sessionGeneration;
    _refreshInFlight = null;
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      _checkGeneration(generation);
      if (response.statusCode != expectedStatus) {
        throw AuthException(_messageFor(response.statusCode));
      }
      final session = _decodeSession(response.body);
      await _writeSession(session, generation);
      return session;
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException('Não foi possível conectar à conta Tutor TDS.');
    }
  }

  Future<AuthSession> _refresh() async {
    _requireConfigured();
    final generation = _sessionGeneration;
    final tokens = await _readTokens();
    _checkGeneration(generation);
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
      _checkGeneration(generation);
      if (response.statusCode != 200) {
        await logout();
        throw const AuthException('Sua sessão expirou. Entre novamente.');
      }
      final session = _decodeSession(response.body);
      await _writeSession(session, generation);
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
      await _tokenOperations;
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
    if (statusCode == 403) {
      return 'Não foi possível validar o código de ativação. Solicite um novo código à instituição.';
    }
    if (statusCode == 429) {
      return 'Muitas tentativas. Aguarde alguns minutos antes de tentar novamente.';
    }
    if (statusCode == 409) return 'Já existe uma conta para este CPF.';
    if (statusCode == 422) {
      return 'Confira os dados informados e tente novamente.';
    }
    return 'Não foi possível acessar sua conta agora.';
  }

  void dispose() => _client.close();
}
