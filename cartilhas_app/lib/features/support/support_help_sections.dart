import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/tds_brand_stripe.dart';

/// Conteúdo estático da Central de Ajuda: disponível offline, sem chamadas
/// de rede, dados pessoais ou eventos. Textos em pt-BR.
class SupportHelpSections {
  static const List<({String question, String answer})> faq = [
    (
      question: 'Preciso de internet para usar o suporte?',
      answer:
          'O chat e o WhatsApp precisam de conexão. As cartilhas já baixadas '
          'e esta lista de dúvidas continuam disponíveis offline.',
    ),
    (
      question: 'Em quanto tempo a equipe responde?',
      answer:
          'Normalmente em alguns minutos no horário de atendimento '
          '(segunda a sexta, 9h às 17h). Fora desse horário, a resposta chega '
          'no próximo dia útil.',
    ),
    (
      question: 'O suporte pode alterar meu progresso ou certificado?',
      answer:
          'Não. Progresso, frequência e certificados seguem as regras '
          'oficiais da coordenação. O chat é apenas um canal de atendimento.',
    ),
    (
      question: 'Posso enviar fotos ou documentos?',
      answer:
          'Sim. Pelo chat você pode anexar imagens e arquivos para explicar '
          'melhor o problema.',
    ),
    (
      question: 'Esqueci minha senha ou não consigo entrar. E agora?',
      answer:
          'Use a opção "Esqueci a senha" na tela de entrada. Se continuar '
          'com dificuldade, fale com a equipe pelo chat ou WhatsApp.',
    ),
  ];
}

/// Cabeçalho institucional: container com a marca TDS e os parceiros.
class SupportBrandHeader extends StatelessWidget {
  const SupportBrandHeader({super.key});

  static const _partners = [
    'assets/logos/logo_uft.png',
    'assets/logos/logo_ipex.png',
    'assets/logos/logo_fapto.png',
    'assets/logos/logo_cdr.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.muted.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TdsBrandStripe(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              children: [
                Image.asset(
                  'assets/branding/logo_tds_fundo_branco.png',
                  height: 64,
                  fit: BoxFit.contain,
                  semanticLabel: 'Tutor TDS',
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final path in _partners)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Image.asset(
                          path,
                          height: 26,
                          fit: BoxFit.contain,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Central de Ajuda',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
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

/// Resumo de perguntas frequentes em acordeão.
class SupportFaqSection extends StatelessWidget {
  const SupportFaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.quiz_outlined, size: 18, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              'Perguntas frequentes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.muted.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < SupportHelpSections.faq.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  title: Text(
                    SupportHelpSections.faq[i].question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        SupportHelpSections.faq[i].answer,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
