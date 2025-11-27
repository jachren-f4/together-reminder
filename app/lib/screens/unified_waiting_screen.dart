import 'dart:async';
import 'package:flutter/material.dart';
import '../models/base_session.dart';
import '../models/quest_type_config.dart';
import '../models/quiz_session.dart';
import '../models/you_or_me.dart';
import '../services/storage_service.dart';
import '../services/quiz_service.dart';
import '../services/you_or_me_service.dart';
import '../utils/logger.dart';
import '../config/brand/brand_loader.dart';
import 'unified_results_screen.dart';

/// Unified waiting screen for all quest types
/// Configurable polling, partner status, and navigation
class UnifiedWaitingScreen extends StatefulWidget {
  final BaseSession session;
  final WaitingConfig config;
  final ResultsConfig resultsConfig;
  final Widget Function(BaseSession) resultsContentBuilder;

  const UnifiedWaitingScreen({
    super.key,
    required this.session,
    required this.config,
    required this.resultsConfig,
    required this.resultsContentBuilder,
  });

  @override
  State<UnifiedWaitingScreen> createState() => _UnifiedWaitingScreenState();
}

class _UnifiedWaitingScreenState extends State<UnifiedWaitingScreen>
    with TickerProviderStateMixin {
  final StorageService _storage = StorageService();
  Timer? _pollingTimer;
  late BaseSession _session;
  bool _isChecking = false;
  String? _error;

  // Animation controllers
  late AnimationController _breatheController;
  late AnimationController _dotsController;
  late AnimationController _messageController;

  // Current message index for rotation
  int _currentMessageIndex = 0;
  final List<String> _waitingMessages = [
    'Good things take time...',
    'Your partner is on their way...',
    'Almost there...',
    'Patience is a virtue...',
    'The wait will be worth it...',
  ];

  @override
  void initState() {
    super.initState();
    _session = widget.session;

    // Breathing animation for icon area
    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Dots animation
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Message rotation
    _messageController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _startMessageRotation();

    // Start auto-polling if configured
    if (widget.config.pollingType == PollingType.auto) {
      _startAutoPolling();
    }
  }

  void _startMessageRotation() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _messageController.forward().then((_) {
        if (!mounted) return;
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _waitingMessages.length;
        });
        _messageController.reverse().then((_) {
          _startMessageRotation();
        });
      });
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _breatheController.dispose();
    _dotsController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _startAutoPolling() {
    final interval = widget.config.pollingInterval ?? const Duration(seconds: 5);
    _pollingTimer = Timer.periodic(interval, (_) => _checkStatus());

    // Also check immediately
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    if (_isChecking || !mounted) return;

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      if (widget.config.isDualSession) {
        await _checkDualSession();
      } else {
        await _checkSingleSession();
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
      Logger.error('Status check failed', error: e, stackTrace: stackTrace, service: 'unified');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _checkSingleSession() async {
    // Classic or Affirmation Quiz
    final service = QuizService();
    final updated = await service.getSession(_session.id);

    if (updated == null) {
      setState(() => _error = 'Session not found');
      Logger.warn('Session not found: ${_session.id}', service: 'unified');
      return;
    }

    if (!mounted) return;

    setState(() => _session = updated);

    if (updated.isCompleted) {
      Logger.success('Session completed, navigating to results', service: 'unified');
      _navigateToResults();
    }
  }

  Future<void> _checkDualSession() async {
    // You or Me - check partner's separate session
    final partner = _storage.getPartner();
    if (partner == null) {
      setState(() => _error = 'Partner not found');
      return;
    }

    // Extract timestamp from session ID (format: youorme_{userId}_{timestamp})
    final parts = _session.id.split('_');
    if (parts.length < 3) {
      setState(() => _error = 'Invalid session ID format');
      Logger.error('Invalid You or Me session ID: ${_session.id}', service: 'unified');
      return;
    }

    final timestamp = parts.last;
    final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';

    Logger.debug('Checking partner session: $partnerSessionId', service: 'unified');

    final service = YouOrMeService();
    final partnerSession = await service.getSession(partnerSessionId, forceRefresh: true);

    if (partnerSession != null &&
        partnerSession.answers != null &&
        (_session as YouOrMeSession).answers != null) {
      Logger.success('Both users answered, navigating to results', service: 'unified');
      _navigateToResults();
    }
  }

  void _navigateToResults() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => UnifiedResultsScreen(
          session: _session,
          config: widget.resultsConfig,
          contentBuilder: widget.resultsContentBuilder,
        ),
      ),
    );
  }

  String _getPartnerStatus() {
    if (_session is QuizSession) {
      final quizSession = _session as QuizSession;
      final answerCount = quizSession.answers?.length ?? 0;
      return '$answerCount/2 answered';
    } else if (_session is YouOrMeSession) {
      final youOrMeSession = _session as YouOrMeSession;
      return youOrMeSession.areBothUsersAnswered() ? 'Both answered' : 'Waiting for partner';
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = _storage.getPartner();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting for Partner'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Elegant dots animation
              _buildElegantDots(theme),

              const SizedBox(height: 24),

              // Waiting message (static title)
              Text(
                widget.config.waitingMessage,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Rotating message with crossfade
              AnimatedBuilder(
                animation: _messageController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 1.0 - _messageController.value,
                    child: Text(
                      _waitingMessages[_currentMessageIndex],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Status info with breathing animation
              AnimatedBuilder(
                animation: _breatheController,
                builder: (context, child) {
                  final scale = 1.0 + (0.02 * Curves.easeInOut.transform(_breatheController.value));
                  final yOffset = -4.0 * Curves.easeInOut.transform(
                    _breatheController.value < 0.5
                        ? _breatheController.value * 2
                        : 2.0 - _breatheController.value * 2,
                  );
                  return Transform.translate(
                    offset: Offset(0, yOffset),
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  );
                },
                child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getPartnerStatus(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),

                    // Time remaining (if configured)
                    if (widget.config.showTimeRemaining) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getTimeRemaining(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ),

              const SizedBox(height: 32),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),

              // Manual refresh button (if configured)
              if (widget.config.pollingType == PollingType.manual)
                FilledButton.icon(
                  onPressed: _isChecking ? null : _checkStatus,
                  icon: _isChecking
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(BrandLoader().colors.textOnPrimary),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),

              // Auto-polling indicator
              if (widget.config.pollingType == PollingType.auto)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Auto-checking every ${widget.config.pollingInterval?.inSeconds ?? 5}s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

              const Spacer(),

              // Hint text
              Text(
                'You\'ll be notified when your partner completes the quest',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElegantDots(ThemeData theme) {
    return SizedBox(
      width: 80,
      height: 40,
      child: AnimatedBuilder(
        animation: _dotsController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              // Stagger each dot's animation
              final offset = index * 0.33;
              final animValue = (_dotsController.value + offset) % 1.0;

              // Create a smooth wave: 0->1->0 over the animation cycle
              final wave = animValue < 0.5
                  ? animValue * 2
                  : 2.0 - (animValue * 2);

              // Apply easing
              final easedWave = Curves.easeInOut.transform(wave);

              // Scale: 0.6 -> 1.0 -> 0.6
              final scale = 0.6 + (0.4 * easedWave);
              // Opacity: 0.3 -> 1.0 -> 0.3
              final opacity = 0.3 + (0.7 * easedWave);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  String _getTimeRemaining() {
    if (_session.isExpired) return 'Expired';

    final expiryTime = DateTime(
      _session.createdAt.year,
      _session.createdAt.month,
      _session.createdAt.day,
      23,
      59,
      59,
    );

    final remaining = expiryTime.difference(DateTime.now());

    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m remaining';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m remaining';
    } else {
      return 'Less than 1m remaining';
    }
  }
}
