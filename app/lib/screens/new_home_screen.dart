import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../utils/logger.dart';
import '../utils/number_formatter.dart';
import '../services/storage_service.dart';
import '../services/arena_service.dart';
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
import '../animations/animation_config.dart';
import '../theme/app_theme.dart';
import '../widgets/poke_bottom_sheet.dart';
import '../widgets/remind_bottom_sheet.dart';
import '../widgets/daily_pulse_widget.dart';
import '../widgets/daily_quests_widget.dart';
import '../widgets/quest_carousel.dart';
import '../widgets/debug/debug_menu.dart';
import '../widgets/leaderboard_bottom_sheet.dart';
import '../models/daily_quest.dart';
import 'daily_pulse_screen.dart';
import 'linked_game_screen.dart';
import 'word_search_game_screen.dart';
import 'quiz_match_game_screen.dart';
import 'inbox_screen.dart';
import 'steps_intro_screen.dart';
import 'steps_counter_screen.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> with TickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();
  final DailyPulseService _pulseService = DailyPulseService();
  final WordSearchService _wordSearchService = WordSearchService();
  final LinkedService _linkedService = LinkedService();
  final QuizService _quizService = QuizService();
  final HomePollingService _pollingService = HomePollingService();

  bool _isRefreshing = false;
  DateTime? _lastSyncTime;
  late AnimationController _pulseController;
  late AnimationController _lpPulseController;
  int _lastLPValue = 0;

  // Cached side quests Future to prevent FutureBuilder from rebuilding on every setState
  // Without this, the carousel blinks every time any setState is called (e.g., from DailyQuests polling)
  Future<List<DailyQuest>>? _sideQuestsFuture;

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

    // Fetch LP from server on load to ensure sync
    _syncLPFromServer();

    // Sync daily quests on load (handles returning users after reinstall)
    _syncDailyQuestsIfNeeded();

    // Subscribe to unified polling service for side quest updates
    _pollingService.subscribe();
    _pollingService.subscribeToTopic('sideQuests', _onSideQuestUpdate);

    // Initialize cached Future on first load
    _refreshSideQuestsFuture();
  }

  /// Called when HomePollingService detects side quest updates (Linked/Word Search turn changes)
  void _onSideQuestUpdate() {
    if (mounted) {
      Logger.debug('Side quest update from polling service', service: 'home');
      _refreshSideQuestsFuture();
      setState(() {});
    }
  }

  /// Fetch LP from server on home screen load
  /// This ensures LP is synced even if the user hasn't played a game this session
  Future<void> _syncLPFromServer() async {
    try {
      await LovePointService.fetchAndSyncFromServer();
      // Update stored value after sync
      if (mounted) {
        final newLP = _arenaService.getLovePoints();
        if (newLP != _lastLPValue) {
          _lastLPValue = newLP;
          setState(() {});
        }
      }
    } catch (e) {
      Logger.error('Failed to sync LP on home screen load', error: e, service: 'home');
    }
  }

  /// Sync daily quests from server if none exist locally
  /// This handles the case of returning users after reinstall
  Future<void> _syncDailyQuestsIfNeeded() async {
    // Check if quests already exist locally (fast path - no network call)
    final existingQuests = _storage.getTodayQuests();
    if (existingQuests.isNotEmpty) {
      Logger.debug('Quest sync skipped - ${existingQuests.length} quests already exist', service: 'home');
      return;
    }

    // No local quests - use centralized initialization service
    final initService = QuestInitializationService();
    final result = await initService.ensureQuestsInitialized();

    if (result.isSuccess && result.wasNewlyInitialized && mounted) {
      Logger.success('Quests restored for returning user: ${result.questCount} quests', service: 'home');
      setState(() {}); // Trigger rebuild to show quests
    } else if (!result.isSuccess) {
      Logger.error('Quest init failed: ${result.errorMessage}', service: 'home');
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
    _pollingService.unsubscribeFromTopic('sideQuests', _onSideQuestUpdate);
    _pollingService.unsubscribe();
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
    return Scaffold(
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
    );
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
        // Daily Quests
        DailyQuestsWidget(key: ValueKey(_storage.getTodayQuests().length)),

        const SizedBox(height: 10),

        // Side Quests section header with action buttons
        Padding(
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
        const SizedBox(height: 20),

        // Side quests horizontal carousel
        _buildSideQuestsCarousel(),

        const SizedBox(height: 16),

        // Version number for debugging hot reload
        Center(
          child: Text(
            'v1.0.63',
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

      // Couple Quiz (server-centric)
      _buildQuestCard(
        emoji: '🎯',
        title: 'Couple Quiz',
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
        );
      },
    );
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
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LinkedGameScreen()),
        );
        // Refresh state after returning to show updated quest status
        if (mounted) {
          _refreshSideQuestsFuture();
          setState(() {});
        }
        break;
      case QuestType.wordSearch:
        await Navigator.push(
          context,
          // Use PageRouteBuilder to disable iOS swipe-to-go-back gesture
          // Word Search needs full left edge for selecting leftmost column letters
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const WordSearchGameScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
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

    // Steps Together - FIRST card (iOS only, skip on web)
    if (!kIsWeb && Platform.isIOS) {
      final stepsService = StepsFeatureService();
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

    // Linked - SECOND card (arroword puzzle game)
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
      } else if (activeLinkedMatch.currentTurnUserId != user.id) {
        // It's partner's turn - show partner badge
        linkedQuest.userCompletions = {
          user.id: true,
          partnerKey: false,
        };
      }
    }

    quests.add(linkedQuest);

    // Word Search - always show SECOND (turn-based word search puzzle)
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
      } else if (activeWordSearchMatch.currentTurnUserId != user.id) {
        // It's partner's turn - show partner badge
        wordSearchQuest.userCompletions = {
          user.id: true,
          partnerKey: false,
        };
      }
    }

    quests.add(wordSearchQuest);

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
          // Title section (no border needed - border is on stats section below)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                // "LOVE QUEST" title with debug menu access
                GestureDetector(
                  onDoubleTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const DebugMenu(),
                    );
                  },
                  child: Text(
                    'LOVE QUEST',
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

          // Stats section with top border (full width, edge-to-edge)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: BrandLoader().colors.primary, width: 2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  // Stats rows
                  _buildStatRow('PARTY', 'You & ${partner?.name ?? "Partner"}'),
                  const SizedBox(height: 16),
                  _buildStatRow('LOVE POINTS', lovePoints.toString()),
                  const SizedBox(height: 16),

                  // Progress bar
                  _buildProgressBar(),
                ],
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
