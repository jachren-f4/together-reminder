import 'package:flutter/material.dart';
import '../models/you_or_me_match.dart';
import '../services/storage_service.dart';
import '../widgets/editorial/editorial.dart';

/// Results screen for You-or-Me Match (server-centric architecture)
///
/// Displays scores and completion status
class YouOrMeMatchResultsScreen extends StatelessWidget {
  final YouOrMeMatch match;
  final ServerYouOrMeQuiz? quiz;
  final int myScore;
  final int partnerScore;
  final int? lpEarned;

  const YouOrMeMatchResultsScreen({
    super.key,
    required this.match,
    this.quiz,
    required this.myScore,
    required this.partnerScore,
    this.lpEarned,
  });

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';
    final lp = lpEarned ?? 30;

    final totalQuestions = quiz?.totalQuestions ?? 10;
    final matchPercentage = totalQuestions > 0
        ? ((myScore + partnerScore) / (totalQuestions * 2) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            EditorialHeaderSimple(
              title: 'You or Me Results',
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
                        'Game Complete!',
                        style: EditorialStyles.headline,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        'See how well you and $partnerName matched!',
                        style: EditorialStyles.bodyTextItalic,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Score comparison card
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
                                'MATCH SCORE',
                                style: EditorialStyles.labelUppercaseSmall,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '$matchPercentage%',
                                style: EditorialStyles.scoreLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getMatchDescription(matchPercentage),
                                style: EditorialStyles.bodyTextItalic,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Container(
                                height: 1,
                                color: EditorialStyles.inkLight,
                              ),
                              const SizedBox(height: 24),

                              // Individual scores
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildScoreColumn(userName, myScore, totalQuestions),
                                  Container(
                                    width: 1,
                                    height: 60,
                                    color: EditorialStyles.inkLight,
                                  ),
                                  _buildScoreColumn(partnerName, partnerScore, totalQuestions),
                                ],
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

  Widget _buildScoreColumn(String name, int score, int total) {
    return Column(
      children: [
        Text(
          name.length > 10 ? '${name.substring(0, 10)}...' : name,
          style: EditorialStyles.labelUppercaseSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '$score/$total',
          style: EditorialStyles.scoreMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'matches',
          style: EditorialStyles.bodySmall.copyWith(
            color: EditorialStyles.inkMuted,
          ),
        ),
      ],
    );
  }

  String _getMatchDescription(int percentage) {
    if (percentage >= 90) {
      return 'Perfect sync! You really know each other!';
    } else if (percentage >= 70) {
      return 'Great minds think alike!';
    } else if (percentage >= 50) {
      return 'Good connection! Keep learning about each other.';
    } else if (percentage >= 30) {
      return 'Interesting differences! Variety is the spice of life.';
    } else {
      return 'Opposites attract! Time to explore your differences.';
    }
  }
}
