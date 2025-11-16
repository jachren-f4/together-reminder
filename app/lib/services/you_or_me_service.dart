import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/you_or_me.dart';
import '../services/storage_service.dart';
import '../services/love_point_service.dart';
import '../services/quest_utilities.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../models/daily_quest.dart';
import '../config/dev_config.dart';
import '../utils/logger.dart';

/// Service for managing You or Me game sessions
///
/// Handles:
/// - Loading questions from JSON
/// - Random question selection with category variety
/// - Session creation and management
/// - Firebase RTDB synchronization
/// - Background listening for partner sessions
/// - Results calculation
/// - Data cleanup (30 days retention)
class YouOrMeService {
  static final YouOrMeService _instance = YouOrMeService._internal();
  factory YouOrMeService() => _instance;
  YouOrMeService._internal();

  final _storage = StorageService();
  final _database = FirebaseDatabase.instance.ref();

  List<YouOrMeQuestion>? _questionBank;

  // ═══════════════════════════════════════════════════════════════════════════
  // Question Loading & Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load questions from JSON asset
  /// Called once on app startup
  Future<void> loadQuestions() async {
    if (_questionBank != null) {
      Logger.debug('Question bank already loaded', service: 'you_or_me');
      return;
    }

    Logger.info('Loading You or Me question bank', service: 'you_or_me');

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/you_or_me_questions.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;

      _questionBank = (data['questions'] as List)
          .map((q) => YouOrMeQuestion.fromMap(q as Map<String, dynamic>))
          .toList();

      Logger.success(
        'Loaded ${_questionBank!.length} questions',
        service: 'you_or_me',
      );
    } catch (e) {
      Logger.error(
        'Failed to load question bank',
        error: e,
        service: 'you_or_me',
      );
      rethrow;
    }
  }

  /// Get random questions for a new session
  ///
  /// - Ensures category variety (3-4 different categories)
  /// - Max 4 questions per category
  /// - Tracks used questions per couple to avoid repetition
  /// - Resets progression when pool exhausted
  Future<List<YouOrMeQuestion>> getRandomQuestions(
    int count,
    String coupleId,
  ) async {
    await loadQuestions();

    if (_questionBank == null || _questionBank!.isEmpty) {
      throw Exception('Question bank not loaded or empty');
    }

    // Get used question IDs from progression
    final usedIds = _getUsedQuestionIds(coupleId);

    Logger.debug(
      'Question pool: ${_questionBank!.length} total, $usedIds used',
      service: 'you_or_me',
    );

    // Filter available questions
    final available = _questionBank!
        .where((q) => !usedIds.contains(q.id))
        .toList();

    // If not enough available, reset progression
    if (available.length < count) {
      Logger.warn(
        'Not enough questions (${available.length}/$count), resetting progression',
        service: 'you_or_me',
      );
      _resetProgression(coupleId);
      return getRandomQuestions(count, coupleId);
    }

    // Select questions with category variety
    final selected = _selectWithVariety(available, count);

    // Mark as used
    _markQuestionsAsUsed(coupleId, selected);

    Logger.success(
      'Selected $count questions with categories: ${selected.map((q) => q.category).toSet()}',
      service: 'you_or_me',
    );

    return selected;
  }

  /// Select questions ensuring category variety
  ///
  /// Rules:
  /// - At least 3 different categories
  /// - Max 4 questions per category
  List<YouOrMeQuestion> _selectWithVariety(
    List<YouOrMeQuestion> available,
    int count,
  ) {
    final selected = <YouOrMeQuestion>[];
    final categoryCounts = <String, int>{};
    final random = Random();

    // Shuffle available questions
    final shuffled = List<YouOrMeQuestion>.from(available)..shuffle(random);

    // Pick questions with category limits
    for (final question in shuffled) {
      if (selected.length >= count) break;

      final categoryCount = categoryCounts[question.category] ?? 0;

      // Limit any single category to max 4 questions
      if (categoryCount < 4) {
        selected.add(question);
        categoryCounts[question.category] = categoryCount + 1;
      }
    }

    return selected;
  }

  /// Get set of used question IDs for a couple
  Set<String> _getUsedQuestionIds(String coupleId) {
    final box = _storage.youOrMeProgressionBox;
    final data = box.get(coupleId) as Map?;
    if (data == null) return {};
    return (data['usedQuestionIds'] as List? ?? []).cast<String>().toSet();
  }

  /// Mark questions as used in progression tracking
  void _markQuestionsAsUsed(String coupleId, List<YouOrMeQuestion> questions) {
    final box = _storage.youOrMeProgressionBox;
    final data = box.get(coupleId, defaultValue: {}) as Map;
    final usedIds = Set<String>.from(data['usedQuestionIds'] ?? []);

    usedIds.addAll(questions.map((q) => q.id));

    box.put(coupleId, {
      'usedQuestionIds': usedIds.toList(),
      'totalPlayed': (data['totalPlayed'] ?? 0) + 1,
      'lastPlayedAt': DateTime.now().millisecondsSinceEpoch,
    });

    Logger.debug(
      'Marked ${questions.length} questions as used (total: ${usedIds.length})',
      service: 'you_or_me',
    );
  }

  /// Reset progression when all questions exhausted
  void _resetProgression(String coupleId) {
    final box = _storage.youOrMeProgressionBox;
    box.put(coupleId, {
      'usedQuestionIds': [],
      'totalPlayed': 0,
      'lastPlayedAt': DateTime.now().millisecondsSinceEpoch,
    });

    Logger.info('Reset question progression for couple', service: 'you_or_me');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Session Management
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start a new You or Me session (DEPRECATED - use generateDualSessions)
  ///
  /// [questId] - Optional daily quest ID (null if from Activities screen)
  @Deprecated('Use generateDualSessions() instead for two-session architecture')
  Future<YouOrMeSession> startSession({
    required String userId,
    required String partnerId,
    String? questId,
  }) async {
    Logger.info('Starting You or Me session', service: 'you_or_me');

    final coupleId = QuestUtilities.generateCoupleId(userId, partnerId);
    final questions = await getRandomQuestions(10, coupleId);

    final session = YouOrMeSession(
      id: 'youorme_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      partnerId: partnerId,
      questId: questId,
      questions: questions,
      answers: {},
      status: 'in_progress',
      createdAt: DateTime.now(),
      coupleId: coupleId,
      initiatedBy: userId,
      subjectUserId: userId,
    );

    // Save locally
    await _storage.saveYouOrMeSession(session);

    // Sync to Firebase
    await _syncSessionToRTDB(session);

    Logger.success(
      'Started session: ${session.id} (quest: ${questId ?? "standalone"})',
      service: 'you_or_me',
    );

    return session;
  }

  /// Generate TWO You or Me sessions (one per user) with SAME questions
  ///
  /// This implements the two-session architecture used by quiz games.
  /// Both sessions contain identical questions, but each user owns their session.
  ///
  /// [questId] - Optional daily quest ID (null if from Activities screen)
  ///
  /// Returns Map with both sessions:
  /// - Key: userId (who owns the session)
  /// - Value: YouOrMeSession
  Future<Map<String, YouOrMeSession>> generateDualSessions({
    required String userId,
    required String partnerId,
    String? questId,
  }) async {
    Logger.info('Generating dual You or Me sessions', service: 'you_or_me');

    final coupleId = QuestUtilities.generateCoupleId(userId, partnerId);
    final questions = await getRandomQuestions(10, coupleId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // User's session (e.g., Alice's session)
    final userSession = YouOrMeSession(
      id: 'youorme_${userId}_$timestamp',
      userId: userId,
      partnerId: partnerId,
      initiatedBy: userId,
      subjectUserId: userId,
      questId: questId,
      questions: questions, // SAME questions
      answers: {},
      status: 'in_progress',
      createdAt: DateTime.now(),
      coupleId: coupleId,
    );

    // Partner's session (e.g., Bob's session) with SAME questions
    final partnerSession = YouOrMeSession(
      id: 'youorme_${partnerId}_$timestamp',
      userId: partnerId,
      partnerId: userId,
      initiatedBy: partnerId,
      subjectUserId: partnerId,
      questId: questId,
      questions: questions, // SAME questions as userSession
      answers: {},
      status: 'in_progress',
      createdAt: DateTime.now(),
      coupleId: coupleId,
    );

    // Save both sessions locally
    await _storage.saveYouOrMeSession(userSession);
    await _storage.saveYouOrMeSession(partnerSession);

    // Sync both sessions to Firebase
    await _syncSessionToRTDB(userSession);
    await _syncSessionToRTDB(partnerSession);

    Logger.success(
      'Generated dual sessions with same questions: ${userSession.id}, ${partnerSession.id}',
      service: 'you_or_me',
    );

    return {
      userId: userSession,
      partnerId: partnerSession,
    };
  }

  /// Submit user's answers for a session
  ///
  /// Triggers completion if both users have answered
  Future<void> submitAnswers(
    String sessionId,
    String userId,
    List<YouOrMeAnswer> answers,
  ) async {
    Logger.info(
      'Submitting answers for session $sessionId',
      service: 'you_or_me',
    );

    var session = _storage.getYouOrMeSession(sessionId);
    if (session == null) {
      Logger.error('Session not found: $sessionId', service: 'you_or_me');
      throw Exception('Session not found');
    }

    // Validate answer count
    if (answers.length != 10) {
      Logger.error(
        'Invalid answer count: ${answers.length} (expected 10)',
        service: 'you_or_me',
      );
      throw Exception('Must submit exactly 10 answers');
    }

    // Store answers
    session.answers ??= {};
    session.answers![userId] = answers;

    // Save locally
    await session.save();

    // Sync to Firebase
    await _syncSessionToRTDB(session);

    Logger.success(
      'Answers submitted for $userId (${session.getAnswerCount()}/2 users)',
      service: 'you_or_me',
    );

    // Mark quest as completed for this user
    await _markQuestCompletedForUser(sessionId, userId);

    // Check if both answered
    if (session.areBothUsersAnswered()) {
      Logger.info('Both users answered, completing session', service: 'you_or_me');
      await _completeSession(session);
    }
  }

  /// Complete session and award Love Points
  /// Called when both users have submitted answers
  Future<void> _completeSession(YouOrMeSession session) async {
    Logger.info('Completing session: ${session.id}', service: 'you_or_me');

    const lpEarned = 30; // Standard quest reward

    // Award LP to both users
    await LovePointService.awardPointsToBothUsers(
      userId1: session.userId,
      userId2: session.partnerId,
      amount: lpEarned,
      reason: 'you_or_me_completion',
      relatedId: session.id,
    );

    session.lpEarned = lpEarned;
    session.status = 'completed';
    session.completedAt = DateTime.now();

    await session.save();
    await _syncSessionToRTDB(session);

    Logger.success(
      'Session completed, 30 LP awarded to both users',
      service: 'you_or_me',
    );
  }

  /// Get user's own session from a paired session ID
  ///
  /// When a user receives a quest created by their partner, the contentId
  /// points to the partner's session. This method finds the user's own session
  /// by extracting the timestamp and constructing the user's session ID.
  ///
  /// Session ID format: `youorme_{userId}_{timestamp}`
  ///
  /// Example:
  /// - Partner session: `youorme_alice-dev-user-001_1763214684237`
  /// - User session:    `youorme_bob-dev-user-002_1763214684237`
  Future<YouOrMeSession?> getUserSessionFromPaired(String pairedSessionId, String userId) async {
    try {
      Logger.info(
        'Getting user session from paired: pairedId=$pairedSessionId, userId=$userId',
        service: 'you_or_me',
      );

      // Extract timestamp from paired session ID
      final parts = pairedSessionId.split('_');
      Logger.debug('Session ID parts: $parts', service: 'you_or_me');

      if (parts.length < 3) {
        Logger.error('Invalid session ID format: $pairedSessionId (parts: ${parts.length})', service: 'you_or_me');
        return null;
      }

      // Last part is the timestamp
      final timestamp = parts.last;
      Logger.debug('Extracted timestamp: $timestamp', service: 'you_or_me');

      // Construct user's own session ID
      final userSessionId = 'youorme_${userId}_$timestamp';
      Logger.info(
        'Constructed user session ID: $userSessionId',
        service: 'you_or_me',
      );

      // Try to get user's session (checks local storage first, then Firebase)
      final session = await getSession(userSessionId);

      if (session == null) {
        Logger.error(
          'User session not found! Looked for: $userSessionId',
          service: 'you_or_me',
        );
      } else {
        Logger.success(
          'Found user session: $userSessionId',
          service: 'you_or_me',
        );
      }

      return session;
    } catch (e) {
      Logger.error('Error finding user session from paired', error: e, service: 'you_or_me');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Firebase RTDB Sync
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sync session to Firebase RTDB using couple ID path
  Future<void> _syncSessionToRTDB(YouOrMeSession session) async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) {
        Logger.warn('User or partner not found, skipping Firebase sync', service: 'you_or_me');
        return;
      }

      final coupleId = _generateCoupleId(user.id, partner.pushToken);
      final sessionRef = _database
          .child('you_or_me_sessions')
          .child(coupleId)
          .child(session.id);

      await sessionRef.set(session.toMap());

      Logger.debug(
        'Synced session to Firebase: ${session.id}',
        service: 'you_or_me',
      );
    } catch (e) {
      Logger.error(
        'Failed to sync session to Firebase',
        error: e,
        service: 'you_or_me',
      );
      // Don't rethrow - allow local storage to continue
    }
  }

  /// Get session with Firebase fallback using couple ID path
  ///
  /// Tries in order:
  /// 1. Local storage (fastest)
  /// 2. Firebase couple ID path (shared by both users)
  Future<YouOrMeSession?> getSession(String sessionId, {bool forceRefresh = false}) async {
    // If not forcing refresh, try local storage first
    if (!forceRefresh) {
      var session = _storage.getYouOrMeSession(sessionId);
      if (session != null) {
        Logger.debug('Session found in local storage', service: 'you_or_me');
        return session;
      }
    }

    Logger.debug(
      forceRefresh
          ? 'Force refreshing session from Firebase'
          : 'Session not in local storage, checking Firebase',
      service: 'you_or_me',
    );

    // 2. Try Firebase couple ID path
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) {
        Logger.warn('User or partner not found, cannot check Firebase', service: 'you_or_me');
        return null;
      }

      final coupleId = _generateCoupleId(user.id, partner.pushToken);
      final snapshot = await _database
          .child('you_or_me_sessions')
          .child(coupleId)
          .child(sessionId)
          .once();

      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(
          snapshot.snapshot.value as Map,
        );
        final session = YouOrMeSession.fromMap(data);

        Logger.debug('Session found in Firebase couple path', service: 'you_or_me');
        await _storage.saveYouOrMeSession(session); // Cache locally
        return session;
      }
    } catch (e) {
      Logger.error(
        'Failed to load session from Firebase',
        error: e,
        service: 'you_or_me',
      );
    }

    Logger.warn('Session not found anywhere: $sessionId', service: 'you_or_me');
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Background Listener
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start listening for couple's sessions using couple ID path
  /// Called once on app startup
  Future<void> startListeningForPartnerSessions() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) {
        throw Exception('User or partner not found');
      }

      final coupleId = _generateCoupleId(user.id, partner.pushToken);

      Logger.info(
        'Starting listener for couple sessions: $coupleId',
        service: 'you_or_me',
      );

      final ref = _database
          .child('you_or_me_sessions')
          .child(coupleId);

      // Listen for new sessions
      ref.onChildAdded.listen((event) {
        try {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final session = YouOrMeSession.fromMap(data);
          _storage.saveYouOrMeSession(session);
          Logger.debug(
            'Partner session added: ${session.id}',
            service: 'you_or_me',
          );
        } catch (e) {
          Logger.error(
            'Failed to process partner session',
            error: e,
            service: 'you_or_me',
          );
        }
      });

      // Listen for session updates
      ref.onChildChanged.listen((event) {
        try {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final session = YouOrMeSession.fromMap(data);
          _storage.saveYouOrMeSession(session);
          Logger.debug(
            'Partner session updated: ${session.id}',
            service: 'you_or_me',
          );
        } catch (e) {
          Logger.error(
            'Failed to process partner session update',
            error: e,
            service: 'you_or_me',
          );
        }
      });

      Logger.success('Partner session listener started', service: 'you_or_me');
    } catch (e) {
      Logger.warn(
        'Could not start partner listener (no partner yet?)',
        service: 'you_or_me',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Results Calculation
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calculate results for a completed session (two-session architecture)
  ///
  /// Works with the new two-session architecture where each user has their own session.
  /// Compares answers across sessions to determine agreement.
  ///
  /// Returns stats about:
  /// - Number of matches (how many times they agreed)
  /// - Agreement percentage
  /// - Detailed question-by-question comparison
  Map<String, dynamic> calculateResults(YouOrMeSession session) {
    if (!session.areBothUsersAnswered()) {
      throw Exception('Cannot calculate results - both users must answer');
    }

    final userAnswers = session.answers![session.userId]!;
    final partnerAnswers = session.answers![session.partnerId]!;

    Logger.debug(
      'Calculating results for session ${session.id} (subject: ${session.subjectUserId})',
      service: 'you_or_me',
    );

    int agreements = 0;
    final comparisons = <Map<String, dynamic>>[];

    // Compare each question
    for (int i = 0; i < session.questions.length; i++) {
      final question = session.questions[i];
      final userAnswer = userAnswers[i].answerValue;
      final partnerAnswer = partnerAnswers[i].answerValue;

      // Determine who each person thinks is more likely
      // In this session, the subject is session.subjectUserId
      // - If answer is true ("Me"), they think the subject (session owner)
      // - If answer is false ("You"), they think the non-subject (partner)

      final userThinks = userAnswer ? session.subjectUserId : session.partnerId;
      final partnerThinks = partnerAnswer ? session.subjectUserId : session.partnerId;

      final agreed = userThinks == partnerThinks;
      if (agreed) agreements++;

      // Convert boolean answers to string format for results screen
      // true = "Me" (subject), false = "You" (partner)
      final userAnswerString = userAnswer ? 'me' : 'partner';
      final partnerAnswerString = partnerAnswer ? 'me' : 'partner';

      comparisons.add({
        'question': question,  // Full question object
        'userAnswer': userAnswerString,  // String format
        'partnerAnswer': partnerAnswerString,  // String format
        'agreed': agreed,  // boolean
      });

      Logger.debug(
        'Q${i + 1}: ${question.content} - User thinks: $userThinks, Partner thinks: $partnerThinks - ${agreed ? "AGREED" : "different"}',
        service: 'you_or_me',
      );
    }

    final totalQuestions = session.questions.length;
    final disagreements = totalQuestions - agreements;

    final results = {
      'agreements': agreements,
      'disagreements': disagreements,
      'agreementPercentage': (agreements / totalQuestions * 100).round(),
      'comparisons': comparisons,
      'totalQuestions': totalQuestions,
    };

    Logger.success(
      'Results: ${results['agreementPercentage']}% agreement ($agreements/$totalQuestions matches)',
      service: 'you_or_me',
    );

    return results;
  }

  /// Calculate results from two separate sessions (dual-session architecture)
  ///
  /// This method handles the case where each user has their own session
  /// instead of both users' answers being in the same session.
  ///
  /// @param userSession The current user's session with their answers
  /// @param partnerSession The partner's session (can be null if not available)
  Map<String, dynamic> calculateResultsFromDualSessions(
    YouOrMeSession userSession,
    YouOrMeSession? partnerSession,
  ) {
    // If no partner session, return partial results
    if (partnerSession == null || partnerSession.answers == null) {
      Logger.info(
        'No partner session available, returning partial results',
        service: 'you_or_me',
      );

      return {
        'agreements': 0,
        'disagreements': 0,
        'agreementPercentage': 0,
        'comparisons': [],
        'totalQuestions': userSession.questions.length,
        'partnerCompleted': false,
      };
    }

    // Extract answers from each session
    final userAnswers = userSession.answers![userSession.userId];
    final partnerAnswers = partnerSession.answers![partnerSession.userId];

    if (userAnswers == null || partnerAnswers == null) {
      Logger.warn(
        'Missing answers in one of the sessions',
        service: 'you_or_me',
      );
      return {
        'agreements': 0,
        'disagreements': 0,
        'agreementPercentage': 0,
        'comparisons': [],
        'totalQuestions': userSession.questions.length,
        'partnerCompleted': false,
      };
    }

    Logger.debug(
      'Calculating results from dual sessions: ${userSession.id} and ${partnerSession.id}',
      service: 'you_or_me',
    );

    int agreements = 0;
    final comparisons = <Map<String, dynamic>>[];

    // Compare each question
    for (int i = 0; i < userSession.questions.length; i++) {
      final question = userSession.questions[i];
      final userAnswer = userAnswers[i].answerValue;
      final partnerAnswer = partnerAnswers[i].answerValue;

      // Determine who each person thinks is more likely
      // Note: In dual sessions, each session might have different subjectUserId
      // We need to normalize based on the actual users
      final userThinks = userAnswer ? userSession.userId : userSession.partnerId;
      final partnerThinks = partnerAnswer ? partnerSession.userId : partnerSession.partnerId;

      // For agreement, we check if they both selected the same person
      final agreed = userThinks == partnerThinks;
      if (agreed) agreements++;

      // Convert boolean answers to string format for results screen
      final userAnswerString = userAnswer ? 'me' : 'partner';
      final partnerAnswerString = partnerAnswer ? 'me' : 'partner';

      comparisons.add({
        'question': question,
        'userAnswer': userAnswerString,
        'partnerAnswer': partnerAnswerString,
        'agreed': agreed,
      });
    }

    final totalQuestions = userSession.questions.length;
    final disagreements = totalQuestions - agreements;

    final results = {
      'agreements': agreements,
      'disagreements': disagreements,
      'agreementPercentage': (agreements / totalQuestions * 100).round(),
      'comparisons': comparisons,
      'totalQuestions': totalQuestions,
      'partnerCompleted': true,
    };

    Logger.success(
      'Dual session results: ${results['agreementPercentage']}% agreement ($agreements/$totalQuestions matches)',
      service: 'you_or_me',
    );

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data Cleanup
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clean up sessions older than 30 days
  /// Called periodically on app startup
  Future<void> cleanupOldSessions() async {
    final box = _storage.youOrMeSessionsBox;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    final toDelete = <String>[];
    for (final session in box.values) {
      if (session.createdAt.isBefore(cutoff)) {
        toDelete.add(session.id);
      }
    }

    for (final id in toDelete) {
      await box.delete(id);
    }

    if (toDelete.isNotEmpty) {
      Logger.info(
        'Cleaned up ${toDelete.length} old You or Me sessions',
        service: 'you_or_me',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate couple ID from two user IDs
  /// Ensures consistent couple ID regardless of who initiates
  String _generateCoupleId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Mark daily quest as completed for the user who submitted answers
  ///
  /// Unlike quiz service, You or Me uses dual sessions with different IDs.
  /// We need to match quests by timestamp since both sessions share the same timestamp.
  Future<void> _markQuestCompletedForUser(String sessionId, String userId) async {
    try {
      Logger.info(
        'Marking quest completed for user: $userId, session: $sessionId',
        service: 'you_or_me',
      );

      // Extract timestamp from session ID (format: youorme_{userId}_{timestamp})
      final sessionParts = sessionId.split('_');
      if (sessionParts.length < 3) {
        Logger.error('Invalid session ID format for quest marking: $sessionId', service: 'you_or_me');
        return;
      }
      final timestamp = sessionParts.last;

      // Find the quest that has a contentId with the same timestamp
      final quests = _storage.getTodayQuests();
      final quest = quests.firstWhere(
        (q) {
          if (q.type != QuestType.youOrMe) return false;

          // Extract timestamp from quest's contentId
          final questIdParts = q.contentId.split('_');
          if (questIdParts.length < 3) return false;

          // Match by timestamp since both sessions share the same timestamp
          return questIdParts.last == timestamp;
        },
        orElse: () => throw Exception('Quest not found for session timestamp: $timestamp'),
      );

      Logger.debug(
        'Found quest: ${quest.id} with contentId: ${quest.contentId}',
        service: 'you_or_me',
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

      Logger.success(
        'Quest marked completed for user $userId',
        service: 'you_or_me',
      );
    } catch (e) {
      Logger.error('Could not mark quest completed', error: e, service: 'you_or_me');
      // Don't throw - this is a non-critical operation
    }
  }
}
