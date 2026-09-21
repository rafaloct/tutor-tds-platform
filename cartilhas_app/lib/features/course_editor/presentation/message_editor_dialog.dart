import 'package:flutter/material.dart';
import '../models/course_editor_models.dart';
import 'course_editor_screen.dart';

String messageTypeLabel(String type) => switch (type) {
  'bot' => 'Tutor',
  'user' => 'Estudante',
  'question' => 'Pergunta',
  'quiz' => 'Quiz',
  _ => type,
};

class MessageEditorDialog extends StatefulWidget {
  const MessageEditorDialog({super.key, this.message});
  final Map<String, dynamic>? message;
  @override
  State<MessageEditorDialog> createState() => _MessageEditorDialogState();
}

class _MessageEditorDialogState extends State<MessageEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> _message = copyEditorJson(
    widget.message ??
        {'id': newEditorId('content'), 'type': 'bot', 'content': ''},
  );
  late final _content = TextEditingController(
    text: _message['content'] as String? ?? '',
  );
  late final _feedback = TextEditingController(
    text: _message['feedback'] as String? ?? '',
  );
  late final _explanation = TextEditingController(
    text: _message['explanation'] as String? ?? '',
  );
  late final List<_OptionFields> _options = (_message['options'] as List? ?? [])
      .map((o) => _OptionFields(o as Map<String, dynamic>))
      .toList();
  String? _error;
  String get _type => _message['type'] as String;
  @override
  void dispose() {
    _content.dispose();
    _feedback.dispose();
    _explanation.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    if (_type == 'user' && _options.isEmpty) {
      setState(
        () => _error = 'Adicione uma alternativa para continuar a leitura.',
      );
      return;
    }
    if ((_type == 'quiz' || _type == 'question') && _options.length < 2) {
      setState(() => _error = 'Adicione pelo menos duas alternativas.');
      return;
    }
    if (_type == 'quiz' && !_options.any((o) => o.correct)) {
      setState(() => _error = 'Marque ao menos uma alternativa correta.');
      return;
    }
    _message['content'] = _content.text.trim();
    if (_message.containsKey('feedback') || _feedback.text.trim().isNotEmpty) {
      _message['feedback'] = _feedback.text.trim();
    }
    if (_message.containsKey('explanation') ||
        _explanation.text.trim().isNotEmpty) {
      _message['explanation'] = _explanation.text.trim();
    }
    if (_message.containsKey('options') || _options.isNotEmpty) {
      _message['options'] = _options.map((o) => o.toJson()).toList();
    }
    Navigator.pop(context, _message);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mensagem'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: {'bot', 'user', 'question', 'quiz', _type}
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(messageTypeLabel(type)),
                      ),
                    )
                    .toList(),
                onChanged: (type) => setState(() => _message['type'] = type!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _content,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Conteúdo'),
                validator: requiredEditorText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feedback,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Feedback (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _explanation,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Explicação (opcional)',
                ),
              ),
              if (_type != 'bot' || _options.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (var i = 0; i < _options.length; i++)
                  _option(_options[i], i),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _options.add(
                      _OptionFields({
                        'label': '',
                        'value': newEditorId('option'),
                      }),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar alternativa'),
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Aplicar mensagem')),
    ],
  );
  Widget _option(_OptionFields option, int index) => Card(
    key: ObjectKey(option),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Alternativa ${index + 1}')),
              IconButton(
                tooltip: 'Remover alternativa',
                onPressed: () => setState(() {
                  _options.removeAt(index);
                  option.dispose();
                }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextFormField(
            controller: option.label,
            decoration: const InputDecoration(
              labelText: 'Texto da alternativa',
            ),
            validator: requiredEditorText,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: option.feedback,
            decoration: const InputDecoration(
              labelText: 'Feedback da alternativa (opcional)',
            ),
          ),
          if (_type == 'quiz')
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Resposta correta'),
              value: option.correct,
              onChanged: (value) => setState(() => option.correct = value!),
            ),
        ],
      ),
    ),
  );
}

class _OptionFields {
  _OptionFields(Map<String, dynamic> source)
    : data = copyEditorJson(source),
      label = TextEditingController(text: source['label'] as String? ?? ''),
      feedback = TextEditingController(
        text: source['feedback'] as String? ?? '',
      ),
      correct = source['isCorrect'] == true;
  final Map<String, dynamic> data;
  final TextEditingController label;
  final TextEditingController feedback;
  bool correct;
  Map<String, dynamic> toJson() => {
    ...data,
    'label': label.text.trim(),
    if (data.containsKey('feedback') || feedback.text.trim().isNotEmpty)
      'feedback': feedback.text.trim(),
    if (data.containsKey('isCorrect') || correct) 'isCorrect': correct,
  };
  void dispose() {
    label.dispose();
    feedback.dispose();
  }
}
