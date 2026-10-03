import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../certificates/data/certificate_service.dart';
import '../../profile/data/profile_data_store.dart';
import '../data/auth_repository.dart';
import '../models/auth_session.dart';
import '../models/external_auth_result.dart';

class ExternalProfileCompletionScreen extends StatefulWidget {
  const ExternalProfileCompletionScreen({
    super.key,
    required this.onboardingToken,
    this.verifiedEmail,
    this.profileDataStore,
  });

  final String onboardingToken;
  final String? verifiedEmail;
  final ProfileDataStore? profileDataStore;

  @override
  State<ExternalProfileCompletionScreen> createState() =>
      _ExternalProfileCompletionScreenState();
}

class _ExternalProfileCompletionScreenState
    extends State<ExternalProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cpf = TextEditingController();
  final _phone = TextEditingController();
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##');
  final _phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');
  late final ProfileDataStore _profileDataStore;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profileDataStore =
        widget.profileDataStore ?? SecureProfileDataStore();
  }

  @override
  void dispose() {
    _name.dispose();
    _cpf.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _persistLocalProfile() => _profileDataStore.write(
    ProfileData(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      cpf: _cpf.text.trim(),
    ),
  );

  Future<void> _finish(AuthSession session) async {
    await _persistLocalProfile();
    if (mounted) Navigator.of(context).pop(session);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context
          .read<AuthRepository>()
          .completeExternalProfile(
            onboardingToken: widget.onboardingToken,
            name: _name.text.trim(),
            cpf: _cpf.text,
            phone: _phone.text,
          );
      if (!mounted) return;
      if (result.isAuthenticated) {
        await _finish(result.session!);
        return;
      }
      if (result.status ==
          ExternalAuthStatus.existingAccountLinkRequired) {
        await _linkExisting(
          result.onboardingToken ?? widget.onboardingToken,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkExisting(String onboardingToken) async {
    var credential = '';
    var busy = false;
    String? errorMessage;
    final formKey = GlobalKey<FormState>();
    final session = await showDialog<AuthSession>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (busy || !formKey.currentState!.validate()) return;
            setDialogState(() {
              busy = true;
              errorMessage = null;
            });
            try {
              final result = await context
                  .read<AuthRepository>()
                  .linkExistingExternal(
                    onboardingToken: onboardingToken,
                    cpf: _cpf.text,
                    password: credential,
                  );
              if (result.isAuthenticated &&
                  dialogContext.mounted) {
                Navigator.of(dialogContext).pop(result.session);
                return;
              }
              throw const AuthException(
                'Não foi possível vincular a conta existente.',
              );
            } on AuthException catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                busy = false;
                errorMessage = error.message;
              });
            }
          }

          return AlertDialog(
            title: const Text('Conta Tutor já existente'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Este CPF já pertence a uma conta Tutor. '
                    'Confirme a credencial atual para vincular '
                    'Google/e-mail à mesma pessoa. Sem acesso, '
                    'procure a equipe TDS.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Senha Tutor atual',
                    ),
                    onChanged: (value) => credential = value,
                    validator: (value) => (value?.isEmpty ?? true)
                        ? 'Informe sua senha Tutor'
                        : null,
                    onFieldSubmitted: (_) => submit(),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Agora não'),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: const Text('Vincular conta'),
              ),
            ],
          );
        },
      ),
    );
    if (session != null && mounted) await _finish(session);
    if (session == null && mounted) {
      setState(
        () => _error =
            'A conta existente não foi vinculada. '
            'Use sua senha Tutor ou peça reconciliação assistida.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete seu cadastro')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Sua identidade externa foi validada. '
            'Agora complete somente os dados necessários ao Tutor TDS.',
          ),
          if (widget.verifiedEmail case final email?
              when email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('E-mail validado: $email'),
          ],
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 2
                      ? 'Informe seu nome'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cpf,
                  inputFormatters: [_cpfMask],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'CPF'),
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      CertificateService.isValidCpf(value ?? '')
                      ? null
                      : 'Informe um CPF válido',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  inputFormatters: [_phoneMask],
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone / WhatsApp',
                  ),
                  validator: (value) =>
                      (value?.replaceAll(RegExp(r'\D'), '').length ?? 0) <
                          10
                      ? 'Informe um telefone válido'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Validando...' : 'Continuar'),
          ),
        ],
      ),
    ),
  );
}
