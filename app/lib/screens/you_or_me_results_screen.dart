import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:confetti/confetti.dart';
import '../models/you_or_me.dart';
import '../services/you_or_me_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../services/haptic_service.dart';
import '../services/celebration_service.dart';
import '../animations/animation_config.dart';
import '../models/daily_quest.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';

/// Results screen for You or Me game
/// Editorial newspaper aesthetic with score ring and answer cards
class YouOrMeResultsScreen extends StatefulWidget {
  final YouOrMeSession session;

  const YouOrMeResultsScreen({
    super.key,
    required this.session,
  });

  @override
  State<YouOrMeResultsScreen> createState() => _YouOrMeResultsScreenState();
}

class _YouOrMeResultsScreenState extends State<YouOrMeResultsScreen>
    with TickerProviderStateMixin {
  final YouOrMeService _service = YouOrMeService();
  final StorageService _storage = StorageService();
  Map<String, dynamic>? _results;
  bool _isLoadingPartnerSession = false;
  late ConfettiController _confettiController;

  // Animation controllers for LP reward card
  late AnimationController _rewardCardController;
  late Animation<double> _rewardFadeAnimation;
  late Animation<double> _rewardScaleAnimation;

  @override
  void initState() {
    super.initState();
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

    _loadSessionAndCalculateResults();
    _checkQuestCompletion();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _rewardCardController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionAndCalculateResults() async {
    setState(() {
      _isLoadingPartnerSession = true;
    });

    try {
      if (!widget.session.areBothUsersAnswered()) {
        Logger.debug('Not all users answered, refreshing session from Firebase', service: 'you_or_me');
        final refreshedSession = await _service.getSession(
          widget.session.id,
          forceRefresh: true,
        );

        if (refreshedSession != null && refreshedSession.areBothUsersAnswered()) {
          setState(() {
            _results = _service.calculateResults(refreshedSession);
            _isLoadingPartnerSession = false;
          });
        } else {
          Logger.debug('Still waiting for partner to complete', service: 'you_or_me');
          setState(() {
            _results = null;
            _isLoadingPartnerSession = false;
          });
        }
      } else {
        Logger.debug('Both users answered, calculating results', service: 'you_or_me');
        setState(() {
          _results = _service.calculateResults(widget.session);
          _isLoadingPartnerSession = false;
        });
      }
    } catch (e) {
      Logger.error('Error loading session results', error: e, service: 'you_or_me');
      setState(() {
        _results = null;
        _isLoadingPartnerSession = false;
      });
    }
  }

  Future<void> _checkQuestCompletion() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) {
        Logger.debug('No user or partner, skipping quest completion check', service: 'you_or_me');
        return;
      }

      final questService = DailyQuestService(storage: _storage);
      final todayQuests = questService.getTodayQuests();

      Logger.debug('Checking quest completion - Found ${todayQuests.length} quests today', service: 'you_or_me');
      Logger.debug('Session ID: ${widget.session.id}', service: 'you_or_me');

      final matchingQuest = todayQuests
          .where((q) => q.type == QuestType.youOrMe && q.contentId == widget.session.id)
          .firstOrNull;

      if (matchingQuest == null) {
        Logger.debug('❌ No matching You or Me quest found for session ${widget.session.id}', service: 'you_or_me');
        return;
      }

      Logger.debug('✅ Found matching quest: ${matchingQuest.id} for session ${widget.session.id}', service: 'you_or_me');

      final userAnswers = widget.session.answers?[user.id];
      if (userAnswers == null || userAnswers.length < widget.session.questions.length) {
        Logger.debug('User has not completed all questions yet (${userAnswers?.length ?? 0}/${widget.session.questions.length})', service: 'you_or_me');
        return;
      }

      Logger.debug('User ${user.id} completed all ${widget.session.questions.length} questions, marking quest complete', service: 'you_or_me');

      final bothCompleted = await questService.completeQuestForUser(
        questId: matchingQuest.id,
        userId: user.id,
      );

      Logger.debug('Quest completion result - bothCompleted: $bothCompleted', service: 'you_or_me');

      final syncService = QuestSyncService(storage: _storage);

      await syncService.markQuestCompleted(
        questId: matchingQuest.id,
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );

      Logger.debug('Quest completion synced to Firebase for quest ${matchingQuest.id}', service: 'you_or_me');

      if (bothCompleted) {
        Logger.success('Daily You or Me quest completed by both users! Awarding 30 LP...', service: 'you_or_me');

        await LovePointService.awardPointsToBothUsers(
          userId1: user.id,
          userId2: partner.pushToken,
          amount: 30,
          reason: 'daily_quest_you_or_me',
          relatedId: matchingQuest.id,
        );
      }
    } catch (e) {
      Logger.error('Error checking quest completion', error: e, service: 'you_or_me');
    }
  }

  String _getAgreementMessage(int percentage) {
    if (percentage >= 90) return '"You\'re totally in sync!"';
    if (percentage >= 70) return '"You know each other pretty well!"';
    if (percentage >= 50) return '"Some fun surprises here!"';
    return '"Lots to discover about each other!"';
  }

  void _shareResults() {
    if (_results == null) return;
    final agreementPercentage = _results!['agreementPercentage'] as int;

    Share.share(
      'We matched $agreementPercentage% on You or Me! 🤝\n\n'
      'Try TogetherRemind to test how well you know your partner!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';
    final userName = user?.name ?? 'You';

    if (_isLoadingPartnerSession || _results == null) {
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              EditorialHeaderSimple(
                title: 'Results',
                onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final agreements = _results!['agreements'] as int;
    final disagreements = _results!['disagreements'] as int;
    final agreementPercentage = _results!['agreementPercentage'] as int;
    final comparisons = _results!['comparisons'] as List<Map<String, dynamic>>;

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
                  title: 'Game Complete',
                  onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Score hero
                    _buildScoreHero(agreementPercentage, partnerName),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats grid
                          _buildStatsGrid(agreements, disagreements),
                          const SizedBox(height: 32),

                          // Breakdown header
                          Text('BREAKDOWN', style: EditorialStyles.labelUppercase),
                          const SizedBox(height: 16),

                          // Answer cards
                          ...comparisons.map((comparison) {
                            final question = comparison['question'] as YouOrMeQuestion;
                            final userAnswer = comparison['userAnswer'] as String?;
                            final partnerAnswer = comparison['partnerAnswer'] as String?;
                            final agreed = comparison['agreed'] as bool;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildAnswerCard(
                                question: question,
                                userAnswer: userAnswer,
                                partnerAnswer: partnerAnswer,
                                agreed: agreed,
                                userName: userName,
                                partnerName: partnerName,
                              ),
                            );
                          }),

                          // Reward card
                          const SizedBox(height: 12),
                          _buildRewardCard(30),
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

  Widget _buildScoreHero(int agreementPercentage, String partnerName) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border(bottom: EditorialStyles.border),
      ),
      child: Column(
        children: [
          Text(
            'YOU & ${partnerName.toUpperCase()} MATCHED',
            style: EditorialStyles.labelUppercaseSmall,
          ),
          const SizedBox(height: 20),

          // Score ring
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _ScoreRingPainter(
                percentage: agreementPercentage / 100,
                trackColor: EditorialStyles.inkLight,
                progressColor: EditorialStyles.ink,
              ),
              child: Center(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$agreementPercentage',
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
          ),
          const SizedBox(height: 20),

          Text(
            _getAgreementMessage(agreementPercentage),
            style: EditorialStyles.bodyTextItalic,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int matched, int different) {
    return Row(
      children: [
        Expanded(child: _buildStatBox('$matched', 'Matched')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatBox('$different', 'Different')),
      ],
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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

  Widget _buildAnswerCard({
    required YouOrMeQuestion question,
    required String? userAnswer,
    required String? partnerAnswer,
    required bool agreed,
    required String userName,
    required String partnerName,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: agreed ? EditorialStyles.inkLight.withValues(alpha: 0.3) : EditorialStyles.paper,
        border: EditorialStyles.fullBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.prompt,
                  style: EditorialStyles.labelUppercaseSmall.copyWith(
                    color: EditorialStyles.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${question.content}"',
                  style: EditorialStyles.bodyTextItalic.copyWith(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Answer comparison
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: EditorialStyles.inkLight)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildAnswerItem(
                    label: 'You Said',
                    answer: _formatAnswer(userAnswer, true, partnerName),
                    agreed: agreed,
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: EditorialStyles.inkLight,
                ),
                Expanded(
                  child: _buildAnswerItem(
                    label: '$partnerName Said',
                    answer: _formatAnswer(partnerAnswer, false, partnerName),
                    agreed: agreed,
                  ),
                ),
              ],
            ),
          ),

          // Match indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: agreed ? EditorialStyles.ink : EditorialStyles.inkLight.withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: agreed ? EditorialStyles.paper : EditorialStyles.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      agreed ? Icons.check : Icons.close,
                      size: 12,
                      color: agreed ? EditorialStyles.ink : EditorialStyles.paper,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  agreed ? 'MATCH!' : 'DIFFERENT',
                  style: EditorialStyles.labelUppercaseSmall.copyWith(
                    color: agreed ? EditorialStyles.paper : EditorialStyles.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerItem({
    required String label,
    required String answer,
    required bool agreed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: EditorialStyles.labelUppercaseSmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: agreed ? EditorialStyles.ink : Colors.transparent,
              border: agreed ? null : Border.all(color: EditorialStyles.inkLight),
            ),
            child: Text(
              answer,
              style: EditorialStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: agreed ? EditorialStyles.paper : EditorialStyles.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAnswer(String? answer, bool isUser, String partnerName) {
    switch (answer) {
      case 'me':
        return isUser ? 'Me' : 'You';
      case 'partner':
        return isUser ? partnerName : 'Me';
      case 'neither':
        return 'Neither';
      case 'both':
        return 'Both';
      default:
        return '—';
    }
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
      -1.5708,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
