import 'package:flutter/material.dart';
import '../../models/base_session.dart';
import '../../models/quiz_session.dart';
import '../../models/quiz_question.dart';
import '../../services/quiz_service.dart';
import '../../services/storage_service.dart';

/// Results content widget for Affirmation Quiz
/// Displays individual score (not match percentage) and answers on 1-5 scale
class AffirmationResultsContent extends StatefulWidget {
  final BaseSession session;

  const AffirmationResultsContent({
    super.key,
    required this.session,
  });

  @override
  State<AffirmationResultsContent> createState() => _AffirmationResultsContentState();
}

class _AffirmationResultsContentState extends State<AffirmationResultsContent> {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  late List<QuizQuestion> _questions;

  @override
  void initState() {
    super.initState();
    final session = widget.session as QuizSession;
    _questions = _quizService.getSessionQuestions(session);
  }

  /// Calculate average score from 1-5 scale answers
  double _calculateAverageScore(List<int> answers) {
    if (answers.isEmpty) return 0;
    final sum = answers.reduce((a, b) => a + b);
    return sum / answers.length;
  }

  /// Convert average (1-5) to percentage (0-100)
  int _averageToPercentage(double average) {
    return ((average / 5.0) * 100).round();
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session as QuizSession;
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null) {
      return const Center(child: Text('User not found'));
    }

    final userAnswers = session.answers?[user.id] ?? [];
    final partnerAnswers = session.answers?[partner?.pushToken] ?? [];

    final averageScore = _calculateAverageScore(userAnswers);
    final scorePercentage = _averageToPercentage(averageScore);
    final bothCompleted = userAnswers.isNotEmpty && partnerAnswers.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quiz title
            Text(
              session.quizName ?? 'Affirmation Quiz',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair Display',
              ),
            ),

            const SizedBox(height: 8),

            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                session.category?.toUpperCase() ?? 'AFFIRMATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                  letterSpacing: 1.0,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Your results section
            Text(
              'Your results',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'This represents how satisfied you are with ${session.category ?? 'this area'} in your relationship at present.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            // Circular progress indicator showing individual score
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: scorePercentage / 100,
                        strokeWidth: 12,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getScoreColor(scorePercentage),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$scorePercentage%',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Playfair Display',
                          ),
                        ),
                        Text(
                          '${averageScore.toStringAsFixed(1)}/5.0',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Partner status
            _buildPartnerStatus(theme, bothCompleted, partner?.name),

            const SizedBox(height: 32),

            // Your answers section
            Text(
              'Your answers',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // List of questions and answers
            ...List.generate(_questions.length, (index) {
              if (index >= userAnswers.length) return const SizedBox.shrink();

              final question = _questions[index];
              final answer = userAnswers[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAnswerCard(theme, index + 1, question.question, answer),
              );
            }),

            const SizedBox(height: 24),

            // Done button
            FilledButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerStatus(ThemeData theme, bool bothCompleted, String? partnerName) {
    if (bothCompleted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${partnerName ?? 'Your partner'} has also completed this quiz',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: theme.colorScheme.onSecondaryContainer,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Awaiting ${partnerName ?? 'partner'}\'s answers',
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAnswerCard(ThemeData theme, int number, String question, int answer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $question',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Heart icons showing the rating
              ...List.generate(5, (index) {
                final value = index + 1;
                final isSelected = value <= answer;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    isSelected ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: isSelected ? Colors.red : Colors.grey[400],
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                '$answer/5',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
