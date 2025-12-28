import 'package:flutter/material.dart';
import 'package:togetherremind/models/activity_item.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/services/activity_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/reminder_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/widgets/participant_avatars.dart';
import 'package:togetherremind/widgets/brand/brand_widget_factory.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
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

  String _getHeaderSubtitle() {
    switch (_filter) {
      case 'yourTurn':
        return 'Things that need your attention';
      case 'completed':
        return 'Your completed activities';
      case 'unread':
        return 'Unread activities';
      case 'all':
      default:
        return 'Track all your activities together';
    }
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

      case ActivityType.question:
        // Daily questions are handled via home screen widget
        // Navigate back to home screen (user can access from there)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return to home screen to answer the daily question'),
            duration: Duration(seconds: 2),
          ),
        );
        break;

      case ActivityType.affirmation:
      case ActivityType.quiz:
        // Daily quests are the entry point for quizzes now - direct user to home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return to home screen to complete this quest'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {});
        break;

      case ActivityType.wouldYouRather:
        // Would You Rather is no longer available as standalone
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return to home screen to complete this quest'),
            duration: Duration(seconds: 2),
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

    // Us 2.0 uses its own gradient background
    final isUs2 = BrandWidgetFactory.isUs2;
    final bgGradient = isUs2
        ? BrandLoader().colors.backgroundGradient
        : AppTheme.backgroundGradient;

    return Container(
      decoration: BoxDecoration(
        gradient: bgGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inbox',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getHeaderSubtitle(),
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterTab(
                          label: 'All',
                          isSelected: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterTab(
                          label: 'Your Turn',
                          isSelected: _filter == 'yourTurn',
                          onTap: () => setState(() => _filter = 'yourTurn'),
                        ),
                        const SizedBox(width: 8),
                        _FilterTab(
                          label: 'Completed',
                          isSelected: _filter == 'completed',
                          onTap: () => setState(() => _filter = 'completed'),
                        ),
                        const SizedBox(width: 8),
                        _FilterTab(
                          label: 'Pokes',
                          isSelected: _filter == 'pokes',
                          onTap: () => setState(() => _filter = 'pokes'),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlack : AppTheme.primaryWhite,
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlack : const Color(0xFFE0E0E0),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 14,
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

  Color _getStatusBadgeColor() {
    switch (activity.status) {
      case ActivityStatus.yourTurn:
        return const Color(0xFFE0E0E0); // Gray background
      case ActivityStatus.waitingForPartner:
        return const Color(0xFFE0E0E0); // Gray background
      case ActivityStatus.completed:
        return AppTheme.primaryBlack; // Black background
      case ActivityStatus.mutual:
        return AppTheme.primaryBlack;
      case ActivityStatus.expired:
        return BrandLoader().colors.error;
      case ActivityStatus.pending:
        return AppTheme.textSecondary;
    }
  }

  Color _getStatusBadgeTextColor() {
    switch (activity.status) {
      case ActivityStatus.yourTurn:
        return AppTheme.primaryBlack; // Black text on gray
      case ActivityStatus.waitingForPartner:
        return AppTheme.primaryBlack; // Black text on gray
      case ActivityStatus.completed:
        return AppTheme.primaryWhite; // White text on black
      case ActivityStatus.mutual:
        return AppTheme.primaryWhite;
      case ActivityStatus.expired:
        return BrandLoader().colors.textOnPrimary;
      case ActivityStatus.pending:
        return AppTheme.primaryWhite;
    }
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    final diff = now.difference(activity.timestamp);

    if (diff.inDays == 0) {
      return 'Today ${DateFormat('h:mm a').format(activity.timestamp)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM d').format(activity.timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          border: Border.all(
            color: const Color(0xFFF0F0F0),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type badge and timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlack,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activity.typeLabel.toUpperCase(),
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryWhite,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  _getFormattedTime(),
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 13,
                    color: const Color(0xFFAAAAAA),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title (Playfair Display)
            Text(
              activity.title,
              style: AppTheme.headlineFont.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              activity.subtitle,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),

            // Footer: Status badge (left) and avatars (right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status badge
                if (activity.statusBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusBadgeColor(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activity.statusBadge!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusBadgeTextColor(),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                // Participant avatars
                ParticipantAvatars(
                  participants: activity.participants,
                  size: 32,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
