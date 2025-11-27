import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    {'emoji': '⚡', 'label': 'Now', 'minutes': 0},
    {'emoji': '☕', 'label': '1 Hour', 'minutes': 60},
    {'emoji': '🌙', 'label': '8 PM', 'special': 'tonight'},
    {'emoji': '☀️', 'label': '8 AM', 'special': 'tomorrow'},
  ];

  @override
  Widget build(BuildContext context) {
    final partner = StorageService().getPartner();
    final partnerName = partner?.name ?? 'Partner';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
        border: Border(
          top: BorderSide(color: AppTheme.primaryBlack, width: 2),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.primaryBlack, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REMINDER',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        '✕',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Hero section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    Text(
                      'Send a',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -1,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Reminder',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -1,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 40,
                      height: 1,
                      color: AppTheme.primaryBlack,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Schedule a thoughtful message for your partner',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Recipient bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.primaryBlack, width: 1),
                    bottom: BorderSide(color: AppTheme.primaryBlack, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TO',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      partnerName,
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Message field
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MESSAGE',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryBlack, width: 1),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 3,
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'What would you like to remind them about?',
                          hintStyle: AppTheme.headlineFont.copyWith(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Delivery time
                    Text(
                      'DELIVERY TIME',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _timeOptions.map((option) {
                        final isSelected = _selectedTime == option['label'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedTime = option['label'] as String;
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                right: option != _timeOptions.last ? 8 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryBlack
                                    : AppTheme.primaryWhite,
                                border: Border.all(
                                  color: AppTheme.primaryBlack,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    option['emoji'] as String,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    option['label'] as String,
                                    style: AppTheme.bodyFont.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: isSelected
                                          ? AppTheme.primaryWhite
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Quick messages
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUICK MESSAGES',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.5,
                      children: _quickMessages.map((msg) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _messageController.text = msg['text'];
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.borderLight,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  msg['emoji'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    msg['text'],
                                    style: AppTheme.bodyFont.copyWith(
                                      fontSize: 12,
                                      color: AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Footer with send button
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.primaryBlack, width: 2),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _sendReminder,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          color: AppTheme.primaryBlack,
                          child: Center(
                            child: Text(
                              'SEND REMINDER',
                              style: AppTheme.headlineFont.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 2,
                                color: AppTheme.primaryWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your partner will be notified at the scheduled time',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendReminder() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a reminder message'),
          backgroundColor: AppTheme.primaryBlack,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a time'),
          backgroundColor: AppTheme.primaryBlack,
        ),
      );
      return;
    }

    final partner = StorageService().getPartner();
    final user = StorageService().getUser();
    if (partner == null || user == null) return;

    final selectedTimeOption =
        _timeOptions.firstWhere((t) => t['label'] == _selectedTime);
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
        Logger.warn(
            'Reminder saved locally but failed to send push notification',
            service: 'reminder');
      }
    } catch (e) {
      Logger.error('Error sending push notification',
          error: e, service: 'reminder');
    }

    // Close modal and show success
    if (mounted) {
      Navigator.pop(context);
      _showSuccessOverlay(partner.name);
    }
  }

  void _showSuccessOverlay(String partnerName) {
    showDialog(
      context: context,
      barrierColor: AppTheme.primaryBlack.withAlpha((0.95 * 255).round()),
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: const Text('✨', style: TextStyle(fontSize: 120)),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'REMINDER SENT',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.primaryWhite,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$partnerName will be notified',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.primaryWhite.withAlpha((0.7 * 255).round()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime _calculateScheduledTime(Map<String, dynamic> timeOption) {
    final now = DateTime.now();

    if (timeOption['special'] == 'tonight') {
      var tonight = DateTime(now.year, now.month, now.day, 20, 0);
      if (now.isAfter(tonight)) {
        tonight = tonight.add(const Duration(days: 1));
      }
      return tonight;
    } else if (timeOption['special'] == 'tomorrow') {
      final tomorrow = now.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0);
    } else {
      return now.add(Duration(minutes: timeOption['minutes'] as int));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
