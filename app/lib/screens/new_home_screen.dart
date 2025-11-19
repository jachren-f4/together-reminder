import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../utils/number_formatter.dart';
import '../services/storage_service.dart';
import '../services/arena_service.dart';
import '../services/daily_pulse_service.dart';
import '../services/ladder_service.dart';
import '../services/memory_flip_service.dart';
import '../services/quiz_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../theme/app_theme.dart';
import '../widgets/poke_bottom_sheet.dart';
import '../widgets/remind_bottom_sheet.dart';
import '../widgets/daily_pulse_widget.dart';
import '../widgets/daily_quests_widget.dart';
import '../widgets/quest_carousel.dart';
import '../widgets/debug/debug_menu.dart';
import '../models/daily_quest.dart';
import 'daily_pulse_screen.dart';
import 'word_ladder_hub_screen.dart';
import 'memory_flip_game_screen.dart';
import 'quiz_intro_screen.dart';
import 'inbox_screen.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();
  final DailyPulseService _pulseService = DailyPulseService();
  final LadderService _ladderService = LadderService();
  final MemoryFlipService _memoryService = MemoryFlipService();
  final QuizService _quizService = QuizService();

  bool _isRefreshing = false;
  DateTime? _lastSyncTime;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Register LP change callback for real-time counter updates
    _setupLPChangeCallback();
  }

  /// Setup callback for real-time LP counter updates
  /// Matches pattern used by quest cards (daily_quests_widget.dart)
  void _setupLPChangeCallback() {
    // Register callback WITHOUT creating a new listener
    // (Listener already started in main.dart - don't create duplicate!)
    LovePointService.setLPChangeCallback(() {
      if (mounted) {
        setState(() {
          // Trigger rebuild to update LP counter
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user != null && partner != null) {
        // Sync quests from Firebase
        final questService = DailyQuestService(storage: _storage);
        final syncService = QuestSyncService(
          storage: _storage,
        );

        await syncService.syncTodayQuests(
          currentUserId: user.id,
          partnerUserId: partner.pushToken,
        );

        setState(() {
          _lastSyncTime = DateTime.now();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updated from Firebase!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Error refreshing', error: e, service: 'home');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: $e'),
            backgroundColor: Colors.red,
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
        const DailyQuestsWidget(),

        const SizedBox(height: 24),

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
              Row(
                children: [
                  _buildActionButton('POKE', false, _showPokeBottomSheet),
                  const SizedBox(width: 10),
                  _buildActionButton('REMIND', false, _showRemindBottomSheet),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Side quests horizontal carousel
        _buildSideQuestsCarousel(),

        const SizedBox(height: 40),

        // Version number for debugging hot reload
        Center(
          child: Text(
            'v1.0.12',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade400,
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMainQuestsCarousel() {
    final pulseStatus = _pulseService.getDailyPulseStatus();
    final activeLadders = _ladderService.getActiveLadders();
    final myTurnLadders = activeLadders.where((l) => _ladderService.isMyTurn(l)).length;
    final activePuzzle = _storage.getActivePuzzle();
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

      // Word Ladder
      _buildQuestCard(
        emoji: '🪜',
        title: 'Word Ladder Duet',
        subtitle: myTurnLadders > 0
            ? '$myTurnLadders puzzle${myTurnLadders == 1 ? "" : "s"} waiting'
            : activeLadders.isEmpty
                ? 'Start new puzzle'
                : '${activeLadders.length} active',
        rewards: ['+15 LP'],
        isActive: myTurnLadders > 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WordLadderHubScreen()),
        ),
      ),

      // Memory Flip
      _buildQuestCard(
        emoji: '🃏',
        title: 'Memory Flip Co-op',
        subtitle: activePuzzle != null
            ? '${activePuzzle.matchedPairs}/${activePuzzle.totalPairs} pairs found'
            : 'Start new puzzle',
        rewards: ['+40 LP'],
        isActive: activePuzzle != null && activePuzzle.matchedPairs < activePuzzle.totalPairs,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MemoryFlipGameScreen()),
        ),
      ),

      // Couple Quiz
      _buildQuestCard(
        emoji: '🎯',
        title: 'Couple Quiz',
        subtitle: activeQuiz != null ? 'Quiz in progress' : 'Start new session',
        rewards: ['+30 LP'],
        isActive: activeQuiz != null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuizIntroScreen()),
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
    return FutureBuilder<List<DailyQuest>>(
      future: _getSideQuests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sideQuests = snapshot.data ?? [];

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RemindBottomSheet(),
    );
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
      case QuestType.wordLadder:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WordLadderHubScreen()),
        );
        // Refresh state after returning to show updated quest status
        if (mounted) setState(() {});
        break;
      case QuestType.memoryFlip:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MemoryFlipGameScreen()),
        );
        // Refresh state after returning to show updated quest status
        if (mounted) setState(() {});
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

  /// Build list of side quests (Word Ladder, Memory Flip always shown) + placeholders
  Future<List<DailyQuest>> _getSideQuests() async {
    final quests = <DailyQuest>[];
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Get user/partner for completion tracking
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    // Word Ladder - always show (users can start new sessions)
    final activeLadders = _ladderService.getActiveLadders();
    final myTurnLadders = activeLadders.where((l) => _ladderService.isMyTurn(l));

    String wordLadderDesc;
    String wordLadderContentId;
    if (myTurnLadders.isNotEmpty) {
      wordLadderDesc = '${myTurnLadders.length} puzzle${myTurnLadders.length == 1 ? "" : "s"} waiting';
      wordLadderContentId = myTurnLadders.first.id;
    } else {
      wordLadderDesc = 'Start new puzzle';
      wordLadderContentId = 'new_word_ladder';
    }

    final wordLadderQuest = DailyQuest.create(
      dateKey: dateKey,
      type: QuestType.wordLadder,
      contentId: wordLadderContentId,
      isSideQuest: true,
      imagePath: null, // No image yet for Word Ladder
      description: wordLadderDesc,
    );

    // Set completion state based on turn tracking
    if (user != null && partner != null && activeLadders.isNotEmpty) {
      // Check first active ladder for turn state
      final firstLadder = activeLadders.first;

      if (firstLadder.status == 'completed') {
        // Ladder is completed - show COMPLETED badge
        wordLadderQuest.status = 'completed';
        wordLadderQuest.userCompletions = {
          user.id: true,
          partner.pushToken: true,
        };
      } else if (!_ladderService.isMyTurn(firstLadder)) {
        // It's partner's turn - mark user as completed to show partner badge
        wordLadderQuest.userCompletions = {
          user.id: true,
          partner.pushToken: false,
        };
      }
      // Otherwise leave as default (shows "YOUR TURN" badge)
    }

    quests.add(wordLadderQuest);

    // Memory Flip - always show (users can start new sessions)
    final activePuzzle = _storage.getActivePuzzle();

    String memoryFlipDesc;
    String memoryFlipContentId;
    if (activePuzzle != null && activePuzzle.matchedPairs < activePuzzle.totalPairs) {
      memoryFlipDesc = '${activePuzzle.matchedPairs}/${activePuzzle.totalPairs} pairs found';
      memoryFlipContentId = activePuzzle.id;
    } else {
      memoryFlipDesc = 'Start new puzzle';
      memoryFlipContentId = 'new_memory_flip';
    }

    final memoryFlipQuest = DailyQuest.create(
      dateKey: dateKey,
      type: QuestType.memoryFlip,
      contentId: memoryFlipContentId,
      isSideQuest: true,
      imagePath: null, // No image yet for Memory Flip
      description: memoryFlipDesc,
    );

    // Check flip allowance and mark user as "completed" if out of flips
    if (user != null && partner != null && activePuzzle != null && activePuzzle.status != 'completed') {
      final allowance = await _memoryService.getFlipAllowance(user.id);
      if (allowance != null && allowance.flipsRemaining == 0) {
        // Mark user as "completed" to trigger OUT OF FLIPS badge
        memoryFlipQuest.userCompletions = {
          user.id: true,
          partner.pushToken: false,
        };
      }
    }

    // Set completion state if puzzle is completed
    if (user != null && partner != null && activePuzzle != null && activePuzzle.status == 'completed') {
      memoryFlipQuest.status = 'completed';
      memoryFlipQuest.userCompletions = {
        user.id: true,
        partner.pushToken: true,
      };
    }

    quests.add(memoryFlipQuest);

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
                      color: Colors.black,
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
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black, width: 2),
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
  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.headlineFont.copyWith( // Use serif font like HTML mockup
            fontSize: 14,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        Text(
          value,
          style: AppTheme.headlineFont.copyWith( // Use serif font (Playfair Display) like HTML mockup
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
            decoration: const BoxDecoration(
              color: Colors.black, // Black progress bar
            ),
          ),
        ),
      ),
    );
  }

  /// Build styled action button with optional dot indicator
  Widget _buildActionButton(String label, bool showDot, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
