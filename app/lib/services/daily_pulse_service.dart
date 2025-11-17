import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/quiz_expansion.dart';
import '../models/quiz_question.dart';
import '../models/user.dart';
import '../widgets/daily_pulse_widget.dart';
import 'storage_service.dart';
import 'quiz_service.dart';
import 'notification_service.dart';
import '../config/dev_config.dart';
import '../utils/logger.dart';

/// Service for managing Daily Pulse feature
/// - One question per day, alternating subject between partners
/// - Subject answers about themselves, Predictor guesses
/// - Tracks streaks and awards bonus LP
class DailyPulseService {
  final StorageService _storage = StorageService();
  final QuizService _quizService = QuizService();
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  bool _isListening = false;

  /// Get today's Daily Pulse (creates new one if needed)
  QuizDailyPulse getTodaysPulse() {
    final today = _getDateKey(DateTime.now());
    final existingPulse = _storage.getDailyPulse(today);

    if (existingPulse != null) {
      return existingPulse;
    }

    // Create new Daily Pulse for today
    return _createNewDailyPulse();
  }

  /// Check if today's pulse is available
  bool hasTodaysPulse() {
    final today = _getDateKey(DateTime.now());
    return _storage.getDailyPulse(today) != null;
  }

  /// Submit answer for today's Daily Pulse
  Future<void> submitAnswer(String userId, int answerIndex) async {
    final pulse = getTodaysPulse();

    if (pulse.isCompleted) {
      throw Exception('Daily Pulse already completed');
    }

    // Add answer
    pulse.answers ??= {};
    pulse.answers![userId] = answerIndex;

    // Check if both users have answered
    final partner = _storage.getPartner();
    if (partner != null && pulse.answers!.length == 2) {
      pulse.bothAnswered = true;
      await _completeDailyPulse(pulse);
    }

    // Save updated pulse
    _storage.saveDailyPulse(pulse);

    // Sync to RTDB for partner
    await _syncPulseToRTDB(pulse);

    // Send notification to partner
    await _sendAnswerNotification(pulse, userId);
  }

  /// Complete the Daily Pulse and calculate results
  Future<void> _completeDailyPulse(QuizDailyPulse pulse) async {
    final answers = pulse.answers!;

    // Identify subject and predictor
    final subjectAnswer = answers[pulse.subjectUserId];
    final predictorId = answers.keys.firstWhere((id) => id != pulse.subjectUserId);
    final predictorGuess = answers[predictorId];

    if (subjectAnswer == null || predictorGuess == null) {
      throw Exception('Missing answers');
    }

    // Check if match
    pulse.isMatch = subjectAnswer == predictorGuess;
    pulse.completedAt = DateTime.now();

    // Calculate LP (10 for match, 5 for participation)
    int baseLP = pulse.isMatch ? 10 : 5;

    // Check streak and apply multiplier
    final streak = _storage.getStreak('daily_pulse');
    if (streak != null && _isConsecutiveDay(streak.lastCompletedDate)) {
      // Continue streak
      streak.currentStreak++;
      if (streak.currentStreak > streak.longestStreak) {
        streak.longestStreak = streak.currentStreak;
      }
      streak.lastCompletedDate = DateTime.now();
      streak.totalCompleted++;
      await _storage.updateStreak(streak);
    } else {
      // Reset streak or create new
      final newStreak = QuizStreak(
        type: 'daily_pulse',
        currentStreak: 1,
        longestStreak: streak?.longestStreak ?? 1,
        lastCompletedDate: DateTime.now(),
        totalCompleted: (streak?.totalCompleted ?? 0) + 1,
      );
      await _storage.saveStreak(newStreak);
    }

    // Apply streak bonuses
    final currentStreak = _storage.getStreak('daily_pulse')?.currentStreak ?? 1;
    int bonusLP = 0;
    if (currentStreak == 7) bonusLP = 10;
    if (currentStreak == 14) bonusLP = 25;
    if (currentStreak == 30) bonusLP = 50;

    pulse.lpAwarded = baseLP + bonusLP;

    // Update user LP
    final user = _storage.getUser();
    if (user != null) {
      user.lovePoints = (user.lovePoints) + pulse.lpAwarded;
      await user.save();
    }

    // Send notification to both users about completion
    await _sendCompletionNotification(pulse);

    // Check for streak milestones and send special notification
    await _checkStreakMilestone(currentStreak);
  }

  /// Create new Daily Pulse for today
  QuizDailyPulse _createNewDailyPulse() {
    final today = DateTime.now();
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      throw Exception('User or partner not found');
    }

