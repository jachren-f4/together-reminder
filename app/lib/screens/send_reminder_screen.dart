import 'package:flutter/material.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/reminder_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/utils/logger.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
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

    final partner = _storageService.getPartner();
    final user = _storageService.getUser();
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

    await _storageService.saveReminder(reminder);

    // Send push notification via Cloud Function
    try {
      final success = await ReminderService.sendReminder(reminder);
      if (!success) {
        Logger.warn('Reminder saved locally but failed to send push notification', service: 'reminder');
      }
    } catch (e) {
      Logger.error('Error sending push notification', error: e, service: 'reminder');
    }

    // Show success overlay
    if (mounted) {
      _showSuccessOverlay(partner.name, _selectedTime!);
    }

    // Clear form
    _messageController.clear();
    setState(() {
      _selectedTime = null;
    });
  }

  void _showSuccessOverlay(String partnerName, String timeLabel) {
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
                    child: const Text('✨', style: TextStyle(fontSize: 120)),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Reminder Sent!',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryWhite,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$partnerName will be notified $timeLabel',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 16,
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

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Column(
                children: [
                  const Text('💕', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                    'Together',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryWhite,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: BrandLoader().colors.textPrimary.withAlpha((0.06 * 255).round()),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(partner?.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          partner?.name ?? 'Partner',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Expanded(
                child: Column(
                  children: [
                    // Reminder Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryWhite,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: BrandLoader().colors.textPrimary.withAlpha((0.06 * 255).round()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What would you like to remind them about?',
                              style: AppTheme.bodyFont.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Type your reminder...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppTheme.borderLight, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppTheme.borderLight, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: AppTheme.primaryBlack, width: 2),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Text(
                              'When should they be reminded?',
                              style: AppTheme.bodyFont.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),

                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 2.2,
                              children: _timeOptions.map((option) {
                                final isSelected = _selectedTime == option['label'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTime = option['label'] as String;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryBlack
                                          : AppTheme.backgroundGray,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryBlack
                                            : AppTheme.borderLight,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          option['emoji'] as String,
                                          style: TextStyle(fontSize: 18),
                                        ),
                                        Text(
                                          option['label'] as String,
                                          style: AppTheme.bodyFont.copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? AppTheme.primaryWhite
                                                : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),

                            // Send button
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _sendReminder,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlack,
                                      foregroundColor: AppTheme.primaryWhite,
                                      elevation: 0,
                                      shadowColor: AppTheme.primaryBlack.withAlpha((0.15 * 255).round()),
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Send Reminder',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('💌', style: TextStyle(fontSize: 18)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Earn +8 LP',
                                  style: AppTheme.bodyFont.copyWith(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
