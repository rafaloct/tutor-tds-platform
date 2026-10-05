import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cartilhas_app/features/operations/operations_controller.dart';
import 'package:cartilhas_app/features/operations/operations_models.dart';
import 'fake_operations_gateway.dart';

void main() {
  late FakeOperationsGateway gateway;
  late OperationsController controller;
  setUp(() {
    gateway = FakeOperationsGateway();
    var sequence = 0;
    controller = OperationsController(
      gateway,
      sessionKey: 'actor-a',
      nextCommandId: () => 'synthetic-command-${sequence++}',
    );
  });
  tearDown(() => controller.dispose());
  Future<void> select() async {
    await controller.load();
    controller.selectScope(scopeA);
    await controller.search('Pessoa');
    await controller.selectPerson(controller.people.single);
  }

  test(
    'existing person enrolls, joins and revokes without baseline or losing history',
    () async {
      await select();
      await controller.enroll('Matrícula autorizada');
      await controller.assign('Turma conferida');
      expect(controller.snapshot!.assigned, true);
      expect(controller.snapshot!.baselineLinked, false);
      await controller.revoke('Correção da turma');
      expect(controller.snapshot!.assigned, false);
      expect(controller.snapshot!.enrolled, true);
      expect(controller.snapshot!.history.map((item) => item.action), [
        'enroll',
        'assign',
        'revoke',
      ]);
      expect(controller.message, contains('Simulação'));
    },
  );

  test(
    'new person flows through registration, enrollment and assignment with server IDs',
    () async {
      await controller.load();
      controller.selectScope(scopeB);
      await controller.register(
        const OperationRegistration(
          name: 'Nova pessoa sintética',
          cpf: '00000000000',
          phone: '00000000000',
          password: 'synthetic-password-only',
        ),
        'Cadastro autorizado',
      );
      expect(controller.snapshot!.person.id, 'synthetic-new-1');
      expect(controller.message, contains('Cadastro confirmado'));
      expect(controller.message, isNot(contains('Fluxo completo')));
      await controller.enroll('Matrícula conferida');
      expect(controller.message, contains('Matrícula confirmada'));
      expect(controller.message, isNot(contains('Fluxo completo')));
      await controller.assign('Turma conferida');
      expect(controller.snapshot!.scope.versionId, 'v2');
      expect(controller.snapshot!.history.length, 3);
      expect(controller.message, contains('Fluxo completo confirmado'));
    },
  );

  test('starting a new registration clears the prior confirmation', () async {
    await select();
    await controller.enroll('Matrícula conferida');
    await controller.assign('Turma conferida');
    expect(controller.message, contains('Fluxo completo confirmado'));

    controller.beginRegistration();

    expect(controller.snapshot, isNull);
    expect(controller.message, isNull);
  });

  test(
    'response loss retries the exact command without a second mutation',
    () async {
      await select();
      gateway.loseNextResponse = true;
      await controller.enroll('Matrícula autorizada');
      expect(controller.snapshot!.enrolled, false);
      expect(controller.canRetry, true);
      await controller.assign('Outra operação não permitida');
      controller.selectScope(scopeB);
      expect(gateway.commands.length, 1);
      expect(controller.scope, scopeA);
      await controller.retry();
      expect(identical(gateway.commands[0], gateway.commands[1]), true);
      expect(gateway.mutations, 1);
      expect(controller.snapshot!.enrolled, true);
    },
  );

  test(
    'double tap cannot dispatch twice while first command is pending',
    () async {
      await select();
      gateway.pause = Completer<void>();
      final first = controller.enroll('Autorizado');
      await controller.enroll('Autorizado');
      expect(gateway.commands.length, 1);
      gateway.pause!.complete();
      await first;
      expect(gateway.mutations, 1);
    },
  );

  test('late read from A cannot populate B or restore selection', () async {
    await controller.load();
    controller.selectScope(scopeA);
    gateway.searchResult = Completer<List<OperationPerson>>();
    final search = controller.search('Pessoa');
    controller.replaceSession('actor-b');
    gateway.searchResult!.complete(gateway.people);
    await search;
    expect(controller.people, isEmpty);
    expect(controller.scope, isNull);
    expect(controller.snapshot, isNull);
    expect(controller.busy, false);
  });

  test(
    'late mutation confirmation cannot appear under another session',
    () async {
      await select();
      gateway.pause = Completer<void>();
      final operation = controller.enroll('Autorizado');
      controller.replaceSession('actor-b');
      gateway.pause!.complete();
      await operation;
      expect(controller.snapshot, isNull);
      expect(controller.message, isNull);
      expect(controller.canRetry, false);
    },
  );

  test(
    'server denial clears context and personal data and is not retried',
    () async {
      await select();
      gateway.denied = true;
      await controller.enroll('Autorizado anteriormente');
      expect(controller.people, isEmpty);
      expect(controller.snapshot, isNull);
      expect(controller.scopes, isEmpty);
      expect(controller.canRetry, false);
      expect(controller.message, contains('revogado'));
    },
  );

  test(
    'no automatic context selection and no command with missing reason',
    () async {
      await controller.load();
      expect(controller.scope, isNull);
      await controller.enroll('Autorizado');
      await select();
      await controller.enroll(' ');
      expect(gateway.commands, isEmpty);
      expect(controller.message, contains('motivo'));
    },
  );

  test('revision conflict requires reread without automatic retry', () async {
    await select();
    final before = controller.snapshot!;
    gateway.records['${scopeA.classId}/${before.person.id}'] =
        OperationSnapshot(
          person: before.person,
          scope: scopeA,
          revision: 9,
          enrolled: true,
          assigned: false,
          baselineLinked: null,
          history: [],
        );
    await controller.enroll('Outro operador alterou');
    expect(controller.snapshot, isNull);
    expect(controller.canRetry, false);
    expect(controller.message, contains('conferência'));
  });

  test(
    'reload clears old scope objects and selecting another class drops person data',
    () async {
      await select();
      controller.selectScope(scopeB);
      expect(controller.snapshot, isNull);
      expect(controller.people, isEmpty);
      await controller.load();
      expect(controller.scope, isNull);
    },
  );
}
