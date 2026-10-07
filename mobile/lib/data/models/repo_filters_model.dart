import 'package:equatable/equatable.dart';

/// Sort options of GET /repos (`sort` query parameter).
enum RepoSort {
  stars('stars', 'Nhiều sao'),
  trending('trending', 'Tăng trưởng'),
  updated('updated', 'Mới cập nhật'),
  newest('newest', 'Mới tạo');

  final String apiValue;
  final String label;

  const RepoSort(this.apiValue, this.label);
}

/// One language or topic with the number of repos (backend FilterCount).
class FilterOption extends Equatable {
  final String name;
  final int count;

  const FilterOption({required this.name, required this.count});

  factory FilterOption.fromJson(Map<String, dynamic> json) =>
      FilterOption(name: json['name'] as String? ?? '', count: json['count'] as int? ?? 0);

  @override
  List<Object?> get props => [name, count];
}

/// Options for the filter UI (GET /repos/filters).
class RepoFiltersModel extends Equatable {
  final List<FilterOption> languages;
  final List<FilterOption> topics;

  const RepoFiltersModel({this.languages = const [], this.topics = const []});

  factory RepoFiltersModel.fromJson(Map<String, dynamic> json) {
    List<FilterOption> parse(String key) => (json[key] as List<dynamic>? ?? const [])
        .map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return RepoFiltersModel(languages: parse('languages'), topics: parse('topics'));
  }

  @override
  List<Object?> get props => [languages, topics];
}

/// One day of the star chart (GET /repos/{id}/stars).
class StarPointModel extends Equatable {
  final DateTime date;
  final int stars;

  const StarPointModel({required this.date, required this.stars});

  factory StarPointModel.fromJson(Map<String, dynamic> json) => StarPointModel(
        date: DateTime.parse(json['date'] as String),
        stars: json['stars'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [date, stars];
}
