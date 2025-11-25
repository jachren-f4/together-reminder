import 'dart:async';
import 'package:flutter/material.dart';
import '../models/linked.dart';
import '../services/linked_service.dart';
import '../services/storage_service.dart';
import 'linked/progress_ring.dart';
import 'linked/partner_badge.dart';
import 'linked/completion_badge.dart';
import 'linked/score_row.dart';
import 'linked/countdown_timer.dart';

/// Card displaying the Linked game status on the home screen
///
/// 5 states based on game progress and turn:
/// - YourTurnFresh: Your turn, no progress yet
/// - PartnerTurnFresh: Partner's turn, no progress yet
/// - YourTurnInProgress: Your turn, game in progress
/// - PartnerTurnInProgress: Partner's turn, game in progress (polls every 10s)
/// - Completed: Game finished
class LinkedCard extends StatefulWidget {
  final VoidCallback onTap;
  final bool showShadow;

  const LinkedCard({
    super.key,
    required this.onTap,
    this.showShadow = false,
  });

  @override
  State<LinkedCard> createState() => _LinkedCardState();
}

class _LinkedCardState extends State<LinkedCard> {
  final LinkedService _service = LinkedService();
  final StorageService _storage = StorageService();

  LinkedGameState? _gameState;
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadGameState();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGameState({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final gameState = await _service.getOrCreateMatch();
      if (mounted) {
        setState(() {
          _gameState = gameState;
          _isLoading = false;
        });
        _updatePolling();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _updatePolling() {
    _pollingTimer?.cancel();

    // Only poll during partner's turn (when we're waiting)
    if (_gameState != null && !_gameState!.isMyTurn && !_gameState!.match.isCompleted) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) {
          _loadGameState(silent: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    if (_error != null) {
      return _buildErrorCard();
    }

    if (_gameState == null) {
      return _buildEmptyCard();
    }

    return _buildCard();
  }

  Widget _buildLoadingCard() {
    return _CardContainer(
      borderWidth: 1,
      showShadow: widget.showShadow,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return _CardContainer(
      borderWidth: 1,
      showShadow: widget.showShadow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              'Failed to load game',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _loadGameState,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return _CardContainer(
      borderWidth: 1,
      showShadow: widget.showShadow,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No game available'),
      ),
    );
  }

  Widget _buildCard() {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final userId = user?.id ?? '';

    final cardState = _gameState!.match.getCardState(userId);

    switch (cardState) {
      case LinkedCardState.yourTurnFresh:
        return _buildYourTurnFreshCard();
      case LinkedCardState.partnerTurnFresh:
        return _buildPartnerTurnFreshCard(partner?.name ?? 'Partner', partner?.avatarEmoji);
      case LinkedCardState.yourTurnInProgress:
        return _buildYourTurnInProgressCard();
      case LinkedCardState.partnerTurnInProgress:
        return _buildPartnerTurnInProgressCard(partner?.name ?? 'Partner', partner?.avatarEmoji);
      case LinkedCardState.completed:
        return _buildCompletedCard(partner?.name ?? 'Partner');
    }
  }

  /// State 1: Your Turn (Fresh) - 2px border, "Your Turn" badge
  Widget _buildYourTurnFreshCard() {
    return GestureDetector(
      onTap: widget.onTap,
      child: _CardContainer(
        borderWidth: 2, // Thick border = action required
        showShadow: widget.showShadow,
        child: Stack(
          children: [
            // Background image placeholder
            _buildBackgroundImage(),
            // Content overlay
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Badge row
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _YourTurnBadge(),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Bottom content
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Linked',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start the puzzle',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.9),
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
    );
  }

  /// State 2: Partner's Turn (Fresh) - 1px border, Partner badge
  Widget _buildPartnerTurnFreshCard(String partnerName, String? emoji) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _CardContainer(
        borderWidth: 1, // Thin border = waiting
        showShadow: widget.showShadow,
        child: Stack(
          children: [
            _buildBackgroundImage(),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        LinkedPartnerBadge(
                          partnerName: partnerName,
                          partnerEmoji: emoji,
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Linked',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Waiting for $partnerName to start',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.9),
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
    );
  }

  /// State 3: Your Turn (In Progress) - 2px border, progress ring, scores
  Widget _buildYourTurnInProgressCard() {
    return GestureDetector(
      onTap: widget.onTap,
      child: _CardContainer(
        borderWidth: 2,
        showShadow: widget.showShadow,
        child: Stack(
          children: [
            _buildBackgroundImage(),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _YourTurnBadge(),
                        const Spacer(),
                        LinkedProgressRing(
                          progressPercent: _gameState!.progressPercent,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Linked',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_gameState!.match.currentRack.length} letters in your rack',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinkedScoreRowCompact(
                          userScore: _gameState!.myScore,
                          partnerScore: _gameState!.partnerScore,
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
    );
  }

  /// State 4: Partner's Turn (In Progress) - 1px border, progress ring, scores
  Widget _buildPartnerTurnInProgressCard(String partnerName, String? emoji) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _CardContainer(
        borderWidth: 1,
        showShadow: widget.showShadow,
        child: Stack(
          children: [
            _buildBackgroundImage(),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        LinkedPartnerBadge(
                          partnerName: partnerName,
                          partnerEmoji: emoji,
                        ),
                        const Spacer(),
                        LinkedProgressRing(
                          progressPercent: _gameState!.progressPercent,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Linked',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Waiting for $partnerName's move",
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinkedScoreRowCompact(
                          userScore: _gameState!.myScore,
                          partnerScore: _gameState!.partnerScore,
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
    );
  }

  /// State 5: Completed - 1px border, completion badge, final scores, countdown
  Widget _buildCompletedCard(String partnerName) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _CardContainer(
        borderWidth: 1,
        showShadow: widget.showShadow,
        child: Stack(
          children: [
            _buildBackgroundImage(dimmed: true),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _CompletedBadge(),
                        const Spacer(),
                        const LinkedCompletionBadge(),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Linked',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const LinkedCountdownStatic(
                          remaining: null, // Puzzles are persistent
                          prefix: '',
                          textStyle: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinkedScoreRowCompact(
                          userScore: _gameState!.myScore,
                          partnerScore: _gameState!.partnerScore,
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
    );
  }

  Widget _buildBackgroundImage({bool dimmed = false}) {
    // Placeholder gradient background - replace with actual image later
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dimmed
              ? [Colors.grey.shade400, Colors.grey.shade600]
              : [Colors.blue.shade300, Colors.purple.shade400],
        ),
      ),
    );
  }
}

/// Card container with configurable border width
class _CardContainer extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final bool showShadow;

  const _CardContainer({
    required this.child,
    required this.borderWidth,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: borderWidth),
        borderRadius: BorderRadius.circular(0), // Sharp corners
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 0,
                  offset: const Offset(4, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// "Your Turn" badge widget
class _YourTurnBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Text(
        'Your Turn',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// "Completed" badge widget (inverted colors)
class _CompletedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Completed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
