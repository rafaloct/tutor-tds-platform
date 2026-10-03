import 'package:flutter/material.dart';
import '../../../widgets/tds_brand_stripe.dart';
import '../../analytics/telemetry_route.dart';
import '../data/course_editor_repository.dart';
import '../models/course_editor_models.dart';
import 'course_editor_screen.dart';
import 'message_editor_dialog.dart';
import 'material_editor_dialog.dart';

class CourseStructureEditor extends StatefulWidget {
  const CourseStructureEditor({
    super.key,
    required this.gateway,
    required this.courseId,
    required this.versionId,
  });
  final CourseEditorGateway gateway;
  final String courseId;
  final String versionId;
  @override
  State<CourseStructureEditor> createState() => _CourseStructureEditorState();
}

class _CourseStructureEditorState extends State<CourseStructureEditor> {
  EditableCourse? _course;
  List<Map<String, dynamic>> _versions = [];
  int _versionSelectionEpoch = 0;
  bool _busy = true;
  bool _dirty = false;
  bool _conflict = false;
  String? _error;
  final _title = TextEditingController();
  final _author = TextEditingController();
  bool get _editable => _course?.canEdit == true && !_busy && !_conflict;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  void _accept(EditableCourse course) {
    if (course.data['versions'] is List) {
      _versions = (course.data['versions'] as List)
          .cast<Map<String, dynamic>>();
    }
    _versions =
        [
          {
            'version_id': course.versionId,
            'version_number': course.versionNumber,
            'status': course.status,
          },
          ..._versions.where((v) => v['version_id'] != course.versionId),
        ]..sort(
          (a, b) => (b['version_number'] as int).compareTo(
            a['version_number'] as int,
          ),
        );
    _course = course;
    _title.text = course.title;
    _author.text = course.author;
    _dirty = false;
    _conflict = false;
  }

  Future<void> _run(Future<EditableCourse> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final course = await action();
      if (mounted) setState(() => _accept(course));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = editorError(e);
          _conflict = _conflict || (e is CourseEditorException && e.conflict);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (_dirty &&
        !await _confirm(
          'Recarregar versão?',
          'Suas alterações não salvas serão descartadas.',
        )) {
      return;
    }
    await _run(
      () => widget.gateway.course(
        widget.courseId,
        versionId: _course?.versionId ?? widget.versionId,
      ),
    );
  }

  Future<void> _selectVersion(String? versionId) async {
    if (versionId == null || versionId == _course?.versionId) return;
    setState(() => _versionSelectionEpoch++);
    if (_dirty &&
        !await _confirm(
          'Trocar de versão?',
          'Suas alterações não salvas serão descartadas.',
        )) {
      return;
    }
    await _run(
      () => widget.gateway.course(widget.courseId, versionId: versionId),
    );
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _leave() async {
    if (!_busy &&
        (!_dirty ||
            await _confirm(
              'Sair sem salvar?',
              'As alterações feitas nesta tela serão descartadas.',
            )) &&
        mounted) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _change(VoidCallback mutation) => setState(() {
    mutation();
    _dirty = true;
  });
  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _author.text.trim().isEmpty) {
      setState(() => _error = 'Preencha título e autoria.');
      return;
    }
    _course!.data['title'] = _title.text.trim();
    _course!.data['author'] = _author.text.trim();
    await _run(() => widget.gateway.save(_course!));
  }

  Future<void> _transition(String action, String label) async {
    final validation = _course!.releaseValidationError;
    if (action != 'archive' && validation != null) {
      setState(() => _error = validation);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }
    if (!await _confirm(
      '$label?',
      action == 'publish'
          ? 'Esta versão ficará disponível no catálogo deste ambiente. Matrículas existentes conservam sua versão.'
          : 'Confirmar a mudança de estado desta versão?',
    )) {
      return;
    }
    await _run(() => widget.gateway.transition(_course!, action));
  }

