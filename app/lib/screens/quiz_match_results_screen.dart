import 'package:flutter/material.dart';
import '../models/quiz_match.dart';
import '../services/storage_service.dart';
import '../widgets/editorial/editorial.dart';

/// Results screen for Quiz Match (server-centric architecture)
///
/// Displays match percentage with question-by-question comparison.
/// Editorial design with clear match/mismatch indicators.
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
    final user = storage.getUser();
    final partner = storage.getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';

    // Use server-provided values directly (server is authoritative)
    final percentage = matchPercentage ?? match.matchPercentage ?? 0;
    final lp = lpEarned ?? 30;

    // Determine which answers belong to whom
    final isPlayer1 = user?.id == match.player1Id;
    final userAnswers = isPlayer1 ? match.player1Answers : match.player2Answers;
    final partnerAnswers = isPlayer1 ? match.player2Answers : match.player1Answers;

    // Derive match count from server's percentage (server calculates this)
    final totalQuestions = quiz?.questions.length ?? userAnswers.length;
    final matchCount = totalQuestions > 0
        ? ((percentage / 100) * totalQuestions).round()
        : 0;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Score summary section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                      child: Column(
                        children: [
                          // Large percentage display
                          Text(
                            '$percentage%',
                            style: EditorialStyles.scoreLarge.copyWith(
                              fontSize: 72,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'MATCH',
                            style: EditorialStyles.labelUppercase,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getMatchDescription(percentage),
                            style: EditorialStyles.bodyTextItalic,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Match count and LP earned row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatPill('$matchCount/$totalQuestions matched'),
                              const SizedBox(width: 12),
                              _buildStatPill('+$lp LP'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(
                      height: 1,
                      color: EditorialStyles.ink.withValues(alpha: 0.15),
                    ),

                    // Answer comparison header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Text(
                        'ANSWER COMPARISON',
                        style: EditorialStyles.labelUppercase,
                      ),
                    ),

                    // Question-by-question comparison
                    if (quiz != null && quiz!.questions.isNotEmpty)
                      ...List.generate(quiz!.questions.length, (index) {
                        final question = quiz!.questions[index];
                        final userAnswer = index < userAnswers.length ? userAnswers[index] : -1;
                        final partnerAnswer = index < partnerAnswers.length ? partnerAnswers[index] : -1;
                        final isMatch = userAnswer == partnerAnswer && userAnswer >= 0;

                        return _buildQuestionComparison(
                          questionNumber: index + 1,
                          questionText: question.text,
                          choices: question.choices,
                          userAnswer: userAnswer,
                          partnerAnswer: partnerAnswer,
                          userName: userName,
                          partnerName: partnerName,
                          isMatch: isMatch,
                        );
                      })
                    else
                      // Fallback when no quiz data available
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Detailed comparison not available.',
                          style: EditorialStyles.bodyTextItalic.copyWith(
                            color: EditorialStyles.inkMuted,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
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

  Widget _buildStatPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Text(
        text,
        style: EditorialStyles.labelUppercaseSmall,
      ),
    );
  }

  Widget _buildQuestionComparison({
    required int questionNumber,
    required String questionText,
    required List<String> choices,
    required int userAnswer,
    required int partnerAnswer,
    required String userName,
    required String partnerName,
    required bool isMatch,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
        color: isMatch
            ? EditorialStyles.ink.withValues(alpha: 0.03)
            : EditorialStyles.paper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header with match indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: EditorialStyles.border),
            ),
            child: Row(
              children: [
                // Question number
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: EditorialStyles.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: TextStyle(
                        color: EditorialStyles.paper,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Question text
                Expanded(
                  child: Text(
                    questionText,
                    style: EditorialStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Match indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMatch ? EditorialStyles.ink : Colors.transparent,
                    border: Border.all(
                      color: EditorialStyles.ink,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isMatch ? 'MATCH' : 'DIFF',
                    style: TextStyle(
                      color: isMatch ? EditorialStyles.paper : EditorialStyles.ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Answer comparison rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAnswerRow(
                  label: userName,
                  answer: userAnswer >= 0 && userAnswer < choices.length
                      ? choices[userAnswer]
                      : '—',
                  isHighlighted: isMatch,
                ),
                const SizedBox(height: 8),
                _buildAnswerRow(
                  label: partnerName,
                  answer: partnerAnswer >= 0 && partnerAnswer < choices.length
                      ? choices[partnerAnswer]
                      : '—',
                  isHighlighted: isMatch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerRow({
    required String label,
    required String answer,
    required bool isHighlighted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: EditorialStyles.labelUppercaseSmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            answer,
            style: EditorialStyles.bodySmall.copyWith(
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
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
