import 'package:equatable/equatable.dart';

import 'repo_brief_model.dart';

/// Learning status of a repo: Muốn thử -> Đang tìm hiểu -> Đã sử dụng.
/// [apiValue] is the value used by the backend ("want_to_try" | "learning" | "used").
enum LearningStatus {
  wantToTry('want_to_try', 'Muốn thử'),
  learning('learning', 'Đang tìm hiểu'),
  used('used', 'Đã sử dụng');

  final String apiValue;
  final String label;

  const LearningStatus(this.apiValue, this.label);

  static LearningStatus? fromApi(String? value) {
    for (final status in LearningStatus.values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}

/// A repo on the user's learning path (backend LearningOut).
class LearningItemModel extends Equatable {
  final int id;
  final int repoId;
  final LearningStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final RepoBriefModel repo;

  const LearningItemModel({
    required this.id,
    required this.repoId,
    required this.status,
    this.startedAt,
    this.completedAt,
    required this.updatedAt,
    required this.repo,
  });

  factory LearningItemModel.fromJson(Map<String, dynamic> json) {
    return LearningItemModel(
      id: json['id'] as int,
      repoId: json['repo_id'] as int,
      status: LearningStatus.fromApi(json['status'] as String?) ?? LearningStatus.wantToTry,
      startedAt: _date(json['started_at']),
      completedAt: _date(json['completed_at']),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      repo: RepoBriefModel.fromJson(json['repo'] as Map<String, dynamic>),
    );
  }

  static DateTime? _date(dynamic value) => value == null ? null : DateTime.parse(value as String);

  @override
  List<Object?> get props => [id, repoId, status, startedAt, completedAt, updatedAt, repo];
}
