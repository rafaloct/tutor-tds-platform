import 'package:flutter/material.dart';

sealed class AtuiComponent {
  const AtuiComponent();
}

class TextComponent extends AtuiComponent {
  final String content;
  final double fontSize;
  final bool bold;
  final Color? color;
  const TextComponent({
    required this.content,
    this.fontSize = 14,
    this.bold = false,
    this.color,
  });
}

class CardComponent extends AtuiComponent {
  final String title;
  final String content;
  const CardComponent({required this.title, required this.content});
}

class ButtonComponent extends AtuiComponent {
  final String label;
  final String action;
  const ButtonComponent({required this.label, required this.action});
}

class TipComponent extends AtuiComponent {
  final String content;
  const TipComponent({required this.content});
}

class UnknownComponent extends AtuiComponent {
  final String type;
  const UnknownComponent(this.type);
}
