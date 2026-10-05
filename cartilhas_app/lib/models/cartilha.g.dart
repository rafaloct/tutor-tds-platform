// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cartilha.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Cartilha _$CartilhaFromJson(Map<String, dynamic> json) => Cartilha(
  id: json['id'] as String,
  title: json['title'] as String,
  author: json['author'] as String,
  sections: (json['sections'] as List<dynamic>)
      .map((e) => Section.fromJson(e as Map<String, dynamic>))
      .toList(),
  downloadUrl: json['downloadUrl'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  courseVersionId: json['course_version_id'] as String?,
  versionNumber: (json['version_number'] as num?)?.toInt(),
  classId: json['class_id'] as String?,
  legacyProgressCompatible: json['legacy_progress_compatible'] as bool? ?? true,
);

Map<String, dynamic> _$CartilhaToJson(Cartilha instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'author': instance.author,
  'sections': instance.sections,
  'downloadUrl': instance.downloadUrl,
  'thumbnailUrl': instance.thumbnailUrl,
  'course_version_id': instance.courseVersionId,
  'version_number': instance.versionNumber,
  'class_id': instance.classId,
  'legacy_progress_compatible': instance.legacyProgressCompatible,
};

Section _$SectionFromJson(Map<String, dynamic> json) => Section(
  id: json['id'] as String,
  title: json['title'] as String,
  messages: (json['messages'] as List<dynamic>)
      .map((e) => Message.fromJson(e as Map<String, dynamic>))
      .toList(),
  materials:
      (json['materials'] as List<dynamic>?)
          ?.map((e) => CourseMaterial.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$SectionToJson(Section instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'messages': instance.messages,
  'materials': instance.materials,
};

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  type: json['type'] as String,
  content: json['content'] as String,
  options: (json['options'] as List<dynamic>?)
      ?.map((e) => Option.fromJson(e as Map<String, dynamic>))
      .toList(),
  feedback: json['feedback'] as String?,
  explanation: json['explanation'] as String?,
  experience: json['experience'] == null
      ? null
      : ExperienceBlock.fromJson(json['experience'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'type': instance.type,
  'content': instance.content,
  'options': instance.options,
  'feedback': instance.feedback,
  'explanation': instance.explanation,
  'experience': instance.experience,
};

ExperienceBlock _$ExperienceBlockFromJson(Map<String, dynamic> json) =>
    ExperienceBlock(
      id: json['id'] as String,
      kind: $enumDecode(_$ExperienceKindEnumMap, json['kind']),
      objective: json['objective'] as String,
      isRequired: json['required'] as bool? ?? false,
      actionLabel: json['actionLabel'] as String?,
      ai: json['ai'] == null
          ? null
          : ExperienceAiConfig.fromJson(json['ai'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ExperienceBlockToJson(ExperienceBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$ExperienceKindEnumMap[instance.kind]!,
      'objective': instance.objective,
      'required': instance.isRequired,
      'actionLabel': instance.actionLabel,
      'ai': instance.ai,
    };

const _$ExperienceKindEnumMap = {
  ExperienceKind.scenario: 'scenario',
  ExperienceKind.reveal: 'reveal',
  ExperienceKind.reflection: 'reflection',
  ExperienceKind.actionChallenge: 'action_challenge',
};

ExperienceAiConfig _$ExperienceAiConfigFromJson(Map<String, dynamic> json) =>
    ExperienceAiConfig(starterPrompt: json['starterPrompt'] as String);

Map<String, dynamic> _$ExperienceAiConfigToJson(ExperienceAiConfig instance) =>
    <String, dynamic>{'starterPrompt': instance.starterPrompt};

Option _$OptionFromJson(Map<String, dynamic> json) => Option(
  label: json['label'] as String,
  value: json['value'] as String?,
  isCorrect: json['isCorrect'] as bool?,
  feedback: json['feedback'] as String?,
);

Map<String, dynamic> _$OptionToJson(Option instance) => <String, dynamic>{
  'label': instance.label,
  'value': instance.value,
  'isCorrect': instance.isCorrect,
  'feedback': instance.feedback,
};
