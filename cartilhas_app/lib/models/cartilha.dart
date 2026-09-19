import 'package:json_annotation/json_annotation.dart';

part 'cartilha.g.dart';

@JsonSerializable()
class Cartilha {
  final String id;
  final String title;
  final String author;
  final List<Section> sections;
  @JsonKey(name: 'downloadUrl')
  final String? downloadUrl;
  @JsonKey(name: 'thumbnailUrl')
  final String? thumbnailUrl;

  Cartilha({
    required this.id,
    required this.title,
    required this.author,
    required this.sections,
    this.downloadUrl,
    this.thumbnailUrl,
  });

  factory Cartilha.fromJson(Map<String, dynamic> json) =>
      _$CartilhaFromJson(json);
  Map<String, dynamic> toJson() => _$CartilhaToJson(this);
}

@JsonSerializable()
class Section {
  final String id;
  final String title;
  final List<Message> messages;

  Section({required this.id, required this.title, required this.messages});

  factory Section.fromJson(Map<String, dynamic> json) =>
      _$SectionFromJson(json);
  Map<String, dynamic> toJson() => _$SectionToJson(this);
}

@JsonSerializable()
class Message {
  final String type; // bot, user, question, quiz
  final String content;
  final List<Option>? options;
  final String? feedback;
  final String? explanation;

  Message({
    required this.type,
    required this.content,
    this.options,
    this.feedback,
    this.explanation,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

@JsonSerializable()
class Option {
  final String label;
  final String? value;
  final bool? isCorrect;
  final String? feedback;

  Option({required this.label, this.value, this.isCorrect, this.feedback});

  factory Option.fromJson(Map<String, dynamic> json) => _$OptionFromJson(json);
  Map<String, dynamic> toJson() => _$OptionToJson(this);
}
