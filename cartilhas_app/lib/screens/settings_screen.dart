import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../features/auth/data/account_data_deletion_service.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/models/auth_session.dart';
import '../features/auth/presentation/account_login_dialog.dart';
import '../features/learning_events/learning_event_queue.dart';
import '../features/study_ai/data/assessment_sync_queue.dart';
import '../services/privacy_preferences.dart';
import '../services/theme_controller.dart';
import '../widgets/responsive_body.dart';
import 'chatwoot_screen.dart';
import 'onboarding_screen.dart';
import 'privacy_screen.dart';
import 'welcome_screen.dart';
import '../features/analytics/telemetry_route.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _shareLearningData = false;
  bool _rememberCertificateConsent = false;
  bool _hasOnlineAccount = false;
  bool _checkingOnlineAccount = true;
  bool _loggingIn = false;
  AuthUser? _onlineUser;
  bool _deletingAccount = false;
  bool _loggingOut = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthRepository>();
      try {
        final hasSession = await auth.hasSession();
        AuthUser? user;
        if (hasSession) {
          try {
            user = await auth.currentUser();
          } on AuthException {
            // Uma falha de rede não invalida os tokens locais. Um 401/refresh
            // inválido é refletido pela segunda leitura abaixo.
          }
        }
        final stillHasSession = await auth.hasSession();
        if (mounted) {
          setState(() {
            _hasOnlineAccount = stillHasSession;
            _onlineUser = stillHasSession ? user : null;
            _checkingOnlineAccount = false;
          });
        }
      } on AuthException {
        if (mounted) setState(() => _checkingOnlineAccount = false);
      }
    });
  }

  Future<void> _loginOnline() async {
    if (_loggingIn) return;
    final auth = context.read<AuthRepository>();
    if (!auth.isConfigured) return;
    setState(() => _loggingIn = true);
    try {
      final session = await showAccountLoginDialog(context);
      if (session == null || !mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', session.user.name);
      if (!mounted) return;
      setState(() {
        _hasOnlineAccount = true;
        _onlineUser = session.user;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conta de ${session.user.name} conectada.')),
      );
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
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

  Future<void> _openAccountDeletionPage() async {
    final opened = await launchUrl(
      Uri.parse(AppConfig.accountDeletionUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir a página de exclusão.'),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir conta e dados?'),
        content: const Text(
          'Esta ação é permanente. A conta, sessões, matrículas, progresso e analytics associados serão removidos do servidor. Os dados e certificados salvos na área privada deste aplicativo também serão apagados. Registros públicos de certificados já emitidos podem ser mantidos para preservar sua verificação.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir definitivamente'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await context.read<AuthRepository>().deleteAccount();
      var localDeleteFailed = false;
      try {
        await AccountDataDeletionService().deleteLocalData();
      } on Object {
        localDeleteFailed = true;
      }
      if (!mounted) return;
      if (localDeleteFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A conta online foi excluída. Para remover arquivos restantes, limpe os dados do app nas configurações do Android.',
            ),
          ),
        );
      }
      Navigator.pushAndRemoveUntil(
        context,
        trackedRoute(pageId: 'welcome', builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta online?'),
        content: const Text(
          'A sessão online será encerrada. Envios pendentes desta conta serão removidos para não serem atribuídos à próxima pessoa. O perfil, as cartilhas e o progresso salvos neste aparelho não serão apagados e ainda não são separados por usuário. Em um dispositivo compartilhado, essas informações podem continuar visíveis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair da conta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final authRepository = context.read<AuthRepository>();
    setState(() => _loggingOut = true);
    try {
      await Future.wait([
        const LearningEventQueue().clear(),
        const AssessmentSyncQueue().clear(),
      ]);
      await authRepository.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        trackedRoute(
          pageId: 'welcome',
          featureId: 'account_logout',
          builder: (_) => const WelcomeScreen(skipExistingUserRedirect: true),
        ),
        (_) => false,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível encerrar a sessão com segurança.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final authConfigured = context.read<AuthRepository>().isConfigured;

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
            const _SectionTitle('Conta'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const ValueKey('account-session-status'),
                    leading: const Icon(Icons.account_circle_outlined),
                    title: Text(
                      _checkingOnlineAccount
                          ? 'Verificando conta online'
                          : _hasOnlineAccount
                          ? 'Conta online conectada'
                          : 'Sem conta online conectada',
                    ),
                    subtitle: Text(
                      _onlineUser != null
                          ? '${_onlineUser!.name} • perfil ${_roleLabel(_onlineUser!.role)}. Os acessos às turmas serão atualizados ao voltar. O progresso local continua neste aparelho.'
                          : 'O perfil e o progresso deste aparelho permanecem disponíveis no modo local.',
                    ),
                  ),
                  if (!_checkingOnlineAccount && !_hasOnlineAccount) ...[
                    const Divider(height: 1),
                    ListTile(
                      key: const ValueKey('account-login-action'),
                      leading: const Icon(Icons.login),
                      title: const Text('Entrar na conta online'),
                      subtitle: Text(
                        authConfigured
                            ? 'Use outra conta para sincronizar e atualizar os acessos deste usuário'
                            : 'A conta online não está disponível nesta configuração do aplicativo',
                      ),
                      trailing: _loggingIn
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: authConfigured && !_loggingIn
                          ? _loginOnline
                          : null,
                    ),
                  ],
                  if (_hasOnlineAccount) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sair da conta'),
                      subtitle: const Text(
                        'Encerra apenas a sessão online; não apaga os dados locais',
                      ),
                      trailing: _loggingOut
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: _loggingOut ? null : _logout,
                    ),
                  ],
                ],
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
                      trackedRoute(
                        pageId: 'privacy_policy',
                        resourceId: 'privacy_policy',
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: const Text('Excluir conta e dados'),
                    subtitle: Text(
                      _hasOnlineAccount
                          ? 'Remove sua conta online e os dados privados deste dispositivo'
                          : 'Disponível quando uma conta online estiver conectada',
                    ),
                    trailing: _deletingAccount
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _hasOnlineAccount && !_deletingAccount
                        ? _deleteAccount
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Solicitar exclusão pelo site'),
                    subtitle: const Text(
                      'Alternativa para quem não consegue acessar a conta no app',
                    ),
                    onTap: _openAccountDeletionPage,
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
                      trackedRoute(
                        pageId: 'onboarding',
                        featureId: 'onboarding_replay',
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
                      trackedRoute(
                        pageId: 'support',
                        featureId: 'support',
                        builder: (_) => const ChatwootScreen(),
                      ),
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
              'Tutor TDS 1.4.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(String role) => switch (role) {
  'admin' => 'administrativo',
  'teacher' => 'docente',
  'monitor' => 'monitor',
  _ => 'estudante',
};

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
