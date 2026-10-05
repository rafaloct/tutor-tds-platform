import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_gateway.dart';
import 'package:cartilhas_app/features/class_lifecycle/presentation/close_classroom_screen.dart';
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
    'program operator can inspect readiness but has no close action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CloseClassroomScreen(
            gateway: FakeClassLifecycleGateway.programOperator(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Encerrar turma'), findsNothing);
      expect(find.byType(CloseClassroomScreen), findsOneWidget);
    },
  );
}
