import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import '../utils/logger.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../services/haptic_service.dart';
import '../services/celebration_service.dart';
import '../animations/animation_config.dart';
import '../models/daily_quest.dart';
import '../services/quest_utilities.dart';
import '../widgets/editorial/editorial.dart';

/// Results screen for affirmation-style quizzes
/// Editorial newspaper aesthetic with fraction score display
class AffirmationResultsScreen extends StatefulWidget {
  final QuizSession session;

  const AffirmationResultsScreen({
    super.key,
    required this.session,
  });

  @override
  State<AffirmationResultsScreen> createState() => _AffirmationResultsScreenState();
}

class _AffirmationResultsScreenState extends State<AffirmationResultsScreen>
    with TickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  late List<QuizQuestion> _questions;
  late ConfettiController _confettiController;

  // Animation controllers for LP reward card
  late AnimationController _rewardCardController;
  late Animation<double> _rewardFadeAnimation;
  late Animation<double> _rewardScaleAnimation;

  @override
  void initState() {
    super.initState();
    _questions = _quizService.getSessionQuestions(widget.session);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

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

    // Start animation with delay for staggered effect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Trigger celebration with confetti and sound
      CelebrationService().celebrate(
        CelebrationType.questComplete,
        confettiController: _confettiController,
      );

      Future.delayed(AnimationConfig.staggerDelay, () {
        if (mounted) {
          _rewardCardController.forward();
        }
      });
    });

    _checkQuestCompletion();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _rewardCardController.dispose();
    super.dispose();
  }

  /// Calculate total score from 1-5 scale answers
  int _calculateTotalScore(List<int> answers) {
    if (answers.isEmpty) return 0;
    // Answers are 0-indexed (0-4), convert to 1-5
    return answers.fold(0, (sum, answer) => sum + (answer + 1));
  }

  /// Get max possible score
  int _getMaxScore() {
    return _questions.length * 5;
  }

  /// Get rating label based on percentage
  String _getRatingLabel(int score, int maxScore) {
    final percentage = (score / maxScore * 100).round();
    if (percentage >= 90) return 'EXCELLENT';
    if (percentage >= 75) return 'VERY GOOD';
    if (percentage >= 60) return 'GOOD';
    if (percentage >= 40) return 'FAIR';
    return 'NEEDS ATTENTION';
  }

  /// Get encouraging message based on score
  String _getScoreMessage(int score, int maxScore) {
    final percentage = (score / maxScore * 100).round();
    final category = widget.session.category ?? 'this area';

    if (percentage >= 80) {
      return 'Your responses show a strong foundation of $category in your relationship.';
    } else if (percentage >= 60) {
      return 'You have a solid base in $category with room for growth together.';
    } else {
      return 'This is a great opportunity to strengthen $category together.';
    }
  }

  /// Get answer label for 1-5 scale
  String _getAnswerLabel(int index) {
    const labels = ['Strongly Disagree', 'Disagree', 'Neutral', 'Agree', 'Strongly Agree'];
    if (index >= 0 && index < labels.length) {
      return labels[index];
    }
    return 'Unknown';
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
        Logger.success('Daily affirmation quest completed by both users! Awarding 30 LP...', service: 'quiz');

        await LovePointService.awardPointsToBothUsers(
          userId1: user.id,
          userId2: partner.pushToken,
          amount: 30,
          reason: 'daily_quest_affirmation',
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
        Logger.success('All daily quests completed! Advancing progression...', service: 'quiz');

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

  void _shareResults() {
    final user = _storage.getUser();
    final userAnswers = widget.session.answers?[user?.id] ?? [];
    final totalScore = _calculateTotalScore(userAnswers);
    final maxScore = _getMaxScore();

    Share.share(
      'I scored $totalScore/$maxScore on "${widget.session.quizName ?? 'Affirmation Quiz'}"! 💕\n\n'
      'Try TogetherRemind to reflect on your relationship together!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    if (user == null) {
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: Center(
          child: Text('User not found', style: EditorialStyles.bodyText),
        ),
      );
    }

    final userAnswers = widget.session.answers?[user.id] ?? [];
    final partnerAnswers = widget.session.answers?[partner?.pushToken] ?? [];
    final totalScore = _calculateTotalScore(userAnswers);
    final partnerScore = _calculateTotalScore(partnerAnswers);
    final maxScore = _getMaxScore();
    final bothCompleted = userAnswers.isNotEmpty && partnerAnswers.isNotEmpty;
    final lpEarned = widget.session.lpEarned ?? 30;

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: Stack(
        children: [
          // Confetti celebration overlay
          CelebrationService().createConfettiWidget(
            _confettiController,
            type: CelebrationType.questComplete,
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                EditorialHeaderSimple(
                  title: 'Complete',
                  onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Score hero
                        _buildScoreHero(totalScore, maxScore),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Partner comparison
                              _buildComparisonCard(
                                totalScore,
                                partnerScore,
                                maxScore,
                                bothCompleted,
                                partnerName,
                              ),
                              const SizedBox(height: 24),

                              // Your responses header
                              Text('YOUR RESPONSES', style: EditorialStyles.labelUppercase),
                              const SizedBox(height: 16),

                              // Answer cards
                              ...List.generate(_questions.length, (index) {
                                if (index >= userAnswers.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildAnswerCard(
                                    _questions[index].question,
                                    userAnswers[index],
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
        ],
      ),
    );
  }

  Widget _buildScoreHero(int score, int maxScore) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border(bottom: EditorialStyles.border),
      ),
      child: Column(
        children: [
          Text(
            'YOUR SCORE',
            style: EditorialStyles.labelUppercaseSmall,
          ),
          const SizedBox(height: 20),

          // Fraction score display
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$score',
                  style: EditorialStyles.scoreLarge,
                ),
                TextSpan(
                  text: '/',
                  style: EditorialStyles.scoreMedium.copyWith(
                    fontWeight: FontWeight.w300,
                  ),
                ),
                TextSpan(
                  text: '$maxScore',
                  style: EditorialStyles.scoreMedium.copyWith(
                    color: EditorialStyles.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Text(
            _getRatingLabel(score, maxScore),
            style: EditorialStyles.labelUppercase.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _getScoreMessage(score, maxScore),
            style: EditorialStyles.bodyTextItalic,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
    int userScore,
    int partnerScore,
    int maxScore,
    bool bothCompleted,
    String partnerName,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: EditorialStyles.inkLight)),
            ),
            child: Text('PARTNER COMPARISON', style: EditorialStyles.labelUppercase),
          ),

          // Scores row
          Row(
            children: [
              // Your score
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: EditorialStyles.inkLight)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'YOU',
                        style: EditorialStyles.labelUppercaseSmall.copyWith(
                          color: EditorialStyles.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$userScore',
                              style: EditorialStyles.scoreMedium,
                            ),
                            TextSpan(
                              text: '/$maxScore',
                              style: EditorialStyles.bodySmall.copyWith(
                                color: EditorialStyles.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Partner score
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        partnerName.toUpperCase(),
                        style: EditorialStyles.labelUppercaseSmall.copyWith(
                          color: EditorialStyles.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (bothCompleted)
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$partnerScore',
                                style: EditorialStyles.scoreMedium,
                              ),
                              TextSpan(
                                text: '/$maxScore',
                                style: EditorialStyles.bodySmall.copyWith(
                                  color: EditorialStyles.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: EditorialStyles.inkLight.withValues(alpha: 0.3),
                            border: Border.all(color: EditorialStyles.inkLight),
                          ),
                          child: Text(
                            'Waiting...',
                            style: EditorialStyles.bodySmall.copyWith(
                              fontStyle: FontStyle.italic,
                              color: EditorialStyles.inkMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(String question, int answerIndex) {
    final rating = answerIndex + 1; // Convert 0-4 to 1-5

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$question"',
            style: EditorialStyles.bodyTextItalic.copyWith(
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          // Rating dots
          Row(
            children: [
              // 5 dots
              ...List.generate(5, (index) {
                final isFilled = index < rating;
                return Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: isFilled ? EditorialStyles.ink : EditorialStyles.paper,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: EditorialStyles.ink,
                      width: EditorialStyles.borderWidth,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                '${_getAnswerLabel(answerIndex)} ($rating/5)',
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
                  Text(
                    '+$lpEarned LP',
                    style: TextStyle(
                      fontFamily: EditorialStyles.scoreLarge.fontFamily,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: EditorialStyles.paper,
                    ),
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
