import 'package:flutter/material.dart';

/// Explicita a fonte e os parâmetros usados antes de gerar uma atividade.
class StudyConfigurationPanel extends StatelessWidget {
  const StudyConfigurationPanel({
    super.key,
    required this.source,
    required this.controls,
  });

  final String source;
  final List<Widget> controls;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fonte: $source',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < controls.length; index++) ...[
                    if (index > 0) const SizedBox(width: 12),
                    controls[index],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudyCountSelector extends StatelessWidget {
  const StudyCountSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.label = 'Quantidade',
  });

  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            isDense: true,
            isExpanded: true,
            items: [
              for (final option in options)
                DropdownMenuItem(value: option, child: Text('$option itens')),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ),
    );
  }
}
