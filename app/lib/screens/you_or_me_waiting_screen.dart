import 'package:flutter/material.dart';
import 'dart:async';
import '../models/you_or_me.dart';
import '../models/daily_quest.dart';
import '../services/you_or_me_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/poke_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import 'you_or_me_results_screen.dart';

/// Waiting screen for You or Me game
/// Editorial newspaper aesthetic with spinner and partner status
class YouOrMeWaitingScreen extends StatefulWidget {
  final YouOrMeSession session;

  const YouOrMeWaitingScreen({
    super.key,
    required this.session,
  });

  @override
  State<YouOrMeWaitingScreen> createState() => _YouOrMeWaitingScreenState();
}

class _YouOrMeWaitingScreenState extends State<YouOrMeWaitingScreen>
    with TickerProviderStateMixin {
  final YouOrMeService _service = YouOrMeService();
  final StorageService _storage = StorageService();
  Timer? _pollTimer;
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

    _checkQuestCompletion();
    _startPolling();
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
    _pollTimer?.cancel();
    _breatheController.dispose();
    _dotsController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkPartnerCompletion();
    });
  }

  Future<void> _checkPartnerCompletion() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      final sessionParts = widget.session.id.split('_');
      if (sessionParts.length < 3) {
        Logger.error('Invalid session ID format: ${widget.session.id}', service: 'you_or_me');
        return;
      }
      final timestamp = sessionParts.last;

      final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';

      final partnerSession = await _service.getSession(
        partnerSessionId,
        forceRefresh: true,
      );

      final updatedSession = await _service.getSession(
        widget.session.id,
        forceRefresh: true,
      );

      if (updatedSession == null) {
        Logger.warn('Session not found during polling', service: 'you_or_me');
        return;
      }

      final userHasAnswered = updatedSession.hasUserAnswered(user.id);
      final partnerHasAnswered = partnerSession != null &&
                                partnerSession.hasUserAnswered(partner.pushToken);

      if (userHasAnswered && partnerHasAnswered) {
        Logger.info('Both users completed! Navigating to results...', service: 'you_or_me');

        _pollTimer?.cancel();

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeResultsScreen(session: updatedSession),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error checking partner completion', error: e, service: 'you_or_me');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _checkQuestCompletion() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      final questService = DailyQuestService(storage: _storage);
      final todayQuests = questService.getTodayQuests();

      final sessionParts = widget.session.id.split('_');
      final sessionTimestamp = sessionParts.length >= 3 ? sessionParts.last : '';

      final matchingQuest = todayQuests
          .where((q) {
            if (q.type != QuestType.youOrMe) return false;

            final questIdParts = q.contentId.split('_');
            if (questIdParts.length < 3) return false;

            return questIdParts.last == sessionTimestamp;
          })
          .firstOrNull;

      if (matchingQuest == null) {
        return;
      }

      final userAnswers = widget.session.answers?[user.id];
      if (userAnswers == null || userAnswers.length < widget.session.questions.length) {
        return;
      }

      await questService.completeQuestForUser(
        questId: matchingQuest.id,
        userId: user.id,
      );

      final syncService = QuestSyncService(storage: _storage);

      await syncService.markQuestCompleted(
        questId: matchingQuest.id,
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );

      Logger.success('Daily You or Me quest marked as completed for ${user.name}', service: 'you_or_me');
    } catch (e) {
      Logger.error('Error checking quest completion', error: e, service: 'you_or_me');
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
    final partnerName = partner?.name ?? 'Partner';
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
                            // Subtle scale: 1.0 -> 1.02 -> 1.0 (breathing effect)
                            final scale = 1.0 + (0.02 * Curves.easeInOut.transform(_breatheController.value));
                            // Subtle vertical float: 0 -> -4px -> 0
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
                          label: _isSendingPoke ? 'Sending...' : 'Nudge Partner',
                          emoji: '👆',
                          onPressed: _isSendingPoke ? null : _sendReminder,
                        ),
                      ),

                      // Check for updates
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _isChecking ? null : _checkPartnerCompletion,
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
              // Stagger each dot's animation
              final offset = index * 0.33;
              final animValue = (_dotsController.value + offset) % 1.0;

              // Create a smooth wave: 0->1->0 over the animation cycle
              final wave = animValue < 0.5
                  ? animValue * 2
                  : 2.0 - (animValue * 2);

              // Apply easing
              final easedWave = Curves.easeInOut.transform(wave);

              // Scale: 0.6 -> 1.0 -> 0.6
              final scale = 0.6 + (0.4 * easedWave);
              // Opacity: 0.3 -> 1.0 -> 0.3
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
