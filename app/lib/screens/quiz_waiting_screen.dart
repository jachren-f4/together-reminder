import 'package:flutter/material.dart';
import '../models/quiz_session.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import 'quiz_results_screen.dart';
import '../utils/logger.dart';

class QuizWaitingScreen extends StatefulWidget {
  final QuizSession session;

  const QuizWaitingScreen({super.key, required this.session});

  @override
  State<QuizWaitingScreen> createState() => _QuizWaitingScreenState();
}

class _QuizWaitingScreenState extends State<QuizWaitingScreen> {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  late QuizSession _session;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Future<void> _checkSessionStatus() async {
    setState(() => _isChecking = true);

    try {
      // CRITICAL: Check Firebase for updates, not just local storage
      // This ensures we see partner's answers immediately when they submit
      final updatedSession = await _quizService.getSession(_session.id);
      if (updatedSession == null) {
        Logger.warn('Session not found: ${_session.id}', service: 'quiz');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session not found')),
          );
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        _session = updatedSession;
      });

      // If completed, navigate to results
      if (_session.isCompleted) {
        Logger.success('Session completed! Navigating to results...', service: 'quiz');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuizResultsScreen(session: _session),
          ),
        );
        return;
      }

      // Check if both users have answered (waiting for completion calculation)
      final bothAnswered = _session.answers != null && _session.answers!.length >= 2;
      if (bothAnswered && !_session.isCompleted) {
        // Both users answered! Completion calculation should be running.
        Logger.info('Both users answered (${_session.answers!.length} answers) - waiting for completion calculation...', service: 'quiz');
        // Don't navigate yet - wait for lpEarned to be calculated
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Both answered! Results calculating...')),
          );
        }
        return;
      }

      // Log current answer count for debugging
      final answerCount = _session.answers?.length ?? 0;
      Logger.debug('Manual check: $answerCount/2 answers, completed: ${_session.isCompleted}', service: 'quiz');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated! $answerCount/2 partners answered')),
        );
      }

      // If expired, show error and return home
      if (_session.isExpired && !_session.isCompleted) {
        _showExpiredDialog();
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Quiz Expired'),
        content: const Text(
          'This quiz session has expired. You can start a new one anytime!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to intro
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getTimeRemaining() {
    final now = DateTime.now();
    final remaining = _session.expiresAt.difference(now);

    if (remaining.isNegative) return 'Expired';

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hr ${minutes} min';
    } else {
      return '$minutes min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = _storage.getPartner();
    final user = _storage.getUser();
    final partnerAnswered = _session.answers?.length == 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting for Partner'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Opacity(
                      opacity: 0.5 + (0.5 * value),
                      child: const Text(
                        '⏳',
                        style: TextStyle(fontSize: 100),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Status message
              Text(
                'You\'re all done!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                partnerAnswered
                    ? 'Calculating results...'
                    : 'Waiting for ${partner?.name ?? "your partner"} to finish',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 40),

              // Info card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.person,
                      'You',
                      'Answered',
                      theme,
                      Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.person_outline,
                      partner?.name ?? 'Partner',
                      partnerAnswered ? 'Answered' : 'Pending',
                      theme,
                      partnerAnswered ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Timer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Time remaining: ${_getTimeRemaining()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Help text
              Text(
                'You\'ll get a notification when your partner completes the quiz!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              // Check for Updates button
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkSessionStatus,
                icon: Icon(_isChecking ? Icons.hourglass_empty : Icons.refresh),
                label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Close button
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String name,
    String status,
    ThemeData theme,
    Color statusColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status == 'Answered' ? Icons.check_circle : Icons.pending,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
