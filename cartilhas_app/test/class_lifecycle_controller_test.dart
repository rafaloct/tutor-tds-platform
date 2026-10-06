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

    test('requires override reason only when gateway requests it', () async {
      final gateway = FakeClassLifecycleGateway(
        capabilities: const ClassLifecycleCapabilities(
          canPrepare: true,
          canClose: true,
          canActivate: true,
          canOverrideCapacity: true,
        ),
        occupancy: 31,
        capacity: 30,
        requiresOverrideReason: true,
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
      expect(
        controller.stepValidationMessage,
        'Informe a justificativa da exceção de capacidade.',
      );

      controller.setCapacityOverrideReason(
        'Ampliação autorizada pela coordenação',
      );
      expect(controller.canAdvance, isTrue);
      await controller.submit();

      expect(
        gateway.lastPrepareCommand?.capacityOverrideReason,
        'Ampliação autorizada pela coordenação',
      );
    });

    test(
      'does not calculate client-side capacity override permission',
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
          capacityCanProceed: false,
        );
        final controller = PrepareClassroomController(gateway);
        await controller.load();
        await controller.selectProgram('program-tds');
        await controller.selectCourse('course-ia');

        expect(controller.capacity?.canProceed, isFalse);
        expect(controller.capacity?.occupancy, 30);
        expect(controller.capacity?.capacity, 30);
      },
    );
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

    test('program operator capability never authorizes close', () async {
      final controller = CloseClassroomController(
        FakeClassLifecycleGateway.programOperator(),
      );
      await controller.load();
      controller.setCloseReason('Teste');
      controller.setCertificateNoticeConfirmed(true);

      expect(controller.canCloseCapability, isFalse);
      expect(controller.canSubmit, isFalse);
    });
  });
}
