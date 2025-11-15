import 'package:flutter/material.dart';
import '../models/quiz_session.dart';
import '../services/storage_service.dart';
import 'quiz_question_screen.dart';

/// Intro screen for affirmation-style quizzes
/// Shows the quiz name, goal, research context, and how it works
class AffirmationIntroScreen extends StatelessWidget {
  final QuizSession session;

  const AffirmationIntroScreen({
    super.key,
    required this.session,
  });

  String _getResearchContext(String category) {
    // Map categories to research contexts
    switch (category) {
      case 'trust':
        return 'Research in relationship psychology shows that trust is built through consistent, small positive interactions and mutual understanding.';
      case 'emotional_support':
        return 'Studies show that couples who regularly express emotional support report higher relationship satisfaction and stronger bonds.';
      case 'commitment':
        return 'Research indicates that couples who align on commitment levels experience greater relationship stability and satisfaction.';
      case 'intimacy':
        return 'Intimacy research demonstrates that emotional closeness is just as important as physical connection for long-term relationship health.';
      case 'relationship_satisfaction':
        return 'A 2023 study in Personal Relationships found that regular check-ins on satisfaction levels help couples identify and address concerns early.';
      case 'shared_values':
        return 'Research shows that couples with aligned values and expectations experience fewer conflicts and greater long-term compatibility.';
      default:
        return 'Research shows that regular self-reflection strengthens relationship awareness and promotes healthy communication.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = StorageService();
    final partner = storage.getPartner();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Affirmation'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'QUIZ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quiz title
              Text(
                session.quizName ?? 'Affirmation Quiz',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair Display',
                ),
              ),

              const SizedBox(height: 32),

              // Goal section
              _buildSection(
                theme: theme,
                title: 'Goal',
                content: 'Gain awareness of strength and growth areas in how you connect emotionally as a couple.',
              ),

              const SizedBox(height: 24),

              // Research section
              _buildSection(
                theme: theme,
                title: 'Research',
                content: _getResearchContext(session.category ?? 'trust'),
              ),

              const SizedBox(height: 24),

              // How it works section
              _buildSection(
                theme: theme,
                title: 'How it works',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBulletPoint(theme, 'Rate 5 statements about your relationship'),
                    const SizedBox(height: 8),
                    _buildBulletPoint(theme, '${partner?.name ?? 'Your partner'} completes the same quiz'),
                    const SizedBox(height: 8),
                    _buildBulletPoint(theme, 'Reflect on your answers together'),
                    const SizedBox(height: 8),
                    _buildBulletPoint(theme, 'Earn 30 LP when both complete'),
                  ],
                ),
              ),

              const Spacer(),

              // CTA button
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => QuizQuestionScreen(session: session),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required dynamic content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (content is String)
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          )
        else
          content,
      ],
    );
  }

  Widget _buildBulletPoint(ThemeData theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
