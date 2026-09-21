import 'dart:convert';
import 'dart:math';

Map<String, dynamic> copyEditorJson(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

String newEditorId(String prefix) {
  final random = Random.secure();
  return '${prefix}_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

class EditorProgram {
  const EditorProgram({
    required this.id,
    required this.name,
    required this.canCreate,
  });
  factory EditorProgram.fromJson(Map<String, dynamic> json) => EditorProgram(
    id: json['id'] as String,
    name: json['name'] as String,
    canCreate: json['can_create'] == true,
  );
  final String id;
  final String name;
  final bool canCreate;
}

/// Keeps unedited content fields, stable IDs and version IDs intact.
class EditableCourse {
  EditableCourse.fromJson(Map<String, dynamic> json)
    : data = copyEditorJson(json);
  final Map<String, dynamic> data;
  String get courseId => data['course_id'] as String;
  String get versionId => data['version_id'] as String;
  int get revision => data['revision'] as int;
  String get title => data['title'] as String? ?? '';
  String get author => data['author'] as String? ?? '';
  String get status => data['status'] as String? ?? '';
  int get versionNumber => data['version_number'] as int? ?? 1;
  bool get canEdit => status == 'draft' && data['can_edit'] == true;
  bool get canSubmit => data['can_submit'] == true;
  bool get canPublish => data['can_publish'] == true;
  bool get canArchive => data['can_archive'] == true;
  bool get canFork => data['can_fork'] == true;
  List<dynamic> get sections => data['sections'] as List<dynamic>? ?? [];
  String? get releaseValidationError {
    if (title.trim().isEmpty || author.trim().isEmpty) {
      return 'Preencha título e autoria antes de enviar ou publicar.';
    }
    if (sections.isEmpty) {
      return 'Adicione pelo menos um módulo antes de enviar ou publicar.';
    }
    for (var index = 0; index < sections.length; index++) {
      final section = sections[index] as Map<String, dynamic>;
      final messages = section['messages'] as List? ?? [];
      if (messages.isEmpty) {
        return 'O módulo ${index + 1} precisa de pelo menos uma mensagem.';
      }
      for (var item = 0; item < messages.length; item++) {
        final message = messages[item] as Map<String, dynamic>;
        final where = 'Módulo ${index + 1}, mensagem ${item + 1}';
        final type = message['type'];
        if (!{'bot', 'user', 'question', 'quiz'}.contains(type)) {
          return '$where: escolha um tipo de mensagem compatível.';
        }
        if ((message['content'] as String? ?? '').trim().isEmpty) {
          return '$where: preencha o conteúdo.';
        }
        if (type == 'bot') continue;
        final options = message['options'] as List? ?? [];
        final minimum = type == 'user' ? 1 : 2;
        if (options.length < minimum ||
            options.any((o) => (o['label'] as String? ?? '').trim().isEmpty)) {
          return '$where: adicione ${minimum == 1 ? 'uma alternativa' : 'pelo menos duas alternativas'} com texto para permitir avançar na leitura.';
        }
        if (type == 'quiz' && !options.any((o) => o['isCorrect'] == true)) {
          return '$where: marque ao menos uma alternativa correta.';
        }
      }
    }
    return null;
  }

  String get statusLabel => switch (status) {
    'draft' => 'Rascunho',
    'in_review' || 'review' => 'Em revisão',
    'published' => 'Publicado',
    'archived' => 'Arquivado',
    _ => status,
  };
  Map<String, dynamic> get revisionBody => {
    'version_id': versionId,
    'expected_revision': revision,
  };
  Map<String, dynamic> get saveBody => {
    ...revisionBody,
    'title': title,
    'author': author,
    'sections': sections,
    if (data.containsKey('downloadUrl')) 'downloadUrl': data['downloadUrl'],
    if (data.containsKey('thumbnailUrl')) 'thumbnailUrl': data['thumbnailUrl'],
  };
}