  Future<void> _module([Map<String, dynamic>? section]) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ModuleDialog(title: section?['title'] as String? ?? ''),
    );
    if (value == null || !mounted) return;
    _change(() {
      if (section != null) {
        section['title'] = value;
      } else {
        _course!.data.putIfAbsent('sections', () => <dynamic>[]);
        _course!.sections.add({
          'id': newEditorId('module'),
          'title': value,
          'messages': <dynamic>[],
        });
      }
    });
  }

  Future<void> _message(Map<String, dynamic> section, [int? index]) async {
    final messages = section['messages'] as List;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MessageEditorDialog(
        message: index == null ? null : messages[index] as Map<String, dynamic>,
      ),
    );
    if (result != null && mounted) {
      _change(() {
        if (index == null) {
          messages.add(result);
        } else {
          messages[index] = result;
        }
      });
    }
  }

  Future<void> _remove(List<dynamic> items, int index, String label) async {
    if (await _confirm(
          'Remover $label?',
          'A remoção será aplicada quando você salvar o rascunho.',
        ) &&
        mounted) {
      _change(() => items.removeAt(index));
    }
  }

  Future<void> _material(Map<String, dynamic> section, [int? index]) async {
    final materials = section['materials'] as List? ?? <dynamic>[];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MaterialEditorDialog(
        material: index == null
            ? null
            : materials[index] as Map<String, dynamic>,
      ),
    );
    if (result != null && mounted) {
      _change(() {
        if (index == null) {
          materials.add(result);
        } else {
          materials[index] = result;
        }
        section['materials'] = materials;
      });
    }
  }

  void _move(List<dynamic> items, int index, int direction) => _change(() {
    final item = items.removeAt(index);
    items.insert(index + direction, item);
  });
  @override
  Widget build(BuildContext context) {
    final course = _course;
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar estrutura'),
          actions: [
            IconButton(
              onPressed: _busy ? null : _reload,
              tooltip: 'Recarregar versão',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const TdsBrandStripe(),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_conflict)
              OutlinedButton(
                onPressed: _busy ? null : _reload,
                child: const Text('Recarregar versão do servidor'),
              ),
            if (course != null) ...[
              if (_versions.length > 1) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('${course.versionId}:$_versionSelectionEpoch'),
                  initialValue: course.versionId,
                  decoration: const InputDecoration(
                    labelText: 'Versão do curso',
                  ),
                  items: _versions
                      .map(
                        (v) => DropdownMenuItem<String>(
                          value: v['version_id'] as String,
                          child: Text(
                            'Versão ${v['version_number']} • ${_statusLabel(v['status'] as String)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy ? null : _selectVersion,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                '${course.statusLabel} • Versão ${course.versionNumber} • Revisão ${course.revision}',
              ),
              if (_dirty) const Text('Alterações não salvas'),
              if (!course.canEdit)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Esta versão está disponível somente para leitura.',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: _editable,
                decoration: const InputDecoration(labelText: 'Título do curso'),
                onChanged: (_) => _change(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _author,
                enabled: _editable,
                decoration: const InputDecoration(labelText: 'Autoria'),
                onChanged: (_) => _change(() {}),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < course.sections.length; i++)
                _section(course.sections[i] as Map<String, dynamic>, i),
              if (course.canEdit)
                OutlinedButton.icon(
                  onPressed: _editable ? () => _module() : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar módulo'),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (course.canEdit)
                    FilledButton(
                      onPressed: _editable && _dirty ? _save : null,
                      child: const Text('Salvar rascunho'),
                    ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            trackedRoute(
                              pageId: 'course_editor_preview',
                              featureId: 'course_editor',
                              builder: (_) => _CoursePreview(
                                title: _title.text,
                                author: _author.text,
                                sections: course.sections,
                              ),
                            ),
                          ),
                    child: const Text('Pré-visualizar'),
                  ),
                  if (course.canSubmit)
                    FilledButton(
                      onPressed: _busy || _dirty || _conflict
                          ? null
                          : () => _transition('submit', 'Enviar para revisão'),
                      child: const Text('Enviar para revisão'),
                    ),
                  if (course.canPublish)
                    FilledButton(
                      onPressed: _busy || _dirty || _conflict
                          ? null
                          : () => _transition('publish', 'Publicar versão'),
                      child: const Text('Publicar'),
                    ),
                  if (course.canArchive)
                    OutlinedButton(
                      onPressed: _busy || _dirty || _conflict
                          ? null
                          : () => _transition('archive', 'Arquivar versão'),
                      child: const Text('Arquivar'),
                    ),
                  if (course.canFork)
                    OutlinedButton(
                      onPressed: _busy || _dirty || _conflict
                          ? null
                          : () => _run(() => widget.gateway.fork(course)),
                      child: const Text('Criar nova versão'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(Map<String, dynamic> section, int index) {
    final messages = section['messages'] as List<dynamic>;
    final materials = section['materials'] as List? ?? <dynamic>[];
    return Card(
      key: ValueKey(section['id']),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Módulo ${index + 1}: ${section['title']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_course!.canEdit)
              Wrap(
                children: [
                  TextButton(
                    onPressed: _editable ? () => _module(section) : null,
                    child: const Text('Renomear'),
                  ),
                  IconButton(
                    tooltip: 'Subir módulo',
                    onPressed: _editable && index > 0
                        ? () => _move(_course!.sections, index, -1)
                        : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Descer módulo',
                    onPressed: _editable && index < _course!.sections.length - 1
                        ? () => _move(_course!.sections, index, 1)
                        : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    tooltip: 'Remover módulo',
                    onPressed: _editable
                        ? () => _remove(_course!.sections, index, 'módulo')
                        : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            for (var j = 0; j < messages.length; j++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${messages[j]['content']}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(messageTypeLabel('${messages[j]['type']}')),
                onTap: _editable ? () => _message(section, j) : null,
                trailing: _editable
                    ? PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') _message(section, j);
                          if (action == 'delete') {
                            _remove(messages, j, 'mensagem');
                          }
                          if (action == 'up') _move(messages, j, -1);
                          if (action == 'down') _move(messages, j, 1);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar mensagem'),
                          ),
                          if (j > 0)
                            const PopupMenuItem(
                              value: 'up',
                              child: Text('Subir mensagem'),
                            ),
                          if (j < messages.length - 1)
                            const PopupMenuItem(
                              value: 'down',
                              child: Text('Descer mensagem'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Remover mensagem'),
                          ),
                        ],
                      )
                    : null,
              ),
            for (var m = 0; m < materials.length; m++)
              ListTile(
                title: Text('${materials[m]['title']}'),
                subtitle: Text('Material • ${materials[m]['kind']}'),
                onTap: _editable ? () => _material(section, m) : null,
                trailing: _editable
                    ? IconButton(
                        tooltip: 'Remover material',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(materials, m, 'material'),
                      )
                    : null,
              ),
            if (_course!.canEdit)
              TextButton.icon(
                onPressed: _editable && materials.length < 50
                    ? () => _material(section)
                    : null,
                icon: const Icon(Icons.attach_file),
                label: const Text('Adicionar material'),
              ),
            if (_course!.canEdit)
              TextButton.icon(
                onPressed: _editable ? () => _message(section) : null,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Adicionar mensagem'),
              ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'draft' => 'Rascunho',
  'in_review' => 'Em revisão',
  'published' => 'Publicado',
  'archived' => 'Arquivado',
  _ => status,
};

class _ModuleDialog extends StatefulWidget {
  const _ModuleDialog({required this.title});
  final String title;
  @override
  State<_ModuleDialog> createState() => _ModuleDialogState();
}

class _ModuleDialogState extends State<_ModuleDialog> {
  late final _controller = TextEditingController(text: widget.title);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Módulo'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Título do módulo'),
        validator: requiredEditorText,
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
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Aplicar'),
      ),
    ],
  );
}

/// Deliberately has no student reader, progress repository or learning events.
class _CoursePreview extends StatelessWidget {
  const _CoursePreview({
    required this.title,
    required this.author,
    required this.sections,
  });
  final String title;
  final String author;
  final List<dynamic> sections;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pré-visualização')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TdsBrandStripe(),
        const SizedBox(height: 12),
        const Text(
          'Leitura de conferência. Não registra progresso nem respostas.',
        ),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        Text(author),
        for (final section in sections) ...[
          const SizedBox(height: 20),
          Text(
            '${section['title']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final material in section['materials'] as List? ?? [])
            ListTile(
              title: Text('${material['title']}'),
              subtitle: Text(
                '${material['kind']} • ${material['url'] ?? material['media_id']}',
              ),
            ),
          for (final message in section['messages'] as List)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      messageTypeLabel('${message['type']}'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SelectableText('${message['content']}'),
                    for (final option in message['options'] as List? ?? [])
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${option['isCorrect'] == true ? '✓ ' : '• '}${option['label']}${option['feedback'] == null ? '' : '\n${option['feedback']}'}',
                        ),
                      ),
                    if (message['feedback'] != null)
                      Text('Feedback: ${message['feedback']}'),
                    if (message['explanation'] != null)
                      Text('Explicação: ${message['explanation']}'),
                  ],
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
