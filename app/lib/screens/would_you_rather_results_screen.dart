import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/storage_service.dart';
import '../services/quiz_service.dart';

/// Results screen for Would You Rather quiz
/// Shows prediction accuracy + alignment bonuses
class WouldYouRatherResultsScreen extends StatefulWidget {
  final QuizSession session;

  const WouldYouRatherResultsScreen({super.key, required this.session});

  @override
  State<WouldYouRatherResultsScreen> createState() => _WouldYouRatherResultsScreenState();
}

class _WouldYouRatherResultsScreenState extends State<WouldYouRatherResultsScreen> {
  final StorageService _storage = StorageService();
  final QuizService _quizService = QuizService();
  late ConfettiController _confettiController;
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;
  late QuizSession _currentSession;
  bool _showDetailedReview = false;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadQuestions();

    // Trigger confetti if good results
    if (_currentSession.matchPercentage != null && _currentSession.matchPercentage! >= 70) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final questions = _currentSession.questionIds
        .map((id) => _storage.getQuizQuestion(id))
        .whereType<QuizQuestion>()
        .toList();

    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = _storage.getPartner();
    final user = _storage.getUser();
    final partnerName = partner?.name ?? 'Partner';
    final userName = user?.name ?? 'You';

    // Check if both partners have completed
    final bothCompleted = _currentSession.answers != null &&
                          _currentSession.answers!.length >= 2 &&
                          _currentSession.predictions != null &&
                          _currentSession.predictions!.length >= 2;

    final matchPercentage = _currentSession.matchPercentage ?? 0;
    final alignmentMatches = _currentSession.alignmentMatches;
    final lpEarned = _currentSession.lpEarned ?? 0;

