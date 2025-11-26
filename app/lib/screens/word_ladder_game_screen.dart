import 'package:flutter/material.dart';
import '../models/ladder_session.dart';
import '../services/ladder_service.dart';
import 'word_ladder_completion_screen.dart';
import '../utils/logger.dart';
import '../config/brand/brand_loader.dart';

class WordLadderGameScreen extends StatefulWidget {
  final String sessionId;

  const WordLadderGameScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<WordLadderGameScreen> createState() => _WordLadderGameScreenState();
}

class _WordLadderGameScreenState extends State<WordLadderGameScreen> {
  final LadderService _ladderService = LadderService();
  final TextEditingController _wordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  LadderSession? _session;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadSession() {
    setState(() {
      _session = _ladderService.getLadderSession(widget.sessionId);
      _isLoading = false;
    });
  }

  Future<void> _submitWord() async {
    if (_wordController.text.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await _ladderService.makeMove(
      sessionId: widget.sessionId,
      newWord: _wordController.text.trim().toUpperCase(),
    );

    if (!mounted) return;

    if (result.success) {
      if (result.isCompleted) {
        // Navigate to completion screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WordLadderCompletionScreen(
              sessionId: widget.sessionId,
            ),
          ),
        );
      } else {
        // Success - refresh session and clear input
        _wordController.clear();
        _loadSession();
        _showSuccessSnackBar(result.message ?? 'Great move!');
      }
    } else {
      // Error - show message
      setState(() {
        _errorMessage = result.errorMessage;
        _isSubmitting = false;
      });
    }

    setState(() => _isSubmitting = false);
  }

  Future<void> _handleYield() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yield Turn?'),
        content: const Text(
          'Can\'t find the next word? Your partner will be notified and can help you out!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yield'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await _ladderService.yieldTurn(widget.sessionId);

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context, true); // Return to hub
      _showSuccessSnackBar('Turn yielded to partner');
    } else {
      _showErrorSnackBar(result.errorMessage ?? 'Failed to yield');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: BrandLoader().colors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: BrandLoader().colors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Word Ladder')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isMyTurn = _ladderService.isMyTurn(_session!);
    final theme = Theme.of(context);

    // DEBUG: Log turn information
    Logger.debug('Word Ladder Game Screen - isMyTurn: $isMyTurn', service: 'word_ladder');
    Logger.debug('Session currentTurn: ${_session!.currentTurn}', service: 'word_ladder');
    Logger.debug('Current word: ${_session!.currentWord}', service: 'word_ladder');

    // DEBUG: Log AppBar actions
    Logger.debug('Building AppBar - isMyTurn: $isMyTurn', service: 'word_ladder');
    if (isMyTurn) {
      Logger.debug('Yield button SHOULD be visible', service: 'word_ladder');
    } else {
      Logger.debug('Yield button hidden (not user\'s turn)', service: 'word_ladder');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Ladder'),
        centerTitle: true,
        actions: [
          if (isMyTurn)
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: _handleYield,
              tooltip: 'Yield turn',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Goal
            _buildGoalCard(),
            const SizedBox(height: 24),

            // Current word
            _buildCurrentWord(),
            const SizedBox(height: 32),

            // Word chain history
            _buildWordChain(),
            const SizedBox(height: 32),

            // Input (if my turn)
            if (isMyTurn) ...[
              _buildInput(),
              const SizedBox(height: 16),
              _buildSubmitButton(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _buildErrorMessage(),
              ],
            ] else
              _buildWaitingMessage(),

            const SizedBox(height: 24),

            // Stats
            _buildStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Transform',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
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
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWord() {
    return Column(
      children: [
        const Text(
          'Current Word',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BrandLoader().colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
          child: Text(
            _session!.currentWord,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordChain() {
    final theme = Theme.of(context);
    final stepCount = _session!.stepCount;
    final optimalSteps = _session!.optimalSteps ?? stepCount;

    // Calculate remaining steps (only show if we haven't exceeded optimal)
    final remainingSteps = stepCount < optimalSteps ? optimalSteps - stepCount : 0;

    // Build progress label
    final progressLabel = stepCount < optimalSteps
        ? 'Progress ($stepCount of $optimalSteps steps)'
        : 'Progress ($stepCount steps)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          progressLabel,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),

        // Horizontal scrollable list
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Completed words and current word
              ..._buildCompletedWords(theme),

              // Empty placeholder steps (if any remaining)
              if (remainingSteps > 0) ..._buildEmptySteps(remainingSteps),

              // Target word at the end
              _buildTargetWord(theme),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCompletedWords(ThemeData theme) {
    final widgets = <Widget>[];

    for (int i = 0; i < _session!.wordChain.length; i++) {
      final word = _session!.wordChain[i];
      final isCurrent = word == _session!.currentWord;

      // Add word chip
      widgets.add(
        Chip(
          label: Text(
            word,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          backgroundColor: isCurrent
              ? theme.colorScheme.primary.withOpacity(0.9)
              : theme.colorScheme.primary.withOpacity(0.7),
          labelStyle: const TextStyle(color: Colors.white),
          side: BorderSide(
            color: isCurrent
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withOpacity(0.7),
            width: 2,
          ),
        ),
      );

      // Add arrow after each word
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.arrow_forward,
            size: 20,
            color: BrandLoader().colors.disabled,
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildEmptySteps(int count) {
    final widgets = <Widget>[];

    for (int i = 0; i < count; i++) {
      // Add empty placeholder chip
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: BrandLoader().colors.divider,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Text(
            '???',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: BrandLoader().colors.disabled,
            ),
          ),
        ),
      );

      // Add arrow
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.arrow_forward,
            size: 20,
            color: BrandLoader().colors.disabled,
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildTargetWord(ThemeData theme) {
    return Chip(
      label: Text(
        _session!.endWord,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      backgroundColor: theme.colorScheme.primary,
      labelStyle: const TextStyle(color: Colors.white),
      side: BorderSide(
        color: theme.colorScheme.primary,
        width: 2,
      ),
    );
  }

  Widget _buildInput() {
    return TextField(
      controller: _wordController,
      focusNode: _focusNode,
      textCapitalization: TextCapitalization.characters,
      maxLength: _session!.currentWord.length,
      style: const TextStyle(
        fontSize: 24,
        letterSpacing: 3,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        labelText: 'Enter next word',
        hintText: _session!.currentWord,
        border: const OutlineInputBorder(),
        errorText: _errorMessage,
        counterText: '',
      ),
      onSubmitted: (_) => _submitWord(),
      enabled: !_isSubmitting,
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton.icon(
      onPressed: _isSubmitting ? null : _submitWord,
      icon: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_forward),
      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Word'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandLoader().colors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BrandLoader().colors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: BrandLoader().colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: BrandLoader().colors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandLoader().colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty, size: 48, color: BrandLoader().colors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Waiting for partner...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: BrandLoader().colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow(
              label: 'Steps taken',
              value: _session!.stepCount.toString(),
            ),
            if (_session!.optimalSteps != null) ...[
              const Divider(height: 16),
              _StatRow(
                label: 'Optimal steps',
                value: _session!.optimalSteps.toString(),
                isTarget: true,
              ),
            ],
            const Divider(height: 16),
            _StatRow(
              label: 'Language',
              value: _session!.language.toUpperCase(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTarget;

  const _StatRow({
    required this.label,
    required this.value,
    this.isTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: BrandLoader().colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isTarget
                ? Theme.of(context).colorScheme.primary
                : BrandLoader().colors.textPrimary.withOpacity(0.87),
          ),
        ),
      ],
    );
  }
}
