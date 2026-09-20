import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

abstract interface class AuthTokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'tutor_tds:auth_tokens:v1';
  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    try {
      final value = await _storage.read(key: _key);
      if (value == null || value.isEmpty) return null;
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        await clear();
        return null;
      }
      return AuthTokens.fromJson(decoded);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
