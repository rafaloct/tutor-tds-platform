// Exemplo de referência — copie/adapte ao design system do app ou ignore.
// Consome cartilhas_app/assets/branding/generated/curiosities.json
// e variants/*_spot.jpg como companhia visual opcional.
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

const _kCuriositiesPath =
    'cartilhas_app/assets/branding/generated/curiosities.json';
const _kSpotPath =
    'cartilhas_app/assets/branding/generated/variants/curiosity_card_spot.jpg';

class Curiosity {
  final String id, question, answer, source;
  const Curiosity(this.id, this.question, this.answer, this.source);

  factory Curiosity.fromJson(Map<String, dynamic> j) =>
      Curiosity(j['id'], j['question'], j['answer'], j['source']);
}

class CuriosityDeck {
  CuriosityDeck._(this._items) : _order = List.generate(_items.length, (i) => i);
  final List<Curiosity> _items;
  final List<int> _order;
  final _rng = Random();
  int _cursor = 0;

  static Future<CuriosityDeck> load() async {
    final raw = await rootBundle.loadString(_kCuriositiesPath);
    final items = (jsonDecode(raw)['items'] as List)
        .map((e) => Curiosity.fromJson(e))
        .toList();
    return CuriosityDeck._(items);
  }

  /// Próximo cartão sem repetição até esgotar o baralho.
  Curiosity next() {
    if (_cursor >= _order.length) {
      _order.shuffle(_rng);
      _cursor = 0;
    }
    return _items[_order[_cursor++]];
  }
}

/// Cartão compacto: ilustração spot à esquerda, pergunta em destaque,
/// resposta curta e fonte. Some junto com o estado que o criou.
class CuriosityCard extends StatelessWidget {
  const CuriosityCard({super.key, required this.item, this.showImage = true});
  final Curiosity item;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(_kSpotPath, width: 72, height: 72,
                    fit: BoxFit.cover),
              ),
            if (showImage) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Você sabia?',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: const Color(0xFF093AF4))),
                  const SizedBox(height: 2),
                  Text(item.question,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(item.answer,
                      style: theme.textTheme.bodySmall,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Fonte: ${item.source}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
