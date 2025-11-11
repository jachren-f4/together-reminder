import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../models/quiz_session.dart';
import 'quiz_question_screen.dart';
import 'quiz_waiting_screen.dart';

class QuizIntroScreen extends StatefulWidget {
  const QuizIntroScreen({super.key});

  @override
  State<QuizIntroScreen> createState() => _QuizIntroScreenState();
}

class _QuizIntroScreenState extends State<QuizIntroScreen> {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  void _checkActiveSession() {
    final activeSession = _quizService.getActiveSession();
    if (activeSession != null) {
      // Navigate to appropriate screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = _storage.getUser();
        if (user != null && activeSession.hasUserAnswered(user.id)) {
          // User already answered, show waiting screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => QuizWaitingScreen(session: activeSession),
            ),
          );
        } else {
          // User needs to answer
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => QuizQuestionScreen(session: activeSession),
            ),
          );
        }
      });
    }
  }

  Future<void> _startQuiz() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _quizService.startQuizSession();

      if (!mounted) return;

      // Navigate to question screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuizQuestionScreen(session: session),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedSessions = _quizService.getCompletedSessions();
    final avgMatch = _quizService.getAverageMatchPercentage();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Couple Quiz'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Text(
                      '🧩',
                      style: TextStyle(fontSize: 80),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ready to Start?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair Display',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'ll answer 5 questions about yourself.\nThen ${_storage.getPartner()?.name ?? 'your partner'} will try to predict your answers!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Role explanation card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person,
                            color: theme.colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are the SUBJECT',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How it works:',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint('Answer honestly about yourself'),
                    _buildBulletPoint('${_storage.getPartner()?.name ?? 'Your partner'} sees your questions later'),
                    _buildBulletPoint('They try to predict your answers'),
                    _buildBulletPoint('See how well they know you!'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Info cards
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.1),
                      theme.colorScheme.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.military_tech, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Potential reward',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '10-50 LP',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair Display',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on prediction accuracy',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stats (if any completed quizzes)
              if (completedSessions.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Stats',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            '${completedSessions.length}',
                            'Completed',
                            theme,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          _buildStatItem(
                            '${avgMatch.round()}%',
                            'Avg Match',
                            theme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const Spacer(),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Start button
              FilledButton(
                onPressed: _isLoading ? null : _startQuiz,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Start Quiz',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              // Info text
              Text(
                'Both you and your partner will answer the same 5 questions. See how well you match!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 18,
              height: 1.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
