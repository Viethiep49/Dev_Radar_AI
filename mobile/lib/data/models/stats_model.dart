import 'package:equatable/equatable.dart';

/// GET /stats/overview
class StatsOverviewModel extends Equatable {
  final int totalRepos;
  final int wantToTry;
  final int learning;
  final int used;
  final int collectionsCount;
  final int notesCount;
  final int completedThisWeek;

  const StatsOverviewModel({
    required this.totalRepos,
    required this.wantToTry,
    required this.learning,
    required this.used,
    required this.collectionsCount,
    required this.notesCount,
    required this.completedThisWeek,
  });

  factory StatsOverviewModel.fromJson(Map<String, dynamic> json) {
    final byStatus = json['by_status'] as Map<String, dynamic>? ?? const {};
    return StatsOverviewModel(
      totalRepos: json['total_repos'] as int? ?? 0,
      wantToTry: byStatus['want_to_try'] as int? ?? 0,
      learning: byStatus['learning'] as int? ?? 0,
      used: byStatus['used'] as int? ?? 0,
      collectionsCount: json['collections_count'] as int? ?? 0,
      notesCount: json['notes_count'] as int? ?? 0,
      completedThisWeek: json['completed_this_week'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [totalRepos, wantToTry, learning, used, collectionsCount, notesCount, completedThisWeek];
}

/// One item of GET /stats/weekly: repos started / completed in the week starting [weekStart] (Monday).
class WeeklyStatModel extends Equatable {
  final DateTime weekStart;
  final int completed;
  final int started;

  const WeeklyStatModel({required this.weekStart, required this.completed, required this.started});

  factory WeeklyStatModel.fromJson(Map<String, dynamic> json) {
    return WeeklyStatModel(
      weekStart: DateTime.parse(json['week_start'] as String),
      completed: json['completed'] as int? ?? 0,
      started: json['started'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [weekStart, completed, started];
}

/// One item of GET /stats/languages.
class LanguageStatModel extends Equatable {
  final String language;
  final int count;

  const LanguageStatModel({required this.language, required this.count});

  factory LanguageStatModel.fromJson(Map<String, dynamic> json) {
    return LanguageStatModel(
      language: json['language'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [language, count];
}
