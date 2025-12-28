import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/us2_theme.dart';
import '../models/quiz_match.dart';
import '../services/quiz_match_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/love_point_service.dart';
import '../services/poke_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import 'quiz_match_results_screen.dart';

/// Waiting screen for Quiz Match (server-centric architecture)
///
/// Polls server for partner completion using QuizMatchService
class QuizMatchWaitingScreen extends StatefulWidget {
  final String matchId;
  final String quizType;
  final String? questId; // Optional: Daily quest ID for updating local status

  const QuizMatchWaitingScreen({
    super.key,
    required this.matchId,
    required this.quizType,
    this.questId,
  });

  @override
  State<QuizMatchWaitingScreen> createState() => _QuizMatchWaitingScreenState();
}

class _QuizMatchWaitingScreenState extends State<QuizMatchWaitingScreen>
    with TickerProviderStateMixin {
  final QuizMatchService _service = QuizMatchService();
  final StorageService _storage = StorageService();
  bool _isChecking = false;
  bool _isSendingPoke = false;
  bool _isHandlingCompletion = false;  // Guard against multiple completion attempts

  /// Check if Us 2.0 brand is active
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

  @override
  void initState() {
    super.initState();
    Logger.debug('QuizMatchWaitingScreen initState for matchId=${widget.matchId}', service: 'quiz');

    // Breathing animation for partner card (subtle scale)
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

    // Set pending results flag when entering waiting screen
    // This ensures that if user goes back to home and partner completes later,
    // the quest card will show "RESULTS ARE READY!" instead of "COMPLETED"
    // Note: HomePollingService also sets this flag as a backup when detecting partner completion
    _setPendingResultsFlag();

    _startPolling();
  }

  /// Set the pending results flag when entering the waiting screen
  Future<void> _setPendingResultsFlag() async {
    final contentType = '${widget.quizType}_quiz'; // 'classic_quiz' or 'affirmation_quiz'
    await _storage.setPendingResultsMatchId(contentType, widget.matchId);
    Logger.debug('Waiting screen: Set pending results flag for $contentType (matchId: ${widget.matchId})', service: 'quiz');
  }

  void _startPolling() {
    Logger.info('QuizMatchWaitingScreen starting polling for matchId=${widget.matchId}, quizType=${widget.quizType}', service: 'quiz');

    _service.startPolling(
      widget.matchId,
      onUpdate: (state) {
        Logger.debug('Quiz waiting callback: isCompleted=${state.isCompleted}, userAnswered=${state.hasUserAnswered}, partnerAnswered=${state.hasPartnerAnswered}', service: 'quiz');

        if (!mounted) {
          Logger.debug('Quiz waiting: widget not mounted, ignoring callback', service: 'quiz');
          return;
        }

        if (_isHandlingCompletion) {
          Logger.debug('Quiz waiting: already handling completion, ignoring callback', service: 'quiz');
          return;
        }

        // Check both isCompleted (status == 'completed') and partner answered (in case status wasn't updated yet)
        // This provides redundancy in case there's a database sync issue
        if (state.isCompleted || (state.hasUserAnswered && state.hasPartnerAnswered)) {
          Logger.info('Quiz completed! Navigating to results (isCompleted=${state.isCompleted})', service: 'quiz');
          _isHandlingCompletion = true;
          _service.stopPolling();
          _handleCompletion(state);
        } else {
          Logger.debug('Quiz waiting: not completed yet, continuing to poll', service: 'quiz');
        }
      },
      intervalSeconds: 5,
      quizType: widget.quizType,
    );
  }

  /// Handle quiz completion - sync LP and quest status, then navigate to results
  Future<void> _handleCompletion(QuizMatchGameState state) async {
    // Pending results flag is managed by HomePollingService
    // (consolidated to single source of truth)

    // LP is now server-authoritative - sync from server
    // This ensures both devices show the same LP value
    await LovePointService.fetchAndSyncFromServer();
    Logger.debug('Waiting screen: Synced LP from server after quiz completion', service: 'quiz');

    // Update local quest status to completed
    await _updateLocalQuestStatus();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizMatchResultsScreen(
          match: state.match,
          quiz: state.quiz,
          matchPercentage: state.match.matchPercentage,
          lpEarned: 30, // Standard LP reward for quiz completion
        ),
      ),
    );
  }

  /// Update local quest status to completed in Hive storage
  Future<void> _updateLocalQuestStatus() async {
    if (widget.questId == null) return;

    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null) return;

    try {
      // Mark current user as completed
      final questService = DailyQuestService(storage: _storage);
      await questService.completeQuestForUser(
        questId: widget.questId!,
        userId: user.id,
      );

      // Mark quest as fully completed (both partners done)
      final quest = _storage.getDailyQuest(widget.questId!);
      if (quest != null) {
        quest.status = 'completed';
        // Also mark partner as completed in userCompletions
        // Use partner.id (UUID) if available, fallback to pushToken for backward compatibility
        if (partner != null) {
          final partnerKey = partner.id.isNotEmpty ? partner.id : partner.pushToken;
          quest.userCompletions ??= {};
          quest.userCompletions![partnerKey] = true;
        }
        await StorageService().saveDailyQuest(quest);
        Logger.debug('Waiting screen: Marked quest as fully completed for ${widget.questId}', service: 'quiz');
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
      final state = await _service.pollMatchState(widget.matchId, quizType: widget.quizType);

      if (!mounted) return;

      // Check both isCompleted and bothAnswered for redundancy
      if (state.isCompleted || (state.hasUserAnswered && state.hasPartnerAnswered)) {
        Logger.info('Manual check detected completion: isCompleted=${state.isCompleted}, bothAnswered=${state.hasUserAnswered && state.hasPartnerAnswered}', service: 'quiz');
        _isHandlingCompletion = true;
        _service.stopPolling();
        await _handleCompletion(state);
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

    // Us 2.0 brand uses different styling
    if (_isUs2) {
      return _buildUs2Screen(partnerName, partnerEmoji);
    }

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            EditorialHeaderSimple(
              title: widget.quizType == 'affirmation' ? 'Affirmation Quiz' : 'Classic Quiz',
              onClose: () => Navigator.of(context).pop(),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Column(
                    children: [
                      // Elegant dots animation
                      _buildElegantDots(),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Waiting for $partnerName',
                        style: EditorialStyles.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Rotating message with crossfade
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

                      // Partner card with breathing animation
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

                      // Divider
                      _buildDivider(),
                      const SizedBox(height: 32),

                      // Poke button
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: EditorialPrimaryButton(
                          label: _isSendingPoke ? 'Sending...' : 'Send a Gentle Reminder',
                          onPressed: _isSendingPoke ? null : _sendReminder,
                        ),
                      ),

                      // Check for updates
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

  /// Build Us 2.0 styled waiting screen
  Widget _buildUs2Screen(String partnerName, String partnerEmoji) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Us2Theme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.quizType == 'affirmation' ? 'Affirmation Quiz' : 'Classic Quiz',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Us2Theme.textDark,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Column(
                      children: [
                        // Animated Dots
                        _buildUs2Dots(),
                        const SizedBox(height: 40),

                        // Title
                        Text(
                          'Waiting for $partnerName',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
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
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: Us2Theme.textMedium,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),

                        // Partner Card
                        AnimatedBuilder(
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
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 300),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Us2Theme.cream,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.05),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Avatar - subtle muted style for waiting state
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Us2Theme.cardSalmon.withOpacity(0.3),
                                        Us2Theme.beige,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Us2Theme.primaryBrandPink.withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Opacity(
                                      opacity: 0.6,
                                      child: Text(
                                        partnerEmoji,
                                        style: const TextStyle(fontSize: 28),
                                      ),
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
                                        style: GoogleFonts.nunito(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Us2Theme.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'In progress...',
                                        style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          color: Us2Theme.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Spinner
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Us2Theme.primaryBrandPink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Divider
                        _buildUs2Divider(),
                        const SizedBox(height: 32),

                        // Reminder Button
                        GestureDetector(
                          onTap: _isSendingPoke ? null : _sendReminder,
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 300),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            decoration: BoxDecoration(
                              color: Us2Theme.cream,
                              border: Border.all(
                                color: Us2Theme.primaryBrandPink,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                _isSendingPoke ? 'Sending...' : 'Send a Gentle Reminder',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Us2Theme.primaryBrandPink,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Check for updates
                        const SizedBox(height: 24),
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
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                          boxShadow: [
                            BoxShadow(
                              color: Us2Theme.glowPink.withOpacity(0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
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
                      'We\'ll notify you when results are ready',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Us2Theme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Us 2.0 styled animated dots
  Widget _buildUs2Dots() {
    return SizedBox(
      width: 100,
      height: 30,
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
              final scale = 0.7 + (0.3 * easedWave);
              final opacity = 0.4 + (0.6 * easedWave);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: Us2Theme.cardGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Us2Theme.glowPink.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
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

  /// Build Us 2.0 styled divider
  Widget _buildUs2Divider() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
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
}
