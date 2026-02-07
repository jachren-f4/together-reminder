import 'package:flutter/material.dart';
import '../exceptions/game_exceptions.dart';
import '../services/linked_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/love_point_service.dart';
import '../services/unlock_service.dart';
import '../services/play_mode_service.dart';
import '../models/linked.dart';
import '../widgets/linked/answer_cell.dart';
import '../widgets/linked/turn_complete_dialog.dart';
import '../widgets/linked/partner_first_dialog.dart';
import '../widgets/linked/linked_tutorial_overlay.dart';
import '../widgets/together/player_indicator_chip.dart';
import '../widgets/unlock_popup.dart';
import 'linked_completion_screen.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../config/linked_constants.dart';
import '../theme/app_theme.dart';
import '../mixins/game_polling_mixin.dart';

/// Main game screen for Linked (arroword puzzle game)
/// Design matches mockups/crossword/interactive-gameplay.html
class LinkedGameScreen extends StatefulWidget {
  const LinkedGameScreen({super.key});

  @override
  State<LinkedGameScreen> createState() => _LinkedGameScreenState();
}

class _LinkedGameScreenState extends State<LinkedGameScreen>
    with GamePollingMixin {
  final LinkedService _service = LinkedService();

  /// Check if we're running the Us2 brand
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  LinkedGameState? _gameState;
  bool _isLoading = true;
  String? _error;

  // Draft state - letters placed but not submitted
  final Map<int, String> _draftPlacements = {};
  final Map<int, int> _draftRackIndices = {};
  final Set<int> _usedRackIndices = {};

  // Highlight state for hints
  final Set<int> _highlightedCells = {};

  // Submission animation state
  bool _isSubmitting = false;
  LinkedTurnResult? _lastResult;
  final Map<int, _CellAnimationState> _cellAnimations = {};
  bool _showTurnComplete = false;
  bool _showPartnerFirst = false;
  bool _showTutorial = false;
  bool _showClueHintBanner = false;

  // Triple-tap detection for tutorial trigger (dev feature)
  int _titleTapCount = 0;
  DateTime? _lastTitleTap;

  // GlobalKeys for tutorial highlights
  final GlobalKey _clueKey = GlobalKey();
  final GlobalKey _rackKey = GlobalKey();
  final GlobalKey _submitKey = GlobalKey();
  bool _clueKeyAssigned = false; // Track if clue key has been assigned this build

  // Grid key and cell positions for floating points
  final GlobalKey _gridKey = GlobalKey();
  final Map<int, Offset> _cellPositions = {};

  // Word completion animation state (show one at a time)
  int _currentWordIndex = -1; // -1 means no word showing

  // Dynamic cell size (calculated in grid builder, used for rack sizing)
  double _calculatedCellSize = 50.0; // Default for 7x9 grid

  bool get _isTogetherMode => PlayModeService().isSinglePhone;

  // GamePollingMixin overrides
  @override
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

  @override
  void initState() {
    super.initState();
    _loadGameState();
  }

  @override
  void dispose() {
    cancelPolling();
    super.dispose();
  }

  /// Handle "I'm Ready" in together mode — reload game state for partner's turn
  void _handleTogetherReady() {
    setState(() {
      _showTurnComplete = false;
      _draftPlacements.clear();
      _draftRackIndices.clear();
      _usedRackIndices.clear();
      _highlightedCells.clear();
      _cellAnimations.clear();
      _lastResult = null;
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
        // In together mode, show handoff dialog; in separate mode, show "partner first"
        final showPartnerTurnDialog = !_isTogetherMode && !gameState.isMyTurn;
        final showTogetherHandoff = _isTogetherMode && !gameState.isMyTurn;

        // Check if tutorial should be shown (first time playing Linked)
        final shouldShowTutorial = !StorageService().hasSeenLinkedTutorial();

        // Check if clue hint banner should be shown (first time, after tutorial)
        final shouldShowClueHint = !StorageService().hasSeenLinkedClueHint() && !shouldShowTutorial;

        setState(() {
          _gameState = gameState;
          _isLoading = false;
          _draftPlacements.clear();
          _draftRackIndices.clear();
          _usedRackIndices.clear();
          _highlightedCells.clear();
          _cellAnimations.clear();
          _showTurnComplete = showTogetherHandoff;
          _showPartnerFirst = showPartnerTurnDialog && !shouldShowTutorial;
          _showTutorial = shouldShowTutorial;
          _showClueHintBanner = shouldShowClueHint;
          _currentWordIndex = -1;
          _lastResult = null;
        });

        // Auto-dismiss clue hint banner after 10 seconds
        if (shouldShowClueHint) {
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted && _showClueHintBanner) {
              StorageService().markLinkedClueHintSeen();
              setState(() => _showClueHintBanner = false);
            }
          });
        }
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
      _navigateToCompletionWithLPSync(match);
    }
  }

  Future<void> _navigateToCompletionWithLPSync(LinkedMatch match) async {
    // Set pending results flag FIRST - if app is killed before navigation,
    // user will see "RESULTS ARE READY!" on home screen
    await StorageService().setPendingResultsMatchId('linked', match.matchId);

    // LP is server-authoritative - sync from server before showing completion
    // Server already awarded LP via awardLP() in linked/submit route
    await LovePointService.fetchAndSyncFromServer();

    if (!mounted) return;

    final user = StorageService().getUser();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LinkedCompletionScreen(
          match: match,
          currentUserId: user?.id ?? '',
          partnerName: StorageService().getPartner()?.name,
        ),
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: BrandLoader().colors.textPrimary.withOpacity(0.87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reset clue key tracking for this build
    _clueKeyAssigned = false;

    return Scaffold(
      backgroundColor: _isUs2 ? null : BrandLoader().colors.background,
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
                    : (StorageService().getPartner()?.name ?? 'Partner'),
                onLeave: () => Navigator.of(context).pop(),
                onStay: () => setState(() => _showTurnComplete = false),
                isTogetherMode: _isTogetherMode,
                onTogetherReady: _isTogetherMode ? _handleTogetherReady : null,
              ),
            ),
          if (_showPartnerFirst)
            Positioned.fill(
              child: PartnerFirstDialog(
                partnerName: StorageService().getPartner()?.name ?? 'Partner',
                puzzleType: 'puzzle',
                onGoBack: () => Navigator.of(context).pop(),
                onStay: () => setState(() => _showPartnerFirst = false),
              ),
            ),
          // Tutorial overlay (first time playing Linked)
          if (_showTutorial)
            Positioned.fill(
              child: LinkedTutorialOverlay(
                clueKey: _clueKey,
                rackKey: _rackKey,
                submitKey: _submitKey,
                onComplete: () {
                  StorageService().markLinkedTutorialSeen();
                  setState(() {
                    _showTutorial = false;
                    // Show partner first dialog after tutorial if it's partner's turn
                    if (_gameState != null && !_gameState!.isMyTurn) {
                      _showPartnerFirst = true;
                    }
                  });
                },
                onSkip: () {
                  StorageService().markLinkedTutorialSeen();
                  setState(() {
                    _showTutorial = false;
                    // Show partner first dialog after tutorial if it's partner's turn
                    if (_gameState != null && !_gameState!.isMyTurn) {
                      _showPartnerFirst = true;
                    }
                  });
                },
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

    if (_gameState == null) {
      return const Center(child: Text('No puzzle available'));
    }

    // Check for completion first - navigation will happen in _checkGameCompletion
    // Show loading while navigation is pending
    if (_gameState!.match.status == 'completed') {
      return const Center(child: CircularProgressIndicator());
    }

    if (_gameState!.puzzle == null) {
      return const Center(child: Text('No puzzle available'));
    }

    // Dialogs moved to build() Stack to cover full screen including status bar
    return Container(
      color: BrandLoader().colors.surface,
      child: Stack(
        children: [
          // Main content
          Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildGridWithOverlay()),
              _buildBottomSection(),
            ],
          ),
          // Clue hint banner overlay (first time only)
          if (_showClueHintBanner && _isUs2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 160, // Position above the bottom section
              child: _buildClueHintBanner(),
            ),
        ],
      ),
    );
  }

  /// Build clue hint banner for first-time users
  Widget _buildClueHintBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Blue circle with ?
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Hint text
          const Expanded(
            child: Text(
              'Tap on a clue to take a closer look.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          // Dismiss button
          GestureDetector(
            onTap: () {
              StorageService().markLinkedClueHintSeen();
              setState(() => _showClueHintBanner = false);
            },
            child: const Icon(
              Icons.close,
              size: 18,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }

  /// Triple-tap on title triggers tutorial (dev feature)
  void _onTitleTap() {
    final now = DateTime.now();
    if (_lastTitleTap != null && now.difference(_lastTitleTap!).inMilliseconds < 500) {
      _titleTapCount++;
      if (_titleTapCount >= 3) {
        _titleTapCount = 0;
        setState(() => _showTutorial = true);
      }
    } else {
      _titleTapCount = 1;
    }
    _lastTitleTap = now;
  }

  /// Header: ← Linked | You: 0 | Taija: 30
  Widget _buildHeader() {
    final partnerName = StorageService().getPartner()?.name ?? 'Partner';

    if (_isUs2) {
      return _buildUs2Header(partnerName);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BrandLoader().colors.surface,
        border: Border(bottom: BorderSide(color: BrandLoader().colors.textPrimary, width: 2)),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text('←', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 16),
          // Title (triple-tap to show tutorial)
          GestureDetector(
            onTap: _onTitleTap,
            child: const Text(
              'CROSSWORD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
              ),
            ),
          ),
          const Spacer(),
          // Scores
          Row(
            children: [
              // Your score with active indicator
              if (_gameState!.isMyTurn)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                'You: ${_gameState!.myScore}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                  color: BrandLoader().colors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              // Partner score
              if (!_gameState!.isMyTurn)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                '$partnerName: ${_gameState!.partnerScore}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                  color: BrandLoader().colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Us2 styled header with gradient back button and score badges
  Widget _buildUs2Header(String partnerName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Gradient back button - compact
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
          // Title - compact (triple-tap to show tutorial)
          GestureDetector(
            onTap: _onTitleTap,
            child: Text(
              'CROSSWORD',
              style: TextStyle(
                fontFamily: Us2Theme.fontHeading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Us2Theme.textDark,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Spacer(),
          // Score badges - compact
          Row(
            children: [
              _buildUs2ScoreBadge(
                'You: ${_gameState!.myScore}',
                isActive: _gameState!.isMyTurn,
              ),
              const SizedBox(width: 6),
              _buildUs2ScoreBadge(
                '$partnerName: ${_gameState!.partnerScore}',
                isActive: !_gameState!.isMyTurn,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Us2 styled score badge - compact
  Widget _buildUs2ScoreBadge(String text, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: Us2Theme.accentGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive ? Us2Theme.scoreBadgeShadow : null,
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

  /// Grid container with animation overlay
  Widget _buildGridWithOverlay() {
    return GestureDetector(
      onTap: _highlightedCells.isNotEmpty
          ? () => setState(() => _highlightedCells.clear())
          : null,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          _buildGrid(),
          // Floating points overlay (only during animation)
          ..._buildFloatingPoints(),
          // Word completion overlay (handles its own visibility)
          _buildWordCompletionOverlay(),
        ],
      ),
    );
  }

  /// Grid container with dark background (or gold frame for Us2)
  /// Uses full-width layout so smaller grids (5x7, 6x8) have larger cells
  Widget _buildGrid() {
    final puzzle = _gameState!.puzzle!;
    final cols = puzzle.cols;
    final rows = puzzle.rows;
    final boardState = _gameState!.match.boardState;

    if (_isUs2) {
      return _buildUs2Grid(puzzle, cols, rows, boardState);
    }

    // Spacing constants
    const double horizontalPadding = 24.0; // Total left + right padding
    const double cellSpacing = 2.0;
    const double framePadding = 4.0; // Container padding

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size based on BOTH width and height constraints
        // Use the smaller value to ensure grid fits in both dimensions

        // Width-based cell size
        final availableWidth = constraints.maxWidth - horizontalPadding - framePadding;
        final horizontalSpacing = cellSpacing * (cols - 1);
        final cellSizeFromWidth = (availableWidth - horizontalSpacing) / cols;

        // Height-based cell size (use maxHeight if available, otherwise use width-based)
        final verticalSpacing = cellSpacing * (rows - 1);
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - framePadding - 16 // 16 for vertical padding
            : double.infinity;
        final cellSizeFromHeight = availableHeight.isFinite
            ? (availableHeight - verticalSpacing) / rows
            : cellSizeFromWidth;

        // Use the smaller cell size to fit both dimensions
        final cellSize = cellSizeFromWidth < cellSizeFromHeight
            ? cellSizeFromWidth
            : cellSizeFromHeight;

        // Store for rack sizing (safe to update directly, won't cause rebuild loop)
        if (_calculatedCellSize != cellSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _calculatedCellSize != cellSize) {
              setState(() => _calculatedCellSize = cellSize);
            }
          });
        }

        // Calculate grid dimensions based on final cell size
        final gridWidth = (cellSize * cols) + horizontalSpacing;
        final gridHeight = (cellSize * rows) + verticalSpacing;

        return Container(
          key: _gridKey,
          color: BrandLoader().colors.background,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2, vertical: 8),
          child: Center(
            child: SizedBox(
              width: gridWidth + framePadding,
              height: gridHeight + framePadding,
              child: Container(
                decoration: BoxDecoration(
                  color: BrandLoader().colors.textPrimary,
                ),
                padding: EdgeInsets.all(framePadding / 2),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: cellSpacing,
                    crossAxisSpacing: cellSpacing,
                  ),
                  itemCount: cols * rows,
                  itemBuilder: (context, index) {
                    return _buildCell(index, puzzle, boardState, cellSize);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Us2 styled grid with gold beveled frame - compact
  /// Uses full-width layout so smaller grids (5x7, 6x8) have larger cells
  Widget _buildUs2Grid(LinkedPuzzle puzzle, int cols, int rows, Map<String, String> boardState) {
    // Spacing constants
    const double horizontalPadding = 16.0; // Total left + right padding
    const double outerFramePadding = 6.0; // Gold frame outer padding
    const double innerFramePadding = 4.0; // Gold mid inner padding
    const double totalFramePadding = (outerFramePadding + innerFramePadding) * 2;
    const double cellSpacing = 2.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size based on BOTH width and height constraints
        // Use the smaller value to ensure grid fits in both dimensions

        // Width-based cell size
        final availableWidth = constraints.maxWidth - horizontalPadding - totalFramePadding;
        final horizontalSpacing = cellSpacing * (cols - 1);
        final cellSizeFromWidth = (availableWidth - horizontalSpacing) / cols;

        // Height-based cell size (use maxHeight if available, otherwise use width-based)
        final verticalSpacing = cellSpacing * (rows - 1);
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - totalFramePadding - 8 // 8 for vertical padding
            : double.infinity;
        final cellSizeFromHeight = availableHeight.isFinite
            ? (availableHeight - verticalSpacing) / rows
            : cellSizeFromWidth;

        // Use the smaller cell size to fit both dimensions
        final cellSize = cellSizeFromWidth < cellSizeFromHeight
            ? cellSizeFromWidth
            : cellSizeFromHeight;

        // Store for rack sizing (safe to update directly, won't cause rebuild loop)
        if (_calculatedCellSize != cellSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _calculatedCellSize != cellSize) {
              setState(() => _calculatedCellSize = cellSize);
            }
          });
        }

        // Calculate grid dimensions based on final cell size
        final gridWidth = (cellSize * cols) + horizontalSpacing;
        final gridHeight = (cellSize * rows) + verticalSpacing;

        // Total height including frame
        final totalHeight = gridHeight + totalFramePadding;

        return Container(
          key: _gridKey,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2, vertical: 4),
          child: Center(
            child: SizedBox(
              width: gridWidth + totalFramePadding,
              height: totalHeight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: Us2Theme.gridFrameGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Us2Theme.goldBorder, width: 1.5),
                  boxShadow: [
                    ...Us2Theme.gridFrameShadow,
                    // Inset highlight for bevel effect
                    const BoxShadow(
                      color: Color(0x66FFFFFF),
                      blurRadius: 0,
                      spreadRadius: 0,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(outerFramePadding),
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
                  padding: const EdgeInsets.all(innerFramePadding),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: cellSpacing,
                        crossAxisSpacing: cellSpacing,
                      ),
                      itemCount: cols * rows,
                      itemBuilder: (context, index) {
                        return _buildCell(index, puzzle, boardState, cellSize);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildFloatingPoints() {
    final List<Widget> widgets = [];
    for (final entry in _cellAnimations.entries) {
      final index = entry.key;
      final animState = entry.value;
      if (animState.showPoints && _cellPositions.containsKey(index)) {
        final position = _cellPositions[index]!;
        widgets.add(
          _FloatingPointsWidget(
            key: ValueKey('float_$index'),
            position: position,
            points: animState.points,
            isCorrect: animState.isCorrect,
            onComplete: () {
              if (mounted) {
                setState(() {
                  _cellAnimations[index] = animState.copyWith(showPoints: false);
                });
              }
            },
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildWordCompletionOverlay() {
    // Only show if we have a valid current word index
    if (_lastResult == null ||
        _currentWordIndex < 0 ||
        _currentWordIndex >= _lastResult!.completedWords.length) {
      return const SizedBox.shrink();
    }

    final word = _lastResult!.completedWords[_currentWordIndex];

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey('word_$_currentWordIndex'), // Unique key per word
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1600), // Doubled duration
            builder: (context, value, child) {
              // Fade in during first 20%, stay visible until 80%, fade out in last 20%
              double opacity;
              if (value < 0.2) {
                opacity = value * 5; // Fade in
              } else if (value < 0.8) {
                opacity = 1.0; // Stay visible
              } else {
                opacity = 1 - ((value - 0.8) * 5); // Fade out
              }

              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.8 + (value.clamp(0.0, 0.3) * 0.67), // Scale up to 1.0 and stay
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: BrandLoader().colors.success,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: BrandLoader().colors.success.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      '${word.word} +${word.bonus}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: BrandLoader().colors.textOnPrimary,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int index, LinkedPuzzle puzzle, Map<String, String> boardState, double cellSize) {
    // Use cellTypes from API to determine cell type
    if (puzzle.isVoidCell(index)) {
      if (_isUs2) {
        return Container(
          decoration: BoxDecoration(
            gradient: Us2Theme.voidCellGradient,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        );
      }
      return Container(color: BrandLoader().colors.textPrimary.withOpacity(0.13));
    }

    if (puzzle.isClueCell(index)) {
      // Check if this is a split clue cell (two clues pointing to same cell)
      final splitClues = puzzle.getSplitClues(index);
      if (splitClues != null) {
        return _buildSplitClueCell(splitClues[0], splitClues[1], cellSize);
      }

      // Regular single clue cell - use target_index based lookup
      final clue = puzzle.getClueAtCell(index);
      if (clue != null) {
        // Assign clue key to first clue cell in top rows (for tutorial highlight)
        final useClueKey = !_clueKeyAssigned && index < 12;
        if (useClueKey) _clueKeyAssigned = true;
        return _buildClueCell(clue, cellSize, useKey: useClueKey);
      }
      // Fallback if clue not found
      return Container(color: BrandLoader().colors.selected);
    }

    // Answer cell - check animation state
    final animState = _cellAnimations[index];

    // Check if locked (from server)
    final lockedLetter = boardState[index.toString()];
    if (lockedLetter != null) {
      return _buildAnswerCell(
        index,
        lockedLetter,
        animState?.justLocked == true ? AnswerCellState.locked : AnswerCellState.locked,
        showGlow: animState?.justLocked == true,
        cellSize: cellSize,
      );
    }

    // Check if draft placement
    final draftLetter = _draftPlacements[index];
    if (draftLetter != null) {
      // During submission animation, show result state
      if (animState != null && !animState.isCorrect) {
        return _buildAnswerCell(index, draftLetter, AnswerCellState.incorrect, cellSize: cellSize);
      }
      return _buildAnswerCell(index, draftLetter, AnswerCellState.draft, cellSize: cellSize);
    }

    // Empty answer cell
    return _buildAnswerCell(index, null, AnswerCellState.empty, cellSize: cellSize);
  }

  Widget _buildClueCell(LinkedClue clue, double cellSize, {bool useKey = false}) {
    final isDown = clue.arrow == 'down';
    final displayText = clue.content.toUpperCase();

    // Calculate font size based on text length AND cell size
    // Base sizes are for ~50px cells (standard 7x9 grid)
    // Scale proportionally for larger/smaller cells
    final textLength = displayText.length;
    final hasSpace = displayText.contains(' ');
    final scaleFactor = cellSize / 50.0; // 50px is our reference cell size

    // Detect if content is actually an emoji (single character or emoji sequence)
    // This handles cases where type is "emoji" but content is regular text
    final isActuallyEmoji = clue.type == 'emoji' &&
        textLength <= 2 &&
        !RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(clue.content);

    // Check if this is an emoji with a text hint (e.g., 🍑 with "_SS")
    if (clue.hasTextHint && isActuallyEmoji) {
      return _buildEmojiTextClueCell(clue, isDown, cellSize);
    }

    // Check for emoji prefix (emoji followed by text)
    final hasEmojiPrefix = _hasEmojiPrefix(clue.content);

    // G4 style: Split at spaces with FittedBox for text with spaces
    if (hasSpace && !isActuallyEmoji) {
      return _buildG4StyleClueCell(clue, isDown, cellSize, hasEmojiPrefix, useKey: useKey);
    }

    // Base font sizes (for 50px cells), then scale
    double baseFontSize;
    if (isActuallyEmoji) {
      baseFontSize = 28; // Large emoji
    } else if (textLength <= 3) {
      baseFontSize = 18;
    } else if (textLength <= 5) {
      baseFontSize = 14;
    } else if (textLength <= 8) {
      baseFontSize = 11;
    } else if (textLength <= 12) {
      baseFontSize = 9;
    } else {
      baseFontSize = 7;
    }
    final fontSize = baseFontSize * scaleFactor;

    return GestureDetector(
      onTap: () => _showClueDialog(clue),
      child: Container(
        key: useKey ? _clueKey : null,
        decoration: _isUs2
            ? BoxDecoration(
                gradient: Us2Theme.clueCellGradient,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Us2Theme.cellBorder, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xE6FFFFFF),
                    blurRadius: 0,
                    spreadRadius: 0,
                    offset: Offset(0, 1),
                  ),
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              )
            : null,
        color: _isUs2 ? null : BrandLoader().colors.selected,
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: isActuallyEmoji
                    ? Text(
                        clue.content,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1.0,
                        ),
                      )
                    : SizedBox(
                        width: cellSize - 10,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            displayText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Arial',
                              fontSize: fontSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                              color: _isUs2 ? Us2Theme.textDark : BrandLoader().colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              bottom: isDown ? 1 : null,
              right: isDown ? null : 1,
              left: isDown ? 0 : null,
              top: isDown ? null : 0,
              child: Text(
                isDown ? '▼' : '▶',
                style: TextStyle(
                  fontSize: 6 * scaleFactor,
                  color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if content starts with an emoji character
  bool _hasEmojiPrefix(String content) {
    if (content.isEmpty) return false;
    final emojiPattern = RegExp(
      r'^[\u{1F300}-\u{1F9FF}]|^[\u{2600}-\u{26FF}]|^[\u{2700}-\u{27BF}]|^[\u{1F600}-\u{1F64F}]|^[\u{1F680}-\u{1F6FF}]',
      unicode: true,
    );
    return emojiPattern.hasMatch(content);
  }

  /// Split content into emoji and text parts
  Map<String, String> _splitEmojiAndText(String content) {
    final emojiPattern = RegExp(
      r'^([\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}])+',
      unicode: true,
    );

    final match = emojiPattern.firstMatch(content);
    if (match != null) {
      return {
        'emoji': match.group(0) ?? '',
        'text': content.substring(match.end).trim(),
      };
    }
    return {'emoji': '', 'text': content};
  }

  /// G4 style: Split text at spaces with FittedBox for auto-scaling
  Widget _buildG4StyleClueCell(LinkedClue clue, bool isDown, double cellSize, bool hasEmojiPrefix, {bool useKey = false}) {
    final scaleFactor = cellSize / 50.0;

    // Extract emoji and text parts (if emoji exists)
    String emoji = '';
    String text = clue.content.toUpperCase();

    if (hasEmojiPrefix) {
      final parts = _splitEmojiAndText(clue.content);
      emoji = parts['emoji'] ?? '';
      text = parts['text']?.toUpperCase() ?? '';
    }

    // Split text at spaces
    final words = text.split(' ');

    return GestureDetector(
      onTap: () => _showClueDialog(clue),
      child: Container(
        key: useKey ? _clueKey : null,
        decoration: _isUs2
            ? BoxDecoration(
                gradient: Us2Theme.clueCellGradient,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Us2Theme.cellBorder, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xE6FFFFFF),
                    blurRadius: 0,
                    spreadRadius: 0,
                    offset: Offset(0, 1),
                  ),
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              )
            : null,
        color: _isUs2 ? null : BrandLoader().colors.selected,
        padding: const EdgeInsets.all(2),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji on top (if present)
                  if (emoji.isNotEmpty)
                    Text(
                      emoji,
                      style: TextStyle(
                        fontSize: 16 * scaleFactor,
                        height: 1.0,
                      ),
                    ),
                  // Each word on its own line with FittedBox
                  ...words.map((word) =>
                    SizedBox(
                      width: cellSize - 8,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          word,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Arial',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            color: _isUs2 ? Us2Theme.textDark : BrandLoader().colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Direction arrow
            Positioned(
              bottom: isDown ? 1 : null,
              right: isDown ? null : 1,
              left: isDown ? 0 : null,
              top: isDown ? null : 0,
              child: Text(
                isDown ? '▼' : '▶',
                style: TextStyle(
                  fontSize: 6 * scaleFactor,
                  color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a clue cell with emoji on top (left-aligned) and text hint on bottom (right-aligned)
  /// Used for emoji clues that point to single letters (e.g., 🍑 _SS for "A")
  Widget _buildEmojiTextClueCell(LinkedClue clue, bool isDown, double cellSize) {
    final scaleFactor = cellSize / 50.0;
    return GestureDetector(
      onTap: () => _showClueDialog(clue),
      child: Container(
        decoration: _isUs2
            ? BoxDecoration(
                gradient: Us2Theme.clueCellGradient,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Us2Theme.cellBorder, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xE6FFFFFF),
                    blurRadius: 0,
                    offset: Offset(0, 1),
                  ),
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              )
            : null,
        color: _isUs2 ? null : BrandLoader().colors.selected,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Stack(
          children: [
            // Main content: emoji top-left, text bottom-right
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Emoji row - left aligned
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      clue.content,
                      style: TextStyle(
                        fontSize: 22 * scaleFactor,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                // Text hint row - right aligned
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      clue.text!.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 14 * scaleFactor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: _isUs2 ? Us2Theme.letterPink : BrandLoader().colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Arrow indicator
            Positioned(
              bottom: isDown ? 1 : null,
              right: isDown ? null : 1,
              left: isDown ? 0 : null,
              top: isDown ? null : 0,
              child: Text(
                isDown ? '▼' : '▶',
                style: TextStyle(
                  fontSize: 6 * scaleFactor,
                  color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClueDialog(LinkedClue clue) {
    // Dismiss hint banner when user taps a clue
    if (_showClueHintBanner) {
      StorageService().markLinkedClueHintSeen();
      setState(() => _showClueHintBanner = false);
    }

    // Determine direction text
    final directionText = clue.arrow == 'down' ? 'Down' : 'Across';

    // Detect if content is actually an emoji
    final isActuallyEmoji = clue.type == 'emoji' &&
        clue.content.length <= 2 &&
        !RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(clue.content);

    if (_isUs2) {
      // Us 2.0 styled dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Large emoji or text
                Text(
                  isActuallyEmoji ? clue.content : clue.content.toUpperCase(),
                  style: TextStyle(
                    fontSize: isActuallyEmoji ? 64 : 24,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                // Text hint if available
                if (clue.text != null && clue.text!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      clue.text!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Us2Theme.textDark,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Direction hint
                Text(
                  '\u2022 $directionText',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 20),
                // Got it button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Original dialog for other brands
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Clue ${clue.number}'),
          content: Text(clue.content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Build a split clue cell containing two clues (across on top, down on bottom)
  Widget _buildSplitClueCell(LinkedClue acrossClue, LinkedClue downClue, double cellSize) {
    return GestureDetector(
      onTap: () => _showSplitClueDialog(acrossClue, downClue),
      child: Container(
        color: BrandLoader().colors.selected,
        child: Column(
          children: [
            // Top half: across clue
            Expanded(
              child: _buildSplitClueHalf(acrossClue, cellSize, isTop: true),
            ),
            // Divider line
            Container(
              height: 1,
              color: BrandLoader().colors.textSecondary.withOpacity(0.4),
            ),
            // Bottom half: down clue
            Expanded(
              child: _buildSplitClueHalf(downClue, cellSize, isTop: false),
            ),
          ],
        ),
      ),
    );
  }

  /// Build one half of a split clue cell using FittedBox for auto-scaling
  Widget _buildSplitClueHalf(LinkedClue clue, double cellSize, {required bool isTop}) {
    final isDown = clue.arrow == 'down';
    final displayText = clue.content.toUpperCase();
    final scaleFactor = cellSize / 50.0;

    // Arrow indicator widget
    final arrow = Positioned(
      bottom: isDown ? 0 : null,
      top: isDown ? null : 0,
      right: isDown ? null : 0,
      left: isDown ? 0 : null,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Text(
          isDown ? '▼' : '▶',
          style: TextStyle(
            fontSize: 6 * scaleFactor,
            color: BrandLoader().colors.textSecondary,
          ),
        ),
      ),
    );

    // Handle emoji with text hint (e.g., "🇳🇴 CITY")
    if (clue.hasTextHint && clue.type == 'emoji') {
      return Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      clue.content,
                      style: TextStyle(fontSize: 20 * scaleFactor, height: 1),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      clue.text!.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 13 * scaleFactor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: BrandLoader().colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          arrow,
        ],
      );
    }

    // Text or emoji content - use FittedBox for auto-scaling
    // Uppercase any text mixed with emoji (emojis don't have case, so toUpperCase() preserves them)
    final textContent = clue.type == 'emoji' ? clue.content.toUpperCase() : displayText;
    final isEmoji = clue.type == 'emoji';
    final maxFontSize = isEmoji ? 22.0 : 16.0;

    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                textContent,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: isEmoji ? null : 'Arial',
                  fontSize: maxFontSize * scaleFactor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1.1,
                  color: BrandLoader().colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        arrow,
      ],
    );
  }

  /// Show dialog with both clues for a split cell
  void _showSplitClueDialog(LinkedClue acrossClue, LinkedClue downClue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Split Clue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('▶ ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(acrossClue.content)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('▼ ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(downClue.content)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCell(int index, String? letter, AnswerCellState state, {bool showGlow = false, double? cellSize}) {
    // Scale font size based on cell size
    // Match rack tile formula: rack uses tileSize * 0.5 where tileSize = cellSize * 0.85
    // So effective fontSize = cellSize * 0.85 * 0.5 = cellSize * 0.425
    final effectiveCellSize = cellSize ?? 50.0;
    final fontSize = effectiveCellSize * 0.425; // Match rack tile visual size
    final isHighlighted = _highlightedCells.contains(index);
    final isInteractive = _gameState!.isMyTurn && state != AnswerCellState.locked && !_isSubmitting;
    final animState = _cellAnimations[index];

    // Also accept drops on draft cells (to swap/replace letters)
    final canAcceptDrop = isInteractive && (state == AnswerCellState.empty || state == AnswerCellState.draft);

    // Draft cells can be dragged to move to another cell
    final canDrag = isInteractive && state == AnswerCellState.draft && letter != null;

    // Wrap with animation if needed
    Widget wrapWithAnimation(Widget child) {
      if (animState?.isShaking == true) {
        return _ShakeWidget(
          key: ValueKey('shake_$index'),
          child: child,
          onComplete: () {
            if (mounted) {
              setState(() {
                _cellAnimations[index] = animState!.copyWith(isShaking: false);
              });
            }
          },
        );
      }
      if (animState?.isPopping == true) {
        return _PopWidget(
          key: ValueKey('pop_$index'),
          child: child,
          onComplete: () {
            if (mounted) {
              setState(() {
                _cellAnimations[index] = animState!.copyWith(isPopping: false);
              });
            }
          },
        );
      }
      return child;
    }

    return wrapWithAnimation(DragTarget<_RackDragData>(
      onWillAcceptWithDetails: (details) => canAcceptDrop,
      onAcceptWithDetails: (details) {
        // Haptic feedback on letter drop
        HapticService().trigger(HapticType.medium);

        setState(() {
          // If there was already a letter here, return it to rack first
          if (_draftPlacements.containsKey(index)) {
            final oldRackIndex = _draftRackIndices[index];
            if (oldRackIndex != null) {
              _usedRackIndices.remove(oldRackIndex);
            }
          }
          // Place the new letter
          _draftPlacements[index] = details.data.letter;
          _draftRackIndices[index] = details.data.rackIndex;
          _usedRackIndices.add(details.data.rackIndex);
          // Clear hint highlights when letter is placed
          _highlightedCells.clear();
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isDragTarget = candidateData.isNotEmpty;

        Color bgColor = Colors.white;  // Default, may be overridden
        Color textColor = BrandLoader().colors.textPrimary.withOpacity(0.87);
        Color? glowColor;
        Color? borderColor;
        BorderRadius? borderRadius;
        Gradient? gradient;
        bool useDashedBorder = false;

        // Us2-specific styling
        // Track if this is a golden tile (draft state keeps rack tile style)
        bool isGoldenTile = false;

        if (_isUs2) {
          borderRadius = BorderRadius.circular(4);
          textColor = Us2Theme.letterPink;

          switch (state) {
            case AnswerCellState.empty:
              gradient = Us2Theme.answerCellGradient;
              borderColor = Us2Theme.gradientAccentStart.withOpacity(isDragTarget ? 0.8 : 0.4);
              useDashedBorder = !isDragTarget;
              if (isHighlighted) {
                borderColor = Us2Theme.gradientAccentStart;
                glowColor = Us2Theme.glowPink;
              }
            case AnswerCellState.draft:
              // Keep golden tile style for placed letters
              isGoldenTile = true;
              gradient = Us2Theme.letterTileGradient;
              textColor = Us2Theme.tileText;
              borderRadius = BorderRadius.circular(6);
            case AnswerCellState.locked:
              gradient = Us2Theme.answerCellGradient;
              borderColor = Us2Theme.gradientAccentStart.withOpacity(0.4);
              if (showGlow) glowColor = Us2Theme.glowPink;
            case AnswerCellState.incorrect:
              bgColor = const Color(0xFFFFCCCC);
              borderColor = Colors.red;
              textColor = Colors.red.shade900;
          }
        } else {
          // Original brand styling
          final surface = BrandLoader().colors.surface;

          switch (state) {
            case AnswerCellState.empty:
              bgColor = isDragTarget
                  ? Color.alphaBlend(BrandLoader().colors.info.withOpacity(0.1), surface)
                  : surface;
              if (isHighlighted) {
                bgColor = Color.alphaBlend(BrandLoader().colors.info.withOpacity(0.2), surface);
                borderColor = BrandLoader().colors.info;
                glowColor = BrandLoader().colors.info;
              }
            case AnswerCellState.draft:
              bgColor = isDragTarget
                  ? Color.alphaBlend(BrandLoader().colors.info.withOpacity(0.15), surface)
                  : Color.alphaBlend(BrandLoader().colors.warning.withOpacity(0.2), surface);
            case AnswerCellState.locked:
              bgColor = Color.alphaBlend(BrandLoader().colors.success.withOpacity(0.15), surface);
              textColor = BrandLoader().colors.textPrimary;
              if (showGlow) glowColor = BrandLoader().colors.success;
            case AnswerCellState.incorrect:
              bgColor = Color.alphaBlend(BrandLoader().colors.error.withOpacity(0.7), surface);
              textColor = BrandLoader().colors.textOnPrimary;
          }
        }

        // Store cell position for floating points animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateCellPosition(context, index);
        });

        final baseCellContent = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: gradient == null ? bgColor : null,
            gradient: gradient,
            borderRadius: borderRadius,
            border: isDragTarget
                ? Border.all(color: _isUs2 ? Us2Theme.gradientAccentStart : BrandLoader().colors.info, width: 2)
                : borderColor != null
                    ? Border.all(color: borderColor, width: useDashedBorder ? 2 : 2)
                    : (_isUs2 ? Border.all(color: Us2Theme.cellBorder, width: 1) : null),
            boxShadow: [
              if (glowColor != null)
                BoxShadow(color: glowColor.withOpacity(0.6), blurRadius: 12, spreadRadius: 2),
              if (_isUs2 && isGoldenTile) ...[
                // Golden tile shadow for draft letters
                ...Us2Theme.letterTileShadow,
              ] else if (_isUs2) ...[
                const BoxShadow(
                  color: Color(0xE6FFFFFF),
                  blurRadius: 0,
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: Us2Theme.glowPink.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ],
          ),
          child: Center(
            child: letter != null
                ? Text(
                    letter,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      fontFamily: isGoldenTile ? Us2Theme.fontBody : 'Georgia',
                      color: textColor,
                      shadows: isGoldenTile
                          ? [const Shadow(color: Color(0x4DFFFFFF), offset: Offset(0, 1))]
                          : null,
                    ),
                  )
                : null,
          ),
        );

        // Wrap highlighted cells with pulse animation
        final cellContent = isHighlighted
            ? _PulseWidget(key: ValueKey('pulse_$index'), child: baseCellContent)
            : baseCellContent;

        // If this is a draft cell, make it draggable
        if (canDrag) {
          final rackIndex = _draftRackIndices[index] ?? -1;
          return Draggable<_RackDragData>(
            data: _RackDragData(letter: letter, rackIndex: rackIndex, fromCellIndex: index),
            onDragStarted: () {
              // Remove letter from current cell when drag starts
              setState(() {
                _draftPlacements.remove(index);
                _draftRackIndices.remove(index);
                if (rackIndex >= 0) {
                  _usedRackIndices.remove(rackIndex);
                }
              });
            },
            onDraggableCanceled: (velocity, offset) {
              // If drag was cancelled (dropped outside valid target), return to original cell
              setState(() {
                _draftPlacements[index] = letter;
                _draftRackIndices[index] = rackIndex;
                if (rackIndex >= 0) {
                  _usedRackIndices.add(rackIndex);
                }
              });
            },
            feedback: Material(
              elevation: 8,
              color: Colors.transparent,
              child: Container(
                width: effectiveCellSize,
                height: effectiveCellSize,
                decoration: BoxDecoration(
                  color: BrandLoader().colors.warning.withOpacity(0.3),
                  border: Border.all(color: BrandLoader().colors.textPrimary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: BrandLoader().colors.textPrimary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                      color: BrandLoader().colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            childWhenDragging: Container(
              decoration: BoxDecoration(
                color: BrandLoader().colors.surface,
                border: Border.all(color: BrandLoader().colors.borderLight, width: 1),
              ),
            ),
            child: cellContent,
          );
        }

        // For non-draggable cells, just use tap to return to rack
        return GestureDetector(
          onTap: isInteractive && state == AnswerCellState.draft
              ? () => _returnToRack(index)
              : null,
          child: cellContent,
        );
      },
    ));
  }

  void _updateCellPosition(BuildContext cellContext, int index) {
    final RenderBox? renderBox = cellContext.findRenderObject() as RenderBox?;
    final RenderBox? gridBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && gridBox != null) {
      final cellPosition = renderBox.localToGlobal(Offset.zero, ancestor: gridBox);
      final cellSize = renderBox.size;
      _cellPositions[index] = Offset(
        cellPosition.dx + cellSize.width / 2,
        cellPosition.dy + cellSize.height / 2,
      );
    }
  }

  void _returnToRack(int cellIndex) {
    setState(() {
      final rackIndex = _draftRackIndices[cellIndex];
      _draftPlacements.remove(cellIndex);
      _draftRackIndices.remove(cellIndex);
      if (rackIndex != null) {
        _usedRackIndices.remove(rackIndex);
      }
    });
  }

  /// Bottom section: Rack + Action buttons (always visible to prevent layout shifts)
  Widget _buildBottomSection() {
    return Container(
      decoration: BoxDecoration(
        color: _isUs2 ? null : BrandLoader().colors.surface,
        border: _isUs2 ? null : Border(top: BorderSide(color: BrandLoader().colors.textPrimary, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Always show rack to prevent grid resize
          _buildRack(),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildRack() {
    final rack = _gameState!.match.currentRack;
    final isMyTurn = _gameState!.isMyTurn;
    final isDisabled = !isMyTurn || _showTurnComplete || _isSubmitting;

    // Wrap rack in DragTarget so letters can be dragged back from the grid
    return DragTarget<_RackDragData>(
      onWillAcceptWithDetails: (details) => !isDisabled && details.data.fromCellIndex != null,
      onAcceptWithDetails: (details) {
        // Letter dragged back to rack - it's already been removed from the grid in onDragStarted
        // Just need to make sure it's properly returned to the rack
        if (details.data.rackIndex >= 0) {
          setState(() {
            _usedRackIndices.remove(details.data.rackIndex);
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDragTarget = candidateData.isNotEmpty;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isUs2 ? 12 : 12,
            vertical: _isUs2 ? 6 : 12,
          ),
          decoration: _isUs2
              ? BoxDecoration(
                  color: isDragTarget ? Us2Theme.gradientAccentStart.withOpacity(0.1) : null,
                  border: isDragTarget ? Border(top: BorderSide(color: Us2Theme.gradientAccentStart, width: 2)) : null,
                )
              : BoxDecoration(
                  color: isDragTarget ? BrandLoader().colors.info.withOpacity(0.1) : null,
                  border: Border(
                    bottom: BorderSide(color: BrandLoader().colors.divider),
                    top: isDragTarget ? BorderSide(color: BrandLoader().colors.info, width: 2) : BorderSide.none,
                  ),
                ),
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Column(
              children: [
                // Us2: Only show text when dragging back, otherwise hide for compact layout
                if (!_isUs2 || isDragTarget)
                  Text(
                    isDragTarget ? 'DROP TO RETURN' : 'YOUR LETTERS',
                    style: TextStyle(
                      fontSize: _isUs2 ? 11 : 10,
                      letterSpacing: _isUs2 ? 2 : 1,
                      fontWeight: _isUs2 ? FontWeight.w700 : (isDragTarget ? FontWeight.bold : FontWeight.normal),
                      color: _isUs2
                          ? (isDragTarget ? Us2Theme.gradientAccentStart : const Color(0xFF8B7355))
                          : (isDragTarget ? BrandLoader().colors.info : BrandLoader().colors.textSecondary),
                    ),
                  ),
                SizedBox(height: _isUs2 ? (isDragTarget ? 8 : 4) : 10),
                // Always show rackSize tile slots to prevent layout shift
                Row(
                  key: _rackKey,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(LinkedConstants.rackSize, (index) {
                    // Show actual letter if available, otherwise empty slot
                    final hasLetter = index < rack.length;
                    final letter = hasLetter ? rack[index] : '';
                    final isUsed = hasLetter && _usedRackIndices.contains(index);
                    // Show empty slot if no letter or if rack is empty (waiting for partner)
                    if (!hasLetter) {
                      return _buildEmptyRackSlot();
                    }
                    return _buildRackTile(letter, index, isUsed, isDisabled: isDisabled);
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Empty rack slot - used when waiting for partner or when letter has been placed
  Widget _buildEmptyRackSlot() {
    final tileSize = _calculatedCellSize * 0.85; // Match rack tile size
    final tileMargin = _isUs2 ? 3.0 : 4.0;

    if (_isUs2) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: tileMargin),
        width: tileSize,
        height: tileSize,
        decoration: BoxDecoration(
          color: Us2Theme.goldLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Us2Theme.goldBorder.withOpacity(0.5), width: 1.5),
        ),
      );
    }
    return Container(
      margin: EdgeInsets.symmetric(horizontal: tileMargin),
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: BrandLoader().colors.background,
        border: Border.all(
          color: BrandLoader().colors.borderLight,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
    );
  }

  Widget _buildRackTile(String letter, int rackIndex, bool isUsed, {bool isDisabled = false}) {
    if (isUsed) {
      return _buildEmptyRackSlot();
    }

    // Use cell size for rack tiles (with slight reduction for visual balance)
    // Rack letters should be similar size to grid cells
    final tileSize = _calculatedCellSize * 0.85; // Slightly smaller than cells
    final tileMargin = _isUs2 ? 3.0 : 4.0;
    final fontSize = tileSize * 0.5; // Font is ~50% of tile size

    final tile = Container(
      margin: EdgeInsets.symmetric(horizontal: tileMargin),
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        gradient: _isUs2 ? Us2Theme.letterTileGradient : null,
        color: _isUs2 ? null : BrandLoader().colors.warning.withOpacity(0.15),
        borderRadius: _isUs2 ? BorderRadius.circular(8) : null,
        border: _isUs2 ? null : Border.all(color: BrandLoader().colors.textPrimary, width: 2),
        boxShadow: _isUs2 ? Us2Theme.letterTileShadow : null,
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            fontFamily: _isUs2 ? Us2Theme.fontBody : 'Georgia',
            color: _isUs2 ? Us2Theme.tileText : BrandLoader().colors.textPrimary,
            shadows: _isUs2 ? [const Shadow(color: Color(0x4DFFFFFF), offset: Offset(0, 1))] : null,
          ),
        ),
      ),
    );

    // If disabled, just show the tile without drag capability
    if (isDisabled) {
      return tile;
    }

    return Draggable<_RackDragData>(
      data: _RackDragData(letter: letter, rackIndex: rackIndex),
      feedback: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            gradient: _isUs2 ? Us2Theme.letterTileGradient : null,
            color: _isUs2 ? null : BrandLoader().colors.warning.withOpacity(0.15),
            borderRadius: _isUs2 ? BorderRadius.circular(8) : null,
            border: _isUs2 ? null : Border.all(color: BrandLoader().colors.textPrimary, width: 2),
            boxShadow: _isUs2
                ? [
                    const BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                    ...Us2Theme.letterTileShadow,
                  ]
                : [
                    BoxShadow(
                      color: BrandLoader().colors.textPrimary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                fontFamily: _isUs2 ? Us2Theme.fontBody : 'Georgia',
                color: _isUs2 ? Us2Theme.tileText : BrandLoader().colors.textPrimary,
                shadows: _isUs2 ? [const Shadow(color: Color(0x4DFFFFFF), offset: Offset(0, 1))] : null,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: EdgeInsets.symmetric(horizontal: tileMargin),
        width: tileSize,
        height: tileSize,
        decoration: BoxDecoration(
          color: _isUs2 ? Us2Theme.goldLight.withOpacity(0.3) : BrandLoader().colors.background,
          borderRadius: _isUs2 ? BorderRadius.circular(10) : null,
          border: Border.all(
            color: _isUs2 ? Us2Theme.goldBorder.withOpacity(0.5) : BrandLoader().colors.borderLight,
            width: 2,
          ),
        ),
      ),
      child: tile,
    );
  }

  Widget _buildActionBar() {
    final hasPlacements = _draftPlacements.isNotEmpty;
    final hintsRemaining = _gameState!.myVision;
    final isMyTurn = _gameState!.isMyTurn;
    final isDisabled = !isMyTurn || _showTurnComplete || _isSubmitting;

    // Determine button state and text
    // Button always says "SUBMIT TURN" for clarity
    const String buttonText = 'SUBMIT TURN';
    bool buttonEnabled;
    Color buttonBgColor;
    Color buttonTextColor;

    if (_isSubmitting) {
      buttonEnabled = false;
      buttonBgColor = BrandLoader().colors.disabled;
      buttonTextColor = BrandLoader().colors.textOnPrimary;
    } else if (_showTurnComplete || !isMyTurn) {
      buttonEnabled = false;
      buttonBgColor = BrandLoader().colors.background;
      buttonTextColor = BrandLoader().colors.textSecondary;
    } else if (hasPlacements) {
      buttonEnabled = true;
      buttonBgColor = BrandLoader().colors.textPrimary;
      buttonTextColor = BrandLoader().colors.textOnPrimary;
    } else {
      buttonEnabled = false;
      buttonBgColor = BrandLoader().colors.divider;
      buttonTextColor = BrandLoader().colors.disabled;
    }

    if (_isUs2) {
      return _buildUs2ActionBar(
        buttonText: buttonText,
        buttonEnabled: buttonEnabled,
        hintsRemaining: hintsRemaining,
        isDisabled: isDisabled,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Row(
        children: [
          // Hint button (always visible, disabled when not your turn)
          Expanded(
            child: Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: GestureDetector(
                onTap: !isDisabled && hintsRemaining > 0 ? _useHint : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.surface,
                    border: Border.all(color: isDisabled ? BrandLoader().colors.disabled : BrandLoader().colors.textPrimary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'Hint',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: (hintsRemaining > 0 && !isDisabled) ? BrandLoader().colors.textPrimary : BrandLoader().colors.disabled,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($hintsRemaining)',
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'Georgia',
                          color: (hintsRemaining > 0 && !isDisabled) ? BrandLoader().colors.textSecondary : BrandLoader().colors.disabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Main action button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: buttonEnabled ? _submitTurn : null,
              child: Container(
                key: _submitKey,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: buttonBgColor,
                  border: Border.all(color: BrandLoader().colors.textPrimary),
                ),
                child: Center(
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: buttonTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Us2 styled action bar with gradient buttons
  Widget _buildUs2ActionBar({
    required String buttonText,
    required bool buttonEnabled,
    required int hintsRemaining,
    required bool isDisabled,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          // Hint button - compact
          Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
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
          // Main action button - compact
          Expanded(
            child: GestureDetector(
              onTap: buttonEnabled ? _submitTurn : null,
              child: Opacity(
                opacity: buttonEnabled ? 1.0 : 0.6,
                child: Container(
                  key: _submitKey,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: buttonEnabled
                        ? const LinearGradient(
                            colors: [Color(0xFFFF7B6B), Color(0xFFFF9F6B)],
                          )
                        : LinearGradient(
                            colors: [Colors.grey.shade300, Colors.grey.shade400],
                          ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: buttonEnabled
                        ? [
                            BoxShadow(
                              color: Us2Theme.glowPink.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      buttonText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: buttonEnabled ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _useHint() async {
    try {
      // Calculate remaining rack letters (exclude letters already placed as drafts)
      final fullRack = _gameState!.match.currentRack;
      final remainingRack = <String>[];
      for (int i = 0; i < fullRack.length; i++) {
        if (!_usedRackIndices.contains(i)) {
          remainingRack.add(fullRack[i]);
        }
      }

      final result = await _service.useHint(
        _gameState!.match.matchId,
        remainingRack: remainingRack,
      );
      if (mounted) {
        setState(() {
          _highlightedCells.clear();
          // API now returns only cells for remaining rack letters
          _highlightedCells.addAll(result.validCells);

          // Update hints remaining locally (avoid full reload which clears highlights)
          if (_gameState != null) {
            final oldMatch = _gameState!.match;
            final currentUserId = StorageService().getUser()?.id ?? '';
            final isPlayer1 = oldMatch.player1Id == currentUserId;

            final updatedMatch = oldMatch.copyWith(
              player1Vision: isPlayer1 ? result.hintsRemaining : oldMatch.player1Vision,
              player2Vision: !isPlayer1 ? result.hintsRemaining : oldMatch.player2Vision,
            );

            _gameState = LinkedGameState(
              match: updatedMatch,
              puzzle: _gameState!.puzzle,
              isMyTurn: _gameState!.isMyTurn,
              canPlay: _gameState!.canPlay,
              myScore: _gameState!.myScore,
              partnerScore: _gameState!.partnerScore,
              myVision: result.hintsRemaining,
              partnerVision: _gameState!.partnerVision,
              progressPercent: _gameState!.progressPercent,
            );
          }
        });

        if (_highlightedCells.isEmpty) {
          _showToast('No valid placements found for remaining letters');
        } else {
          _showToast('${_highlightedCells.length} cells highlighted • Tap to dismiss');
        }
        // Hints persist until letter placed or user taps to dismiss
      }
    } catch (e) {
      if (mounted) {
        _showToast('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _submitTurn() async {
    if (_draftPlacements.isEmpty || _isSubmitting) return;

    final placements = _draftPlacements.entries
        .map((e) => LinkedDraftPlacement(
              cellIndex: e.key,
              letter: e.value,
              rackIndex: _draftRackIndices[e.key] ?? -1,
            ))
        .toList();

    setState(() => _isSubmitting = true);

    try {
      // In together mode, use onBehalfOf when it's the phantom user's turn
      String? onBehalfOf;
      if (_isTogetherMode) {
        final playMode = PlayModeService();
        final phantomId = playMode.phantomUserId;
        // Determine if current turn belongs to phantom user
        if (phantomId != null &&
            _gameState!.match.currentTurnUserId == phantomId) {
          onBehalfOf = phantomId;
        }
      }

      final result = await _service.submitTurn(
        _gameState!.match.matchId,
        placements,
        onBehalfOf: onBehalfOf,
      );

      if (mounted) {
        setState(() {
          _lastResult = result;
        });

        // Animate each cell result with staggered timing
        await _animateResults(result);

        // Show turn complete state and update state incrementally (no reload)
        setState(() {
          _isSubmitting = false;
          _showTurnComplete = true;

          // Update game state incrementally from submit result
          _updateStateFromResult(result);
        });

        // NOTE: Pending results flag is set in _navigateToCompletionWithLPSync when game completes
        // We don't set it here because the game hasn't completed yet - just a turn ended

        // Save updated match to local storage after setState (for quest card turn display)
        if (_gameState != null) {
          await StorageService().saveLinkedMatch(_gameState!.match);
        }

        // Check for unlock progression (Linked → Word Search)
        _checkForUnlock();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showToast('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _checkForUnlock() async {
    final unlockService = UnlockService();
    final result = await unlockService.notifyCompletion(UnlockTrigger.linked);

    if (result != null && result.hasNewUnlocks && mounted) {
      // Show unlock celebration after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await UnlockPopup.show(context, featureType: UnlockFeatureType.wordSearch);
      }
    }
  }

  /// Update local game state from submit result (no API reload needed)
  void _updateStateFromResult(LinkedTurnResult result) {
    if (_gameState == null) return;

    final oldMatch = _gameState!.match;
    final newBoardState = Map<String, String>.from(oldMatch.boardState);

    // Determine player info from match and current user
    final currentUserId = StorageService().getUser()?.id ?? '';
    final isPlayer1 = oldMatch.player1Id == currentUserId;
    final partnerId = isPlayer1 ? oldMatch.player2Id : oldMatch.player1Id;

    // Lock correct cells in board state (keys are strings)
    for (final placement in result.results) {
      if (placement.correct) {
        // Get the letter from draft placements
        final letter = _draftPlacements[placement.cellIndex];
        if (letter != null) {
          newBoardState[placement.cellIndex.toString()] = letter;
        }
      }
    }

    // Create updated match with new state
    final updatedMatch = LinkedMatch(
      matchId: oldMatch.matchId,
      puzzleId: oldMatch.puzzleId,
      status: result.gameComplete ? 'completed' : 'active',
      boardState: newBoardState,
      currentRack: [], // Not our turn anymore
      currentTurnUserId: partnerId, // Switch to partner's turn
      turnNumber: oldMatch.turnNumber + 1,
      player1Score: isPlayer1 ? result.newScore : oldMatch.player1Score,
      player2Score: !isPlayer1 ? result.newScore : oldMatch.player2Score,
      player1Vision: oldMatch.player1Vision,
      player2Vision: oldMatch.player2Vision,
      lockedCellCount: newBoardState.length,
      totalAnswerCells: oldMatch.totalAnswerCells,
      player1Id: oldMatch.player1Id,
      player2Id: oldMatch.player2Id,
      winnerId: result.winnerId,
      createdAt: oldMatch.createdAt,
      completedAt: result.gameComplete ? DateTime.now() : null,
    );

    // Update game state
    final newProgressPercent = oldMatch.totalAnswerCells > 0
        ? (newBoardState.length / oldMatch.totalAnswerCells * 100).round()
        : 0;

    _gameState = LinkedGameState(
      match: updatedMatch,
      puzzle: _gameState!.puzzle,
      isMyTurn: false, // Just submitted, now partner's turn
      canPlay: false,
      myScore: result.newScore,
      partnerScore: _gameState!.partnerScore,
      myVision: _gameState!.myVision,
      partnerVision: _gameState!.partnerVision,
      progressPercent: newProgressPercent,
    );

    // Clear draft state
    _draftPlacements.clear();
    _draftRackIndices.clear();
    _usedRackIndices.clear();

    // Check game completion
    _checkGameCompletion();
  }

  Future<void> _animateResults(LinkedTurnResult result) async {
    // Phase 1: Animate each letter placement with staggered timing
    for (int i = 0; i < result.results.length; i++) {
      final placement = result.results[i];
      final points = placement.correct ? 10 : 0;

      await Future.delayed(const Duration(milliseconds: 400));

      // Haptic and sound feedback for each result
      if (placement.correct) {
        HapticService().trigger(HapticType.success);
        SoundService().play(SoundId.wordFound);
      } else {
        HapticService().trigger(HapticType.warning);
      }

      if (mounted) {
        setState(() {
          _cellAnimations[placement.cellIndex] = _CellAnimationState(
            isCorrect: placement.correct,
            points: points,
            showPoints: true,
            justLocked: placement.correct,
            isShaking: !placement.correct, // Shake incorrect letters
            isPopping: placement.correct,   // Pop correct letters
          );
        });
      }

      // Wait for shake/pop animation to complete before showing next
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Wait for last letter animation to complete (1200ms for FloatingPointsWidget)
    await Future.delayed(const Duration(milliseconds: 1100));

    // Clear letter animations before showing word bonuses
    if (mounted) {
      setState(() {
        _cellAnimations.clear();
      });
    }

    // Phase 2: Show word completion bonuses one at a time (sequential)
    if (result.completedWords.isNotEmpty) {
      for (int i = 0; i < result.completedWords.length; i++) {
        if (mounted) {
          setState(() {
            _currentWordIndex = i;
          });
        }

        // Wait for word animation to complete (1600ms)
        await Future.delayed(const Duration(milliseconds: 1800));
      }

      // Clear word animation state
      if (mounted) {
        setState(() {
          _currentWordIndex = -1;
        });
      }
    }

    // Small pause before showing turn complete
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

/// Data transferred during drag from rack or grid cell
class _RackDragData {
  final String letter;
  final int rackIndex;
  final int? fromCellIndex; // If dragging from a grid cell, this is the source cell index

  _RackDragData({required this.letter, required this.rackIndex, this.fromCellIndex});
}

/// Animation state for a cell
class _CellAnimationState {
  final bool isCorrect;
  final int points;
  final bool showPoints;
  final bool justLocked;
  final bool isShaking; // For incorrect letters
  final bool isPopping; // For correct letters

  _CellAnimationState({
    required this.isCorrect,
    required this.points,
    required this.showPoints,
    required this.justLocked,
    this.isShaking = false,
    this.isPopping = false,
  });

  _CellAnimationState copyWith({
    bool? isCorrect,
    int? points,
    bool? showPoints,
    bool? justLocked,
    bool? isShaking,
    bool? isPopping,
  }) {
    return _CellAnimationState(
      isCorrect: isCorrect ?? this.isCorrect,
      points: points ?? this.points,
      showPoints: showPoints ?? this.showPoints,
      justLocked: justLocked ?? this.justLocked,
      isShaking: isShaking ?? this.isShaking,
      isPopping: isPopping ?? this.isPopping,
    );
  }
}

/// Floating points animation widget
class _FloatingPointsWidget extends StatefulWidget {
  final Offset position;
  final int points;
  final bool isCorrect;
  final VoidCallback onComplete;

  const _FloatingPointsWidget({
    super.key,
    required this.position,
    required this.points,
    required this.isCorrect,
    required this.onComplete,
  });

  @override
  State<_FloatingPointsWidget> createState() => _FloatingPointsWidgetState();
}

class _FloatingPointsWidgetState extends State<_FloatingPointsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _positionAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _positionAnimation = Tween<double>(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuart,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the pre-calculated position
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx - 20,
          top: widget.position.dy + _positionAnimation.value - 10,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isCorrect
                      ? BrandLoader().colors.success
                      : BrandLoader().colors.error,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isCorrect ? BrandLoader().colors.success : BrandLoader().colors.error)
                          .withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.isCorrect ? '+${widget.points}' : '✗',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: BrandLoader().colors.textOnPrimary,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shake animation widget for incorrect letter placements
class _ShakeWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onComplete;

  const _ShakeWidget({
    super.key,
    required this.child,
    this.onComplete,
  });

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Shake left-right 4 times
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// Pop/scale animation widget for correct letter placements
class _PopWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onComplete;

  const _PopWidget({
    super.key,
    required this.child,
    this.onComplete,
  });

  @override
  State<_PopWidget> createState() => _PopWidgetState();
}

class _PopWidgetState extends State<_PopWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Pop: scale up to 1.15, then settle to 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 2,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Subtle pulsing animation for hint-highlighted cells
class _PulseWidget extends StatefulWidget {
  final Widget child;

  const _PulseWidget({
    super.key,
    required this.child,
  });

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Gentle pulse: scale from 1.0 to 1.05 and back
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Loop the animation
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}