    // Determine subject for today (alternates daily)
    final daysSinceEpoch = today.difference(DateTime(2024, 1, 1)).inDays;
    final isUserSubject = daysSinceEpoch % 2 == 0;
    final subjectUserId = isUserSubject ? user.id : partner.pushToken; // Use pushToken as partner ID

    // Get a random question from question bank
    final question = _quizService.getRandomQuestionForDailyPulse();

    final pulse = QuizDailyPulse(
      id: _getDateKey(today),
      questionId: question.id,
      availableDate: DateTime(today.year, today.month, today.day),
      subjectUserId: subjectUserId,
      answers: {},
      bothAnswered: false,
      lpAwarded: 0,
      completedAt: null,
      isMatch: false,
    );

    _storage.saveDailyPulse(pulse);
    return pulse;
  }

  /// Get the question for today's pulse
  QuizQuestion getTodaysQuestion() {
    final pulse = getTodaysPulse();
    return _quizService.getQuestionById(pulse.questionId);
  }

  /// Check if user has answered today's pulse
  bool hasUserAnswered(String userId) {
    final pulse = getTodaysPulse();
    return pulse.answers?.containsKey(userId) ?? false;
  }

  /// Check if current user is the subject today
  bool isUserSubjectToday() {
    final user = _storage.getUser();
    if (user == null) return false;

    final pulse = getTodaysPulse();
    return pulse.subjectUserId == user.id;
  }

  /// Get current Daily Pulse streak
  int getCurrentStreak() {
    final streak = _storage.getStreak('daily_pulse');
    if (streak == null) return 0;

    // Check if streak is still valid (completed yesterday or today)
    if (_isConsecutiveDay(streak.lastCompletedDate) || _isToday(streak.lastCompletedDate)) {
      return streak.currentStreak;
    }

    return 0; // Streak broken
  }

  /// Get status for Daily Pulse widget
  DailyPulseStatus getDailyPulseStatus() {
    final pulse = getTodaysPulse();
    final user = _storage.getUser();

    if (user == null) return DailyPulseStatus.subjectNotAnswered;

    if (pulse.bothAnswered) {
      return DailyPulseStatus.bothCompleted;
    }

    final hasAnswered = hasUserAnswered(user.id);
    final isSubject = isUserSubjectToday();

    if (hasAnswered) {
      return DailyPulseStatus.waitingForPartner;
    } else if (isSubject) {
      return DailyPulseStatus.subjectNotAnswered;
    } else {
      return DailyPulseStatus.predictorNotAnswered;
    }
  }

  /// Helper: Generate date key (YYYY-MM-DD)
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Helper: Check if date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Helper: Check if date is consecutive day (yesterday or today)
  bool _isConsecutiveDay(DateTime lastDate) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    return _isToday(lastDate) ||
        (lastDate.year == yesterday.year &&
            lastDate.month == yesterday.month &&
            lastDate.day == yesterday.day);
  }

  /// Sync Daily Pulse to RTDB (dev mode only)
  Future<void> _syncPulseToRTDB(QuizDailyPulse pulse) async {
    if (!DevConfig.isSimulatorSync) return;

    try {
      final emulatorId = await DevConfig.emulatorId;
      if (emulatorId == null) return;

      await _rtdb.child('daily_pulses').child(emulatorId).child(pulse.id).set({
        'id': pulse.id,
        'questionId': pulse.questionId,
        'availableDate': pulse.availableDate.millisecondsSinceEpoch,
        'subjectUserId': pulse.subjectUserId,
        'answers': pulse.answers,
        'bothAnswered': pulse.bothAnswered,
        'lpAwarded': pulse.lpAwarded,
        'completedAt': pulse.completedAt?.millisecondsSinceEpoch,
        'isMatch': pulse.isMatch,
      });

      Logger.success('Daily Pulse synced to RTDB: ${pulse.id}', service: 'daily_pulse');
    } catch (e) {
      Logger.error('Error syncing Daily Pulse to RTDB', error: e, service: 'daily_pulse');
    }
  }

  /// Start listening for partner's Daily Pulse updates
  Future<void> startListeningForPartnerPulses() async {
    if (_isListening) return;
    if (!DevConfig.isSimulatorSync) return;

    _isListening = true;

    try {
      final myIndex = await DevConfig.partnerIndex;
      final partnerEmulatorId = myIndex == 0 ? 'web-bob' : 'emulator-5554';

      Logger.info('Listening for partner Daily Pulses: $partnerEmulatorId', service: 'daily_pulse');

      _rtdb.child('daily_pulses').child(partnerEmulatorId).onChildAdded.listen((event) {
        if (event.snapshot.value != null) {
          _handlePartnerPulse(event.snapshot);
        }
      });

      _rtdb.child('daily_pulses').child(partnerEmulatorId).onChildChanged.listen((event) {
        if (event.snapshot.value != null) {
          _handlePartnerPulse(event.snapshot);
        }
      });
    } catch (e) {
      Logger.error('Error listening for partner Daily Pulses', error: e, service: 'daily_pulse');
    }
  }

  /// Handle partner's Daily Pulse from RTDB
  void _handlePartnerPulse(DataSnapshot snapshot) {
    try {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final pulseId = data['id'] as String;

      final existingPulse = _storage.getDailyPulse(pulseId);
      if (existingPulse != null) {
        // Update existing pulse
        existingPulse.answers = data['answers'] != null
            ? Map<String, int>.from(
                (data['answers'] as Map).map(
                  (k, v) => MapEntry(k.toString(), v as int),
                ),
              )
            : {};
        existingPulse.bothAnswered = data['bothAnswered'] as bool;
        existingPulse.lpAwarded = data['lpAwarded'] as int;
        existingPulse.completedAt = data['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'] as int)
            : null;
        existingPulse.isMatch = data['isMatch'] as bool;
        _storage.saveDailyPulse(existingPulse);
        Logger.info('Updated existing Daily Pulse from partner: $pulseId', service: 'daily_pulse');
      } else {
        // Create new pulse from partner
        final pulse = QuizDailyPulse(
          id: pulseId,
          questionId: data['questionId'] as String,
          availableDate: DateTime.fromMillisecondsSinceEpoch(data['availableDate'] as int),
          subjectUserId: data['subjectUserId'] as String,
          answers: data['answers'] != null
              ? Map<String, int>.from(
                  (data['answers'] as Map).map(
                    (k, v) => MapEntry(k.toString(), v as int),
                  ),
                )
              : {},
          bothAnswered: data['bothAnswered'] as bool,
          lpAwarded: data['lpAwarded'] as int,
          completedAt: data['completedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'] as int)
              : null,
          isMatch: data['isMatch'] as bool,
        );

        _storage.saveDailyPulse(pulse);
        Logger.success('Received new Daily Pulse from partner: $pulseId', service: 'daily_pulse');
      }
    } catch (e) {
      Logger.error('Error handling partner Daily Pulse', error: e, service: 'daily_pulse');
    }
  }

  /// Send notification when user answers
  Future<void> _sendAnswerNotification(QuizDailyPulse pulse, String userId) async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      // Determine if user is the subject
      final isSubject = userId == pulse.subjectUserId;

      final callable = _functions.httpsCallable('sendDailyPulseAnswer');
      await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your partner',
        'isSubject': isSubject,
        'pulseId': pulse.id,
      });

      Logger.success('Daily Pulse answer notification sent', service: 'daily_pulse');
    } catch (e) {
      Logger.error('Error sending answer notification', error: e, service: 'daily_pulse');
    }
  }

  /// Send completion notification to both users
  Future<void> _sendCompletionNotification(QuizDailyPulse pulse) async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      final currentStreak = getCurrentStreak();

      final callable = _functions.httpsCallable('sendDailyPulseCompletion');

      // Send to partner
      await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your partner',
        'isMatch': pulse.isMatch,
        'lpEarned': pulse.lpAwarded,
        'currentStreak': currentStreak,
      });

      Logger.success('Daily Pulse completion notification sent', service: 'daily_pulse');
    } catch (e) {
      Logger.error('Error sending completion notification', error: e, service: 'daily_pulse');
    }
  }

  /// Check for streak milestones and send special notification
  Future<void> _checkStreakMilestone(int streak) async {
    // Check if this streak count is a milestone
    if (streak != 7 && streak != 14 && streak != 30) {
      return; // Not a milestone
    }

    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      // Determine milestone message and bonus
      String milestoneText;
      int bonusLP;

      switch (streak) {
        case 7:
          milestoneText = '7 Day Streak! 🔥\n+10 bonus LP for dedication!';
          bonusLP = 10;
          break;
        case 14:
          milestoneText = '2 Week Streak! 🔥🔥\n+25 bonus LP for commitment!';
          bonusLP = 25;
          break;
        case 30:
          milestoneText = '30 Day Streak! 🔥🔥🔥\n+50 bonus LP for consistency!';
          bonusLP = 50;
          break;
        default:
          return;
      }

      final callable = _functions.httpsCallable('sendDailyPulseStreakMilestone');

      // Send to partner
      await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your partner',
        'streak': streak,
        'bonusLP': bonusLP,
        'milestoneText': milestoneText,
      });

      Logger.success('Streak milestone notification sent for $streak days', service: 'daily_pulse');
    } catch (e) {
      Logger.error('Error sending streak milestone notification', error: e, service: 'daily_pulse');
    }
  }
}
