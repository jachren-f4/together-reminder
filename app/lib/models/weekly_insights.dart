/// Aggregated insights for a week's Journal entries.
///
/// Calculated from JournalEntry data, not stored directly.
class WeeklyInsights {
  /// Total questions explored together (from quizzes and You or Me)
  final int totalQuestions;

  /// Number of questions where answers aligned
  final int alignedAnswers;

  /// Number of days with at least one activity (0-7)
  final int daysConnected;

  /// Number of daily quests completed
  final int dailyQuestsCompleted;

  /// Number of side quests completed (Linked, Word Search)
  final int sideQuestsCompleted;

  /// Number of Steps Together completions
  final int stepsTogetherCompleted;

  /// Maximum possible days for this week (usually 7, but may be less for first week)
  final int possibleDays;

  const WeeklyInsights({
    required this.totalQuestions,
    required this.alignedAnswers,
    required this.daysConnected,
    required this.dailyQuestsCompleted,
    required this.sideQuestsCompleted,
    required this.stepsTogetherCompleted,
    this.possibleDays = 7,
  });

  /// Empty insights (for empty weeks)
  static const empty = WeeklyInsights(
    totalQuestions: 0,
    alignedAnswers: 0,
    daysConnected: 0,
    dailyQuestsCompleted: 0,
    sideQuestsCompleted: 0,
    stepsTogetherCompleted: 0,
  );

  /// Total quests completed across all categories
  int get totalQuestsCompleted =>
      dailyQuestsCompleted + sideQuestsCompleted + stepsTogetherCompleted;

  /// Alignment percentage (0.0 - 1.0)
  double get alignmentPercentage =>
      totalQuestions > 0 ? alignedAnswers / totalQuestions : 0.0;

  /// Whether the week has any activity
  bool get hasActivity => totalQuestsCompleted > 0;

  /// Connection rate (days connected / possible days)
  double get connectionRate =>
      possibleDays > 0 ? daysConnected / possibleDays : 0.0;

  /// Create insights from a list of journal entries
  factory WeeklyInsights.fromEntries(
    List<dynamic> entries, {
    int possibleDays = 7,
  }) {
    int totalQuestions = 0;
    int alignedAnswers = 0;
    int dailyQuests = 0;
    int sideQuests = 0;
    int stepsQuests = 0;
    final daysWithActivity = <int>{};

    for (final entry in entries) {
      // Track day of week
      final dayOfWeek = entry.completedAt.weekday as int;
      daysWithActivity.add(dayOfWeek);

      // Categorize entry
      switch (entry.type.toString()) {
        case 'JournalEntryType.classicQuiz':
        case 'JournalEntryType.affirmationQuiz':
        case 'JournalEntryType.welcomeQuiz':
          dailyQuests++;
          totalQuestions += (entry.alignedCount as int) + (entry.differentCount as int);
          alignedAnswers += entry.alignedCount as int;
          break;
        case 'JournalEntryType.youOrMe':
          dailyQuests++;
          totalQuestions += (entry.alignedCount as int) + (entry.differentCount as int);
          alignedAnswers += entry.alignedCount as int;
          break;
        case 'JournalEntryType.linked':
        case 'JournalEntryType.wordSearch':
          sideQuests++;
          break;
        case 'JournalEntryType.stepsTogether':
          stepsQuests++;
          break;
      }
    }

    return WeeklyInsights(
      totalQuestions: totalQuestions,
      alignedAnswers: alignedAnswers,
      daysConnected: daysWithActivity.length,
      dailyQuestsCompleted: dailyQuests,
      sideQuestsCompleted: sideQuests,
      stepsTogetherCompleted: stepsQuests,
      possibleDays: possibleDays,
    );
  }

  @override
  String toString() {
    return 'WeeklyInsights(questions: $totalQuestions, aligned: $alignedAnswers, '
        'days: $daysConnected/$possibleDays, quests: $totalQuestsCompleted)';
  }
}
