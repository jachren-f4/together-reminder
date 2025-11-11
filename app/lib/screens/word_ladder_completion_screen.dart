import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/ladder_session.dart';
import '../services/ladder_service.dart';

class WordLadderCompletionScreen extends StatefulWidget {
  final String sessionId;

  const WordLadderCompletionScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<WordLadderCompletionScreen> createState() =>
      _WordLadderCompletionScreenState();
}

class _WordLadderCompletionScreenState
    extends State<WordLadderCompletionScreen> {
  final LadderService _ladderService = LadderService();
  late ConfettiController _confettiController;
  LadderSession? _session;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadSession();
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _loadSession() {
    setState(() {
      _session = _ladderService.getLadderSession(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ladder Complete')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isOptimal = _session!.optimalSteps != null &&
        _session!.stepCount <= _session!.optimalSteps!;

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Trophy icon
                  Icon(
                    Icons.emoji_events,
                    size: 120,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Ladder Complete!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'You and your partner worked together beautifully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Transformation
                  Card(
                    elevation: 4,
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _session!.startWord,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(Icons.arrow_forward, size: 28),
                          ),
                          Text(
                            _session!.endWord,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _StatRow(
                            icon: Icons.star,
                            label: 'Love Points Earned',
                            value: '+${_session!.lpEarned} LP',
                            highlight: true,
                          ),
                          const Divider(height: 24),
                          _StatRow(
                            icon: Icons.show_chart,
                            label: 'Steps Taken',
                            value: _session!.stepCount.toString(),
                          ),
                          if (_session!.optimalSteps != null) ...[
                            const Divider(height: 24),
                            _StatRow(
                              icon: isOptimal ? Icons.check_circle : Icons.info,
                              label: 'Optimal Steps',
                              value: _session!.optimalSteps.toString(),
                              highlight: isOptimal,
                            ),
                          ],
                          if (_session!.yieldCount > 0) ...[
                            const Divider(height: 24),
                            _StatRow(
                              icon: Icons.swap_horiz,
                              label: 'Times Yielded',
                              value: _session!.yieldCount.toString(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (isOptimal) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.military_tech, color: Colors.amber.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Optimal Solution Bonus! +10 LP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Word chain
                  _buildWordChain(),

                  const SizedBox(height: 32),

                  // Auto-generation info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.autorenew,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'A new ladder has been automatically generated to keep the fun going!',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Back button
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Ladders'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2, // Down
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.pink,
                Colors.purple,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.orange,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordChain() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Journey',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _session!.wordChain.asMap().entries.map((entry) {
            final index = entry.key;
            final word = entry.value;
            final isFirst = index == 0;
            final isLast = index == _session!.wordChain.length - 1;

            return Chip(
              label: Text(
                word,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              backgroundColor: isFirst || isLast
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              labelStyle: TextStyle(
                color: isFirst || isLast ? Colors.white : Colors.black87,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight ? theme.colorScheme.primary : Colors.grey.shade700;

    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
