import 'package:equatable/equatable.dart';

/// A notification saved by the backend (backend NotificationOut), e.g. a new release
/// of a watched repo: type "release", data {"tag_name", "html_url"}.
class NotificationModel extends Equatable {
  final int id;
  final String type;
  final String title;
  final String? body;
  final int? repoId;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.repoId,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      repoId: json['repo_id'] as int?,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        type: type,
        title: title,
        body: body,
        repoId: repoId,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  String? get releaseTag => data?['tag_name'] as String?;

  @override
  List<Object?> get props => [id, type, title, body, repoId, data, isRead, createdAt];
}
