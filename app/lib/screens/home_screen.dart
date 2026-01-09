import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../widgets/brand/brand_widget_factory.dart';
import '../config/animation_constants.dart';
import '../utils/logger.dart';
import '../utils/number_formatter.dart';
import '../services/storage_service.dart';
import '../services/arena_service.dart';
import '../models/arena.dart';
import '../services/daily_pulse_service.dart';
import '../services/word_search_service.dart';
import '../services/linked_service.dart';
import '../services/quiz_service.dart';
import '../services/quest_initialization_service.dart';
import '../services/love_point_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/steps_feature_service.dart';
import '../services/home_polling_service.dart';
import '../services/unlock_service.dart';
import '../services/magnet_service.dart';
import '../models/magnet_collection.dart';
import '../models/cooldown_status.dart';
import '../animations/animation_config.dart';
import '../theme/app_theme.dart';
import '../widgets/poke_bottom_sheet.dart';
import '../widgets/remind_bottom_sheet.dart';
import '../widgets/daily_pulse_widget.dart';
import '../widgets/daily_quests_widget.dart';
import '../widgets/quest_carousel.dart';
import '../widgets/debug/debug_menu.dart';
import '../widgets/leaderboard_bottom_sheet.dart';
import '../widgets/animations/dramatic_entrance_widgets.dart';
import '../models/daily_quest.dart';
import 'daily_pulse_screen.dart';
import 'linked_game_screen.dart';
import 'linked_intro_screen.dart';
import 'word_search_game_screen.dart';
import 'word_search_intro_screen.dart';
import 'quiz_match_game_screen.dart';
import 'quiz_match_waiting_screen.dart';
import 'quiz_intro_screen.dart';
import 'affirmation_intro_screen.dart';
import 'you_or_me_match_intro_screen.dart';
import 'game_waiting_screen.dart';
import 'quiz_match_results_screen.dart';
import 'you_or_me_match_results_screen.dart';
import '../services/quiz_match_service.dart';
import '../services/you_or_me_match_service.dart';
import '../services/unified_game_service.dart';
import 'inbox_screen.dart';
import 'steps_intro_screen.dart';
import 'steps_counter_screen.dart';
import 'linked_completion_screen.dart';
import 'word_search_completion_screen.dart';
import 'magnet_collection_screen.dart';
import '../widgets/lp_intro_overlay.dart';
import '../widgets/animations/lp_celebration_overlay.dart';
import '../widgets/brand/us2/us2_connection_bar.dart';

/// Home tab content showing daily quests, side quests, and stats
///
/// This is the content displayed in the Home tab of MainScreen.
/// Use MainScreen for navigation (includes bottom nav bar).
class HomeScreen extends StatefulWidget {
  /// If true, shows the LP intro overlay after Welcome Quiz completion
  final bool showLpIntro;

  /// Callback to notify parent when LP intro visibility changes
  /// Used by MainScreen to hide bottom nav during LP intro
  final void Function(bool visible)? onLpIntroVisibilityChanged;

  const HomeScreen({
    super.key,
    this.showLpIntro = false,
    this.onLpIntroVisibilityChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, RouteAware {
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();
  final DailyPulseService _pulseService = DailyPulseService();
  final WordSearchService _wordSearchService = WordSearchService();
  final LinkedService _linkedService = LinkedService();
  final QuizService _quizService = QuizService();
  final HomePollingService _pollingService = HomePollingService();
  final UnlockService _unlockService = UnlockService();
  final MagnetService _magnetService = MagnetService();

  bool _isRefreshing = false;
  MagnetCollection? _magnetCollection;
  UnlockState? _unlockState; // Cached unlock state for rendering
  DateTime? _lastSyncTime;
  late AnimationController _pulseController;
  late AnimationController _lpPulseController;
  int _lastLPValue = 0;

  // Cached side quests Future to prevent FutureBuilder from rebuilding on every setState
  // Without this, the carousel blinks every time any setState is called (e.g., from DailyQuests polling)
  Future<List<DailyQuest>>? _sideQuestsFuture;

  // LP intro overlay state
  bool _showingLpIntro = false;

  // LP celebration animation state (Us 2.0 only)
  final GlobalKey<Us2ConnectionBarState> _connectionBarKey = GlobalKey<Us2ConnectionBarState>();
  final GlobalKey _dailyQuestsSectionKey = GlobalKey();
  bool _showingLpCelebration = false;
  int? _lpBeforeQuest; // LP value before navigating to a daily quest
  int? _lpBeforeCelebration; // LP value stored when celebration starts (for connection bar animation)
  bool _navigatedToDailyQuest = false; // Track if we came from a daily quest

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // LP counter pulse animation (single pulse when LP changes)
    _lpPulseController = AnimationController(
      vsync: this,
      duration: AnimationConfig.normal,
    );

    // Store initial LP value
    _lastLPValue = _arenaService.getLovePoints();

    // Register LP change callback for real-time counter updates
    _setupLPChangeCallback();

    // Register unlock change callback to refresh when features are unlocked
    _unlockService.addOnUnlockChanged(_onUnlockChanged);

    // Fetch unlock state for locked quest rendering
    _fetchUnlockState();

    // Fetch magnet collection (for Us 2.0 connection bar)
    _fetchMagnetCollection();

    // Sync LP from server on initial load - triggers magnet unlock celebration if needed
    // Use postFrameCallback to ensure context is available for showing dialogs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LovePointService.fetchAndSyncFromServer();
      }
    });

    // Subscribe to unified polling service for side quest updates
    _pollingService.subscribe();
    _pollingService.subscribeToTopic('sideQuests', _onSideQuestUpdate);
    // Us 2.0: Also subscribe to daily quest updates since DailyQuestsWidget isn't used
    if (BrandWidgetFactory.isUs2) {
      _pollingService.subscribeToTopic('dailyQuests', _onDailyQuestUpdate);
    }

    // Initialize cached Future on first load
    _refreshSideQuestsFuture();

