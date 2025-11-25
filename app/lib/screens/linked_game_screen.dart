import 'dart:async';
import 'package:flutter/material.dart';
import '../services/linked_service.dart';
import '../services/storage_service.dart';
import '../models/linked.dart';
import '../widgets/linked/answer_cell.dart';
import 'linked_completion_screen.dart';

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
          _draftPlacements.clear();
          _draftRackIndices.clear();
          _usedRackIndices.clear();
          _highlightedCells.clear();
          _cellAnimations.clear();
          _showTurnComplete = false;
          _currentWordIndex = -1;
          _lastResult = null;
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
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
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

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildGridWithOverlay()),
          _buildBottomSection(),
        ],
      ),
    );
  }

  /// Header: ← Linked | You: 0 | Taija: 30
  Widget _buildHeader() {
    final partnerName = StorageService().getPartner()?.name ?? 'Partner';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
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
            'LINKED',
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
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
    return Stack(
      children: [
        _buildGrid(),
        // Floating points overlay (only during animation)
        ..._buildFloatingPoints(),
        // Word completion overlay (handles its own visibility)
        _buildWordCompletionOverlay(),
      ],
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
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: AspectRatio(
          aspectRatio: cols / rows,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF222222),
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
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      '${word.word} +${word.bonus}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
      return Container(color: const Color(0xFF222222));
    }

    if (puzzle.isClueCell(index)) {
      final clueNum = puzzle.gridnums[index];
      final clue = puzzle.clues[clueNum.toString()];
      if (clue != null) {
        return _buildClueCell(clue);
      }
      // Fallback if clue not found
      return Container(color: const Color(0xFFE8E8E8));
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
        color: const Color(0xFFE8E8E8),
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
                  color: const Color(0xFF111111),
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
                style: const TextStyle(
                  fontSize: 6,
                  color: Color(0xFF666666),
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

  Widget _buildAnswerCell(int index, String? letter, AnswerCellState state, {bool showGlow = false}) {
    final isHighlighted = _highlightedCells.contains(index);
    final isInteractive = _gameState!.isMyTurn && state != AnswerCellState.locked && !_isSubmitting;

    // Also accept drops on draft cells (to swap/replace letters)
    final canAcceptDrop = isInteractive && (state == AnswerCellState.empty || state == AnswerCellState.draft);

    // Draft cells can be dragged to move to another cell
    final canDrag = isInteractive && state == AnswerCellState.draft && letter != null;

    return DragTarget<_RackDragData>(
      onWillAcceptWithDetails: (details) => canAcceptDrop,
      onAcceptWithDetails: (details) {
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
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isDragTarget = candidateData.isNotEmpty;

        Color bgColor;
        Color textColor = Colors.black87;
        Color? glowColor;

        switch (state) {
          case AnswerCellState.empty:
            bgColor = isDragTarget ? const Color(0xFFE3F2FD) : Colors.white;
          case AnswerCellState.draft:
            bgColor = isDragTarget ? const Color(0xFFE3F2FD) : const Color(0xFFFFEE58);
          case AnswerCellState.locked:
            bgColor = const Color(0xFF81C784);
            textColor = const Color(0xFF1B5E20);
            if (showGlow) glowColor = Colors.green;
          case AnswerCellState.incorrect:
            bgColor = const Color(0xFFEF5350);
            textColor = Colors.white;
        }

        // Store cell position for floating points animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateCellPosition(context, index);
        });

        final cellContent = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: bgColor,
            border: isDragTarget
                ? Border.all(color: const Color(0xFF2196F3), width: 2)
                : null,
            boxShadow: [
              if (isHighlighted)
                BoxShadow(color: Colors.blue.withValues(alpha: 0.5), blurRadius: 8),
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

        // If this is a draft cell, make it draggable
        if (canDrag) {
          final rackIndex = _draftRackIndices[index] ?? -1;
          return Draggable<_RackDragData>(
            data: _RackDragData(letter: letter!, rackIndex: rackIndex, fromCellIndex: index),
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
                  color: const Color(0xFFFFEE58),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
              ),
            ),
            childWhenDragging: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
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
    );
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 2)),
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
            color: isDragTarget ? const Color(0xFFE3F2FD) : null,
            border: Border(
              bottom: const BorderSide(color: Color(0xFFE0E0E0)),
              top: isDragTarget ? const BorderSide(color: Color(0xFF2196F3), width: 2) : BorderSide.none,
            ),
          ),
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Column(
              children: [
                Text(
                  isDragTarget ? 'DROP TO RETURN' : (isMyTurn ? 'YOUR LETTERS' : 'WAITING FOR PARTNER'),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: isDragTarget ? const Color(0xFF2196F3) : const Color(0xFF666666),
                    fontWeight: isDragTarget ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(rack.length, (index) {
                    final letter = rack[index];
                    final isUsed = _usedRackIndices.contains(index);
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

  Widget _buildRackTile(String letter, int rackIndex, bool isUsed, {bool isDisabled = false}) {
    if (isUsed) {
      // Empty slot
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(
            color: const Color(0xFFCCCCCC),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
      );
    }

    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Georgia',
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
            color: const Color(0xFFFFF8E1),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Georgia',
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
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: const Color(0xFFCCCCCC), width: 2),
        ),
      ),
      child: tile,
    );
  }

  Widget _buildActionBar() {
    final hasPlacements = _draftPlacements.isNotEmpty;
    final hintsRemaining = _gameState!.match.player1Vision;
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
      buttonBgColor = Colors.grey;
      buttonTextColor = Colors.white;
    } else if (_showTurnComplete || !isMyTurn) {
      buttonText = "${partnerName.toUpperCase()}'S TURN";
      buttonEnabled = false;
      buttonBgColor = const Color(0xFFE8E8E8);
      buttonTextColor = const Color(0xFF666666);
    } else if (hasPlacements) {
      buttonText = 'SUBMIT TURN';
      buttonEnabled = true;
      buttonBgColor = Colors.black;
      buttonTextColor = Colors.white;
    } else {
      buttonText = 'PLACE LETTERS';
      buttonEnabled = false;
      buttonBgColor = const Color(0xFFE0E0E0);
      buttonTextColor = Colors.grey;
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
                    color: Colors.white,
                    border: Border.all(color: isDisabled ? Colors.grey : Colors.black),
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
                          color: (hintsRemaining > 0 && !isDisabled) ? Colors.black : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($hintsRemaining)',
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'Georgia',
                          color: (hintsRemaining > 0 && !isDisabled) ? Colors.black54 : Colors.grey,
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
                  border: Border.all(color: Colors.black),
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
      final result = await _service.useHint(_gameState!.match.matchId);
      if (mounted) {
        setState(() => _highlightedCells.add(result.cellIndex));
        _showToast('${result.validCells.length} valid placements highlighted!');

        // Clear highlights after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _highlightedCells.clear());
          }
        });

        await _loadGameState();
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

        // Show turn complete state
        setState(() {
          _isSubmitting = false;
          _showTurnComplete = true;
        });

        // Reload game state after animation
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadGameState();
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

  Future<void> _animateResults(LinkedTurnResult result) async {
    // Phase 1: Animate each letter placement with staggered timing
    for (int i = 0; i < result.results.length; i++) {
      final placement = result.results[i];
      final points = placement.correct ? 10 : 0;

      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        setState(() {
          _cellAnimations[placement.cellIndex] = _CellAnimationState(
            isCorrect: placement.correct,
            points: points,
            showPoints: true,
            justLocked: placement.correct,
          );
        });
      }
    }

    // Wait for last letter animation to complete (1200ms for FloatingPointsWidget)
    await Future.delayed(const Duration(milliseconds: 1400));

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

  _CellAnimationState({
    required this.isCorrect,
    required this.points,
    required this.showPoints,
    required this.justLocked,
  });

  _CellAnimationState copyWith({
    bool? isCorrect,
    int? points,
    bool? showPoints,
    bool? justLocked,
  }) {
    return _CellAnimationState(
      isCorrect: isCorrect ?? this.isCorrect,
      points: points ?? this.points,
      showPoints: showPoints ?? this.showPoints,
      justLocked: justLocked ?? this.justLocked,
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
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFEF5350),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isCorrect ? Colors.green : Colors.red)
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.isCorrect ? '+${widget.points}' : '✗',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
