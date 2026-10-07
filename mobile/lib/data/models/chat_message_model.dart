import 'package:equatable/equatable.dart';

/// A README/docs excerpt the AI answer is based on.
class ChatSourceModel extends Equatable {
  final String path;
  final String excerpt;

  const ChatSourceModel({required this.path, required this.excerpt});

  factory ChatSourceModel.fromJson(Map<String, dynamic> json) => ChatSourceModel(
        path: json['path'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
      );

  @override
  List<Object?> get props => [path, excerpt];
}

/// One chat message (backend ChatMessageOut). [id] is null for a question that
/// is shown optimistically and not saved by the backend yet.
class ChatMessageModel extends Equatable {
  final int? id;
  final String role; // "user" | "assistant"
  final String content;
  final List<ChatSourceModel> sources;
  final DateTime createdAt;

  const ChatMessageModel({
    this.id,
    required this.role,
    required this.content,
    this.sources = const [],
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as int?,
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        sources: (json['sources'] as List<dynamic>? ?? const [])
            .map((e) => ChatSourceModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  @override
  List<Object?> get props => [id, role, content, sources, createdAt];
}

/// Result of POST /chat/{repoId}: the saved question and the AI answer.
class ChatExchangeModel extends Equatable {
  final ChatMessageModel question;
  final ChatMessageModel answer;

  const ChatExchangeModel({required this.question, required this.answer});

  factory ChatExchangeModel.fromJson(Map<String, dynamic> json) => ChatExchangeModel(
        question: ChatMessageModel.fromJson(json['question'] as Map<String, dynamic>),
        answer: ChatMessageModel.fromJson(json['answer'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [question, answer];
}
