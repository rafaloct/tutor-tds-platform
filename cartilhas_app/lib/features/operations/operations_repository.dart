import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/data/auth_repository.dart';
import 'operations_gateway.dart';
import 'operations_models.dart';

class OperationsRepository implements OperationsGateway {
  OperationsRepository({
    required this.apiUrl,
    required this.auth,
    required this.owner,
    required this.generation,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String apiUrl, owner;
  final AuthRepository auth;
  final int generation;
  final http.Client _client;
  final Map<String, String> _proofs = {};
  @override
  bool get isSimulation => false;
  String get sessionKey => '$apiUrl|$owner|$generation';
  void close() {
    _proofs.clear();
    _client.close();
  }

  Future<void> _check(String key) async {
    if (key != sessionKey ||
        generation != auth.sessionGeneration ||
        await auth.localUserId() != owner) {
      _proofs.clear();
      throw const OperationFailure(OperationFailureKind.denied);
    }
  }

  Future<Map<String, dynamic>> _request(
    String key,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    await _check(key);
    try {
      final uri = Uri.parse(
        '${apiUrl.replaceFirst(RegExp(r'/+$'), '')}/operations$path',
      );
      final response = await auth.authorized((token) async {
        await _check(key);
        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        return (body == null
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 15));
      });
      await _check(key);
      if (response.statusCode != 200) {
        throw OperationFailure(switch (response.statusCode) {
          401 || 403 => OperationFailureKind.denied,
          409 => OperationFailureKind.conflict,
          422 => OperationFailureKind.invalid,
          _ => OperationFailureKind.unavailable,
        });
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on OperationFailure {
      rethrow;
    } catch (_) {
      throw const OperationFailure(OperationFailureKind.unavailable);
    }
  }

  OperationScope _scope(Map<String, dynamic> data) => OperationScope(
    institutionId: data['institution_id'] as String,
    programId: data['program_id'] as String,
    courseId: data['course_id'] as String,
    classId: data['class_id'] as String,
    versionId: data['version_id'] as String,
    label: data['label'] as String,
  );
  OperationSnapshot _snapshot(Map<String, dynamic> data) => OperationSnapshot(
    person: OperationPerson(
      data['person']['id'] as String,
      data['person']['name'] as String,
    ),
    scope: _scope(data['scope'] as Map<String, dynamic>),
    revision: data['revision'] as int,
    enrolled: data['enrolled'] as bool,
    assigned: data['assigned'] as bool,
    baselineLinked: data['baseline_linked'] as bool?,
    history: (data['history'] as List)
        .map(
          (entry) => OperationHistory(
            action: entry['action'] as String,
            reason: entry['reason'] as String,
            actorLabel: entry['actor_label'] as String,
            occurredAt: DateTime.parse(entry['occurred_at'] as String),
          ),
        )
        .toList(),
  );

  @override
  Future<List<OperationScope>> scopes(String sessionKey) async {
    final data = await _request(sessionKey, '/scopes');
    return (data['scopes'] as List)
        .map((entry) => _scope(entry as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<OperationPerson>> search(
    String sessionKey,
    OperationScope scope,
    String query,
  ) async {
    final data = await _request(
      sessionKey,
      '/${Uri.encodeComponent(scope.classId)}/search',
      {'query': query},
    );
    return (data['people'] as List).map((entry) {
      final id = entry['id'] as String;
      _proofs['${scope.programId}/$id'] = entry['identity_proof'] as String;
      return OperationPerson(id, entry['name'] as String);
    }).toList();
  }

  @override
  Future<OperationSnapshot> inspect(
    String sessionKey,
    OperationScope scope,
    String personId,
  ) async => _snapshot(
    await _request(
      sessionKey,
      '/${Uri.encodeComponent(scope.classId)}/inspect',
      {
        'person_id': personId,
        'identity_proof': _proofs['${scope.programId}/$personId'],
      },
    ),
  );
  @override
  Future<OperationSnapshot> execute(OperationCommand command) async =>
      _snapshot(
        await _request(
          command.sessionKey,
          '/${Uri.encodeComponent(command.scope.classId)}/commands',
          {
            'id': command.id,
            'action': command.action.name,
            'reason': command.reason,
            'institution_id': command.scope.institutionId,
            'program_id': command.scope.programId,
            'course_id': command.scope.courseId,
            'version_id': command.scope.versionId,
            'person_id': command.personId,
            'expected_revision': command.expectedRevision,
            'identity_proof':
                _proofs['${command.scope.programId}/${command.personId}'],
            if (command.registration case final registration?)
              'registration': {
                'name': registration.name,
                'cpf': registration.cpf,
                'phone': registration.phone,
                'password': registration.password,
              },
          },
        ),
      );
}
