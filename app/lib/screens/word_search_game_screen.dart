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
import '../services/play_mode_service.dart';
import '../models/word_search.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../theme/app_theme.dart';
import '../widgets/linked/turn_complete_dialog.dart';
import '../widgets/linked/partner_first_dialog.dart';
import '../widgets/together/player_indicator_chip.dart';
import '../widgets/unlock_popup.dart';
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

  /// Check if we're running the Us2 brand
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

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
  bool get _isTogetherMode => PlayModeService().isSinglePhone;

  bool get shouldPoll => !_isTogetherMode && !_isLoading && !_isSubmitting && _gameState != null && !_gameState!.isMyTurn;

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

  /// Handle "I'm Ready" in together mode — reload game state for partner's turn
  void _handleTogetherReady() {
    setState(() {
      _showTurnComplete = false;
      _clearSelection();
      _hintPosition = null;
    });
    _loadGameState();
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
        final showPartnerTurnDialog = !_isTogetherMode && !gameState.isMyTurn;
        final showTogetherHandoff = _isTogetherMode && !gameState.isMyTurn;

        setState(() {
          _gameState = gameState;
          _isLoading = false;
          _clearSelection();
          _hintPosition = null;
          _showTurnComplete = showTogetherHandoff;
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
    // Set pending results flag FIRST - if app is killed before navigation,
    // user will see "RESULTS ARE READY!" on home screen
    if (_gameState != null) {
      await _storage.setPendingResultsMatchId('word_search', _gameState!.match.matchId);
    }

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
      // In together mode, use onBehalfOf when it's the phantom user's turn
      String? onBehalfOf;
      if (_isTogetherMode) {
        final playMode = PlayModeService();
        final phantomId = playMode.phantomUserId;
        if (phantomId != null &&
            _gameState!.match.currentTurnUserId == phantomId) {
          onBehalfOf = phantomId;
        }
      }

      final result = await _service.submitWord(
        matchId: _gameState!.match.matchId,
        word: _selectedWord,
        positions: _selectedPositions,
        onBehalfOf: onBehalfOf,
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
          // NOTE: Pending results flag is set in _navigateToCompletionWithLPSync when game completes
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
      // Show unlock popup after a brief delay for word found overlay
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) {
        await UnlockPopup.show(context, featureType: UnlockFeatureType.stepsTogether);
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
    // iOS swipe-to-go-back is disabled at the route level (PageRouteBuilder in home_screen.dart)
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _isUs2 ? Us2Theme.bgGradientEnd : BrandLoader().colors.background,
        body: Container(
          decoration: _isUs2
              ? const BoxDecoration(gradient: Us2Theme.backgroundGradient)
              : null,
          child: Stack(
            children: [
              // Main content inside SafeArea
              SafeArea(
                child: _buildBody(),
              ),
              // Full-screen overlay dialogs (outside SafeArea to cover status bar)
              if (_showTurnComplete)
                Positioned.fill(
                  child: TurnCompleteDialog(
                    partnerName: _isTogetherMode
                        ? PlayModeService().partnerName
                        : (_storage.getPartner()?.name ?? 'Partner'),
                    onLeave: () => Navigator.of(context).pop(),
                    onStay: () => setState(() => _showTurnComplete = false),
                    isTogetherMode: _isTogetherMode,
                    onTogetherReady: _isTogetherMode ? _handleTogetherReady : null,
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
          color: _isUs2 ? Colors.transparent : BrandLoader().colors.surface,
          child: Column(
            children: [
              // Header - fixed
              _isUs2 ? _buildUs2Header() : _buildHeader(),
              // Middle section - flexible, contains grid and word bank
              Expanded(
                child: _buildMiddleSection(),
              ),
              // Bottom bar - fixed
              _isUs2 ? _buildUs2BottomBar() : _buildBottomBar(),
            ],
          ),
        ),
        // Floating bubble overlay (on top of everything)
        if (_selectedWord.isNotEmpty)
          Positioned(
            top: _isUs2 ? 52 : 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isUs2 ? 16 : 16,
                  vertical: _isUs2 ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  gradient: _isUs2 ? Us2Theme.accentGradient : null,
                  color: _isUs2 ? null : BrandLoader().colors.textPrimary,
                  borderRadius: _isUs2 ? BorderRadius.circular(16) : null,
                  boxShadow: _isUs2
                      ? [
                          BoxShadow(
                            color: Us2Theme.glowPink.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _selectedWord.toUpperCase(),
                  style: TextStyle(
                    fontSize: _isUs2 ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: _isUs2 ? Colors.white : BrandLoader().colors.textOnPrimary,
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

  /// Us2 styled header with gradient back button and score badges
  Widget _buildUs2Header() {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';
    final isMyTurn = _gameState!.isMyTurn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Gradient back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: Us2Theme.accentGradient,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.glowPink.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '←',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Title
          Text(
            'WORD SEARCH',
            style: TextStyle(
              fontFamily: Us2Theme.fontHeading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Us2Theme.textDark,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          // Score badges
          Row(
            children: [
              _buildUs2ScoreBadge(
                'You: ${_gameState!.myScore}',
                isActive: isMyTurn,
              ),
              const SizedBox(width: 6),
              _buildUs2ScoreBadge(
                '$partnerName: ${_gameState!.partnerScore}',
                isActive: !isMyTurn,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Us2 styled score badge
  Widget _buildUs2ScoreBadge(String text, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: Us2Theme.accentGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Us2Theme.glowPink.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            const Text('💗', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
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

    // Account for 2px spacing between cells
    const spacing = 2.0;
    final unitSize = _cellSize + spacing;
    final col = (localPos.dx / unitSize).floor();
    final row = (localPos.dy / unitSize).floor();

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
    // Account for 2px spacing between cells
    const spacing = 2.0;
    final unitSize = _cellSize + spacing;
    return Offset(
      cell.col * unitSize + _cellSize / 2,
      cell.row * unitSize + _cellSize / 2,
    );
  }

  // Determine which adjacent cell to select based on direction from last cell
  // Uses angle snapping to nearest of 8 directions for more predictable control
  GridPosition? _getNextCellByDirection(GridPosition fromCell, Offset toLocalPos) {
    final fromCenter = _getCellCenter(fromCell);
    final dx = toLocalPos.dx - fromCenter.dx;
    final dy = toLocalPos.dy - fromCenter.dy;

    // Need to move at least 30% of cell size to register
    final threshold = _cellSize * 0.3;
    final distance = (dx * dx + dy * dy);
    if (distance < threshold * threshold) return null;

    // Calculate angle in degrees (0-360), with 0° pointing right, going clockwise
    // atan2 returns radians from -π to π, with 0 pointing right
    double angleRad = math.atan2(dy, dx);
    double angleDeg = angleRad * 180 / math.pi;
    if (angleDeg < 0) angleDeg += 360;

    // Snap to nearest 45° direction (8 directions total)
    // 0° = right, 45° = down-right, 90° = down, 135° = down-left
    // 180° = left, 225° = up-left, 270° = up, 315° = up-right
    int snappedAngle = ((angleDeg + 22.5) ~/ 45 * 45).round() % 360;

    // Map snapped angle to dRow, dCol
    int dRow = 0;
    int dCol = 0;
    switch (snappedAngle) {
      case 0:   // Right
        dCol = 1; dRow = 0;
        break;
      case 45:  // Down-right
        dCol = 1; dRow = 1;
        break;
      case 90:  // Down
        dCol = 0; dRow = 1;
        break;
      case 135: // Down-left
        dCol = -1; dRow = 1;
        break;
      case 180: // Left
        dCol = -1; dRow = 0;
        break;
      case 225: // Up-left
        dCol = -1; dRow = -1;
        break;
      case 270: // Up
        dCol = 0; dRow = -1;
        break;
      case 315: // Up-right
        dCol = 1; dRow = -1;
        break;
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

    // If selection already started (via onTapDown), don't restart
    // This prevents losing the first cell when dragging from edge
    if (_isSelecting && _selectedPositions.isNotEmpty) return;

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
    GridPosition? nextCell;

    if (_selectedPositions.length < 2) {
      // PHASE 1: First 2 cells - use direct hit-testing for accurate direction
      // This prevents issues with diagonal selection (e.g., bottom-left to top-right)
      final directHitCell = _getCellFromPosition(details.globalPosition);
      if (directHitCell == null) return;
      // Only accept adjacent cells (including diagonals)
      final rowDiff = (directHitCell.row - lastCell.row).abs();
      final colDiff = (directHitCell.col - lastCell.col).abs();
      if (rowDiff <= 1 && colDiff <= 1 && (rowDiff > 0 || colDiff > 0)) {
        nextCell = directHitCell;
      } else {
        return; // Not adjacent, ignore
      }
    } else {
      // PHASE 2: Direction established - continue in that direction based on distance
      // Get the established direction from first 2 cells
      final first = _selectedPositions[0];
      final second = _selectedPositions[1];
      final dRow = (second.row - first.row).sign; // -1, 0, or 1
      final dCol = (second.col - first.col).sign;

      // Calculate next cell in established direction
      final expectedNextRow = lastCell.row + dRow;
      final expectedNextCol = lastCell.col + dCol;

      // Check if finger has moved far enough toward next cell
      // Account for 2px spacing between cells
      const spacing = 2.0;
      final unitSize = _cellSize + spacing;
      final nextCellCenter = Offset(
        expectedNextCol * unitSize + _cellSize / 2,
        expectedNextRow * unitSize + _cellSize / 2,
      );
      final lastCellCenter = _getCellCenter(lastCell);

      // Calculate progress toward next cell (0 = at last cell, 1 = at next cell)
      final totalDist = (nextCellCenter - lastCellCenter).distance;
      final currentDist = (localPos - lastCellCenter).distance;

      // Also check we're moving in the right direction (not backwards)
      final toNext = nextCellCenter - lastCellCenter;
      final toFinger = localPos - lastCellCenter;
      final dotProduct = toNext.dx * toFinger.dx + toNext.dy * toFinger.dy;

      // Need to be at least 50% of the way to next cell, moving forward
      // (Higher threshold prevents flickering at cell boundaries)
      if (dotProduct > 0 && currentDist > totalDist * 0.5) {
        final puzzle = _gameState?.puzzle;
        if (puzzle != null &&
            expectedNextRow >= 0 && expectedNextRow < puzzle.rows &&
            expectedNextCol >= 0 && expectedNextCol < puzzle.cols) {
          nextCell = GridPosition(expectedNextRow, expectedNextCol);
        }
      }

      // Also check for backtracking
      if (nextCell == null && _selectedPositions.length >= 2) {
        final prevCell = _selectedPositions[_selectedPositions.length - 2];
        final prevCellCenter = _getCellCenter(prevCell);
        final toPrev = prevCellCenter - lastCellCenter;
        final dotPrev = toPrev.dx * toFinger.dx + toPrev.dy * toFinger.dy;
        final prevDist = (localPos - lastCellCenter).distance;
        final totalPrevDist = (prevCellCenter - lastCellCenter).distance;

        // Need to be 60% of the way back to trigger backtrack (higher than forward threshold)
        if (dotPrev > 0 && prevDist > totalPrevDist * 0.6) {
          // Backtracking
          setState(() {
            _selectedPositions.removeLast();
            _updateSelectedWord();
          });
          return;
        }
      }

      if (nextCell == null) return;
    }

    // Allow backtracking for phase 1
    if (_selectedPositions.length >= 2 && _selectedPositions.length < 3) {
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

    // Light haptic feedback when adding cell to selection
    HapticService().trigger(HapticType.light);

    setState(() {
      _selectedPositions.add(nextCell!);
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
        // Account for 2px spacing between cells (9 gaps for 10 columns)
        const spacing = 2.0;
        final totalSpacing = spacing * (puzzle.cols - 1);
        _cellSize = (gridSize - totalSpacing) / puzzle.cols;

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
                  final gridContent = Container(
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

                  // Us2: Wrap grid in gold beveled frame
                  if (_isUs2) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: Us2Theme.gridFrameGradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Us2Theme.goldBorder, width: 1.5),
                        boxShadow: [
                          ...Us2Theme.gridFrameShadow,
                          const BoxShadow(
                            color: Color(0x66FFFFFF),
                            blurRadius: 0,
                            spreadRadius: 0,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Us2Theme.goldMid,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: gridContent,
                        ),
                      ),
                    );
                  }

                  return gridContent;
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

    // Us2 styling
    if (_isUs2) {
      return Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? Us2Theme.letterTileGradient // Gold gradient for selected
              : null,
          color: isSelected
              ? null
              : isHint
                  ? const Color(0xFFBBDEFB) // Light blue hint
                  : foundColor ?? const Color(0xFFFFFBF5), // Cream
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected
                ? Us2Theme.goldBorder
                : isHint
                    ? const Color(0xFF2196F3)
                    : Us2Theme.cellBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0x33000000),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0xE6FFFFFF),
                    blurRadius: 0,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            letter.toUpperCase(),
            style: TextStyle(
              fontFamily: Us2Theme.fontHeading,
              fontSize: cellSize * 0.42,
              fontWeight: FontWeight.w700,
              color: isSelected ? Us2Theme.tileText : Us2Theme.textDark,
            ),
          ),
        ),
      );
    }

    // Original brand styling
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
          color: _isUs2 ? null : BrandLoader().colors.surface,
          gradient: _isUs2
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFBF5), Color(0xFFFFF5EE)],
                )
              : null,
          borderRadius: _isUs2 ? const BorderRadius.vertical(top: Radius.circular(12)) : null,
          border: _isUs2
              ? Border.all(color: const Color(0x4DC9A875))
              : Border(top: BorderSide(color: const Color(0xFFE0E0E0))),
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
                    fontWeight: _isUs2 ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 1,
                    color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
                  ),
                ),
                Text(
                  '${match.totalWordsFound} / ${puzzle.words.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: _isUs2 ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 1,
                    color: _isUs2 ? Us2Theme.gradientAccentStart : BrandLoader().colors.textSecondary,
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
                      color: _isUs2 ? Colors.white : BrandLoader().colors.surface,
                      borderRadius: _isUs2 ? BorderRadius.circular(6) : null,
                      border: Border.all(
                        color: found ? color! : (_isUs2 ? Us2Theme.cellBorder : const Color(0xFFE0E0E0)),
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          word.toUpperCase(),
                          style: TextStyle(
                            fontSize: _isUs2 ? 10 : 11,
                            fontWeight: _isUs2 ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: 0.5,
                            color: found
                                ? color!.withValues(alpha: 0.6)
                                : (_isUs2 ? Us2Theme.textDark : BrandLoader().colors.textPrimary),
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

  /// Us2 styled bottom bar with gradient buttons
  Widget _buildUs2BottomBar() {
    final isMyTurn = _gameState!.isMyTurn;
    final hintsRemaining = _gameState!.myHints;
    final wordsThisTurn = _gameState!.match.wordsFoundThisTurn;
    final isDisabled = !isMyTurn;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 6, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBF5), Color(0xFFFFF5EE)],
        ),
      ),
      child: Row(
        children: [
          // Hint button - compact
          Opacity(
            opacity: isDisabled || hintsRemaining <= 0 ? 0.5 : 1.0,
            child: GestureDetector(
              onTap: !isDisabled && hintsRemaining > 0 ? _useHint : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: Us2Theme.accentGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Us2Theme.glowPink.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      'Hint ($hintsRemaining)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Turn progress - compact
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: isMyTurn
                    ? Us2Theme.accentGradient
                    : const LinearGradient(
                        colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
                      ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: isMyTurn
                    ? [
                        BoxShadow(
                          color: Us2Theme.glowPink.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress dots
                  Row(
                    children: List.generate(3, (i) {
                      final filled = i < wordsThisTurn;
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: isMyTurn
                              ? Colors.white.withOpacity(filled ? 1.0 : 0.4)
                              : const Color(0xFF666666).withOpacity(filled ? 0.6 : 0.3),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isMyTurn ? '$wordsThisTurn/3 FOUND' : "PARTNER'S TURN",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isMyTurn ? Colors.white : const Color(0xFF666666),
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

  // Spacing between cells in the GridView
  static const double _spacing = 2.0;

  _WordSearchLinePainter({
    required this.cellSize,
    required this.selectedPositions,
    required this.foundWords,
    required this.wordColors,
    required this.isSelecting,
    required this.pulseValue,
  });

  // Helper to get cell center accounting for spacing
  Offset _cellCenter(int row, int col) {
    final unitSize = cellSize + _spacing;
    return Offset(
      col * unitSize + cellSize / 2,
      row * unitSize + cellSize / 2,
    );
  }

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

        final start = _cellCenter(firstPos['row']!, firstPos['col']!);
        final end = _cellCenter(lastPos['row']!, lastPos['col']!);

        canvas.drawLine(start, end, paint);
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

        final start = _cellCenter(first.row, first.col);
        final end = _cellCenter(last.row, last.col);

        // Draw glow layer first
        canvas.drawLine(start, end, glowPaint);
        // Draw main line on top
        canvas.drawLine(start, end, paint);
      } else if (selectedPositions.length == 1) {
        // Draw pulsing circle for single cell selection
        final pos = selectedPositions.first;
        final center = _cellCenter(pos.row, pos.col);

        canvas.drawCircle(
          center,
          cellSize * 0.35 * pulseValue,
          glowPaint,
        );
        canvas.drawCircle(
          center,
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
