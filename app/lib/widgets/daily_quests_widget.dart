import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/home_polling_service.dart';
import '../services/love_point_service.dart';
import '../services/unlock_service.dart';
import '../services/you_or_me_match_service.dart';
import '../theme/app_theme.dart';
import '../config/brand/brand_loader.dart';
import '../utils/logger.dart';
import '../widgets/quest_carousel.dart';
import '../widgets/animations/dramatic_entrance_widgets.dart';
import '../screens/quiz_intro_screen.dart';
import '../screens/affirmation_intro_screen.dart';
import '../screens/you_or_me_match_intro_screen.dart';
import '../screens/quiz_match_results_screen.dart';
import '../screens/quiz_match_waiting_screen.dart';
import '../screens/you_or_me_match_results_screen.dart';
import '../screens/game_waiting_screen.dart';
import '../services/quiz_match_service.dart';
import '../services/unified_game_service.dart';

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

  // Optimistic guidance override - takes precedence over server state
  // Set when returning from a quest, cleared when server state is fetched
  GuidanceTarget? _guidanceTargetOverride;

  // Track whether we're still waiting for initial quest load
  // This prevents showing the ugly "No Daily Quests Yet" flash
  bool _isInitialLoad = true;

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

    // Register unlock change callback to refresh when features are unlocked
    _unlockService.addOnUnlockChanged(_onUnlockChanged);

    // Mark initial load complete after a brief delay
    // This gives QuestInitializationService time to sync if needed
    _waitForQuestsToLoad();
  }

  /// Wait for quests to appear (either from Hive or server sync)
  /// Shows a brief loading state instead of "No Daily Quests Yet"
  Future<void> _waitForQuestsToLoad() async {
    // Check immediately - quests might already be in Hive
    if (_questService.getMainDailyQuests().isNotEmpty) {
      if (mounted) setState(() => _isInitialLoad = false);
      return;
    }

    // Give time for QuestInitializationService to sync from server
    // Check every 200ms for up to 3 seconds
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      if (_questService.getMainDailyQuests().isNotEmpty) {
        setState(() => _isInitialLoad = false);
        return;
      }
    }

    // After 3 seconds, stop waiting and show whatever state we have
    if (mounted) setState(() => _isInitialLoad = false);
  }

  Future<void> _fetchUnlockState() async {
    try {
      final state = await _unlockService.getUnlockState();
      if (mounted && state != null) {
        setState(() {
          _unlockState = state;
          // Clear optimistic override now that we have real server state
          _guidanceTargetOverride = null;
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
  void didPopNext() async {
    // Called when a route has been popped off, and this route is now visible
    // This happens when returning from quiz/waiting/results screens
    if (mounted) {
      // Force immediate poll when returning from a game screen
      // MUST await before setState to prevent flash (stale data → fresh data)
      await _pollingService.pollNow();
      if (!mounted) return;

      // Optimistically update guidance to point to next incomplete quest
      // This ensures quest cards and hand position update together instantly
      _updateGuidanceOptimistically();
      setState(() {});

      // Then fetch real unlock state in background (for accuracy)
      _fetchUnlockState();
      Logger.debug('Route popped - refreshing quest cards with optimistic guidance', service: 'quest');
    }
  }

  /// Optimistically update guidance target based on local quest completion state
  /// Points to the first incomplete quest (both partners must have completed previous ones)
  void _updateGuidanceOptimistically() {
    final quests = _questService.getMainDailyQuests();

    // Find first incomplete quest (both partners completed = isCompleted)
    GuidanceTarget? newTarget;
    for (final quest in quests) {
      if (!quest.isCompleted) {
        // This is the first incomplete quest - point here
        if (quest.type == QuestType.quiz && quest.formatType == 'classic') {
          newTarget = GuidanceTarget.classicQuiz;
        } else if (quest.type == QuestType.quiz && quest.formatType == 'affirmation') {
          newTarget = GuidanceTarget.affirmationQuiz;
        } else if (quest.type == QuestType.youOrMe) {
          newTarget = GuidanceTarget.youOrMe;
        }
        break;
      }
    }

    // If all daily quests completed, point to side quests (linked)
    newTarget ??= GuidanceTarget.linked;

    // Set the override - this takes precedence until server state arrives
    _guidanceTargetOverride = newTarget;
    Logger.debug('Optimistic guidance update: pointing to $newTarget', service: 'guidance');
  }

  /// Called when HomePollingService detects quest updates
  void _onQuestUpdate() {
    if (mounted) {
      setState(() {});
      // Also sync LP from server - partner completion may have awarded LP
      LovePointService.fetchAndSyncFromServer();
    }
  }

  /// Called when UnlockService detects new unlocks (e.g., after quiz completion)
  void _onUnlockChanged() {
    if (mounted) {
      Logger.debug('Unlock state changed - refreshing from service cache', service: 'quest');
      // Get the updated state from service's cache (already updated by notifyCompletion)
      final updatedState = _unlockService.cachedState;
      if (updatedState != null) {
        setState(() {
          _unlockState = updatedState;
        });
      }
    }
  }

  @override
  void dispose() {
    questRouteObserver.unsubscribe(this);
    _pollingService.unsubscribeFromTopic('dailyQuests', _onQuestUpdate);
    _pollingService.unsubscribe();
    _unlockService.removeOnUnlockChanged(_onUnlockChanged); // Remove unlock callback
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final quests = _questService.getMainDailyQuests();
    final allCompleted = _questService.areAllMainQuestsCompleted();

    // Debug: Log quest completion state on every build
    for (final quest in quests) {
      Logger.debug(
        '🎯 Quest build: ${quest.formatType} status=${quest.status} '
        'completions=${quest.userCompletions} userId=${user?.id}',
        service: 'quest-debug',
      );
    }

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
        // Show loading state during initial load to prevent "No Daily Quests Yet" flash
        if (_isInitialLoad && quests.isEmpty)
          _buildLoadingState()
        else if (quests.isEmpty)
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
            guidanceBuilder: _getGuidanceState,
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

  /// Loading state shown during initial quest sync
  /// This prevents the "No Daily Quests Yet" flash
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 340, // Match carousel card height
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: BrandLoader().colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: BrandLoader().colors.borderLight,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    BrandLoader().colors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading quests...',
                style: TextStyle(
                  fontSize: 14,
                  color: BrandLoader().colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
        unlockCriteria: isLocked ? 'Complete quizzes first' : null,
      );
    }

    // Daily quizzes (classic, affirmation) are never locked
    return (isLocked: false, unlockCriteria: null);
  }

  /// Determine if a daily quest should show onboarding guidance
  ({bool showGuidance, String? guidanceText}) _getGuidanceState(DailyQuest quest) {
    // If unlock state hasn't loaded yet, don't show guidance
    if (_unlockState == null) {
      return (showGuidance: false, guidanceText: null);
    }

    final storage = StorageService();
    final user = storage.getUser();
    final userId = user?.id;

    // Check if any quest is in "waiting for partner" state
    // If user completed but partner hasn't, suppress all guidance - user should wait for results
    if (userId != null) {
      final allQuests = _questService.getMainDailyQuests();
      final anyWaitingForPartner = allQuests.any((q) {
        final userCompleted = q.hasUserCompleted(userId);
        final bothCompleted = q.isCompleted;
        return userCompleted && !bothCompleted;
      });
      if (anyWaitingForPartner) {
        Logger.debug('_getGuidanceState: SUPPRESSING all guidance (waiting for partner)', service: 'guidance');
        return (showGuidance: false, guidanceText: null);
      }
    }

    // Check for pending results - user needs to see results before moving on
    // Order: classic_quiz (1) → affirmation_quiz (2) → you_or_me (3)
    final hasClassicPending = storage.hasPendingResults('classic_quiz');
    final hasAffirmationPending = storage.hasPendingResults('affirmation_quiz');
    final hasYouOrMePending = storage.hasPendingResults('you_or_me');
    final anyPending = hasClassicPending || hasAffirmationPending || hasYouOrMePending;

    Logger.debug('_getGuidanceState: quest=${quest.type.name} format=${quest.formatType} '
        'pending=[classic:$hasClassicPending, affirmation:$hasAffirmationPending, youOrMe:$hasYouOrMePending]',
        service: 'guidance');

    // If any quest has pending results, only that quest shows guidance
    // Earlier quests take priority - all others are suppressed
    if (anyPending) {
      if (quest.type == QuestType.quiz && quest.formatType == 'classic' && hasClassicPending) {
        Logger.debug('_getGuidanceState: showing guidance on CLASSIC (pending)', service: 'guidance');
        return (showGuidance: true, guidanceText: 'Continue Here');
      }
      if (quest.type == QuestType.quiz && quest.formatType == 'affirmation' && hasAffirmationPending && !hasClassicPending) {
        Logger.debug('_getGuidanceState: showing guidance on AFFIRMATION (pending)', service: 'guidance');
        return (showGuidance: true, guidanceText: 'Continue Here');
      }
      if (quest.type == QuestType.youOrMe && hasYouOrMePending && !hasClassicPending && !hasAffirmationPending) {
        Logger.debug('_getGuidanceState: showing guidance on YOU_OR_ME (pending)', service: 'guidance');
        return (showGuidance: true, guidanceText: 'Continue Here');
      }
      // Some other quest has pending results - suppress guidance on this quest
      Logger.debug('_getGuidanceState: SUPPRESSING guidance on ${quest.type.name} (other quest has pending)', service: 'guidance');
      return (showGuidance: false, guidanceText: null);
    }

    // Use optimistic override if set, otherwise use server state
    final target = _guidanceTargetOverride ?? _unlockState!.currentGuidanceTarget;
    final text = _unlockState!.guidanceText;

    // Match quest type to guidance target
    if (quest.type == QuestType.quiz) {
      if (quest.formatType == 'classic' && target == GuidanceTarget.classicQuiz) {
        return (showGuidance: true, guidanceText: text);
      }
      if (quest.formatType == 'affirmation' && target == GuidanceTarget.affirmationQuiz) {
        return (showGuidance: true, guidanceText: text);
      }
    }
    if (quest.type == QuestType.youOrMe && target == GuidanceTarget.youOrMe) {
      return (showGuidance: true, guidanceText: text);
    }

    return (showGuidance: false, guidanceText: null);
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
    final storage = StorageService();
    final contentType = quest.formatType == 'affirmation' ? 'affirmation_quiz' : 'classic_quiz';
    final quizType = quest.formatType == 'affirmation' ? 'affirmation' : 'classic';
    final user = storage.getUser();
    final userId = user?.id;

    // Check for pending results (user was on waiting screen and killed app)
    final pendingMatchId = storage.getPendingResultsMatchId(contentType);

    // Check if user has completed but partner hasn't (waiting for partner state)
    final userCompleted = userId != null && quest.hasUserCompleted(userId);
    final bothCompleted = quest.isCompleted;
    final waitingForPartner = userCompleted && !bothCompleted;

    Logger.debug('Quiz tap: contentType=$contentType userCompleted=$userCompleted '
        'bothCompleted=$bothCompleted pendingMatchId=$pendingMatchId',
        service: 'quest');

    // Case 1: Both completed AND we have pendingMatchId → show results
    // If no pendingMatchId, user already saw results - fall through to start new game
    if (bothCompleted && pendingMatchId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizMatchResultsScreen(
            matchId: pendingMatchId,
            quizType: quizType,
            fromPendingResults: true,
          ),
        ),
      );
      return;
    }

    // Case 2: User completed, waiting for partner → go directly to waiting screen
    if (waitingForPartner) {
      String matchId;

      if (pendingMatchId != null) {
        // Use stored matchId
        matchId = pendingMatchId;
      } else {
        // No stored matchId - fetch active match from server
        // getOrCreateMatch returns existing match if user already submitted
        try {
          final state = await QuizMatchService().getOrCreateMatch(quizType);
          matchId = state.match.id;

          // Store it for future use
          await storage.setPendingResultsMatchId(contentType, matchId);
          Logger.debug('Restored matchId from server: $matchId', service: 'quest');
        } catch (e) {
          Logger.error('Failed to get active match, falling back to intro', error: e, service: 'quest');
          // Fall through to intro screen
          matchId = '';
        }
      }

      if (matchId.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizMatchWaitingScreen(
              matchId: matchId,
              quizType: quizType,
              questId: quest.id,
            ),
          ),
        );
        return;
      }
    }

    // Case 3: Normal flow - show intro screen
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
    final storage = StorageService();
    const contentType = 'you_or_me';
    final user = storage.getUser();
    final userId = user?.id;

    // Check for pending results (user was on waiting screen and killed app)
    final pendingMatchId = storage.getPendingResultsMatchId(contentType);

    // Check if user has completed but partner hasn't (waiting for partner state)
    final userCompleted = userId != null && quest.hasUserCompleted(userId);
    final bothCompleted = quest.isCompleted;
    final waitingForPartner = userCompleted && !bothCompleted;

    Logger.debug('YouOrMe tap: userCompleted=$userCompleted '
        'bothCompleted=$bothCompleted pendingMatchId=$pendingMatchId',
        service: 'quest');

    // Case 1: Both completed AND we have pendingMatchId → show results
    // If no pendingMatchId, user already saw results - fall through to start new game
    if (bothCompleted && pendingMatchId != null) {
      try {
        final state = await YouOrMeMatchService().pollMatchState(pendingMatchId);

        if (mounted && state.isCompleted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => YouOrMeMatchResultsScreen(
                match: state.match,
                quiz: state.quiz,
                myScore: state.myScore,
                partnerScore: state.partnerScore,
                fromPendingResults: true,
                matchPercentage: state.matchPercentage,
                userAnswers: state.userAnswers,
                partnerAnswers: state.partnerAnswers,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        Logger.error('Failed to fetch completed results', error: e, service: 'you_or_me');
        await storage.clearPendingResultsMatchId(contentType);
        // Fall through to intro screen
      }
    }

    // Case 2: User completed, waiting for partner → go directly to waiting screen
    if (waitingForPartner) {
      String matchId;

      if (pendingMatchId != null) {
        matchId = pendingMatchId;
      } else {
        // No stored matchId - fetch active match from server
        try {
          final state = await YouOrMeMatchService().getOrCreateMatch();
          matchId = state.match.id;
          await storage.setPendingResultsMatchId(contentType, matchId);
          Logger.debug('Restored YouOrMe matchId from server: $matchId', service: 'quest');
        } catch (e) {
          Logger.error('Failed to get active YouOrMe match, falling back to intro', error: e, service: 'quest');
          matchId = '';
        }
      }

      if (matchId.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameWaitingScreen(
              matchId: matchId,
              gameType: GameType.you_or_me,
              questId: quest.id,
            ),
          ),
        );
        return;
      }
    }

    // Case 3: Normal flow - show intro screen
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
