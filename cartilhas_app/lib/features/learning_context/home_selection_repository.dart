import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class HomeSelectionRepository {
  Future<String?> read(String ownerId);
  Future<void> write(String ownerId, String cohortId);
}

class HomeSelectionException implements Exception {
  const HomeSelectionException();
}

class LocalHomeSelectionRepository implements HomeSelectionRepository {
  LocalHomeSelectionRepository(String apiUrl)
    : _environment = apiUrl.replaceFirst(RegExp(r'/+$'), '');
  final String _environment;
  String _key(String owner) =>
      'learning_home:selection:${sha256.convert(utf8.encode(jsonEncode([_environment, owner])))}';

  @override
  Future<String?> read(String ownerId) async =>
      (await SharedPreferences.getInstance()).getString(_key(ownerId));

  @override
  Future<void> write(String ownerId, String cohortId) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      _key(ownerId),
      cohortId,
    )) {
      throw const HomeSelectionException();
    }
  }
}

class FakeHomeSelectionRepository implements HomeSelectionRepository {
  final Map<String, String> selections = {};
  @override
  Future<String?> read(String ownerId) async => selections[ownerId];
  @override
  Future<void> write(String ownerId, String cohortId) async {
    selections[ownerId] = cohortId;
  }
}
