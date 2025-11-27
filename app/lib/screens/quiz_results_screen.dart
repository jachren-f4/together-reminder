import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import '../utils/logger.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../models/daily_quest.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../services/quest_utilities.dart';
import '../services/haptic_service.dart';
import '../services/celebration_service.dart';
import '../animations/animation_config.dart';
import '../widgets/editorial/editorial.dart';

class QuizResultsScreen extends StatefulWidget {
  final QuizSession session;

  const QuizResultsScreen({super.key, required this.session});

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen>
    with TickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  late ConfettiController _confettiController;
  late List<QuizQuestion> _questions;

  // Animation controllers for Phase 2 visual effects
  late AnimationController _scoreRingController;
  late AnimationController _rewardCardController;
  late Animation<double> _scoreRingAnimation;
  late Animation<double> _rewardFadeAnimation;
  late Animation<double> _rewardScaleAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _questions = _quizService.getSessionQuestions(widget.session);

    // Initialize score ring animation (arc draw effect)
    _scoreRingController = AnimationController(
      vsync: this,
      duration: AnimationConfig.celebrationIn,
    );
    _scoreRingAnimation = CurvedAnimation(
      parent: _scoreRingController,
      curve: AnimationConfig.scaleIn,
    );

    // Initialize reward card animation (staggered reveal)
    _rewardCardController = AnimationController(
      vsync: this,
      duration: AnimationConfig.normal,
    );
    _rewardFadeAnimation = CurvedAnimation(
      parent: _rewardCardController,
      curve: AnimationConfig.fadeIn,
    );
    _rewardScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rewardCardController,
      curve: AnimationConfig.scaleIn,
    ));

    // Trigger celebration for high scores (80%+) with confetti, sound, and haptic
    if ((widget.session.matchPercentage ?? 0) >= 80) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final celebrationType = (widget.session.matchPercentage ?? 0) == 100
            ? CelebrationType.perfectScore
            : CelebrationType.questComplete;
        CelebrationService().celebrate(
          celebrationType,
          confettiController: _confettiController,
        );
      });
    }

    // Start animations with staggered timing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scoreRingController.forward();
      // Delay reward card animation for staggered effect
      Future.delayed(AnimationConfig.staggerDelay, () {
        if (mounted) {
          _rewardCardController.forward();
          HapticService().trigger(HapticType.success);
        }
      });
    });

    _checkQuestCompletion();
  }

  Future<void> _checkQuestCompletion() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      final questService = DailyQuestService(storage: _storage);
      final todayQuests = questService.getTodayQuests();

      final matchingQuest = todayQuests.where((q) =>
        q.type == QuestType.quiz && q.contentId == widget.session.id
      ).firstOrNull;

      if (matchingQuest == null) return;

      final userAnswers = widget.session.answers?[user.id];
      if (userAnswers == null || userAnswers.length < widget.session.questionIds.length) {
        return;
      }

      final bothCompleted = await questService.completeQuestForUser(
        questId: matchingQuest.id,
        userId: user.id,
      );

      final syncService = QuestSyncService(storage: _storage);

      await syncService.markQuestCompleted(
        questId: matchingQuest.id,
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );

      if (bothCompleted) {
        await LovePointService.awardPointsToBothUsers(
          userId1: user.id,
          userId2: partner.pushToken,
          amount: 30,
          reason: 'daily_quest_quiz',
          relatedId: matchingQuest.id,
        );

        await _checkDailyQuestsCompletion(questService, user.id, partner.pushToken);
      }
    } catch (e) {
      Logger.error('Error checking quest completion', error: e, service: 'quiz');
    }
  }

  Future<void> _checkDailyQuestsCompletion(
    DailyQuestService questService,
    String currentUserId,
    String partnerUserId,
  ) async {
    try {
      if (questService.areAllMainQuestsCompleted()) {
        final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
        var progressionState = _storage.getQuizProgressionState(coupleId);
        if (progressionState == null) return;

        for (int i = 0; i < 3; i++) {
          progressionState.currentPosition++;
          if (progressionState.currentPosition >= 4) {
            progressionState.currentTrack++;
            progressionState.currentPosition = 0;
            if (progressionState.currentTrack >= 3) {
              progressionState.hasCompletedAllTracks = true;
              progressionState.currentTrack = 2;
              progressionState.currentPosition = 3;
              break;
            }
          }
        }

        await _storage.updateQuizProgressionState(progressionState);

        final syncService = QuestSyncService(storage: _storage);
        await syncService.saveProgressionState(progressionState);
      }
    } catch (e) {
      Logger.error('Error checking daily quests completion', error: e, service: 'quiz');
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scoreRingController.dispose();
    _rewardCardController.dispose();
    super.dispose();
  }

  String _getMatchMessage(int percentage) {
    if (percentage == 100) return '"Perfect sync!"';
    if (percentage >= 80) return '"Great minds think alike!"';
    if (percentage >= 60) return '"On the same wavelength!"';
    if (percentage >= 40) return '"Learning more every day!"';
    return '"Every quiz brings you closer!"';
  }

  void _shareResults() {
    final matchPercentage = widget.session.matchPercentage ?? 0;
    final lpEarned = widget.session.lpEarned ?? 0;
    Share.share(
      'We scored $matchPercentage% on our couple quiz and earned $lpEarned LP! 💕\n\n'
      'Try TogetherRemind to test how well you know your partner!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchPercentage = widget.session.matchPercentage ?? 0;
    final lpEarned = widget.session.lpEarned ?? 0;
    final answers = widget.session.answers ?? {};
    final userIds = answers.keys.toList();
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    // Calculate stats
    int matchCount = 0;
    if (userIds.length >= 2) {
      for (int i = 0; i < _questions.length; i++) {
        if (answers[userIds[0]]?[i] == answers[userIds[1]]?[i]) {
          matchCount++;
        }
      }
    }
    final differentCount = _questions.length - matchCount;

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header
                EditorialHeaderSimple(
                  title: 'Quiz Complete',
                  onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Score hero
                        _buildScoreHero(matchPercentage),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stats grid
                              _buildStatsGrid(matchCount, differentCount, _questions.length),
                              const SizedBox(height: 32),

                              // Answer breakdown header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('ANSWER BREAKDOWN', style: EditorialStyles.labelUppercase),
                                  Text(
                                    'Scroll for more',
                                    style: EditorialStyles.bodySmall.copyWith(
                                      color: EditorialStyles.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Answer cards
                              if (userIds.length >= 2)
                                ..._questions.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final question = entry.value;
                                  final myAnswer = user != null && answers.containsKey(user.id)
                                      ? answers[user.id]![index]
                                      : answers[userIds[0]]![index];
                                  final partnerAnswer = user != null && answers.containsKey(user.id)
                                      ? answers[userIds.firstWhere((id) => id != user.id)]![index]
                                      : answers[userIds[1]]![index];
                                  final isMatch = myAnswer == partnerAnswer;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildAnswerCard(
                                      question,
                                      myAnswer,
                                      partnerAnswer,
                                      isMatch,
                                      partnerName,
                                    ),
                                  );
                                }),

                              // Reward card
                              const SizedBox(height: 12),
                              _buildRewardCard(lpEarned),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: EditorialStyles.paper,
                    border: Border(top: EditorialStyles.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: EditorialSecondaryButton(
                          label: 'Share',
                          onPressed: _shareResults,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EditorialPrimaryButton(
                          label: 'Done',
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Confetti with brand colors via CelebrationService
          CelebrationService().createConfettiWidget(
            _confettiController,
            type: (widget.session.matchPercentage ?? 0) == 100
                ? CelebrationType.perfectScore
                : CelebrationType.questComplete,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreHero(int matchPercentage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border(bottom: EditorialStyles.border),
      ),
      child: Column(
        children: [
          Text(
            'YOUR MATCH SCORE',
            style: EditorialStyles.labelUppercaseSmall,
          ),
          const SizedBox(height: 16),

          // Animated score ring with arc draw effect
          AnimatedBuilder(
            animation: _scoreRingAnimation,
            builder: (context, child) {
              return SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
                    percentage: (matchPercentage / 100) * _scoreRingAnimation.value,
                    trackColor: EditorialStyles.inkLight,
                    progressColor: EditorialStyles.ink,
                  ),
                  child: Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${(matchPercentage * _scoreRingAnimation.value).round()}',
                            style: EditorialStyles.scoreLarge,
                          ),
                          TextSpan(
                            text: '%',
                            style: EditorialStyles.scoreMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Fade in the message after ring animation
          AnimatedBuilder(
            animation: _scoreRingAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _scoreRingAnimation.value,
                child: Text(
                  _getMatchMessage(matchPercentage),
                  style: EditorialStyles.bodyText.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int matched, int different, int total) {
    return Row(
      children: [
        Expanded(child: _buildStatBox('$matched', 'Matched')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatBox('$different', 'Different')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatBox('$total', 'Total')),
      ],
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Column(
        children: [
          Text(value, style: EditorialStyles.scoreMedium),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: EditorialStyles.labelUppercaseSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(
    QuizQuestion question,
    int myAnswerIndex,
    int partnerAnswerIndex,
    bool isMatch,
    String partnerName,
  ) {
    final myAnswer = question.options[myAnswerIndex];
    final partnerAnswer = question.options[partnerAnswerIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMatch ? EditorialStyles.inkLight.withValues(alpha: 0.3) : EditorialStyles.paper,
        border: EditorialStyles.fullBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: EditorialStyles.bodySmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Answer comparison
          Row(
            children: [
              Expanded(
                child: _buildAnswerItem('You Said', myAnswer, isMatch),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnswerItem('$partnerName Said', partnerAnswer, isMatch),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Match indicator
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isMatch ? EditorialStyles.ink : EditorialStyles.paper,
                  shape: BoxShape.circle,
                  border: isMatch ? null : Border.all(color: EditorialStyles.ink, width: 2),
                ),
                child: Center(
                  child: Icon(
                    isMatch ? Icons.check : Icons.close,
                    size: 12,
                    color: isMatch ? EditorialStyles.paper : EditorialStyles.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isMatch ? 'MATCH' : 'DIFFERENT',
                style: EditorialStyles.labelUppercaseSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerItem(String label, String value, bool isMatch) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border.all(
          color: isMatch ? EditorialStyles.ink : EditorialStyles.inkLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: EditorialStyles.labelUppercaseSmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: EditorialStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(int lpEarned) {
    return AnimatedBuilder(
      animation: _rewardCardController,
      builder: (context, child) {
        return Transform.scale(
          scale: _rewardScaleAnimation.value,
          child: Opacity(
            opacity: _rewardFadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: EditorialStyles.ink,
                border: EditorialStyles.fullBorder,
              ),
              child: Column(
                children: [
                  Text(
                    'YOU EARNED',
                    style: EditorialStyles.labelUppercase.copyWith(
                      color: EditorialStyles.paper.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Animated LP count that counts up
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: lpEarned),
                    duration: AnimationConfig.normal,
                    builder: (context, value, child) {
                      return Text(
                        '+$value LP',
                        style: TextStyle(
                          fontFamily: EditorialStyles.scoreLarge.fontFamily,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: EditorialStyles.paper,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double percentage;
  final Color trackColor;
  final Color progressColor;

  _ScoreRingPainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
