import 'package:flutter/material.dart';

class FlashcardReviewStatus extends StatelessWidget {
  const FlashcardReviewStatus({
    super.key,
    required this.source,
    required this.remembered,
    required this.toReview,
  });

  final String source;
  final int remembered;
  final int toReview;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Autoavaliação: $remembered lembrados e $toReview para revisar. Fonte: $source.',
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fonte: $source',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text('$remembered lembrei'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.replay_outlined, size: 18),
                    label: Text('$toReview para revisar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
