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

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters (only if not already registered)
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

    // Open boxes
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
  }

  // Reminder operations
  Box<Reminder> get remindersBox => Hive.box<Reminder>(_remindersBox);

  Future<void> saveReminder(Reminder reminder) async {
    await remindersBox.put(reminder.id, reminder);
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
    await remindersBox.delete(id);
  }

  Future<void> clearAllReminders() async {
    await remindersBox.clear();
  }

  // Partner operations
  Box<Partner> get partnerBox => Hive.box<Partner>(_partnerBox);

  Future<void> savePartner(Partner partner) async {
    await partnerBox.put('partner', partner);
  }

  Partner? getPartner() {
    return partnerBox.get('partner');
  }

  bool hasPartner() {
    return partnerBox.get('partner') != null;
  }

  Future<void> deletePartner() async {
    await partnerBox.delete('partner');
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
    await clearAllReminders();
    await deletePartner();
    // Keep user data for potential re-pairing
  }

  // Love Point Transaction operations
  Box<LovePointTransaction> get transactionsBox =>
      Hive.box<LovePointTransaction>(_transactionsBox);

  Future<void> saveTransaction(LovePointTransaction transaction) async {
    await transactionsBox.put(transaction.id, transaction);
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
}
