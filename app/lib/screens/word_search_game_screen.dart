import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../exceptions/game_exceptions.dart';
import '../services/word_search_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/love_point_service.dart';
import '../services/unlock_service.dart';
import '../models/word_search.dart';
import '../config/brand/brand_loader.dart';
import '../theme/app_theme.dart';
import '../widgets/linked/turn_complete_dialog.dart';
import '../widgets/linked/partner_first_dialog.dart';
import '../widgets/unlock_celebration.dart';
import '../animations/animation_config.dart';
import '../mixins/game_polling_mixin.dart';
import 'word_search_completion_screen.dart';

/// Word Search game screen
/// Design matches mockups/wordsearch/word-search-game.html
///
/// Features:
/// - 10x10 grid with touch/drag selection
/// - Floating bubble showing current selection
/// - Word bank grid (3 columns)
/// - Turn progress with 3 dots (X/3 FOUND)
/// - 3 words per turn before switch
/// - Colored lines for found words
class WordSearchGameScreen extends StatefulWidget {
  const WordSearchGameScreen({super.key});

  @override
  State<WordSearchGameScreen> createState() => _WordSearchGameScreenState();
}

class _WordSearchGameScreenState extends State<WordSearchGameScreen>
    with TickerProviderStateMixin, GamePollingMixin {
  final WordSearchService _service = WordSearchService();
  final StorageService _storage = StorageService();

  WordSearchGameState? _gameState;
  bool _isLoading = true;
  String? _error;

  // Selection state
  final List<GridPosition> _selectedPositions = [];
  String _selectedWord = '';
  bool _isSelecting = false;

  // Hint state
  GridPosition? _hintPosition;

  // Submission state
  bool _isSubmitting = false;

  // Turn complete dialog state
  bool _showTurnComplete = false;
  bool _showPartnerFirst = false;

  // GamePollingMixin overrides
  @override
  bool get shouldPoll => !_isLoading && !_isSubmitting && _gameState != null && !_gameState!.isMyTurn;

  @override
  Future<void> onPollUpdate() async {
    final newState = await _service.pollMatchState(_gameState!.match.matchId);
    if (mounted) {
      final wasPartnerTurn = !_gameState!.isMyTurn;
      setState(() => _gameState = newState);

      if (wasPartnerTurn && newState.isMyTurn) {
        _showToast("It's your turn!");
      }
      _checkGameCompletion();
    }
  }

  // Shake animation for invalid words
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Selection trail pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Accessibility - reduce motion preference
  bool _reduceMotion = false;

  // Word colors matching mockup CSS variables
  static const List<Color> _wordColors = [
    Color(0xFF5C6BC0), // Indigo
    Color(0xFF66BB6A), // Green
    Color(0xFFFFA726), // Orange
    Color(0xFFAB47BC), // Purple
    Color(0xFFEF5350), // Red
  ];

  @override
  void initState() {
    super.initState();

    // Initialize shake animation
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    // Initialize pulse animation for selection trail
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _loadGameState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AnimationConfig.shouldReduceMotion(context);

    // Stop pulse animation if reduce motion is enabled
    if (_reduceMotion && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    cancelPolling();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Track if cooldown is active
  bool _isCooldownActive = false;

  Future<void> _loadGameState() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isCooldownActive = false;
    });

    try {
      final gameState = await _service.getOrCreateMatch();
      if (mounted) {
        // Show dialog if it's not my turn when entering the game
        final showPartnerTurnDialog = !gameState.isMyTurn;

        setState(() {
          _gameState = gameState;
          _isLoading = false;
          _clearSelection();
          _hintPosition = null;
          _showTurnComplete = false;
          _showPartnerFirst = showPartnerTurnDialog;
        });
        startPolling();
        _checkGameCompletion();
      }
    } on CooldownActiveException catch (e) {
      if (mounted) {
        setState(() {
          _isCooldownActive = true;
          _error = e.message;
          _isLoading = false;
        });
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

  void _checkGameCompletion() {
    if (_gameState == null) return;
    final match = _gameState!.match;
    if (match.status == 'completed') {
      cancelPolling();
      _navigateToCompletionScreen();
    }
  }

  Future<void> _navigateToCompletionScreen() async {
    // LP is server-authoritative - sync from server before showing completion
    // Server already awarded LP via awardLP() in word-search/submit route
    await LovePointService.fetchAndSyncFromServer();

    if (!mounted) return;

    final user = _storage.getUser();
    final partner = _storage.getPartner();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => WordSearchCompletionScreen(
          match: _gameState!.match,
          currentUserId: user?.id ?? '',
          partnerName: partner?.name,
        ),
      ),
    );
  }

  void _showToast(String message) {
    // Disabled - all toasts removed per user request
  }

  void _shakeGrid() {
    // Skip shake animation if reduce motion is enabled
    if (_reduceMotion) return;
    _shakeController.forward(from: 0);
  }

  void _clearSelection() {
    setState(() {
      _selectedPositions.clear();
      _selectedWord = '';
      _isSelecting = false;
    });
  }

  bool _isAdjacent(GridPosition a, GridPosition b) {
    final rowDiff = (a.row - b.row).abs();
    final colDiff = (a.col - b.col).abs();
    return rowDiff <= 1 && colDiff <= 1 && !(rowDiff == 0 && colDiff == 0);
  }

  bool _isInLine(GridPosition a, GridPosition b, GridPosition c) {
    // Check if three points are in a straight line
    final dr1 = b.row - a.row;
    final dc1 = b.col - a.col;
    final dr2 = c.row - b.row;
    final dc2 = c.col - b.col;

    // Normalize to direction (-1, 0, 1)
    int sign(int n) => n == 0 ? 0 : (n > 0 ? 1 : -1);
    return sign(dr1) == sign(dr2) && sign(dc1) == sign(dc2);
  }

  bool _isPositionSelected(int row, int col) {
    return _selectedPositions.any((p) => p.row == row && p.col == col);
  }

  void _onCellTapDown(int row, int col) {
    if (!_gameState!.isMyTurn || _isSubmitting) return;

    // Haptic feedback on selection start
    HapticService().trigger(HapticType.selection);

    setState(() {
      _isSelecting = true;
      _selectedPositions.clear();
      _selectedPositions.add(GridPosition(row, col));
      _updateSelectedWord();
    });
  }

  void _onSelectionEnd() {
    setState(() {
      _isSelecting = false;
    });

    // Auto-submit if word is valid (length >= 3)
    if (_selectedWord.length >= 3 && _gameState!.isMyTurn) {
      _submitWord();
    }
  }

  void _updateSelectedWord() {
    if (_gameState?.puzzle == null) return;
    final puzzle = _gameState!.puzzle!;

    _selectedWord = _selectedPositions
        .map((p) => puzzle.letterAt(p.row, p.col))
        .join();
  }

  Future<void> _submitWord() async {
    if (_selectedWord.length < 3 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await _service.submitWord(
        matchId: _gameState!.match.matchId,
        word: _selectedWord,
        positions: _selectedPositions,
      );

      if (result.valid) {
        // Success feedback
        HapticService().trigger(HapticType.success);
        SoundService().play(SoundId.wordFound);

        _showWordFoundOverlay(_selectedWord.toUpperCase(), result.pointsEarned);

        // Check for unlock progression (Word Search → Steps)
        _checkForUnlock();

        // If game is complete, navigate directly to completion screen
        // Don't use refreshGameState() - that would create a new match!
        if (result.gameComplete) {
          cancelPolling();
          if (mounted) {
            _clearSelection();
            // Short delay to show the word found overlay
            await Future.delayed(const Duration(milliseconds: 800));
            // Fetch the completed match state for accurate scores
            try {
              final finalState = await _service.pollMatchState(_gameState!.match.matchId);
              setState(() => _gameState = finalState);
            } catch (e) {
              // If fetch fails, proceed with current state
            }
            _navigateToCompletionScreen();
          }
          return;
        }

        // Refresh game state (only if game not complete)
        final newState = await _service.refreshGameState();
        if (mounted) {
          setState(() {
            _gameState = newState;
            _clearSelection();
          });

          // Show turn complete dialog if turn ended
          if (result.turnComplete) {
            // Delay to let the word found overlay show first
            await Future.delayed(const Duration(milliseconds: 1200));
            if (mounted) {
              setState(() => _showTurnComplete = true);
            }
          }
        }
      } else {
        // Error feedback and shake grid for invalid word
        HapticService().trigger(HapticType.warning);
        _shakeGrid();
        _clearSelection();
      }
    } on NotYourTurnException catch (e) {
      _showToast(e.message);
      await _loadGameState();
    } catch (e) {
      _showToast('Error: $e');
      _clearSelection();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showWordFoundOverlay(String word, int points) {
    final overlay = OverlayEntry(
      builder: (context) => _WordFoundOverlay(word: word, points: points),
    );
    Overlay.of(context).insert(overlay);
    Future.delayed(const Duration(milliseconds: 1600), () => overlay.remove());
  }

  Future<void> _checkForUnlock() async {
    final unlockService = UnlockService();
    final result = await unlockService.notifyCompletion(UnlockTrigger.wordSearch);

    if (result != null && result.hasNewUnlocks && mounted) {
      // Show unlock celebration after a brief delay for word found overlay
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) {
        await UnlockCelebrations.showStepsUnlocked(context, result.lpAwarded);
      }
    }
  }

  Future<void> _useHint() async {
    if (_gameState == null || !_gameState!.isMyTurn) return;
    if (_gameState!.myHints <= 0) {
      _showToast('No hints remaining');
      return;
    }

    try {
      final result = await _service.useHint(_gameState!.match.matchId);
      setState(() {
        _hintPosition = GridPosition(result.row, result.col);
        // Don't store _hintWord - we don't want to reveal which word it is
      });
      _showToast('A word starts at the highlighted letter');

      final newState = await _service.refreshGameState();
      if (mounted) {
        setState(() => _gameState = newState);
      }
    } catch (e) {
      _showToast('Error using hint: $e');
    }
  }

  Color _getWordColor(int colorIndex) {
    return _wordColors[colorIndex % _wordColors.length];
  }

  Color? _getFoundWordColor(int row, int col) {
    if (_gameState == null) return null;

    for (final fw in _gameState!.match.foundWords) {
      for (final pos in fw.positions) {
        if (pos['row'] == row && pos['col'] == col) {
          return _getWordColor(fw.colorIndex).withValues(alpha: 0.35);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // PopScope handles Android back button
    // iOS swipe-to-go-back is disabled at the route level (PageRouteBuilder in new_home_screen.dart)
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: BrandLoader().colors.background,
        body: Stack(
          children: [
            // Main content inside SafeArea
            SafeArea(
              child: _buildBody(),
            ),
            // Full-screen overlay dialogs (outside SafeArea to cover status bar)
            if (_showTurnComplete)
              Positioned.fill(
                child: TurnCompleteDialog(
                  partnerName: _storage.getPartner()?.name ?? 'Partner',
                  onLeave: () => Navigator.of(context).pop(),
                  onStay: () => setState(() => _showTurnComplete = false),
                ),
              ),
            if (_showPartnerFirst)
              Positioned.fill(
                child: PartnerFirstDialog(
                  partnerName: _storage.getPartner()?.name ?? 'Partner',
                  puzzleType: 'word search',
                  onGoBack: () => Navigator.of(context).pop(),
                  onStay: () => setState(() => _showPartnerFirst = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Cooldown active - show friendly message with editorial serif style
    if (_isCooldownActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: BrandLoader().colors.surface,
              border: Border.all(
                color: BrandLoader().colors.textPrimary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(6, 6),
                  color: BrandLoader().colors.textPrimary.withValues(alpha: 0.1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decorative header line
                Container(
                  width: 60,
                  height: 2,
                  color: BrandLoader().colors.textPrimary,
                ),
                const SizedBox(height: 24),
                // Main title - serif uppercase
                Text(
                  'COME BACK',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 3,
                    color: BrandLoader().colors.textPrimary,
                  ),
                ),
                Text(
                  'TOMORROW',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 3,
                    color: BrandLoader().colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                // Divider line
                Container(
                  width: 40,
                  height: 1,
                  color: BrandLoader().colors.textSecondary,
                ),
                const SizedBox(height: 16),
                // Subtitle - italic serif
                Text(
                  'A new puzzle awaits at midnight',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: BrandLoader().colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Button with editorial border style
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: BrandLoader().colors.textPrimary,
                    ),
                    child: Text(
                      'RETURN HOME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: BrandLoader().colors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: BrandLoader().colors.error),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadGameState, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_gameState == null || _gameState!.puzzle == null) {
      return const Center(child: Text('No puzzle available'));
    }

    // Use a simple Column with Expanded to avoid overflow issues
    return Stack(
      children: [
        // Main content - simple flex layout that can't overflow
        Container(
          color: BrandLoader().colors.surface,
          child: Column(
            children: [
              // Header - fixed
              _buildHeader(),
              // Middle section - flexible, contains grid and word bank
              Expanded(
                child: _buildMiddleSection(),
              ),
              // Bottom bar - fixed
              _buildBottomBar(),
            ],
          ),
        ),
        // Floating bubble overlay (on top of everything)
        if (_selectedWord.isNotEmpty)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: BrandLoader().colors.textPrimary,
                ),
                child: Text(
                  _selectedWord.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: BrandLoader().colors.textOnPrimary,
                  ),
                ),
              ),
            ),
          ),
        // Dialogs moved to build() Stack to cover full screen including status bar
      ],
    );
  }

  /// Middle section containing grid and word bank
  /// Uses LayoutBuilder to calculate sizes that fit within constraints
  Widget _buildMiddleSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Minimum height for word bank (header + 3 rows of words + padding)
        const minWordBankHeight = 140.0;
        // Maximum word bank height (cap it so we have extra space for centering)
        const maxWordBankHeight = 180.0;

        double gridSize;
        double wordBankHeight;
        double extraSpace;

        if (kIsWeb) {
          // Web/Chrome: Use fixed grid size (iPhone 14 Pro Max width ~430px)
          // This prevents overflow issues on web
          const webMaxGridSize = 380.0;
          gridSize = math.min(webMaxGridSize, availableWidth - 12);

          // Word bank gets remaining space
          wordBankHeight = (availableHeight - gridSize - 12).clamp(minWordBankHeight, double.infinity);

          // No centering on web - just fit content
          extraSpace = 0;
        } else {
          // Mobile: Dynamic layout with centering
          // Grid size: square, using full width minus padding
          final desiredGridSize = availableWidth - 12; // 6px padding each side

          // Cap grid size so word bank has minimum space
          final maxGridSize = availableHeight - minWordBankHeight;
          gridSize = desiredGridSize.clamp(100.0, maxGridSize);

          // Word bank height: remaining space, but capped for centering
          final remainingAfterGrid = availableHeight - gridSize - 12;
          wordBankHeight = remainingAfterGrid.clamp(minWordBankHeight, maxWordBankHeight);

          // Total content height
          final totalContentHeight = gridSize + 12 + wordBankHeight;

          // Extra space for centering (this is what's left over)
          extraSpace = availableHeight - totalContentHeight;
        }

        // Use a Column with spacers to center content (mobile only)
        return Column(
          children: [
            // Top spacer (half of extra space) - mobile only
            if (extraSpace > 0) SizedBox(height: extraSpace / 2),
            // Grid area with padding - fixed size
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: SizedBox(
                width: gridSize,
                height: gridSize,
                child: _buildGrid(),
              ),
            ),
            // Word bank - expands on web, fixed on mobile
            if (kIsWeb)
              Expanded(child: _buildWordBank())
            else
              SizedBox(
                height: wordBankHeight,
                child: _buildWordBank(),
              ),
            // Bottom spacer (half of extra space) - mobile only
            if (extraSpace > 0) SizedBox(height: extraSpace / 2),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final partner = _storage.getPartner();
    final isMyTurn = _gameState!.isMyTurn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BrandLoader().colors.surface,
        border: Border(
          bottom: BorderSide(color: BrandLoader().colors.textPrimary, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              '←',
              style: TextStyle(
                fontSize: 18,
                color: BrandLoader().colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Title
          Text(
            'WORD SEARCH',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: BrandLoader().colors.textPrimary,
            ),
          ),
          const Spacer(),
          // Scores
          Row(
            children: [
              // My score
              Row(
                children: [
                  if (isMyTurn)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: BrandLoader().colors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    'You: ${_gameState!.myScore}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BrandLoader().colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Partner score
              Row(
                children: [
                  if (!isMyTurn)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: BrandLoader().colors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    '${partner?.name ?? "Partner"}: ${_gameState!.partnerScore}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BrandLoader().colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea(double gridSize) {
    // Grid with calculated size passed from parent
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: SizedBox(
        width: gridSize,
        height: gridSize,
        child: _buildGrid(),
      ),
    );
  }

  // Grid key for position calculation
  final GlobalKey _gridKey = GlobalKey();
  double _cellSize = 0;

  GridPosition? _getCellFromPosition(Offset globalPosition) {
    final puzzle = _gameState?.puzzle;
    if (puzzle == null || _cellSize == 0) return null;

    final RenderBox? gridBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return null;

    final localPos = gridBox.globalToLocal(globalPosition);

    final col = (localPos.dx / _cellSize).floor();
    final row = (localPos.dy / _cellSize).floor();

    if (row >= 0 && row < puzzle.rows && col >= 0 && col < puzzle.cols) {
      return GridPosition(row, col);
    }
    return null;
  }

  Offset? _getLocalPosition(Offset globalPosition) {
    final RenderBox? gridBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null) return null;
    return gridBox.globalToLocal(globalPosition);
  }

  // Get the center position of a cell in local coordinates
  Offset _getCellCenter(GridPosition cell) {
    return Offset(
      (cell.col + 0.5) * _cellSize,
      (cell.row + 0.5) * _cellSize,
    );
  }

  // Determine which adjacent cell to select based on direction from last cell
  GridPosition? _getNextCellByDirection(GridPosition fromCell, Offset toLocalPos) {
    final fromCenter = _getCellCenter(fromCell);
    final dx = toLocalPos.dx - fromCenter.dx;
    final dy = toLocalPos.dy - fromCenter.dy;

    // Need to move at least 30% of cell size to register
    final threshold = _cellSize * 0.3;
    if (dx.abs() < threshold && dy.abs() < threshold) return null;

    // Calculate direction using angle
    // Diagonal zones: 22.5° to 67.5° (and equivalents in other quadrants)
    final angle = (dx == 0 && dy == 0) ? 0 : (dy.abs() / (dx.abs() + 0.001));

    int dRow = 0;
    int dCol = 0;

    // Determine horizontal component
    if (dx.abs() >= threshold) {
      dCol = dx > 0 ? 1 : -1;
    }

    // Determine vertical component
    if (dy.abs() >= threshold) {
      dRow = dy > 0 ? 1 : -1;
    }

    // If moving mostly diagonal (angle between 0.4 and 2.5, roughly 22° to 68°)
    // ensure both components are set
    if (angle > 0.4 && angle < 2.5 && dx.abs() >= threshold * 0.7 && dy.abs() >= threshold * 0.7) {
      if (dCol == 0) dCol = dx > 0 ? 1 : -1;
      if (dRow == 0) dRow = dy > 0 ? 1 : -1;
    }

    if (dRow == 0 && dCol == 0) return null;

    final puzzle = _gameState?.puzzle;
    if (puzzle == null) return null;

    final newRow = fromCell.row + dRow;
    final newCol = fromCell.col + dCol;

    if (newRow >= 0 && newRow < puzzle.rows && newCol >= 0 && newCol < puzzle.cols) {
      return GridPosition(newRow, newCol);
    }
    return null;
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_gameState!.isMyTurn || _isSubmitting) return;

    final cell = _getCellFromPosition(details.globalPosition);
    if (cell != null) {
      // Haptic feedback on selection start
      HapticService().trigger(HapticType.selection);

      setState(() {
        _isSelecting = true;
        _selectedPositions.clear();
        _selectedPositions.add(cell);
        _updateSelectedWord();
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isSelecting || !_gameState!.isMyTurn || _isSubmitting) return;
    if (_selectedPositions.isEmpty) return;

    final localPos = _getLocalPosition(details.globalPosition);
    if (localPos == null) return;

    final lastCell = _selectedPositions.last;

    // Use direction-based detection from last cell
    final nextCell = _getNextCellByDirection(lastCell, localPos);
    if (nextCell == null) return;

    // Allow backtracking
    if (_selectedPositions.length >= 2) {
      final prevCell = _selectedPositions[_selectedPositions.length - 2];
      if (prevCell.row == nextCell.row && prevCell.col == nextCell.col) {
        setState(() {
          _selectedPositions.removeLast();
          _updateSelectedWord();
        });
        return;
      }
    }

    // Don't add if already selected
    if (_isPositionSelected(nextCell.row, nextCell.col)) return;

    // Must maintain straight line direction after first 2 cells
    if (_selectedPositions.length >= 2) {
      final prevLast = _selectedPositions[_selectedPositions.length - 2];
      if (!_isInLine(prevLast, lastCell, nextCell)) return;
    }

    // Light haptic feedback when adding cell to selection
    HapticService().trigger(HapticType.light);

    setState(() {
      _selectedPositions.add(nextCell);
      _updateSelectedWord();
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    _onSelectionEnd();
  }

  Widget _buildGrid() {
    final puzzle = _gameState!.puzzle!;

    // RepaintBoundary isolates CustomPaint repaints for better performance
    return RepaintBoundary(
      child: LayoutBuilder(
      builder: (context, constraints) {
        final gridSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        _cellSize = gridSize / puzzle.cols;

        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Center(
            child: GestureDetector(
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              onTapDown: (details) {
                final cell = _getCellFromPosition(details.globalPosition);
                if (cell != null) {
                  _onCellTapDown(cell.row, cell.col);
                }
              },
              onTapUp: (_) => _onSelectionEnd(),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, gridChild) {
                  return Container(
                    key: _gridKey,
                    width: gridSize,
                    height: gridSize,
                    child: CustomPaint(
                      painter: _WordSearchLinePainter(
                        cellSize: _cellSize,
                        selectedPositions: _selectedPositions,
                        foundWords: _gameState!.match.foundWords,
                        wordColors: _wordColors,
                        isSelecting: _isSelecting,
                        pulseValue: _pulseAnimation.value,
                      ),
                      child: gridChild,
                    ),
                  );
                },
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: puzzle.cols,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: puzzle.totalCells,
                  itemBuilder: (context, index) {
                    final pos = puzzle.indexToPosition(index);
                    return _buildCell(pos.row, pos.col, _cellSize);
                  },
                ),
              ),
            ),
          ),
        );
      },
    ),
    );
  }

  Widget _buildCell(int row, int col, double cellSize) {
    final puzzle = _gameState!.puzzle!;
    final letter = puzzle.letterAt(row, col);

    final isSelected = _isPositionSelected(row, col);
    final isHint = _hintPosition?.row == row && _hintPosition?.col == col;
    final foundColor = _getFoundWordColor(row, col);

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFF9800).withValues(alpha: 0.2) // Orange selection
            : isHint
                ? const Color(0xFF2196F3).withValues(alpha: 0.2) // Blue hint
                : foundColor ?? BrandLoader().colors.surface,
        border: Border.all(
          color: isSelected
              ? BrandLoader().colors.textPrimary
              : isHint
                  ? const Color(0xFF2196F3)
                  : const Color(0xFF666666),
          width: isSelected ? 2 : 1.5,
        ),
      ),
      child: Center(
        child: Text(
          letter.toUpperCase(),
          style: AppTheme.headlineFont.copyWith(
            fontSize: cellSize * 0.45,
            fontWeight: FontWeight.w700,
            color: BrandLoader().colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildWordBank() {
    final puzzle = _gameState!.puzzle!;
    final match = _gameState!.match;

    // Dynamic layout: word bank expands to fill remaining space
    // Use 4 columns x 3 rows layout for better readability
    const int columnCount = 4;
    const double gapSize = 6;

    return ClipRect(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BrandLoader().colors.surface,
          border: Border(
            top: BorderSide(color: const Color(0xFFE0E0E0)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row - fixed height
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FIND THESE WORDS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: BrandLoader().colors.textSecondary,
                  ),
                ),
                Text(
                  '${match.totalWordsFound} / ${puzzle.words.length}',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: BrandLoader().colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Word grid - expands to fill available space
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  mainAxisSpacing: gapSize,
                  crossAxisSpacing: gapSize,
                  childAspectRatio: 2.2, // Width to height ratio for word items
                ),
                itemCount: puzzle.words.length,
                itemBuilder: (context, index) {
                  final word = puzzle.words[index];
                  final found = match.isWordFound(word);
                  final foundWord = match.getFoundWord(word);
                  final color = foundWord != null
                      ? _getWordColor(foundWord.colorIndex)
                      : null;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: BrandLoader().colors.surface,
                      border: Border.all(
                        color: found ? color! : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          word.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: found
                                ? color!.withValues(alpha: 0.6)
                                : BrandLoader().colors.textPrimary,
                            decoration: found ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isMyTurn = _gameState!.isMyTurn;
    final hintsRemaining = _gameState!.myHints;
    final wordsThisTurn = _gameState!.match.wordsFoundThisTurn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: BrandLoader().colors.surface,
        border: Border(
          top: BorderSide(color: const Color(0xFFE0E0E0)),
        ),
      ),
      child: Row(
        children: [
          // Hint button
          Expanded(
            child: GestureDetector(
              onTap: isMyTurn && hintsRemaining > 0 ? _useHint : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: BrandLoader().colors.surface,
                  border: Border.all(
                    color: isMyTurn && hintsRemaining > 0
                        ? BrandLoader().colors.textPrimary
                        : const Color(0xFFBDBDBD),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '💡',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'HINT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: isMyTurn && hintsRemaining > 0
                            ? BrandLoader().colors.textPrimary
                            : const Color(0xFFBDBDBD),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '($hintsRemaining)',
                      style: TextStyle(
                        fontSize: 9,
                        color: BrandLoader().colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Turn progress
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isMyTurn
                    ? BrandLoader().colors.textPrimary
                    : BrandLoader().colors.surface,
                border: Border.all(
                  color: BrandLoader().colors.textPrimary,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress dots
                  Row(
                    children: List.generate(3, (i) {
                      final filled = i < wordsThisTurn;
                      return Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: isMyTurn
                              ? BrandLoader().colors.textOnPrimary.withValues(alpha: filled ? 1.0 : 0.4)
                              : BrandLoader().colors.textSecondary.withValues(alpha: filled ? 1.0 : 0.4),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isMyTurn ? '$wordsThisTurn/3 FOUND' : "PARTNER'S TURN",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isMyTurn
                          ? BrandLoader().colors.textOnPrimary
                          : BrandLoader().colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay widget shown when a word is found
class _WordFoundOverlay extends StatefulWidget {
  final String word;
  final int points;

  const _WordFoundOverlay({required this.word, required this.points});

  @override
  State<_WordFoundOverlay> createState() => _WordFoundOverlayState();
}

class _WordFoundOverlayState extends State<_WordFoundOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: BrandLoader().colors.success,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: BrandLoader().colors.success.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.word,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: BrandLoader().colors.textOnPrimary,
                        fontFamily: 'Georgia',
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${widget.points}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: BrandLoader().colors.textOnPrimary.withValues(alpha: 0.9),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for drawing selection and found word lines
class _WordSearchLinePainter extends CustomPainter {
  final double cellSize;
  final List<GridPosition> selectedPositions;
  final List<WordSearchFoundWord> foundWords;
  final List<Color> wordColors;
  final bool isSelecting;
  final double pulseValue;

  _WordSearchLinePainter({
    required this.cellSize,
    required this.selectedPositions,
    required this.foundWords,
    required this.wordColors,
    required this.isSelecting,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw found word lines first (underneath current selection)
    for (final foundWord in foundWords) {
      if (foundWord.positions.isEmpty) continue;

      final color = wordColors[foundWord.colorIndex % wordColors.length];
      final paint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = cellSize * 0.7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final positions = foundWord.positions;
      if (positions.length >= 2) {
        final firstPos = positions.first;
        final lastPos = positions.last;

        final startX = (firstPos['col']! + 0.5) * cellSize;
        final startY = (firstPos['row']! + 0.5) * cellSize;
        final endX = (lastPos['col']! + 0.5) * cellSize;
        final endY = (lastPos['row']! + 0.5) * cellSize;

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      }
    }

    // Draw current selection line (on top) with pulsing effect
    if (selectedPositions.isNotEmpty && isSelecting) {
      // Main selection line
      final paint = Paint()
        ..color = const Color(0xFFFF9800).withValues(alpha: 0.5) // Orange
        ..strokeWidth = cellSize * 0.7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Pulsing glow effect
      final glowPaint = Paint()
        ..color = const Color(0xFFFF9800).withValues(alpha: 0.2 * pulseValue) // Pulsing glow
        ..strokeWidth = cellSize * 0.9
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      if (selectedPositions.length >= 2) {
        final first = selectedPositions.first;
        final last = selectedPositions.last;

        final startX = (first.col + 0.5) * cellSize;
        final startY = (first.row + 0.5) * cellSize;
        final endX = (last.col + 0.5) * cellSize;
        final endY = (last.row + 0.5) * cellSize;

        // Draw glow layer first
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
        // Draw main line on top
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      } else if (selectedPositions.length == 1) {
        // Draw pulsing circle for single cell selection
        final pos = selectedPositions.first;
        final centerX = (pos.col + 0.5) * cellSize;
        final centerY = (pos.row + 0.5) * cellSize;

        canvas.drawCircle(
          Offset(centerX, centerY),
          cellSize * 0.35 * pulseValue,
          glowPaint,
        );
        canvas.drawCircle(
          Offset(centerX, centerY),
          cellSize * 0.25,
          paint..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WordSearchLinePainter oldDelegate) {
    return oldDelegate.selectedPositions != selectedPositions ||
        oldDelegate.foundWords != foundWords ||
        oldDelegate.isSelecting != isSelecting ||
        oldDelegate.pulseValue != pulseValue;
  }
}
