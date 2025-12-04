import 'package:flutter/material.dart';
import '../models/you_or_me_match.dart';
import '../services/storage_service.dart';
import '../widgets/editorial/editorial.dart';

/// Results screen for You-or-Me Match (bulk submission)
///
/// Displays match percentage with question-by-question comparison.
/// Editorial design with clear match/mismatch indicators.
class YouOrMeMatchResultsScreen extends StatelessWidget {
  final YouOrMeMatch match;
  final ServerYouOrMeQuiz? quiz;
  final int myScore;
  final int partnerScore;
  final int? lpEarned;
  final int? matchPercentage;
  final List<String>? userAnswers;
  final List<String>? partnerAnswers;

  const YouOrMeMatchResultsScreen({
    super.key,
    required this.match,
    this.quiz,
    required this.myScore,
    required this.partnerScore,
    this.lpEarned,
    this.matchPercentage,
    this.userAnswers,
    this.partnerAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';
    final lp = lpEarned ?? 30;

    // Use server-provided values directly (server is authoritative)
    final totalQuestions = quiz?.totalQuestions ?? 10;
    final displayMatchPercentage = matchPercentage ?? 0;

    // Derive match count from server's percentage
    final totalMatches = totalQuestions > 0
        ? ((displayMatchPercentage / 100) * totalQuestions).round()
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
                            '$displayMatchPercentage%',
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
                            _getMatchDescription(displayMatchPercentage),
                            style: EditorialStyles.bodyTextItalic,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Match count and LP earned row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatPill('$totalMatches/$totalQuestions matched'),
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
                    if (quiz != null && quiz!.questions.isNotEmpty &&
                        userAnswers != null && partnerAnswers != null)
                      ...List.generate(quiz!.questions.length, (index) {
                        final question = quiz!.questions[index];
                        final userAnswer = index < userAnswers!.length ? userAnswers![index] : '';
                        final partnerAnswer = index < partnerAnswers!.length ? partnerAnswers![index] : '';
                        final isMatch = userAnswer.isNotEmpty && userAnswer == partnerAnswer;

                        return _buildQuestionComparison(
                          questionNumber: index + 1,
                          prompt: question.prompt,
                          content: question.content,
                          userAnswer: userAnswer,
                          partnerAnswer: partnerAnswer,
                          userName: userName,
                          partnerName: partnerName,
                          isMatch: isMatch,
                        );
                      })
                    else
                      // Fallback when no detailed data available
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Individual scores summary
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: EditorialStyles.fullBorder,
                              ),
                              child: Row(
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
                            ),
                          ],
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
    required String prompt,
    required String content,
    required String userAnswer,
    required String partnerAnswer,
    required String userName,
    required String partnerName,
    required bool isMatch,
  }) {
    // Convert answer codes to display names
    String formatAnswer(String answer, String userName, String partnerName) {
      switch (answer.toLowerCase()) {
        case 'me':
        case 'self':
          return userName;
        case 'you':
        case 'partner':
          return partnerName;
        default:
          return answer.isNotEmpty ? answer : '—';
      }
    }

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt,
                        style: EditorialStyles.labelUppercaseSmall.copyWith(
                          color: EditorialStyles.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content,
                        style: EditorialStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                  label: '$userName said',
                  answer: formatAnswer(userAnswer, userName, partnerName),
                  isHighlighted: isMatch,
                ),
                const SizedBox(height: 8),
                _buildAnswerRow(
                  label: '$partnerName said',
                  answer: formatAnswer(partnerAnswer, userName, partnerName),
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
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: EditorialStyles.labelUppercaseSmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
        ),
        Expanded(
          flex: 3,
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
