import 'package:flutter/material.dart';
import 'dart:async';
import '../models/you_or_me_match.dart';
import '../services/you_or_me_match_service.dart';
import '../services/storage_service.dart';
import '../services/arena_service.dart';
import '../services/daily_quest_service.dart';
import '../services/poke_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import 'you_or_me_match_game_screen.dart';
import 'you_or_me_match_results_screen.dart';

/// Waiting screen for You-or-Me Match (server-centric architecture)
///
/// Polls server for turn changes using YouOrMeMatchService
class YouOrMeMatchWaitingScreen extends StatefulWidget {
  final String matchId;
  final String? questId; // Optional: Daily quest ID for updating local status

  const YouOrMeMatchWaitingScreen({
    super.key,
    required this.matchId,
    this.questId,
  });

  @override
  State<YouOrMeMatchWaitingScreen> createState() => _YouOrMeMatchWaitingScreenState();
}

class _YouOrMeMatchWaitingScreenState extends State<YouOrMeMatchWaitingScreen>
    with TickerProviderStateMixin {
  final YouOrMeMatchService _service = YouOrMeMatchService();
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();
  bool _isChecking = false;
  bool _isSendingPoke = false;

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
    _service.startPolling(
      widget.matchId,
      onUpdate: (state) {
        if (!mounted) return;

        if (state.isCompleted) {
          _service.stopPolling();
          _handleCompletion(state);
        } else if (state.isMyTurn) {
          // Our turn now, go back to game
          _service.stopPolling();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const YouOrMeMatchGameScreen(),
            ),
          );
        }
      },
      intervalSeconds: 5,
    );
  }

  /// Handle game completion - sync LP and quest status, then navigate to results
  Future<void> _handleCompletion(YouOrMeGameState state) async {
    // Award LP locally (same as the submitter gets)
    const lpEarned = 30;
    await _arenaService.awardLovePoints(lpEarned, 'you_or_me_complete');
    Logger.debug('Waiting screen: Awarded $lpEarned LP locally for You or Me completion', service: 'you_or_me');

    // Update local quest status to completed
    await _updateLocalQuestStatus();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => YouOrMeMatchResultsScreen(
          match: state.match,
          quiz: state.quiz,
          myScore: state.myScore,
          partnerScore: state.partnerScore,
          lpEarned: lpEarned,
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
        if (partner != null) {
          quest.userCompletions ??= {};
          quest.userCompletions![partner.pushToken] = true;
        }
        await quest.save();
        Logger.debug('Waiting screen: Marked quest as fully completed for ${widget.questId}', service: 'you_or_me');
      }
    } catch (e) {
      Logger.error('Failed to update quest status from waiting screen', error: e, service: 'you_or_me');
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
    _service.stopPolling();
    _breatheController.dispose();
    _dotsController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      final state = await _service.pollMatchState(widget.matchId);

      if (!mounted) return;

      if (state.isCompleted) {
        _service.stopPolling();
        await _handleCompletion(state);
      } else if (state.isMyTurn) {
        _service.stopPolling();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const YouOrMeMatchGameScreen(),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error checking status', error: e, service: 'you_or_me');
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
              title: 'You or Me',
              onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
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
                            status: 'Their turn...',
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
                          label: _isSendingPoke ? 'Sending...' : 'Nudge Partner',
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
                    'We\'ll notify you when it\'s your turn',
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
