import 'dart:async';

import 'package:cartilhas_app/features/ead_account/application/ead_my_area_controller.dart';
import 'package:cartilhas_app/features/ead_account/domain/ead_learner_action_policy.dart'
    show EadSessionProof;
import 'package:cartilhas_app/features/ead_account/presentation/ead_my_area_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final initialTime = DateTime.utc(2026, 10, 18, 17);

EadSessionProof proof({
  int id = 3,
  String env = 'staging',
  DateTime? verifiedAt,
  DateTime? expiresAt,
  bool verified = true,
}) => EadSessionProof(
  wpUserId: id,
  environmentId: env,
  verifiedAt: verifiedAt ?? initialTime.subtract(const Duration(minutes: 2)),
  expiresAt: expiresAt ?? initialTime.add(const Duration(minutes: 8)),
  brokerVerified: verified,
);

EadAccountReadSnapshot snapshot({
  int id = 3,
  String env = 'staging',
  DateTime? observedAt,
  bool sourceVerified = true,
  List<EadAreaCourse> courses = const [
    EadAreaCourse(
      wpCourseId: 1298,
      title: 'Agricultura Sustentável',
      enrollment: EadEnrollmentState.enrolled,
      progressPercent: 42,
      nextLesson: 'Aula 2',
      resumeAuthorized: true,
    ),
  ],
}) => EadAccountReadSnapshot(
  wpUserId: id,
  environmentId: env,
  observedAt: observedAt ?? initialTime.subtract(const Duration(seconds: 12)),
  authenticatedLearnPressOrigin: sourceVerified,
  courses: courses,
);

class FakeEadReader implements EadMyAreaReader {
  FakeEadReader(this.handle);
  Future<EadAccountReadSnapshot> Function(EadSessionProof) handle;
  int calls = 0;

  @override
  Future<EadAccountReadSnapshot> read(EadSessionProof proof) {
    calls++;
    return handle(proof);
  }
}

