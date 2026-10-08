import 'package:equatable/equatable.dart';

/// One rendered roadmap video, as returned by POST /api/v1/videos/roadmap.
class RoadmapVideoModel extends Equatable {
  final String jobId;

  /// Relative, e.g. `/api/v1/videos/<jobId>`. The backend does not know its own
  /// public host, so play and share `ApiConstants.absoluteUrl(url)`.
  final String url;
  final double durationSeconds;
  final int sizeBytes;

  const RoadmapVideoModel({
    required this.jobId,
    required this.url,
    required this.durationSeconds,
    required this.sizeBytes,
  });

  factory RoadmapVideoModel.fromJson(Map<String, dynamic> json) => RoadmapVideoModel(
        jobId: json['job_id'] as String,
        url: json['url'] as String,
        durationSeconds: (json['duration_seconds'] as num).toDouble(),
        sizeBytes: json['size_bytes'] as int,
      );

  @override
  List<Object?> get props => [jobId, url, durationSeconds, sizeBytes];
}
