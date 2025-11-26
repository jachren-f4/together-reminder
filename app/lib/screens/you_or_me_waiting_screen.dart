import 'package:flutter/material.dart';
import 'dart:async';
import '../models/you_or_me.dart';
import '../models/daily_quest.dart';
import '../services/you_or_me_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../utils/logger.dart';
import '../config/brand/brand_loader.dart';
import 'you_or_me_results_screen.dart';

/// Waiting screen for You or Me game
/// Shows while waiting for partner to complete the game
class YouOrMeWaitingScreen extends StatefulWidget {
  final YouOrMeSession session;

  const YouOrMeWaitingScreen({
    super.key,
    required this.session,
  });

  @override
  State<YouOrMeWaitingScreen> createState() => _YouOrMeWaitingScreenState();
}

class _YouOrMeWaitingScreenState extends State<YouOrMeWaitingScreen> {
  final YouOrMeService _service = YouOrMeService();
  final StorageService _storage = StorageService();
  Timer? _pollTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkQuestCompletion();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 3 seconds to check if partner has completed
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

      // For You or Me, we need to check if the partner's session exists and has answers
      // Extract timestamp from current session ID
      final sessionParts = widget.session.id.split('_');
      if (sessionParts.length < 3) {
        Logger.error('Invalid session ID format: ${widget.session.id}', service: 'you_or_me');
        return;
      }
      final timestamp = sessionParts.last;

      // Construct partner's session ID
      final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';

      // Try to get the partner's session from Firebase
      final partnerSession = await _service.getSession(
        partnerSessionId,
        forceRefresh: true,
      );

      // Also refresh our own session to ensure we have latest data
      final updatedSession = await _service.getSession(
        widget.session.id,
        forceRefresh: true,
      );

      if (updatedSession == null) {
        Logger.warn('Session not found during polling', service: 'you_or_me');
        return;
      }

      // Check if both sessions exist and have answers
      final userHasAnswered = updatedSession.hasUserAnswered(user.id);
      final partnerHasAnswered = partnerSession != null &&
                                partnerSession.hasUserAnswered(partner.pushToken);

      if (userHasAnswered && partnerHasAnswered) {
        Logger.info('Both users completed! Navigating to results...', service: 'you_or_me');

        _pollTimer?.cancel();

        if (!mounted) return;

        // Pass the user's session which will have the questions
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

  /// Check if this game session is linked to a daily quest and mark it as completed
  Future<void> _checkQuestCompletion() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      // Check if there's a daily quest for this game session
      final questService = DailyQuestService(storage: _storage);
      final todayQuests = questService.getTodayQuests();

      // Extract timestamp from session ID (format: youorme_{userId}_{timestamp})
      final sessionParts = widget.session.id.split('_');
      final sessionTimestamp = sessionParts.length >= 3 ? sessionParts.last : '';

      // Find quest with matching timestamp (both sessions share the same timestamp)
      final matchingQuest = todayQuests
          .where((q) {
            if (q.type != QuestType.youOrMe) return false;

            // Extract timestamp from quest's contentId
            final questIdParts = q.contentId.split('_');
            if (questIdParts.length < 3) return false;

            // Match by timestamp since both sessions share the same timestamp
            return questIdParts.last == sessionTimestamp;
          })
          .firstOrNull;

      if (matchingQuest == null) {
        // Not a daily quest game - just played from Activities screen
        return;
      }

      // Check if current user has completed all questions
      final userAnswers = widget.session.answers?[user.id];
      if (userAnswers == null || userAnswers.length < widget.session.questions.length) {
        return; // User hasn't completed the game yet
      }

      // Mark quest as completed for this user
      await questService.completeQuestForUser(
        questId: matchingQuest.id,
        userId: user.id,
      );

      // Sync with Firebase
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = _storage.getPartner();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: BrandLoader().colors.textPrimary),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: BrandLoader().colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_empty,
                  color: BrandLoader().colors.textOnPrimary,
                  size: 60,
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                'All done!',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair Display',
                  color: const Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Message
              Text(
                'Waiting for ${partner?.name ?? 'your partner'} to complete the game...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BrandLoader().colors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(BrandLoader().colors.primary),
              ),

              const SizedBox(height: 32),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFD),
                  border: Border.all(color: const Color(0xFFF0F0F0), width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF6E6E6E),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You\'ll see the results as soon as they finish!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: BrandLoader().colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Exit button
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text(
                  'Exit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6E6E6E),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
