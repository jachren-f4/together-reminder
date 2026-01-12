import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/journal_entry.dart';
import '../models/weekly_insights.dart';
import '../models/quiz_session.dart';
import '../models/quiz_answer_detail.dart';
import '../models/you_or_me.dart';
import '../models/linked.dart';
import '../models/word_search.dart';
import 'storage_service.dart';
import 'api_client.dart';
import '../utils/logger.dart';

/// Service for managing Journal entries and weekly insights.
///
/// The Journal displays completed quests in a scrapbook/polaroid style
/// with week-based navigation (Monday-Sunday).
class JournalService {
  static final JournalService _instance = JournalService._internal();
  factory JournalService() => _instance;
  JournalService._internal();

  /// Box name for journal entries
  static const String journalBoxName = 'journal_entries';

  /// Key for first-time open flag in metadata
  static const String _firstOpenKey = 'journal_first_open';

  // ============================================
  // Week Utilities
  // ============================================

  /// Get the Monday of the week containing the given date.
  /// Uses ISO 8601 week definition (Monday = 1, Sunday = 7).
  static DateTime getMondayOfWeek(DateTime date) {
    // weekday: Monday=1, Sunday=7
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  /// Get display string: "Dec 23 - 29" or "Dec 30 - Jan 5"
  static String formatWeekRange(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    if (monday.month == sunday.month) {
      return '${DateFormat('MMM d').format(monday)} - ${sunday.day}';
    }
    return '${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d').format(sunday)}';
  }

  /// Check if we can navigate to previous week.
  /// Limit: couple creation date.
  bool canNavigateToPreviousWeek(DateTime currentWeekStart) {
    final couple = StorageService().getUser();
    if (couple == null) return false;

    // Use user creation date as proxy for couple creation
    // TODO: Add couple.createdAt field when available
    final creationWeek = getMondayOfWeek(DateTime.now().subtract(const Duration(days: 365)));
    return currentWeekStart.isAfter(creationWeek);
  }

  /// Check if we can navigate to next week.
  /// Limit: current week (can't go to future).
  bool canNavigateToNextWeek(DateTime currentWeekStart) {
    final thisWeek = getMondayOfWeek(DateTime.now());
    return currentWeekStart.isBefore(thisWeek);
  }

  /// Check if a date is the same calendar day as another (in local timezone).
  static bool isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  // ============================================
  // Entry Retrieval
  // ============================================

  /// Get all journal entries for a specific week (Monday-Sunday).
  /// Fetches from API and caches locally.
  /// Returns entries sorted by completedAt descending.
  Future<List<JournalEntry>> getEntriesForWeek(DateTime weekStart) async {
    // Format date as YYYY-MM-DD
    final startStr = DateFormat('yyyy-MM-dd').format(weekStart);

    try {
      // Fetch from API
      final response = await ApiClient().get<Map<String, dynamic>>(
        '/api/journal/week',
        queryParams: {'start': startStr},
        parser: (json) => json,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final entriesJson = data['entries'] as List<dynamic>? ?? [];

        final entries = entriesJson.map((json) {
          return _parseJournalEntry(json as Map<String, dynamic>);
        }).toList();

        // Cache entries locally
        final box = await _getJournalBox();
        for (final entry in entries) {
          await box.put(entry.entryId, entry);
        }

        Logger.debug('Fetched ${entries.length} journal entries from API',
            service: 'journal');

        return entries;
      } else {
        Logger.debug('API error, falling back to local cache: ${response.error}',
            service: 'journal');
        return await _getLocalEntriesForWeek(weekStart);
      }
    } catch (e) {
      Logger.debug('Exception fetching journal entries, using local cache: $e',
          service: 'journal');
      return await _getLocalEntriesForWeek(weekStart);
    }
  }

  /// Fallback: Get entries from local Hive cache.
  Future<List<JournalEntry>> _getLocalEntriesForWeek(DateTime weekStart) async {
    final box = await _getJournalBox();
    final weekEnd = weekStart.add(const Duration(days: 7));

    final entries = box.values.where((entry) {
      final completedAt = entry.completedAt.toLocal();
      final monday = weekStart.toLocal();
      final sunday = weekEnd.toLocal();
      return completedAt.isAfter(monday.subtract(const Duration(seconds: 1))) &&
          completedAt.isBefore(sunday);
    }).toList();

    // Sort by completedAt descending (most recent first within each day)
    entries.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    return entries;
  }

  /// Parse a journal entry from API JSON response.
  JournalEntry _parseJournalEntry(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'classicQuiz';
    final type = JournalEntryType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => JournalEntryType.classicQuiz,
    );

    final entryId = json['entryId'] as String? ?? '';
    final title = json['title'] as String? ?? '';
    final completedAt = DateTime.parse(json['completedAt'] as String);
    final contentId = json['contentId'] as String?;

    // Use appropriate factory constructor based on type
    switch (type) {
      case JournalEntryType.linked:
        return JournalEntry.linked(
          entryId: entryId,
          title: title,
          completedAt: completedAt,
          contentId: contentId,
          userScore: json['userScore'] as int? ?? 0,
          partnerScore: json['partnerScore'] as int? ?? 0,
          totalTurns: json['totalTurns'] as int? ?? 0,
          userHintsUsed: json['userHintsUsed'] as int? ?? 0,
          partnerHintsUsed: json['partnerHintsUsed'] as int? ?? 0,
          winnerId: json['winnerId'] as String?,
        );

      case JournalEntryType.wordSearch:
        return JournalEntry.wordSearch(
          entryId: entryId,
          title: title,
          completedAt: completedAt,
          contentId: contentId,
          userScore: json['userScore'] as int? ?? 0,
          partnerScore: json['partnerScore'] as int? ?? 0,
          userPoints: json['userPoints'] as int? ?? 0,
          partnerPoints: json['partnerPoints'] as int? ?? 0,
          totalTurns: json['totalTurns'] as int? ?? 0,
          userHintsUsed: json['userHintsUsed'] as int? ?? 0,
          partnerHintsUsed: json['partnerHintsUsed'] as int? ?? 0,
          winnerId: json['winnerId'] as String?,
        );

      case JournalEntryType.stepsTogether:
        return JournalEntry.steps(
          entryId: entryId,
          title: title,
          completedAt: completedAt,
          combinedSteps: json['combinedSteps'] as int? ?? 0,
          stepGoal: json['stepGoal'] as int? ?? 0,
        );

      default:
        // Quiz types (classic, affirmation, welcome, youOrMe)
        return JournalEntry.quiz(
          entryId: entryId,
          type: type,
          title: title,
          completedAt: completedAt,
          contentId: contentId,
          alignedCount: json['alignedCount'] as int? ?? 0,
          differentCount: json['differentCount'] as int? ?? 0,
        );
    }
  }

  /// Group entries by local calendar day.
  /// Returns Map with date (time stripped) as key.
  Map<DateTime, List<JournalEntry>> groupEntriesByDay(
      List<JournalEntry> entries) {
    final grouped = <DateTime, List<JournalEntry>>{};

    for (final entry in entries) {
      final localDate = entry.completedAt.toLocal();
      final dayKey = DateTime(localDate.year, localDate.month, localDate.day);

      grouped.putIfAbsent(dayKey, () => []).add(entry);
    }

    // Sort keys by date descending
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  /// Get possible days for a week (handles couple created mid-week).
  int getPossibleDaysInWeek(DateTime weekStart) {
    // TODO: Use actual couple creation date when available
    // For now, assume all 7 days are possible
    return 7;
  }

  // ============================================
  // Insights
  // ============================================

  /// Fetch weekly insights from API, fallback to local calculation.
  Future<WeeklyInsights> getWeeklyInsights(DateTime weekStart) async {
    final startStr = DateFormat('yyyy-MM-dd').format(weekStart);

    try {
      // Fetch from API
      final response = await ApiClient().get<Map<String, dynamic>>(
        '/api/journal/insights',
        queryParams: {'start': startStr},
        parser: (json) => json,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final insights = data['insights'] as Map<String, dynamic>?;

        if (insights != null) {
          return WeeklyInsights(
            totalQuestions: insights['totalQuestions'] as int? ?? 0,
            alignedAnswers: insights['alignedAnswers'] as int? ?? 0,
            daysConnected: insights['daysConnected'] as int? ?? 0,
            possibleDays: insights['possibleDays'] as int? ?? 7,
            dailyQuestsCompleted: insights['dailyQuestsCompleted'] as int? ?? 0,
            sideQuestsCompleted: insights['sideQuestsCompleted'] as int? ?? 0,
            stepsTogetherCompleted: insights['stepsTogetherCompleted'] as int? ?? 0,
          );
        }
      }
    } catch (e) {
      Logger.debug('Exception fetching insights, using local calculation: $e',
          service: 'journal');
    }

    // Fallback to local calculation
    final entries = await _getLocalEntriesForWeek(weekStart);
    final possibleDays = getPossibleDaysInWeek(weekStart);

    if (entries.isEmpty) {
      return WeeklyInsights.empty;
    }

    return WeeklyInsights.fromEntries(entries, possibleDays: possibleDays);
  }

  // ============================================
  // Detail Data (for bottom sheet)
  // ============================================

  /// Get detailed quiz answers from API for displaying in the detail sheet.
  /// Returns null if the API call fails or data is unavailable.
  Future<QuizDetailsResponse?> getQuizDetails(String matchId) async {
    try {
      final response = await ApiClient().get<Map<String, dynamic>>(
        '/api/journal/quiz/$matchId',
        parser: (json) => json,
      );

      if (response.success && response.data != null) {
        return QuizDetailsResponse.fromJson(response.data!);
      } else {
        Logger.debug('Failed to fetch quiz details: ${response.error}',
            service: 'journal');
        return null;
      }
    } catch (e) {
      Logger.debug('Exception fetching quiz details: $e', service: 'journal');
      return null;
    }
  }

  /// Get quiz session answers for displaying in the detail sheet.
  Future<QuizSession?> getQuizSession(String sessionId) async {
    return StorageService().getQuizSession(sessionId);
  }

  /// Get You or Me session for displaying in the detail sheet.
  Future<YouOrMeSession?> getYouOrMeSession(String sessionId) async {
    return StorageService().getYouOrMeSession(sessionId);
  }

  /// Get Linked match for displaying in the detail sheet.
  Future<LinkedMatch?> getLinkedMatch(String matchId) async {
    return StorageService().getLinkedMatch(matchId);
  }

  /// Get Word Search match for displaying in the detail sheet.
  Future<WordSearchMatch?> getWordSearchMatch(String matchId) async {
    return StorageService().getWordSearchMatch(matchId);
  }

  // ============================================
  // Entry Creation
  // ============================================

  /// Create a journal entry from a completed quiz session.
  Future<JournalEntry?> createEntryFromQuiz(QuizSession session) async {
    // Check if both users have answered
    if (session.answers == null || session.answers!.length < 2) return null;

    // Calculate alignment from answers
    final answerLists = session.answers!.values.toList();
    if (answerLists.length < 2) return null;

    int alignedCount = 0;
    final totalQuestions = session.questionIds.length;
    for (int i = 0; i < totalQuestions && i < answerLists[0].length && i < answerLists[1].length; i++) {
      if (answerLists[0][i] == answerLists[1][i]) {
        alignedCount++;
      }
    }

    final entry = JournalEntry.quiz(
      entryId: 'journal_${session.id}',
      type: _getQuizEntryType(session.formatType ?? 'classic'),
      title: session.quizName ?? 'Quiz',
      completedAt: session.completedAt ?? DateTime.now(),
      contentId: session.id,
      alignedCount: alignedCount,
      differentCount: totalQuestions - alignedCount,
    );

    await _saveEntry(entry);
    return entry;
  }

  /// Create a journal entry from a completed You or Me session.
  Future<JournalEntry?> createEntryFromYouOrMe(YouOrMeSession session) async {
    // Check if both users have answered all questions
    if (!session.areBothUsersAnswered()) return null;

    // Calculate alignment - compare answers from both users
    int aligned = 0;
    int different = 0;
    final answers = session.answers;
    if (answers != null && answers.length >= 2) {
      final userIds = answers.keys.toList();
      final user1Answers = answers[userIds[0]] ?? [];
      final user2Answers = answers[userIds[1]] ?? [];

      for (int i = 0; i < user1Answers.length && i < user2Answers.length; i++) {
        if (user1Answers[i].answerValue == user2Answers[i].answerValue) {
          aligned++;
        } else {
          different++;
        }
      }
    }

    final entry = JournalEntry.quiz(
      entryId: 'journal_yom_${session.id}',
      type: JournalEntryType.youOrMe,
      title: 'You or Me',
      completedAt: session.completedAt ?? DateTime.now(),
      contentId: session.id,
      alignedCount: aligned,
      differentCount: different,
    );

    await _saveEntry(entry);
    return entry;
  }

  /// Create a journal entry from a completed Linked match.
  Future<JournalEntry?> createEntryFromLinked(
      LinkedMatch match, String currentUserId) async {
    if (!match.isCompleted) return null;

    final isPlayer1 = match.player1Id == currentUserId;
    final userScore = isPlayer1 ? match.player1Score : match.player2Score;
    final partnerScore = isPlayer1 ? match.player2Score : match.player1Score;
    final userHints =
        isPlayer1 ? (2 - match.player1Vision) : (2 - match.player2Vision);
    final partnerHints =
        isPlayer1 ? (2 - match.player2Vision) : (2 - match.player1Vision);

    final entry = JournalEntry.linked(
      entryId: 'journal_linked_${match.matchId}',
      title: 'Crossword',
      completedAt: match.completedAt ?? DateTime.now(),
      contentId: match.matchId,
      userScore: userScore,
      partnerScore: partnerScore,
      totalTurns: match.turnNumber,
      userHintsUsed: userHints.clamp(0, 2),
      partnerHintsUsed: partnerHints.clamp(0, 2),
      winnerId: match.winnerId,
    );

    await _saveEntry(entry);
    return entry;
  }

  /// Create a journal entry from a completed Word Search match.
  Future<JournalEntry?> createEntryFromWordSearch(
      WordSearchMatch match, String currentUserId) async {
    if (!match.isCompleted) return null;

    final isPlayer1 = match.player1Id == currentUserId;
    final userWords =
        isPlayer1 ? match.player1WordsFound : match.player2WordsFound;
    final partnerWords =
        isPlayer1 ? match.player2WordsFound : match.player1WordsFound;
    final userPoints = isPlayer1 ? match.player1Score : match.player2Score;
    final partnerPoints = isPlayer1 ? match.player2Score : match.player1Score;
    final userHints =
        isPlayer1 ? (3 - match.player1Hints) : (3 - match.player2Hints);
    final partnerHints =
        isPlayer1 ? (3 - match.player2Hints) : (3 - match.player1Hints);

    final entry = JournalEntry.wordSearch(
      entryId: 'journal_ws_${match.matchId}',
      title: 'Word Search',
      completedAt: match.completedAt ?? DateTime.now(),
      contentId: match.matchId,
      userScore: userWords,
      partnerScore: partnerWords,
      userPoints: userPoints,
      partnerPoints: partnerPoints,
      totalTurns: match.turnNumber,
      userHintsUsed: userHints.clamp(0, 3),
      partnerHintsUsed: partnerHints.clamp(0, 3),
      winnerId: match.winnerId,
    );

    await _saveEntry(entry);
    return entry;
  }

  // ============================================
  // First-Time State
  // ============================================

  /// Check if this is the first time opening the journal.
  /// Used to show the intro animation screen.
  bool get isFirstTimeOpening {
    final box = Hive.box(StorageService.appMetadataBoxName);
    return box.get(_firstOpenKey, defaultValue: true) as bool;
  }

  /// Mark journal as opened (after first-time transition completes).
  Future<void> markAsOpened() async {
    final box = Hive.box(StorageService.appMetadataBoxName);
    await box.put(_firstOpenKey, false);
  }

  /// Reset first-time flag (for testing).
  Future<void> resetFirstTimeFlag() async {
    final box = Hive.box(StorageService.appMetadataBoxName);
    await box.delete(_firstOpenKey);
  }

  // ============================================
  // Private Helpers
  // ============================================

  Future<Box<JournalEntry>> _getJournalBox() async {
    if (Hive.isBoxOpen(journalBoxName)) {
      return Hive.box<JournalEntry>(journalBoxName);
    }
    return await Hive.openBox<JournalEntry>(journalBoxName);
  }

  Future<void> _saveEntry(JournalEntry entry) async {
    final box = await _getJournalBox();
    await box.put(entry.entryId, entry);
  }

  JournalEntryType _getQuizEntryType(String quizType) {
    switch (quizType.toLowerCase()) {
      case 'classic':
        return JournalEntryType.classicQuiz;
      case 'affirmation':
        return JournalEntryType.affirmationQuiz;
      case 'welcome':
        return JournalEntryType.welcomeQuiz;
      default:
        return JournalEntryType.classicQuiz;
    }
  }
}
