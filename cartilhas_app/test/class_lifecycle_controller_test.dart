import 'package:flutter_test/flutter_test.dart';

import 'package:cartilhas_app/features/class_lifecycle/application/class_lifecycle_controller.dart';
import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_gateway.dart';
import 'package:cartilhas_app/features/class_lifecycle/models/class_lifecycle_models.dart';

void main() {
  group('PrepareClassroomController', () {
    test(
      'submits only server-provided opaque version and capability',
      () async {
        final gateway = FakeClassLifecycleGateway.coordinator();
        final controller = PrepareClassroomController(gateway);
        await controller.load();

        controller.setClassName('Turma Palmas Centro');
        controller.setOfferMunicipality('Palmas');
        controller.setOfferLocation('Laboratório');
        controller.next();
        await controller.selectProgram('program-tds');
        await controller.selectCourse('course-ia');
        controller.next();
        controller.setDates(DateTime(2026, 10, 10), DateTime(2026, 10, 12));
        controller.next();
        controller.setTeacher('teacher-1');
        controller.toggleMonitor('monitor-1', true);
        controller.next();
        controller.next();

        expect(controller.currentStep, 5);
        expect(controller.canAdvance, isTrue);
        await controller.submit();

        expect(controller.result?.statusLabel, 'Planejada');
        expect(
          gateway.lastPrepareCommand?.courseVersionId,
          'version-server-only',
        );
        expect(gateway.lastPrepareCommand?.offerMunicipality, 'Palmas');
        expect(gateway.lastPrepareCommand?.monitorIds, ['monitor-1']);
      },
    );

    test('capacity above 30 remains an advisory warning', () async {
      final gateway = FakeClassLifecycleGateway(
        capabilities: const ClassLifecycleCapabilities(
          canPrepare: true,
          canClose: true,
          canActivate: true,
          canOverrideCapacity: false,
        ),
        occupancy: 31,
        capacity: 30,
      );
      final controller = PrepareClassroomController(gateway);
      await controller.load();

      controller.setClassName('Turma Palmas Associação');
      controller.setOfferMunicipality('Palmas');
      controller.setOfferLocation('Associação');
      controller.next();
      await controller.selectProgram('program-tds');
      await controller.selectCourse('course-ia');
      controller.next();
      controller.setDates(DateTime(2026, 10, 10), DateTime(2026, 10, 12));
      controller.next();
      controller.setTeacher('teacher-1');
      controller.next();
      controller.next();

      expect(controller.currentStep, 5);
      expect(controller.stepValidationMessage, isNull);
      expect(controller.capacity?.canProceed, isTrue);
      expect(controller.capacity?.message, contains('referência de 30'));
      expect(controller.canAdvance, isTrue);
      await controller.submit();
      expect(gateway.lastPrepareCommand, isNotNull);
    });

    test(
      'shows the soft capacity reference without blocking preparation',
      () async {
        final gateway = FakeClassLifecycleGateway(
          capabilities: const ClassLifecycleCapabilities(
            canPrepare: true,
            canClose: false,
            canActivate: false,
            canOverrideCapacity: false,
          ),
          occupancy: 30,
          capacity: 30,
        );
        final controller = PrepareClassroomController(gateway);
        await controller.load();
        await controller.selectProgram('program-tds');
        await controller.selectCourse('course-ia');

        expect(controller.capacity?.canProceed, isTrue);
        expect(controller.capacity?.occupancy, 30);
        expect(controller.capacity?.capacity, 30);
      },
    );
  });

  group('ActivateClassroomController', () {
    test('operator activates only after server readiness and a reason', () async {
      final gateway = FakeClassLifecycleGateway.programOperator();
      final controller = ActivateClassroomController(gateway);
      await controller.load();
      expect(controller.selectedClassId, 'class-planned-1');
      expect(controller.canSubmit, isFalse);
      controller.setReason('Oferta e equipe conferidas');
      expect(controller.canSubmit, isTrue);
      await controller.submit();
      expect(controller.result?.statusLabel, 'Em andamento');
      expect(gateway.lastActivationReason, 'Oferta e equipe conferidas');
    });

    test('activation remains blocked when readiness says no', () async {
      final gateway = FakeClassLifecycleGateway(
        capabilities: const ClassLifecycleCapabilities(
          canPrepare: true,
          canClose: true,
          canActivate: true,
          canOverrideCapacity: false,
        ),
        readinessCanActivate: false,
      );
      final controller = ActivateClassroomController(gateway);
      await controller.load();
      controller.setReason('Oferta conferida');
      expect(controller.canSubmit, isFalse);
      expect(controller.readiness?.blockers, isNotEmpty);
    });
  });

  group('CloseClassroomController', () {
    test('blocks close while server readiness has blockers', () async {
      final gateway = FakeClassLifecycleGateway.coordinator(
        readinessCanClose: false,
      );
      final controller = CloseClassroomController(gateway);
      await controller.load();
      controller.setCloseReason('Atividades concluídas');
      controller.setCertificateNoticeConfirmed(true);

      expect(controller.readiness?.canClose, isFalse);
      expect(controller.canSubmit, isFalse);
      expect(controller.readiness?.blockers, isNotEmpty);
    });

    test('requires explicit reason and certificate acknowledgement', () async {
      final gateway = FakeClassLifecycleGateway.coordinator();
      final controller = CloseClassroomController(gateway);
      await controller.load();

      expect(controller.canSubmit, isFalse);
      controller.setCloseReason('Atividades concluídas');
      expect(controller.canSubmit, isFalse);
      controller.setCertificateNoticeConfirmed(true);
      expect(controller.canSubmit, isTrue);

      await controller.submit();
      expect(controller.result?.statusLabel, 'Encerrada');
      expect(gateway.lastCloseReason, 'Atividades concluídas');
    });

    test('program operator closes after server readiness', () async {
      final gateway = FakeClassLifecycleGateway.programOperator();
      final controller = CloseClassroomController(gateway);
      await controller.load();
      controller.setCloseReason('Atividades concluídas');
      controller.setCertificateNoticeConfirmed(true);

      expect(controller.canCloseCapability, isTrue);
      expect(controller.canSubmit, isTrue);
      await controller.submit();
      expect(gateway.lastCloseReason, 'Atividades concluídas');
    });
  });
}
