import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../models/quiz_session.dart';
import 'speed_round_screen.dart';
import 'speed_round_results_screen.dart';

/// Intro screen for Speed Round quiz format
class SpeedRoundIntroScreen extends StatefulWidget {
  const SpeedRoundIntroScreen({super.key});

  @override
  State<SpeedRoundIntroScreen> createState() => _SpeedRoundIntroScreenState();
}

class _SpeedRoundIntroScreenState extends State<SpeedRoundIntroScreen> {
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
    if (activeSession != null && activeSession.formatType == 'speed_round') {
      // Navigate to appropriate screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = _storage.getUser();
        if (user != null && activeSession.hasUserAnswered(user.id)) {
          // User already answered, check if both answered
          if (activeSession.answers != null && activeSession.answers!.length == 2) {
            // Show results
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => SpeedRoundResultsScreen(
                  session: activeSession,
                  userAnswers: activeSession.answers![user.id] ?? [],
                ),
              ),
            );
          } else {
            // Waiting for partner
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => SpeedRoundResultsScreen(
                  session: activeSession,
                  userAnswers: activeSession.answers![user.id] ?? [],
                ),
              ),
            );
          }
        } else {
          // User needs to answer
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SpeedRoundScreen(session: activeSession),
            ),
          );
        }
      });
    }
  }

  Future<void> _startSpeedRound() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await _quizService.startQuizSession(
        formatType: 'speed_round',
      );

      if (!mounted) return;

      // Navigate to Speed Round screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SpeedRoundScreen(session: session),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  int _getSpeedRoundCount() {
    return _quizService
        .getCompletedSessions()
        .where((s) => s.formatType == 'speed_round')
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speedRoundCount = _getSpeedRoundCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speed Round'),
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
                    const Text(
                      '⚡',
                      style: TextStyle(fontSize: 80),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Speed Round',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fast-paced knowledge test',
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
                      _buildInfoRow(Icons.quiz, '10 rapid-fire questions'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.timer, '10 seconds per question'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.local_fire_department, 'Streak bonus: +5 LP per 3 consecutive correct'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.favorite, 'Earn 20-40 LP + streak bonuses'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Stats Card
              if (speedRoundCount > 0)
                Card(
                  elevation: 2,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt, color: Colors.blue, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$speedRoundCount Speed Round${speedRoundCount == 1 ? "" : "s"} Completed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              'Keep the lightning pace!',
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

              const Spacer(),

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
                onPressed: _isLoading ? null : _startSpeedRound,
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt),
                          SizedBox(width: 8),
                          Text(
                            'Start Speed Round',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        Icon(icon, size: 20, color: Colors.blue.shade700),
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
