import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/base_session.dart';
import '../models/quest_type_config.dart';
import '../models/quiz_session.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../utils/logger.dart';
import '../config/brand/brand_loader.dart';

/// Unified results screen for all quest types
/// Provides frame with confetti, LP banner, and quest completion logic
/// Renders quest-specific content via builder
class UnifiedResultsScreen extends StatefulWidget {
  final BaseSession session;
  final ResultsConfig config;
  final Widget Function(BaseSession) contentBuilder;

  const UnifiedResultsScreen({
    super.key,
    required this.session,
    required this.config,
    required this.contentBuilder,
  });

  @override
  State<UnifiedResultsScreen> createState() => _UnifiedResultsScreenState();
}

class _UnifiedResultsScreenState extends State<UnifiedResultsScreen> {
  final StorageService _storage = StorageService();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Show confetti if configured and threshold met
    if (_shouldShowConfetti()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confettiController.play();
      });
    }

    // Handle quest completion
    _checkQuestCompletion();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  bool _shouldShowConfetti() {
    if (!widget.config.showConfetti) return false;
    if (widget.config.confettiThreshold == null) return false;

    // Only QuizSession has matchPercentage
    if (widget.session is QuizSession) {
      final session = widget.session as QuizSession;
      final matchPercentage = session.matchPercentage ?? 0;
      return matchPercentage >= widget.config.confettiThreshold!;
    }

    return false;
  }

  Future<void> _checkQuestCompletion() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) {
        Logger.debug('No user or partner found, skipping quest completion', service: 'unified');
        return;
      }

      // Find quest by session ID
      final questService = DailyQuestService(storage: _storage);
      final todayQuests = questService.getTodayQuests();

      // Look up quest by contentId
      final matchingQuests = todayQuests.where((q) => q.contentId == widget.session.id).toList();

      if (matchingQuests.isEmpty) {
        Logger.debug('No matching quest found for session ${widget.session.id}', service: 'unified');
        // Not a daily quest - just a standalone quiz/game
        return;
      }

      final quest = matchingQuests.first;

      Logger.debug('Found matching quest: ${quest.id}', service: 'unified');

      // Check if user has completed all questions
      final userHasCompleted = widget.session.hasUserAnswered(user.id);
      if (!userHasCompleted) {
        Logger.debug('User has not completed session yet', service: 'unified');
        return;
      }

      // Mark quest as completed for this user
      final bothCompleted = await questService.completeQuestForUser(
        questId: quest.id,
        userId: user.id,
      );

      Logger.debug('Quest completion status - bothCompleted: $bothCompleted', service: 'unified');

      // Sync with Firebase
      final syncService = QuestSyncService(storage: _storage);
      await syncService.markQuestCompleted(
        questId: quest.id,
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );

      // Award LP if both users completed and LP not yet awarded
      if (bothCompleted && (quest.lpAwarded == null || quest.lpAwarded == 0)) {
        Logger.success('Both users completed quest, awarding LP', service: 'unified');

        await LovePointService.awardPointsToBothUsers(
          userId1: user.id,
          userId2: partner.pushToken,
          amount: 30,
          reason: 'daily_quest_${quest.type.name}',
          relatedId: quest.id,
        );

        // Mark LP as awarded on quest
        quest.lpAwarded = 30;
        await _storage.saveDailyQuest(quest);
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Error checking quest completion',
        error: e,
        stackTrace: stackTrace,
        service: 'unified',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Quest-specific content (provided via builder)
          widget.contentBuilder(widget.session),

          // Confetti overlay
          if (widget.config.showConfetti)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: [
                  BrandLoader().colors.error,
                  BrandLoader().colors.primary,
                  BrandLoader().colors.success,
                  BrandLoader().colors.warning,
                  BrandLoader().colors.info,
                  BrandLoader().colors.accentGreen,
                ],
              ),
            ),
        ],
      ),
    );
  }
}
