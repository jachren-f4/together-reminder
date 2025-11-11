import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/love_point_service.dart';

/// Results screen for Speed Round with streak bonus breakdown
class SpeedRoundResultsScreen extends StatefulWidget {
  final QuizSession session;
  final List<int> userAnswers;

  const SpeedRoundResultsScreen({
    super.key,
    required this.session,
    required this.userAnswers,
  });

  @override
  State<SpeedRoundResultsScreen> createState() => _SpeedRoundResultsScreenState();
}

class _SpeedRoundResultsScreenState extends State<SpeedRoundResultsScreen> with SingleTickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();

  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late List<QuizQuestion> _questions;

  bool _bothAnswered = false;
  int _correctCount = 0;
  int _matchPercentage = 0;
  List<int> _streakBonuses = [];
  int _totalStreakBonus = 0;
  int _baseLp = 0;
  int _totalLp = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _questions = _quizService.getSessionQuestions(widget.session);
    _calculateResults();
    _animationController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _calculateResults() {
    final user = _storage.getUser();
    if (user == null) return;

    // Check if both users answered
    _bothAnswered = widget.session.answers != null &&
                     widget.session.answers!.length == 2;

    if (_bothAnswered) {
      // Calculate match percentage and streak bonuses
      final userId = user.id;
      final partnerId = widget.session.answers!.keys
          .firstWhere((id) => id != userId, orElse: () => '');

      if (partnerId.isNotEmpty) {
        final userAnswers = widget.session.answers![userId] ?? [];
        final partnerAnswers = widget.session.answers![partnerId] ?? [];

        // Calculate correct answers
        int consecutiveCorrect = 0;
        for (int i = 0; i < userAnswers.length && i < partnerAnswers.length; i++) {
          if (userAnswers[i] == partnerAnswers[i] && userAnswers[i] != -1) {
            _correctCount++;
            consecutiveCorrect++;

            // Check for streak bonus (every 3 consecutive)
            if (consecutiveCorrect == 3) {
              _streakBonuses.add(i + 1); // Question number
              _totalStreakBonus += 5;
              consecutiveCorrect = 0; // Reset streak
            }
          } else {
            consecutiveCorrect = 0; // Break streak
          }
        }

        // Calculate percentage
        _matchPercentage = ((_correctCount / _questions.length) * 100).round();

        // Calculate LP
        // Base LP: 20-40 based on match percentage (Speed Round reward)
        _baseLp = 20 + ((_matchPercentage / 100) * 20).round();
        _totalLp = _baseLp + _totalStreakBonus;

        // Award LP (fire and forget)
        LovePointService.awardPoints(
          amount: _totalLp,
          reason: 'speed_round',
          relatedId: widget.session.id,
        );

        // Show confetti for good performance
        if (_matchPercentage >= 70) {
          _confettiController.play();
        }
      }
    }
  }

  bool get _isSubject {
    final user = _storage.getUser();
    if (user == null) return false;
    return widget.session.isUserSubject(user.id);
  }

  String _getSpeedRoundMessage(int percentage) {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Your partner';

    if (_isSubject) {
      if (percentage >= 90) return '$partnerName nailed it! Lightning fast!';
      if (percentage >= 70) return '$partnerName kept up with you!';
      if (percentage >= 50) return '$partnerName learned quickly!';
      return '$partnerName is getting faster!';
    } else {
      if (percentage >= 90) return 'Lightning fast accuracy!';
      if (percentage >= 70) return 'Great speed and knowledge!';
      if (percentage >= 50) return 'Solid performance under pressure!';
      return 'Speed round is challenging!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Your partner';

    if (!_bothAnswered) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Speed Round Complete'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  'Waiting for $partnerName',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your answers are saved! Check back when $partnerName completes the Speed Round.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _matchPercentage >= 70 ? Colors.green.shade50 : Colors.orange.shade50,
      appBar: AppBar(
        title: const Text('Speed Round Results'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Confetti overlay
          if (_matchPercentage >= 70)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                colors: const [
                  Colors.red,
                  Colors.pink,
                  Colors.purple,
                  Colors.orange,
                  Colors.yellow,
                ],
              ),
            ),

          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Result Icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _matchPercentage >= 70 ? Colors.green : Colors.orange,
                        boxShadow: [
                          BoxShadow(
                            color: (_matchPercentage >= 70 ? Colors.green : Colors.orange)
                                .withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.bolt,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Match percentage
                Text(
                  '$_matchPercentage% Match!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _matchPercentage >= 70 ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _getSpeedRoundMessage(_matchPercentage),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 32),

                // Score breakdown
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
                          'Speed Round Stats',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildStatRow(
                          Icons.check_circle,
                          'Correct Answers',
                          '$_correctCount/${_questions.length}',
                          Colors.green,
                        ),

                        if (_streakBonuses.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildStatRow(
                            Icons.local_fire_department,
                            'Streak Bonuses',
                            '${_streakBonuses.length} × 5 LP',
                            Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: Text(
                              'Got 3 in a row on questions: ${_streakBonuses.join(", ")}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // LP Earned Card
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
                            Icon(
                              Icons.favorite,
                              color: Colors.purple.shade400,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '+$_totalLp LP',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Base: $_baseLp LP${_totalStreakBonus > 0 ? " + Streaks: $_totalStreakBonus LP" : ""}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Done Button
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
