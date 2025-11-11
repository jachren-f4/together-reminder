import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/quiz_expansion.dart';
import '../models/quiz_question.dart';
import '../services/daily_pulse_service.dart';
import '../services/storage_service.dart';

/// Results screen for Daily Pulse
/// Shows match/no match with celebration animation
class DailyPulseResultsScreen extends StatefulWidget {
  final QuizDailyPulse pulse;
  final QuizQuestion question;
  final String partnerName;

  const DailyPulseResultsScreen({
    super.key,
    required this.pulse,
    required this.question,
    required this.partnerName,
  });

  @override
  State<DailyPulseResultsScreen> createState() => _DailyPulseResultsScreenState();
}

class _DailyPulseResultsScreenState extends State<DailyPulseResultsScreen> with SingleTickerProviderStateMixin {
  final DailyPulseService _dailyPulseService = DailyPulseService();
  final StorageService _storage = StorageService();
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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

    // Trigger animations
    _animationController.forward();
    if (widget.pulse.isMatch) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Get options with "Other" appended
  List<String> get _optionsWithOther {
    final options = List<String>.from(widget.question.options);
    if (!options.any((opt) => opt.toLowerCase().contains('other'))) {
      options.add('Other / Something else');
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _storage.getUser();
    final isUserSubject = widget.pulse.subjectUserId == user?.id;
    final currentStreak = _dailyPulseService.getCurrentStreak();

    // Get answers
    final subjectAnswer = widget.pulse.answers?[widget.pulse.subjectUserId];

    String? predictorId;
    try {
      predictorId = widget.pulse.answers?.keys.firstWhere(
        (id) => id != widget.pulse.subjectUserId,
        orElse: () => '',
      );
    } catch (e) {
      predictorId = null;
    }

    int? predictorGuess;
    if (predictorId != null && predictorId.isNotEmpty) {
      predictorGuess = widget.pulse.answers?[predictorId];
    }

    final subjectName = isUserSubject ? 'You' : widget.partnerName;
    final predictorName = isUserSubject ? widget.partnerName : 'You';

    return Scaffold(
      backgroundColor: widget.pulse.isMatch ? Colors.green.shade50 : Colors.orange.shade50,
      appBar: AppBar(
        title: const Text('Daily Pulse Results'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Confetti overlay
          if (widget.pulse.isMatch)
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
                        color: widget.pulse.isMatch ? Colors.green : Colors.orange,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.pulse.isMatch ? Colors.green : Colors.orange).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.pulse.isMatch ? Icons.check_circle : Icons.help_outline,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Result Text
                Text(
                  widget.pulse.isMatch ? 'Perfect Match! 💕' : 'Not Quite! 🤔',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.pulse.isMatch ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.pulse.isMatch
                      ? 'You two are in sync!'
                      : 'Still learning about each other!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 32),

                // Question Card
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
                          'Today\'s Question',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.question.question,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Answers Section
                _buildAnswersSection(
                  theme,
                  subjectName,
                  predictorName,
                  subjectAnswer,
                  predictorGuess,
                ),

                const SizedBox(height: 24),

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
                              '+${widget.pulse.lpAwarded} LP',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.pulse.isMatch ? 'Perfect Match Bonus!' : 'Participation Points',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Streak Card
                if (currentStreak > 0) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    color: Colors.orange.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$currentStreak Day Streak!',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                'Keep it going!',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Done Button
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
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

  Widget _buildAnswersSection(
    ThemeData theme,
    String subjectName,
    String predictorName,
    int? subjectAnswer,
    int? predictorGuess,
  ) {
    return Card(
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
              'Answers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Subject's answer
            _buildAnswerRow(
              theme,
              '$subjectName answered:',
              subjectAnswer != null ? _optionsWithOther[subjectAnswer] : 'No answer',
              Colors.blue.shade100,
              Colors.blue.shade700,
            ),

            const SizedBox(height: 12),

            // Predictor's guess
            _buildAnswerRow(
              theme,
              '$predictorName predicted:',
              predictorGuess != null ? _optionsWithOther[predictorGuess] : 'No prediction',
              Colors.purple.shade100,
              Colors.purple.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerRow(
    ThemeData theme,
    String label,
    String answer,
    Color bgColor,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            answer,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
