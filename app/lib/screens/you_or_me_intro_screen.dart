import 'package:flutter/material.dart';
import '../models/you_or_me.dart';
import '../services/storage_service.dart';
import '../config/brand/brand_loader.dart';
import 'you_or_me_game_screen.dart';

/// Intro screen for You or Me game
/// Explains the game concept and starts the session
class YouOrMeIntroScreen extends StatelessWidget {
  final YouOrMeSession session;

  const YouOrMeIntroScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = StorageService();
    final partner = storage.getPartner();

    return Scaffold(
      appBar: AppBar(
        title: const Text('You or Me?'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: BrandLoader().colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'GAME',
                  style: TextStyle(
                    color: BrandLoader().colors.textOnPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Game title
              Text(
                'You or Me?',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair Display',
                ),
              ),

              const SizedBox(height: 32),

              // Goal section
              _buildSection(
                theme: theme,
                title: 'What is this?',
                content: 'A fun comparison game where you answer 10 questions about who\'s more likely to do something, who has a certain trait, or who would handle different scenarios.',
              ),

              const SizedBox(height: 24),

              // How it works section
              _buildSection(
                theme: theme,
                title: 'How it works',
                content: 'You\'ll see questions like "Who\'s more creative?" or "Who would plan the perfect date?" Answer with: You, ${partner?.name ?? 'Your partner'}, Neither, or Both.',
              ),

              const SizedBox(height: 24),

              // Insight section
              _buildSection(
                theme: theme,
                title: 'Why play?',
                content: 'Compare your perspectives! See how you view yourselves and discover where you agree (and where you might be surprised).',
              ),

              const Spacer(),

              // Start button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => YouOrMeGameScreen(session: session),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandLoader().colors.primary,
                    foregroundColor: BrandLoader().colors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Game',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Question count info
              Center(
                child: Text(
                  '10 questions • Takes 2-3 minutes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BrandLoader().colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required String content,
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
        Text(
          content,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: BrandLoader().colors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
