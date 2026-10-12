import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps an ambiguous prepare command until the API confirms its receipt.
abstract interface class PendingClassPrepareStore {
  Future<String?> read(String scope);
  Future<void> write(String scope, String body);
  Future<void> clear(String scope);
}

class SecurePendingClassPrepareStore implements PendingClassPrepareStore {
  SecurePendingClassPrepareStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String scope) =>
      'tutor_tds:pending_class_prepare:v1:${sha256.convert(utf8.encode(scope))}';

  @override
  Future<String?> read(String scope) => _storage.read(key: _key(scope));

  @override
  Future<void> write(String scope, String body) =>
      _storage.write(key: _key(scope), value: body);

  @override
  Future<void> clear(String scope) => _storage.delete(key: _key(scope));
}
