import 'package:hive_flutter/hive_flutter.dart';
import '../models/reminder.dart';
import '../models/partner.dart';
import '../models/user.dart';
import '../models/love_point_transaction.dart';
import '../models/quiz_question.dart';
import '../models/quiz_session.dart';
import '../models/badge.dart';
import '../models/word_pair.dart';
import '../models/ladder_session.dart';
import '../models/memory_flip.dart';
import '../models/quiz_expansion.dart';
import '../models/daily_quest.dart';
import '../models/quiz_progression_state.dart';
import '../models/you_or_me.dart';
import '../utils/logger.dart';

class StorageService {
  static const String _remindersBox = 'reminders';
  static const String _partnerBox = 'partner';
  static const String _userBox = 'user';
  static const String _transactionsBox = 'love_point_transactions';
  static const String _quizQuestionsBox = 'quiz_questions';
  static const String _quizSessionsBox = 'quiz_sessions';
  static const String _badgesBox = 'badges';
  static const String _ladderSessionsBox = 'ladder_sessions';
  static const String _memoryPuzzlesBox = 'memory_puzzles';
  static const String _memoryAllowancesBox = 'memory_allowances';
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
      if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(WordPairAdapter());
      if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(LadderSessionAdapter());
      if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(MemoryPuzzleAdapter());
      if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(MemoryCardAdapter());
      if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(MemoryFlipAllowanceAdapter());
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

      // Open boxes
      Logger.debug('Opening Hive boxes...', service: 'storage');
      await Hive.openBox<Reminder>(_remindersBox);
      await Hive.openBox<Partner>(_partnerBox);
      await Hive.openBox<User>(_userBox);
      await Hive.openBox<LovePointTransaction>(_transactionsBox);
      await Hive.openBox<QuizQuestion>(_quizQuestionsBox);
      await Hive.openBox<QuizSession>(_quizSessionsBox);
      await Hive.openBox<Badge>(_badgesBox);
      await Hive.openBox<LadderSession>(_ladderSessionsBox);
      await Hive.openBox<MemoryPuzzle>(_memoryPuzzlesBox);
      await Hive.openBox<MemoryFlipAllowance>(_memoryAllowancesBox);
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

      Logger.info('Hive storage initialized successfully (20 boxes opened)', service: 'storage');
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
      Logger.info('Saved partner: ${partner.name} (${partner.pushToken.substring(0, 8)}...)', service: 'storage');
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

  // Ladder Session operations
  Box<LadderSession> get ladderSessionsBox =>
      Hive.box<LadderSession>(_ladderSessionsBox);

  Future<void> saveLadderSession(LadderSession session) async {
    await ladderSessionsBox.put(session.id, session);
  }

  List<LadderSession> getAllLadderSessions() {
    final sessions = ladderSessionsBox.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  List<LadderSession> getActiveLadders() {
    return ladderSessionsBox.values
        .where((session) => session.status == 'active')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> updateLadderSession(LadderSession session) async {
    await session.save();
  }

  LadderSession? getLadderSession(String id) {
    return ladderSessionsBox.get(id);
  }

  int getActiveLadderCount() {
    return ladderSessionsBox.values
        .where((session) => session.status == 'active')
        .length;
  }

  List<LadderSession> getCompletedLadders() {
    return ladderSessionsBox.values
        .where((session) => session.status == 'completed')
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  }

  // Memory Flip operations
  Box<MemoryPuzzle> get memoryPuzzlesBox =>
      Hive.box<MemoryPuzzle>(_memoryPuzzlesBox);

  Box<MemoryFlipAllowance> get memoryAllowancesBox =>
      Hive.box<MemoryFlipAllowance>(_memoryAllowancesBox);

  Future<void> saveMemoryPuzzle(MemoryPuzzle puzzle) async {
    await memoryPuzzlesBox.put(puzzle.id, puzzle);
  }

  MemoryPuzzle? getMemoryPuzzle(String id) {
    return memoryPuzzlesBox.get(id);
  }

  List<MemoryPuzzle> getAllMemoryPuzzles() {
    final puzzles = memoryPuzzlesBox.values.toList();
    puzzles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return puzzles;
  }

  MemoryPuzzle? getActivePuzzle() {
    return memoryPuzzlesBox.values
        .where((p) => p.status == 'active')
        .firstOrNull;
  }

  List<MemoryPuzzle> getCompletedPuzzles() {
    final puzzles = memoryPuzzlesBox.values
        .where((p) => p.status == 'completed')
        .toList();
    puzzles.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return puzzles;
  }

  Future<void> saveMemoryAllowance(MemoryFlipAllowance allowance) async {
    await memoryAllowancesBox.put(allowance.userId, allowance);
  }

  MemoryFlipAllowance? getMemoryAllowance(String userId) {
    return memoryAllowancesBox.get(userId);
  }

  Future<void> updateMemoryPuzzle(MemoryPuzzle puzzle) async {
    await puzzle.save();
  }

  Future<void> updateMemoryAllowance(MemoryFlipAllowance allowance) async {
    await allowance.save();
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
    await quest.save();
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
}
