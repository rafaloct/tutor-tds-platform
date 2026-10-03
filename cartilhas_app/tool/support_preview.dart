import 'package:cartilhas_app/features/support/support_controller.dart';
import 'package:cartilhas_app/features/support/support_demo_screen.dart';
import 'package:cartilhas_app/features/support/support_gateway.dart';
import 'package:cartilhas_app/features/support/support_models.dart';
import 'package:cartilhas_app/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw UnsupportedError(
      'support_preview.dart é somente DEMONSTRAÇÃO e não pode rodar em release.',
    );
  }

  final gateway = FakeSupportGateway();
  final controller = SupportController(gateway);

  runApp(
    SupportPreviewApp(
      controller: controller,
      session: const SupportSession(
        sessionId: 'demo-session-a',
        ownerId: 'demo-owner-a',
        displayLabel: 'Participante A',
        optionalConsentGranted: false,
        contexts: [
          SupportContextOption(
            id: 'demo-turma-palmas',
            cohortLabel: 'Turma Palmas',
            courseLabel: 'IA e Inclusão Digital',
          ),
          SupportContextOption(
            id: 'demo-turma-itaguatins',
            cohortLabel: 'Turma Itaguatins',
            courseLabel: 'IA e Inclusão Digital',
          ),
        ],
      ),
    ),
  );
}

class SupportPreviewApp extends StatelessWidget {
  const SupportPreviewApp({
    super.key,
    required this.controller,
    required this.session,
  });

  final SupportController controller;
  final SupportSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEMONSTRAÇÃO • Central TDS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: SupportDemoScreen(controller: controller, session: session),
    );
  }
}
