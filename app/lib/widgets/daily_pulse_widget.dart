import 'package:flutter/material.dart';

/// Daily Pulse Widget - Compact card for Activities screen
/// Shows today's daily pulse question with role indicator and streak
class DailyPulseWidget extends StatelessWidget {
  final bool isSubject; // Is current user the subject today?
  final String partnerName;
  final String questionPreview;
  final int currentStreak;
  final DailyPulseStatus status;
  final VoidCallback onTap;

  const DailyPulseWidget({
    super.key,
    required this.isSubject,
    required this.partnerName,
    required this.questionPreview,
    required this.currentStreak,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title + Streak
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📅 Today\'s Pulse',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Playfair Display',
                  ),
                ),
                if (currentStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🔥 $currentStreak days',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Role Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRoleBadgeText(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Question Preview or Status Message
            Text(
              _getMainText(),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            // CTA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getCtaText(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleBadgeText() {
    switch (status) {
      case DailyPulseStatus.subjectNotAnswered:
        return 'You\'re SUBJECT today - Answer about yourself!';
      case DailyPulseStatus.predictorNotAnswered:
        return 'You\'re PREDICTOR - Guess $partnerName\'s answer!';
      case DailyPulseStatus.bothCompleted:
        return 'Completed! 🎉';
      case DailyPulseStatus.waitingForPartner:
        return isSubject
            ? 'Waiting for $partnerName to predict...'
            : 'Waiting for $partnerName to answer...';
    }
  }

  String _getMainText() {
    switch (status) {
      case DailyPulseStatus.subjectNotAnswered:
      case DailyPulseStatus.predictorNotAnswered:
        return questionPreview;
      case DailyPulseStatus.waitingForPartner:
        return 'Your answer has been submitted. $partnerName will be notified!';
      case DailyPulseStatus.bothCompleted:
        return 'See how well you know each other!';
    }
  }

  String _getCtaText() {
    switch (status) {
      case DailyPulseStatus.subjectNotAnswered:
      case DailyPulseStatus.predictorNotAnswered:
        return 'Tap to answer';
      case DailyPulseStatus.waitingForPartner:
        return 'Check back later';
      case DailyPulseStatus.bothCompleted:
        return 'View results';
    }
  }
}

enum DailyPulseStatus {
  subjectNotAnswered,
  predictorNotAnswered,
  waitingForPartner,
  bothCompleted,
}
