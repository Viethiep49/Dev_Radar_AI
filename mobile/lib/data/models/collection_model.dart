import 'package:equatable/equatable.dart';

import 'repo_brief_model.dart';

/// A user's collection (backend CollectionOut).
class CollectionModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollectionModel({
    required this.id,
    required this.name,
    this.description,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      itemCount: json['item_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, name, description, itemCount, createdAt, updatedAt];
}

/// A repo inside a collection (backend CollectionRepoOut).
class CollectionRepoModel extends Equatable {
  final RepoBriefModel repo;
  final DateTime addedAt;

  const CollectionRepoModel({required this.repo, required this.addedAt});

  factory CollectionRepoModel.fromJson(Map<String, dynamic> json) {
    return CollectionRepoModel(
      repo: RepoBriefModel.fromJson(json),
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }

  @override
  List<Object?> get props => [repo, addedAt];
}

/// Collection with its repos (backend CollectionDetailOut).
class CollectionDetailModel extends Equatable {
  final CollectionModel collection;
  final List<CollectionRepoModel> repos;

  const CollectionDetailModel({required this.collection, required this.repos});

  factory CollectionDetailModel.fromJson(Map<String, dynamic> json) {
    return CollectionDetailModel(
      collection: CollectionModel.fromJson(json),
      repos: (json['repos'] as List<dynamic>? ?? const [])
          .map((e) => CollectionRepoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [collection, repos];
}
