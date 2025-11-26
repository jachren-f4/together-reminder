/// Brand-specific content file paths
///
/// Each brand can have its own set of content (quizzes, questions, etc.)
/// stored as JSON files in brand-specific directories.
class ContentPaths {
  final String _brandId;

  const ContentPaths(this._brandId);

  /// Base path for this brand's data files
  String get _dataPath => 'assets/brands/$_brandId/data';

  /// Base path for this brand's word lists
  String get _wordsPath => 'assets/brands/$_brandId/words';

  // ============================================
  // Quiz Content
  // ============================================

  /// Classic quiz questions (180 questions)
  String get quizQuestionsPath => '$_dataPath/quiz_questions.json';

  /// Affirmation quizzes (6 quizzes with 5-point scale)
  String get affirmationQuizzesPath => '$_dataPath/affirmation_quizzes.json';

  /// You or Me game questions (60 comparison questions)
  String get youOrMeQuestionsPath => '$_dataPath/you_or_me_questions.json';

  // ============================================
  // Word Lists (for Word Ladder game)
  // ============================================

  String get englishWordsPath => '$_wordsPath/english_words.json';
  String get finnishWordsPath => '$_wordsPath/finnish_words.json';
}
