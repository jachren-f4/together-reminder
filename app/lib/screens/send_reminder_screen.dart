import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/reminder_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/utils/logger.dart';
import 'package:uuid/uuid.dart';

class SendReminderScreen extends StatefulWidget {
  const SendReminderScreen({super.key});

  @override
  State<SendReminderScreen> createState() => _SendReminderScreenState();
}

class _SendReminderScreenState extends State<SendReminderScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _messageController = TextEditingController();
  String? _selectedTime;

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

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

  DateTime _calculateScheduledTime(Map<String, dynamic> timeOption) {
    final now = DateTime.now();

    if (timeOption['special'] == 'tonight') {
      // Schedule for 8 PM (20:00) today in local time
      var tonight = DateTime(now.year, now.month, now.day, 20, 0);
      // If it's already past 8 PM, schedule for tomorrow 8 PM
      if (now.isAfter(tonight)) {
        tonight = tonight.add(const Duration(days: 1));
      }
      return tonight;
    } else if (timeOption['special'] == 'tomorrow') {
      // Schedule for 8 AM tomorrow in local time
      final tomorrow = now.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0);
    } else {
      return now.add(Duration(minutes: timeOption['minutes'] as int));
    }
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

    final partner = _storageService.getPartner();
    final user = _storageService.getUser();
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

    await _storageService.saveReminder(reminder);

    // Send push notification via Cloud Function
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

    // Show success overlay with appropriate message
    if (mounted) {
      final isScheduled = _selectedTime != 'Now';
      _showSuccessOverlay(partner.name, _selectedTime!, isScheduled);
    }

    // Clear form
    _messageController.clear();
    setState(() {
      _selectedTime = null;
    });
  }

  void _showSuccessOverlay(String partnerName, String timeLabel, bool isScheduled) {
    // Determine the title and subtitle based on whether it was scheduled or sent now
    final title = isScheduled ? 'REMINDER SCHEDULED' : 'REMINDER SENT';
    final subtitle = isScheduled
        ? '$partnerName will be notified at $timeLabel'
        : '$partnerName will be notified now';

    showDialog(
      context: context,
      barrierColor: AppTheme.primaryBlack.withAlpha((0.95 * 255).round()),
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
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
                    child: Text(isScheduled ? '⏰' : '✨', style: const TextStyle(fontSize: 120)),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.primaryWhite,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
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

  @override
  Widget build(BuildContext context) {
    final partner = _storageService.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    return Container(
      color: AppTheme.primaryWhite,
      child: SafeArea(
        child: Column(
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

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Hero section
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 40),
                      child: Column(
                        children: [
                          Text(
                            'Send a',
                            style: AppTheme.headlineFont.copyWith(
                              fontSize: 42,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -1,
                              color: AppTheme.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'Reminder',
                            style: AppTheme.headlineFont.copyWith(
                              fontSize: 42,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -1,
                              color: AppTheme.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: 40,
                            height: 1,
                            color: AppTheme.primaryBlack,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Schedule a thoughtful message for your partner',
                            style: AppTheme.headlineFont.copyWith(
                              fontSize: 14,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.primaryBlack, width: 1),
                          bottom:
                              BorderSide(color: AppTheme.primaryBlack, width: 1),
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
                          TextField(
                            controller: _messageController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'What would you like to remind them about?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.borderLight, width: 2),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.borderLight, width: 2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlack, width: 2),
                              ),
                            ),
                            onSubmitted: (value) {
                              _dismissKeyboard();
                            },
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
                              final isSelected =
                                  _selectedTime == option['label'];
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
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Footer with send button
            Container(
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
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
