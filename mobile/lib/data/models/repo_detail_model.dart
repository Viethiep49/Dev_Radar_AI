import 'package:equatable/equatable.dart';

import 'learning_model.dart';
import 'repo_model.dart';

/// Full repo detail (GET /repos/{id}): the list fields ([repo]) plus README,
/// the AI summary and the current user's flags for this repo.
class RepoDetailModel extends Equatable {
  final RepoModel repo;
  final String? readme;
  final bool readmeAvailable;

  /// AI summary (null until the backend job has generated it).
  final String? summary;
  final String? quickstart;
  final String? summaryModel;

  final bool isWatched;
  final LearningStatus? learningStatus;
  final List<int> collectionIds;

  final DateTime? pushedAt;
  final DateTime? createdAt;

  const RepoDetailModel({
    required this.repo,
    this.readme,
    this.readmeAvailable = false,
    this.summary,
    this.quickstart,
    this.summaryModel,
    this.isWatched = false,
    this.learningStatus,
    this.collectionIds = const [],
    this.pushedAt,
    this.createdAt,
  });

  factory RepoDetailModel.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>?;
    return RepoDetailModel(
      repo: RepoModel.fromJson(json),
      readme: json['readme'] as String?,
      readmeAvailable: json['readme_available'] as bool? ?? false,
      summary: summary?['summary'] as String?,
      quickstart: summary?['quickstart'] as String?,
      summaryModel: summary?['model'] as String?,
      isWatched: json['is_watched'] as bool? ?? false,
      learningStatus: LearningStatus.fromApi(json['learning_status'] as String?),
      collectionIds: (json['collection_ids'] as List<dynamic>? ?? const []).map((e) => e as int).toList(),
      pushedAt: _date(json['github_pushed_at']),
      createdAt: _date(json['github_created_at']),
    );
  }

  static DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse(value as String);

  bool get hasSummary => summary != null && summary!.trim().isNotEmpty;
  bool get hasQuickstart => quickstart != null && quickstart!.trim().isNotEmpty;

  RepoDetailModel copyWith({
    bool? isWatched,
    LearningStatus? Function()? learningStatus,
    List<int>? collectionIds,
  }) {
    return RepoDetailModel(
      repo: repo,
      readme: readme,
      readmeAvailable: readmeAvailable,
      summary: summary,
      quickstart: quickstart,
      summaryModel: summaryModel,
      isWatched: isWatched ?? this.isWatched,
      learningStatus: learningStatus != null ? learningStatus() : this.learningStatus,
      collectionIds: collectionIds ?? this.collectionIds,
      pushedAt: pushedAt,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        repo,
        readme,
        readmeAvailable,
        summary,
        quickstart,
        summaryModel,
        isWatched,
        learningStatus,
        collectionIds,
        pushedAt,
        createdAt,
      ];
}
