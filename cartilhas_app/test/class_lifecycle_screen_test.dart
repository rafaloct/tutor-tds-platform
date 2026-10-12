import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_gateway.dart';
import 'package:cartilhas_app/features/class_lifecycle/presentation/close_classroom_screen.dart';
import 'package:cartilhas_app/features/class_lifecycle/presentation/activate_classroom_screen.dart';
import 'package:cartilhas_app/features/class_lifecycle/presentation/prepare_classroom_screen.dart';

void main() {
  testWidgets(
    'denied prepare renders fail-closed state without submit action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PrepareClassroomScreen(
            gateway: FakeClassLifecycleGateway.denied(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preparação indisponível'), findsOneWidget);
      expect(find.text('Preparar turma'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Preparar turma'), findsNothing);
    },
  );

  testWidgets('close readiness explains certificates are independent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CloseClassroomScreen(
          gateway: FakeClassLifecycleGateway.coordinator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Antes de encerrar'), findsOneWidget);
    expect(find.text('Certificados são independentes'), findsOneWidget);
    expect(
      find.textContaining('não emite, não valida e não fabrica certificados'),
      findsOneWidget,
    );
    expect(find.text('Encerrar turma'), findsWidgets);
  });

  testWidgets(
    'program operator receives the close action from server capability',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CloseClassroomScreen(
            gateway: FakeClassLifecycleGateway.programOperator(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('close_classroom_action')),
        300,
      );
      expect(find.byKey(const Key('close_classroom_action')), findsOneWidget);
      expect(find.byType(CloseClassroomScreen), findsOneWidget);
    },
  );

  testWidgets('program operator can activate a planned class', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ActivateClassroomScreen(
        gateway: FakeClassLifecycleGateway.programOperator(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Turma Palmas — Inclusão Digital'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('activate_reason')), 'Oferta conferida');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ativar turma'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar ativação'));
    await tester.pumpAndSettle();
    expect(find.text('Turma ativada'), findsOneWidget);
  });
}
