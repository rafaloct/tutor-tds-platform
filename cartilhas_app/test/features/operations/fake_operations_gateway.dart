import 'dart:async';
import 'package:cartilhas_app/features/operations/operations_gateway.dart';
import 'package:cartilhas_app/features/operations/operations_models.dart';

const scopeA = OperationScope(
  institutionId: 'synthetic-i',
  programId: 'synthetic-p',
  courseId: 'synthetic-c',
  classId: 'synthetic-a',
  versionId: 'v1',
  label: 'Programa teste / Curso / Turma A',
);
const scopeB = OperationScope(
  institutionId: 'synthetic-i',
  programId: 'synthetic-p',
  courseId: 'synthetic-c',
  classId: 'synthetic-b',
  versionId: 'v2',
  label: 'Programa teste / Curso / Turma B',
);

/// Only compiled by tests. No network, production bootstrap or persistence.
class FakeOperationsGateway implements OperationsGateway {
  @override
  bool get isSimulation => true;
  final people = <OperationPerson>[
    const OperationPerson('synthetic-person', 'Pessoa teste'),
  ];
  final records = <String, OperationSnapshot>{};
  final receipts = <String, (OperationCommand, OperationSnapshot)>{};
  final commands = <OperationCommand>[];
  bool denied = false;
  bool loseNextResponse = false;
  Completer<void>? pause;
  Completer<List<OperationPerson>>? searchResult;
  int mutations = 0;

  void _authorize(String session, OperationScope scope) {
    if (denied || session != 'actor-a' || ![scopeA, scopeB].contains(scope)) {
      throw const OperationFailure(OperationFailureKind.denied);
    }
  }

  @override
  Future<List<OperationScope>> scopes(String sessionKey) async {
    if (denied || sessionKey != 'actor-a') {
      throw const OperationFailure(OperationFailureKind.denied);
    }
    return [scopeA, scopeB];
  }

  @override
  Future<List<OperationPerson>> search(
    String sessionKey,
    OperationScope scope,
    String query,
  ) async {
    _authorize(sessionKey, scope);
    if (searchResult != null) return searchResult!.future;
    return people
        .where(
          (person) => person.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  @override
  Future<OperationSnapshot> inspect(
    String sessionKey,
    OperationScope scope,
    String personId,
  ) async {
    _authorize(sessionKey, scope);
    final person = people.firstWhere((person) => person.id == personId);
    return records['${scope.classId}/$personId'] ??
        OperationSnapshot(
          person: person,
          scope: scope,
          revision: 0,
          enrolled: false,
          assigned: false,
          baselineLinked: false,
          history: [],
        );
  }

  @override
  Future<OperationSnapshot> execute(OperationCommand command) async {
    commands.add(command);
    if (pause != null) await pause!.future;
    _authorize(command.sessionKey, command.scope);
    final previous = receipts[command.id];
    if (previous != null) {
      if (!identical(previous.$1, command)) {
        throw const OperationFailure(OperationFailureKind.conflict);
      }
      return previous.$2;
    }
    OperationSnapshot before;
    if (command.action == OperationAction.register) {
      final person = OperationPerson(
        'synthetic-new-${people.length}',
        command.registration!.name,
      );
      people.add(person);
      before = OperationSnapshot(
        person: person,
        scope: command.scope,
        revision: 0,
        enrolled: false,
        assigned: false,
        baselineLinked: false,
        history: [],
      );
    } else {
      before = await inspect(
        command.sessionKey,
        command.scope,
        command.personId!,
      );
      if (before.revision != command.expectedRevision) {
        throw const OperationFailure(OperationFailureKind.conflict);
      }
      if (command.action == OperationAction.assign && !before.enrolled) {
        throw const OperationFailure(OperationFailureKind.invalid);
      }
    }
    final after = OperationSnapshot(
      person: before.person,
      scope: command.scope,
      revision: before.revision + 1,
      enrolled: command.action == OperationAction.enroll || before.enrolled,
      assigned: command.action == OperationAction.assign
          ? true
          : command.action == OperationAction.revoke
          ? false
          : before.assigned,
      baselineLinked: before.baselineLinked,
      history: [
        ...before.history,
        OperationHistory(
          action: command.action.name,
          reason: command.reason,
          actorLabel: 'Operador sintético',
          occurredAt: DateTime.utc(2026, 10, 3),
        ),
      ],
    );
    records['${command.scope.classId}/${after.person.id}'] = after;
    receipts[command.id] = (command, after);
    mutations++;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const OperationFailure(OperationFailureKind.unavailable);
    }
    return after;
  }
}
