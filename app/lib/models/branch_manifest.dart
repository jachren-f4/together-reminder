/// Metadata for a content branch loaded from manifest.json
///
/// Each branch folder can contain a manifest.json that defines:
/// - Video path for intro screen
/// - Image path for quest card
/// - Fallback emoji if video fails
///
/// Example manifest.json:
/// ```json
/// {
///   "branch": "lighthearted",
///   "activityType": "classicQuiz",
///   "videoPath": "assets/brands/togetherremind/videos/classic-quiz-lighthearted.mp4",
///   "imagePath": "assets/brands/togetherremind/images/quests/classic-quiz-lighthearted.png",
///   "fallbackEmoji": "🧩"
/// }
/// ```
class BranchManifest {
  final String branch;
  final String activityType;
  final String? videoPath;
  final String? imagePath;
  final String? fallbackEmoji;
  final String? displayName;
  final String? description;

  const BranchManifest({
    required this.branch,
    required this.activityType,
    this.videoPath,
    this.imagePath,
    this.fallbackEmoji,
    this.displayName,
    this.description,
  });

  factory BranchManifest.fromJson(Map<String, dynamic> json) {
    return BranchManifest(
      branch: json['branch'] as String,
      activityType: json['activityType'] as String,
      videoPath: json['videoPath'] as String?,
      imagePath: json['imagePath'] as String?,
      fallbackEmoji: json['fallbackEmoji'] as String?,
      displayName: json['displayName'] as String?,
      description: json['description'] as String?,
    );
  }

  /// Create fallback manifest when file doesn't exist
  factory BranchManifest.fallback({
    required String branch,
    required String activityType,
    String? fallbackEmoji,
  }) {
    return BranchManifest(
      branch: branch,
      activityType: activityType,
      fallbackEmoji: fallbackEmoji ?? '💝',
      displayName: _capitalize(branch),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Map<String, dynamic> toJson() {
    return {
      'branch': branch,
      'activityType': activityType,
      if (videoPath != null) 'videoPath': videoPath,
      if (imagePath != null) 'imagePath': imagePath,
      if (fallbackEmoji != null) 'fallbackEmoji': fallbackEmoji,
      if (displayName != null) 'displayName': displayName,
      if (description != null) 'description': description,
    };
  }

  @override
  String toString() =>
      'BranchManifest(branch: $branch, activityType: $activityType, '
      'videoPath: $videoPath, imagePath: $imagePath)';
}
