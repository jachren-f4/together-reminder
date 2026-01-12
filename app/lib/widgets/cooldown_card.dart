import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/us2_theme.dart';
import '../models/cooldown_status.dart';

/// Card shown when an activity is on cooldown
///
/// Displays remaining time and batch status with Us2 styling.
/// Includes auto-updating countdown timer.
class CooldownCard extends StatefulWidget {
  final CooldownStatus status;
  final String activityName;

  const CooldownCard({
    super.key,
    required this.status,
    required this.activityName,
  });

  @override
  State<CooldownCard> createState() => _CooldownCardState();
}

class _CooldownCardState extends State<CooldownCard> {
  Timer? _timer;
  String _remainingTime = '';

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    // Update every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateRemainingTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemainingTime() {
    if (mounted) {
      setState(() {
        _remainingTime = widget.status.formattedRemaining ?? 'Soon';
      });
    }
  }

  /// Format activity name for display (e.g., "Classic Quiz" -> "classic quizzes")
  String _formatActivityPlural() {
    final name = widget.activityName.toLowerCase();

    // Handle each activity type appropriately
    if (name.contains('quiz')) {
      // "Classic Quiz" -> "classic quizzes", "Affirmation Quiz" -> "affirmation quizzes"
      return name.replaceAll(' quiz', ' quizzes');
    }
    if (name == 'you or me') {
      return 'You or Me games';
    }
    if (name == 'crossword') {
      return 'crosswords';
    }
    if (name == 'word search') {
      return 'word searches';
    }

    return widget.activityName;
  }

  /// Get the header text for the timer (e.g., "MORE QUIZZES IN")
  String _getTimerHeader() {
    final name = widget.activityName.toLowerCase();

    if (name.contains('quiz')) {
      return 'MORE QUIZZES IN';
    }
    if (name == 'you or me') {
      return 'MORE GAMES IN';
    }
    if (name == 'crossword') {
      return 'MORE CROSSWORDS IN';
    }
    if (name == 'word search') {
      return 'MORE PUZZLES IN';
    }

    return 'MORE IN';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clock icon with glow
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Us2Theme.primaryBrandPink.withValues(alpha: 0.15),
                  Us2Theme.gradientAccentEnd.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '⏰',
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'All Done!',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'You\'ve completed 2 ${_formatActivityPlural()}. Now do other things in Us 2.0.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Us2Theme.textMedium,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Timer display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: Us2Theme.backgroundGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Us2Theme.primaryBrandPink.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _getTimerHeader(),
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Us2Theme.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _remainingTime,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.primaryBrandPink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Footer info
          Text(
            'More ${_formatActivityPlural()} will unlock after the timer.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Us2Theme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small cooldown badge for quest cards
class CooldownBadge extends StatelessWidget {
  final String remainingTime;

  const CooldownBadge({
    super.key,
    required this.remainingTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⏰', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            remainingTime,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Remaining plays indicator (shows "1 play left" when < 2)
class RemainingPlaysIndicator extends StatelessWidget {
  final int remaining;

  const RemainingPlaysIndicator({
    super.key,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    if (remaining >= 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Us2Theme.gradientAccentEnd.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        remaining == 1 ? '1 play left today' : 'Last play!',
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Us2Theme.gradientAccentEnd,
        ),
      ),
    );
  }
}
