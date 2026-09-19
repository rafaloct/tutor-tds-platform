import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../services/privacy_preferences.dart';
import '../services/theme_controller.dart';
import '../widgets/responsive_body.dart';
import 'chatwoot_screen.dart';
import 'onboarding_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _shareLearningData = false;
  bool _rememberCertificateConsent = false;

  @override
  void initState() {
    super.initState();
    PrivacyPreferences.hasConsent().then((value) {
      if (mounted) setState(() => _shareLearningData = value);
    });
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _rememberCertificateConsent =
              prefs.getBool('certificate_consent_v1') == true;
        });
      }
    });
  }

  Future<void> _rateApp() async {
    final marketUri = Uri.parse('market://details?id=com.tutortds_cartilhas');
    try {
      if (await launchUrl(marketUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } on Exception {
      // A Play Store pode não estar instalada; usa o endereço web abaixo.
    }

    final opened = await launchUrl(
      Uri.parse(AppConfig.playStoreUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a Play Store.')),
      );
    }
  }

  Future<void> _setSharing(bool value) async {
    await PrivacyPreferences.saveDecision(consent: value);
    if (mounted) setState(() => _shareLearningData = value);
  }

  Future<void> _setCertificateConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('certificate_consent_v1', value);
    if (mounted) setState(() => _rememberCertificateConsent = value);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ResponsiveBody(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SectionTitle('Aparência'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tema do aplicativo'),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemePreference>(
                      segments: const [
                        ButtonSegment(
                          value: ThemePreference.system,
                          label: Text('Sistema'),
                        ),
                        ButtonSegment(
                          value: ThemePreference.light,
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemePreference.dark,
                          label: Text('Escuro'),
                        ),
                      ],
                      selected: {themeController.preference},
                      onSelectionChanged: (selection) {
                        themeController.setPreference(selection.first);
                      },
                      showSelectedIcon: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Idioma'),
            const Card(
              child: ListTile(
                leading: Icon(Icons.language_outlined),
                title: Text('Português (Brasil)'),
                subtitle: Text('Idioma do conteúdo pedagógico validado'),
                trailing: Icon(Icons.check_circle_outline),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Privacidade'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _shareLearningData,
                    onChanged: _setSharing,
                    secondary: const Icon(Icons.sync_lock_outlined),
                    title: const Text('Compartilhar progresso pedagógico'),
                    subtitle: const Text(
                      'Permite enviar cadastro e eventos de início/conclusão à equipe TDS.',
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _rememberCertificateConsent,
                    onChanged: _setCertificateConsent,
                    secondary: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Lembrar autorização de certificado'),
                    subtitle: const Text(
                      'Desative para o app pedir novamente antes da próxima emissão. Não apaga certificados já emitidos.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Como seus dados são usados'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Ajuda e participação'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('Rever apresentação do app'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const OnboardingScreen(openedFromSettings: true),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.support_agent_outlined),
                    title: const Text('Falar com a equipe TDS'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatwootScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.star_outline_rounded),
                    title: const Text('Avaliar o Tutor TDS'),
                    subtitle: const Text(
                      'Sua avaliação ajuda o projeto a melhorar',
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: _rateApp,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tutor TDS 1.2.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
