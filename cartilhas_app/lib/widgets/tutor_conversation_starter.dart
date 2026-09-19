import 'package:flutter/material.dart';

/// Ações locais que ajudam o estudante a começar uma conversa com intenção.
///
/// Os textos só são enviados quando a pessoa toca em uma ação; exibir este
/// componente não consome IA nem rede.
class TutorConversationStarter extends StatelessWidget {
  const TutorConversationStarter({
    super.key,
    required this.onSelected,
    this.contextLabel,
  });

  final ValueChanged<String> onSelected;
  final String? contextLabel;

  @override
  Widget build(BuildContext context) {
    final hasContext = contextLabel?.trim().isNotEmpty ?? false;
    final subject = hasContext ? 'este conteúdo' : 'um tema das cartilhas';
    final actions = <({IconData icon, String label, String prompt})>[
      (
        icon: Icons.lightbulb_outline,
        label: 'Explique de forma simples',
        prompt: 'Explique $subject de forma simples e passo a passo.',
      ),
      (
        icon: Icons.agriculture_outlined,
        label: 'Mostre um exemplo prático',
        prompt:
            'Mostre um exemplo prático de $subject aplicado à realidade do Tocantins.',
      ),
      (
        icon: Icons.quiz_outlined,
        label: 'Quero praticar',
        prompt:
            'Faça uma pergunta curta sobre $subject para eu responder e depois me dê feedback.',
      ),
    ];

    return Semantics(
      container: true,
      label: 'Sugestões para iniciar a conversa',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasContext
                  ? 'Como você quer estudar ${contextLabel!.trim()}?'
                  : 'Por onde você quer começar?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in actions)
                  ActionChip(
                    avatar: Icon(action.icon, size: 18),
                    label: Text(action.label),
                    onPressed: () => onSelected(action.prompt),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
