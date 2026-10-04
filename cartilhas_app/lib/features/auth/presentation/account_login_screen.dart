import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../certificates/data/certificate_service.dart';
import '../../../widgets/responsive_body.dart';
import '../../../widgets/tds_brand_stripe.dart';
import '../data/auth_repository.dart';
import '../models/auth_session.dart';

class AccountLoginScreen extends StatefulWidget {
  const AccountLoginScreen({super.key});

  @override
  State<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

class _AccountLoginScreenState extends State<AccountLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpf = TextEditingController();
  final _password = TextEditingController();

  bool _obscurePassword = true;
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _cpf.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final session = await context.read<AuthRepository>().login(
        cpf: _cpf.text,
        password: _password.text,
      );
      _password.clear();
      if (!mounted) return;
      Navigator.of(context).pop<AuthSession>(session);
    } on AuthException catch (error) {
      _password.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Entrar no Tutor TDS')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: ResponsiveBody(
            maxWidth: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: colors.primary,
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.account_circle_outlined,
                              size: 40,
                              color: colors.onPrimary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Uma conta, acessos diferentes',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: colors.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Entre com a conta TDS que você já possui. As áreas liberadas aparecem de acordo com os vínculos confirmados pelo servidor.',
                              style: TextStyle(color: colors.onPrimary),
                            ),
                          ],
                        ),
                      ),
                      const TdsBrandStripe(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'O perfil não é escolhido nesta tela',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Participante, monitor, professor e coordenação usam o mesmo acesso. O aplicativo mostra somente as ferramentas autorizadas para sua conta e para cada turma ou programa.',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _RoleChip(
                                  icon: Icons.school_outlined,
                                  label: 'Participante',
                                ),
                                _RoleChip(
                                  icon: Icons.visibility_outlined,
                                  label: 'Monitor',
                                ),
                                _RoleChip(
                                  icon: Icons.groups_outlined,
                                  label: 'Professor',
                                ),
                                _RoleChip(
                                  icon: Icons.admin_panel_settings_outlined,
                                  label: 'Coordenação',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Dados da conta',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'CPF e senha são usados somente para autenticar este acesso e não ficam gravados nesta tela.',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              key: const ValueKey('account-login-cpf'),
                              controller: _cpf,
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                labelText: 'CPF da conta',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              inputFormatters: [
                                MaskTextInputFormatter(mask: '###.###.###-##'),
                              ],
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  CertificateService.isValidCpf(value ?? '')
                                  ? null
                                  : 'Informe um CPF válido',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('account-password'),
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _obscurePassword,
                              enableSuggestions: false,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Mostrar senha'
                                      : 'Ocultar senha',
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => (value?.length ?? 0) < 12
                                  ? 'Use pelo menos 12 caracteres'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _errorMessage!,
                                  key: const ValueKey('account-error'),
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                            if (_busy) ...[
                              const SizedBox(height: 16),
                              const LinearProgressIndicator(),
                              const SizedBox(height: 8),
                              const Text(
                                'Confirmando acesso...',
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 20),
                            Text(
                              'Sem internet? Volte e continue no modo local. Recursos de gestão e sincronização exigem conta online.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.login),
            label: const Text('Entrar na conta'),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(label));
}
