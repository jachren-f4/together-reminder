import 'package:hive_flutter/hive_flutter.dart';
import '../models/reminder.dart';
import '../models/partner.dart';
import '../models/user.dart';
import '../models/love_point_transaction.dart';
import '../models/quiz_question.dart';
import '../models/quiz_session.dart';
import '../models/badge.dart';
import '../models/quiz_expansion.dart';
import '../models/daily_quest.dart';
import '../models/quiz_progression_state.dart';
import '../models/you_or_me.dart';
import '../models/linked.dart';
import '../models/word_search.dart';
import '../models/branch_progression_state.dart';
import '../models/steps_data.dart';
import '../models/journal_entry.dart';
import '../utils/logger.dart';

class StorageService {
  static const String _remindersBox = 'reminders';
  static const String _partnerBox = 'partner';
  static const String _userBox = 'user';
  static const String _transactionsBox = 'love_point_transactions';
  static const String _quizQuestionsBox = 'quiz_questions';
  static const String _quizSessionsBox = 'quiz_sessions';
  static const String _badgesBox = 'badges';
  static const String _quizFormatsBox = 'quiz_formats';
  static const String _quizCategoriesBox = 'quiz_categories';
  static const String _quizStreaksBox = 'quiz_streaks';
  static const String _dailyPulsesBox = 'daily_pulses';
  static const String _dailyQuestsBox = 'daily_quests';
  static const String _dailyQuestCompletionsBox = 'daily_quest_completions';
  static const String _quizProgressionStatesBox = 'quiz_progression_states';
  static const String _youOrMeSessionsBox = 'you_or_me_sessions';
  static const String _youOrMeProgressionBox = 'you_or_me_progression';
  static const String _appMetadataBox = 'app_metadata';  // Untyped box for metadata
  static const String _linkedMatchesBox = 'linked_matches';
  static const String _wordSearchMatchesBox = 'word_search_matches';
  static const String _branchProgressionBox = 'branch_progression_states';
  static const String _stepsDaysBox = 'steps_days';
  static const String _stepsConnectionBox = 'steps_connection';
  static const String _journalEntriesBox = 'journal_entries';

  // Public box name for JournalService access
  static const String appMetadataBoxName = 'app_metadata';

