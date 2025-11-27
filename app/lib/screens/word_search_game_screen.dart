import 'dart:async';
import 'package:flutter/material.dart';
import '../services/word_search_service.dart';
import '../services/storage_service.dart';
import '../models/word_search.dart';
import '../config/brand/brand_loader.dart';
import '../theme/app_theme.dart';
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
    with SingleTickerProviderStateMixin {
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

  // Polling timer for partner's turn
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 10);

  // Shake animation for invalid words
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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

    _loadGameState();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _shakeController.dispose();
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

  Future<void> _loadGameState() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gameState = await _service.getOrCreateMatch();
      if (mounted) {
        setState(() {
          _gameState = gameState;
          _isLoading = false;
          _clearSelection();
          _hintPosition = null;
        });
        _startPolling();
        _checkGameCompletion();
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
      _navigateToCompletionScreen();
    }
  }

  void _navigateToCompletionScreen() {
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
        _showWordFoundOverlay(_selectedWord.toUpperCase(), result.pointsEarned);

        // Refresh game state
        final newState = await _service.refreshGameState();
        if (mounted) {
          setState(() {
            _gameState = newState;
            _clearSelection();
          });
        }

        if (result.turnComplete) {
          _showToast("Turn complete! Partner's turn now.");
        }

        if (result.gameComplete) {
          _checkGameCompletion();
        }
      } else {
        // Shake grid for invalid word (no toast)
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

    return Stack(
      children: [
        // Main content
        Container(
          color: BrandLoader().colors.surface,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildGameArea()),
              _buildWordBank(),
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
      ],
    );
  }

  Widget _buildHeader() {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final isMyTurn = _gameState!.isMyTurn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                fontSize: 20,
                color: BrandLoader().colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Text(
            'WORD SEARCH',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              letterSpacing: 2,
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
                      fontWeight: isMyTurn ? FontWeight.w700 : FontWeight.w400,
                      color: BrandLoader().colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Partner score
              Row(
                children: [
                  if (!isMyTurn)
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
                    '${partner?.name ?? "Partner"}: ${_gameState!.partnerScore}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: !isMyTurn ? FontWeight.w700 : FontWeight.w400,
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

  Widget _buildGameArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _buildGrid(),
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

    return LayoutBuilder(
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
              child: Container(
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
                ),
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
          ),
        );
      },
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

    // Fixed height for word items (4 rows * 36px + 3 gaps * 8px + padding)
    const double wordItemHeight = 36;
    const double rowCount = 4;
    const double gapSize = 8;
    const double totalHeight = (wordItemHeight * rowCount) + (gapSize * (rowCount - 1));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BrandLoader().colors.surface,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
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
                '${match.totalWordsFound} / 12',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: BrandLoader().colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Word grid (3 columns, fixed height)
          SizedBox(
            height: totalHeight,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: gapSize,
                crossAxisSpacing: gapSize,
                mainAxisExtent: wordItemHeight,
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.surface,
                    border: Border.all(
                      color: found ? color! : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      word.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: found
                            ? color!.withValues(alpha: 0.6)
                            : BrandLoader().colors.textPrimary,
                        decoration: found ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isMyTurn = _gameState!.isMyTurn;
    final hintsRemaining = _gameState!.myHints;
    final wordsThisTurn = _gameState!.match.wordsFoundThisTurn;

    return Container(
      padding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    const SizedBox(width: 6),
                    Text(
                      'HINT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: isMyTurn && hintsRemaining > 0
                            ? BrandLoader().colors.textPrimary
                            : const Color(0xFFBDBDBD),
                      ),
                    ),
                    const SizedBox(width: 4),
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
          const SizedBox(width: 12),
          // Turn progress
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: isMyTurn
                              ? BrandLoader().colors.textOnPrimary.withValues(alpha: filled ? 1.0 : 0.4)
                              : BrandLoader().colors.textSecondary.withValues(alpha: filled ? 1.0 : 0.4),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMyTurn ? '$wordsThisTurn/3 FOUND' : "PARTNER'S TURN",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
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

  _WordSearchLinePainter({
    required this.cellSize,
    required this.selectedPositions,
    required this.foundWords,
    required this.wordColors,
    required this.isSelecting,
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

    // Draw current selection line (on top)
    if (selectedPositions.isNotEmpty && isSelecting) {
      final paint = Paint()
        ..color = const Color(0xFFFF9800).withValues(alpha: 0.5) // Orange
        ..strokeWidth = cellSize * 0.7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (selectedPositions.length >= 2) {
        final first = selectedPositions.first;
        final last = selectedPositions.last;

        final startX = (first.col + 0.5) * cellSize;
        final startY = (first.row + 0.5) * cellSize;
        final endX = (last.col + 0.5) * cellSize;
        final endY = (last.row + 0.5) * cellSize;

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WordSearchLinePainter oldDelegate) {
    return oldDelegate.selectedPositions != selectedPositions ||
        oldDelegate.foundWords != foundWords ||
        oldDelegate.isSelecting != isSelecting;
  }
}
