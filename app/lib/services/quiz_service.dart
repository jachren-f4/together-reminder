import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../models/badge.dart';
import '../models/user.dart';
import '../models/partner.dart';
import 'storage_service.dart';
import 'quiz_question_bank.dart';
import 'love_point_service.dart';
import '../config/dev_config.dart';

class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  final StorageService _storage = StorageService();
  final QuizQuestionBank _questionBank = QuizQuestionBank();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  bool _isListening = false;

  /// Start a new quiz session
  /// The initiator becomes the SUBJECT - quiz is ABOUT them
  /// Partner becomes the PREDICTOR - tries to guess subject's answers
  Future<QuizSession> startQuizSession({
    String formatType = 'classic',
    String? categoryFilter,
    int? difficulty,
  }) async {
    // Check for active session
    final activeSession = _storage.getActiveQuizSession();
    if (activeSession != null) {
      throw Exception('A quiz is already in progress. Complete it first.');
    }

    // Ensure question bank is loaded
    await _questionBank.initialize();

    // Get random questions based on format type
    final List<QuizQuestion> questions;
    final int requiredQuestions;

    if (formatType == 'speed_round') {
      questions = _questionBank.getRandomQuestionsForSpeedRound();
      requiredQuestions = 10;
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
      answers: {},
    );

    await _storage.saveQuizSession(session);

    // Sync to RTDB for partner to receive (backup to push notifications)
    await _syncSessionToRTDB(session);

    // Send notification to partner
    await _sendQuizInviteNotification(session);

    print('✅ Quiz session started: ${session.id} (Subject: ${user.name}, Format: $formatType)');
    return session;
  }

  /// Submit answers for a quiz session
  Future<void> submitAnswers(String sessionId, String userId, List<int> answers) async {
    final session = _storage.getQuizSession(sessionId);
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

    print('✅ Answers submitted for user $userId');

    // Check if both partners have answered
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user != null && partner != null) {
      final bothAnswered = session.answers!.length >= 2;

      if (bothAnswered) {
        // Calculate results and award LP
        await _calculateAndCompleteSession(session);
      } else {
        // Notify partner if they haven't answered yet
        await _sendQuizReminderNotification(session, userId);
      }
    }
  }

  /// Calculate match percentage and complete session
  /// NEW LOGIC: Compare SUBJECT's self-answers vs. PREDICTOR's guesses
  Future<void> _calculateAndCompleteSession(QuizSession session) async {
    final answers = session.answers!;
    if (answers.length < 2) return;

    // Identify subject and predictor
    final subjectAnswers = answers[session.subjectUserId];
    if (subjectAnswers == null) {
      print('❌ Error: Subject has not answered yet');
      return;
    }

    // Find predictor (the other user)
    final predictorId = answers.keys.firstWhere(
      (id) => id != session.subjectUserId,
      orElse: () => '',
    );
    if (predictorId.isEmpty) {
      print('❌ Error: Predictor not found');
      return;
    }

    final predictorGuesses = answers[predictorId];
    if (predictorGuesses == null) {
      print('❌ Error: Predictor has not answered yet');
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

    // Award LP based on match percentage
    int lpEarned = 0;
    if (matchPercentage == 100) {
      lpEarned = 50; // Perfect match
      await _awardPerfectSyncBadge();
    } else if (matchPercentage >= 80) {
      lpEarned = 30; // Great match
    } else if (matchPercentage >= 60) {
      lpEarned = 20; // Good match
    } else {
      lpEarned = 10; // Participation
    }

    // Update session
    session.matchPercentage = matchPercentage;
    session.lpEarned = lpEarned;
    session.status = 'completed';
    session.completedAt = DateTime.now();
    await session.save();

    // Award LP to current user
    if (lpEarned > 0) {
      await LovePointService.awardPoints(
        amount: lpEarned,
        reason: 'quiz_completed',
        relatedId: session.id,
      );
    }

    // Send completion notification to both users
    await _sendQuizCompletedNotification(session, matchPercentage, lpEarned);

    print('✅ Quiz completed: $matchPercentage% match, +$lpEarned LP earned');
  }

  /// Award Perfect Sync badge if not already earned
  Future<void> _awardPerfectSyncBadge() async {
    const badgeName = 'Perfect Sync';

    // Check if badge already exists
    if (_storage.hasBadge(badgeName)) {
      print('Badge "$badgeName" already earned');
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
    print('🏆 Badge earned: $badgeName');
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

      print('✅ Quiz invite sent to partner: $message');
    } catch (e) {
      print('❌ Error sending quiz invite: $e');
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

      print('✅ Quiz reminder sent to partner');
    } catch (e) {
      print('❌ Error sending quiz reminder: $e');
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

      print('✅ Quiz completion notification sent');
    } catch (e) {
      print('❌ Error sending completion notification: $e');
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
    return session.questionIds
        .map((id) => _storage.getQuizQuestion(id))
        .where((q) => q != null)
        .cast<QuizQuestion>()
        .toList();
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
  bool isSpeedRoundUnlocked() {
    return getCompletedClassicQuizzesCount() >= 5;
  }

  /// Sync quiz session to RTDB (dev mode only)
  Future<void> _syncSessionToRTDB(QuizSession session) async {
    // Only sync in debug mode on simulators
    if (!DevConfig.isSimulatorSync) {
      return;
    }

    try {
      final emulatorId = await DevConfig.emulatorId;
      if (emulatorId == null) return;

      await _rtdb.child('quiz_sessions').child(emulatorId).child(session.id).set({
        'id': session.id,
        'questionIds': session.questionIds,
        'createdAt': session.createdAt.millisecondsSinceEpoch,
        'expiresAt': session.expiresAt.millisecondsSinceEpoch,
        'status': session.status,
        'initiatedBy': session.initiatedBy,
        'answers': session.answers,
        'matchPercentage': session.matchPercentage,
        'lpEarned': session.lpEarned,
        'completedAt': session.completedAt?.millisecondsSinceEpoch,
      });

      print('✅ Quiz session synced to RTDB: ${session.id}');
    } catch (e) {
      print('❌ Error syncing quiz session to RTDB: $e');
    }
  }

  /// Start listening for partner's quiz sessions
  Future<void> startListeningForPartnerSessions() async {
    if (_isListening) return;
    if (!DevConfig.isSimulatorSync) return;

    _isListening = true;

    try {
      final myIndex = await DevConfig.partnerIndex;
      // For now, hardcode: Alice (index 0) listens for Bob (web-bob), Bob (index 1) listens for Alice (emulator-5554)
      final partnerEmulatorId = myIndex == 0 ? 'web-bob' : 'emulator-5554';

      print('👂 Listening for partner quiz sessions: $partnerEmulatorId');

      _rtdb.child('quiz_sessions').child(partnerEmulatorId).onChildAdded.listen((event) {
        if (event.snapshot.value != null) {
          _handlePartnerQuizSession(event.snapshot);
        }
      });

      _rtdb.child('quiz_sessions').child(partnerEmulatorId).onChildChanged.listen((event) {
        if (event.snapshot.value != null) {
          _handlePartnerQuizSession(event.snapshot);
        }
      });
    } catch (e) {
      print('❌ Error listening for partner quiz sessions: $e');
    }
  }

  /// Handle partner's quiz session from RTDB
  void _handlePartnerQuizSession(DataSnapshot snapshot) {
    try {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final sessionId = data['id'] as String;

      // Check if we already have this session
      final existingSession = _storage.getQuizSession(sessionId);
      if (existingSession != null) {
        // Update existing session
        existingSession.status = data['status'] as String;
        existingSession.answers = data['answers'] != null
            ? Map<String, List<int>>.from(
                (data['answers'] as Map).map(
                  (k, v) => MapEntry(k.toString(), List<int>.from(v)),
                ),
              )
            : {};
        existingSession.matchPercentage = data['matchPercentage'] as int?;
        existingSession.lpEarned = data['lpEarned'] as int?;
        existingSession.completedAt = data['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'] as int)
            : null;
        existingSession.save();
        print('🔄 Updated existing quiz session from partner: $sessionId');
      } else {
        // Create new session
        final session = QuizSession(
          id: sessionId,
          questionIds: List<String>.from(data['questionIds'] ?? []),
          createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] as int),
          status: data['status'] as String,
          initiatedBy: data['initiatedBy'] as String,
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

        _storage.saveQuizSession(session);
        print('✅ Received new quiz session from partner: $sessionId');
      }
    } catch (e) {
      print('❌ Error handling partner quiz session: $e');
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
