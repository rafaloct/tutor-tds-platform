import 'package:flutter/material.dart';
import '../../remote_materials/course_material.dart';
import '../models/course_editor_models.dart';

class MaterialEditorDialog extends StatefulWidget {
  const MaterialEditorDialog({super.key, this.material});
  final Map<String, dynamic>? material;
  @override
  State<MaterialEditorDialog> createState() => _MaterialEditorDialogState();
}

class _MaterialEditorDialogState extends State<MaterialEditorDialog> {
  final _form = GlobalKey<FormState>();
  late String _kind = widget.material?['kind'] as String? ?? 'pdf';
  late final _title = TextEditingController(
    text: widget.material?['title'] as String? ?? '',
  );
  late final _target = TextEditingController(
    text:
        (widget.material?['url'] ?? widget.material?['media_id']) as String? ??
        '',
  );
  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Material do módulo'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Formato'),
              items: const [
                DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                DropdownMenuItem(value: 'video', child: Text('Vídeo')),
                DropdownMenuItem(value: 'link', child: Text('Link')),
              ],
              onChanged: (value) => setState(() {
                _kind = value!;
                _target.clear();
              }),
            ),
            TextFormField(
              controller: _title,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'Título do material',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe o título.'
                  : null,
            ),
            TextFormField(
              controller: _target,
              maxLength: _kind == 'video' ? 36 : 2000,
              decoration: InputDecoration(
                labelText: _kind == 'video'
                    ? 'ID da mídia publicada'
                    : 'URL pública HTTPS',
                helperText: _kind == 'video'
                    ? 'Mídia do mesmo programa, curso e módulo.'
                    : 'Sem credenciais, query ou fragmento.',
                helperMaxLines: 3,
              ),
              validator: (value) =>
                  (_kind == 'video'
                      ? RegExp(
                          r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,35}$',
                        ).hasMatch(value?.trim() ?? '')
                      : isPublicMaterialUrl(value?.trim()))
                  ? null
                  : 'Informe um destino válido.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, <String, dynamic>{
              'id': widget.material?['id'] ?? newEditorId('material'),
              'kind': _kind,
              'title': _title.text.trim(),
              _kind == 'video' ? 'media_id' : 'url': _target.text.trim(),
            });
          }
        },
        child: const Text('Aplicar material'),
      ),
    ],
  );
}
