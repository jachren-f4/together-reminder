import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../models/ladder_session.dart';
import '../services/ladder_service.dart';
import '../services/storage_service.dart';
import 'word_ladder_game_screen.dart';
import '../config/brand/brand_loader.dart';

class WordLadderHubScreen extends StatefulWidget {
  const WordLadderHubScreen({super.key});

  @override
  State<WordLadderHubScreen> createState() => _WordLadderHubScreenState();
}

class _WordLadderHubScreenState extends State<WordLadderHubScreen> {
  final LadderService _ladderService = LadderService();
  final StorageService _storage = StorageService();
  List<LadderSession> _activeLadders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLadders();
  }

  Future<void> _initializeLadders() async {
    setState(() => _isLoading = true);

    try {
      // Check if initial ladders exist, if not create them
      final activeCount = _storage.getActiveLadderCount();

      if (activeCount == 0) {
        await _ladderService.createInitialLadders();
      }

      setState(() {
        _activeLadders = _ladderService.getActiveLadders();
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Error initializing ladders', error: e, service: 'word_ladder');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Ladder Duet'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _initializeLadders,
              child: _activeLadders.isEmpty
                  ? _buildEmptyState()
                  : _buildLadderList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_neutral, size: 64, color: BrandLoader().colors.disabled),
          const SizedBox(height: 16),
          const Text(
            'No active ladders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: BrandLoader().colors.disabled),
          ),
        ],
      ),
    );
  }

  Widget _buildLadderList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeLadders.length,
      itemBuilder: (context, index) {
        final ladder = _activeLadders[index];
        final isMyTurn = _ladderService.isMyTurn(ladder);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _LadderCard(
            ladder: ladder,
            isMyTurn: isMyTurn,
            onTap: () => _openLadder(ladder),
          ),
        );
      },
    );
  }

  void _openLadder(LadderSession ladder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordLadderGameScreen(sessionId: ladder.id),
      ),
    );

    // Refresh on return
    if (result == true || mounted) {
      await _initializeLadders();
    }
  }
}

class _LadderCard extends StatelessWidget {
  final LadderSession ladder;
  final bool isMyTurn;
  final VoidCallback onTap;

  const _LadderCard({
    required this.ladder,
    required this.isMyTurn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isYielded = ladder.isYielded;
    final theme = Theme.of(context);

    // Color scheme based on state
    Color cardColor;
    Color borderColor;
    IconData icon;

    if (isYielded) {
      cardColor = BrandLoader().colors.warning.withOpacity(0.1);
      borderColor = BrandLoader().colors.warning;
      icon = Icons.help_outline;
    } else if (isMyTurn) {
      cardColor = theme.colorScheme.primaryContainer;
      borderColor = theme.colorScheme.primary;
      icon = Icons.play_arrow;
    } else {
      cardColor = BrandLoader().colors.background;
      borderColor = BrandLoader().colors.border;
      icon = Icons.hourglass_empty;
    }

    return Card(
      elevation: isMyTurn || isYielded ? 4 : 1,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(icon, color: borderColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isYielded
                          ? 'Partner needs help!'
                          : isMyTurn
                              ? 'Your turn'
                              : 'Partner\'s turn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: borderColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ladder.language.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Word transformation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ladder.startWord,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward, size: 24),
                  ),
                  Text(
                    ladder.endWord,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current: ${ladder.currentWord}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ladder.stepCount} steps${ladder.optimalSteps != null ? " • Target: ${ladder.optimalSteps}" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: BrandLoader().colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMyTurn || isYielded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'TAP TO PLAY',
                        style: TextStyle(
                          color: BrandLoader().colors.textOnPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
