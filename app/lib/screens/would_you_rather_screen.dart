import 'package:flutter/material.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/storage_service.dart';
import '../services/quiz_service.dart';
import 'would_you_rather_results_screen.dart';

/// Two-phase Would You Rather screen
/// Phase 1: Answer questions about yourself
/// Phase 2: Predict what your partner would choose
class WouldYouRatherScreen extends StatefulWidget {
  final QuizSession session;

  const WouldYouRatherScreen({super.key, required this.session});

  @override
  State<WouldYouRatherScreen> createState() => _WouldYouRatherScreenState();
}

class _WouldYouRatherScreenState extends State<WouldYouRatherScreen> {
  final StorageService _storage = StorageService();
  final QuizService _quizService = QuizService();

  int _currentQuestionIndex = 0;
  bool _isPhase1 = true; // Phase 1: Answer about self, Phase 2: Predict partner
  bool _showPhaseTransition = false; // Show transition screen between phases
  List<int> _myAnswers = [];
  List<int> _myPredictions = [];
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    // Load questions from storage
    final questions = widget.session.questionIds
        .map((id) => _storage.getQuizQuestion(id))
        .whereType<QuizQuestion>()
        .toList();

    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      if (_isPhase1) {
        // Phase 1: User answering about themselves
        if (_myAnswers.length == _currentQuestionIndex) {
          _myAnswers.add(optionIndex);
        } else {
          _myAnswers[_currentQuestionIndex] = optionIndex;
        }
      } else {
        // Phase 2: User predicting partner's answer
        if (_myPredictions.length == _currentQuestionIndex) {
          _myPredictions.add(optionIndex);
        } else {
          _myPredictions[_currentQuestionIndex] = optionIndex;
        }
      }
    });

    // Auto-advance after selection
    Future.delayed(const Duration(milliseconds: 300), () {
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      // End of current phase
      if (_isPhase1) {
        // Show transition screen before Phase 2
        setState(() {
          _showPhaseTransition = true;
        });
      } else {
        // Both phases complete - submit
        _submitAnswers();
      }
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _startPhase2() {
    setState(() {
      _isPhase1 = false;
      _showPhaseTransition = false;
      _currentQuestionIndex = 0;
    });
  }

  Future<void> _submitAnswers() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _storage.getUser();
      if (user == null) {
        throw Exception('User not found');
      }

      // Submit both answers and predictions
      await _quizService.submitWouldYouRatherAnswers(
        widget.session.id,
        user.id,
        _myAnswers,
        _myPredictions,
      );

      if (!mounted) return;

      // Navigate to results
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => WouldYouRatherResultsScreen(
            session: _storage.getQuizSession(widget.session.id)!,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting answers: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Would You Rather?'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Would You Rather?'),
        ),
        body: const Center(
          child: Text('No questions available'),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Your partner';

    // Get current answer (if any)
    final currentAnswers = _isPhase1 ? _myAnswers : _myPredictions;
    final hasAnswered = currentAnswers.length > _currentQuestionIndex;
    final selectedIndex = hasAnswered ? currentAnswers[_currentQuestionIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPhase1 ? 'Answer About Yourself' : 'Predict $partnerName'),
        centerTitle: true,
      ),
      body: _showPhaseTransition
          ? _buildPhaseTransitionScreen(partnerName)
          : _isSubmitting
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Submitting your answers...'),
                    ],
                  ),
                )
              : SafeArea(
              child: Column(
                children: [
                  // Progress indicator
                  _buildProgressIndicator(),

                  // Question area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Phase indicator
                          _buildPhaseIndicator(partnerName),

                          const SizedBox(height: 24),

                          // Question card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  const Text(
                                    '💭',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _formatQuestion(currentQuestion.question, partnerName),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Options
                          ...currentQuestion.options.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final isSelected = selectedIndex == index;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildOptionCard(
                                option,
                                isSelected,
                                () => _selectAnswer(index),
                              ),
                            );
                          }).toList(),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // Navigation buttons
                  _buildNavigationButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _isPhase1 ? 'Phase 1 of 2' : 'Phase 2 of 2',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator(String partnerName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isPhase1 ? Colors.blue.shade50 : Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPhase1 ? Colors.blue.shade200 : Colors.purple.shade200,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isPhase1 ? Icons.person : Icons.psychology,
            color: _isPhase1 ? Colors.blue.shade700 : Colors.purple.shade700,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPhase1 ? 'About You' : 'About $partnerName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isPhase1 ? Colors.blue.shade700 : Colors.purple.shade700,
                  ),
                ),
                Text(
                  _isPhase1
                      ? 'Choose what YOU would rather do'
                      : 'Predict what $partnerName would choose',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuestion(String question, String partnerName) {
    if (_isPhase1) {
      // Phase 1: "Would I rather..."
      return question;
    } else {
      // Phase 2: "Would [Partner] rather..."
      return question.replaceAll('Would I rather:', 'Would $partnerName rather:');
    }
  }

  Widget _buildOptionCard(String option, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.purple.shade600 : Colors.grey.shade300,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.purple.shade600 : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.purple.shade600 : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.purple.shade900 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final currentAnswers = _isPhase1 ? _myAnswers : _myPredictions;
    final hasAnswered = currentAnswers.length > _currentQuestionIndex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          if (_currentQuestionIndex > 0 || !_isPhase1)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousQuestion,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),

          if (_currentQuestionIndex > 0 || !_isPhase1)
            const SizedBox(width: 12),

          // Next button (disabled if not answered)
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: hasAnswered ? _nextQuestion : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentQuestionIndex == _questions.length - 1
                        ? (_isPhase1 ? 'Next Phase' : 'Submit')
                        : 'Next',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(_currentQuestionIndex == _questions.length - 1 && !_isPhase1
                      ? Icons.check
                      : Icons.arrow_forward),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseTransitionScreen(String partnerName) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success icon
            const Text(
              '✅',
              style: TextStyle(fontSize: 80),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Congratulations
            const Text(
              'Phase 1 Complete!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              'Great! You\'ve shared your preferences.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Phase 2 explanation card
            Card(
              elevation: 2,
              color: Colors.purple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.purple.shade200,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.psychology,
                          color: Colors.purple.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Phase 2: Prediction Time',
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
                      'Now predict how $partnerName would answer the same questions!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How well do you know each other?',
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

            const SizedBox(height: 48),

            // Start Phase 2 button
            FilledButton(
              onPressed: _startPhase2,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Start Predicting $partnerName',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
