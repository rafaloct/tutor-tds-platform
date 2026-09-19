import 'atui_models.dart';

class ATUIParser {
  static AtuiComponent parse(Map<String, dynamic> json) {
    final type = json['type'];
    final props = json['props'] ?? {};

    switch (type) {
      case 'text':
        return TextComponent(
          content: props['content'] ?? '',
          fontSize: (props['fontSize'] ?? 14).toDouble(),
          bold: props['bold'] == true,
        );
      case 'card':
        return CardComponent(
          title: props['title'] ?? '',
          content: props['content'] ?? '',
        );
      case 'button':
        return ButtonComponent(
          label: props['label'] ?? 'Botão',
          action: props['action'] ?? '',
        );
      case 'tip':
        return TipComponent(content: props['content'] ?? '');
      default:
        return UnknownComponent(type ?? 'unknown');
    }
  }
}
