import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/arena_service.dart';
import '../services/daily_pulse_service.dart';
import '../services/ladder_service.dart';
import '../services/memory_flip_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import '../widgets/poke_bottom_sheet.dart';
import '../widgets/remind_bottom_sheet.dart';
import '../widgets/daily_pulse_widget.dart';
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

class _NewHomeScreenState extends State<NewHomeScreen> {
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();
  final DailyPulseService _pulseService = DailyPulseService();
  final LadderService _ladderService = LadderService();
  final MemoryFlipService _memoryService = MemoryFlipService();
  final QuizService _quizService = QuizService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopSection(),
              _buildArenaProgressSection(),
              _buildMainContent(),
            ],
          ),
        ),
      ),
    );
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
          // User row with avatars
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
                    Text(
                      _getGreeting(),
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Quests
          Text(
            'Main Quests',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildMainQuestsCarousel(),
          const SizedBox(height: 32),

          // Side Quests
          Text(
            'Side Quests',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSideQuestsGrid(),
        ],
      ),
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

  Widget _buildSideQuestsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _buildSideQuestCard(
          emoji: '📝',
          title: 'Inbox',
          subtitle: '2 new',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InboxScreen()),
          ),
        ),
        _buildSideQuestCard(
          emoji: '💭',
          title: 'Would You',
          subtitle: 'Soon',
          onTap: null, // Coming soon
        ),
        _buildSideQuestCard(
          emoji: '🎭',
          title: 'Challenge',
          subtitle: 'Daily',
          onTap: null, // Coming soon
        ),
      ],
    );
  }

  Widget _buildSideQuestCard({
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          border: Border.all(color: AppTheme.borderLight, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
}
