import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/home_polling_service.dart';
import '../services/love_point_service.dart';
import '../services/unlock_service.dart';
import '../theme/app_theme.dart';
import '../config/brand/brand_loader.dart';
import '../utils/logger.dart';
import '../widgets/quest_carousel.dart';
import '../widgets/animations/dramatic_entrance_widgets.dart';
import '../screens/quiz_intro_screen.dart';
import '../screens/affirmation_intro_screen.dart';
import '../screens/you_or_me_match_intro_screen.dart';

/// Global RouteObserver for tracking navigation events
/// This should be added to MaterialApp's navigatorObservers
final RouteObserver<ModalRoute<void>> questRouteObserver = RouteObserver<ModalRoute<void>>();

/// Widget displaying daily quests with completion tracking
///
/// Shows 3 daily quests with visual progress tracker and completion banner.
/// Uses HomePollingService for unified partner completion sync.
class DailyQuestsWidget extends StatefulWidget {
  const DailyQuestsWidget({Key? key}) : super(key: key);

  @override
  State<DailyQuestsWidget> createState() => _DailyQuestsWidgetState();
}

class _DailyQuestsWidgetState extends State<DailyQuestsWidget> with RouteAware {
  final StorageService _storage = StorageService();
  final HomePollingService _pollingService = HomePollingService();
  final UnlockService _unlockService = UnlockService();
  late DailyQuestService _questService;
  UnlockState? _unlockState;

  @override
  void initState() {
    super.initState();
    _questService = DailyQuestService(
      storage: _storage,
    );

    // Subscribe to unified polling service for partner quest completions
    _pollingService.subscribe();
    _pollingService.subscribeToTopic('dailyQuests', _onQuestUpdate);

    // Fetch unlock state for You or Me locking
    _fetchUnlockState();
  }

  Future<void> _fetchUnlockState() async {
    try {
      final state = await _unlockService.getUnlockState();
      if (mounted && state != null) {
        setState(() {
          _unlockState = state;
        });
      }
    } catch (e) {
      Logger.error('Failed to fetch unlock state', error: e, service: 'quest');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events to detect when we return from a quest screen
    final route = ModalRoute.of(context);
    if (route != null) {
      questRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Called when a route has been popped off, and this route is now visible
    // This happens when returning from quiz/waiting/results screens
    if (mounted) {
      // Force immediate poll when returning from a game screen
      _pollingService.pollNow();
      setState(() {});
      Logger.debug('Route popped - refreshing quest cards', service: 'quest');
    }
  }

  /// Called when HomePollingService detects quest updates
  void _onQuestUpdate() {
    if (mounted) {
      setState(() {});
      // Also sync LP from server - partner completion may have awarded LP
      LovePointService.fetchAndSyncFromServer();
    }
  }

  @override
  void dispose() {
    questRouteObserver.unsubscribe(this);
    _pollingService.unsubscribeFromTopic('dailyQuests', _onQuestUpdate);
    _pollingService.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final quests = _questService.getMainDailyQuests();
    final allCompleted = _questService.areAllMainQuestsCompleted();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: BrandLoader().colors.textPrimary, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Section header with bounce animation (swipe hint commented out)
          BounceInWidget(
            delay: const Duration(milliseconds: 400),
            initialScale: 0.9,
            initialTranslateY: 30.0,
            trackingKey: 'daily_quests_header',
            child: Padding(
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
                      color: BrandLoader().colors.textPrimary,
                    ),
                  ),
                // Text(
                //   '← SWIPE →', // Match HTML mockup exactly (always LTR, uppercase)
                //   style: AppTheme.headlineFont.copyWith( // Use serif font like HTML mockup
                //     fontSize: 13, // Increased from 11 to match visual size of HTML mockup
                //     color: const Color(0xFF999999),
                //     fontWeight: FontWeight.w600,
                //     letterSpacing: 1,
                //   ),
                // ),
              ],
            ),
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
            isLockedBuilder: _getQuestLockState,
          ),

        const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BrandLoader().colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BrandLoader().colors.borderLight,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today, size: 48, color: BrandLoader().colors.textTertiary),
          const SizedBox(height: 12),
          Text(
            'No Daily Quests Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: BrandLoader().colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check back tomorrow for new quests!',
            style: TextStyle(
              fontSize: 14,
              color: BrandLoader().colors.textSecondary,
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
          color: BrandLoader().colors.surface,
          border: Border.all(color: BrandLoader().colors.textPrimary, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BrandLoader().colors.textPrimary.withOpacity(0.06),
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
                  color: BrandLoader().colors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Determine if a daily quest is locked based on unlock state
  ({bool isLocked, String? unlockCriteria}) _getQuestLockState(DailyQuest quest) {
    // If unlock state hasn't loaded yet, show everything as unlocked
    if (_unlockState == null) {
      return (isLocked: false, unlockCriteria: null);
    }

    // Only You or Me can be locked in daily quests
    if (quest.type == QuestType.youOrMe) {
      final isLocked = !_unlockState!.isFeatureUnlocked(UnlockableFeature.youOrMe);
      return (
        isLocked: isLocked,
        unlockCriteria: isLocked ? 'Complete a Daily Quest to unlock' : null,
      );
    }

    // Daily quizzes (classic, affirmation) are never locked
    return (isLocked: false, unlockCriteria: null);
  }

  void _handleQuestTap(DailyQuest quest) async {
    // Navigate based on quest type
    switch (quest.type) {
      case QuestType.quiz:
        await _handleQuizQuestTap(quest);
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

      case QuestType.linked:
        // Linked is handled via Side Quests carousel, not daily quests
        break;

      case QuestType.wordSearch:
        // TODO: Navigate to Word Search screen
        break;

      case QuestType.steps:
        // Steps Together is handled via Side Quests carousel, not daily quests
        break;
    }

    // Refresh state after returning from quest
    // setState() alone is enough - Hive returns the same object instances
    // that were updated by the game screen's _updateLocalQuestStatus()
    // The rebuild will re-read from _questService.getMainDailyQuests()
    // which fetches fresh data from Hive
    if (mounted) {
      setState(() {
        // Force widget rebuild - Hive objects are already updated
      });
    }
  }

  Future<void> _handleQuizQuestTap(DailyQuest quest) async {
    // Always show intro screen first
    // The game screen will handle redirecting to waiting/results if user has already answered
    // NOTE: We don't skip intro based on local userCompletions because:
    // 1. With cooldown disabled, server may create a new match even after "completion"
    // 2. The game screen properly handles all states (new, in-progress, waiting, completed)
    if (quest.formatType == 'affirmation') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AffirmationIntroScreen(
            branch: quest.branch,
            questId: quest.id,
          ),
        ),
      );
    } else {
      // Classic quiz
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizIntroScreen(
            branch: quest.branch,
            questId: quest.id,
          ),
        ),
      );
    }
  }

  Future<void> _handleYouOrMeQuestTap(DailyQuest quest) async {
    // Always show intro screen first (same reasoning as quiz quests)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouOrMeMatchIntroScreen(
          branch: quest.branch,
          questId: quest.id,
        ),
      ),
    );
  }
}
