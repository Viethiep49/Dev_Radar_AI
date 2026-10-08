import 'package:dev_radar_ai/data/models/page_model.dart';
import 'package:dev_radar_ai/data/models/repo_model.dart';

/// JSON of one repo as returned by the backend (RepoOut).
Map<String, dynamic> repoJson(int id, {String? language = 'Dart', bool isHot = false}) => {
      'id': id,
      'github_id': 1000 + id,
      'full_name': 'owner$id/repo$id',
      'owner': 'owner$id',
      'name': 'repo$id',
      'description': 'Repo number $id',
      'html_url': 'https://github.com/owner$id/repo$id',
      'homepage': null,
      'language': language,
      'topics': ['flutter'],
      'stars': 100 * id,
      'forks': id,
      'open_issues': 0,
      'license': 'MIT',
      'owner_avatar_url': null,
      'github_created_at': '2025-01-01T00:00:00Z',
      'github_pushed_at': '2026-10-01T00:00:00Z',
      'fetched_at': '2026-10-08T00:00:00Z',
      'stars_gained_7d': id,
      'is_hot': isHot,
    };

Map<String, dynamic> pageJson(List<int> ids, {int page = 1, int limit = 20, int? total}) => {
      'items': ids.map(repoJson).toList(),
      'page': page,
      'limit': limit,
      'total': total ?? ids.length,
    };

RepoModel repoModel(int id) => RepoModel.fromJson(repoJson(id));

PageModel<RepoModel> repoPage(List<int> ids, {int page = 1, int limit = 20, int? total}) =>
    PageModel.fromJson(pageJson(ids, page: page, limit: limit, total: total), RepoModel.fromJson);

Map<String, dynamic> detailJson(
  int id, {
  bool isWatched = false,
  String? learningStatus,
  List<int> collectionIds = const [],
  bool hasSummary = true,
}) =>
    {
      ...repoJson(id),
      'readme': '# repo$id',
      'readme_available': true,
      // The backend sends null until the cron (or the on-demand endpoint) has run.
      'summary': hasSummary
          ? {
              'summary': 'A great repo',
              'quickstart': 'flutter pub add repo$id',
              'model': 'test-model',
              'created_at': '2026-10-01T00:00:00Z',
            }
          : null,
      'is_watched': isWatched,
      'learning_status': learningStatus,
      'collection_ids': collectionIds,
    };

Map<String, dynamic> chatMessageJson(int id, String role, String content) => {
      'id': id,
      'repo_id': 1,
      'role': role,
      'content': content,
      'sources': role == 'assistant'
          ? [
              {'path': 'README.md', 'excerpt': 'Install with pub'},
            ]
          : null,
      'created_at': '2026-10-08T10:00:00Z',
    };
