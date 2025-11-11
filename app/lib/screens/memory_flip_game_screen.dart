import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:togetherremind/models/memory_flip.dart';
import 'package:togetherremind/services/memory_flip_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/love_point_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/widgets/match_reveal_dialog.dart';

class MemoryFlipGameScreen extends StatefulWidget {
  const MemoryFlipGameScreen({super.key});

  @override
  State<MemoryFlipGameScreen> createState() => _MemoryFlipGameScreenState();
}

class _MemoryFlipGameScreenState extends State<MemoryFlipGameScreen> {
  final MemoryFlipService _service = MemoryFlipService();
  final StorageService _storage = StorageService();
  late ConfettiController _confettiController;

  MemoryPuzzle? _puzzle;
  MemoryFlipAllowance? _allowance;
  String? _userId;
  bool _isLoading = true;
  bool _isProcessing = false;

  // Temporarily flipped cards (not yet matched)
  List<MemoryCard> _flippedCards = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadGameState();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadGameState() async {
    setState(() => _isLoading = true);

    try {
      // Get current user
      final user = _storage.getUser();
      if (user == null) {
        // Handle no user case
        return;
      }
      _userId = user.id;

      // Track old puzzle to detect new puzzle generation
      final oldPuzzle = _puzzle;

      // Load or generate puzzle
      final puzzle = await _service.getCurrentPuzzle();
      final allowance = await _service.getFlipAllowance(_userId!);

      // If this is a new puzzle (different ID), notify partner
      if (oldPuzzle == null || oldPuzzle.id != puzzle.id) {
        final partner = _storage.getPartner();
        if (partner != null && puzzle.matchedPairs == 0) {
          // Only send notification if no matches yet (truly new puzzle)
          final userName = user.name ?? 'Your partner';
          final expiresInDays = puzzle.expiresAt.difference(DateTime.now()).inDays;

          await _service.sendNewPuzzleNotification(
            partnerToken: partner.pushToken,
            senderName: userName,
            totalPairs: puzzle.totalPairs,
            expiresInDays: expiresInDays,
          );
        }
      }

      setState(() {
        _puzzle = puzzle;
        _allowance = allowance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading game: $e')),
        );
      }
    }
  }

  Future<void> _onCardTap(MemoryCard card) async {
    // Prevent interactions while processing
    if (_isProcessing) return;

    // Can't flip matched cards
    if (card.isMatched) return;

    // Already flipped in current turn
    if (_flippedCards.any((c) => c.id == card.id)) return;

    // Check if user has flips remaining
    if (_allowance?.canFlip != true) {
      _showNoFlipsDialog();
      return;
    }

    // Check if already have 2 cards flipped (should reset first)
    if (_flippedCards.length >= 2) {
      return;
    }

    setState(() {
      _flippedCards.add(card);
    });

    // If this is the second card, check for match
    if (_flippedCards.length == 2) {
      await _checkForMatch();
    }
  }

