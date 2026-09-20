import 'package:flutter/material.dart';

import '../services/privacy_preferences.dart';
import '../widgets/responsive_body.dart';
import 'home_screen.dart';
import '../features/analytics/telemetry_route.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e dados')),
      body: ResponsiveBody(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.shield_outlined, size: 52, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'Como o Tutor TDS usa seus dados',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const _PrivacySection(
              title: 'Dados do cadastro',
              body:
                  'No uso offline, nome e WhatsApp ficam nas preferências privadas do aplicativo; o CPF fica no armazenamento seguro protegido pelo sistema do dispositivo. Dados legados são migrados e removidos das preferências comuns. Se você escolher criar uma conta online, nome e WhatsApp são cadastrados na API TDS; o CPF é transformado em um código criptográfico e o número original não é armazenado no servidor. A senha é protegida por hash e não fica salva no aplicativo. Com sua autorização de acompanhamento, os eventos de início ou conclusão também podem ser enviados à equipe do Programa TDS. Essa autorização é independente da conta e da emissão de certificados.',
            ),
            const _PrivacySection(
              title: 'Certificados verificáveis',
              body:
                  'Quando você toca em Emitir certificado, o app pede uma confirmação específica e envia por conexão segura seu nome, CPF e a conclusão da cartilha. O servidor usa o CPF apenas para criar um código criptográfico que evita duplicidade e não armazena o número. O registro público contém nome, cartilha, data, identificador, hash e assinatura; o CPF e o WhatsApp nunca aparecem no PDF, no QR Code ou na página pública.',
            ),
            const _PrivacySection(
              title: 'Carteira no dispositivo',
              body:
                  'Os PDFs e o índice da carteira ficam na área privada do aplicativo. Eles podem ser removidos ao desinstalar o app ou limpar seus dados. Ao imprimir, exportar, compartilhar ou enviar por e-mail, você escolhe outro aplicativo e passa a controlar a cópia compartilhada. O registro público permanece no servidor para permitir a validação.',
            ),
            const _PrivacySection(
              title: 'Tutor de IA',
              body:
                  'Quando você usa o Tutor de IA, a pergunta digitada ou transcrita é enviada ao serviço de inteligência artificial do Programa TDS para gerar a resposta. CPF e WhatsApp não são incluídos nessa conversa.',
            ),
            const _PrivacySection(
              title: 'Microfone',
              body:
                  'O microfone é opcional e só é ativado depois que você toca no botão de voz e autoriza o acesso. O app usa a fala para preencher o campo de pergunta e não mantém uma gravação de áudio.',
            ),
            const _PrivacySection(
              title: 'Seus controles',
              body:
                  'Você pode continuar lendo as cartilhas sem autorizar o envio de dados pedagógicos. Também pode retirar a autorização nas Configurações e solicitar acesso, correção ou exclusão dos seus dados pelo e-mail ipexdesenvolvimento@uft.edu.br.',
            ),
            const SizedBox(height: 8),
            Text(
              'Responsável: Programa TDS - UFT/IPEX. Esta tela resume as práticas implementadas no aplicativo e deve corresponder à Política de Privacidade publicada na Play Store.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyConsentScreen extends StatelessWidget {
  const PrivacyConsentScreen({super.key});

  Future<void> _finish(BuildContext context, bool consent) async {
    await PrivacyPreferences.saveDecision(consent: consent);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      trackedRoute(pageId: 'home', builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 560,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 64,
                  color: colors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Você controla seus dados',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Se você escolheu criar uma conta online, os dados necessários ao cadastro foram enviados conforme informado nessa ação. Separadamente, para acompanhar sua formação, o Programa TDS pode receber os eventos de início e conclusão das cartilhas. Você pode continuar usando o conteúdo sem autorizar esse acompanhamento. A emissão de certificado tem uma confirmação de privacidade própria, mostrada somente quando você solicitar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    trackedRoute(
                      pageId: 'privacy_policy',
                      resourceId: 'privacy_policy',
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ler detalhes de privacidade'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => _finish(context, true),
                  child: const Text('Concordar e continuar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _finish(context, false),
                  child: const Text('Agora não'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String body;

  const _PrivacySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}
