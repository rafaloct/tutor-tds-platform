import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/models/auth_session.dart';
import '../features/certificates/data/certificate_service.dart';
import '../services/privacy_preferences.dart';
import '../widgets/responsive_body.dart';
import '../widgets/tds_brand_stripe.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'privacy_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  bool _privacyConsent = false;

  final phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');
  final cpfMask = MaskTextInputFormatter(mask: '###.###.###-##');

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    if (name.isNotEmpty && mounted) {
      final hasSeenPrivacyNotice = await PrivacyPreferences.hasSeenNotice();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => hasSeenPrivacyNotice
              ? const HomeScreen()
              : const PrivacyConsentScreen(),
        ),
      );
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('user_phone', _phoneController.text);
    await prefs.setString('user_cpf', _cpfController.text);
    await PrivacyPreferences.saveDecision(consent: _privacyConsent);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  Future<void> _createOnlineAccount() async {
    if (!_formKey.currentState!.validate()) return;
    final session = await _showAccountDialog(register: true);
    if (session == null || !mounted) return;
    await _saveData();
  }

  Future<void> _loginOnline() async {
    final session = await _showAccountDialog(register: false);
    if (session == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', session.user.name);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyConsentScreen()),
    );
  }

  Future<AuthSession?> _showAccountDialog({required bool register}) async {
    final auth = context.read<AuthRepository>();
    final dialogFormKey = GlobalKey<FormState>();
    var cpfValue = register ? _cpfController.text : '';
    var passwordValue = '';
    var obscurePassword = true;
    var busy = false;
    String? errorMessage;

    final result = await showDialog<AuthSession>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (!dialogFormKey.currentState!.validate() || busy) return;
            setDialogState(() {
              busy = true;
              errorMessage = null;
            });
            try {
              final session = register
                  ? await auth.register(
                      name: _nameController.text.trim(),
                      cpf: _cpfController.text,
                      phone: _phoneController.text,
                      password: passwordValue,
                    )
                  : await auth.login(cpf: cpfValue, password: passwordValue);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(session);
              }
            } on AuthException catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                busy = false;
                errorMessage = error.message;
              });
            }
          }

          return AlertDialog(
            title: Text(register ? 'Criar conta Tutor TDS' : 'Entrar na conta'),
            content: Form(
              key: dialogFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      register
                          ? 'Sua conta ajuda a sincronizar o progresso quando houver internet.'
                          : 'Use seu CPF e sua senha. O CPF não fica salvo neste acesso.',
                    ),
                    if (!register) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('account-login-cpf'),
                        initialValue: cpfValue,
                        decoration: const InputDecoration(
                          labelText: 'CPF da conta',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        inputFormatters: [
                          MaskTextInputFormatter(mask: '###.###.###-##'),
                        ],
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: (value) => cpfValue = value,
                        validator: (value) =>
                            CertificateService.isValidCpf(value ?? '')
                            ? null
                            : 'Informe um CPF válido',
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('account-password'),
                      obscureText: obscurePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: register
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: busy
                              ? null
                              : () => setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 12
                          ? 'Use pelo menos 12 caracteres'
                          : null,
                      onChanged: (value) => passwordValue = value,
                      textInputAction: register
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: register ? null : (_) => submit(),
                    ),
                    if (register) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('account-password-confirmation'),
                        obscureText: obscurePassword,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Confirme a senha',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) => value != passwordValue
                            ? 'As senhas precisam ser iguais'
                            : null,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => submit(),
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          errorMessage!,
                          key: const ValueKey('account-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        register ? 'Criando conta...' : 'Entrando...',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  register ? 'Criar conta segura' : 'Entrar na conta',
                ),
              ),
            ],
          );
        },
      ),
    );
    return result;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accountAvailable = context.read<AuthRepository>().isConfigured;
    return Scaffold(
      backgroundColor: colors.primary,
      body: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Center(
          child: ResponsiveBody(
            maxWidth: 520,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Material(
                color: colors.surface,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ColoredBox(
                        color: colors.primary,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                          child: Column(
                            children: [
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Image.asset(
                                  'assets/branding/logo_tds_fundo_branco.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Aprenda, pratique e avance',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Conteúdo TDS e ferramentas de estudo em um só lugar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const TdsBrandStripe(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Bem-vindo ao TDS',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Preencha seus dados para começar',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome completo',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) =>
                                    value!.isEmpty ? 'Obrigatório' : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'WhatsApp',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                inputFormatters: [phoneMask],
                                keyboardType: TextInputType.phone,
                                validator: (value) =>
                                    value!.length < 15 ? 'Inválido' : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _cpfController,
                                decoration: const InputDecoration(
                                  labelText: 'CPF',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                inputFormatters: [cpfMask],
                                keyboardType: TextInputType.number,
                                validator: (value) =>
                                    CertificateService.isValidCpf(value ?? '')
                                    ? null
                                    : 'Informe um CPF válido',
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _saveData(),
                              ),
                              if (accountAvailable) ...[
                                const SizedBox(height: 18),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer.withValues(
                                      alpha: 0.45,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colors.outlineVariant,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Conta online opcional',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Entre para preparar a sincronização do seu progresso ou continue usando somente este dispositivo.',
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Ao criar a conta, nome, CPF e WhatsApp são enviados à API TDS. A senha não é armazenada no aplicativo.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton.tonalIcon(
                                          onPressed: _createOnlineAccount,
                                          icon: const Icon(
                                            Icons.person_add_alt_1_outlined,
                                          ),
                                          label: const Text('Criar conta'),
                                        ),
                                        TextButton(
                                          onPressed: _loginOnline,
                                          child: const Text('Já tenho conta'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                'O cadastro fica no dispositivo. Ao emitir um certificado, você verá uma confirmação separada de privacidade.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _privacyConsent,
                                onChanged: (value) => setState(() {
                                  _privacyConsent = value ?? false;
                                }),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  'Autorizo o envio dos meus dados e do progresso à equipe TDS.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PrivacyPolicyScreen(),
                                    ),
                                  ),
                                  child: const Text(
                                    'Entenda como seus dados são usados',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _saveData,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 54),
                                ),
                                child: Text(
                                  accountAvailable
                                      ? 'Continuar neste dispositivo'
                                      : 'Entrar',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
