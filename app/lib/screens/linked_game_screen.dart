import 'dart:async';
import 'package:flutter/material.dart';
import '../services/linked_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/love_point_service.dart';
import '../models/linked.dart';
import '../widgets/linked/answer_cell.dart';
import '../widgets/linked/turn_complete_dialog.dart';
import '../widgets/linked/partner_first_dialog.dart';
import 'linked_completion_screen.dart';
import '../config/brand/brand_loader.dart';
import '../theme/app_theme.dart';

/// Main game screen for Linked (arroword puzzle game)
/// Design matches mockups/crossword/interactive-gameplay.html
class LinkedGameScreen extends StatefulWidget {
  const LinkedGameScreen({super.key});

  @override
  State<LinkedGameScreen> createState() => _LinkedGameScreenState();
}

class _LinkedGameScreenState extends State<LinkedGameScreen> {
  final LinkedService _service = LinkedService();

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

  // Grid key and cell positions for floating points
  final GlobalKey _gridKey = GlobalKey();
  final Map<int, Offset> _cellPositions = {};

  // Word completion animation state (show one at a time)
  int _currentWordIndex = -1; // -1 means no word showing

  // Polling timer
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _loadGameState();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_isLoading && !_isSubmitting && _gameState != null && !_gameState!.isMyTurn) {
        _pollForUpdate();
      }
    });
  }

  Future<void> _pollForUpdate() async {
    try {
      final newState = await _service.pollMatchState(_gameState!.match.matchId);
      if (mounted) {
        final wasPartnerTurn = !_gameState!.isMyTurn;
        setState(() => _gameState = newState);

        if (wasPartnerTurn && newState.isMyTurn) {
          _showToast("It's your turn!");
        }
        _checkGameCompletion();
      }
    } catch (e) {
      // Silent failure for polling
    }
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
        // Check if this is a new puzzle where partner goes first
        // Show dialog if: not my turn AND turn number is 1 (fresh puzzle)
        final isNewPuzzlePartnerFirst =
            !gameState.isMyTurn && gameState.match.turnNumber == 1;

        setState(() {
          _gameState = gameState;
          _isLoading = false;
          _draftPlacements.clear();
          _draftRackIndices.clear();
          _usedRackIndices.clear();
          _highlightedCells.clear();
          _cellAnimations.clear();
          _showTurnComplete = false;
          _showPartnerFirst = isNewPuzzlePartnerFirst;
          _currentWordIndex = -1;
          _lastResult = null;
        });
        _startPolling();
        _checkGameCompletion();
      }
    } on LinkedCooldownActiveException catch (e) {
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
      _pollTimer?.cancel();
      _navigateToCompletionWithLPSync(match);
    }
  }

  Future<void> _navigateToCompletionWithLPSync(LinkedMatch match) async {
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
    return Scaffold(
      backgroundColor: BrandLoader().colors.background,
      body: SafeArea(
        child: _buildBody(),
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

    return Stack(
      children: [
        // Game content
        Container(
          color: BrandLoader().colors.surface,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildGridWithOverlay()),
              _buildBottomSection(),
            ],
          ),
        ),
        // Turn complete dialog overlay
        if (_showTurnComplete)
          TurnCompleteDialog(
            partnerName: StorageService().getPartner()?.name ?? 'Partner',
            onLeave: () => Navigator.of(context).pop(),
            onStay: () => setState(() => _showTurnComplete = false),
          ),
        // Partner first dialog overlay (shown when entering new puzzle where partner starts)
        if (_showPartnerFirst)
          PartnerFirstDialog(
            partnerName: StorageService().getPartner()?.name ?? 'Partner',
            puzzleType: 'puzzle',
            onGoBack: () => Navigator.of(context).pop(),
            onStay: () => setState(() => _showPartnerFirst = false),
          ),
      ],
    );
  }

  /// Header: ← Linked | You: 0 | Taija: 30
  Widget _buildHeader() {
    final partnerName = StorageService().getPartner()?.name ?? 'Partner';

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
          // Title
          const Text(
            'CROSSWORD',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              letterSpacing: 2,
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
                  fontWeight: _gameState!.isMyTurn ? FontWeight.w700 : FontWeight.w400,
                  fontFamily: 'Georgia',
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
                  fontWeight: !_gameState!.isMyTurn ? FontWeight.w700 : FontWeight.w400,
                  fontFamily: 'Georgia',
                ),
              ),
            ],
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

  /// Grid container with dark background
  Widget _buildGrid() {
    final puzzle = _gameState!.puzzle!;
    final cols = puzzle.cols;
    final rows = puzzle.rows;
    final boardState = _gameState!.match.boardState;

    return Container(
      key: _gridKey,
      color: BrandLoader().colors.background,
      padding: const EdgeInsets.all(12),
      child: Center(
        child: AspectRatio(
          aspectRatio: cols / rows,
          child: Container(
            decoration: BoxDecoration(
              color: BrandLoader().colors.textPrimary,
            ),
            padding: const EdgeInsets.all(2),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: cols * rows,
              itemBuilder: (context, index) {
                return _buildCell(index, puzzle, boardState);
              },
            ),
          ),
        ),
      ),
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

  Widget _buildCell(int index, LinkedPuzzle puzzle, Map<String, String> boardState) {
    // Use cellTypes from API to determine cell type
    if (puzzle.isVoidCell(index)) {
      return Container(color: BrandLoader().colors.textPrimary.withOpacity(0.13));
    }

    if (puzzle.isClueCell(index)) {
      // Check if this is a split clue cell (two clues pointing to same cell)
      final splitClues = puzzle.getSplitClues(index);
      if (splitClues != null) {
        return _buildSplitClueCell(splitClues[0], splitClues[1]);
      }

      // Regular single clue cell - use target_index based lookup
      final clue = puzzle.getClueAtCell(index);
      if (clue != null) {
        return _buildClueCell(clue);
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
      );
    }

    // Check if draft placement
    final draftLetter = _draftPlacements[index];
    if (draftLetter != null) {
      // During submission animation, show result state
      if (animState != null && !animState.isCorrect) {
        return _buildAnswerCell(index, draftLetter, AnswerCellState.incorrect);
      }
      return _buildAnswerCell(index, draftLetter, AnswerCellState.draft);
    }

    // Empty answer cell
    return _buildAnswerCell(index, null, AnswerCellState.empty);
  }

  Widget _buildClueCell(LinkedClue clue) {
    final isDown = clue.arrow == 'down';
    final displayText = clue.content.toUpperCase();

    // Calculate font size based on text length
    final textLength = displayText.length;
    final hasSpace = displayText.contains(' ');
    double fontSize;
    if (clue.type == 'emoji') {
      fontSize = 28; // Large emoji
    } else if (textLength <= 4) {
      fontSize = 16;
    } else if (textLength <= 8) {
      fontSize = 12;
    } else if (textLength <= 12 || hasSpace) {
      fontSize = 9;
    } else {
      fontSize = 7;
    }

    return GestureDetector(
      onTap: () => _showClueDialog(clue),
      child: Container(
        color: BrandLoader().colors.selected,
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            Center(
              child: Text(
                clue.type == 'emoji' ? clue.content : displayText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: clue.type == 'emoji' ? null : 'Arial',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1.05,
                  color: BrandLoader().colors.textPrimary,
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
                  fontSize: 6,
                  color: BrandLoader().colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClueDialog(LinkedClue clue) {
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

  /// Build a split clue cell containing two clues (across on top, down on bottom)
  Widget _buildSplitClueCell(LinkedClue acrossClue, LinkedClue downClue) {
    return GestureDetector(
      onTap: () => _showSplitClueDialog(acrossClue, downClue),
      child: Container(
        color: BrandLoader().colors.selected,
        child: Column(
          children: [
            // Top half: across clue
            Expanded(
              child: _buildSplitClueHalf(acrossClue, isTop: true),
            ),
            // Divider line
            Container(
              height: 1,
              color: BrandLoader().colors.textSecondary.withOpacity(0.4),
            ),
            // Bottom half: down clue
            Expanded(
              child: _buildSplitClueHalf(downClue, isTop: false),
            ),
          ],
        ),
      ),
    );
  }

  /// Build one half of a split clue cell
  Widget _buildSplitClueHalf(LinkedClue clue, {required bool isTop}) {
    final isDown = clue.arrow == 'down';
    final displayText = clue.content.toUpperCase();

    // Smaller font sizes for split cells (half the height)
    final textLength = displayText.length;
    double fontSize;
    if (clue.type == 'emoji') {
      fontSize = 14; // Smaller emoji for split cell
    } else if (textLength <= 4) {
      fontSize = 10;
    } else if (textLength <= 8) {
      fontSize = 8;
    } else {
      fontSize = 6;
    }

    return Stack(
      children: [
        // Centered content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              clue.type == 'emoji' ? clue.content : displayText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: clue.type == 'emoji' ? null : 'Arial',
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1.05,
                color: BrandLoader().colors.textPrimary,
              ),
            ),
          ),
        ),
        // Arrow indicator
        Positioned(
          bottom: isDown ? 0 : null,
          top: isDown ? null : 0,
          right: isDown ? null : 0,
          left: isDown ? 0 : null,
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Text(
              isDown ? '▼' : '▶',
              style: TextStyle(
                fontSize: 5,
                color: BrandLoader().colors.textSecondary,
              ),
            ),
          ),
        ),
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

  Widget _buildAnswerCell(int index, String? letter, AnswerCellState state, {bool showGlow = false}) {
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

        Color bgColor;
        Color textColor = BrandLoader().colors.textPrimary.withOpacity(0.87);
        Color? glowColor;
        Color? borderColor;

        // Use Color.alphaBlend to create SOLID colors (not transparent)
        // This prevents the dark grid background from showing through
        final surface = BrandLoader().colors.surface;

        switch (state) {
          case AnswerCellState.empty:
            bgColor = isDragTarget
                ? Color.alphaBlend(BrandLoader().colors.info.withOpacity(0.1), surface)
                : surface;
            // Highlight hint cells with light blue background + glow
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

        // Store cell position for floating points animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateCellPosition(context, index);
        });

        final baseCellContent = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: bgColor,
            border: isDragTarget
                ? Border.all(color: BrandLoader().colors.info, width: 2)
                : borderColor != null
                    ? Border.all(color: borderColor, width: 3)
                    : null,
            boxShadow: [
              if (glowColor != null)
                BoxShadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: Center(
            child: letter != null
                ? Text(
                    letter,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                      color: textColor,
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
                width: 42,
                height: 42,
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
                      fontSize: 20,
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
        color: BrandLoader().colors.surface,
        border: Border(top: BorderSide(color: BrandLoader().colors.textPrimary, width: 2)),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
                Text(
                  isDragTarget ? 'DROP TO RETURN' : 'YOUR LETTERS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: isDragTarget ? BrandLoader().colors.info : BrandLoader().colors.textSecondary,
                    fontWeight: isDragTarget ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 8),
                // Always show 5 tile slots to prevent layout shift
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 42,
      height: 42,
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

    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: BrandLoader().colors.warning.withOpacity(0.15),
        border: Border.all(color: BrandLoader().colors.textPrimary, width: 2),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Georgia',
            color: BrandLoader().colors.textPrimary,
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
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: BrandLoader().colors.warning.withOpacity(0.15),
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
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Georgia',
                color: BrandLoader().colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: BrandLoader().colors.background,
          border: Border.all(color: BrandLoader().colors.borderLight, width: 2),
        ),
      ),
      child: tile,
    );
  }

  Widget _buildActionBar() {
    final hasPlacements = _draftPlacements.isNotEmpty;
    final hintsRemaining = _gameState!.myVision;
    final isMyTurn = _gameState!.isMyTurn;
    final partnerName = StorageService().getPartner()?.name ?? 'Partner';
    final isDisabled = !isMyTurn || _showTurnComplete || _isSubmitting;

    // Determine button state and text
    String buttonText;
    bool buttonEnabled;
    Color buttonBgColor;
    Color buttonTextColor;

    if (_isSubmitting) {
      buttonText = 'SUBMITTING...';
      buttonEnabled = false;
      buttonBgColor = BrandLoader().colors.disabled;
      buttonTextColor = BrandLoader().colors.textOnPrimary;
    } else if (_showTurnComplete || !isMyTurn) {
      buttonText = "${partnerName.toUpperCase()}'S TURN";
      buttonEnabled = false;
      buttonBgColor = BrandLoader().colors.background;
      buttonTextColor = BrandLoader().colors.textSecondary;
    } else if (hasPlacements) {
      buttonText = 'SUBMIT TURN';
      buttonEnabled = true;
      buttonBgColor = BrandLoader().colors.textPrimary;
      buttonTextColor = BrandLoader().colors.textOnPrimary;
    } else {
      buttonText = 'PLACE LETTERS';
      buttonEnabled = false;
      buttonBgColor = BrandLoader().colors.divider;
      buttonTextColor = BrandLoader().colors.disabled;
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
      final result = await _service.submitTurn(
        _gameState!.match.matchId,
        placements,
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

        // Save updated match to local storage after setState (for quest card turn display)
        if (_gameState != null) {
          await StorageService().saveLinkedMatch(_gameState!.match);
        }
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