  static Future<void> init() async {
    try {
      Logger.debug('Initializing Hive storage...', service: 'storage');
      await Hive.initFlutter();

      // Register adapters (only if not already registered)
      Logger.debug('Registering Hive adapters...', service: 'storage');
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ReminderAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PartnerAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(LovePointTransactionAdapter());
      if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(QuizQuestionAdapter());
      if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(QuizSessionAdapter());
      if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(BadgeAdapter());
      // Adapter IDs 8-12 were used by removed features (Word Ladder, Memory Flip)
      if (!Hive.isAdapterRegistered(13)) Hive.registerAdapter(QuizFormatAdapter());
      if (!Hive.isAdapterRegistered(14)) Hive.registerAdapter(QuizCategoryAdapter());
      if (!Hive.isAdapterRegistered(15)) Hive.registerAdapter(QuizStreakAdapter());
      if (!Hive.isAdapterRegistered(16)) Hive.registerAdapter(QuizDailyPulseAdapter());
      if (!Hive.isAdapterRegistered(17)) Hive.registerAdapter(DailyQuestAdapter());
      if (!Hive.isAdapterRegistered(18)) Hive.registerAdapter(DailyQuestCompletionAdapter());
      if (!Hive.isAdapterRegistered(19)) Hive.registerAdapter(QuizProgressionStateAdapter());
      if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(YouOrMeQuestionAdapter());
      if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(YouOrMeAnswerAdapter());
      if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(YouOrMeSessionAdapter());
      if (!Hive.isAdapterRegistered(23)) Hive.registerAdapter(LinkedMatchAdapter());
      if (!Hive.isAdapterRegistered(24)) Hive.registerAdapter(WordSearchFoundWordAdapter());
      if (!Hive.isAdapterRegistered(25)) Hive.registerAdapter(WordSearchMatchAdapter());
      if (!Hive.isAdapterRegistered(26)) Hive.registerAdapter(BranchProgressionStateAdapter());
      if (!Hive.isAdapterRegistered(27)) Hive.registerAdapter(StepsDayAdapter());
      if (!Hive.isAdapterRegistered(28)) Hive.registerAdapter(StepsConnectionAdapter());
      // Journal adapters (typeId 30=entry, 31=enum)
      if (!Hive.isAdapterRegistered(30)) Hive.registerAdapter(JournalEntryAdapter());
      if (!Hive.isAdapterRegistered(31)) Hive.registerAdapter(JournalEntryTypeAdapter());

      // Open boxes
      Logger.debug('Opening Hive boxes...', service: 'storage');
      await Hive.openBox<Reminder>(_remindersBox);
      await Hive.openBox<Partner>(_partnerBox);
      await Hive.openBox<User>(_userBox);
      await Hive.openBox<LovePointTransaction>(_transactionsBox);
      await Hive.openBox<QuizQuestion>(_quizQuestionsBox);
      await Hive.openBox<QuizSession>(_quizSessionsBox);
      await Hive.openBox<Badge>(_badgesBox);
      await Hive.openBox<QuizFormat>(_quizFormatsBox);
      await Hive.openBox<QuizCategory>(_quizCategoriesBox);
      await Hive.openBox<QuizStreak>(_quizStreaksBox);
      await Hive.openBox<QuizDailyPulse>(_dailyPulsesBox);
      await Hive.openBox<DailyQuest>(_dailyQuestsBox);
      await Hive.openBox<DailyQuestCompletion>(_dailyQuestCompletionsBox);
      await Hive.openBox<QuizProgressionState>(_quizProgressionStatesBox);
      await Hive.openBox<YouOrMeSession>(_youOrMeSessionsBox);
      await Hive.openBox(_youOrMeProgressionBox);  // Untyped box for question tracking
      await Hive.openBox(_appMetadataBox);  // Untyped box for app metadata
      await Hive.openBox<LinkedMatch>(_linkedMatchesBox);
      await Hive.openBox<WordSearchMatch>(_wordSearchMatchesBox);
      await Hive.openBox<BranchProgressionState>(_branchProgressionBox);
      await Hive.openBox<StepsDay>(_stepsDaysBox);
      await Hive.openBox<StepsConnection>(_stepsConnectionBox);
      await Hive.openBox<JournalEntry>(_journalEntriesBox);

      Logger.info('Hive storage initialized successfully (26 boxes opened)', service: 'storage');

      // Debug: Log daily quest state at startup to diagnose persistence issues
      final questsBox = Hive.box<DailyQuest>(_dailyQuestsBox);
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todayQuests = questsBox.values.where((q) => q.dateKey == dateKey).toList();
      for (final quest in todayQuests) {
        Logger.debug(
          '🚀 STARTUP: Quest ${quest.formatType} status=${quest.status} completions=${quest.userCompletions}',
          service: 'quest-debug',
        );
      }
      if (todayQuests.isEmpty) {
        Logger.debug('🚀 STARTUP: No quests found in Hive for today ($dateKey)', service: 'quest-debug');
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize Hive storage', error: e, stackTrace: stackTrace, service: 'storage');
      rethrow;
    }
  }

  // Reminder operations
  Box<Reminder> get remindersBox => Hive.box<Reminder>(_remindersBox);

  Future<void> saveReminder(Reminder reminder) async {
    try {
      await remindersBox.put(reminder.id, reminder);
      Logger.debug('Saved reminder: ${reminder.id} (${reminder.type})', service: 'storage');
    } catch (e, stackTrace) {
      Logger.error('Failed to save reminder ${reminder.id}', error: e, stackTrace: stackTrace, service: 'storage');
      rethrow;
    }
  }

  List<Reminder> getAllReminders() {
    final reminders = remindersBox.values.toList();
    reminders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reminders;
  }

  List<Reminder> getReceivedReminders() {
    return getAllReminders().where((r) => r.type == 'received').toList();
  }

  List<Reminder> getSentReminders() {
    return getAllReminders().where((r) => r.type == 'sent').toList();
  }

  Reminder? getReminder(String id) {
    return remindersBox.get(id);
  }

  Future<void> updateReminderStatus(String id, String status, {DateTime? snoozedUntil}) async {
    final reminder = remindersBox.get(id);
    if (reminder != null) {
      reminder.status = status;
      if (snoozedUntil != null) {
        reminder.snoozedUntil = snoozedUntil;
      }
      await reminder.save();
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await remindersBox.delete(id);
      Logger.debug('Deleted reminder: $id', service: 'storage');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete reminder $id', error: e, stackTrace: stackTrace, service: 'storage');
      rethrow;
    }
  }

  Future<void> clearAllReminders() async {
    try {
      final count = remindersBox.length;
      await remindersBox.clear();
      Logger.info('Cleared $count reminders from storage', service: 'storage');
    } catch (e, stackTrace) {
      Logger.error('Failed to clear reminders', error: e, stackTrace: stackTrace, service: 'storage');
      rethrow;
    }
  }

  // Partner operations
  Box<Partner> get partnerBox => Hive.box<Partner>(_partnerBox);

  Future<void> savePartner(Partner partner) async {
    try {
      await partnerBox.put('partner', partner);
      final tokenPreview = partner.pushToken.length >= 8
          ? '${partner.pushToken.substring(0, 8)}...'
          : partner.pushToken.isEmpty ? '(no token)' : partner.pushToken;
      Logger.info('Saved partner: ${partner.name} ($tokenPreview)', service: 'storage');
    } catch (e, stackTrace) {
      Logger.error('Failed to save partner', error: e, stackTrace: stackTrace, service: 'storage');
      rethrow;
    }
  }

  Partner? getPartner() {
    return partnerBox.get('partner');
  }

  bool hasPartner() {
    return partnerBox.get('partner') != null;
  }

  Future<void> deletePartner() async {
    try {
      await partnerBox.delete('partner');
      Logger.info('Deleted partner from storage', service: 'storage');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete partner', error: e, stackTrace: stackTrace, service: 'storage');
      rethrow;
    }
  }

  // User operations
  Box<User> get userBox => Hive.box<User>(_userBox);

  Future<void> saveUser(User user) async {
    await userBox.put('user', user);
  }

  User? getUser() {
    return userBox.get('user');
  }

  Future<void> deleteUser() async {
    await userBox.delete('user');
  }

  // Clear all data (unpair)
  Future<void> clearAllData() async {
    try {
      Logger.info('Clearing all data (unpair operation)...', service: 'storage');
      await clearAllReminders();
      await deletePartner();
      // Keep user data for potential re-pairing
      Logger.success('Successfully cleared all data (user data preserved)', service: 'storage');
    } catch (e, stackTrace) {
      Logger.error('Failed to clear all data', error: e, stackTrace: stackTrace, service: 'storage');
      rethrow;
    }
  }

  // Love Point Transaction operations
  Box<LovePointTransaction> get transactionsBox =>
      Hive.box<LovePointTransaction>(_transactionsBox);

  Future<void> saveTransaction(LovePointTransaction transaction) async {
    try {
      await transactionsBox.put(transaction.id, transaction);
      Logger.debug('Saved LP transaction: ${transaction.id} (+${transaction.amount} pts, ${transaction.reason})', service: 'storage');
    } catch (e, stackTrace) {
      Logger.error('Failed to save LP transaction ${transaction.id}', error: e, stackTrace: stackTrace, service: 'storage');
      rethrow;
    }
  }

  List<LovePointTransaction> getAllTransactions() {
    final transactions = transactionsBox.values.toList();
    transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return transactions;
  }

  List<LovePointTransaction> getRecentTransactions({int limit = 10}) {
    return getAllTransactions().take(limit).toList();
  }

  // Quiz Question operations
  Box<QuizQuestion> get quizQuestionsBox =>
      Hive.box<QuizQuestion>(_quizQuestionsBox);

  Future<void> saveQuizQuestion(QuizQuestion question) async {
    await quizQuestionsBox.put(question.id, question);
  }

  List<QuizQuestion> getAllQuizQuestions() {
    return quizQuestionsBox.values.toList();
  }

  QuizQuestion? getQuizQuestion(String id) {
    return quizQuestionsBox.get(id);
  }

  // Quiz Session operations
  Box<QuizSession> get quizSessionsBox =>
      Hive.box<QuizSession>(_quizSessionsBox);

  Future<void> saveQuizSession(QuizSession session) async {
    await quizSessionsBox.put(session.id, session);
  }

  QuizSession? getActiveQuizSession() {
    return quizSessionsBox.values
        .where((s) => s.status == 'waiting_for_answers' && !s.isExpired)
        .firstOrNull;
  }

  QuizSession? getQuizSession(String id) {
    return quizSessionsBox.get(id);
  }

  List<QuizSession> getAllQuizSessions() {
    final sessions = quizSessionsBox.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  List<QuizSession> getCompletedQuizSessions() {
    final sessions = quizSessionsBox.values
        .where((s) => s.status == 'completed')
        .toList();
    sessions.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return sessions;
  }

  Future<void> deleteQuizSession(String id) async {
    await quizSessionsBox.delete(id);
  }

  // Badge operations
  Box<Badge> get badgesBox => Hive.box<Badge>(_badgesBox);

  Future<void> saveBadge(Badge badge) async {
    await badgesBox.put(badge.id, badge);
  }

  List<Badge> getAllBadges() {
    final badges = badgesBox.values.toList();
    badges.sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
    return badges;
  }

  bool hasBadge(String badgeName) {
    return badgesBox.values.any((b) => b.name == badgeName);
  }

  // Linked Match operations
  Box<LinkedMatch> get linkedMatchesBox => Hive.box<LinkedMatch>(_linkedMatchesBox);

  Future<void> saveLinkedMatch(LinkedMatch match) async {
    await linkedMatchesBox.put(match.matchId, match);
  }

  LinkedMatch? getLinkedMatch(String matchId) {
    return linkedMatchesBox.get(matchId);
  }

  List<LinkedMatch> getAllLinkedMatches() {
    final matches = linkedMatchesBox.values.toList();
    matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  LinkedMatch? getActiveLinkedMatch() {
    return linkedMatchesBox.values
        .where((m) => m.status == 'active')
        .firstOrNull;
  }

  List<LinkedMatch> getCompletedLinkedMatches() {
    final matches = linkedMatchesBox.values
        .where((m) => m.status == 'completed')
        .toList();
    if (matches.isNotEmpty) {
      matches.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    }
    return matches;
  }

  Future<void> updateLinkedMatch(LinkedMatch match) async {
    await match.save();
  }

  // Word Search Match operations
  Box<WordSearchMatch> get wordSearchMatchesBox => Hive.box<WordSearchMatch>(_wordSearchMatchesBox);

  Future<void> saveWordSearchMatch(WordSearchMatch match) async {
    await wordSearchMatchesBox.put(match.matchId, match);
  }

  WordSearchMatch? getWordSearchMatch(String matchId) {
    return wordSearchMatchesBox.get(matchId);
  }

  List<WordSearchMatch> getAllWordSearchMatches() {
    final matches = wordSearchMatchesBox.values.toList();
    matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  WordSearchMatch? getActiveWordSearchMatch() {
    return wordSearchMatchesBox.values
        .where((m) => m.status == 'active')
        .firstOrNull;
  }

  List<WordSearchMatch> getCompletedWordSearchMatches() {
    final matches = wordSearchMatchesBox.values
        .where((m) => m.status == 'completed')
        .toList();
    if (matches.isNotEmpty) {
      matches.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    }
    return matches;
  }

  Future<void> updateWordSearchMatch(WordSearchMatch match) async {
    await match.save();
  }

  Future<void> deleteWordSearchMatch(String matchId) async {
    await wordSearchMatchesBox.delete(matchId);
  }

  // Daily Pulse operations
  Box<QuizDailyPulse> get dailyPulsesBox => Hive.box<QuizDailyPulse>(_dailyPulsesBox);

  Future<void> saveDailyPulse(QuizDailyPulse pulse) async {
    await dailyPulsesBox.put(pulse.id, pulse);
  }

  QuizDailyPulse? getDailyPulse(String dateKey) {
    return dailyPulsesBox.get(dateKey);
  }

  List<QuizDailyPulse> getAllDailyPulses() {
    final pulses = dailyPulsesBox.values.toList();
    pulses.sort((a, b) => b.availableDate.compareTo(a.availableDate));
    return pulses;
  }

  List<QuizDailyPulse> getCompletedDailyPulses() {
    return getAllDailyPulses().where((p) => p.isCompleted).toList();
  }

  // Streak operations
  Box<QuizStreak> get quizStreaksBox => Hive.box<QuizStreak>(_quizStreaksBox);

  Future<void> saveStreak(QuizStreak streak) async {
    await quizStreaksBox.put(streak.type, streak);
  }

  QuizStreak? getStreak(String type) {
    return quizStreaksBox.get(type);
  }

  Future<void> updateStreak(QuizStreak streak) async {
    await streak.save();
  }

  // Daily Quest operations
  Box<DailyQuest> get dailyQuestsBox => Hive.box<DailyQuest>(_dailyQuestsBox);

  Future<void> saveDailyQuest(DailyQuest quest) async {
    await dailyQuestsBox.put(quest.id, quest);
    // Force flush to disk to ensure data persists across app restarts
    await dailyQuestsBox.flush();
  }

  DailyQuest? getDailyQuest(String id) {
    return dailyQuestsBox.get(id);
  }

  List<DailyQuest> getDailyQuestsForDate(String dateKey) {
    return dailyQuestsBox.values
        .where((q) => q.dateKey == dateKey)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<DailyQuest> getTodayQuests() {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return getDailyQuestsForDate(dateKey);
  }

  List<DailyQuest> getActiveDailyQuests() {
    return dailyQuestsBox.values
        .where((q) => !q.isExpired && !q.isCompleted)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> updateDailyQuest(DailyQuest quest) async {
    // Use saveDailyQuest which includes flush() for reliable persistence
    await saveDailyQuest(quest);
  }

  // Daily Quest Completion operations
  Box<DailyQuestCompletion> get dailyQuestCompletionsBox =>
      Hive.box<DailyQuestCompletion>(_dailyQuestCompletionsBox);

  Future<void> saveDailyQuestCompletion(DailyQuestCompletion completion) async {
    await dailyQuestCompletionsBox.put(completion.dateKey, completion);
  }

  DailyQuestCompletion? getDailyQuestCompletion(String dateKey) {
    return dailyQuestCompletionsBox.get(dateKey);
  }

  DailyQuestCompletion? getTodayCompletion() {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return getDailyQuestCompletion(dateKey);
  }

  List<DailyQuestCompletion> getAllDailyQuestCompletions() {
    final completions = dailyQuestCompletionsBox.values.toList();
    completions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return completions;
  }

  Future<void> updateDailyQuestCompletion(DailyQuestCompletion completion) async {
    await completion.save();
  }

  // Quiz Progression State operations
  Box<QuizProgressionState> get quizProgressionStatesBox =>
      Hive.box<QuizProgressionState>(_quizProgressionStatesBox);

  Future<void> saveQuizProgressionState(QuizProgressionState state) async {
    await quizProgressionStatesBox.put(state.coupleId, state);
  }

  QuizProgressionState? getQuizProgressionState(String coupleId) {
    return quizProgressionStatesBox.get(coupleId);
  }

  Future<void> updateQuizProgressionState(QuizProgressionState state) async {
    await state.save();
  }

  // LP Award tracking operations (prevent duplicate awards)
  static const String _appliedLPAwardsKey = 'applied_lp_awards';

  Set<String> getAppliedLPAwards() {
    final box = Hive.box(_appMetadataBox);  // Use untyped metadata box
    final List<dynamic>? awards = box.get(_appliedLPAwardsKey);
    if (awards == null) return {};
    return Set<String>.from(awards);
  }

  Future<void> markLPAwardAsApplied(String awardId) async {
    final box = Hive.box(_appMetadataBox);  // Use untyped metadata box
    final awards = getAppliedLPAwards();
    awards.add(awardId);
    await box.put(_appliedLPAwardsKey, awards.toList());
  }

  // You or Me Session operations
  Box<YouOrMeSession> get youOrMeSessionsBox =>
      Hive.box<YouOrMeSession>(_youOrMeSessionsBox);

  Future<void> saveYouOrMeSession(YouOrMeSession session) async {
    await youOrMeSessionsBox.put(session.id, session);
  }

  YouOrMeSession? getYouOrMeSession(String sessionId) {
    return youOrMeSessionsBox.get(sessionId);
  }

  List<YouOrMeSession> getAllYouOrMeSessions() {
    final sessions = youOrMeSessionsBox.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  Future<void> updateYouOrMeSession(YouOrMeSession session) async {
    await session.save();
  }

  Future<void> deleteYouOrMeSession(String sessionId) async {
    await youOrMeSessionsBox.delete(sessionId);
  }

  // You or Me Progression operations (untyped box for question tracking)
  Box get youOrMeProgressionBox => Hive.box(_youOrMeProgressionBox);

  // Branch Progression State operations
  Box<BranchProgressionState> get branchProgressionBox =>
      Hive.box<BranchProgressionState>(_branchProgressionBox);

  Future<void> saveBranchProgressionState(BranchProgressionState state) async {
    await branchProgressionBox.put(state.storageKey, state);
  }

  BranchProgressionState? getBranchProgressionState(
    String coupleId,
    BranchableActivityType activityType,
  ) {
    final key = '${coupleId}_${activityType.name}';
    return branchProgressionBox.get(key);
  }

  List<BranchProgressionState> getAllBranchProgressionStates(String coupleId) {
    return branchProgressionBox.values
        .where((s) => s.coupleId == coupleId)
        .toList();
  }

  Future<void> updateBranchProgressionState(BranchProgressionState state) async {
    await state.save();
  }

  Future<void> deleteBranchProgressionState(
    String coupleId,
    BranchableActivityType activityType,
  ) async {
    final key = '${coupleId}_${activityType.name}';
    await branchProgressionBox.delete(key);
  }

  Future<void> clearAllBranchProgressionStates() async {
    await branchProgressionBox.clear();
  }

  // Steps Together operations
  Box<StepsDay> get stepsDaysBox => Hive.box<StepsDay>(_stepsDaysBox);
  Box<StepsConnection> get stepsConnectionBox => Hive.box<StepsConnection>(_stepsConnectionBox);

  /// Save or update a day's step data
  Future<void> saveStepsDay(StepsDay stepsDay) async {
    await stepsDaysBox.put(stepsDay.dateKey, stepsDay);
  }

  /// Get step data for a specific date
  StepsDay? getStepsDay(String dateKey) {
    return stepsDaysBox.get(dateKey);
  }

  /// Get today's step data
  StepsDay? getTodaySteps() {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return getStepsDay(dateKey);
  }

  /// Get yesterday's step data
  StepsDay? getYesterdaySteps() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    return getStepsDay(dateKey);
  }

  /// Get all step days (for history)
  List<StepsDay> getAllStepsDays() {
    final days = stepsDaysBox.values.toList();
    days.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return days;
  }

  /// Get unclaimed step days that are still claimable
  List<StepsDay> getClaimableStepsDays() {
    return stepsDaysBox.values
        .where((day) => day.canClaim)
        .toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
  }

  /// Update a steps day
  Future<void> updateStepsDay(StepsDay stepsDay) async {
    await stepsDay.save();
  }

  /// Save or update connection status
  Future<void> saveStepsConnection(StepsConnection connection) async {
    await stepsConnectionBox.put('connection', connection);
  }

  /// Get current connection status
  StepsConnection? getStepsConnection() {
    return stepsConnectionBox.get('connection');
  }

  /// Check if user has connected Apple Health
  bool isStepsConnected() {
    final connection = getStepsConnection();
    return connection?.isConnected ?? false;
  }

  /// Check if both partners are connected
  bool areBothStepsConnected() {
    final connection = getStepsConnection();
    return connection?.bothConnected ?? false;
  }

  /// Clear all steps data (for testing/reset)
  Future<void> clearAllStepsData() async {
    await stepsDaysBox.clear();
    await stepsConnectionBox.clear();
  }

  // ============================================================
  // Pending Results Tracking
  // ============================================================
  // Tracks matches where user has answered but hasn't seen results yet.
  // Used when user goes to waiting screen, then kills app before seeing results.

  static const String _pendingResultsKey = 'pending_results_match_ids';

  /// Get all pending results match IDs (Map of contentType -> matchId)
  Map<String, String> getPendingResultsMatchIds() {
    final box = Hive.box(_appMetadataBox);
    final data = box.get(_pendingResultsKey);
    if (data == null) return {};
    return Map<String, String>.from(data);
  }

  /// Set a pending results match ID for a content type
  /// Called when user submits answers and goes to waiting screen
  Future<void> setPendingResultsMatchId(String contentType, String matchId) async {
    final box = Hive.box(_appMetadataBox);
    final pending = getPendingResultsMatchIds();
    pending[contentType] = matchId;
    await box.put(_pendingResultsKey, pending);
  }

  /// Get pending results match ID for a specific content type
  String? getPendingResultsMatchId(String contentType) {
    return getPendingResultsMatchIds()[contentType];
  }

  /// Check if there are pending results for a content type
  bool hasPendingResults(String contentType) {
    return getPendingResultsMatchId(contentType) != null;
  }

  /// Clear pending results for a content type (after user has seen results)
  Future<void> clearPendingResultsMatchId(String contentType) async {
    final box = Hive.box(_appMetadataBox);
    final pending = getPendingResultsMatchIds();
    pending.remove(contentType);
    await box.put(_pendingResultsKey, pending);
  }

  /// Clear all pending results (for testing/reset)
  Future<void> clearAllPendingResults() async {
    final box = Hive.box(_appMetadataBox);
    await box.delete(_pendingResultsKey);
  }
}
