import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../models/quiz_session.dart';
import 'would_you_rather_screen.dart';
import 'would_you_rather_results_screen.dart';

/// Intro screen for Would You Rather quiz format
class WouldYouRatherIntroScreen extends StatefulWidget {
  const WouldYouRatherIntroScreen({super.key});

  @override
  State<WouldYouRatherIntroScreen> createState() => _WouldYouRatherIntroScreenState();
}

class _WouldYouRatherIntroScreenState extends State<WouldYouRatherIntroScreen> {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  bool _isLoading = false;
  String? _error;
  bool _isUnlocked = false;
  int _totalQuizCount = 0;

  @override
  void initState() {
    super.initState();
    _checkUnlockStatus();
    _checkActiveSession();
  }

  void _checkUnlockStatus() {
    setState(() {
      _isUnlocked = _quizService.isWouldYouRatherUnlocked();
      _totalQuizCount = _quizService.getCompletedSessions().length;
    });
  }

  void _checkActiveSession() {
    final activeSession = _quizService.getActiveSession();
    if (activeSession != null && activeSession.formatType == 'would_you_rather') {
      // Navigate to appropriate screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = _storage.getUser();
        if (user != null && activeSession.hasUserAnswered(user.id)) {
          // User already answered, check if both answered
          if (activeSession.answers != null && activeSession.answers!.length == 2) {
            // Show results
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => WouldYouRatherResultsScreen(
                  session: activeSession,
                ),
              ),
            );
          } else {
            // Waiting for partner
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => WouldYouRatherResultsScreen(
                  session: activeSession,
                ),
              ),
            );
          }
        } else {
          // User needs to answer
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => WouldYouRatherScreen(session: activeSession),
            ),
          );
        }
      });
    }
  }

  Future<void> _startWouldYouRather() async {
    if (!_isUnlocked) {
      setState(() {
        _error = 'Complete ${15 - _totalQuizCount} more quiz${15 - _totalQuizCount == 1 ? "" : "zes"} to unlock Would You Rather';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _quizService.startQuizSession(
        formatType: 'would_you_rather',
      );

      if (!mounted) return;

      // Navigate to Would You Rather screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => WouldYouRatherScreen(session: session),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  int _getWouldYouRatherCount() {
    return _quizService.getCompletedWouldYouRatherCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wyrCount = _getWouldYouRatherCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Would You Rather?'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    const Text(
                      '💭',
                      style: TextStyle(fontSize: 80),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Would You Rather?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover preferences & predict choices',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Info Cards
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How It Works',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.quiz, '7 "Would You Rather" scenarios'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.touch_app, 'Answer for yourself'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.psychology, 'Predict your partner\'s choice'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.favorite, 'Earn 25-50 LP + alignment bonuses'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Unlock Progress Card (if not unlocked)
              if (!_isUnlocked)
                Card(
                  elevation: 2,
                  color: Colors.purple.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, color: Colors.purple.shade700, size: 32),
                            const SizedBox(width: 12),
                            Text(
                              'Locked',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Complete 15 quizzes to unlock',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        // Progress bar
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: _totalQuizCount / 15,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade700),
                              minHeight: 8,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_totalQuizCount / 15 Quizzes completed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Stats Card (if unlocked and has completed Would You Rather)
              if (_isUnlocked && wyrCount > 0)
                Card(
                  elevation: 2,
                  color: Colors.purple.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology, color: Colors.purple, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$wyrCount Would You Rather${wyrCount == 1 ? "" : "s"} Completed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                            Text(
                              'Keep discovering each other!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Start Button
              FilledButton(
                onPressed: (_isLoading || !_isUnlocked) ? null : _startWouldYouRather,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: !_isUnlocked ? Colors.grey.shade400 : Colors.purple,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(!_isUnlocked ? Icons.lock : Icons.psychology),
                          const SizedBox(width: 8),
                          Text(
                            !_isUnlocked ? 'Locked - Complete More Quizzes' : 'Start Would You Rather',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.purple.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