    // LP intro overlay will be shown after _fetchUnlockState() checks server state
    // This ensures we don't re-show if already shown (server-authoritative)
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
    // This happens when returning from Linked/Word Search game screens
    if (mounted) {
      // Capture previous LP for potential celebration (before sync)
      final previousLp = _lpBeforeQuest;
      final wasFromDailyQuest = _navigatedToDailyQuest;

      // Reset tracking flags
      _lpBeforeQuest = null;
      _navigatedToDailyQuest = false;

      // Force immediate poll when returning from a game screen
      // MUST await before setState to prevent flash (stale data → fresh data)
      await _pollingService.pollNow();
      if (!mounted) return;
      // Sync LP from server - this triggers magnet unlock celebration if threshold crossed
      await LovePointService.fetchAndSyncFromServer();
      if (!mounted) return;

      // Check for LP gain from daily quest (Us 2.0 celebration)
      if (wasFromDailyQuest && BrandWidgetFactory.isUs2 && previousLp != null) {
        final newLp = _arenaService.getLovePoints();
        if (newLp > previousLp) {
          // Trigger LP celebration animation after a brief delay
          await Future.delayed(AnimationConstants.lpCelebrationDelay);
          if (mounted) {
            _triggerLpCelebration(previousLp);
          }
          return; // Don't setState here - celebration handles state updates
        }
      }

      // Refresh unlock state - a game completion may have unlocked features
      _fetchUnlockState();
      // Also refresh side quests carousel
      _refreshSideQuestsFuture();
      // Refresh magnet collection (Us 2.0)
      _fetchMagnetCollection();
      setState(() {});
      Logger.debug('Route popped - refreshing side quests, LP, and unlock state', service: 'home');
    }
  }

  /// Trigger the LP celebration animation for Us 2.0
  void _triggerLpCelebration(int previousLp) {
    if (!mounted || !BrandWidgetFactory.isUs2) return;

    Logger.debug('Triggering LP celebration: $previousLp -> ${_arenaService.getLovePoints()}', service: 'home');

    setState(() {
      _lpBeforeCelebration = previousLp;
      _showingLpCelebration = true;
    });
  }

  /// Called when LP celebration particles arrive at the meter
  void _onLpCelebrationComplete() {
    if (!mounted) return;

    // Trigger the connection bar animation using stored previous LP
    final previousLp = _lpBeforeCelebration ?? (_arenaService.getLovePoints() - 30);
    _connectionBarKey.currentState?.animateLPGain(previousLp);

    // Refresh state and hide overlay
    _fetchUnlockState();
    _refreshSideQuestsFuture();
    _fetchMagnetCollection();

    setState(() {
      _showingLpCelebration = false;
      _lpBeforeCelebration = null;
    });
  }

  /// Called when HomePollingService detects side quest updates (Linked/Word Search turn changes)
  void _onSideQuestUpdate() {
    if (mounted) {
      Logger.debug('Side quest update from polling service', service: 'home');
      _refreshSideQuestsFuture();
      setState(() {});
    }
  }

  /// Called when HomePollingService detects daily quest updates (Us 2.0 only)
  /// In Liia mode, DailyQuestsWidget handles its own polling subscription
  void _onDailyQuestUpdate() {
    if (mounted) {
      Logger.debug('Daily quest update from polling service (Us 2.0)', service: 'home');
      setState(() {});
    }
  }

  /// Called when UnlockService detects new unlocks (e.g., after quiz completion)
  void _onUnlockChanged() {
    if (mounted) {
      Logger.debug('Unlock state changed - refreshing from service cache', service: 'home');
      // Get the updated state from service's cache (already updated by notifyCompletion)
      final updatedState = _unlockService.cachedState;
      if (updatedState != null) {
        setState(() {
          _unlockState = updatedState;
        });
        // Also refresh side quests in case new features are unlocked
        _refreshSideQuestsFuture();
      }
    }
  }

  /// Fetch unlock state for rendering locked quests
  Future<void> _fetchUnlockState() async {
    try {
      final state = await _unlockService.getUnlockState();
      if (mounted && state != null) {
        setState(() {
          _unlockState = state;
          // Show LP intro only if:
          // 1. Widget was created with showLpIntro=true (fresh from quiz results)
          // 2. Server says LP intro hasn't been shown yet (server-authoritative)
          // This prevents re-showing on tab switch or widget rebuild
          if (widget.showLpIntro && !state.lpIntroShown) {
            _showingLpIntro = true;
          }
        });
        // Refresh side quests carousel if state changed
        _refreshSideQuestsFuture();
      }
    } catch (e) {
      Logger.error('Failed to fetch unlock state', error: e, service: 'home');
    }
  }

  /// Fetch magnet collection from server (for Us 2.0 connection bar)
  Future<void> _fetchMagnetCollection() async {
    if (!BrandWidgetFactory.isUs2) return;

    try {
      // First, try to get cached collection for immediate display
      final cached = _magnetService.getCachedCollection();
      if (cached != null && mounted) {
        setState(() {
          _magnetCollection = cached;
        });
      }

      // Then fetch from server to ensure data is fresh
      final collection = await _magnetService.fetchAndSync();
      if (mounted && collection != null) {
        setState(() {
          _magnetCollection = collection;
        });
      }
    } catch (e) {
      Logger.error('Failed to fetch magnet collection', error: e, service: 'home');
    }
  }

  /// Setup callback for real-time LP counter updates
  /// Matches pattern used by quest cards (daily_quests_widget.dart)
  void _setupLPChangeCallback() {
    // Register callback WITHOUT creating a new listener
    // (Listener already started in main.dart - don't create duplicate!)
    LovePointService.setLPChangeCallback(() {
      if (mounted) {
        final newLP = _arenaService.getLovePoints();
        if (newLP != _lastLPValue) {
          // Trigger pulse animation on LP change
          _lpPulseController.forward(from: 0.0);
          HapticService().trigger(HapticType.success);
          _lastLPValue = newLP;
        }
        setState(() {
          // Trigger rebuild to update LP counter
        });
      }
    });
  }

  @override
  void dispose() {
    questRouteObserver.unsubscribe(this);
    _pollingService.unsubscribeFromTopic('sideQuests', _onSideQuestUpdate);
    // Us 2.0: Unsubscribe from daily quest updates
    if (BrandWidgetFactory.isUs2) {
      _pollingService.unsubscribeFromTopic('dailyQuests', _onDailyQuestUpdate);
    }
    _pollingService.unsubscribe();
    _unlockService.removeOnUnlockChanged(_onUnlockChanged); // Remove unlock callback
    LovePointService.setLPChangeCallback(null); // Clear LP callback to prevent memory leak
    _pulseController.dispose();
    _lpPulseController.dispose();
    super.dispose();
  }

  /// Refresh the cached side quests Future (call when data changes)
  void _refreshSideQuestsFuture() {
    _sideQuestsFuture = _getSideQuests();
  }

  @override
  Widget build(BuildContext context) {
    // Check if Us 2.0 brand - use completely different home content
    if (BrandWidgetFactory.isUs2) {
      return _buildUs2Home();
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.backgroundGray,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSimplifiedHeader(),
                  _buildMainContent(),
                ],
              ),
            ),
          ),
        ),
        // LP intro overlay (shown after Welcome Quiz completion)
        if (_showingLpIntro)
          LpIntroOverlay(
            onDismiss: () {
              if (mounted) {
                setState(() => _showingLpIntro = false);
                // Notify parent to show bottom nav again
                widget.onLpIntroVisibilityChanged?.call(false);
              }
            },
          ),
      ],
    );
  }

  /// Build Us 2.0 brand home screen content
  Widget _buildUs2Home() {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final currentArena = _arenaService.getCurrentArena();
    final lovePoints = _arenaService.getLovePoints();
    final nextArena = Arena.getNextArena(lovePoints);

    // Calculate days together
    int daysTogether = 1;
    if (partner != null) {
      daysTogether = DateTime.now().difference(partner.pairedAt).inDays + 1;
    }

    // Get daily quests (non-side quests)
    final allQuests = _storage.getTodayQuests();
    final dailyQuests = allQuests.where((q) => !q.isSideQuest).toList();

    return Stack(
      children: [
        FutureBuilder<List<DailyQuest>>(
          future: _sideQuestsFuture ?? _getSideQuests(),
          builder: (context, snapshot) {
            final sideQuests = snapshot.data ?? [];

            return BrandWidgetFactory.us2HomeContent(
              userName: user?.name ?? 'You',
              partnerName: partner?.name ?? 'Partner',
              dayNumber: daysTogether,
              magnetCollection: _magnetCollection,
              onCollectionTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MagnetCollectionScreen(),
                  ),
                );
              },
              dailyQuests: dailyQuests,
              sideQuests: sideQuests,
              onQuestTap: _navigateToQuest,
              onDebugTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const DebugMenu(),
                );
              },
              getDailyQuestGuidance: _getDailyQuestGuidanceState,
              getSideQuestGuidance: _getSideQuestGuidanceState,
              getCooldownStatus: _getCooldownStatus,
              connectionBarKey: _connectionBarKey,
              dailyQuestsSectionKey: _dailyQuestsSectionKey,
            ) ?? const SizedBox.shrink();
          },
        ),
        // LP intro overlay (shown after Welcome Quiz completion)
        if (_showingLpIntro)
          LpIntroOverlay(
            onDismiss: () {
              if (mounted) {
                setState(() => _showingLpIntro = false);
                widget.onLpIntroVisibilityChanged?.call(false);
              }
            },
          ),
        // LP celebration overlay (flying particles from quest to meter)
        if (_showingLpCelebration)
          Builder(
            builder: (context) {
              // Calculate particle positions
              final screenSize = MediaQuery.of(context).size;

              // Start position: center of daily quests section (approximated)
              // The daily quests carousel is roughly in the middle-upper area
              final startPosition = Offset(
                screenSize.width / 2,
                screenSize.height * 0.55, // ~55% down from top (quest cards area)
              );

              // End position: LP counter in connection bar (upper right of bar)
              // Connection bar is at roughly 40% from top, LP is on the right side
              final endPosition = Offset(
                screenSize.width - 60, // Right side with some padding
                screenSize.height * 0.38, // Slightly below hero section
              );

              return LpCelebrationOverlay(
                startPosition: startPosition,
                endPosition: endPosition,
                onComplete: _onLpCelebrationComplete,
                lpAmount: _arenaService.getLovePoints() - (_lpBeforeCelebration ?? 0),
              );
            },
          ),
      ],
    );
  }

  /// Navigate to the appropriate screen for a quest
  void _navigateToQuest(DailyQuest quest) async {
    final storage = StorageService();
    final user = storage.getUser();
    final userId = user?.id;

    // Check if user has completed but partner hasn't (waiting for partner state)
    final userCompleted = userId != null && quest.hasUserCompleted(userId);
    final bothCompleted = quest.isCompleted;
    final waitingForPartner = userCompleted && !bothCompleted;

    // Track LP before navigating to daily quests (for Us 2.0 celebration)
    final isDailyQuest = quest.type == QuestType.quiz || quest.type == QuestType.youOrMe;
    if (isDailyQuest && BrandWidgetFactory.isUs2) {
      _lpBeforeQuest = _arenaService.getLovePoints();
      _navigatedToDailyQuest = true;
    }

    switch (quest.type) {
      case QuestType.quiz:
        final quizType = quest.formatType == 'affirmation' ? 'affirmation' : 'classic';
        final contentType = quest.formatType == 'affirmation' ? 'affirmation_quiz' : 'classic_quiz';
        final pendingMatchId = storage.getPendingResultsMatchId(contentType);

        Logger.debug('Quiz tap: contentType=$contentType userCompleted=$userCompleted '
            'bothCompleted=$bothCompleted pendingMatchId=$pendingMatchId',
            service: 'quest');

        // Case 1: Both completed AND we have pendingMatchId → show results
        if (bothCompleted && pendingMatchId != null) {
          Navigator.push(
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
          String? matchId = pendingMatchId;

          if (matchId == null) {
            // Fetch from server
            try {
              final state = await QuizMatchService().getOrCreateMatch(quizType);
              matchId = state.match.id;
              await storage.setPendingResultsMatchId(contentType, matchId);
            } catch (e) {
              Logger.error('Failed to get match for waiting screen', error: e, service: 'quest');
              // Fall through to intro screen
            }
          }

          if (matchId != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuizMatchWaitingScreen(
                  matchId: matchId!,
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AffirmationIntroScreen(
                branch: quest.branch,
                questId: quest.id,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizIntroScreen(
                branch: quest.branch,
                questId: quest.id,
              ),
            ),
          );
        }
        break;
      case QuestType.youOrMe:
        final youOrMePendingMatchId = storage.getPendingResultsMatchId('you_or_me');

        Logger.debug('YouOrMe tap: userCompleted=$userCompleted '
            'bothCompleted=$bothCompleted pendingMatchId=$youOrMePendingMatchId',
            service: 'quest');

        // Case 1: Both completed AND we have pendingMatchId → show results
        if (bothCompleted && youOrMePendingMatchId != null) {
          try {
            final state = await YouOrMeMatchService().pollMatchState(youOrMePendingMatchId);

            if (mounted && state.isCompleted) {
              Navigator.push(
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
            await storage.clearPendingResultsMatchId('you_or_me');
            // Fall through to intro screen
          }
        }

        // Case 2: User completed, waiting for partner → go directly to waiting screen
        if (waitingForPartner) {
          String? matchId = youOrMePendingMatchId;

          if (matchId == null) {
            // Fetch from server
            try {
              final state = await YouOrMeMatchService().getOrCreateMatch();
              matchId = state.match.id;
              await storage.setPendingResultsMatchId('you_or_me', matchId);
            } catch (e) {
              Logger.error('Failed to get match for waiting screen', error: e, service: 'quest');
              // Fall through to intro screen
            }
          }

          if (matchId != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameWaitingScreen(
                  matchId: matchId!,
                  gameType: GameType.you_or_me,
                  questId: quest.id,
                ),
              ),
            );
            return;
          }
        }

        // Case 3: Normal flow - show intro screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YouOrMeMatchIntroScreen(
              branch: quest.branch,
              questId: quest.id,
            ),
          ),
        );
        break;
      case QuestType.linked:
        _navigateToLinked();
        break;
      case QuestType.wordSearch:
        _navigateToWordSearch();
        break;
      case QuestType.steps:
        _navigateToSteps();
        break;
      case QuestType.question:
      case QuestType.game:
        // Legacy quest types - no navigation
        break;
    }
  }

  void _navigateToLinked() {
    // Use the same navigation logic as _handleQuestCardTap for linked
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LinkedIntroScreen()),
    ).then((_) {
      if (mounted) {
        _refreshSideQuestsFuture();
        setState(() {});
      }
    });
  }

  void _navigateToWordSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WordSearchIntroScreen()),
    ).then((_) {
      if (mounted) {
        _refreshSideQuestsFuture();
        setState(() {});
      }
    });
  }

  void _navigateToSteps() {
    _handleStepsQuestTap();
  }

  Future<void> _refreshFromFirebase() async {
    setState(() => _isRefreshing = true);

    try {
      // Use the centralized QuestInitializationService
      final initService = QuestInitializationService();
      final result = await initService.ensureQuestsInitialized();

      if (result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quests synced!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (!result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${result.errorMessage ?? result.status.name}'),
            backgroundColor: BrandLoader().colors.error,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error refreshing', error: e, service: 'home');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: $e'),
            backgroundColor: BrandLoader().colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _formatTimeSince(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  Widget _buildTopSection() {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final currentArena = _arenaService.getCurrentArena();

    // Calculate days together
    int daysTogether = 1;
    if (user != null && partner != null) {
      daysTogether = DateTime.now().difference(partner.pairedAt).inDays + 1;
    }

    // Calculate quiz match %
    final completedSessions = _quizService.getCompletedSessions();
    int quizMatch = 0;
    if (completedSessions.isNotEmpty) {
      final lastSession = completedSessions.first;
      quizMatch = lastSession.matchPercentage ?? 0;
    }

    // Calculate streak
    final streak = _pulseService.getCurrentStreak();

    return Container(
      color: AppTheme.primaryWhite,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User row with avatars and refresh button
          Row(
            children: [
              // Avatars
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.borderLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryWhite, width: 2),
                    ),
                    child: const Center(
                      child: Text('💕', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  Positioned(
                    left: 36,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.borderLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryWhite, width: 2),
                      ),
                      child: const Center(
                        child: Text('💎', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 48),
              // Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onDoubleTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const DebugMenu(),
                        );
                      },
                      child: Text(
                        _getGreeting(),
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'You & ${partner?.name ?? "Partner"} • Day $daysTogether',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.borderLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${currentArena.emoji} ${currentArena.name}',
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Refresh button
              IconButton(
                icon: Icon(
                  _isRefreshing ? Icons.hourglass_empty : Icons.refresh,
                  color: AppTheme.textSecondary,
                ),
                tooltip: 'Refresh from Firebase',
                onPressed: _isRefreshing ? null : _refreshFromFirebase,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${_arenaService.getLovePoints()}',
                  'Love Points',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '$streak',
                  'Streak',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '$quizMatch%',
                  'Match',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showPokeBottomSheet,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('💫', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 6),
                      Text('Poke'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _showRemindBottomSheet,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('💕', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 6),
                      Text('Remind'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.borderLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.bodyFont.copyWith(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArenaProgressSection() {
    final currentArena = _arenaService.getCurrentArena();
    final nextArena = _arenaService.getNextArena();
    final lovePoints = _arenaService.getLovePoints();
    final progress = currentArena.getProgress(lovePoints);

    if (nextArena == null) {
      // At max tier, show completion message
      return Container(
        decoration: BoxDecoration(
          gradient: currentArena.gradient,
          border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.1), width: 2),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Text(
              'Maximum Arena Reached! 🏆',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: currentArena.gradient,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.15), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // Progress header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentArena.getProgressString(lovePoints),
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 4.0,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 8.0,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${nextArena.emoji} ${nextArena.name}',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 3.0,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      offset: const Offset(0, 0),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Daily Quests - index 2 in stagger sequence (after header sections)
        HomeStaggeredEntrance(
          index: 2,
          trackingKey: 'home_daily_quests',
          child: DailyQuestsWidget(key: ValueKey(_storage.getTodayQuests().length)),
        ),

        const SizedBox(height: 10),

        // Side Quests section header with action buttons - index 3
        HomeStaggeredEntrance(
          index: 3,
          trackingKey: 'home_side_quests_header',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SIDE QUESTS',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2,
                  ),
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton('POKE', false, _showPokeBottomSheet),
                      const SizedBox(width: 8),
                      _buildActionButton('REMIND', false, _showRemindBottomSheet),
                      const SizedBox(width: 8),
                      _buildActionButton('RANKING', false, _showLeaderboardBottomSheet),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Side quests horizontal carousel - index 4
        HomeStaggeredEntrance(
          index: 4,
          trackingKey: 'home_side_quests_carousel',
          child: _buildSideQuestsCarousel(),
        ),

        const SizedBox(height: 16),

        // Version number for debugging hot reload
        Center(
          child: Text(
            'v1.0.70',
            style: TextStyle(
              fontSize: 10,
              color: BrandLoader().colors.textTertiary,
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMainQuestsCarousel() {
    final pulseStatus = _pulseService.getDailyPulseStatus();
    final activeQuiz = _quizService.getActiveSession();

    final quests = <Widget>[
      // Daily Pulse
      _buildQuestCard(
        emoji: '🧩',
        title: 'Daily Pulse',
        subtitle: pulseStatus != DailyPulseStatus.waitingForPartner && pulseStatus != DailyPulseStatus.bothCompleted
            ? 'Your turn to answer'
            : pulseStatus == DailyPulseStatus.waitingForPartner
                ? 'Waiting for partner'
                : 'Check results',
        rewards: ['+20 LP', '🔥 Streak'],
        isActive: pulseStatus != DailyPulseStatus.waitingForPartner && pulseStatus != DailyPulseStatus.bothCompleted,
        onTap: () => _navigateToDailyPulse(),
      ),

      // Classic Quiz (server-centric)
      _buildQuestCard(
        emoji: '🎯',
        title: 'Classic Quiz',
        subtitle: activeQuiz != null ? 'Quiz in progress' : 'Start new session',
        rewards: ['+30 LP'],
        isActive: activeQuiz != null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuizMatchGameScreen(quizType: 'classic')),
        ),
      ),
    ];

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: quests.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) => quests[index],
      ),
    );
  }

  Widget _buildQuestCard({
    required String emoji,
    required String title,
    required String subtitle,
    required List<String> rewards,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          border: Border.all(
            color: isActive ? AppTheme.primaryBlack : AppTheme.borderLight,
            width: isActive ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: rewards.map((reward) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryBlack : AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    reward,
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppTheme.primaryWhite : AppTheme.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideQuestsCarousel() {
    // Use cached Future to prevent FutureBuilder from showing loading state
    // on every rebuild (e.g., when DailyQuests polling triggers setState)
    // The Future is only refreshed when side quest data actually changes
    return FutureBuilder<List<DailyQuest>>(
      future: _sideQuestsFuture ?? _getSideQuests(),
      builder: (context, snapshot) {
        // Only show loading on initial load, not on rebuilds
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox(
            height: 380,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle errors - show error message with retry option
        if (snapshot.hasError) {
          Logger.error('Side quests error', error: snapshot.error, service: 'home');
          return SizedBox(
            height: 380,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: BrandLoader().colors.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading side quests',
                    style: TextStyle(color: BrandLoader().colors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {}), // Trigger rebuild
                    child: const Text('Tap to retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final sideQuests = snapshot.data ?? [];

        // Handle empty state
        if (sideQuests.isEmpty) {
          return SizedBox(
            height: 380,
            child: Center(
              child: Text(
                'No side quests available',
                style: TextStyle(color: BrandLoader().colors.textSecondary),
              ),
            ),
          );
        }

        return QuestCarousel(
          quests: sideQuests,
          currentUserId: _storage.getUser()?.id,
          onQuestTap: _handleSideQuestTap,
          cardWidthPercent: 0.6, // 60% width to match Daily Quests
          showProgressBar: true,
          isLockedBuilder: _getQuestLockState,
          guidanceBuilder: _getSideQuestGuidanceState,
        );
      },
    );
  }

  /// Determine if a quest is locked based on unlock state
  ({bool isLocked, String? unlockCriteria}) _getQuestLockState(DailyQuest quest) {
    // If unlock state hasn't loaded yet, show everything as unlocked
    if (_unlockState == null) {
      return (isLocked: false, unlockCriteria: null);
    }

    // Map quest type to unlockable feature
    UnlockableFeature? feature;
    String? criteria;

    switch (quest.type) {
      case QuestType.linked:
        feature = UnlockableFeature.linked;
        criteria = 'Complete You or Me first';
        break;
      case QuestType.wordSearch:
        feature = UnlockableFeature.wordSearch;
        criteria = 'Complete crossword first';
        break;
      case QuestType.steps:
        feature = UnlockableFeature.steps;
        criteria = 'Complete Word Search first';
        break;
      default:
        // Daily quests (quiz, youOrMe) handled elsewhere
        return (isLocked: false, unlockCriteria: null);
    }

    final isLocked = !_unlockState!.isFeatureUnlocked(feature);
    return (isLocked: isLocked, unlockCriteria: isLocked ? criteria : null);
  }

  /// Determine if a daily quest should show onboarding guidance (Us 2.0 only)
  ({bool showGuidance, String? guidanceText}) _getDailyQuestGuidanceState(DailyQuest quest) {
    // If unlock state hasn't loaded yet, don't show guidance
    if (_unlockState == null) {
      return (showGuidance: false, guidanceText: null);
    }

    final user = _storage.getUser();
    final userId = user?.id;

    // Check if any quest is in "waiting for partner" state
    // If user completed but partner hasn't, suppress all guidance
    if (userId != null) {
      final allQuests = _storage.getTodayQuests().where((q) => !q.isSideQuest).toList();
      final anyWaitingForPartner = allQuests.any((q) {
        final userCompleted = q.hasUserCompleted(userId);
        final bothCompleted = q.isCompleted;
        return userCompleted && !bothCompleted;
      });
      if (anyWaitingForPartner) {
        return (showGuidance: false, guidanceText: null);
      }
    }

    // Check for pending results - show "Continue Here" on those
    final hasClassicPending = _storage.hasPendingResults('classic_quiz');
    final hasAffirmationPending = _storage.hasPendingResults('affirmation_quiz');
    final hasYouOrMePending = _storage.hasPendingResults('you_or_me');
    final anyPending = hasClassicPending || hasAffirmationPending || hasYouOrMePending;

    if (anyPending) {
      if (quest.type == QuestType.quiz && quest.formatType == 'classic' && hasClassicPending) {
        return (showGuidance: true, guidanceText: 'Continue Here');
      }
      if (quest.type == QuestType.quiz && quest.formatType == 'affirmation' && hasAffirmationPending && !hasClassicPending) {
        return (showGuidance: true, guidanceText: 'Continue Here');
      }
      if (quest.type == QuestType.youOrMe && hasYouOrMePending && !hasClassicPending && !hasAffirmationPending) {
        return (showGuidance: true, guidanceText: 'Continue Here');
      }
      // Some other quest has pending results - suppress guidance on this quest
      return (showGuidance: false, guidanceText: null);
    }

    // Use unlock state guidance target
    final target = _unlockState!.currentGuidanceTarget;
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

  /// Determine if a side quest should show onboarding guidance
  ({bool showGuidance, String? guidanceText}) _getSideQuestGuidanceState(DailyQuest quest) {
    // If unlock state hasn't loaded yet, don't show guidance
    if (_unlockState == null) {
      return (showGuidance: false, guidanceText: null);
    }

    final target = _unlockState!.currentGuidanceTarget;
    final text = _unlockState!.guidanceText;

    // Match quest type to guidance target (Linked and Word Search only)
    if (quest.type == QuestType.linked && target == GuidanceTarget.linked) {
      return (showGuidance: true, guidanceText: text);
    }
    if (quest.type == QuestType.wordSearch && target == GuidanceTarget.wordSearch) {
      return (showGuidance: true, guidanceText: text);
    }

    // Steps is skipped in guidance chain
    return (showGuidance: false, guidanceText: null);
  }

  /// Get cooldown status for a quest based on its type
  /// Returns null if quest type doesn't have cooldowns or if not on cooldown
  CooldownStatus? _getCooldownStatus(DailyQuest quest) {
    // Map quest type to activity type
    ActivityType? activityType;

    switch (quest.type) {
      case QuestType.quiz:
        activityType = quest.formatType == 'affirmation'
            ? ActivityType.affirmationQuiz
            : ActivityType.classicQuiz;
        break;
      case QuestType.youOrMe:
        activityType = ActivityType.youOrMe;
        break;
      case QuestType.linked:
        activityType = ActivityType.linked;
        break;
      case QuestType.wordSearch:
        activityType = ActivityType.wordsearch;
        break;
      default:
        // Steps and other types don't have cooldowns
        return null;
    }

    // Get cooldown status from MagnetService
    return _magnetService.getCooldownStatus(activityType);
  }

  /// Get a short tier name for display in the connection bar
  /// e.g., "Cozy Cabin" -> "Cabin", "Beach Villa" -> "Beach"
  String _getShortTierName(String fullName) {
    // Extract just the first word for most cases
    final words = fullName.split(' ');
    if (words.length >= 2) {
      // For "Cozy Cabin" -> "Cabin", "Beach Villa" -> "Beach", etc.
      // Use the more descriptive word (usually the second for location-based names)
      if (words[0] == 'Cozy' || words[0] == 'Beach' || words[0] == 'Yacht' || words[0] == 'Mountain' || words[0] == 'Castle') {
        return words[0];
      }
      return words[1];
    }
    return fullName;
  }

  void _showPokeBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PokeBottomSheet(),
    );
  }

  void _showRemindBottomSheet() {
    RemindBottomSheet.show(context);
  }

  void _showLeaderboardBottomSheet() {
    LeaderboardBottomSheet.show(context);
  }

  void _navigateToDailyPulse() {
    final pulse = _pulseService.getTodaysPulse();
    final question = _pulseService.getTodaysQuestion();
    final isSubject = _pulseService.isUserSubjectToday();
    final partner = _storage.getPartner();
    final currentStreak = _pulseService.getCurrentStreak();

    final subjectAnswer = pulse.answers?[pulse.subjectUserId];
    int? predictorGuess;
    if (pulse.answers != null) {
      final keys = pulse.answers!.keys.where((id) => id != pulse.subjectUserId);
      if (keys.isNotEmpty) {
        predictorGuess = pulse.answers![keys.first];
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyPulseScreen(
          question: question,
          isSubject: isSubject,
          partnerName: partner?.name ?? 'Partner',
          subjectAnswer: subjectAnswer,
          predictorGuess: predictorGuess,
          currentStreak: currentStreak,
          bothCompleted: pulse.bothAnswered,
        ),
      ),
    );
  }

  /// Handle side quest tap - navigate to appropriate screen or show "Coming Soon"
  Future<void> _handleSideQuestTap(DailyQuest quest) async {
    // Check if this is a placeholder card
    if (quest.contentId.startsWith('placeholder_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coming Soon!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Handle real quest navigation based on type
    switch (quest.type) {
      case QuestType.steps:
        await _handleStepsQuestTap();
        break;
      case QuestType.linked:
        // Check for pending results (user killed app while waiting for partner to complete)
        final linkedPendingMatchId = _storage.getPendingResultsMatchId('linked');
        if (linkedPendingMatchId != null) {
          try {
            // Poll to see if match is completed
            final state = await LinkedService().pollMatchState(linkedPendingMatchId);
            if (mounted && state.match.status == 'completed') {
              final user = _storage.getUser();
              final partner = _storage.getPartner();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LinkedCompletionScreen(
                    match: state.match,
                    currentUserId: user?.id ?? '',
                    partnerName: partner?.name,
                  ),
                ),
              );
              if (mounted) {
                _refreshSideQuestsFuture();
                setState(() {});
              }
              return;
            } else {
              // Match exists but not completed - clear stale flag
              await _storage.clearPendingResultsMatchId('linked');
            }
          } catch (e) {
            // If polling fails, clear the flag and proceed normally
            Logger.error('Failed to poll linked match for pending results: $e');
            await _storage.clearPendingResultsMatchId('linked');
          }
        }
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LinkedIntroScreen()),
        );
        // Refresh state after returning to show updated quest status
        if (mounted) {
          _refreshSideQuestsFuture();
          setState(() {});
        }
        break;
      case QuestType.wordSearch:
        // Check for pending results (user killed app while waiting for partner to complete)
        final wsPendingMatchId = _storage.getPendingResultsMatchId('word_search');
        if (wsPendingMatchId != null) {
          try {
            // Poll to see if match is completed
            final state = await WordSearchService().pollMatchState(wsPendingMatchId);
            if (mounted && state.match.status == 'completed') {
              final user = _storage.getUser();
              final partner = _storage.getPartner();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WordSearchCompletionScreen(
                    match: state.match,
                    currentUserId: user?.id ?? '',
                    partnerName: partner?.name,
                  ),
                ),
              );
              if (mounted) {
                _refreshSideQuestsFuture();
                setState(() {});
              }
              return;
            } else {
              // Match exists but not completed - clear stale flag
              await _storage.clearPendingResultsMatchId('word_search');
            }
          } catch (e) {
            // If polling fails, clear the flag and proceed normally
            Logger.error('Failed to poll word search match for pending results: $e');
            await _storage.clearPendingResultsMatchId('word_search');
          }
        }
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WordSearchIntroScreen()),
        );
        // Refresh state after returning to show updated quest status
        if (mounted) {
          _refreshSideQuestsFuture();
          setState(() {});
        }
        break;
      default:
        // Fallback for unknown quest types
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quest type ${quest.type.name} not yet implemented'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  /// Handle Steps Together card tap - navigate based on connection state
  Future<void> _handleStepsQuestTap() async {
    final stepsService = StepsFeatureService();
    final state = stepsService.getCurrentState();

    Widget targetScreen;

    switch (state) {
      case StepsFeatureState.notSupported:
        // Shouldn't reach here on iOS
        return;

      case StepsFeatureState.neitherConnected:
      case StepsFeatureState.partnerConnected:
      case StepsFeatureState.waitingForPartner:
        // Show intro screen for connection states
        targetScreen = const StepsIntroScreen();
        break;

      case StepsFeatureState.tracking:
      case StepsFeatureState.claimReady:
        // Show counter screen for tracking/claim states
        targetScreen = const StepsCounterScreen();
        break;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetScreen),
    );

    // Refresh state after returning
    if (mounted) {
      _refreshSideQuestsFuture();
      setState(() {});
    }
  }

  /// Build list of side quests (Steps, Linked, Word Search) + placeholders
  Future<List<DailyQuest>> _getSideQuests() async {
    final quests = <DailyQuest>[];
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Get user/partner for completion tracking
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    // Linked - FIRST card (arroword puzzle game)
    final activeLinkedMatch = _storage.getActiveLinkedMatch();

    String linkedDesc;
    String linkedContentId;
    if (activeLinkedMatch != null && activeLinkedMatch.status == 'active') {
      linkedDesc = '${activeLinkedMatch.progressPercent}% complete';
      linkedContentId = activeLinkedMatch.matchId;
    } else {
      linkedDesc = 'Start new puzzle';
      linkedContentId = 'new_linked';
    }

    final linkedQuest = DailyQuest.create(
      dateKey: dateKey,
      type: QuestType.linked,
      contentId: linkedContentId,
      isSideQuest: true,
      imagePath: null,
      description: linkedDesc,
    );

    // Set completion state based on match status
    // Use partner.id (UUID) if available, fallback to pushToken for backward compatibility
    if (user != null && partner != null && activeLinkedMatch != null) {
      final partnerKey = partner.id.isNotEmpty ? partner.id : partner.pushToken;
      if (activeLinkedMatch.status == 'completed') {
        linkedQuest.status = 'completed';
        linkedQuest.userCompletions = {
          user.id: true,
          partnerKey: true,
        };
        // Set pending results flag if not already set
        // This catches the case where partner made the final move and we detected via polling
        if (!_storage.hasPendingResults('linked')) {
          await _storage.setPendingResultsMatchId('linked', activeLinkedMatch.matchId);
        }
      } else if (activeLinkedMatch.currentTurnUserId != user.id) {
        // It's partner's turn - show partner badge
        linkedQuest.userCompletions = {
          user.id: true,
          partnerKey: false,
        };
      }
    }

    quests.add(linkedQuest);

    // Word Search - SECOND card (turn-based word search puzzle)
    final activeWordSearchMatch = _wordSearchService.getCachedActiveMatch();

    String wordSearchDesc;
    String wordSearchContentId;
    if (activeWordSearchMatch != null && activeWordSearchMatch.status == 'active') {
      wordSearchDesc = '${activeWordSearchMatch.progressPercent}% complete';
      wordSearchContentId = activeWordSearchMatch.matchId;
    } else {
      wordSearchDesc = 'Start new puzzle';
      wordSearchContentId = 'new_word_search';
    }

    final wordSearchQuest = DailyQuest.create(
      dateKey: dateKey,
      type: QuestType.wordSearch,
      contentId: wordSearchContentId,
      isSideQuest: true,
      imagePath: null,
      description: wordSearchDesc,
    );

    // Set completion state based on match status
    // Use partner.id (UUID) if available, fallback to pushToken for backward compatibility
    if (user != null && partner != null && activeWordSearchMatch != null) {
      final partnerKey = partner.id.isNotEmpty ? partner.id : partner.pushToken;
      if (activeWordSearchMatch.status == 'completed') {
        wordSearchQuest.status = 'completed';
        wordSearchQuest.userCompletions = {
          user.id: true,
          partnerKey: true,
        };
        // Set pending results flag if not already set
        // This catches the case where partner made the final move and we detected via polling
        if (!_storage.hasPendingResults('word_search')) {
          await _storage.setPendingResultsMatchId('word_search', activeWordSearchMatch.matchId);
        }
      } else if (activeWordSearchMatch.currentTurnUserId != user.id) {
        // It's partner's turn - show partner badge
        wordSearchQuest.userCompletions = {
          user.id: true,
          partnerKey: false,
        };
      }
    }

    quests.add(wordSearchQuest);

    // Steps Together - THIRD card (iOS only, skip on web)
    if (!kIsWeb && Platform.isIOS) {
      final stepsService = StepsFeatureService();

      // Refresh partner status from server to ensure we have latest connection state
      await stepsService.refreshPartnerStatus();

      final stepsState = stepsService.getCurrentState();

      // Only add card if supported (not notSupported state)
      if (stepsState != StepsFeatureState.notSupported) {
        // Determine description and content ID based on state
        String stepsDesc;
        String stepsContentId;

        switch (stepsState) {
          case StepsFeatureState.notSupported:
            // Won't reach here due to outer check
            stepsDesc = '';
            stepsContentId = '';
            break;
          case StepsFeatureState.neitherConnected:
            stepsDesc = 'Connect HealthKit';
            stepsContentId = 'steps_connect';
            break;
          case StepsFeatureState.partnerConnected:
            stepsDesc = 'Partner is ready!';
            stepsContentId = 'steps_connect';
            break;
          case StepsFeatureState.waitingForPartner:
            stepsDesc = 'Waiting for partner';
            stepsContentId = 'steps_waiting';
            break;
          case StepsFeatureState.tracking:
            final projected = stepsService.getProjectedLP();
            stepsDesc = projected > 0 ? 'Tomorrow: +$projected LP' : 'Keep walking!';
            stepsContentId = 'steps_tracking';
            break;
          case StepsFeatureState.claimReady:
            final earnedLP = stepsService.getClaimableRewardAmount();
            stepsDesc = 'Claim +$earnedLP LP';
            stepsContentId = 'steps_claim';
            break;
        }

        final stepsQuest = DailyQuest.create(
          dateKey: dateKey,
          type: QuestType.steps,
          contentId: stepsContentId,
          isSideQuest: true,
          imagePath: null,
          description: stepsDesc,
          quizName: 'Steps Together',
        );

        quests.add(stepsQuest);
      }
    }

    // Add placeholder cards to fill remaining slots (minimum 2 total cards)
    final placeholders = [
      {'title': 'Would You', 'desc': 'Coming Soon'},
      {'title': 'Challenge', 'desc': 'Daily'},
      {'title': 'Daily Dare', 'desc': 'Soon'},
    ];

    int currentCount = quests.length;
    int placeholdersNeeded = currentCount < 2 ? 2 - currentCount : 0;

    for (int i = 0; i < placeholdersNeeded && i < placeholders.length; i++) {
      final placeholder = placeholders[i];
      quests.add(DailyQuest.create(
        dateKey: dateKey,
        type: QuestType.quiz, // Placeholder type (will be ignored on tap)
        contentId: 'placeholder_${placeholder['title']}',
        isSideQuest: true,
        imagePath: null,
        description: placeholder['desc'] as String,
        quizName: placeholder['title'] as String, // Store title in quizName for QuestCard display
      ));
    }

    return quests;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning!';
    } else if (hour < 18) {
      return 'Good Afternoon!';
    } else {
      return 'Good Evening!';
    }
  }

  /// New simplified header matching carousel design
  Widget _buildSimplifiedHeader() {
    final daysTogether = _calculateDaysTogether();
    final lovePoints = _arenaService.getLovePoints();
    final partner = _storage.getPartner();

    return Container(
      color: AppTheme.primaryWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title section - index 0 in stagger sequence
          HomeStaggeredEntrance(
            index: 0,
            trackingKey: 'home_header_title',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  // "LIIA" title with debug menu access
                  GestureDetector(
                    onDoubleTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => const DebugMenu(),
                      );
                    },
                    child: Text(
                      'LIIA',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                        color: BrandLoader().colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // "Day Forty-Two" subtitle
                  Text(
                    'Day ${NumberFormatter.toWords(daysTogether)}',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 14,
                      color: const Color(0xFF666666),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stats section - index 1 in stagger sequence
          HomeStaggeredEntrance(
            index: 1,
            trackingKey: 'home_stats_section',
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: BrandLoader().colors.primary, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    _buildStatRow('PARTY', 'You & ${partner?.name ?? "Partner"}'),
                    const SizedBox(height: 16),
                    _buildStatRow('LOVE POINTS', lovePoints.toString()),
                    const SizedBox(height: 16),
                    _buildProgressBar(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate days together from pairedAt date
  int _calculateDaysTogether() {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user != null && partner != null) {
      return DateTime.now().difference(partner.pairedAt).inDays + 1;
    }
    return 1;
  }

  /// Build stat row with label and value
  /// LP counter gets special pulse animation treatment
  Widget _buildStatRow(String label, String value) {
    final isLPRow = label == 'LOVE POINTS';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.headlineFont.copyWith(
            fontSize: 14,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        // LP counter gets animated pulse effect
        if (isLPRow)
          AnimatedBuilder(
            animation: _lpPulseController,
            builder: (context, child) {
              // Subtle scale pulse (1.0 -> 1.05 -> 1.0)
              final pulseValue = Curves.easeOutBack.transform(_lpPulseController.value);
              final scale = 1.0 + (0.05 * (1.0 - (pulseValue - 0.5).abs() * 2).clamp(0.0, 1.0));

              return Transform.scale(
                scale: _lpPulseController.isAnimating ? scale : 1.0,
                child: Text(
                  value,
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              );
            },
          )
        else
          Text(
            value,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
      ],
    );
  }

  /// Build horizontal progress bar for LP to next arena
  Widget _buildProgressBar() {
    final progress = _arenaService.getCurrentProgress();

    return Container(
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFFE0E0E0), // Gray background showing full length
      ),
      child: Align(
        alignment: Alignment.centerLeft, // Ensure black bar is left-aligned
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: BrandLoader().colors.primary, // Progress bar fill
            ),
          ),
        ),
      ),
    );
  }

  /// Build styled action button with optional dot indicator
  Widget _buildActionButton(String label, bool showDot, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SoundService().tap();
        HapticService().tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          border: Border.all(color: AppTheme.primaryBlack, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              offset: const Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              label,
              style: AppTheme.headlineFont.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppTheme.primaryBlack,
              ),
            ),
            if (showDot)
              Positioned(
                top: -4,
                right: -4,
                child: _buildDotIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  /// Build pulsing dot indicator
  Widget _buildDotIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final value = _pulseController.value;
        final scale = 1.0 + (0.2 * value);
        final opacity = 1.0 - (0.2 * value);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlack,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryWhite, width: 2),
              ),
            ),
          ),
        );
      },
    );
  }

}
