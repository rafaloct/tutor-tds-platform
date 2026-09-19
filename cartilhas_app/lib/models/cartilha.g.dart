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
);

Map<String, dynamic> _$CartilhaToJson(Cartilha instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'author': instance.author,
  'sections': instance.sections,
  'downloadUrl': instance.downloadUrl,
  'thumbnailUrl': instance.thumbnailUrl,
};

Section _$SectionFromJson(Map<String, dynamic> json) => Section(
  id: json['id'] as String,
  title: json['title'] as String,
  messages: (json['messages'] as List<dynamic>)
      .map((e) => Message.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SectionToJson(Section instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'messages': instance.messages,
};

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  type: json['type'] as String,
  content: json['content'] as String,
  options: (json['options'] as List<dynamic>?)
      ?.map((e) => Option.fromJson(e as Map<String, dynamic>))
      .toList(),
  feedback: json['feedback'] as String?,
  explanation: json['explanation'] as String?,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'type': instance.type,
  'content': instance.content,
  'options': instance.options,
  'feedback': instance.feedback,
  'explanation': instance.explanation,
};

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
