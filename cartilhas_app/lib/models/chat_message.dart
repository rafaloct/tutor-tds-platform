import '../genui/atui_models.dart';

class ChatMessage {
  final String role;
  final String? text;
  final List<AtuiComponent>? components;

  ChatMessage({required this.role, this.text, this.components});
}
