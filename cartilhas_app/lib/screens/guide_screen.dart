import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chatwoot_screen.dart';
import '../config/app_config.dart';
import '../features/analytics/app_telemetry_service.dart';
import '../features/analytics/telemetry_route.dart';
import '../widgets/responsive_body.dart';

const _whatsappNumber = '5563993010823';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Como usar o App TDS')),
      body: ResponsiveBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero
              Center(
                child: Column(
                  children: [
                    Image.asset('assets/logos/logo_tds.png', height: 72),
                    const SizedBox(height: 12),
                    const Text(
                      'Seu tutor de bolso para aprender\nno seu ritmo, na sua realidade.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _Section(
                icon: Icons.menu_book,
                color: const Color(0xFF093AF4),
                title: 'O que são as Cartilhas?',
                body:
                    'As cartilhas são materiais educativos do Programa TDS desenvolvidos pela UFT e IPEX. '
                    'Cada uma trata de um tema — como Agricultura Sustentável, Educação Financeira ou Cooperativismo — '
                    'com linguagem simples e exemplos do Tocantins.',
              ),
              _Section(
                icon: Icons.smartphone,
                color: const Color(0xFF093AF4),
                title: 'Para que serve este app?',
                body:
                    'O app traz as cartilhas em formato de conversa interativa, como um vizinho explicando o conteúdo. '
                    'Você responde perguntas, recebe dicas práticas e pode pedir ao Tutor de IA para aprofundar qualquer assunto '
                    'com exemplos da sua própria realidade.',
              ),
              _Section(
                icon: Icons.auto_stories,
                color: const Color(0xFFF9A825),
                title: 'Como usar com a cartilha física?',
                body:
                    '1. Abra a cartilha impressa (ou o PDF) no tema que quer estudar.\n'
                    '2. Leia um bloco de conteúdo na cartilha.\n'
                    '3. Abra o mesmo tema aqui no app e avance pelas perguntas.\n'
                    '4. Quando tiver dúvida sobre algo que leu, use o botão 🤖 para perguntar ao Tutor de IA.\n'
                    '5. O tutor explica com palavras diferentes e exemplos práticos.',
              ),
              _Section(
                icon: Icons.psychology,
                color: const Color(0xFF6A1B9A),
                title: 'O que é o Tutor de IA?',
                body:
                    'É um assistente inteligente treinado exclusivamente com o conteúdo das cartilhas TDS. '
                    'Ele não inventa respostas — só explica o que está nas cartilhas, de um jeito mais fácil de entender. '
                    'Você pode digitar ou usar a voz para fazer perguntas.',
              ),
              _Section(
                icon: Icons.workspace_premium,
                color: const Color(0xFFC62828),
                title: 'Como obter o Certificado?',
                body:
                    'Ao terminar uma cartilha e responder todas as perguntas, aparece o botão '
                    '"Emitir certificado". Confirme a privacidade uma vez: o app valida o registro, '
                    'gera o PDF com QR Code e salva na sua carteira. Em "Meus certificados", você '
                    'pode selecionar um ou vários arquivos para imprimir, exportar, compartilhar ou enviar por e-mail.',
              ),
              _Section(
                icon: Icons.picture_as_pdf,
                color: const Color(0xFF093AF4),
                title: 'Baixar a Cartilha em PDF',
                body:
                    'Em cada cartilha na tela inicial há um botão azul "PDF". '
                    'Toque nele para abrir a versão completa da cartilha no Google Drive — '
                    'você pode ler, salvar ou imprimir. Para ler sem internet, salve o PDF '
                    'no aplicativo de leitura. O tempo de leitura fora do Tutor TDS não '
                    'é acompanhado pelo app.',
              ),
              _Section(
                icon: Icons.menu_book,
                color: const Color(0xFF6A1B9A),
                title: 'Glossário de Termos',
                body:
                    'Toque no ícone 📖 no topo da tela para acessar o Glossário com mais de '
                    '130 termos oficiais extraídos das 9 cartilhas. Filtre por cartilha, '
                    'busque qualquer palavra e aprofunde com o Tutor de IA.',
              ),
              _Section(
                icon: Icons.support_agent,
                color: const Color(0xFF093AF4),
                title: 'Suporte da Equipe TDS',
                body:
                    'Toque no ícone 🎧 no topo para falar diretamente com a equipe TDS. '
                    'Você pode escolher entre o Chat no próprio app ou o WhatsApp. '
                    'O atendimento é feito por pessoas reais da equipe.',
              ),

              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 16),

              // Passo a passo visual
              const Text(
                'Passo a passo rápido',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._steps.map((s) => _StepTile(step: s)),

              const SizedBox(height: 24),

              // Botão de ajuda humana
              _HelpButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _steps = [
  (
    '1',
    'Faça seu cadastro com nome, WhatsApp e CPF — só uma vez',
    Icons.person_add,
  ),
  (
    '2',
    'Escolha uma cartilha na tela inicial. Toque em PDF para baixar a versão impressa',
    Icons.list,
  ),
  ('3', 'Leia o conteúdo e responda as perguntas interativas', Icons.quiz),
  (
    '4',
    'Toque em 🤖 para perguntar ao Tutor de IA em qualquer momento',
    Icons.psychology,
  ),
  (
    '5',
    'Use o Glossário (📖) para consultar os termos de todas as cartilhas',
    Icons.menu_book,
  ),
  (
    '6',
    'Ao concluir, emita o certificado e encontre-o em Meus certificados',
    Icons.workspace_premium,
  ),
  (
    '7',
    'Precisa de ajuda? Chame a equipe TDS pelo Chat no App ou WhatsApp',
    Icons.support_agent,
  ),
];

class _StepTile extends StatelessWidget {
  final (String, String, IconData) step;
  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final (num, text, icon) = step;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF093AF4),
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _HelpButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.support_agent),
      label: const Text('Falar com a equipe TDS'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF093AF4),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => showHumanHelpSheet(context),
    );
  }
}

