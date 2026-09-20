import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../certificates/data/certificate_service.dart';
import '../data/auth_repository.dart';
import '../models/auth_session.dart';

/// Fluxo único de reautenticação. CPF e senha permanecem apenas na memória
/// enquanto o diálogo está aberto; somente os tokens retornados são salvos.
Future<AuthSession?> showAccountLoginDialog(BuildContext context) async {
  final auth = context.read<AuthRepository>();
  final formKey = GlobalKey<FormState>();
  var cpfValue = '';
  var passwordValue = '';
  var obscurePassword = true;
  var busy = false;
  String? errorMessage;

  return showDialog<AuthSession>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> submit() async {
          if (!formKey.currentState!.validate() || busy) return;
          setDialogState(() {
            busy = true;
            errorMessage = null;
          });
          try {
            final session = await auth.login(
              cpf: cpfValue,
              password: passwordValue,
            );
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
          title: const Text('Entrar na conta'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Use seu CPF e sua senha. O CPF e a senha não ficam salvos neste acesso.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('account-login-cpf'),
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
                      onChanged: (value) => cpfValue = value,
                      validator: (value) =>
                          CertificateService.isValidCpf(value ?? '')
                          ? null
                          : 'Informe um CPF válido',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('account-password'),
                      obscureText: obscurePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.password],
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => submit(),
                    ),
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
                      const Text('Entrando...', textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: busy ? null : submit,
              child: const Text('Entrar na conta'),
            ),
          ],
        );
      },
    ),
  );
}
