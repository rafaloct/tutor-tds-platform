import '../genui/atui_models.dart';

class ChatMessage {
  final String role;
  final String? text;
  final List<AtuiComponent>? components;
  final bool isError;

  ChatMessage({
    required this.role,
    this.text,
    this.components,
    this.isError = false,
  });
}