// Abre o bottom sheet de ajuda com 2 opções — WhatsApp ou Chat no App
void showHumanHelpSheet(BuildContext context, {String? duvida}) {
  if (AppConfig.journeyTraceabilityEnabled) {
    context
        .read<AppTelemetryService>()
        .trackFeature(featureId: 'human_help_requested')
        .catchError((Object _) => 0);
  }
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HelpSheet(duvida: duvida),
  );
}

class _HelpSheet extends StatelessWidget {
  final String? duvida;
  const _HelpSheet({this.duvida});

  Future<void> _openWhatsApp(BuildContext context) async {
    Navigator.pop(context);
    final texto = duvida != null
        ? 'Olá! Estou no App Cartilhas TDS e tenho uma dúvida: $duvida'
        : 'Olá! Preciso de ajuda com o App Cartilhas TDS.';
    final url = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent(texto)}',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
  }

  void _openChatwoot(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      trackedRoute(
        pageId: 'support',
        featureId: 'support',
        builder: (_) => const ChatwootScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Como prefere falar com a equipe?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (duvida != null)
              Text(
                'Dúvida: "$duvida"',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
            // Opção 1: Chat no App
            _OptionTile(
              icon: Icons.chat_bubble_outline,
              iconColor: const Color(0xFF093AF4),
              title: 'Chat no App',
              subtitle: 'Conversa direta com a equipe TDS aqui mesmo',
              onTap: () => _openChatwoot(context),
            ),
            const SizedBox(height: 10),
            // Opção 2: WhatsApp
            _OptionTile(
              icon: Icons.phone_in_talk,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: '+55 63 9301-0823',
              onTap: () => _openWhatsApp(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// Widget reutilizável — botão compacto de ajuda humana para outras telas
class HumanHelpButton extends StatelessWidget {
  final String? duvida;
  const HumanHelpButton({super.key, this.duvida});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.support_agent, size: 18),
      label: const Text('Ajuda humana', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF093AF4),
        side: const BorderSide(color: Color(0xFF093AF4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => showHumanHelpSheet(context, duvida: duvida),
    );
  }
}
