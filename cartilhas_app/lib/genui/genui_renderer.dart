import 'package:flutter/material.dart';
import 'atui_models.dart';

class GenUIRenderer extends StatelessWidget {
  final List<AtuiComponent> components;
  final Function(String)? onAction;
  final Function(String)? onError;

  const GenUIRenderer({
    super.key,
    required this.components,
    this.onAction,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: components.map((c) => _buildWidget(c, context)).toList(),
    );
  }

  Widget _buildWidget(AtuiComponent component, BuildContext context) {
    return switch (component) {
      TextComponent() => Text(
        component.content,
        style: TextStyle(
          fontSize: component.fontSize,
          fontWeight: component.bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      CardComponent() => Card(
        child: ListTile(
          title: Text(component.title),
          subtitle: Text(component.content),
        ),
      ),
      ButtonComponent() => _ReactiveButton(
        component: component,
        onAction: onAction,
      ),
      TipComponent() => Container(
        padding: const EdgeInsets.all(8),
        color: Colors.amber[100],
        child: Text(component.content),
      ),
      UnknownComponent() => _handleError(component),
    };
  }

  Widget _handleError(UnknownComponent component) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onError?.call("Erro: Componente '${component.type}' não suportado.");
    });
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.red[100],
      child: Text('Erro: ${component.type}'),
    );
  }
}

class _ReactiveButton extends StatefulWidget {
  final ButtonComponent component;
  final Function(String)? onAction;
  const _ReactiveButton({required this.component, this.onAction});
  @override
  State<_ReactiveButton> createState() => _ReactiveButtonState();
}

class _ReactiveButtonState extends State<_ReactiveButton> {
  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              await widget.onAction?.call(widget.component.action);
              if (mounted) setState(() => _isLoading = false);
            },
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.component.label),
    );
  }
}
