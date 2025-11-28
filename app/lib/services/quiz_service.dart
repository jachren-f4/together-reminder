import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../models/badge.dart';
import '../models/daily_quest.dart';
import 'storage_service.dart';
import 'quiz_question_bank.dart';
import 'affirmation_quiz_bank.dart';
import 'love_point_service.dart';
import 'daily_quest_service.dart';
import 'quest_sync_service.dart';
import 'quiz_api_service.dart';
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
  final QuizApiService _quizApiService = QuizApiService();

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

  /// Submit answers for a quiz session via Supabase API
  Future<void> submitAnswers(String sessionId, String userId, List<int> answers) async {
    await _submitAnswersViaApi(sessionId, answers);
    await _markQuestCompletedForUser(sessionId, userId);
  }

  /// Submit answers via Supabase API
  Future<QuizSubmitResult> _submitAnswersViaApi(String sessionId, List<int> answers, {List<int>? predictions}) async {
    final result = await _quizApiService.submitAnswers(
      sessionId: sessionId,
      answers: answers,
      predictions: predictions,
    );

    // Update local cache with new state
    if (result.success) {
      final session = _storage.getQuizSession(sessionId);
      if (session != null) {
        session.answers = result.answers;
        session.predictions = result.predictions;
        if (result.isCompleted) {
          session.status = 'completed';
          session.matchPercentage = result.matchPercentage;
          session.lpEarned = result.lpEarned;
          session.alignmentMatches = result.alignmentMatches ?? 0;
          session.predictionScores = result.predictionScores;
          session.completedAt = DateTime.now();
        }
        await session.save();
      }
    }

    return result;
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

  /// Sync quiz session to Supabase API
  /// Legacy Firebase RTDB sync has been removed - now using Supabase API exclusively
  Future<void> _syncSessionToRTDB(QuizSession session) async {
    await _syncSessionToSupabaseApi(session);
  }

  /// Sync quiz session to Supabase API (new architecture)
  /// This is called when useSupabaseForQuizzes flag is enabled
  /// Returns the server-generated session ID (may differ from local ID)
  Future<String?> _syncSessionToSupabaseApi(QuizSession session) async {
    try {
      Logger.debug('Syncing session to Supabase API: ${session.id}', service: 'quiz');

      // Get questions to send with the session
      final questions = getSessionQuestions(session);
      final questionsData = questions.map((q) => {
        'id': q.id,
        'text': q.question,
        'choices': q.options,
        'correctIndex': q.correctAnswerIndex,
      }).toList();

      // Create or update session via API
      final gameState = await _quizApiService.createOrGetSession(
        formatType: session.formatType ?? 'classic',
        questions: questionsData,
        quizName: session.quizName,
        category: session.category,
        dailyQuestId: session.dailyQuestId.isEmpty ? null : session.dailyQuestId,
      );

      final serverSessionId = gameState.session.id;
      Logger.success('Session synced to Supabase API. Server ID: $serverSessionId (local was: ${session.id})', service: 'quiz');

      // If server ID differs from local, update local session AND daily quest
      if (serverSessionId != session.id && serverSessionId.isNotEmpty) {
        final oldSessionId = session.id;
        Logger.info('Updating local session ID to match server: $serverSessionId (was: $oldSessionId)', service: 'quiz');

        // Delete old session with local ID
        await _storage.deleteQuizSession(oldSessionId);

        // Update session with server ID and save
        session.id = serverSessionId;
        await _storage.saveQuizSession(session);

        // Also update any DailyQuest that references the old session ID
        final dailyQuests = _storage.getTodayQuests();
        for (final quest in dailyQuests) {
          if (quest.contentId == oldSessionId) {
            Logger.info('Updating DailyQuest ${quest.id} contentId from $oldSessionId to $serverSessionId', service: 'quiz');
            quest.contentId = serverSessionId;
            await _storage.saveDailyQuest(quest);

            // Also update Supabase daily_quests table so partner sees correct contentId
            _updateDailyQuestContentIdInSupabase(quest.id, serverSessionId);
          }
        }
      }

      return serverSessionId;
    } catch (e) {
      Logger.error('Failed to sync session to Supabase API', error: e, service: 'quiz');
      // Don't rethrow - allow local storage to continue working
      return null;
    }
  }

  /// Update daily quest content_id in Supabase (fire-and-forget)
  /// Called when local session ID is updated to match server ID
  void _updateDailyQuestContentIdInSupabase(String questId, String newContentId) {
    // Fire and forget - don't await, just log errors
    _quizApiService.updateDailyQuestContentId(questId, newContentId).then((_) {
      Logger.success('Updated daily_quests in Supabase: $questId -> $newContentId', service: 'quiz');
    }).catchError((e) {
      Logger.error('Failed to update daily_quests in Supabase', error: e, service: 'quiz');
    });
  }

  /// Get quiz session with fallback
  /// Handles two formats:
  /// 1. UUID sessionId - direct lookup
  /// 2. Semantic key "quiz:{formatType}:{dateKey}" - create/get via API
  Future<QuizSession?> getSession(String contentId) async {
    // Check if this is a semantic key (format: quiz:{formatType}:{dateKey})
    if (contentId.startsWith('quiz:')) {
      return await _getOrCreateSessionFromSemanticKey(contentId);
    }

    // Traditional UUID lookup
    // 1. Try local storage first (fast path)
    var session = _storage.getQuizSession(contentId);
    if (session != null) {
      return session;
    }

    // 2. Poll from Supabase API
    try {
      final gameState = await _quizApiService.pollSessionState(contentId);
      return gameState.session;
    } catch (e) {
      Logger.error('Error loading session from Supabase API', error: e, service: 'quiz');
      return null;
    }
  }

  /// Create or get session from semantic key (server-authoritative pattern)
  /// Semantic key format: "quiz:{formatType}:{dateKey}"
  /// This ensures both partners get the same session without race conditions.
  Future<QuizSession?> _getOrCreateSessionFromSemanticKey(String semanticKey) async {
    try {
      // Parse semantic key: "quiz:{formatType}:{dateKey}"
      final parts = semanticKey.split(':');
      if (parts.length < 3) {
        Logger.error('Invalid semantic key format: $semanticKey', service: 'quiz');
        return null;
      }

      final formatType = parts[1];
      final dateKey = parts[2];

      Logger.debug('Creating/getting session from semantic key: formatType=$formatType, dateKey=$dateKey', service: 'quiz');

      // First, check if we already have a session cached for this date+format
      final cachedSession = _findCachedSessionByDateAndFormat(dateKey, formatType);
      if (cachedSession != null) {
        Logger.debug('Found cached session for $formatType on $dateKey: ${cachedSession.id}', service: 'quiz');
        return cachedSession;
      }

      // Load questions from local content bank (required for session creation)
      final questions = await _loadQuestionsForFormat(formatType);
      if (questions.isEmpty) {
        Logger.error('No questions loaded for format: $formatType', service: 'quiz');
        return null;
      }

      // Call API to create or get existing session
      final gameState = await _quizApiService.createOrGetSession(
        formatType: formatType,
        questions: questions,
        dailyQuestId: semanticKey, // Use semantic key as quest link
      );

      // Cache the session locally
      await _storage.saveQuizSession(gameState.session);

      Logger.debug('Got session from API: ${gameState.session.id} (isNew: ${!gameState.hasUserAnswered})', service: 'quiz');
      return gameState.session;
    } catch (e) {
      Logger.error('Error creating/getting session from semantic key', error: e, service: 'quiz');
      return null;
    }
  }

  /// Find cached session by date and format type
  QuizSession? _findCachedSessionByDateAndFormat(String dateKey, String formatType) {
    final allSessions = _storage.getAllQuizSessions();
    for (final session in allSessions) {
      // Check if session matches date and format
      final sessionDate = session.createdAt.toIso8601String().substring(0, 10);
      if (sessionDate == dateKey && session.formatType == formatType) {
        return session;
      }
    }
    return null;
  }

  /// Load questions for a specific format type from local content banks
  Future<List<Map<String, dynamic>>> _loadQuestionsForFormat(String formatType) async {
    try {
      if (formatType == 'affirmation') {
        // Load affirmation questions
        await _affirmationBank.initialize();
        final quiz = _affirmationBank.getRandomQuiz();
        if (quiz == null) return [];
        return quiz.questions.map((q) => <String, dynamic>{
          'id': q.id,
          'text': q.question,
          'category': q.category,
        }).toList();
      } else {
        // Load classic quiz questions
        await _questionBank.initialize();
        final questions = _questionBank.getRandomQuestionsForSession();
        return questions.map((q) => <String, dynamic>{
          'id': q.id,
          'text': q.question,
          'choices': q.options,
          'category': q.category,
        }).toList();
      }
    } catch (e) {
      Logger.error('Error loading questions for format: $formatType', error: e, service: 'quiz');
      return [];
    }
  }

  /// Mark daily quest as completed for the user who submitted answers
  Future<void> _markQuestCompletedForUser(String sessionId, String userId) async {
    try {
      // Find the quest that corresponds to this session
      // Supports both:
      // 1. Direct match (sessionId == contentId for old UUIDs)
      // 2. Semantic key match (contentId like "quiz:classic:2025-11-28" for new quests)
      final quests = _storage.getTodayQuests();
      DailyQuest? quest;

      // First try direct match (old UUID format)
      quest = quests.cast<DailyQuest?>().firstWhere(
        (q) => q?.contentId == sessionId,
        orElse: () => null,
      );

      // If not found, try semantic key lookup
      if (quest == null) {
        // Get the session to find its date and format
        final session = _storage.getQuizSession(sessionId);
        if (session != null) {
          final dateKey = session.createdAt.toIso8601String().substring(0, 10);
          final semanticKey = 'quiz:${session.formatType}:$dateKey';
          quest = quests.cast<DailyQuest?>().firstWhere(
            (q) => q?.contentId == semanticKey,
            orElse: () => null,
          );
        }
      }

      if (quest == null) {
        throw Exception('Quest not found for session: $sessionId');
      }

      // Get partner info for Firebase sync
      final partner = _storage.getPartner();

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
