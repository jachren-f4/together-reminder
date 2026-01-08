import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../services/unified_game_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/love_point_service.dart';
import '../services/poke_service.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import 'quiz_match_results_screen.dart';
import 'you_or_me_match_results_screen.dart';
import '../models/quiz_match.dart';
import '../models/you_or_me_match.dart';

/// Unified waiting screen for all quiz-type games (classic, affirmation, you_or_me)
///
/// Uses UnifiedGameService directly for polling - no intermediate service wrappers.
/// Navigates to the appropriate results screen based on game type.
class GameWaitingScreen extends StatefulWidget {
  final String matchId;
  final GameType gameType;
  final String? questId;

  const GameWaitingScreen({
    super.key,
    required this.matchId,
    required this.gameType,
    this.questId,
  });

  @override
  State<GameWaitingScreen> createState() => _GameWaitingScreenState();
}

class _GameWaitingScreenState extends State<GameWaitingScreen>
    with TickerProviderStateMixin {
  final UnifiedGameService _service = UnifiedGameService();
  final StorageService _storage = StorageService();
  bool _isChecking = false;
  bool _isSendingPoke = false;
  bool _isHandlingCompletion = false;

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  // Animation controllers
  late AnimationController _breatheController;
  late AnimationController _dotsController;
  late AnimationController _messageController;

  // Current message index for rotation
  int _currentMessageIndex = 0;
  final List<String> _waitingMessages = [
    'Good things take time...',
    'Your partner is on their way...',
    'Almost there...',
    'Patience is a virtue...',
    'The wait will be worth it...',
  ];

  String get _gameTitle {
    switch (widget.gameType) {
      case GameType.classic:
        return 'Classic Quiz';
      case GameType.affirmation:
        return 'Affirmation Quiz';
      case GameType.you_or_me:
        return 'You or Me';
    }
  }

  String get _contentType {
    switch (widget.gameType) {
      case GameType.classic:
        return 'classic_quiz';
      case GameType.affirmation:
        return 'affirmation_quiz';
      case GameType.you_or_me:
        return 'you_or_me';
    }
  }

  @override
  void initState() {
    super.initState();
    Logger.debug('GameWaitingScreen initState for matchId=${widget.matchId}, gameType=${widget.gameType}', service: 'quiz');

    // Breathing animation for partner card
    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Dots animation
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Message rotation
    _messageController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _startMessageRotation();

    // Set pending results flag
    _setPendingResultsFlag();

    // Start polling
    _startPolling();
  }

  Future<void> _setPendingResultsFlag() async {
    await _storage.setPendingResultsMatchId(_contentType, widget.matchId);
    Logger.debug('GameWaitingScreen: Set pending results flag for $_contentType (matchId: ${widget.matchId})', service: 'quiz');
  }

  void _startPolling() {
    Logger.info('GameWaitingScreen starting polling for matchId=${widget.matchId}, gameType=${widget.gameType}', service: 'quiz');

    _service.startPolling(
      gameType: widget.gameType,
      matchId: widget.matchId,
      onUpdate: (response) {
        Logger.debug('GameWaitingScreen callback: isCompleted=${response.state.isCompleted}, userAnswered=${response.state.userAnswered}, partnerAnswered=${response.state.partnerAnswered}', service: 'quiz');

        if (!mounted) return;
        if (_isHandlingCompletion) return;

        // Check both isCompleted and both answered for redundancy
        final bothAnswered = response.state.userAnswered && response.state.partnerAnswered;

        if (response.state.isCompleted || bothAnswered) {
          Logger.info('Game completed! Navigating to results (isCompleted=${response.state.isCompleted})', service: 'quiz');
          _isHandlingCompletion = true;
          _service.stopPolling(matchId: widget.matchId);
          _handleCompletion(response);
        }
      },
      intervalSeconds: 5,
    );
  }

  Future<void> _handleCompletion(GamePlayResponse response) async {
    // Sync LP from server
    await LovePointService.fetchAndSyncFromServer();
    Logger.debug('GameWaitingScreen: Synced LP from server after completion', service: 'quiz');

    // Update local quest status
    await _updateLocalQuestStatus();

    if (!mounted) return;

    // Navigate to appropriate results screen
    if (widget.gameType == GameType.you_or_me) {
      _navigateToYouOrMeResults(response);
    } else {
      _navigateToQuizResults(response);
    }
  }

  void _navigateToQuizResults(GamePlayResponse response) {
    // Convert to QuizMatch model for results screen
    final match = QuizMatch(
      id: response.match.id,
      quizId: response.match.quizId,
      quizType: response.match.quizType,
      branch: response.match.branch,
      status: response.match.status,
      player1Answers: response.result?.userAnswers ?? [],
      player2Answers: response.result?.partnerAnswers ?? [],
      matchPercentage: response.result?.matchPercentage,
      player1Id: '', // Not needed for results screen
      player2Id: '', // Not needed for results screen
      date: response.match.date,
      createdAt: DateTime.tryParse(response.match.createdAt) ?? DateTime.now(),
      completedAt: response.match.completedAt != null
          ? DateTime.tryParse(response.match.completedAt!)
          : null,
    );

    ServerQuiz? quiz;
    if (response.quiz != null) {
      quiz = ServerQuiz(
        quizId: response.quiz!.id,
        title: response.quiz!.name,
        branch: response.match.branch,
        questions: response.quiz!.questions.map((q) => ServerQuizQuestion(
          id: q.id,
          text: q.text,
          choices: q.choices,
          category: q.category ?? '',
        )).toList(),
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizMatchResultsScreen(
          match: match,
          quiz: quiz,
          matchPercentage: response.result?.matchPercentage,
          lpEarned: response.result?.lpEarned ?? 30,
        ),
      ),
    );
  }

  void _navigateToYouOrMeResults(GamePlayResponse response) {
    // Convert to YouOrMeMatch model for results screen
    final totalQuestions = response.quiz?.questions.length ?? 10;
    final matchPercentage = response.result?.matchPercentage ?? 0;
    final matchCount = ((matchPercentage / 100) * totalQuestions).round();

    final match = YouOrMeMatch(
      id: response.match.id,
      quizId: response.match.quizId,
      branch: response.match.branch,
      status: response.match.status,
      player1Answers: [],
      player2Answers: [],
      player1AnswerCount: 0,
      player2AnswerCount: 0,
      currentTurnUserId: null,
      turnNumber: 1,
      player1Score: matchCount,
      player2Score: matchCount,
      player1Id: '',
      player2Id: '',
      date: response.match.date,
      createdAt: DateTime.tryParse(response.match.createdAt) ?? DateTime.now(),
      completedAt: response.match.completedAt != null
          ? DateTime.tryParse(response.match.completedAt!)
          : null,
    );

    ServerYouOrMeQuiz? quiz;
    if (response.quiz != null) {
      quiz = ServerYouOrMeQuiz(
        quizId: response.quiz!.id,
        title: response.quiz!.name,
        branch: response.match.branch,
        questions: response.quiz!.questions.map((q) => ServerYouOrMeQuestion(
          id: q.id,
          prompt: q.text.split('\n').first,
          content: q.text.split('\n').length > 1 ? q.text.split('\n')[1] : q.text,
        )).toList(),
        totalQuestions: response.quiz!.questions.length,
      );
    }

    // Convert answers from int (0/1) to string ('you'/'me')
    final userAnswers = response.result?.userAnswers
        .map((i) => i == 1 ? 'me' : 'you')
        .toList();
    final partnerAnswers = response.result?.partnerAnswers
        .map((i) => i == 1 ? 'me' : 'you')
        .toList();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => YouOrMeMatchResultsScreen(
          match: match,
          quiz: quiz,
          myScore: matchCount,
          partnerScore: matchCount,
          lpEarned: response.result?.lpEarned ?? 30,
          matchPercentage: response.result?.matchPercentage,
          userAnswers: userAnswers,
          partnerAnswers: partnerAnswers,
        ),
      ),
    );
  }

  Future<void> _updateLocalQuestStatus() async {
    if (widget.questId == null) return;

    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null) return;

    try {
      final questService = DailyQuestService(storage: _storage);
      await questService.completeQuestForUser(
        questId: widget.questId!,
        userId: user.id,
      );

      final quest = _storage.getDailyQuest(widget.questId!);
      if (quest != null) {
        quest.status = 'completed';
        if (partner != null) {
          final partnerKey = partner.id.isNotEmpty ? partner.id : partner.pushToken;
          quest.userCompletions ??= {};
          quest.userCompletions![partnerKey] = true;
        }
        await StorageService().saveDailyQuest(quest);
        Logger.debug('GameWaitingScreen: Marked quest as fully completed for ${widget.questId}', service: 'quiz');
      }
    } catch (e) {
      Logger.error('Failed to update quest status from waiting screen', error: e, service: 'quiz');
    }
  }

  void _startMessageRotation() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _messageController.forward().then((_) {
        if (!mounted) return;
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _waitingMessages.length;
        });
        _messageController.reverse().then((_) {
          _startMessageRotation();
        });
      });
    });
  }

  @override
  void dispose() {
    _service.stopPolling(matchId: widget.matchId);
    _breatheController.dispose();
    _dotsController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_isChecking || _isHandlingCompletion) return;

    setState(() => _isChecking = true);

    try {
      final response = await _service.getMatchState(
        gameType: widget.gameType,
        matchId: widget.matchId,
      );

      if (!mounted) return;

      final bothAnswered = response.state.userAnswered && response.state.partnerAnswered;
      if (response.state.isCompleted || bothAnswered) {
        Logger.info('Manual check detected completion', service: 'quiz');
        _isHandlingCompletion = true;
        _service.stopPolling(matchId: widget.matchId);
        await _handleCompletion(response);
      }
    } catch (e) {
      Logger.error('Error checking status', error: e, service: 'quiz');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _sendReminder() async {
    setState(() => _isSendingPoke = true);

    try {
      // Check if user has granted push notification permission
      // If not, this is a great moment to ask (contextually relevant)
      final isAuthorized = await NotificationService.isAuthorized();
      if (!isAuthorized) {
        // Request permission - user is about to send a reminder, so they understand the value
        await NotificationService.requestPermission();
        // Continue regardless of result - we still try to send the poke
      }

      await PokeService.sendPoke();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reminder: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingPoke = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'your partner';
    final partnerEmoji = partner?.avatarEmoji ?? '👤';

    if (_isUs2) return _buildUs2Screen(partnerName, partnerEmoji);

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            EditorialHeaderSimple(
              title: _gameTitle,
              onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Column(
                    children: [
                      _buildElegantDots(),
                      const SizedBox(height: 32),

                      Text(
                        'Waiting for $partnerName',
                        style: EditorialStyles.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      AnimatedBuilder(
                        animation: _messageController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: 1.0 - _messageController.value,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Text(
                                _waitingMessages[_currentMessageIndex],
                                style: EditorialStyles.bodyTextItalic,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: AnimatedBuilder(
                          animation: _breatheController,
                          builder: (context, child) {
                            final scale = 1.0 + (0.02 * Curves.easeInOut.transform(_breatheController.value));
                            final yOffset = -4.0 * Curves.easeInOut.transform(
                              _breatheController.value < 0.5
                                  ? _breatheController.value * 2
                                  : 2.0 - _breatheController.value * 2,
                            );
                            return Transform.translate(
                              offset: Offset(0, yOffset),
                              child: Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: EditorialPartnerCard(
                            avatarEmoji: partnerEmoji,
                            name: partnerName,
                            status: 'In progress...',
                            grayscale: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildDivider(),
                      const SizedBox(height: 32),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: EditorialPrimaryButton(
                          label: _isSendingPoke ? 'Sending...' : 'Nudge Partner',
                          onPressed: _isSendingPoke ? null : _sendReminder,
                        ),
                      ),

                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _isChecking ? null : _checkStatus,
                        child: Text(
                          _isChecking ? 'Checking...' : 'Tap to check for updates',
                          style: EditorialStyles.bodySmall.copyWith(
                            color: EditorialStyles.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
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
              child: Column(
                children: [
                  EditorialPrimaryButton(
                    label: 'Return Home',
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We\'ll notify you when results are ready',
                    style: EditorialStyles.bodySmall.copyWith(
                      color: EditorialStyles.inkMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElegantDots() {
    return SizedBox(
      width: 80,
      height: 40,
      child: AnimatedBuilder(
        animation: _dotsController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final offset = index * 0.33;
              final animValue = (_dotsController.value + offset) % 1.0;
              final wave = animValue < 0.5
                  ? animValue * 2
                  : 2.0 - (animValue * 2);
              final easedWave = Curves.easeInOut.transform(wave);
              final scale = 0.6 + (0.4 * easedWave);
              final opacity = 0.3 + (0.7 * easedWave);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: EditorialStyles.ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildDivider() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: EditorialStyles.inkLight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OR',
              style: EditorialStyles.labelUppercaseSmall,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: EditorialStyles.inkLight,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================
  // Us 2.0 Implementation
  // ===========================================

  Widget _buildUs2Screen(String partnerName, String partnerEmoji) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: Us2Theme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildUs2Header(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    children: [
                      // Animated dots
                      _buildUs2Dots(),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Waiting for $partnerName',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Us2Theme.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Rotating message
                      AnimatedBuilder(
                        animation: _messageController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: 1.0 - _messageController.value,
                            child: Text(
                              _waitingMessages[_currentMessageIndex],
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                color: Us2Theme.textMedium,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // Partner card with breathing animation
                      _buildUs2PartnerCard(partnerName, partnerEmoji),
                      const SizedBox(height: 32),

                      // Divider
                      _buildUs2Divider(),
                      const SizedBox(height: 32),

                      // Nudge button
                      _buildUs2NudgeButton(),

                      const SizedBox(height: 24),

                      // Check for updates link
                      GestureDetector(
                        onTap: _isChecking ? null : _checkStatus,
                        child: Text(
                          _isChecking ? 'Checking...' : 'Tap to check for updates',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: Us2Theme.textLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              _buildUs2Footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                size: 20,
                color: Us2Theme.textDark,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _gameTitle,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // Balance
        ],
      ),
    );
  }

  Widget _buildUs2Dots() {
    return SizedBox(
      width: 80,
      height: 40,
      child: AnimatedBuilder(
        animation: _dotsController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final offset = index * 0.33;
              final animValue = (_dotsController.value + offset) % 1.0;
              final wave = animValue < 0.5
                  ? animValue * 2
                  : 2.0 - (animValue * 2);
              final easedWave = Curves.easeInOut.transform(wave);
              final scale = 0.6 + (0.4 * easedWave);
              final opacity = 0.3 + (0.7 * easedWave);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: Us2Theme.accentGradient,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildUs2PartnerCard(String partnerName, String partnerEmoji) {
    return AnimatedBuilder(
      animation: _breatheController,
      builder: (context, child) {
        final scale = 1.0 + (0.02 * Curves.easeInOut.transform(_breatheController.value));
        final yOffset = -4.0 * Curves.easeInOut.transform(
          _breatheController.value < 0.5
              ? _breatheController.value * 2
              : 2.0 - _breatheController.value * 2,
        );
        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Us2Theme.glowPink.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: Us2Theme.accentGradient,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: Text(
                  partnerEmoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Us2Theme.primaryBrandPink.withOpacity(0.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'In progress...',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: Us2Theme.textLight,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUs2Divider() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Us2Theme.beige,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OR',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Us2Theme.textLight,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Us2Theme.beige,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2NudgeButton() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: GestureDetector(
        onTap: _isSendingPoke ? null : _sendReminder,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Us2Theme.primaryBrandPink, width: 2),
          ),
          child: Center(
            child: Text(
              _isSendingPoke ? 'Sending...' : 'Nudge Partner',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Us2Theme.primaryBrandPink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: Us2Theme.accentGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: Us2Theme.buttonGlowShadow,
              ),
              child: Center(
                child: Text(
                  'Return Home',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "We'll notify you when results are ready",
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Us2Theme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