  Future<void> _checkForMatch() async {
    if (_puzzle == null || _flippedCards.length != 2) return;

    setState(() => _isProcessing = true);

    // Wait a moment so user can see both cards
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final card1 = _flippedCards[0];
      final card2 = _flippedCards[1];

      // Check for match
      final matchResult = await _service.checkForMatches(
        _puzzle!,
        card1,
        card2,
        _userId!,
      );

      // Decrement flip allowance
      await _service.decrementFlipAllowance(_userId!);

      // Reload allowance
      final updatedAllowance = await _service.getFlipAllowance(_userId!);

      if (matchResult != null) {
        // Match found! Sync with Cloud and send notification
        final partner = _storage.getPartner();
        final user = _storage.getUser();

        if (partner != null && user != null) {
          // Sync match to Firestore
          await _service.syncMatch(
            _puzzle!.id,
            [card1.id, card2.id],
            _userId!,
          );

          // Send push notification to partner
          await _service.sendMatchNotification(
            partnerToken: partner.pushToken,
            senderName: user.name ?? 'Your Partner',
            emoji: matchResult.card1.emoji,
            quote: matchResult.quote,
            lovePoints: matchResult.lovePoints,
          );

          // Award Love Points for match
          await LovePointService.awardPoints(
            amount: matchResult.lovePoints,
            reason: 'memory_flip_match',
            relatedId: _puzzle!.id,
          );
        }

        // Match found! Show celebration dialog
        setState(() {
          _allowance = updatedAllowance;
          _flippedCards.clear();
          _isProcessing = false;
        });

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => MatchRevealDialog(
              matchResult: matchResult,
              onDismiss: () {
                Navigator.of(context).pop();
                _checkPuzzleCompletion();
              },
            ),
          );
        }
      } else {
        // No match - flip cards back
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() {
          _allowance = updatedAllowance;
          _flippedCards.clear();
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _flippedCards.clear();
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _checkPuzzleCompletion() {
    if (_puzzle?.isCompleted == true) {
      // Trigger confetti
      _confettiController.play();
      // Show completion dialog
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() async {
    if (_puzzle == null) return;

    final points = _service.calculateCompletionPoints(_puzzle!);
    final daysTaken = _puzzle!.completedAt!.difference(_puzzle!.createdAt).inDays;

    // Send completion notification to partner
    final partner = _storage.getPartner();
    final user = _storage.getUser();

    if (partner != null && user != null) {
      await _service.sendCompletionNotification(
        partnerToken: partner.pushToken,
        senderName: user.name ?? 'Your Partner',
        completionQuote: _puzzle!.completionQuote,
        lovePoints: points,
        daysTaken: daysTaken,
      );

      // Award Love Points for puzzle completion
      await LovePointService.awardPoints(
        amount: points,
        reason: 'memory_flip_completed',
        relatedId: _puzzle!.id,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Puzzle Complete!',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _puzzle!.completionQuote,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGray,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    '+$points Love Points',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to activities
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoFlipsDialog() {
    if (_allowance == null) return;

    final resetTime = _service.formatTimeUntilReset(_allowance!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏳', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No flips left',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your flips will reset in $resetTime',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to Play',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoItem(
                '🃏',
                'Find matching pairs',
                'Flip two cards per turn to find matching emojis',
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                '💕',
                'Work together',
                'You and your partner share the same puzzle',
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                '🔄',
                'Limited flips',
                'You get 6 flips per day (3 matching attempts)',
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                '💎',
                'Earn rewards',
                'Complete puzzles faster for bonus Love Points',
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                description,
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.backgroundGray,
          appBar: AppBar(
        backgroundColor: AppTheme.primaryWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Memory Flip',
          style: AppTheme.headlineFont.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.textPrimary),
            onPressed: _showInfoDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppTheme.borderLight,
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildGameContent(),
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              AppTheme.primaryBlack,
              AppTheme.accentGreen,
              Colors.pink,
              Colors.blue,
              Colors.yellow,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    if (_puzzle == null || _allowance == null) {
      return const Center(child: Text('Error loading puzzle'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildFlipAllowanceBanner(),
          const SizedBox(height: 16),
          _buildProgressIndicator(),
          const SizedBox(height: 20),
          _buildMemoryGrid(),
        ],
      ),
    );
  }

  Widget _buildFlipAllowanceBanner() {
    final resetTime = _service.formatTimeUntilReset(_allowance!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('🔄', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_allowance!.flipsRemaining} flips left',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_allowance!.flipsRemaining ~/ 2} attempts remaining',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            'Resets in $resetTime',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _puzzle!.progressPercentage;
    final matchedCount = _puzzle!.matchedPairs;
    final totalCount = _puzzle!.totalPairs;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$matchedCount/$totalCount pairs',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.backgroundGray,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlack),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryGrid() {
    if (_puzzle == null) return const SizedBox.shrink();

    // Sort cards by position
    final sortedCards = List<MemoryCard>.from(_puzzle!.cards)
      ..sort((a, b) => a.position.compareTo(b.position));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: sortedCards.length,
      itemBuilder: (context, index) {
        final card = sortedCards[index];
        final isFlipped = _flippedCards.any((c) => c.id == card.id);

        return _buildMemoryCard(card, isFlipped);
      },
    );
  }

  Widget _buildMemoryCard(MemoryCard card, bool isFlipped) {
    final isMatched = card.isMatched;
    final showEmoji = isMatched || isFlipped;

    return GestureDetector(
      onTap: () => _onCardTap(card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMatched
                ? AppTheme.accentGreen
                : (isFlipped ? AppTheme.primaryBlack : AppTheme.borderLight),
            width: 2,
          ),
        ),
        child: Center(
          child: showEmoji
              ? Text(
                  card.emoji,
                  style: const TextStyle(fontSize: 36),
                )
              : const Text(
                  '❤️',
                  style: TextStyle(fontSize: 28),
                ),
        ),
      ),
    );
  }
}
