import 'package:flutter/material.dart';
import '../../../widgets/tds_brand_stripe.dart';
import '../../analytics/telemetry_route.dart';
import '../data/course_editor_repository.dart';
import '../models/course_editor_models.dart';
import 'course_structure_editor.dart';

class CourseEditorCatalogScreen extends StatefulWidget {
  const CourseEditorCatalogScreen({super.key, required this.gateway});
  final CourseEditorGateway gateway;
  @override
  State<CourseEditorCatalogScreen> createState() =>
      _CourseEditorCatalogScreenState();
}

class _CourseEditorCatalogScreenState extends State<CourseEditorCatalogScreen> {
  List<EditorProgram> _programs = [];
  List<EditableCourse> _courses = [];
  EditorProgram? _program;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.gateway is CourseEditorRepository) {
      (widget.gateway as CourseEditorRepository).dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final programs = await widget.gateway.programs();
      final selected =
          programs.where((p) => p.id == _program?.id).firstOrNull ??
          programs.firstOrNull;
      final courses = selected == null
          ? <EditableCourse>[]
          : await widget.gateway.courses(selected.id);
      if (mounted) {
        setState(() {
          _programs = programs;
          _program = selected;
          _courses = courses;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = editorError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(EditableCourse course) async {
    await Navigator.push(
      context,
      trackedRoute(
        pageId: 'course_editor',
        featureId: 'course_editor',
        courseId: course.courseId,
        builder: (_) => CourseStructureEditor(
          gateway: widget.gateway,
          courseId: course.courseId,
          versionId: course.versionId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _NewCourseDialog(),
    );
    if (result == null || !mounted || _program == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final course = await widget.gateway.create(
        programId: _program!.id,
        courseId: result['id']!,
        title: result['title']!,
        author: result['author']!,
      );
      if (mounted) await _open(course);
    } catch (e) {
      if (mounted) setState(() => _error = editorError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Meus conteúdos'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          tooltip: 'Atualizar conteúdos',
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
        if (!_busy && _programs.isEmpty)
          const Text('Sua conta não possui programas com acesso ao editor.'),
        if (_program != null) ...[
          DropdownButtonFormField<String>(
            initialValue: _program!.id,
            decoration: const InputDecoration(labelText: 'Programa'),
            items: _programs
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                .toList(),
            onChanged: _busy
                ? null
                : (id) {
                    _program = _programs.firstWhere((p) => p.id == id);
                    _load();
                  },
          ),
          const SizedBox(height: 12),
          if (_program!.canCreate)
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text('Criar curso'),
            ),
          const SizedBox(height: 16),
          if (!_busy && _courses.isEmpty)
            const Text('Nenhum conteúdo neste programa.'),
          ..._courses.map(
            (c) => Card(
              child: ListTile(
                title: Text(c.title),
                subtitle: Text('${c.statusLabel} • Versão ${c.versionNumber}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _open(c),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

String editorError(Object error) => error is CourseEditorException
    ? error.message
    : 'Não foi possível carregar o editor. Tente novamente.';

class _NewCourseDialog extends StatefulWidget {
  const _NewCourseDialog();
  @override
  State<_NewCourseDialog> createState() => _NewCourseDialogState();
}

class _NewCourseDialogState extends State<_NewCourseDialog> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _title = TextEditingController();
  final _author = TextEditingController();
  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Criar curso'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: requiredEditorText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _author,
                decoration: const InputDecoration(labelText: 'Autoria'),
                validator: requiredEditorText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _id,
                decoration: const InputDecoration(
                  labelText: 'Código permanente',
                  helperText:
                      'Ex.: horta-comunitaria. Não poderá ser alterado.',
                  helperMaxLines: 3,
                ),
                validator: (v) =>
                    RegExp(
                      r'^[a-z0-9][a-z0-9_-]{2,79}$',
                    ).hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Use 3–80 letras minúsculas, números, - ou _.',
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
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, {
              'id': _id.text.trim(),
              'title': _title.text.trim(),
              'author': _author.text.trim(),
            });
          }
        },
        child: const Text('Criar rascunho'),
      ),
    ],
  );
}

String? requiredEditorText(String? value) =>
    value == null || value.trim().isEmpty ? 'Preencha este campo.' : null;