void main() {
  late DateTime currentTime;
  late FakeEadReader reader;
  late EadMyAreaController controller;

  setUp(() {
    currentTime = initialTime;
    reader = FakeEadReader((_) async => snapshot());
    controller = EadMyAreaController(reader: reader, clock: () => currentTime);
  });

  tearDown(() => controller.dispose());

  group('isolamento da conta EAD', () {
    test('estado inicial desconectado não gera rede nem dados privados', () {
      expect(controller.model.linkState, EadLinkState.disconnected);
      expect(controller.model.courses, isEmpty);
      expect(reader.calls, 0);
    });

    test('aceitar prova não dispara chamadas automáticas', () {
      controller.acceptSession(proof());
      expect(controller.model.snapshotState, EadSnapshotState.unknown);
      expect(controller.model.courses, isEmpty);
      expect(reader.calls, 0);
    });

    test('JWT LP de sete dias não é prova válida para o broker', () async {
      controller.acceptSession(
        proof(expiresAt: initialTime.add(const Duration(days: 7))),
      );
      await controller.refresh();
      expect(controller.model.linkState, EadLinkState.loginRequired);
      expect(reader.calls, 0);
    });

    test('sessão institucional não é prova de conta LearnPress', () async {
      controller.acceptSession(proof(verified: false));
      await controller.refresh();
      expect(controller.model.courses, isEmpty);
      expect(controller.model.linkState, EadLinkState.loginRequired);
      expect(reader.calls, 0);
    });

    test('fonte LearnPress autenticada mostra apenas dados próprios', () async {
      controller.acceptSession(proof());
      await controller.refresh();
      expect(reader.calls, 1);
      expect(controller.model.hasVerifiedScope, true);
      expect(controller.model.snapshotState, EadSnapshotState.current);
      expect(controller.model.courses.single.wpCourseId, 1298);
      expect(controller.model.courses.single.progressPercent, 42);
      expect(controller.model.canResume, true);
    });

    test('resposta que pertence ao aluno B não é exibida para A', () async {
      reader.handle = (_) async => snapshot(id: 4);
      controller.acceptSession(proof(id: 3));
      await controller.refresh();
      expect(controller.model.linkState, EadLinkState.loginRequired);
      expect(controller.model.courses, isEmpty);
      expect(controller.model.canShowPrivate, false);
    });

    test('ambiente staging não aceita resposta de produção', () async {
      reader.handle = (_) async => snapshot(env: 'production');
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.courses, isEmpty);
      expect(controller.model.linkState, EadLinkState.loginRequired);
    });

    test('diretório público não serve de fonte autenticada', () async {
      reader.handle = (_) async => snapshot(sourceVerified: false);
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.linkState, EadLinkState.loginRequired);
      expect(controller.model.courses, isEmpty);
    });

    test('logout apaga imediatamente lista e progresso', () async {
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.courses, isNotEmpty);
      controller.signOutLocally();
      expect(controller.model.courses, isEmpty);
      expect(controller.model.hasVerifiedScope, false);
      expect(controller.model.linkState, EadLinkState.disconnected);
    });

    test('um request A atrasado não reaparece depois do logout', () async {
      final pending = Completer<EadAccountReadSnapshot>();
      reader.handle = (_) => pending.future;
      controller.acceptSession(proof());
      final request = controller.refresh();
      expect(controller.model.snapshotState, EadSnapshotState.loading);
      controller.signOutLocally();
      pending.complete(snapshot(id: 3));
      await request;
      expect(controller.model.courses, isEmpty);
      expect(controller.model.linkState, EadLinkState.disconnected);
    });

    test('resultado tardio A não contamina sessão posterior B', () async {
      final first = Completer<EadAccountReadSnapshot>();
      reader.handle = (_) => first.future;
      controller.acceptSession(proof(id: 3));
      final earlier = controller.refresh();
      controller.acceptSession(proof(id: 4));
      reader.handle = (_) async => snapshot(id: 4);
      await controller.refresh();
      expect(controller.model.snapshotWpUserId, 4);
      first.complete(snapshot(id: 3));
      await earlier;
      expect(controller.model.snapshotWpUserId, 4);
      expect(controller.model.courses.single.progressPercent, 42);
    });

    test('segundo refresh vence o primeiro mesmo na mesma conta', () async {
      final old = Completer<EadAccountReadSnapshot>();
      reader.handle = (_) => old.future;
      controller.acceptSession(proof());
      final first = controller.refresh();
      reader.handle = (_) async => snapshot(
        courses: const [
          EadAreaCourse(
            wpCourseId: 614,
            title: 'IA e Inclusão Digital',
            enrollment: EadEnrollmentState.enrolled,
            progressPercent: 60,
          ),
        ],
      );
      await controller.refresh();
      old.complete(snapshot());
      await first;
      expect(controller.model.courses.single.wpCourseId, 614);
    });
  });

  group('leitura canônica e estados de conectividade', () {
    test('dados anteriores à prova de conta são recusados', () async {
      reader.handle = (_) async => snapshot(
        observedAt: initialTime.subtract(const Duration(minutes: 3)),
      );
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.hasVerifiedScope, false);
      expect(controller.model.courses, isEmpty);
    });

    test('timestamp no futuro é recusado', () async {
      reader.handle = (_) async =>
          snapshot(observedAt: initialTime.add(const Duration(minutes: 1)));
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.linkState, EadLinkState.loginRequired);
      expect(controller.model.courses, isEmpty);
    });

    test('snapshot antigo continua identificado como stale', () async {
      controller.acceptSession(
        proof(
          verifiedAt: initialTime.subtract(const Duration(minutes: 9)),
          expiresAt: initialTime.add(const Duration(minutes: 1)),
        ),
      );
      reader.handle = (_) async => snapshot(
        observedAt: initialTime.subtract(const Duration(minutes: 5)),
      );
      await controller.refresh();
      expect(controller.model.snapshotState, EadSnapshotState.stale);
      expect(controller.model.canShowPrivate, true);
      expect(controller.model.canResume, false);
    });

    test(
      'offline usa só cache verificado em memória e impede retomar',
      () async {
        controller.acceptSession(proof());
        await controller.refresh();
        controller.setOffline();
        expect(controller.model.snapshotState, EadSnapshotState.offline);
        expect(controller.model.courses.single.wpCourseId, 1298);
        expect(controller.model.canResume, false);
        expect(reader.calls, 1);
      },
    );

    test('offline sem snapshot não inventa inscrição', () {
      controller.acceptSession(proof());
      controller.setOffline();
      expect(controller.model.snapshotState, EadSnapshotState.offline);
      expect(controller.model.courses, isEmpty);
    });

    test('resposta expirada demais é tratada como indisponível', () async {
      controller.dispose();
      controller = EadMyAreaController(
        reader: reader,
        clock: () => currentTime,
        maxFreshAge: const Duration(seconds: 3),
        maxOfflineAge: const Duration(seconds: 5),
      );
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.snapshotState, EadSnapshotState.error);
      expect(controller.model.courses, isEmpty);
    });

    test('falha de rede mostra erro sem expor último progresso', () async {
      controller.acceptSession(proof());
      await controller.refresh();
      reader.handle = (_) async =>
          throw const EadAccountReadException(EadAccountReadFailure.offline);
      await controller.refresh();
      expect(controller.model.snapshotState, EadSnapshotState.error);
      expect(controller.model.courses, isEmpty);
    });

    test('erro 401 solicita novo acesso em vez de tratar como zero', () async {
      reader.handle = (_) async => throw const EadAccountReadException(
        EadAccountReadFailure.loginRequired,
      );
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.linkState, EadLinkState.loginRequired);
      expect(controller.model.courses, isEmpty);
    });

    test('erro 403 não divulga matrícula anterior', () async {
      reader.handle = (_) async =>
          throw const EadAccountReadException(EadAccountReadFailure.forbidden);
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.linkState, EadLinkState.loginRequired);
      expect(controller.model.courses, isEmpty);
    });

    test('erro imprevisto não revela detalhe ou dados pessoais', () async {
      reader.handle = (_) async => throw StateError('synthetic failure');
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.snapshotState, EadSnapshotState.error);
      expect(controller.model.courses, isEmpty);
    });

    test('duas linhas com o mesmo curso são rejeitadas', () async {
      reader.handle = (_) async => snapshot(
        courses: const [
          EadAreaCourse(
            wpCourseId: 1298,
            title: 'A',
            enrollment: EadEnrollmentState.enrolled,
          ),
          EadAreaCourse(
            wpCourseId: 1298,
            title: 'B',
            enrollment: EadEnrollmentState.enrolled,
          ),
        ],
      );
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.hasVerifiedScope, false);
      expect(controller.model.courses, isEmpty);
    });

    test('progresso malformado não é arredondado ou publicado', () async {
      reader.handle = (_) async => snapshot(
        courses: const [
          EadAreaCourse(
            wpCourseId: 1298,
            title: 'SAF',
            enrollment: EadEnrollmentState.enrolled,
            progressPercent: 400,
          ),
        ],
      );
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.courses, isEmpty);
      expect(controller.model.linkState, EadLinkState.loginRequired);
    });

    test('resposta com zero cursos é válida, mas sem inscrição', () async {
      reader.handle = (_) async => snapshot(courses: const []);
      controller.acceptSession(proof());
      await controller.refresh();
      expect(controller.model.hasVerifiedScope, true);
      expect(controller.model.courses, isEmpty);
    });

    test('prova expirada durante request cancela a apresentação', () async {
      final pending = Completer<EadAccountReadSnapshot>();
      reader.handle = (_) => pending.future;
      controller.acceptSession(proof());
      final request = controller.refresh();
      currentTime = initialTime.add(const Duration(minutes: 10));
      pending.complete(snapshot());
      await request;
      expect(controller.model.linkState, EadLinkState.loginRequired);
      expect(controller.model.courses, isEmpty);
    });

    test('resultado de request depois de dispose não publica estado', () async {
      final pending = Completer<EadAccountReadSnapshot>();
      reader.handle = (_) => pending.future;
      final disposable = EadMyAreaController(
        reader: reader,
        clock: () => currentTime,
      );
      disposable.acceptSession(proof());
      final waiting = disposable.refresh();
      disposable.dispose();
      pending.complete(snapshot());
      await waiting;
      expect(reader.calls, 1);
    });
  });

  testWidgets('loading and error are visible without exposing courses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<EadAccountReadSnapshot>();
    reader.handle = (_) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => EadMyAreaPreview(
            model: controller.model,
            onRetry: () => unawaited(controller.refresh()),
          ),
        ),
      ),
    );
    controller.acceptSession(proof());
    final waiting = controller.refresh();
    await tester.pump();
    expect(find.text('Consultando dados da conta EAD'), findsOneWidget);
    expect(find.text('Consultando inscrições no EAD...'), findsOneWidget);
    expect(find.text('Agricultura Sustentável'), findsNothing);
    pending.completeError(
      const EadAccountReadException(EadAccountReadFailure.offline),
    );
    await waiting;
    await tester.pump();
    expect(find.text('Conta EAD aguardando consulta'), findsOneWidget);
    expect(find.textContaining('Não foi possível consultar'), findsOneWidget);
    expect(find.text('Agricultura Sustentável'), findsNothing);
  });

  testWidgets('invalid cross-account response never appears on screen', (
    tester,
  ) async {
    reader.handle = (_) async => snapshot(id: 4);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => EadMyAreaPreview(model: controller.model),
        ),
      ),
    );
    controller.acceptSession(proof(id: 3));
    await controller.refresh();
    await tester.pump();
    expect(find.text('Sessão EAD precisa de novo acesso'), findsOneWidget);
    expect(find.text('Agricultura Sustentável'), findsNothing);
  });

  testWidgets('widget acompanha dados verificados e os limpa após logout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => EadMyAreaPreview(model: controller.model),
        ),
      ),
    );
    controller.acceptSession(proof());
    await tester.pump();
    expect(find.text('Agricultura Sustentável'), findsNothing);
    final read = controller.refresh();
    await tester.pump();
    await read;
    await tester.pump();
    expect(find.text('Agricultura Sustentável'), findsOneWidget);
    controller.signOutLocally();
    await tester.pump();
    expect(find.text('Agricultura Sustentável'), findsNothing);
  });
}
