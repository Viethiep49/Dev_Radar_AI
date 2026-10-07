import 'package:equatable/equatable.dart';

import 'repo_model.dart';

/// Short repo info embedded in collections, notes, learning items and watchlist
/// (backend schema RepoBrief).
class RepoBriefModel extends Equatable {
  final int id;
  final String fullName;
  final String owner;
  final String name;
  final String? description;
  final String? language;
  final int stars;
  final String? ownerAvatarUrl;

  const RepoBriefModel({
    required this.id,
    required this.fullName,
    required this.owner,
    required this.name,
    this.description,
    this.language,
    this.stars = 0,
    this.ownerAvatarUrl,
  });

  factory RepoBriefModel.fromJson(Map<String, dynamic> json) {
    return RepoBriefModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      language: json['language'] as String?,
      stars: json['stars'] as int? ?? 0,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'owner': owner,
        'name': name,
        'description': description,
        'language': language,
        'stars': stars,
        'owner_avatar_url': ownerAvatarUrl,
      };

  /// Partial RepoModel so screens that take a RepoModel (detail, chat) can open
  /// right away; the detail screen then loads the full data by id.
  RepoModel toRepoModel() => RepoModel(
        id: id,
        githubId: 0,
        fullName: fullName,
        owner: owner,
        name: name,
        description: description,
        htmlUrl: 'https://github.com/$fullName',
        language: language,
        topics: const [],
        stars: stars,
        forks: 0,
        openIssues: 0,
        ownerAvatarUrl: ownerAvatarUrl,
      );

  @override
  List<Object?> get props => [id, fullName, owner, name, description, language, stars, ownerAvatarUrl];
}
