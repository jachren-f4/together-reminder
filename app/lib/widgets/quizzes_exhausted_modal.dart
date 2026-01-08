import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/us2_theme.dart';

/// Modal shown when all quizzes of a type have been exhausted
///
/// Encourages users to unlock more magnets to get new content.
class QuizzesExhaustedModal extends StatelessWidget {
  final String quizType;
  final int unlockedMagnets;
  final VoidCallback? onViewCollection;
  final VoidCallback onDismiss;

  const QuizzesExhaustedModal({
    super.key,
    required this.quizType,
    required this.unlockedMagnets,
    this.onViewCollection,
    required this.onDismiss,
  });

  /// Show the exhausted modal
  static Future<void> show(
    BuildContext context, {
    required String quizType,
    required int unlockedMagnets,
    VoidCallback? onViewCollection,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => QuizzesExhaustedModal(
        quizType: quizType,
        unlockedMagnets: unlockedMagnets,
        onViewCollection: onViewCollection,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  String get _quizTypeDisplay {
    switch (quizType) {
      case 'classic':
        return 'Classic Quiz';
      case 'affirmation':
        return 'Affirmation Quiz';
      case 'you_or_me':
        return 'You or Me';
      default:
        return 'Quiz';
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingMagnets = 30 - unlockedMagnets;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Us2Theme.cardSalmon,
              Us2Theme.cardSalmonDark,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📚', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'All Caught Up!',
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              "You've played all available\n$_quizTypeDisplay content!",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),

            // Unlock info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🧲', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        '$unlockedMagnets/30 Magnets',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (remainingMagnets > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Unlock $remainingMagnets more to get\nnew questions!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Replay info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE066).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔄', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'You can replay old favorites!',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFE066),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            if (onViewCollection != null) ...[
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  onViewCollection!();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Us2Theme.gradientAccentStart,
                        Us2Theme.gradientAccentEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'View Collection',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextButton(
              onPressed: onDismiss,
              child: Text(
                'Got it',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
