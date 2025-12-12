import 'package:flutter/material.dart';
import 'dart:async';
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

  // Debug heartbeat timer
  Timer? _debugHeartbeat;
  int _heartbeatCount = 0;

  @override
  void initState() {
    super.initState();
    print('🚀 WAITING SCREEN: initState() called');

    // Debug heartbeat - should print every 3 seconds if screen is alive
    _debugHeartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
      _heartbeatCount++;
      print('💓 HEARTBEAT #$_heartbeatCount - screen alive, mounted=$mounted');
    });

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
    _startPolling();
  }

  void _startPolling() {
    print('🚀 WAITING SCREEN: _startPolling() called! matchId=${widget.matchId}, quizType=${widget.quizType}');
    Logger.info('🎯 WaitingScreen._startPolling called for matchId=${widget.matchId}, quizType=${widget.quizType}', service: 'quiz');

    _service.startPolling(
      widget.matchId,
      onUpdate: (state) {
        print('🎯 WAITING: callback received! isCompleted=${state.isCompleted}, hasUserAnswered=${state.hasUserAnswered}, hasPartnerAnswered=${state.hasPartnerAnswered}');

        if (!mounted) {
          print('🎯 WAITING: widget not mounted, ignoring callback');
          return;
        }

        if (_isHandlingCompletion) {
          print('🎯 WAITING: already handling completion, ignoring callback');
          return;
        }

        // Check both isCompleted (status == 'completed') and partner answered (in case status wasn't updated yet)
        // This provides redundancy in case there's a database sync issue
        if (state.isCompleted || (state.hasUserAnswered && state.hasPartnerAnswered)) {
          print('🎯 WAITING: quiz completed! (isCompleted=${state.isCompleted}, bothAnswered=${state.hasUserAnswered && state.hasPartnerAnswered}) Navigating to results');
          _isHandlingCompletion = true;
          _service.stopPolling();
          _handleCompletion(state);
        } else {
          print('🎯 WAITING: not completed yet, continuing to poll');
        }
      },
      intervalSeconds: 5,
      quizType: widget.quizType,
    );
  }

  /// Handle quiz completion - sync LP and quest status, then navigate to results
  Future<void> _handleCompletion(QuizMatchGameState state) async {
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
        await quest.save();
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
    _debugHeartbeat?.cancel();
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
                        child: EditorialSecondaryButton(
                          label: _isSendingPoke ? 'Sending...' : 'Send a Gentle Reminder',
                          emoji: '👆',
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
                  EditorialSecondaryButton(
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
}
