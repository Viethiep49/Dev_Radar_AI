import 'package:equatable/equatable.dart';

import 'repo_brief_model.dart';

/// A watched repo (backend WatchlistItemOut).
class WatchlistItemModel extends Equatable {
  final RepoBriefModel repo;
  final DateTime watchedAt;

  /// Latest release seen by the backend's release check, null until there is one.
  final String? latestReleaseTag;
  final DateTime? latestReleaseAt;

  const WatchlistItemModel({
    required this.repo,
    required this.watchedAt,
    this.latestReleaseTag,
    this.latestReleaseAt,
  });

  factory WatchlistItemModel.fromJson(Map<String, dynamic> json) {
    final release = json['latest_release'] as Map<String, dynamic>?;
    final publishedAt = release?['published_at'] as String?;
    return WatchlistItemModel(
      repo: RepoBriefModel.fromJson(json['repo'] as Map<String, dynamic>),
      watchedAt: DateTime.parse(json['watched_at'] as String),
      latestReleaseTag: release?['tag_name'] as String?,
      latestReleaseAt: publishedAt == null ? null : DateTime.parse(publishedAt),
    );
  }

  @override
  List<Object?> get props => [repo, watchedAt, latestReleaseTag, latestReleaseAt];
}
