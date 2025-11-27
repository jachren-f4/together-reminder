import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:togetherremind/models/memory_flip.dart';
import 'package:togetherremind/services/memory_flip_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/love_point_service.dart';
import 'package:togetherremind/services/general_activity_streak_service.dart';
import 'package:togetherremind/services/haptic_service.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/widgets/match_reveal_dialog.dart';
import 'package:togetherremind/utils/logger.dart';
import 'package:togetherremind/animations/animation_config.dart';
import '../config/brand/brand_loader.dart';

class MemoryFlipGameScreen extends StatefulWidget {
  const MemoryFlipGameScreen({super.key});

  @override
  State<MemoryFlipGameScreen> createState() => _MemoryFlipGameScreenState();
}

class _MemoryFlipGameScreenState extends State<MemoryFlipGameScreen>
    with TickerProviderStateMixin {
  final MemoryFlipService _service = MemoryFlipService();
  final StorageService _storage = StorageService();
  final GeneralActivityStreakService _streakService = GeneralActivityStreakService();
  late ConfettiController _confettiController;

  // Game state
  GameState? _gameState;
  bool _isLoading = true;
  bool _isProcessing = false;

  // Currently selected cards for this turn
  MemoryCard? _selectedCard1;
  MemoryCard? _selectedCard2;

  // Timer for auto-refresh
  Timer? _refreshTimer;

  // Flip animation controllers (one per card)
  final Map<String, AnimationController> _flipControllers = {};
  final Map<String, Animation<double>> _flipAnimations = {};

  // Match sparkle animation
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;

  // Accessibility - reduce motion preference
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AnimationConfig.shouldReduceMotion(context);
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Match sparkle animation (pulsing glow)
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _sparkleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    ));

    _loadGameState();

    // Set up periodic refresh every 10 seconds to check for partner's moves
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isProcessing) {
        _loadGameState(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _confettiController.dispose();
    _sparkleController.dispose();
    // Dispose all flip controllers
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Get or create flip animation controller for a card
  AnimationController _getFlipController(String cardId) {
    if (!_flipControllers.containsKey(cardId)) {
      // Use instant duration when reduce motion is enabled
      final duration = _reduceMotion
          ? AnimationConfig.instant
          : const Duration(milliseconds: 400);
      final controller = AnimationController(
        duration: duration,
        vsync: this,
      );
      _flipControllers[cardId] = controller;
      _flipAnimations[cardId] = Tween<double>(
        begin: 0,
        end: math.pi,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
    }
    return _flipControllers[cardId]!;
  }

  Animation<double> _getFlipAnimation(String cardId) {
    _getFlipController(cardId); // Ensure controller exists
    return _flipAnimations[cardId]!;
  }

  Future<void> _loadGameState({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final gameState = await _service.getOrCreatePuzzle();

      // Track activity streak
      if (!silent && gameState.puzzle.matchedPairs == 0) {
        // New puzzle started
        _streakService.recordActivity();
      }

      setState(() {
        _gameState = gameState;
        _isLoading = false;

        // Reset selection if turn changed
        if (!gameState.isMyTurn) {
          _selectedCard1 = null;
          _selectedCard2 = null;
        }
      });
    } catch (e) {
      Logger.error('Error loading game state', error: e, service: 'memory_flip');
      if (!silent) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading game: $e')),
          );
        }
      }
    }
  }

  Future<void> _onCardTap(MemoryCard card) async {
    if (_gameState == null || _isProcessing) return;

    // Check if it's player's turn
    if (!_gameState!.isMyTurn) {
      HapticService().trigger(HapticType.warning);
      _showNotYourTurnDialog();
      return;
    }

    // Check if player has flips
    if (_gameState!.myFlipsRemaining < 2) {
      HapticService().trigger(HapticType.warning);
      _showNoFlipsDialog();
      return;
    }

    // Can't select already matched cards
    if (card.isMatched) return;

    // Haptic feedback for card tap
    HapticService().trigger(HapticType.medium);
    SoundService().play(SoundId.cardFlip);

    // Trigger flip animation
    final controller = _getFlipController(card.id);

    // Select first or second card
    setState(() {
      if (_selectedCard1 == null) {
        _selectedCard1 = card;
        controller.forward();
      } else if (_selectedCard2 == null && card.id != _selectedCard1!.id) {
        _selectedCard2 = card;
        controller.forward();
      } else if (_selectedCard1!.id == card.id) {
        // Deselect if tapping the same card
        controller.reverse();
        _selectedCard1 = null;
      }
    });

    // Submit move after second card selected
    if (_selectedCard1 != null && _selectedCard2 != null) {
      await _submitMove();
    }
  }

  Future<void> _submitMove() async {
    if (_selectedCard1 == null || _selectedCard2 == null || _gameState == null) return;

    setState(() => _isProcessing = true);

    // Show both cards for a moment
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      final result = await _service.submitMove(
        _gameState!.puzzle.id,
        _selectedCard1!.id,
        _selectedCard2!.id,
      );

      if (result.matchFound) {
        // Match found - success haptic and sound
        HapticService().trigger(HapticType.success);
        SoundService().play(SoundId.matchFound);

        // Show match celebration
        _showMatchDialog();

        // Award Love Points
        final lovePoints = _service.calculateMatchPoints();
        await LovePointService.awardPoints(
          amount: lovePoints,
          reason: 'Memory Flip match: ${_selectedCard1!.emoji}',
        );

        // Play confetti
        _confettiController.play();

        // Track activity
        _streakService.recordActivity();
      } else {
        // No match - warning haptic and flip cards back
        HapticService().trigger(HapticType.warning);

        await Future.delayed(const Duration(milliseconds: 500));

        // Reverse flip animations
        final controller1 = _getFlipController(_selectedCard1!.id);
        final controller2 = _getFlipController(_selectedCard2!.id);
        controller1.reverse();
        controller2.reverse();
      }

      // Clear selection
      setState(() {
        _selectedCard1 = null;
        _selectedCard2 = null;
        _isProcessing = false;
      });

      // Reload game state
      await _loadGameState();

      // Check if game is completed
      if (result.gameCompleted) {
        HapticService().trigger(HapticType.heavy);
        SoundService().play(SoundId.confettiBurst);
        _onPuzzleComplete();
      }

    } catch (e) {
      Logger.error('Error submitting move', error: e, service: 'memory_flip');
      // Reverse flip animations on error
      if (_selectedCard1 != null) {
        _getFlipController(_selectedCard1!.id).reverse();
      }
      if (_selectedCard2 != null) {
        _getFlipController(_selectedCard2!.id).reverse();
      }

      setState(() {
        _selectedCard1 = null;
        _selectedCard2 = null;
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showMatchDialog() {
    if (_selectedCard1 == null || _gameState == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MatchRevealDialog(
        emoji: _selectedCard1!.emoji,
        quote: _selectedCard1!.revealQuote,
        lovePoints: _service.calculateMatchPoints(),
        onDismiss: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showNotYourTurnDialog() {
    final partnerName = _getPartnerName();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not Your Turn'),
        content: Text("It's $partnerName's turn to play. Wait for them to make their move!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadGameState(); // Refresh to check for updates
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNoFlipsDialog() {
    if (_gameState == null) return;

    final timeUntilReset = _service.formatTimeRemaining(_gameState!.timeUntilTurnExpires);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Out of Flips'),
        content: Text(
          timeUntilReset.isNotEmpty
              ? 'You have no flips remaining. New flips available in $timeUntilReset.'
              : 'You have no flips remaining. Check back soon!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onPuzzleComplete() {
    if (_gameState == null) return;

    final puzzle = _gameState!.puzzle;
    final completionPoints = _service.calculateCompletionPoints(puzzle);

    // Award completion bonus
    LovePointService.awardPoints(
      amount: completionPoints,
      reason: 'Memory Flip puzzle completed!',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Puzzle Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(puzzle.completionQuote),
            const SizedBox(height: 20),
            Text(
              'Final Score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text('You: ${puzzle.player1Pairs} pairs'),
            Text('${_getPartnerName()}: ${puzzle.player2Pairs} pairs'),
            const SizedBox(height: 10),
            Text(
              '+$completionPoints Love Points!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to activities
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _getPartnerName() {
    final partner = _storage.getPartner();
    return partner?.name ?? 'Your partner';
  }

  Color _getCardColor(MemoryCard card) {
    if (card.isMatched) {
      return BrandLoader().colors.success.withOpacity(0.3);
    }

    if (_selectedCard1?.id == card.id || _selectedCard2?.id == card.id) {
      return BrandLoader().colors.textPrimary;
    }

    return BrandLoader().colors.divider;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundGray,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: BrandLoader().colors.textPrimary.withOpacity(0.87)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Memory Flip',
          style: TextStyle(
            color: BrandLoader().colors.textPrimary.withOpacity(0.87),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: BrandLoader().colors.textPrimary.withOpacity(0.87)),
            onPressed: _isProcessing ? null : _loadGameState,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_gameState == null) {
      return const Center(child: Text('Error loading game'));
    }

    return Stack(
      children: [
        Column(
          children: [
            _buildTurnIndicator(),
            _buildScoreBoard(),
            _buildFlipAllowance(),
            Expanded(child: _buildGameGrid()),
          ],
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.3,
            colors: [
              AppTheme.primaryBlack,
              AppTheme.accentGreen,
              AppTheme.accentOrange,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTurnIndicator() {
    if (_gameState == null) return const SizedBox.shrink();

    final color = _gameState!.isMyTurn ? BrandLoader().colors.success : BrandLoader().colors.warning;
    final text = _gameState!.isMyTurn
        ? "Your Turn"
        : "Waiting for ${_getPartnerName()}";

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _gameState!.isMyTurn ? Icons.play_arrow : Icons.hourglass_empty,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    if (_gameState == null) return const SizedBox.shrink();

    final myPairs = _gameState!.myPairs;
    final partnerPairs = _gameState!.partnerPairs;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildScoreCard("You", myPairs, BrandLoader().colors.info),
          const Text("vs", style: TextStyle(fontSize: 20)),
          _buildScoreCard(_getPartnerName(), partnerPairs, BrandLoader().colors.error),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String name, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$score pairs',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipAllowance() {
    if (_gameState == null) return const SizedBox.shrink();

    final flipsRemaining = _gameState!.myFlipsRemaining;
    final attemptsRemaining = flipsRemaining ~/ 2;
    final timeUntilReset = _service.formatTimeRemaining(_gameState!.timeUntilTurnExpires);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandLoader().colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app,
                color: flipsRemaining > 0 ? BrandLoader().colors.success : BrandLoader().colors.error,
              ),
              const SizedBox(width: 8),
              Text(
                '$attemptsRemaining attempts left',
                style: TextStyle(
                  color: flipsRemaining > 0 ? BrandLoader().colors.success : BrandLoader().colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (timeUntilReset.isNotEmpty)
            Text(
              'Resets in $timeUntilReset',
              style: TextStyle(
                color: BrandLoader().colors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameGrid() {
    if (_gameState == null) return const SizedBox.shrink();

    final puzzle = _gameState!.puzzle;
    final canInteract = _gameState!.isMyTurn &&
                       _gameState!.myFlipsRemaining >= 2 &&
                       !_isProcessing;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: puzzle.cards.length,
        itemBuilder: (context, index) {
          final card = puzzle.cards[index];
          final isSelected = _selectedCard1?.id == card.id || _selectedCard2?.id == card.id;

          return GestureDetector(
            onTap: canInteract ? () => _onCardTap(card) : null,
            child: _buildFlipCard(card, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildFlipCard(MemoryCard card, bool isSelected) {
    final animation = _getFlipAnimation(card.id);
    final isRevealed = card.isMatched || isSelected;

    // RepaintBoundary isolates repaints for better performance
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: Listenable.merge([animation, _sparkleAnimation]),
      builder: (context, child) {
        final flipValue = animation.value;
        final isShowingFront = flipValue < math.pi / 2;

        // 3D perspective transform
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateY(flipValue);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: Container(
            decoration: BoxDecoration(
              color: _getCardColor(card),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? BrandLoader().colors.textPrimary
                    : BrandLoader().colors.border,
                width: isSelected ? 3 : 1,
              ),
              // Sparkle glow effect for matched cards
              boxShadow: card.isMatched
                  ? [
                      BoxShadow(
                        color: BrandLoader().colors.success.withOpacity(
                          _sparkleAnimation.value * 0.6,
                        ),
                        blurRadius: 12 * _sparkleAnimation.value,
                        spreadRadius: 2 * _sparkleAnimation.value,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isShowingFront
                  // Back of card (question mark)
                  ? _buildCardBack()
                  // Front of card (emoji) - flip horizontally to appear correct
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _buildCardFront(card, isRevealed),
                    ),
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildCardBack() {
    return Icon(
      Icons.help_outline,
      size: 32,
      color: BrandLoader().colors.textSecondary,
    );
  }

  Widget _buildCardFront(MemoryCard card, bool isRevealed) {
    if (isRevealed) {
      return Text(
        card.emoji,
        style: const TextStyle(fontSize: 32),
      );
    }
    return _buildCardBack();
  }
}