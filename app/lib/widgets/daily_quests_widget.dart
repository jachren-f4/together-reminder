import 'dart:async';
import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../services/quiz_service.dart';
import '../services/you_or_me_service.dart';
import '../services/quest_navigation_service.dart';
import '../utils/logger.dart';
import '../theme/app_theme.dart';
import '../widgets/quest_carousel.dart';
import '../screens/you_or_me_intro_screen.dart';
import '../screens/you_or_me_results_screen.dart';
import '../screens/you_or_me_waiting_screen.dart';

/// Widget displaying daily quests with completion tracking
///
/// Shows 3 daily quests with visual progress tracker and completion banner
class DailyQuestsWidget extends StatefulWidget {
  const DailyQuestsWidget({Key? key}) : super(key: key);

  @override
  State<DailyQuestsWidget> createState() => _DailyQuestsWidgetState();
}

class _DailyQuestsWidgetState extends State<DailyQuestsWidget> {
  final StorageService _storage = StorageService();
  late DailyQuestService _questService;
  late QuestSyncService _questSyncService;
  final QuizService _quizService = QuizService();
  final YouOrMeService _youOrMeService = YouOrMeService();
  late QuestNavigationService _navigationService;
  StreamSubscription? _partnerCompletionSubscription;

  @override
  void initState() {
    super.initState();
    _questService = DailyQuestService(
      storage: _storage,
    );
    _questSyncService = QuestSyncService(
      storage: _storage,
    );
    _navigationService = QuestNavigationService(storage: _storage);

    // Listen for partner quest completions
    _listenForPartnerCompletions();

    // Quest generation happens in main.dart on app start
  }

  /// Listen for partner's quest completions in real-time
  void _listenForPartnerCompletions() {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      return; // Can't listen without both users
    }

    _partnerCompletionSubscription = _questSyncService
        .listenForPartnerCompletions(
          currentUserId: user.id,
          partnerUserId: partner.pushToken,
        )
        .listen((partnerCompletions) {
      // partnerCompletions is a map of {questId: true} for completed quests
      if (partnerCompletions.isEmpty) return;

      // Removed verbose logging
      // print('📥 Received partner quest completions: ${partnerCompletions.keys.join(", ")}');

      // Update local storage with partner's completions
      for (final questId in partnerCompletions.keys) {
        final quest = _storage.getDailyQuest(questId);
        // print('🔍 Looking for quest: $questId');
        // print('🔍 Found quest: ${quest != null ? quest.id : "NULL"}');
        // if (quest != null) {
        //   print('🔍 Partner already completed? ${quest.hasUserCompleted(partner.pushToken)}');
        //   print('🔍 Partner user ID: ${partner.pushToken}');
        //   print('🔍 Quest completions: ${quest.userCompletions}');
        // }
        if (quest != null && !quest.hasUserCompleted(partner.pushToken)) {
          quest.userCompletions ??= {};
          quest.userCompletions![partner.pushToken] = true;

          // Check if both completed now
          if (quest.areBothUsersCompleted()) {
            quest.status = 'completed';
            quest.completedAt = DateTime.now();

            // NOTE: LP awarding is now handled by UnifiedResultsScreen for quest types
            // using the unified system (classic, affirmation). This prevents duplicate
            // LP awards (once from partner listener, once from UnifiedResultsScreen).
            //
            // Quest types not yet migrated to unified system would award LP here,
            // but as of Phase 4, all quiz types use UnifiedResultsScreen.
            // Future quest types (You or Me, Word Ladder, etc.) will also use unified
            // system and rely on UnifiedResultsScreen for LP awards.
          } else {
            quest.status = 'in_progress';
          }

          _storage.updateDailyQuest(quest);
          // Removed verbose logging
          // print('✅ Updated quest ${quest.type.name} with partner completion');
        }
      }

      // Trigger UI rebuild
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _partnerCompletionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final quests = _questService.getMainDailyQuests();
    final allCompleted = _questService.areAllMainQuestsCompleted();

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Section header with swipe hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DAILY QUESTS',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.black,
                  ),
                ),
              Text(
                '← SWIPE →', // Match HTML mockup exactly (always LTR, uppercase)
                style: AppTheme.headlineFont.copyWith( // Use serif font like HTML mockup
                  fontSize: 13, // Increased from 11 to match visual size of HTML mockup
                  color: const Color(0xFF999999),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Carousel (replaces vertical list)
        if (quests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildEmptyState(),
          )
        else
          QuestCarousel(
            quests: quests,
            currentUserId: user?.id,
            onQuestTap: _handleQuestTap,
          ),

        // Completion banner
        if (allCompleted) _buildCompletionBanner(),

        const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No Daily Quests Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check back tomorrow for new quests!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text(
              '✅',
              style: TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Way to go! You\'ve completed your Daily Quests',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuestTap(DailyQuest quest) async {
    // Navigate based on quest type
    switch (quest.type) {
      case QuestType.quiz:
        await _handleQuizQuestTap(quest);
        break;

      case QuestType.wordLadder:
        // TODO: Navigate to Word Ladder screen
        break;

      case QuestType.memoryFlip:
        // TODO: Navigate to Memory Flip screen
        break;

      case QuestType.youOrMe:
        await _handleYouOrMeQuestTap(quest);
        break;

      case QuestType.question:
        // TODO: Navigate to Question screen
        break;

      case QuestType.game:
        // TODO: Navigate to Game screen
        break;
    }

    // Refresh state after returning
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleQuizQuestTap(DailyQuest quest) async {
    // Both Classic and Affirmation quizzes now use unified navigation (Phases 3-4)
    try {
      await _navigationService.launchQuest(context, quest);
    } catch (e) {
      _showError('Failed to launch quiz: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _handleYouOrMeQuestTap(DailyQuest quest) async {
    // Get user and partner
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      _showError('User or partner not found');
      return;
    }

    // The quest contentId points to the creator's session.
    // Find the current user's own session from the paired session.
    final session = await _youOrMeService.getUserSessionFromPaired(
      quest.contentId,
      user.id,
    );

    if (session == null) {
      _showError('You or Me session not found');
      return;
    }

    // Check if both users have completed
    if (session.areBothUsersAnswered()) {
      // Both answered - show results
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => YouOrMeResultsScreen(session: session),
        ),
      );
    } else if (session.hasUserAnswered(user.id)) {
      // User answered, waiting for partner
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => YouOrMeWaitingScreen(session: session),
        ),
      );
    } else {
      // User hasn't answered - show intro screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => YouOrMeIntroScreen(session: session),
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
