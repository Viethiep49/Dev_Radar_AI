import 'package:equatable/equatable.dart';

import 'repo_brief_model.dart';

/// A note on a repo (backend NoteOut).
class NoteModel extends Equatable {
  final int id;
  final int repoId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RepoBriefModel repo;

  const NoteModel({
    required this.id,
    required this.repoId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.repo,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] as int,
      repoId: json['repo_id'] as int,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      repo: RepoBriefModel.fromJson(json['repo'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [id, repoId, content, createdAt, updatedAt, repo];
}
