/// JSON shaped like the backend responses, for collections / notes / learning tests.
library;

Map<String, dynamic> repoBriefJson(int id, {String name = 'repo'}) => {
      'id': id,
      'full_name': 'owner/$name$id',
      'owner': 'owner',
      'name': '$name$id',
      'description': 'Description $id',
      'language': 'Dart',
      'stars': 100 * id,
      'owner_avatar_url': null,
    };

Map<String, dynamic> collectionJson(int id, {String name = 'Collection', int itemCount = 0}) => {
      'id': id,
      'name': '$name $id',
      'description': 'About $id',
      'item_count': itemCount,
      'created_at': '2026-10-01T10:00:00Z',
      'updated_at': '2026-10-02T10:00:00Z',
    };

Map<String, dynamic> collectionDetailJson(int id, List<int> repoIds) => {
      ...collectionJson(id, itemCount: repoIds.length),
      'repos': [
        for (final repoId in repoIds) {...repoBriefJson(repoId), 'added_at': '2026-10-03T10:00:00Z'},
      ],
    };

Map<String, dynamic> noteJson(int id, {int repoId = 1, String content = 'Note'}) => {
      'id': id,
      'repo_id': repoId,
      'content': '$content $id',
      'created_at': '2026-10-01T10:00:00Z',
      'updated_at': '2026-10-02T10:00:00Z',
      'repo': repoBriefJson(repoId),
    };

Map<String, dynamic> learningJson(int id, {int repoId = 1, String status = 'learning'}) => {
      'id': id,
      'repo_id': repoId,
      'status': status,
      'started_at': '2026-10-01T10:00:00Z',
      'completed_at': status == 'used' ? '2026-10-05T10:00:00Z' : null,
      'updated_at': '2026-10-05T10:00:00Z',
      'repo': repoBriefJson(repoId),
    };

Map<String, dynamic> pageJson(List<Map<String, dynamic>> items, {int page = 1, int limit = 100, int? total}) => {
      'items': items,
      'page': page,
      'limit': limit,
      'total': total ?? items.length,
    };
