import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../models/badge.dart';
import 'storage_service.dart';
import 'quiz_question_bank.dart';
import 'affirmation_quiz_bank.dart';
import 'love_point_service.dart';
import 'daily_quest_service.dart';
import 'quest_sync_service.dart';
import '../config/dev_config.dart';
import '../utils/logger.dart';

class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  final StorageService _storage = StorageService();
  final QuizQuestionBank _questionBank = QuizQuestionBank();
  final AffirmationQuizBank _affirmationBank = AffirmationQuizBank();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

  /// Start a new quiz session
  /// The initiator becomes the SUBJECT - quiz is ABOUT them
  /// Partner becomes the PREDICTOR - tries to guess subject's answers
  /// For affirmations: both users answer as themselves (no subject/predictor)
  Future<QuizSession> startQuizSession({
    String formatType = 'classic',
    String? categoryFilter,
    int? difficulty,
    bool skipActiveCheck = false, // Allow generating multiple daily quests
    bool isDailyQuest = false, // Mark if this quiz was created from a daily quest
    String dailyQuestId = '', // Link back to the DailyQuest that created this
  }) async {
    // Check for active session (skip for daily quest generation)
    if (!skipActiveCheck) {
      final activeSession = _storage.getActiveQuizSession();
      if (activeSession != null) {
        throw Exception('A quiz is already in progress. Complete it first.');
      }
    }

    // Ensure question banks are loaded
    await _questionBank.initialize();
    await _affirmationBank.initialize();

    // Get questions and metadata based on format type
    final List<QuizQuestion> questions;
    final int requiredQuestions;
    String? quizName;
    String? category;
    String? imagePath;
    String? description;

    if (formatType == 'affirmation') {
      // Affirmation: Get pre-packaged quiz by category
      if (categoryFilter == null) {
        throw Exception('Category filter required for affirmation quizzes');
      }

      final affirmationQuiz = _affirmationBank.getRandomQuizForCategory(categoryFilter);
      if (affirmationQuiz == null) {
        throw Exception('No affirmation quizzes found for category: $categoryFilter');
      }

      questions = affirmationQuiz.questions;
      requiredQuestions = questions.length;
      quizName = affirmationQuiz.name;
      category = affirmationQuiz.category;
      imagePath = affirmationQuiz.imagePath; // Extract for carousel display
      description = affirmationQuiz.description; // Extract for carousel display

    } else if (formatType == 'speed_round') {
      questions = _questionBank.getRandomQuestionsForSpeedRound();
      requiredQuestions = 10;
    } else if (formatType == 'would_you_rather') {
      questions = _questionBank.getRandomQuestionsForWouldYouRather();
      requiredQuestions = 7;
    } else {
      questions = _questionBank.getRandomQuestionsForSession();
      requiredQuestions = 5;
    }

    if (questions.length < requiredQuestions) {
      throw Exception('Not enough questions available for a quiz.');
    }

    final user = _storage.getUser();
    if (user == null) {
      throw Exception('User not found');
    }

    // Create session - CRITICAL: subjectUserId = initiator (quiz is ABOUT them)
    final session = QuizSession(
      id: const Uuid().v4(),
      questionIds: questions.map((q) => q.id).toList(),
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 3)),
      status: 'waiting_for_answers',
      initiatedBy: user.id,
      subjectUserId: user.id, // CRITICAL: Quiz is ABOUT the initiator
      formatType: formatType,
      quizName: quizName, // Set for affirmations
      category: category, // Set for affirmations
      imagePath: imagePath, // Set for carousel display
      description: description, // Set for carousel display
      isDailyQuest: isDailyQuest,
      dailyQuestId: dailyQuestId,
      answers: {},
    );

    await _storage.saveQuizSession(session);

    // Save questions to storage (needed for affirmations since questions aren't in QuizQuestionBank)
    if (formatType == 'affirmation') {
      Logger.info('Creating affirmation quiz: $quizName (category: $category)', service: 'affirmation');
      for (final question in questions) {
        await _storage.saveQuizQuestion(question);
      }
    }

    // Sync to RTDB for partner to receive (backup to push notifications)
    await _syncSessionToRTDB(session);

    // Send notification to partner
    await _sendQuizInviteNotification(session);

    return session;
  }

  /// Submit answers for a quiz session
  Future<void> submitAnswers(String sessionId, String userId, List<int> answers) async {
    final session = await getSession(sessionId);
    if (session == null) {
      throw Exception('Quiz session not found');
    }

    if (session.isExpired) {
      session.status = 'expired';
      await session.save();
      throw Exception('Quiz session has expired');
    }

    if (session.hasUserAnswered(userId)) {
      throw Exception('You have already answered this quiz');
    }

    // Save answers
    session.answers ??= {};
    session.answers![userId] = answers;
    await session.save();

    // Sync updated session to RTDB
    await _syncSessionToRTDB(session);

    // Removed verbose logging
    // print('✅ Answers submitted for user $userId');

    // Mark quest as completed for this user
    await _markQuestCompletedForUser(sessionId, userId);

    // Check if both partners have answered
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user != null && partner != null) {
      final bothAnswered = session.answers!.length >= 2;

      if (bothAnswered) {
        // Calculate results and award LP
        await _calculateAndCompleteSession(session);
        // Sync completed session to RTDB so partner receives the update
        await _syncSessionToRTDB(session);
      } else {
        // Notify partner if they haven't answered yet
        await _sendQuizReminderNotification(session, userId);
      }
    }
  }

  /// Submit Would You Rather answers and predictions
  /// Hybrid format: user answers about self AND predicts partner's answers
  Future<void> submitWouldYouRatherAnswers(
    String sessionId,
    String userId,
    List<int> myAnswers,
    List<int> myPredictions,
  ) async {
    final session = await getSession(sessionId);
    if (session == null) {
      throw Exception('Quiz session not found');
    }

    if (session.isExpired) {
      session.status = 'expired';
      await session.save();
      throw Exception('Quiz session has expired');
    }

    if (session.hasUserAnswered(userId)) {
      throw Exception('You have already answered this quiz');
    }

    // Save both answers and predictions
    session.answers ??= {};
    session.answers![userId] = myAnswers;

    session.predictions ??= {};
    session.predictions![userId] = myPredictions;

    await session.save();

    // Sync updated session to RTDB
    await _syncSessionToRTDB(session);

    // Removed verbose logging
    // print('✅ Would You Rather answers and predictions submitted for user $userId');

    // Mark quest as completed for this user
    await _markQuestCompletedForUser(sessionId, userId);

    // Check if both partners have answered
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user != null && partner != null) {
      final bothAnswered = session.answers!.length >= 2 && session.predictions!.length >= 2;

      if (bothAnswered) {
        // Calculate results and award LP
        await _calculateWouldYouRatherResults(session);
      } else {
        // Notify partner if they haven't answered yet
        await _sendQuizReminderNotification(session, userId);
      }
    }
  }

  /// Calculate match percentage and complete session
  /// NEW LOGIC: Compare SUBJECT's self-answers vs. PREDICTOR's guesses
  /// For affirmations: Calculate individual scores instead of match percentage
  Future<void> _calculateAndCompleteSession(QuizSession session) async {
    final answers = session.answers!;
    if (answers.length < 2) return;

    // Check if this is an affirmation quiz
    if (session.formatType == 'affirmation') {
      await _calculateAffirmationScores(session);
      return;
    }

    // Classic quiz logic: Calculate match percentage
    // Identify subject and predictor
    final subjectAnswers = answers[session.subjectUserId];
    if (subjectAnswers == null) {
      Logger.error('Subject has not answered yet', service: 'quiz');
      return;
    }

    // Find predictor (the other user)
    final predictorId = answers.keys.firstWhere(
      (id) => id != session.subjectUserId,
      orElse: () => '',
    );
    if (predictorId.isEmpty) {
      Logger.error('Predictor not found', service: 'quiz');
      return;
    }

    final predictorGuesses = answers[predictorId];
    if (predictorGuesses == null) {
      Logger.error('Predictor has not answered yet', service: 'quiz');
      return;
    }

    // Calculate prediction accuracy (how well predictor knows subject)
    int matches = 0;
    for (int i = 0; i < subjectAnswers.length && i < predictorGuesses.length; i++) {
      if (subjectAnswers[i] == predictorGuesses[i]) {
        matches++;
      }
    }

    final matchPercentage = ((matches / subjectAnswers.length) * 100).round();

    // Award fixed 30 LP for completing quiz together (regardless of match percentage)
    const int lpEarned = 30;

    // Award Perfect Sync badge for 100% matches
    if (matchPercentage == 100) {
      await _awardPerfectSyncBadge();
    }

    // Update session
    session.matchPercentage = matchPercentage;
    session.lpEarned = lpEarned;
    session.status = 'completed';
    session.completedAt = DateTime.now();
    await session.save();

    // NOTE: LP awarding is now handled by UnifiedResultsScreen for daily quests
    // This prevents duplicate LP awards (once from QuizService, once from UnifiedResultsScreen)
    // Standalone quizzes (non-daily-quests) currently don't award LP - will be added in future if needed

    // Send completion notification to both users
    await _sendQuizCompletedNotification(session, matchPercentage, lpEarned);

    // Removed verbose logging
    // print('✅ Quiz completed: $matchPercentage% match, +$lpEarned LP earned');
  }

  /// Calculate individual scores for affirmation quizzes
  /// No match percentage - each user gets their own score based on 1-5 ratings
  Future<void> _calculateAffirmationScores(QuizSession session) async {
    final answers = session.answers!;
    if (answers.length < 2) return;

    // Calculate individual scores (convert answers to 1-5 scale values)
    // Note: Answers are stored as 0-4 indices in storage, but represent 1-5 values
    final scores = <String, int>{};
    for (final entry in answers.entries) {
      final userId = entry.key;
      final userAnswers = entry.value;

      // Convert 0-4 indices to 1-5 values
      final scaleValues = userAnswers.map((index) => index + 1).toList();
      final average = scaleValues.reduce((a, b) => a + b) / scaleValues.length;
      final percentage = ((average / 5.0) * 100).round();
      scores[userId] = percentage;
      Logger.debug('User $userId affirmation score: $percentage%', service: 'affirmation');
    }

    // Award fixed 30 LP for completing affirmation together
    const int lpEarned = 30;

    // Update session
    session.status = 'completed';
    session.completedAt = DateTime.now();
    session.lpEarned = lpEarned;
    // Store individual scores in predictionScores field (repurposing for affirmations)
    session.predictionScores = scores;
    await session.save();

    // Award LP to BOTH users
    if (lpEarned > 0) {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user != null && partner != null) {
        await LovePointService.awardPointsToBothUsers(
          userId1: user.id,
          userId2: partner.pushToken,
          amount: lpEarned,
          reason: 'affirmation_completed',
          relatedId: session.id,
        );
        Logger.success('Affirmation quiz "${session.quizName}" completed - Scores: ${scores.values.join(', ')}%, +$lpEarned LP awarded', service: 'affirmation');
      }
    }
  }

  /// Award Perfect Sync badge if not already earned
  Future<void> _awardPerfectSyncBadge() async {
    const badgeName = 'Perfect Sync';

    // Check if badge already exists
    if (_storage.hasBadge(badgeName)) {
      Logger.info('Badge "$badgeName" already earned', service: 'quiz');
      return;
    }

    final badge = Badge(
      id: const Uuid().v4(),
      name: badgeName,
      emoji: '🎯',
      description: '100% match on a couple quiz',
      earnedAt: DateTime.now(),
      category: 'quiz',
    );

    await _storage.saveBadge(badge);
    // Removed verbose logging
    // print('🏆 Badge earned: $badgeName');
  }

  /// Calculate Would You Rather results
  /// Scores based on prediction accuracy + alignment bonuses
  Future<void> _calculateWouldYouRatherResults(QuizSession session) async {
    final answers = session.answers!;
    final predictions = session.predictions!;

    if (answers.length < 2 || predictions.length < 2) return;

    // Get both users' answers and predictions
    final userIds = answers.keys.toList();
    final user1Id = userIds[0];
    final user2Id = userIds[1];

    final user1Answers = answers[user1Id]!;
    final user2Answers = answers[user2Id]!;

    final user1Predictions = predictions[user1Id]!;
    final user2Predictions = predictions[user2Id]!;

    // Calculate User 1's prediction accuracy (how well they predicted User 2)
    int user1Correct = 0;
    for (int i = 0; i < user1Predictions.length && i < user2Answers.length; i++) {
      if (user1Predictions[i] == user2Answers[i]) {
        user1Correct++;
      }
    }

    // Calculate User 2's prediction accuracy (how well they predicted User 1)
    int user2Correct = 0;
    for (int i = 0; i < user2Predictions.length && i < user1Answers.length; i++) {
      if (user2Predictions[i] == user1Answers[i]) {
        user2Correct++;
      }
    }

    // Calculate alignment matches (questions where both chose same answer)
    int alignmentMatches = 0;
    for (int i = 0; i < user1Answers.length && i < user2Answers.length; i++) {
      if (user1Answers[i] == user2Answers[i]) {
        alignmentMatches++;
      }
    }

    // Average prediction accuracy
    final totalCorrect = user1Correct + user2Correct;
    final totalQuestions = user1Answers.length + user2Answers.length;
    final overallAccuracy = ((totalCorrect / totalQuestions) * 100).round();

    // Award LP based on prediction accuracy
    int baseLp = 0;
    if (overallAccuracy >= 90) {
      baseLp = 50;
    } else if (overallAccuracy >= 70) {
      baseLp = 40;
    } else if (overallAccuracy >= 50) {
      baseLp = 30;
    } else {
      baseLp = 25;
    }

    // Bonus LP for alignment matches (5 LP per shared preference)
    final alignmentBonus = alignmentMatches * 5;

    final totalLp = baseLp + alignmentBonus;

    // Save results
    session.matchPercentage = overallAccuracy;
    session.alignmentMatches = alignmentMatches;
    session.predictionScores = {
      user1Id: user1Correct,
      user2Id: user2Correct,
    };
    session.lpEarned = totalLp;
    session.status = 'completed';
    session.completedAt = DateTime.now();
    await session.save();

    // Award LP to both users
    final user = _storage.getUser();
    if (user != null) {
      await LovePointService.awardPoints(
        amount: totalLp,
        reason: 'Would You Rather quiz completed',
        relatedId: session.id,
      );
    }

    // Sync to RTDB
    await _syncSessionToRTDB(session);

    // Removed verbose logging
    // print('✅ Would You Rather completed: $overallAccuracy% prediction accuracy, $alignmentMatches alignments, +$totalLp LP');
  }

  /// Send quiz invite notification to partner
  Future<void> _sendQuizInviteNotification(QuizSession session) async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      // NEW MESSAGE: Reflects knowledge test model
      final message = "${user.name ?? 'Your partner'} wants to see how well you know them!";

      final callable = _functions.httpsCallable('sendQuizInvite');
      await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your partner',
        'sessionId': session.id,
        'message': message,
        'formatType': session.formatType,
      });

      // Removed verbose logging
      // print('✅ Quiz invite sent to partner: $message');
    } catch (e) {
      Logger.error('Error sending quiz invite', error: e, service: 'quiz');
    }
  }

  /// Send reminder notification to partner who hasn't answered
  Future<void> _sendQuizReminderNotification(QuizSession session, String answeredUserId) async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      final callable = _functions.httpsCallable('sendQuizReminder');
      await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your partner',
        'sessionId': session.id,
      });

      // Removed verbose logging
      // print('✅ Quiz reminder sent to partner');
    } catch (e) {
      Logger.error('Error sending quiz reminder', error: e, service: 'quiz');
    }
  }

  /// Send completion notification
  Future<void> _sendQuizCompletedNotification(QuizSession session, int matchPercentage, int lpEarned) async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      final callable = _functions.httpsCallable('sendQuizCompleted');
      await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your partner',
        'sessionId': session.id,
        'matchPercentage': matchPercentage,
        'lpEarned': lpEarned,
      });

      // Removed verbose logging
      // print('✅ Quiz completion notification sent');
    } catch (e) {
      Logger.error('Error sending completion notification', error: e, service: 'quiz');
    }
  }

  /// Get active quiz session
  QuizSession? getActiveSession() {
    return _storage.getActiveQuizSession();
  }

  /// Get completed quiz history
  List<QuizSession> getCompletedSessions() {
    return _storage.getCompletedQuizSessions();
  }

  /// Get questions for a session
  List<QuizQuestion> getSessionQuestions(QuizSession session) {
    // Try to load from local storage first
    final questions = session.questionIds
        .map((id) => _storage.getQuizQuestion(id))
        .where((q) => q != null)
        .cast<QuizQuestion>()
        .toList();

    // If not found and it's an affirmation quiz, look up from AffirmationQuizBank
    if (questions.isEmpty && session.formatType == 'affirmation') {
      // Extract quiz ID from question IDs (not category!)
      // Question IDs format: "getting_comfortable_0", "getting_comfortable_1", etc.
      // The quiz ID is everything before the last underscore
      String? quizId;
      if (session.questionIds.isNotEmpty) {
        final firstQuestionId = session.questionIds.first;
        // Extract everything before the last underscore and number
        final lastUnderscoreIndex = firstQuestionId.lastIndexOf('_');
        if (lastUnderscoreIndex > 0) {
          quizId = firstQuestionId.substring(0, lastUnderscoreIndex);
        }
      }

      if (quizId != null) {
        // Ensure affirmation bank is initialized
        if (!_affirmationBank.isInitialized) {
          // This is a synchronous call, which is not ideal but necessary here
          // In practice, the bank should already be initialized during app startup
        }

        // Look up quiz by ID (not category!)
        final affirmationQuiz = _affirmationBank.getQuizById(quizId);
        if (affirmationQuiz != null) {
          return affirmationQuiz.questions;
        } else {
          Logger.error('Could not find affirmation quiz with ID: $quizId', service: 'quiz');
        }
      } else {
        Logger.error('Could not extract quiz ID from question IDs', service: 'quiz');
      }
    }

    return questions;
  }

  /// Check if user has answered current session
  bool hasUserAnswered(String userId) {
    final session = getActiveSession();
    if (session == null) return false;
    return session.hasUserAnswered(userId);
  }

  /// Get average match percentage
  double getAverageMatchPercentage() {
    final completed = getCompletedSessions();
    if (completed.isEmpty) return 0.0;

    final total = completed
        .where((s) => s.matchPercentage != null)
        .map((s) => s.matchPercentage!)
        .reduce((a, b) => a + b);

    return total / completed.length;
  }

  /// Get count of completed Classic Quizzes
  int getCompletedClassicQuizzesCount() {
    return getCompletedSessions()
        .where((s) => s.formatType == 'classic')
        .length;
  }

  /// Check if Speed Round is unlocked (requires 5 Classic Quizzes completed)
  /// In debug mode, always unlocked for testing
  bool isSpeedRoundUnlocked() {
    // Debug bypass: Always unlock Speed Round in debug mode for testing
    if (DevConfig.isSimulatorSync) {
      return true;
    }
    return getCompletedClassicQuizzesCount() >= 5;
  }

  /// Get count of completed "Would You Rather" quizzes
  int getCompletedWouldYouRatherCount() {
    return getCompletedSessions()
        .where((s) => s.formatType == 'would_you_rather')
        .length;
  }

  /// Check if Would You Rather is unlocked (requires 15 total quizzes completed)
  /// In debug mode, always unlocked for testing
  bool isWouldYouRatherUnlocked() {
    // Debug bypass: Always unlock in debug mode for testing
    if (DevConfig.isSimulatorSync) {
      return true;
    }
    return getCompletedSessions().length >= 15;
  }

  /// Sync quiz session to RTDB using shared couple path
  Future<void> _syncSessionToRTDB(QuizSession session) async {
    // Only sync in debug mode on simulators
    if (!DevConfig.isSimulatorSync) {
      return;
    }

    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();
      if (user == null || partner == null) {
        Logger.warn('Cannot sync: user or partner not found', service: 'quiz');
        return;
      }

      final coupleId = _generateCoupleId(user.id, partner.pushToken);
      final sessionRef = _rtdb
          .child('quiz_sessions')
          .child(coupleId)
          .child(session.id);

      final sessionData = {
        'id': session.id,
        'questionIds': session.questionIds,
        'createdAt': session.createdAt.millisecondsSinceEpoch,
        'expiresAt': session.expiresAt.millisecondsSinceEpoch,
        'status': session.status,
        'initiatedBy': session.initiatedBy,
        'subjectUserId': session.subjectUserId,
        'formatType': session.formatType,
        'isDailyQuest': session.isDailyQuest,
        'dailyQuestId': session.dailyQuestId,
        'answers': session.answers,
        'predictions': session.predictions,
        'matchPercentage': session.matchPercentage,
        'lpEarned': session.lpEarned,
        'completedAt': session.completedAt?.millisecondsSinceEpoch,
        'alignmentMatches': session.alignmentMatches,
        'predictionScores': session.predictionScores,
      };

      await sessionRef.set(sessionData);
      // Removed verbose logging
      // print('✅ Session synced to Firebase: ${session.id} at /quiz_sessions/$coupleId/${session.id}');
    } catch (e) {
      Logger.error('Error syncing session to Firebase', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Get quiz session with Firebase fallback (simplified 2-tier)
  /// 1. Try local Hive storage first (fast path)
  /// 2. Check shared Firebase path (couple-based)
  Future<QuizSession?> getSession(String sessionId) async {
    // 1. Try local storage first (fast path)
    var session = _storage.getQuizSession(sessionId);
    if (session != null) {
      // Removed verbose logging
      // print('✅ Session found in local cache: $sessionId');
      return session;
    }

    // 2. Check shared Firebase path
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();
      if (user == null || partner == null) {
        Logger.warn('Cannot load session: user or partner not found', service: 'quiz');
        return null;
      }

      final coupleId = _generateCoupleId(user.id, partner.pushToken);
      final sessionRef = _rtdb
          .child('quiz_sessions')
          .child(coupleId)
          .child(sessionId);

      final snapshot = await sessionRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        session = QuizSession(
          id: data['id'] as String,
          questionIds: List<String>.from(data['questionIds'] ?? []),
          createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] as int),
          status: data['status'] as String,
          initiatedBy: data['initiatedBy'] as String,
          subjectUserId: data['subjectUserId'] as String? ?? data['initiatedBy'] as String,
          formatType: data['formatType'] as String? ?? 'classic',
          isDailyQuest: data['isDailyQuest'] as bool? ?? false,
          dailyQuestId: data['dailyQuestId'] as String? ?? '',
          answers: data['answers'] != null
              ? Map<String, List<int>>.from(
                  (data['answers'] as Map).map(
                    (k, v) => MapEntry(k.toString(), List<int>.from(v)),
                  ),
                )
              : {},
        );

        session.matchPercentage = data['matchPercentage'] as int?;
        session.lpEarned = data['lpEarned'] as int?;
        session.completedAt = data['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'] as int)
            : null;

        // Handle predictions for Would You Rather
        if (data.containsKey('predictions') && data['predictions'] != null) {
          session.predictions = Map<String, List<int>>.from(
            (data['predictions'] as Map).map(
              (k, v) => MapEntry(k.toString(), List<int>.from(v)),
            ),
          );
        }

        // Cache locally
        await _storage.saveQuizSession(session);

        // Removed verbose logging
        // print('✅ Session loaded from Firebase: $sessionId (couple path: /quiz_sessions/$coupleId/$sessionId)');
        return session;
      }
    } catch (e) {
      Logger.error('Error loading session from Firebase', error: e, service: 'quiz');
    }

    Logger.warn('Session not found: $sessionId', service: 'quiz');
    return null;
  }

  /// Generate deterministic couple ID by sorting user IDs alphabetically
  /// Ensures both partners use the same Firebase path
  String _generateCoupleId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Mark daily quest as completed for the user who submitted answers
  Future<void> _markQuestCompletedForUser(String sessionId, String userId) async {
    try {
      // Find the quest that corresponds to this session
      final quests = _storage.getTodayQuests();
      final quest = quests.firstWhere(
        (q) => q.contentId == sessionId,
        orElse: () => throw Exception('Quest not found for session: $sessionId'),
      );

      // Get partner info for Firebase sync
      final partner = _storage.getPartner();

      // Create services
      final dailyQuestService = DailyQuestService(storage: _storage);

      // Create sync service if partner exists
      QuestSyncService? questSyncService;
      if (partner != null) {
        questSyncService = QuestSyncService(
          storage: _storage,
        );
      }

      // Mark quest as completed for this user via DailyQuestService
      final updatedDailyQuestService = DailyQuestService(
        storage: _storage,
        questSyncService: questSyncService,
      );

      await updatedDailyQuestService.completeQuestForUser(
        questId: quest.id,
        userId: userId,
        partnerUserId: partner?.pushToken,
      );

      // Removed verbose logging
      // print('✅ Quest marked completed for user $userId');
    } catch (e) {
      Logger.error('Could not mark quest completed', error: e, service: 'quiz');
      // Don't throw - this is a non-critical operation
    }
  }

  /// Get random question for Daily Pulse
  QuizQuestion getRandomQuestionForDailyPulse() {
    final allQuestions = _questionBank.getAllQuestions();
    if (allQuestions.isEmpty) {
      throw Exception('No questions available for Daily Pulse');
    }

    // Get random question
    final random = DateTime.now().millisecondsSinceEpoch % allQuestions.length;
    return allQuestions[random];
  }

  /// Get question by ID
  QuizQuestion getQuestionById(String questionId) {
    final allQuestions = _questionBank.getAllQuestions();
    try {
      return allQuestions.firstWhere((q) => q.id == questionId);
    } catch (e) {
      // If not found, return a default question
      throw Exception('Question not found: $questionId');
    }
  }
}
