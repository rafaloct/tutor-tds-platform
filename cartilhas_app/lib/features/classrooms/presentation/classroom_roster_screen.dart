import 'package:flutter/material.dart';

import '../data/classroom_repository.dart';
import '../models/classroom_models.dart';

class ClassroomRosterScreen extends StatefulWidget {
  const ClassroomRosterScreen({
    super.key,
    required this.classroom,
    required this.gateway,
  });

  final ClassroomDetails classroom;
  final ClassroomRosterGateway gateway;

  @override
  State<ClassroomRosterScreen> createState() => _ClassroomRosterScreenState();
}

class _ClassroomRosterScreenState extends State<ClassroomRosterScreen> {
  final _search = TextEditingController();
  List<EligibleStudent> _students = const [];
  EligibleStudent? _selected;
  int? _nextOffset;
  String _query = '';
  String? _error;
  String? _success;
  bool _loading = true;
  bool _saving = false;

  bool get _busy => _loading || _saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _students = const [];
        _selected = null;
        _nextOffset = null;
        _query = _search.text.trim();
      }
    });
    try {
      final page = await widget.gateway.eligibleStudents(
        widget.classroom.id,
        query: _query,
        offset: more ? _nextOffset! : 0,
      );
      if (!mounted) return;
      setState(() {
        _students = more ? [..._students, ...page.students] : page.students;
        _nextOffset = page.nextOffset;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ClassroomException
              ? error.message
              : 'Não foi possível carregar os estudantes. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _include() async {
    final student = _selected;
    if (student == null || _busy) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.gateway.includeStudent(widget.classroom.id, student.userId);
      if (!mounted) return;
      setState(() => _success = '${student.name} foi incluído(a) na turma.');
      await _load();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ClassroomException
              ? error.message
              : 'Não foi possível confirmar a inclusão. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Incluir estudantes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.classroom.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecione um estudante já matriculado nesta oferta. A lista mostra apenas quem ainda não está na turma.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            enabled: !_busy,
            maxLength: 100,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Buscar por nome',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _load(),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
          if (_success != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(liveRegion: true, child: Text(_success!)),
            ),
          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => _load(),
              child: const Text('Atualizar lista'),
            ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
          if (!_loading && _error == null && _students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Nenhum estudante disponível com estes critérios. Verifique a matrícula na oferta com a administração.',
              ),
            ),
          ..._students.map(
            (student) => Card(
              child: CheckboxListTile(
                value: _selected?.userId == student.userId,
                title: Text(student.name),
                onChanged: _busy
                    ? null
                    : (checked) => setState(
                        () => _selected = checked == true ? student : null,
                      ),
              ),
            ),
          ),
          if (_nextOffset != null)
            TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Carregar mais'),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || _selected == null ? null : _include,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(_saving ? 'Incluindo…' : 'Incluir na turma'),
          ),
        ],
      ),
    ),
  );
}
