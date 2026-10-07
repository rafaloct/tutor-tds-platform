import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartilhas_app/features/class_lifecycle/models/class_lifecycle_models.dart';
import 'package:cartilhas_app/features/management/presentation/management_workspace_screen.dart';

void main() {
  testWidgets('Gestão mostra lifecycle actions somente por capabilities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var prepare = 0;
    var close = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ManagementWorkspaceScreen(
          operationScopeCount: 0,
          editorProgramCount: 0,
          teamCapability: null,
          lifecycleCapabilities: const ClassLifecycleCapabilities(
            canPrepare: true,
            canClose: true,
            canActivate: true,
            canOverrideCapacity: true,
          ),
          onPrepareClassTap: () => prepare++,
          onCloseClassTap: () => close++,
        ),
      ),
    );

    expect(find.text('Preparar turma'), findsOneWidget);
    expect(find.text('Encerrar turma'), findsOneWidget);
    expect(find.text('Participantes'), findsNothing);

    await tester.tap(find.text('Preparar turma'));
    await tester.tap(find.text('Encerrar turma'));

    expect(prepare, 1);
    expect(close, 1);
  });

  testWidgets('Gestão não inventa lifecycle actions sem capability', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ManagementWorkspaceScreen(
          operationScopeCount: 0,
          editorProgramCount: 0,
          teamCapability: null,
          lifecycleCapabilities: ClassLifecycleCapabilities(
            canPrepare: false,
            canClose: false,
            canActivate: false,
            canOverrideCapacity: false,
          ),
        ),
      ),
    );

    expect(find.text('Preparar turma'), findsNothing);
    expect(find.text('Encerrar turma'), findsNothing);
    expect(
      find.text('Nenhuma ferramenta de gestão disponível'),
      findsOneWidget,
    );
  });
}
