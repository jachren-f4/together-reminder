import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/reminder_service.dart';
import '../utils/logger.dart';
import '../theme/app_theme.dart';

class RemindBottomSheet extends StatefulWidget {
  const RemindBottomSheet({super.key});

  @override
  State<RemindBottomSheet> createState() => _RemindBottomSheetState();
}

class _RemindBottomSheetState extends State<RemindBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedTime;

  final List<Map<String, dynamic>> _quickMessages = [
    {'emoji': '💕', 'text': 'Love you!'},
    {'emoji': '🏠', 'text': "I'm home"},
    {'emoji': '☕', 'text': 'Coffee?'},
    {'emoji': '🛒', 'text': 'Pick up milk'},
  ];

  final List<Map<String, dynamic>> _timeOptions = [
    {'emoji': '⚡', 'label': 'In 1 sec', 'minutes': 0},
    {'emoji': '☕', 'label': '1 hour', 'minutes': 60},
    {'emoji': '🌙', 'label': 'Tonight', 'minutes': null, 'special': 'tonight'},
    {'emoji': '☀️', 'label': 'Tomorrow', 'minutes': null, 'special': 'tomorrow'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  'Send Reminder',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Message input
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Remind me to...',
                    filled: true,
                    fillColor: AppTheme.backgroundGray,
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 20),

                // Quick messages
                Text(
                  'Quick Messages',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: _quickMessages.length,
                  itemBuilder: (context, index) {
                    final message = _quickMessages[index];
                    return _buildQuickMessageButton(message);
                  },
                ),

                const SizedBox(height: 24),

                // Time selection
                Text(
                  'When?',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: _timeOptions.length,
                  itemBuilder: (context, index) {
                    final time = _timeOptions[index];
                    return _buildTimeButton(time);
                  },
                ),

                const SizedBox(height: 32),

                // Send button
                ElevatedButton(
                  onPressed: _sendReminder,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Send Reminder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMessageButton(Map<String, dynamic> message) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _messageController.text = message['text'];
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message['emoji'], style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message['text'],
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(Map<String, dynamic> time) {
    final isSelected = _selectedTime == time['label'];
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedTime = time['label'];
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primaryBlack : AppTheme.backgroundGray,
        foregroundColor: isSelected ? AppTheme.primaryWhite : AppTheme.textPrimary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time['emoji'], style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              time['label'],
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReminder() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder message')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return;
    }

    // Send reminder logic
    final partner = StorageService().getPartner();
    final user = StorageService().getUser();
    if (partner == null || user == null) return;

    final selectedTimeOption = _timeOptions.firstWhere((t) => t['label'] == _selectedTime);
    final scheduledTime = _calculateScheduledTime(selectedTimeOption);

    const uuid = Uuid();
    final reminder = Reminder(
      id: uuid.v4(),
      type: 'sent',
      from: user.name ?? 'You',
      to: partner.name,
      text: _messageController.text,
      timestamp: DateTime.now(),
      scheduledFor: scheduledTime,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await StorageService().saveReminder(reminder);

    try {
      final success = await ReminderService.sendReminder(reminder);
      if (!success) {
        Logger.warn('Reminder saved locally but failed to send push notification', service: 'reminder');
      }
    } catch (e) {
      Logger.error('Error sending push notification', error: e, service: 'reminder');
    }

    // Close modal and show success
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder sent to ${partner.name}'),
          backgroundColor: AppTheme.primaryBlack,
        ),
      );
    }
  }

  DateTime _calculateScheduledTime(Map<String, dynamic> timeOption) {
    if (timeOption['special'] == 'tonight') {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, 20, 0); // 8 PM
    } else if (timeOption['special'] == 'tomorrow') {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0); // 9 AM
    } else {
      return DateTime.now().add(Duration(minutes: timeOption['minutes'] as int));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