    // Calculate base LP and alignment bonus
    final alignmentBonus = alignmentMatches * 5;
    final baseLp = lpEarned - alignmentBonus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !bothCompleted
                    ? _buildWaitingScreen(partnerName)
                    : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildEnhancedResultsContent(userName, partnerName, matchPercentage, alignmentMatches, lpEarned),
                  ),
          ),

          // Confetti (keep existing)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Colors.purple,
                Colors.pink,
                Colors.blue,
                Colors.orange,
                Colors.green,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedResultsContent(String userName, String partnerName, int matchPercentage, int alignmentMatches, int lpEarned) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      return const Center(child: Text('User data not found'));
    }

    // Get individual prediction scores
    final predictionScores = _currentSession.predictionScores ?? {};
    final userScore = predictionScores[user.id] ?? 0;
    final partnerScore = predictionScores[partner.pushToken] ?? 0;
    final totalQuestions = _questions.length;

    // Calculate percentages
    final userPercentage = totalQuestions > 0 ? ((userScore / totalQuestions) * 100).round() : 0;
    final partnerPercentage = totalQuestions > 0 ? ((partnerScore / totalQuestions) * 100).round() : 0;

    // Calculate LP breakdown
    final alignmentBonus = alignmentMatches * 5;
    final baseLp = lpEarned - alignmentBonus;
    final accuracyTier = _getAccuracyTier(matchPercentage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main result card
        _buildMainResultCard(matchPercentage),

        const SizedBox(height: 24),

        // NEW: Detailed Prediction Breakdown
        _buildPredictionBreakdown(userName, partnerName, userScore, partnerScore, userPercentage, partnerPercentage, totalQuestions),

        const SizedBox(height: 24),

        // Alignment section
        _buildAlignmentSection(alignmentMatches, partnerName),

        const SizedBox(height: 24),

        // NEW: Enhanced LP Breakdown
        _buildEnhancedLPBreakdown(lpEarned, baseLp, alignmentBonus, alignmentMatches, accuracyTier, matchPercentage),

        const SizedBox(height: 24),

        // NEW: Question-by-Question Review (Expandable)
        _buildQuestionReview(userName, partnerName),

        const SizedBox(height: 32),

        // Back button
        FilledButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Back to Activities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMainResultCard(int matchPercentage) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade400,
              Colors.purple.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Text(
              '💭',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'Combined Accuracy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$matchPercentage%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getAccuracyMessage(matchPercentage),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionBreakdown(String userName, String partnerName, int userScore, int partnerScore, int userPercentage, int partnerPercentage, int totalQuestions) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Prediction Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // User's prediction
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$userName predicted $partnerName:',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$userScore/$totalQuestions ($userPercentage%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: userPercentage / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),

            const SizedBox(height: 16),

            // Partner's prediction
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$partnerName predicted $userName:',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$partnerScore/$totalQuestions ($partnerPercentage%)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: partnerPercentage / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentSection(int alignmentMatches, String partnerName) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Colors.pink, size: 28),
                const SizedBox(width: 8),
                Text(
                  '$alignmentMatches Shared Preferences',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You and $partnerName chose the same answer on $alignmentMatches question${alignmentMatches == 1 ? "" : "s"}!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedLPBreakdown(int lpEarned, int baseLp, int alignmentBonus, int alignmentMatches, String accuracyTier, int matchPercentage) {
    return Card(
      elevation: 2,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  '+$lpEarned Love Points',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Base Prediction Points
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Base Prediction Points',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '+$baseLp LP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tier: "$accuracyTier" ($matchPercentage% accuracy)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            if (alignmentMatches > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Alignment Bonus ($alignmentMatches × 5)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '+$alignmentBonus LP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bonus for shared preferences',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Earned',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '+$lpEarned LP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionReview(String userName, String partnerName) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) return const SizedBox.shrink();

    final userAnswers = _currentSession.answers?[user.id] ?? [];
    final partnerAnswers = _currentSession.answers?[partner.pushToken] ?? [];
    final userPredictions = _currentSession.predictions?[user.id] ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showDetailedReview = !_showDetailedReview;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.green.shade700, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Question-by-Question Review',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _showDetailedReview ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),
          if (_showDetailedReview) ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final question = _questions[index];
                final userAnswer = index < userAnswers.length ? userAnswers[index] : -1;
                final partnerAnswer = index < partnerAnswers.length ? partnerAnswers[index] : -1;
                final userPrediction = index < userPredictions.length ? userPredictions[index] : -1;

                final predictionCorrect = userAnswer >= 0 && partnerAnswer >= 0 && userPrediction == partnerAnswer;
                final aligned = userAnswer >= 0 && partnerAnswer >= 0 && userAnswer == partnerAnswer;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1}: ${question.question.replaceAll("Would I rather:", "").trim()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAnswerRow('Your answer:', userAnswer >= 0 && userAnswer < question.options.length ? question.options[userAnswer] : '—', Colors.blue),
                      const SizedBox(height: 6),
                      _buildAnswerRow('$partnerName\'s answer:', partnerAnswer >= 0 && partnerAnswer < question.options.length ? question.options[partnerAnswer] : '—', Colors.purple),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Your prediction: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            userPrediction >= 0 && userPrediction < question.options.length ? question.options[userPrediction] : '—',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            predictionCorrect ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color: predictionCorrect ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                      if (aligned) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite, size: 14, color: Colors.pink),
                              const SizedBox(width: 4),
                              Text(
                                'Aligned!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.pink.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerRow(String label, String answer, MaterialColor color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.shade700,
            ),
          ),
        ),
      ],
    );
  }

  String _getAccuracyTier(int percentage) {
    if (percentage >= 90) {
      return 'Exceptional';
    } else if (percentage >= 70) {
      return 'Great';
    } else if (percentage >= 50) {
      return 'Good';
    } else {
      return 'Learning';
    }
  }

  Future<void> _mockAliceCompletion() async {
    final partner = _storage.getPartner();
    if (partner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner not found')),
      );
      return;
    }

    final random = Random();
    final numQuestions = widget.session.questionIds.length;

    // Generate random answers for Alice (0 or 1 for Would You Rather questions)
    final aliceAnswers = List.generate(numQuestions, (_) => random.nextInt(2));

    // Generate random predictions for Alice (what Alice thinks Bob chose)
    final alicePredictions = List.generate(numQuestions, (_) => random.nextInt(2));

    try {
      // Submit Alice's mock answers
      // Use partner's pushToken as their ID since Partner model doesn't have an id field
      await _quizService.submitWouldYouRatherAnswers(
        _currentSession.id,
        partner.pushToken,
        aliceAnswers,
        alicePredictions,
      );

      // Reload the updated session
      final updatedSession = _storage.getQuizSession(_currentSession.id);
      if (updatedSession != null) {
        setState(() {
          _currentSession = updatedSession;
          // Trigger confetti if good results
          if (_currentSession.matchPercentage != null && _currentSession.matchPercentage! >= 70) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _confettiController.play();
            });
          }
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Alice completed! Results calculated.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildWaitingScreen(String partnerName) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Waiting icon
          const Text(
            '⏳',
            style: TextStyle(fontSize: 80),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'Great Job!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          Text(
            'You\'ve completed your predictions!',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          // Waiting card
          Card(
            elevation: 2,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_empty,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Waiting for $partnerName',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$partnerName needs to complete their predictions before we can reveal the results.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back soon to see how well you know each other!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // DEBUG: Mock Alice completing the quiz
          OutlinedButton(
            onPressed: () => _mockAliceCompletion(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.orange.shade600, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bug_report, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text(
                  'DEBUG: Mock Alice Completion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Back button
          FilledButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Back to Activities',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getAccuracyMessage(int percentage) {
    if (percentage >= 90) {
      return 'You know each other incredibly well!';
    } else if (percentage >= 70) {
      return 'Great understanding of each other!';
    } else if (percentage >= 50) {
      return 'Good insights into preferences!';
    } else {
      return 'Still learning each other!';
    }
  }
}
