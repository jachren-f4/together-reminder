/// Brand-specific content file paths
///
/// Each brand can have its own set of content (quizzes, questions, etc.)
/// stored as JSON files in brand-specific directories.
///
/// Supports branching content system where each activity type has
/// multiple content branches (e.g., 'lighthearted' vs 'meaningful' for quizzes).
class ContentPaths {
  final String _brandId;

  const ContentPaths(this._brandId);

  /// Base path for this brand's data files
  String get _dataPath => 'assets/brands/$_brandId/data';

  /// Base path for this brand's word lists
  String get _wordsPath => 'assets/brands/$_brandId/words';

  // ============================================
  // Legacy Paths (flat structure, backward compatible)
  // ============================================

  /// Classic quiz questions - legacy flat file
  String get quizQuestionsPath => '$_dataPath/quiz_questions.json';

  /// Affirmation quizzes - legacy flat file
  String get affirmationQuizzesPath => '$_dataPath/affirmation_quizzes.json';

  /// You or Me game questions - legacy flat file
  String get youOrMeQuestionsPath => '$_dataPath/you_or_me_questions.json';

  /// Legacy folder for migration period
  String get _legacyPath => '$_dataPath/_legacy';

  String get legacyQuizQuestionsPath => '$_legacyPath/quiz_questions.json';
  String get legacyAffirmationQuizzesPath => '$_legacyPath/affirmation_quizzes.json';
  String get legacyYouOrMeQuestionsPath => '$_legacyPath/you_or_me_questions.json';

  // ============================================
  // Branch-Aware Paths (new hierarchical structure)
  // ============================================

  /// Get classic quiz questions for a specific branch
  ///
  /// [branch] - Branch folder name (e.g., 'lighthearted', 'meaningful')
  String getClassicQuizPath(String branch) =>
      '$_dataPath/classic-quiz/$branch/questions.json';

  /// Get affirmation quizzes for a specific branch
  ///
  /// [branch] - Branch folder name (e.g., 'emotional', 'practical')
  String getAffirmationPath(String branch) =>
      '$_dataPath/affirmation/$branch/quizzes.json';

  /// Get You or Me questions for a specific branch
  ///
  /// [branch] - Branch folder name (e.g., 'playful', 'reflective')
  String getYouOrMePath(String branch) =>
      '$_dataPath/you-or-me/$branch/questions.json';

  // ============================================
  // Manifest Files
  // ============================================

  /// Get manifest file for an activity type
  ///
  /// [activity] - Activity folder name (e.g., 'classic-quiz', 'affirmation')
  String getManifestPath(String activity) =>
      '$_dataPath/$activity/manifest.json';

  String get classicQuizManifestPath => getManifestPath('classic-quiz');
  String get affirmationManifestPath => getManifestPath('affirmation');
  String get youOrMeManifestPath => getManifestPath('you-or-me');
}
