import 'package:flutter/material.dart';
import '../models/quiz_question.dart';
import '../services/daily_pulse_service.dart';
import '../services/storage_service.dart';

/// Daily Pulse Screen - Single daily question with three views
/// 1. Subject View: Answer about yourself
/// 2. Predictor View: Guess partner's answer
/// 3. Results View: See if prediction matched
class DailyPulseScreen extends StatefulWidget {
  final QuizQuestion question;
  final bool isSubject; // Is current user the subject?
  final String partnerName;
  final int? subjectAnswer; // Subject's answer (if already submitted)
  final int? predictorGuess; // Predictor's guess (if already submitted)
  final int currentStreak;
  final bool bothCompleted;

  const DailyPulseScreen({
    super.key,
    required this.question,
    required this.isSubject,
    required this.partnerName,
    this.subjectAnswer,
    this.predictorGuess,
    required this.currentStreak,
    required this.bothCompleted,
  });

  @override
  State<DailyPulseScreen> createState() => _DailyPulseScreenState();
}

class _DailyPulseScreenState extends State<DailyPulseScreen> {
  final DailyPulseService _dailyPulseService = DailyPulseService();
  final StorageService _storage = StorageService();
  int? selectedOptionIndex;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-select if already answered
    if (widget.isSubject && widget.subjectAnswer != null) {
      selectedOptionIndex = widget.subjectAnswer;
    } else if (!widget.isSubject && widget.predictorGuess != null) {
      selectedOptionIndex = widget.predictorGuess;
    }
  }

  /// Get options with "Other" appended
  List<String> get _optionsWithOther {
    final options = List<String>.from(widget.question.options);
    if (!options.any((opt) => opt.toLowerCase().contains('other'))) {
      options.add('Other / Something else');
    }
    return options;
  }

  /// Check if current user has already answered
  bool get _hasAlreadyAnswered {
    if (widget.isSubject) {
      return widget.subjectAnswer != null;
    } else {
      return widget.predictorGuess != null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show results if both completed
    if (widget.bothCompleted) {
      return _buildResultsView();
    }

    // Show appropriate view based on role
    if (widget.isSubject) {
      return _buildSubjectView();
    } else {
      return _buildPredictorView();
    }
  }

  /// Subject View: Answer about yourself
  Widget _buildSubjectView() {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Pulse'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '👤',
                            style: TextStyle(fontSize: 64),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'You\'re the Subject Today',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair Display',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Answer this question about yourself. ${widget.partnerName} will try to predict your answer!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Current streak: 🔥 ${widget.currentStreak} days',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Question Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUESTION OF THE DAY',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatQuestionForSubject(widget.question.question),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Playfair Display',
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Options
                          ..._optionsWithOther.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final isSelected = selectedOptionIndex == index;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: _hasAlreadyAnswered
                                    ? null
                                    : () {
                                        setState(() {
                                          selectedOptionIndex = index;
                                        });
                                      },
                                borderRadius: BorderRadius.circular(16),
                                child: Opacity(
                                  opacity: _hasAlreadyAnswered && !isSelected ? 0.5 : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outline.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? theme.colorScheme.onPrimary
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (_hasAlreadyAnswered && isSelected)
                                          Icon(
                                            Icons.lock,
                                            color: theme.colorScheme.onPrimary,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tip or Already Answered Message
                    if (_hasAlreadyAnswered)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Answer submitted! Waiting for ${widget.partnerName} to make their prediction.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Answer honestly - ${widget.partnerName} will try to guess this later!',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: selectedOptionIndex != null && !_isSubmitting && !_hasAlreadyAnswered
                        ? () => _submitAnswer()
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _hasAlreadyAnswered ? 'Answer Already Submitted' : 'Submit Answer',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _hasAlreadyAnswered
                        ? 'Waiting for ${widget.partnerName}...'
                        : 'Tomorrow it\'s ${widget.partnerName}\'s turn',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Predictor View: Guess partner's answer
  Widget _buildPredictorView() {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Pulse'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '🔮',
                            style: TextStyle(fontSize: 64),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Predict ${widget.partnerName}\'s Answer',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair Display',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.partnerName} already answered. What do you think they chose?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Current streak: 🔥 ${widget.currentStreak} days',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Question Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GUESS ${widget.partnerName.toUpperCase()}\'S ANSWER',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatQuestionForPredictor(widget.question.question, widget.partnerName),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Playfair Display',
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Options
                          ..._optionsWithOther.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final isSelected = selectedOptionIndex == index;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: _hasAlreadyAnswered
                                    ? null
                                    : () {
                                        setState(() {
                                          selectedOptionIndex = index;
                                        });
                                      },
                                borderRadius: BorderRadius.circular(16),
                                child: Opacity(
                                  opacity: _hasAlreadyAnswered && !isSelected ? 0.5 : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outline.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? theme.colorScheme.onPrimary
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (_hasAlreadyAnswered && isSelected)
                                          Icon(
                                            Icons.lock,
                                            color: theme.colorScheme.onPrimary,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: selectedOptionIndex != null && !_isSubmitting && !_hasAlreadyAnswered
                        ? () => _submitAnswer()
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _hasAlreadyAnswered ? 'Prediction Already Submitted' : 'Submit Prediction',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _hasAlreadyAnswered
                        ? 'Waiting for ${widget.partnerName}...'
                        : 'Results revealed when you both complete',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Results View: Show match/mismatch
  Widget _buildResultsView() {
    final theme = Theme.of(context);
    final isMatch = widget.subjectAnswer == widget.predictorGuess;
    final lpEarned = isMatch ? 15 : 10; // Match = 15 LP, Mismatch = 10 LP

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Pulse'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Results Header
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            isMatch ? '✅' : '❌',
                            style: const TextStyle(fontSize: 64),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isMatch
                                ? widget.isSubject
                                    ? '${widget.partnerName} knows you perfectly!'
                                    : 'You knew ${widget.partnerName} perfectly!'
                                : widget.isSubject
                                    ? '${widget.partnerName} learned something new!'
                                    : 'Learn more about ${widget.partnerName}!',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: 'Playfair Display',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isMatch ? 'Perfect match!' : 'Not quite, but that\'s okay!',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '+$lpEarned LP earned',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'New streak:',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '🔥 ${widget.currentStreak + 1} days',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Question Recap
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question:',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.question.question,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${widget.partnerName} answered:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _optionsWithOther[widget.subjectAnswer!],
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You predicted:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMatch
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _optionsWithOther[widget.predictorGuess!],
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isMatch
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                                Text(
                                  isMatch ? '✓' : '✗',
                                  style: TextStyle(
                                    color: isMatch
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onErrorContainer,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Next pulse in 23 hours',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format question for subject (first person)
  String _formatQuestionForSubject(String question) {
    // Replace patterns to make it about "YOU"
    return question
        .replaceAll('your ', 'YOUR ')
        .replaceAll('you ', 'YOU ')
        .replaceAll('My ', 'YOUR ')
        .replaceAll('my ', 'your ');
  }

  /// Format question for predictor (third person with partner name)
  String _formatQuestionForPredictor(String question, String partnerName) {
    // Replace patterns to make it about the PARTNER
    return question
        .replaceAll('your ', '$partnerName\'s ')
        .replaceAll('you ', '$partnerName ')
        .replaceAll('My ', '$partnerName\'s ')
        .replaceAll('my ', '$partnerName\'s ')
        .replaceAll('YOUR ', '$partnerName\'s ')
        .replaceAll('YOU ', '$partnerName ');
  }

  /// Submit answer to Daily Pulse
  Future<void> _submitAnswer() async {
    if (selectedOptionIndex == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _storage.getUser();
      if (user == null) {
        throw Exception('User not found');
      }

      // Submit answer via service
      await _dailyPulseService.submitAnswer(user.id, selectedOptionIndex!);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isSubject
                ? 'Answer submitted! Waiting for ${widget.partnerName} to predict...'
                : 'Prediction submitted! Waiting for ${widget.partnerName} to answer...',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Pop back to activities screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting answer: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
