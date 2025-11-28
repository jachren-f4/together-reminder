import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../utils/logger.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/daily_pulse_service.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../widgets/daily_pulse_widget.dart';
import 'quiz_intro_screen.dart';
import 'quiz_results_screen.dart';
import 'daily_pulse_screen.dart';
import 'daily_pulse_results_screen.dart';
import 'speed_round_intro_screen.dart';
import 'would_you_rather_intro_screen.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  final DailyPulseService _dailyPulseService = DailyPulseService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedSessions = _quizService.getCompletedSessions();
    final activeSession = _quizService.getActiveSession();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Strengthen Your Bond',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete activities to earn Love Points and unlock badges',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // Daily Pulse Widget (placeholder for now - will implement backend later)
              _buildDailyPulseSection(theme),

              const SizedBox(height: 24),

              // Quiz formats section header
              Text(
                'Quiz Formats',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Choose your favorite way to test your connection',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              // Active quiz notification (if any)
              if (activeSession != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.warning,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: BrandLoader().colors.warning.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: BrandLoader().colors.textOnPrimary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Quiz in Progress',
                            style: TextStyle(
                              color: BrandLoader().colors.textOnPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You have an active quiz waiting!',
                        style: TextStyle(color: BrandLoader().colors.textOnPrimary),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QuizIntroScreen(),
                            ),
                          ).then((_) => setState(() {}));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandLoader().colors.surface,
                          foregroundColor: BrandLoader().colors.warning,
                        ),
                        child: const Text('Continue Quiz'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Activities grid
              _buildActivityCard(
                context,
                emoji: '🧩',
                title: 'Classic Quiz',
                description: 'Test how well you know each other',
                lpRange: '10-50 LP',
                isActive: activeSession == null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuizIntroScreen(),
                    ),
                  ).then((_) => setState(() {}));
                },
                theme: theme,
              ),

              const SizedBox(height: 16),

              // Speed Round
              _buildActivityCard(
                context,
                emoji: '⚡',
                title: 'Speed Round',
                description: '10 rapid-fire questions with 10-second timer',
                lpRange: '20-40 LP + Streak Bonuses',
                isActive: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SpeedRoundIntroScreen(),
                    ),
                  ).then((_) => setState(() {}));
                },
                theme: theme,
              ),

              const SizedBox(height: 16),

              // Would You Rather
              _buildActivityCard(
                context,
                emoji: '💭',
                title: 'Would You Rather',
                description: 'Answer for yourself, predict your partner',
                lpRange: '25-50 LP + Alignment Bonuses',
                isActive: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WouldYouRatherIntroScreen(),
                    ),
                  ).then((_) => setState(() {}));
                },
                theme: theme,
              ),

              const SizedBox(height: 16),

              // Coming soon activities
              _buildActivityCard(
                context,
                emoji: '🎯',
                title: 'Timeline Challenge',
                description: 'Test your shared memories',
                lpRange: 'Coming Soon',
                isActive: false,
                onTap: null,
                theme: theme,
              ),

              const SizedBox(height: 16),

              _buildActivityCard(
                context,
                emoji: '🎯',
                title: 'Daily Challenge',
                description: 'Complete tasks together',
                lpRange: 'Coming Soon',
                isActive: false,
                onTap: null,
                theme: theme,
              ),

              const SizedBox(height: 32),

              // Quiz history
              if (completedSessions.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Quizzes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to full history
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...completedSessions.take(3).map((session) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildQuizHistoryCard(session, theme),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String description,
    required String lpRange,
    required bool isActive,
    required VoidCallback? onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: isActive ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 32,
                    color: isActive ? null : BrandLoader().colors.textSecondary,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lpRange,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow (only if active)
            if (isActive)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizHistoryCard(QuizSession session, ThemeData theme) {
    final matchPercentage = session.matchPercentage ?? 0;
    final lpEarned = session.lpEarned ?? 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizResultsScreen(session: session),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🧩', style: TextStyle(fontSize: 20)),
              ),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quiz Session',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(session.completedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$matchPercentage%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getMatchColor(matchPercentage),
                  ),
                ),
                Text(
                  '+$lpEarned LP',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Color _getMatchColor(int percentage) {
    if (percentage >= 80) return BrandLoader().colors.success;
    if (percentage >= 60) return BrandLoader().colors.info;
    if (percentage >= 40) return BrandLoader().colors.warning;
    return BrandLoader().colors.textSecondary;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hr ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Widget _buildDailyPulseSection(ThemeData theme) {
    try {
      final partner = _storage.getPartner();
      final partnerName = partner?.name ?? 'Your partner';
      final user = _storage.getUser();

      if (user == null) {
        return const SizedBox.shrink();
      }

      // Get today's pulse and question
      final pulse = _dailyPulseService.getTodaysPulse();
      final question = _dailyPulseService.getTodaysQuestion();
      final isSubject = _dailyPulseService.isUserSubjectToday();
      final currentStreak = _dailyPulseService.getCurrentStreak();
      final status = _dailyPulseService.getDailyPulseStatus();

      // Get answers if both have completed
      final subjectAnswer = pulse.answers?[pulse.subjectUserId];

      int? predictorGuess;
      if (pulse.answers != null) {
        final keys = pulse.answers!.keys.where((id) => id != pulse.subjectUserId);
        if (keys.isNotEmpty) {
          predictorGuess = pulse.answers![keys.first];
        }
      }

      return DailyPulseWidget(
        isSubject: isSubject,
        partnerName: partnerName,
        questionPreview: question.question,
        currentStreak: currentStreak,
        status: status,
        onTap: () {
          // Navigate to results if both completed, otherwise to Daily Pulse screen
          if (pulse.bothAnswered) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DailyPulseResultsScreen(
                  pulse: pulse,
                  question: question,
                  partnerName: partnerName,
                ),
              ),
            ).then((_) => setState(() {}));
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DailyPulseScreen(
                  question: question,
                  isSubject: isSubject,
                  partnerName: partnerName,
                  subjectAnswer: subjectAnswer,
                  predictorGuess: predictorGuess,
                  currentStreak: currentStreak,
                  bothCompleted: pulse.bothAnswered,
                ),
              ),
            ).then((_) => setState(() {}));
          }
        },
      );
    } catch (e) {
      Logger.error('Error loading Daily Pulse', error: e, service: 'daily_pulse');
      // Return empty widget if there's an error
      return const SizedBox.shrink();
    }
  }
}
