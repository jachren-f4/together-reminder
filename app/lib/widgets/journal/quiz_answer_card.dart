import 'package:flutter/material.dart';
import 'package:togetherremind/models/quiz_answer_detail.dart';

/// A card widget displaying a single quiz question with both partners' answers.
///
/// Shows:
/// - Question number badge
/// - Question text
/// - Two answer bubbles (You / Partner)
/// - Alignment badge (Aligned! or Different perspectives)
class QuizAnswerCard extends StatelessWidget {
  final QuizAnswerDetail answer;
  final int questionNumber;
  final String partnerName;

  const QuizAnswerCard({
    super.key,
    required this.answer,
    required this.questionNumber,
    required this.partnerName,
  });

  // Design colors from mockup
  static const _cream = Color(0xFFFFF8F0);
  static const _white = Color(0xFFFFFFFF);
  static const _ink = Color(0xFF2D2D2D);
  static const _inkLight = Color(0xFF8B8B8B);
  static const _beige = Color(0xFFF5E6D8);
  static const _accentPink = Color(0xFFFF6B6B);
  static const _accentOrange = Color(0xFFFF9F43);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question with number badge
          _buildQuestion(),
          const SizedBox(height: 14),
          // Answer bubbles
          _buildAnswerPair(),
          const SizedBox(height: 14),
          // Match badge
          _buildMatchBadge(),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _accentPink,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Text(
              '$questionNumber',
              style: const TextStyle(
                color: _white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Question text
        Expanded(
          child: Text(
            answer.questionText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerPair() {
    return Row(
      children: [
        Expanded(
          child: _buildAnswerBubble(
            name: 'You',
            answerText: answer.userAnswerText,
            isAligned: answer.isAligned,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildAnswerBubble(
            name: partnerName,
            answerText: answer.partnerAnswerText,
            isAligned: answer.isAligned,
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerBubble({
    required String name,
    required String answerText,
    required bool isAligned,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAligned ? _accentPink : _beige,
          width: 1,
        ),
        gradient: isAligned
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accentPink.withOpacity(0.05),
                  _accentOrange.withOpacity(0.05),
                ],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name label
          Text(
            name.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _inkLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Answer text
          Text(
            answerText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchBadge() {
    final isAligned = answer.isAligned;
    final text = isAligned ? 'Aligned!' : 'Different perspectives';
    final emoji = isAligned ? '💕' : '🔍';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isAligned
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _accentPink.withOpacity(0.15),
                    _accentOrange.withOpacity(0.15),
                  ],
                )
              : null,
          color: isAligned ? null : _beige,
        ),
        child: Text(
          '$emoji $text',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isAligned ? _accentPink : _ink,
          ),
        ),
      ),
    );
  }
}
