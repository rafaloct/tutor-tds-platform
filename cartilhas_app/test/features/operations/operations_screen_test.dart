import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cartilhas_app/features/operations/operations_controller.dart';
import 'package:cartilhas_app/features/operations/operations_screen.dart';
import 'fake_operations_gateway.dart';

void main() {
  late FakeOperationsGateway gateway;
  late OperationsController controller;
  setUp(() {
    gateway = FakeOperationsGateway();
    var next = 0;
    controller = OperationsController(
      gateway,
      sessionKey: 'actor-a',
      nextCommandId: () => 'synthetic-ui-${next++}',
    );
  });
  tearDown(() => controller.dispose());
  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: OperationsScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scopePicker = find.byKey(const ValueKey('operation-scope'));
    await tester.scrollUntilVisible(scopePicker, 180);
    await tester.tap(scopePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text(scopeA.label).last);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 180);
    } else {
      await tester.ensureVisible(finder);
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  testWidgets(
    'existing participant completes enrollment, assignment and confirmed revocation',
    (tester) async {
      await open(tester);
      expect(find.textContaining('DEMONSTRAÇÃO'), findsOneWidget);
      expect(gateway.commands, isEmpty);
      await tester.enterText(field('Buscar pessoa'), 'Pessoa');
      await tap(tester, 'Localizar');
      await tap(tester, 'Pessoa teste');
      await tester.ensureVisible(field('Motivo da operação'));
      await tester.enterText(
        field('Motivo da operação'),
        'Vínculo conferido pela equipe',
      );
      await tap(tester, 'Solicitar matrícula');
      await tap(tester, 'Vincular à turma');
      await tap(tester, 'Revogar vínculo');
      await tap(tester, 'Cancelar');
      expect(gateway.mutations, 2);
      await tap(tester, 'Revogar vínculo');
      await tap(tester, 'Confirmar revogação');
      expect(gateway.mutations, 3);
      expect(controller.snapshot!.assigned, false);
      expect(controller.snapshot!.history.length, 3);
      final confirmation = find.textContaining('Nenhuma conta ou matrícula real');
      await tester.scrollUntilVisible(confirmation, -180);
      expect(confirmation, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('session switch clears registration fields and context', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'Cadastrar nova pessoa');
    await tester.ensureVisible(field('Nome'));
    await tester.enterText(field('Nome'), 'Pessoa sintética privada');
    await tester.ensureVisible(field('Senha inicial'));
    await tester.enterText(field('Senha inicial'), 'synthetic-only');
    controller.replaceSession('actor-b');
    await tester.pumpAndSettle();
    expect(find.text('Pessoa sintética privada'), findsNothing);
    expect(find.text('synthetic-only'), findsNothing);
    expect(find.text('Selecionar programa / curso / turma'), findsOneWidget);
    expect(gateway.commands, isEmpty);
  });

  testWidgets(
    'narrow viewport and enlarged text stay scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, scale: 2);
      await tap(tester, 'Cadastrar nova pessoa');
      await tester.scrollUntilVisible(find.text('Solicitar cadastro'), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget);
    },
  );
}
