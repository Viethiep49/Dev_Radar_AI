import 'package:equatable/equatable.dart';

/// The user's chosen languages and topics (GET/PUT /preferences). Used to personalise the feed.
class PreferencesModel extends Equatable {
  final List<String> languages;
  final List<String> topics;

  const PreferencesModel({this.languages = const [], this.topics = const []});

  factory PreferencesModel.fromJson(Map<String, dynamic> json) {
    return PreferencesModel(
      languages: (json['languages'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      topics: (json['topics'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {'languages': languages, 'topics': topics};

  bool get isEmpty => languages.isEmpty && topics.isEmpty;

  @override
  List<Object?> get props => [languages, topics];
}

/// One choice for the onboarding chips: a language or topic and how many repos have it.
class FilterOptionModel extends Equatable {
  final String name;
  final int count;

  const FilterOptionModel({required this.name, required this.count});

  factory FilterOptionModel.fromJson(Map<String, dynamic> json) =>
      FilterOptionModel(name: json['name'] as String? ?? '', count: json['count'] as int? ?? 0);

  @override
  List<Object?> get props => [name, count];
}

/// GET /repos/filters
class FilterOptionsModel extends Equatable {
  final List<FilterOptionModel> languages;
  final List<FilterOptionModel> topics;

  const FilterOptionsModel({this.languages = const [], this.topics = const []});

  factory FilterOptionsModel.fromJson(Map<String, dynamic> json) {
    List<FilterOptionModel> parse(String key) => (json[key] as List<dynamic>? ?? const [])
        .map((e) => FilterOptionModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return FilterOptionsModel(languages: parse('languages'), topics: parse('topics'));
  }

  @override
  List<Object?> get props => [languages, topics];
}
