import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'privacy_screen.dart';
import '../services/privacy_preferences.dart';
import '../widgets/responsive_body.dart';
import '../widgets/tds_brand_stripe.dart';
import '../features/certificates/data/certificate_service.dart';

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
                                child: const Text(
                                  'Entrar',
                                  style: TextStyle(fontSize: 16),
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
