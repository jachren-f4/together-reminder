import 'package:flutter/material.dart';
import '../models/quiz_match.dart';
import '../services/storage_service.dart';
import '../widgets/editorial/editorial.dart';

/// Results screen for Quiz Match (server-centric architecture)
///
/// Displays match percentage and completion status
class QuizMatchResultsScreen extends StatelessWidget {
  final QuizMatch match;
  final ServerQuiz? quiz;
  final int? matchPercentage;
  final int? lpEarned;

  const QuizMatchResultsScreen({
    super.key,
    required this.match,
    this.quiz,
    this.matchPercentage,
    this.lpEarned,
  });

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final partner = storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    final percentage = matchPercentage ?? match.matchPercentage ?? 0;
    final lp = lpEarned ?? 30;

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            EditorialHeaderSimple(
              title: quiz?.title ?? 'Quiz Results',
              onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: Column(
                    children: [
                      // Success icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: EditorialStyles.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check,
                            color: EditorialStyles.paper,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Quiz Complete!',
                        style: EditorialStyles.headline,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        'You and $partnerName have both completed the quiz.',
                        style: EditorialStyles.bodyTextItalic,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Match percentage card
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: EditorialStyles.fullBorder,
                            boxShadow: [
                              BoxShadow(
                                color: EditorialStyles.ink.withValues(alpha: 0.08),
                                offset: const Offset(4, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'MATCH PERCENTAGE',
                                style: EditorialStyles.labelUppercaseSmall,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '$percentage%',
                                style: EditorialStyles.scoreLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getMatchDescription(percentage),
                                style: EditorialStyles.bodyTextItalic,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // LP earned
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          border: EditorialStyles.fullBorder,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💰', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Text(
                              '+$lp LP earned',
                              style: EditorialStyles.labelUppercase,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: EditorialStyles.paper,
                border: Border(top: EditorialStyles.border),
              ),
              child: EditorialPrimaryButton(
                label: 'Return Home',
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMatchDescription(int percentage) {
    if (percentage >= 90) {
      return 'Amazing! You\'re perfectly in sync!';
    } else if (percentage >= 70) {
      return 'Great connection! You know each other well.';
    } else if (percentage >= 50) {
      return 'Good match! Room to grow together.';
    } else if (percentage >= 30) {
      return 'Interesting differences! Keep exploring.';
    } else {
      return 'Opposite perspectives can be exciting!';
    }
  }
}
