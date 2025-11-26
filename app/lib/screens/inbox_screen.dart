import 'package:flutter/material.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/poke_service.dart';
import 'package:togetherremind/services/reminder_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:intl/intl.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final StorageService _storageService = StorageService();
  String _filter = 'all'; // 'all', 'received', 'sent', 'pokes'

  List<Reminder> _getFilteredReminders() {
    final all = _storageService.getAllReminders();

    switch (_filter) {
      case 'received':
        return all.where((r) => r.type == 'received' && !r.isPoke).toList();
      case 'sent':
        return all.where((r) => r.type == 'sent' && !r.isPoke).toList();
      case 'pokes':
        return all.where((r) => r.isPoke).toList();
      default:
        return all;
    }
  }

  Future<void> _updateReminderStatus(String id, String status) async {
    if (status == 'done') {
      // Use ReminderService to mark as done (awards LP)
      await ReminderService.markReminderAsDone(id);
    } else {
      await _storageService.updateReminderStatus(id, status);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reminders = _getFilteredReminders();

    return Container(
      decoration: BoxDecoration(
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
                    'Reminders',
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
                          color: BrandLoader().colors.textPrimary.withOpacity(0.06),
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
                            label: 'Received',
                            isSelected: _filter == 'received',
                            onTap: () => setState(() => _filter = 'received'),
                          ),
                        ),
                        Expanded(
                          child: _FilterTab(
                            label: 'Sent',
                            isSelected: _filter == 'sent',
                            onTap: () => setState(() => _filter = 'sent'),
                          ),
                        ),
                        Expanded(
                          child: _FilterTab(
                            label: '💫 Pokes',
                            isSelected: _filter == 'pokes',
                            onTap: () => setState(() => _filter = 'pokes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Reminders list
            Expanded(
              child: reminders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📭', style: TextStyle(fontSize: 60)),
                          const SizedBox(height: 16),
                          Text(
                            'No reminders yet',
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
                      itemCount: reminders.length,
                      itemBuilder: (context, index) {
                        final reminder = reminders[index];
                        return _ReminderCard(
                          reminder: reminder,
                          onStatusUpdate: (status) =>
                              _updateReminderStatus(reminder.id, status),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.primaryWhite : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final Function(String) onStatusUpdate;

  const _ReminderCard({
    required this.reminder,
    required this.onStatusUpdate,
  });

  bool _isMutualPoke() {
    return reminder.isPoke && PokeService.isMutualPoke(reminder);
  }

  Color _getStatusColor() {
    if (_isMutualPoke()) {
      return AppTheme.primaryBlack;
    }

    switch (reminder.status) {
      case 'done':
      case 'acknowledged':
        return AppTheme.accentGreen;
      case 'snoozed':
        return AppTheme.accentOrange;
      case 'responded_heart':
        return AppTheme.primaryBlack;
      default:
        return AppTheme.primaryBlack;
    }
  }

  IconData _getStatusIcon() {
    if (_isMutualPoke()) {
      return Icons.favorite;
    }

    switch (reminder.status) {
      case 'done':
      case 'acknowledged':
        return Icons.check_circle;
      case 'snoozed':
        return Icons.schedule;
      case 'responded_heart':
        return Icons.favorite_border;
      default:
        return Icons.circle_outlined;
    }
  }

  String _getStatusLabel() {
    if (_isMutualPoke()) {
      return 'Mutual!';
    }

    switch (reminder.status) {
      case 'done':
        return 'Done';
      case 'acknowledged':
        return 'Smiled';
      case 'snoozed':
        return 'Snoozed';
      case 'responded_heart':
        return 'Poked Back';
      case 'sent':
        return 'Sent';
      case 'received':
        return 'Received';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: BrandLoader().colors.textPrimary.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reminder.isPoke)
                      Text(
                        '💫 ',
                        style: const TextStyle(fontSize: 11),
                      ),
                    Text(
                      reminder.isPoke
                          ? _isMutualPoke()
                              ? 'Mutual Poke!'
                              : reminder.type == 'received'
                                  ? 'From ${reminder.from}'
                                  : 'To ${reminder.to}'
                          : reminder.type == 'received'
                              ? 'From ${reminder.from}'
                              : 'To ${reminder.to}',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LP badge for received reminders that aren't done yet
                  if (!reminder.isPoke &&
                      reminder.type == 'received' &&
                      reminder.status != 'done') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accentGreen, width: 1),
                      ),
                      child: Text(
                        '+10 LP',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (reminder.isPoke && _getStatusLabel().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getStatusLabel(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reminder.text,
            style: AppTheme.bodyFont.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
              decoration: reminder.status == 'done' ? TextDecoration.lineThrough : null,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            timeFormat.format(reminder.timestamp),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
          if (reminder.type == 'received' && reminder.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onStatusUpdate('snoozed'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.borderLight, width: 2),
                      foregroundColor: AppTheme.textPrimary,
                      backgroundColor: AppTheme.backgroundGray,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Snooze', style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onStatusUpdate('done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlack,
                      foregroundColor: AppTheme.primaryWhite,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Done', style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
