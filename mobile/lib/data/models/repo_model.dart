import 'package:equatable/equatable.dart';

class RepoModel extends Equatable {
  final int id;
  final int githubId;
  final String fullName;
  final String owner;
  final String name;
  final String? description;
  final String htmlUrl;
  final String? homepage;
  final String? language;
  final List<String> topics;
  final int stars;
  final int forks;
  final int openIssues;
  final String? license;
  final String? ownerAvatarUrl;
  final int starsGained7d;
  final bool isHot;

  const RepoModel({
    required this.id,
    required this.githubId,
    required this.fullName,
    required this.owner,
    required this.name,
    this.description,
    required this.htmlUrl,
    this.homepage,
    this.language,
    required this.topics,
    required this.stars,
    required this.forks,
    required this.openIssues,
    this.license,
    this.ownerAvatarUrl,
    this.starsGained7d = 0,
    this.isHot = false,
  });

  factory RepoModel.fromJson(Map<String, dynamic> json) {
    return RepoModel(
      id: json['id'] as int,
      githubId: json['github_id'] as int? ?? 0,
      fullName: json['full_name'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      htmlUrl: json['html_url'] as String? ?? '',
      homepage: json['homepage'] as String?,
      language: json['language'] as String?,
      topics: (json['topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      stars: json['stars'] as int? ?? 0,
      forks: json['forks'] as int? ?? 0,
      openIssues: json['open_issues'] as int? ?? 0,
      license: json['license'] as String?,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      starsGained7d: json['stars_gained_7d'] as int? ?? 0,
      isHot: json['is_hot'] as bool? ?? false,
    );
  }

  String get effectiveOwnerAvatarUrl {
    final raw = (ownerAvatarUrl != null && ownerAvatarUrl!.isNotEmpty)
        ? ownerAvatarUrl!
        : 'https://github.com/$owner.png';
    return 'https://wsrv.nl/?url=${Uri.encodeComponent(raw)}&w=120&h=120&fit=cover';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'github_id': githubId,
      'full_name': fullName,
      'owner': owner,
      'name': name,
      'description': description,
      'html_url': htmlUrl,
      'homepage': homepage,
      'language': language,
      'topics': topics,
      'stars': stars,
      'forks': forks,
      'open_issues': openIssues,
      'license': license,
      'owner_avatar_url': ownerAvatarUrl,
      'stars_gained_7d': starsGained7d,
      'is_hot': isHot,
    };
  }

  @override
  List<Object?> get props => [
        id,
        githubId,
        fullName,
        owner,
        name,
        description,
        htmlUrl,
        homepage,
        language,
        topics,
        stars,
        forks,
        openIssues,
        license,
        ownerAvatarUrl,
        starsGained7d,
        isHot,
      ];
}
