import 'package:flutter/material.dart';
import '../../models/linked.dart';
import 'void_cell.dart';
import 'clue_cell.dart';
import 'answer_cell.dart';

/// Grid widget for rendering the arroword puzzle
///
/// Uses Stack with Positioned widgets for absolute cell placement
/// Two-layer rendering:
/// 1. Check gridnums - if > 0, render CLUE cell
/// 2. Check grid position - if void area, render VOID cell; else ANSWER cell
class LinkedGrid extends StatelessWidget {
  final LinkedPuzzle puzzle;
  final Map<String, String> boardState; // Locked cells
  final Map<int, String> draftPlacements; // Draft placements (cellIndex -> letter)
  final Set<int> highlightedCells; // Cells highlighted by hint
  final int? dragTargetCell; // Cell being dragged over
  final bool isInteractive; // False during partner's turn
  final Function(int cellIndex, DragData data)? onDrop;
  final Function(int cellIndex)? onCellTap;
  final Function(LinkedClue clue)? onClueTap;

  const LinkedGrid({
    super.key,
    required this.puzzle,
    required this.boardState,
    this.draftPlacements = const {},
    this.highlightedCells = const {},
    this.dragTargetCell,
    this.isInteractive = true,
    this.onDrop,
    this.onCellTap,
    this.onClueTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size based on available width
        final availableWidth = constraints.maxWidth;
        final cellSize = availableWidth / puzzle.cols;

        // Calculate total height
        final totalHeight = cellSize * puzzle.rows;

        return SizedBox(
          width: availableWidth,
          height: totalHeight,
          child: Stack(
            children: _buildCells(cellSize),
          ),
        );
      },
    );
  }

  List<Widget> _buildCells(double cellSize) {
    final cells = <Widget>[];

    for (int i = 0; i < puzzle.gridnums.length; i++) {
      final row = i ~/ puzzle.cols;
      final col = i % puzzle.cols;
      final clueNum = puzzle.gridnums[i];

      // Calculate position
      final left = col * cellSize;
      final top = row * cellSize;

      Widget cell;

      // Layer 1: Check if this is a clue cell
      if (clueNum > 0 && puzzle.clues.containsKey(clueNum.toString())) {
        final clue = puzzle.clues[clueNum.toString()]!;
        cell = LinkedClueCell(
          clue: clue,
          size: cellSize,
          onTap: () => onClueTap?.call(clue),
        );
      }
      // Layer 2: Check cell type (we don't have grid solution on client)
      // Use position-based logic: row 0 and col 0 are clue frame
      else if (row == 0 || col == 0) {
        // Clue frame area but no clue - void cell
        cell = LinkedVoidCell(size: cellSize);
      }
      // Answer cell (in the playable area)
      else {
        cell = _buildAnswerCell(i, cellSize);
      }

      cells.add(
        Positioned(
          left: left,
          top: top,
          child: cell,
        ),
      );
    }

    return cells;
  }

  Widget _buildAnswerCell(int cellIndex, double cellSize) {
    // Check if locked (from server)
    final lockedLetter = boardState[cellIndex.toString()];
    if (lockedLetter != null) {
      return LinkedAnswerCell(
        size: cellSize,
        state: AnswerCellState.locked,
        letter: lockedLetter,
        onTap: () => onCellTap?.call(cellIndex),
      );
    }

    // Check if has draft placement
    final draftLetter = draftPlacements[cellIndex];
    if (draftLetter != null) {
      if (isInteractive) {
        // Return a draggable cell
        return _buildDraggableAnswerCell(cellIndex, draftLetter, cellSize);
      } else {
        // Non-interactive draft
        return LinkedAnswerCell(
          size: cellSize,
          state: AnswerCellState.draft,
          letter: draftLetter,
        );
      }
    }

    // Empty answer cell - can be a drop target
    if (isInteractive) {
      return _buildDropTargetCell(cellIndex, cellSize);
    } else {
      return LinkedAnswerCell(
        size: cellSize,
        state: AnswerCellState.empty,
      );
    }
  }

  Widget _buildDraggableAnswerCell(int cellIndex, String letter, double cellSize) {
    // Find the rack index for this draft placement
    // This would need to be tracked in the parent widget
    return DraggableAnswerCell(
      size: cellSize,
      letter: letter,
      cellIndex: cellIndex,
      rackIndex: -1, // Will be set properly by parent
    );
  }

  Widget _buildDropTargetCell(int cellIndex, double cellSize) {
    final isTarget = dragTargetCell == cellIndex;
    final isHighlighted = highlightedCells.contains(cellIndex);

    return DragTarget<DragData>(
      onWillAcceptWithDetails: (details) {
        // Accept if cell is empty
        final isLocked = boardState.containsKey(cellIndex.toString());
        final hasDraft = draftPlacements.containsKey(cellIndex);
        return !isLocked && !hasDraft;
      },
      onAcceptWithDetails: (details) {
        onDrop?.call(cellIndex, details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isDraggingOver = candidateData.isNotEmpty;

        return LinkedAnswerCell(
          size: cellSize,
          state: AnswerCellState.empty,
          isHighlighted: isHighlighted,
          isDragTarget: isDraggingOver || isTarget,
          onTap: () => onCellTap?.call(cellIndex),
        );
      },
    );
  }
}

/// Grid wrapper with zoom/pan support
class InteractiveLinkedGrid extends StatelessWidget {
  final LinkedPuzzle puzzle;
  final Map<String, String> boardState;
  final Map<int, String> draftPlacements;
  final Set<int> highlightedCells;
  final int? dragTargetCell;
  final bool isInteractive;
  final Function(int cellIndex, DragData data)? onDrop;
  final Function(int cellIndex)? onCellTap;
  final Function(LinkedClue clue)? onClueTap;

  const InteractiveLinkedGrid({
    super.key,
    required this.puzzle,
    required this.boardState,
    this.draftPlacements = const {},
    this.highlightedCells = const {},
    this.dragTargetCell,
    this.isInteractive = true,
    this.onDrop,
    this.onCellTap,
    this.onClueTap,
  });

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(20),
      child: LinkedGrid(
        puzzle: puzzle,
        boardState: boardState,
        draftPlacements: draftPlacements,
        highlightedCells: highlightedCells,
        dragTargetCell: dragTargetCell,
        isInteractive: isInteractive,
        onDrop: onDrop,
        onCellTap: onCellTap,
        onClueTap: onClueTap,
      ),
    );
  }
}
