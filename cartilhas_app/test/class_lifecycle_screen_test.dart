import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartilhas_app/features/class_lifecycle/data/class_lifecycle_gateway.dart';
import 'package:cartilhas_app/features/class_lifecycle/models/class_lifecycle_models.dart';
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
    await tester.scrollUntilVisible(
      find.text('Certificados são independentes'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
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
        scrollable: find.byType(Scrollable).first,
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
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Turma Palmas — Inclusão Digital'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar ativação'));
    await tester.pumpAndSettle();
    expect(find.text('Turma ativada'), findsOneWidget);
  });

  testWidgets('falha de prontidão da única turma permite nova consulta', (tester) async {
    final gateway = FakeClassLifecycleGateway(
      capabilities: const ClassLifecycleCapabilities(
        canPrepare: true, canClose: true, canActivate: true,
        canOverrideCapacity: false,
      ),
      failNextActivationReadiness: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: ActivateClassroomScreen(gateway: gateway),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Falha temporária'), findsOneWidget);
    await tester.tap(find.text('Atualizar prontidão'));
    await tester.pumpAndSettle();
    expect(find.text('Preparação conferida pelo servidor.'), findsOneWidget);
  });

  testWidgets('confirmação de encerramento mostra nome da turma', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CloseClassroomScreen(
        gateway: FakeClassLifecycleGateway.programOperator(),
      ),
    ));
    await tester.pumpAndSettle();
    final reason = find.byKey(const Key('close_reason'));
    await tester.scrollUntilVisible(
      reason,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(reason, 'Atividades concluídas');
    final certificate = find.byType(CheckboxListTile);
    await tester.scrollUntilVisible(
      certificate,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(certificate);
    await tester.pumpAndSettle();
    final close = find.widgetWithText(FilledButton, 'Encerrar turma');
    await tester.scrollUntilVisible(
      close,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Turma Palmas — IA'),
      ),
      findsOneWidget,
    );
  });
}
