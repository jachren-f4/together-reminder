import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/brand_config.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
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

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

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

    if (_isUs2) {
      return _buildUs2Screen(partnerName);
    }

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

  // ============================================================
  // Us 2.0 Brand Implementation
  // ============================================================

  Widget _buildUs2Screen(String partnerName) {
    return Container(
      decoration: const BoxDecoration(
        gradient: Us2Theme.backgroundGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildUs2Header(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Hero section
                    _buildUs2HeroSection(),

                    const SizedBox(height: 24),

                    // Recipient card
                    _buildUs2RecipientCard(partnerName),

                    const SizedBox(height: 16),

                    // Message card
                    _buildUs2MessageCard(),

                    const SizedBox(height: 16),

                    // Time picker card
                    _buildUs2TimePickerCard(),

                    const SizedBox(height: 16),

                    // Quick messages card
                    _buildUs2QuickMessagesCard(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Footer
            _buildUs2Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildUs2Header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                size: 20,
                color: Us2Theme.textDark,
              ),
            ),
          ),
          Text(
            'REMINDER',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Us2Theme.textLight,
            ),
          ),
          const SizedBox(width: 40), // Balance the layout
        ],
      ),
    );
  }

  Widget _buildUs2HeroSection() {
    return Column(
      children: [
        // Large emoji
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: Us2Theme.accentGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Us2Theme.glowPink,
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '💌',
              style: TextStyle(fontSize: 36),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
          ).createShader(bounds),
          child: Text(
            'Send a Reminder',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Schedule a thoughtful message',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Us2Theme.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildUs2RecipientCard(String partnerName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: Us2Theme.accentGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TO',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Us2Theme.textLight,
                  ),
                ),
                Text(
                  partnerName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                ),
              ],
            ),
          ),
          const Text('💕', style: TextStyle(fontSize: 24)),
        ],
      ),
    );
  }

  Widget _buildUs2MessageCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MESSAGE',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Us2Theme.textLight,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            autofocus: false,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: Us2Theme.textDark,
            ),
            decoration: InputDecoration(
              hintText: 'What would you like to remind them?',
              hintStyle: GoogleFonts.nunito(
                fontSize: 15,
                color: Us2Theme.textLight,
              ),
              filled: true,
              fillColor: Us2Theme.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Us2Theme.gradientAccentStart,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onSubmitted: (value) => _dismissKeyboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2TimePickerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DELIVERY TIME',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Us2Theme.textLight,
            ),
          ),
          const SizedBox(height: 12),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      right: option != _timeOptions.last ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: isSelected ? Us2Theme.accentGradient : null,
                      color: isSelected ? null : Us2Theme.cream,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Us2Theme.glowPink,
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          option['emoji'] as String,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option['label'] as String,
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isSelected ? Colors.white : Us2Theme.textDark,
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
    );
  }

  Widget _buildUs2QuickMessagesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK MESSAGES',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Us2Theme.textLight,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.2,
            children: _quickMessages.map((msg) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _messageController.text = msg['text'];
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Us2Theme.cream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        msg['emoji'],
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          msg['text'],
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Us2Theme.textDark,
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
    );
  }

  Widget _buildUs2Footer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUs2 ? _sendUs2Reminder : _sendReminder,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: Us2Theme.accentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.glowPink,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'SEND REMINDER',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your partner will be notified at the scheduled time',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Us2Theme.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _sendUs2Reminder() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a reminder message',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: Us2Theme.gradientAccentStart,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a time',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: Us2Theme.gradientAccentStart,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      _showUs2SuccessOverlay(partner.name, _selectedTime!, isScheduled);
    }

    // Clear form
    _messageController.clear();
    setState(() {
      _selectedTime = null;
    });
  }

  void _showUs2SuccessOverlay(String partnerName, String timeLabel, bool isScheduled) {
    final title = isScheduled ? 'Reminder Scheduled' : 'Reminder Sent';
    final subtitle = isScheduled
        ? '$partnerName will be notified at $timeLabel'
        : '$partnerName will be notified now';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Us2Theme.glowPink,
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: Us2Theme.accentGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Us2Theme.glowPink,
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            isScheduled ? '⏰' : '✨',
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                  ).createShader(bounds),
                  child: Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Us2Theme.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
