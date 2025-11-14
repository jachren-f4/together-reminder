import 'package:flutter/material.dart';
import 'package:togetherremind/models/activity_item.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/models/quiz_session.dart';
import 'package:togetherremind/services/activity_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/reminder_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/widgets/participant_avatars.dart';
import 'package:togetherremind/screens/quiz_intro_screen.dart';
import 'package:togetherremind/screens/quiz_results_screen.dart';
import 'package:togetherremind/screens/would_you_rather_intro_screen.dart';
import 'package:togetherremind/screens/word_ladder_hub_screen.dart';
import 'package:togetherremind/screens/memory_flip_game_screen.dart';
import 'package:intl/intl.dart';

class ActivityHubScreen extends StatefulWidget {
  const ActivityHubScreen({super.key});

  @override
  State<ActivityHubScreen> createState() => _ActivityHubScreenState();
}

class _ActivityHubScreenState extends State<ActivityHubScreen> {
  final ActivityService _activityService = ActivityService();
  final StorageService _storageService = StorageService();
  String _filter = 'all'; // 'all', 'yourTurn', 'unread', 'completed'

  @override
  void initState() {
    super.initState();
  }

  List<ActivityItem> _getFilteredActivities() {
    return _activityService.getFilteredActivities(_filter);
  }

  Future<void> _handleActivityTap(ActivityItem activity) async {
    switch (activity.type) {
      case ActivityType.reminder:
        final reminder = activity.sourceData as Reminder;
        if (reminder.type == 'received' && reminder.status == 'pending') {
          await _showReminderActions(reminder);
        }
        break;

      case ActivityType.poke:
        // Pokes are handled inline, no navigation needed
        break;

      case ActivityType.quiz:
        final session = activity.sourceData as QuizSession;
        if (session.isCompleted) {
          // Navigate to results
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizResultsScreen(session: session),
            ),
          );
        } else {
          // Navigate to intro/quiz
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const QuizIntroScreen(),
            ),
          );
        }
        setState(() {}); // Refresh after returning
        break;

      case ActivityType.wouldYouRather:
        // Navigate to Would You Rather
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WouldYouRatherIntroScreen(),
          ),
        );
        setState(() {});
        break;

      case ActivityType.wordLadder:
        // Navigate to Word Ladder Hub
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WordLadderHubScreen(),
          ),
        );
        setState(() {});
        break;

      case ActivityType.memoryFlip:
        // Navigate to Memory Flip game (uses singleton/active puzzle)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MemoryFlipGameScreen(),
          ),
        );
        setState(() {});
        break;

      case ActivityType.dailyPulse:
        // Daily Pulse navigation (if implemented)
        // For now, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily Pulse coming soon!')),
        );
        break;
    }
  }

  Future<void> _showReminderActions(Reminder reminder) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reminder'),
        content: Text(reminder.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _storageService.updateReminderStatus(
                reminder.id,
                'snoozed',
              );
              setState(() {});
              Navigator.pop(context);
            },
            child: Text('Snooze'),
          ),
          TextButton(
            onPressed: () async {
              await ReminderService.markReminderAsDone(reminder.id);
              setState(() {});
              Navigator.pop(context);
            },
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = _getFilteredActivities();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Activity Hub',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter tabs
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.06 * 255).round()),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FilterTab(
                            label: 'All',
                            isSelected: _filter == 'all',
                            onTap: () => setState(() => _filter = 'all'),
                          ),
                        ),
                        Expanded(
                          child: _FilterTab(
                            label: 'Your Turn',
                            isSelected: _filter == 'yourTurn',
                            onTap: () => setState(() => _filter = 'yourTurn'),
                          ),
                        ),
                        Expanded(
                          child: _FilterTab(
                            label: 'Unread',
                            isSelected: _filter == 'unread',
                            onTap: () => setState(() => _filter = 'unread'),
                          ),
                        ),
                        Expanded(
                          child: _FilterTab(
                            label: 'Completed',
                            isSelected: _filter == 'completed',
                            onTap: () => setState(() => _filter = 'completed'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Activities list
            Expanded(
              child: activities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📭', style: TextStyle(fontSize: 60)),
                          const SizedBox(height: 16),
                          Text(
                            _getEmptyMessage(),
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return _ActivityCard(
                          activity: activity,
                          onTap: () => _handleActivityTap(activity),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_filter) {
      case 'yourTurn':
        return 'No activities waiting for you';
      case 'unread':
        return 'No unread activities';
      case 'completed':
        return 'No completed activities yet';
      default:
        return 'No activities yet';
    }
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlack : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.primaryWhite : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityItem activity;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.activity,
    required this.onTap,
  });

  Color _getTypeColor() {
    switch (activity.type) {
      case ActivityType.quiz:
      case ActivityType.wouldYouRather:
      case ActivityType.dailyPulse:
        return const Color(0xFFF5E6D3); // Beige
      case ActivityType.wordLadder:
      case ActivityType.memoryFlip:
        return const Color(0xFFE6DDF5); // Light purple
      case ActivityType.poke:
        return const Color(0xFFFFE6F0); // Light pink
      case ActivityType.reminder:
        return const Color(0xFFE6F3FF); // Light blue
    }
  }

  Color _getStatusBadgeColor() {
    switch (activity.status) {
      case ActivityStatus.yourTurn:
        return AppTheme.accentOrange;
      case ActivityStatus.waitingForPartner:
        return AppTheme.textTertiary;
      case ActivityStatus.completed:
        return AppTheme.accentGreen;
      case ActivityStatus.mutual:
        return AppTheme.primaryBlack;
      case ActivityStatus.expired:
        return Colors.red;
      case ActivityStatus.pending:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.06 * 255).round()),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon/Emoji
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getTypeColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  activity.displayEmoji,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type label
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      activity.typeLabel,
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    activity.title,
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    activity.subtitle,
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Right side: Time and avatars
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Time
                Text(
                  timeFormat.format(activity.timestamp),
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),

                // Participant avatars
                ParticipantAvatars(
                  participants: activity.participants,
                  size: 32,
                ),

                // Status badge (if any)
                if (activity.statusBadge != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusBadgeColor().withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      activity.statusBadge!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusBadgeColor(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
