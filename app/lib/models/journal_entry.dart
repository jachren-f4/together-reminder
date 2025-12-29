import 'package:hive/hive.dart';

part 'journal_entry.g.dart';

/// Types of activities that can appear in the Journal.
@HiveType(typeId: 31)
enum JournalEntryType {
  @HiveField(0)
  classicQuiz,

  @HiveField(1)
  affirmationQuiz,

  @HiveField(2)
  youOrMe,

  @HiveField(3)
  linked,

  @HiveField(4)
  wordSearch,

  @HiveField(5)
  stepsTogether,

  @HiveField(6)
  welcomeQuiz,
}

/// A single entry in the couple's Journal.
///
/// Represents a completed quest/game that both partners have finished.
/// Entries are grouped by week and displayed as polaroid-style cards.
@HiveType(typeId: 30)
class JournalEntry extends HiveObject {
  /// Unique identifier for this entry
  @HiveField(0)
  late String entryId;

  /// Type of activity (quiz, game, steps, etc.)
  @HiveField(1)
  late JournalEntryType type;

  /// Display title (quiz name, game type, etc.)
  @HiveField(2)
  late String title;

  /// When the activity was completed (UTC)
  @HiveField(3)
  late DateTime completedAt;

  /// Reference ID to the source data (quiz session ID, match ID, etc.)
  @HiveField(4)
  String? contentId;

  // ============================================
  // Quiz-specific fields
  // ============================================

  /// Number of questions where partners' answers aligned
  @HiveField(5, defaultValue: 0)
  int alignedCount = 0;

  /// Number of questions where partners' answers differed
  @HiveField(6, defaultValue: 0)
  int differentCount = 0;

  // ============================================
  // Game-specific fields (Linked, Word Search)
  // ============================================

  /// User's score (words found for Linked, words found for Word Search)
  @HiveField(7, defaultValue: 0)
  int userScore = 0;

  /// Partner's score
  @HiveField(8, defaultValue: 0)
  int partnerScore = 0;

  /// Total turns taken in the game
  @HiveField(9, defaultValue: 0)
  int totalTurns = 0;

  /// Number of hints user consumed
  @HiveField(10, defaultValue: 0)
  int userHintsUsed = 0;

  /// Number of hints partner consumed
  @HiveField(11, defaultValue: 0)
  int partnerHintsUsed = 0;

  // ============================================
  // Word Search specific fields
  // ============================================

  /// User's points (Word Search has both word count and points)
  @HiveField(12, defaultValue: 0)
  int userPoints = 0;

  /// Partner's points
  @HiveField(13, defaultValue: 0)
  int partnerPoints = 0;

  // ============================================
  // Winner info
  // ============================================

  /// ID of the winner (for competitive games), null for tie
  @HiveField(14)
  String? winnerId;

  // ============================================
  // Steps Together specific
  // ============================================

  /// Combined steps for the day (Steps Together)
  @HiveField(15, defaultValue: 0)
  int combinedSteps = 0;

  /// Step goal for the day
  @HiveField(16, defaultValue: 0)
  int stepGoal = 0;

  // ============================================
  // Sync status
  // ============================================

  /// Sync status: 'pending', 'synced', 'failed'
  @HiveField(17, defaultValue: 'synced')
  String syncStatus = 'synced';

  // ============================================
  // Constructors
  // ============================================

  JournalEntry();

  /// Create a quiz journal entry
  JournalEntry.quiz({
    required this.entryId,
    required this.type,
    required this.title,
    required this.completedAt,
    required this.contentId,
    required this.alignedCount,
    required this.differentCount,
  });

  /// Create a Linked game journal entry
  JournalEntry.linked({
    required this.entryId,
    required this.title,
    required this.completedAt,
    required this.contentId,
    required this.userScore,
    required this.partnerScore,
    required this.totalTurns,
    required this.userHintsUsed,
    required this.partnerHintsUsed,
    this.winnerId,
  }) : type = JournalEntryType.linked;

  /// Create a Word Search game journal entry
  JournalEntry.wordSearch({
    required this.entryId,
    required this.title,
    required this.completedAt,
    required this.contentId,
    required this.userScore,
    required this.partnerScore,
    required this.userPoints,
    required this.partnerPoints,
    required this.totalTurns,
    required this.userHintsUsed,
    required this.partnerHintsUsed,
    this.winnerId,
  }) : type = JournalEntryType.wordSearch;

  /// Create a Steps Together journal entry
  JournalEntry.steps({
    required this.entryId,
    required this.title,
    required this.completedAt,
    required this.combinedSteps,
    required this.stepGoal,
  }) : type = JournalEntryType.stepsTogether;

  // ============================================
  // Helpers
  // ============================================

  /// Whether this is a quiz-type entry
  bool get isQuiz =>
      type == JournalEntryType.classicQuiz ||
      type == JournalEntryType.affirmationQuiz ||
      type == JournalEntryType.welcomeQuiz;

  /// Whether this is a You or Me entry
  bool get isYouOrMe => type == JournalEntryType.youOrMe;

  /// Whether this is a game-type entry (Linked or Word Search)
  bool get isGame =>
      type == JournalEntryType.linked || type == JournalEntryType.wordSearch;

  /// Whether this is a Steps Together entry
  bool get isSteps => type == JournalEntryType.stepsTogether;

  /// Total questions for quiz-type entries
  int get totalQuestions => alignedCount + differentCount;

  /// Whether the scores are tied (for game entries)
  bool get isTie => isGame && userScore == partnerScore;

  /// Get display name for the entry type
  String get typeName {
    switch (type) {
      case JournalEntryType.classicQuiz:
        return 'Classic Quiz';
      case JournalEntryType.affirmationQuiz:
        return 'Affirmation Quiz';
      case JournalEntryType.welcomeQuiz:
        return 'Welcome Quiz';
      case JournalEntryType.youOrMe:
        return 'You or Me';
      case JournalEntryType.linked:
        return 'Linked';
      case JournalEntryType.wordSearch:
        return 'Word Search';
      case JournalEntryType.stepsTogether:
        return 'Steps Together';
    }
  }

  /// Get emoji for the entry type
  String get typeEmoji {
    switch (type) {
      case JournalEntryType.classicQuiz:
        return '📝';
      case JournalEntryType.affirmationQuiz:
        return '💕';
      case JournalEntryType.welcomeQuiz:
        return '🎉';
      case JournalEntryType.youOrMe:
        return '🤔';
      case JournalEntryType.linked:
        return '🔗';
      case JournalEntryType.wordSearch:
        return '🔍';
      case JournalEntryType.stepsTogether:
        return '👟';
    }
  }
}
