import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import '../../../config/brand/us2_theme.dart';
import '../../../models/linked.dart';

/// Debug tab for previewing crossword puzzle layouts with different font variants
class CrosswordPreviewTab extends StatefulWidget {
  const CrosswordPreviewTab({super.key});

  @override
  State<CrosswordPreviewTab> createState() => _CrosswordPreviewTabState();
}

class _CrosswordPreviewTabState extends State<CrosswordPreviewTab> {
  int _selectedPuzzle = 0;
  int _selectedVariant = 0; // 0=D, 1=E, 2=F, 3=G1, 4=G2, 5=G3, 6=G4
  LinkedPuzzle? _puzzle;
  bool _loading = false;
  String? _error;

  // Puzzle IDs and display names
  final List<String> _puzzleIds = [
    'puzzle_5x7_001',
    'puzzle_5x7_002',
    'puzzle_5x7_003',
    'puzzle_5x7_004',
    'puzzle_7x9_001',
    'puzzle_7x9_002',
  ];

  final List<String> _puzzleNames = [
    '5×7 #1',
    '5×7 #2',
    '5×7 #3',
    '5×7 #4',
    '7×9 #1',
    '7×9 #2',
  ];

  final List<String> _variantNames = [
    'D: Auto-scale by length',
    'E: Auto-scale, emoji-text aware',
    'F: No ellipsis, shrink to fit',
    'G1: Split emoji/text (small)',
    'G2: Split emoji/text (medium)',
    'G3: Split emoji/text (large)',
    'G4: Split emoji/text (fitted)',
  ];

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  Future<void> _loadPuzzle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load puzzle from debug assets
      final puzzleId = _puzzleIds[_selectedPuzzle];
      final jsonString = await rootBundle.loadString(
        'assets/debug/linked/$puzzleId.json',
      );
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final puzzle = _convertRawPuzzle(json);

      setState(() {
        _puzzle = puzzle;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load puzzle: $e';
        _loading = false;
      });
    }
  }

  /// Convert raw puzzle JSON (with grid) to LinkedPuzzle (with cellTypes)
  LinkedPuzzle _convertRawPuzzle(Map<String, dynamic> json) {
    final size = json['size'] as Map<String, dynamic>;
    final rows = size['rows'] as int;
    final cols = size['cols'] as int;
    final grid = List<String>.from(json['grid'] ?? []);
    final cluesJson = json['clues'] as Map<String, dynamic>;

    // Build clue cell indices from target_index values
    final clueCellIndices = <int>{};

    void addClueCellIndex(int targetIndex, String direction) {
      if (direction == 'across') {
        clueCellIndices.add(targetIndex - 1); // Left of answer
      } else if (direction == 'down') {
        clueCellIndices.add(targetIndex - cols); // Above answer
      }
    }

    for (final entry in cluesJson.entries) {
      final clueData = entry.value as Map<String, dynamic>;
      if (clueData.containsKey('arrow')) {
        // Single-direction clue
        addClueCellIndex(clueData['target_index'] as int, clueData['arrow'] as String);
      } else {
        // Dual-direction clue
        if (clueData.containsKey('across')) {
          final across = clueData['across'] as Map<String, dynamic>;
          addClueCellIndex(across['target_index'] as int, 'across');
        }
        if (clueData.containsKey('down')) {
          final down = clueData['down'] as Map<String, dynamic>;
          addClueCellIndex(down['target_index'] as int, 'down');
        }
      }
    }

    // Build cellTypes array
    final cellTypes = <String>[];
    for (int i = 0; i < grid.length; i++) {
      if (clueCellIndices.contains(i)) {
        cellTypes.add('clue');
      } else if (grid[i] == '.') {
        cellTypes.add('void');
      } else {
        cellTypes.add('answer');
      }
    }

    // Parse clues
    final clues = <String, LinkedClue>{};
    for (final entry in cluesJson.entries) {
      final clueNumStr = entry.key;
      final clueNum = int.tryParse(clueNumStr) ?? 0;
      final clueData = entry.value as Map<String, dynamic>;

      if (clueData.containsKey('arrow')) {
        // Single-direction format
        clues[clueNumStr] = LinkedClue.fromJson(clueData, clueNumber: clueNum);
      } else {
        // Dual-direction format
        if (clueData.containsKey('across')) {
          final acrossData = clueData['across'] as Map<String, dynamic>;
          clues['${clueNumStr}_across'] = LinkedClue.fromJsonDirection(
            acrossData,
            clueNumber: clueNum,
            direction: 'across',
          );
        }
        if (clueData.containsKey('down')) {
          final downData = clueData['down'] as Map<String, dynamic>;
          clues['${clueNumStr}_down'] = LinkedClue.fromJsonDirection(
            downData,
            clueNumber: clueNum,
            direction: 'down',
          );
        }
      }
    }

    return LinkedPuzzle(
      puzzleId: json['puzzleId'] ?? 'unknown',
      title: json['title'] ?? 'Preview Puzzle',
      author: json['author'] ?? 'Unknown',
      rows: rows,
      cols: cols,
      clues: clues,
      cellTypes: cellTypes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Puzzle selector
          Text(
            'SELECT PUZZLE',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_puzzleIds.length, (index) {
              final isSelected = _selectedPuzzle == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedPuzzle = index);
                  _loadPuzzle();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Us2Theme.primaryBrandPink : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _puzzleNames[index],
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // Variant selector
          Text(
            'FONT VARIANT',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(7, (index) {
            final isSelected = _selectedVariant == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedVariant = index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Us2Theme.primaryBrandPink.withValues(alpha: 0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Us2Theme.primaryBrandPink : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  _variantNames[index],
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Us2Theme.primaryBrandPink : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Preview
          Text(
            'PREVIEW',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_puzzle != null)
            _buildPreviewGrid(),
        ],
      ),
    );
  }

  Widget _buildPreviewGrid() {
    final puzzle = _puzzle!;
    final gridCols = puzzle.cols;
    final gridRows = puzzle.rows;
    final cellSize = (MediaQuery.of(context).size.width - 64) / gridCols;

    return Container(
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Us2Theme.cellBorder, width: 2),
      ),
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridCols,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: gridRows * gridCols,
        itemBuilder: (context, index) {
          // Check if this is a clue cell
          if (puzzle.isClueCell(index)) {
            // Check for split clues (two clues in same cell)
            final splitClues = puzzle.getSplitClues(index);
            if (splitClues != null) {
              return _buildSplitClueCellPreview(splitClues[0], splitClues[1], cellSize);
            }

            // Regular single clue
            final clue = puzzle.getClueAtCell(index);
            if (clue != null) {
              return _buildClueCell(clue, cellSize);
            }
          }

          // Check if this is a void cell
          if (puzzle.isVoidCell(index)) {
            return Container(
              decoration: BoxDecoration(
                color: Us2Theme.textDark,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }

          // Answer cell
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Us2Theme.cellBorder, width: 1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClueCell(LinkedClue clue, double cellSize) {
    final isDown = clue.arrow == 'down';
    final displayText = clue.content.toUpperCase();
    final textLength = displayText.length;
    final hasSpace = displayText.contains(' ');
    final scaleFactor = cellSize / 50.0;

    // Check for pure emoji (no text)
    final isActuallyEmoji = clue.type == 'emoji' &&
        textLength <= 2 &&
        !RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(clue.content);

    // Check for emoji+text combination (emoji followed by text)
    final hasEmojiPrefix = _hasEmojiPrefix(clue.content);
    final isEmojiText = hasEmojiPrefix && textLength > 2;

    // Variants G1-G4 (indices 3-6) use split rendering for any text with spaces
    if (_selectedVariant >= 3 && hasSpace && !isActuallyEmoji) {
      final gVariant = _selectedVariant - 3; // 0=G1, 1=G2, 2=G3, 3=G4
      return _buildSplitTextCell(clue, cellSize, isDown, scaleFactor, gVariant, isEmojiText);
    }

    // Calculate font size based on selected variant
    double fontSize;
    int maxLines;
    double lineHeight;
    TextOverflow overflow;

    switch (_selectedVariant) {
      case 0: // Variant D: Auto-scale based on length
        fontSize = _getVariantDFontSize(textLength, isActuallyEmoji, hasSpace, cellSize);
        maxLines = 2;
        lineHeight = 1.0;
        overflow = TextOverflow.ellipsis;
        break;
      case 1: // Variant E: Auto-scale with emoji-text awareness
        fontSize = _getVariantEFontSize(clue.content, isActuallyEmoji, isEmojiText, cellSize);
        maxLines = 2;
        lineHeight = 1.0;
        overflow = TextOverflow.ellipsis;
        break;
      case 2: // Variant F: No ellipsis, shrink to fit
        fontSize = _getVariantFFontSize(clue.content, isActuallyEmoji, isEmojiText, cellSize);
        maxLines = 3;
        lineHeight = 0.95;
        overflow = TextOverflow.visible;
        break;
      case 3: // G1: Split (non-emoji case falls through to D)
      case 4: // G2: Split (non-emoji case falls through to D)
      case 5: // G3: Split (non-emoji case falls through to D)
      case 6: // G4: Split (non-emoji case falls through to D)
      default:
        fontSize = _getVariantDFontSize(textLength, isActuallyEmoji, hasSpace, cellSize);
        maxLines = 2;
        lineHeight = 1.0;
        overflow = TextOverflow.ellipsis;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: Us2Theme.clueCellGradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Us2Theme.cellBorder, width: 1),
      ),
      padding: const EdgeInsets.all(2),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
              child: isActuallyEmoji
                  ? Text(
                      clue.content,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        height: lineHeight,
                      ),
                    )
                  : SizedBox(
                      width: cellSize - 8,
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
                            color: Us2Theme.textDark,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          // Direction arrow
          Positioned(
            bottom: isDown ? 0 : null,
            top: isDown ? null : 0,
            left: isDown ? 0 : null,
            right: isDown ? null : 0,
            child: Text(
              isDown ? '▼' : '▶',
              style: TextStyle(
                fontSize: 5 * scaleFactor,
                color: Us2Theme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a split clue cell containing two clues (across on top, down on bottom)
  Widget _buildSplitClueCellPreview(LinkedClue acrossClue, LinkedClue downClue, double cellSize) {
    final scaleFactor = cellSize / 50.0;

    return Container(
      decoration: BoxDecoration(
        gradient: Us2Theme.clueCellGradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Us2Theme.cellBorder, width: 1),
      ),
      child: Column(
        children: [
          // Top half: across clue
          Expanded(
            child: _buildSplitClueHalfPreview(acrossClue, scaleFactor, isTop: true),
          ),
          // Divider line
          Container(
            height: 1,
            color: Us2Theme.textLight.withValues(alpha: 0.4),
          ),
          // Bottom half: down clue
          Expanded(
            child: _buildSplitClueHalfPreview(downClue, scaleFactor, isTop: false),
          ),
        ],
      ),
    );
  }

  /// Build one half of a split clue cell using FittedBox for auto-scaling
  Widget _buildSplitClueHalfPreview(LinkedClue clue, double scaleFactor, {required bool isTop}) {
    final isDown = clue.arrow == 'down';
    final displayText = clue.content.toUpperCase();

    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                displayText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  color: Us2Theme.textDark,
                ),
              ),
            ),
          ),
        ),
        // Direction arrow
        Positioned(
          bottom: isDown ? 0 : null,
          top: isDown ? null : 0,
          left: isDown ? 0 : null,
          right: isDown ? null : 0,
          child: Text(
            isDown ? '▼' : '▶',
            style: TextStyle(
              fontSize: 4 * scaleFactor,
              color: Us2Theme.textLight,
            ),
          ),
        ),
      ],
    );
  }

  /// Check if content starts with an emoji character
  bool _hasEmojiPrefix(String content) {
    if (content.isEmpty) return false;
    // Emoji regex pattern - matches common emoji ranges
    final emojiPattern = RegExp(
      r'^[\u{1F300}-\u{1F9FF}]|^[\u{2600}-\u{26FF}]|^[\u{2700}-\u{27BF}]|^[\u{1F600}-\u{1F64F}]|^[\u{1F680}-\u{1F6FF}]',
      unicode: true,
    );
    return emojiPattern.hasMatch(content);
  }

  /// Variants G1-G4: Split text at spaces into separate lines
  /// gVariant: 0=G1(small), 1=G2(medium), 2=G3(large), 3=G4(fitted)
  Widget _buildSplitTextCell(LinkedClue clue, double cellSize, bool isDown, double scaleFactor, int gVariant, bool hasEmojiPrefix) {
    // Extract emoji and text parts (if emoji exists)
    String emoji = '';
    String text = clue.content.toUpperCase();

    if (hasEmojiPrefix) {
      final parts = _splitEmojiAndText(clue.content);
      emoji = parts['emoji'] ?? '';
      text = parts['text']?.toUpperCase() ?? '';
    }

    // Emoji size varies by variant
    final emojiFontSize = switch (gVariant) {
      0 => 14 * scaleFactor,  // G1: small emoji
      1 => 16 * scaleFactor,  // G2: medium emoji
      2 => 18 * scaleFactor,  // G3: large emoji
      3 => 16 * scaleFactor,  // G4: medium emoji (text is fitted)
      _ => 16 * scaleFactor,
    };

    // Text size varies by variant - G2, G3, G4 have bigger text
    final textFontSize = switch (gVariant) {
      0 => _getTextOnlyFontSize(text.length, cellSize),           // G1: original small
      1 => _getTextOnlyFontSizeMedium(text.length, cellSize),     // G2: medium
      2 => _getTextOnlyFontSizeLarge(text.length, cellSize),      // G3: large
      3 => _getTextOnlyFontSizeLarge(text.length, cellSize),      // G4: large (will be fitted)
      _ => _getTextOnlyFontSize(text.length, cellSize),
    };

    // G4 uses FittedBox for text
    final usesFittedBox = gVariant == 3;

    return Container(
      decoration: BoxDecoration(
        gradient: Us2Theme.clueCellGradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Us2Theme.cellBorder, width: 1),
      ),
      padding: const EdgeInsets.all(2),
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: cellSize - 4,
              height: cellSize - 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji.isNotEmpty)
                      Text(
                        emoji,
                        style: TextStyle(
                          fontSize: emojiFontSize,
                          height: 1.0,
                        ),
                      ),
                    // Force wrap at spaces - split text into separate lines
                    if (text.isNotEmpty)
                      ...text.split(' ').map((word) =>
                        Text(
                          word,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Arial',
                            fontSize: usesFittedBox ? 14 : textFontSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 0.95,
                            color: Us2Theme.textDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Direction arrow
          Positioned(
            bottom: isDown ? 0 : null,
            top: isDown ? null : 0,
            left: isDown ? 0 : null,
            right: isDown ? null : 0,
            child: Text(
              isDown ? '▼' : '▶',
              style: TextStyle(
                fontSize: 5 * scaleFactor,
                color: Us2Theme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
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

  /// Font size for text-only part in split rendering - G1 (small)
  double _getTextOnlyFontSize(int textLength, double cellSize) {
    if (textLength <= 3) return 10.0;
    if (textLength <= 5) return 9.0;
    if (textLength <= 8) return 8.0;
    return 7.0;
  }

  /// Font size for text-only part in split rendering - G2 (medium)
  double _getTextOnlyFontSizeMedium(int textLength, double cellSize) {
    if (textLength <= 3) return 12.0;
    if (textLength <= 5) return 11.0;
    if (textLength <= 8) return 10.0;
    return 9.0;
  }

  /// Font size for text-only part in split rendering - G3 (large)
  double _getTextOnlyFontSizeLarge(int textLength, double cellSize) {
    if (textLength <= 3) return 14.0;
    if (textLength <= 5) return 12.0;
    if (textLength <= 8) return 11.0;
    return 10.0;
  }

  // Variant D: Auto-scale based on length and cell size
  double _getVariantDFontSize(int textLength, bool isEmoji, bool hasSpace, double cellSize) {
    if (isEmoji) return 28 * (cellSize / 50.0);

    // Calculate ideal font size based on cell size and text length
    // Aim for text to fit in 2 lines at most
    final availableWidth = cellSize - 6; // padding
    final charsPerLine = textLength > 8 ? (textLength / 2).ceil() : textLength;
    final idealCharWidth = availableWidth / charsPerLine;
    final fontSize = idealCharWidth * 1.2; // Font size is typically ~1.2x char width

    // Clamp to reasonable range
    return fontSize.clamp(7.0, 16.0);
  }

  // Variant E: Auto-scale with emoji+text awareness
  // Accounts for emoji taking more visual width than regular characters
  double _getVariantEFontSize(String content, bool isEmoji, bool isEmojiText, double cellSize) {
    if (isEmoji) return 28 * (cellSize / 50.0);

    final textLength = content.length;
    final availableWidth = cellSize - 6;

    if (isEmojiText) {
      // Emoji+text: emoji takes ~2 char widths, reduce effective space
      // Extract text part only for length calculation
      final parts = _splitEmojiAndText(content);
      final textOnly = parts['text'] ?? '';
      final textOnlyLength = textOnly.length;

      // For emoji+text, be more aggressive with smaller font
      if (textOnlyLength <= 4) return 9.0;
      if (textOnlyLength <= 6) return 8.0;
      if (textOnlyLength <= 10) return 7.0;
      return 6.0;
    }

    // Regular text - same as variant D
    final charsPerLine = textLength > 8 ? (textLength / 2).ceil() : textLength;
    final idealCharWidth = availableWidth / charsPerLine;
    final fontSize = idealCharWidth * 1.2;
    return fontSize.clamp(7.0, 16.0);
  }

  // Variant F: No ellipsis, shrink to fit all content
  // Uses smaller base sizes and allows more wrapping
  double _getVariantFFontSize(String content, bool isEmoji, bool isEmojiText, double cellSize) {
    if (isEmoji) return 24 * (cellSize / 50.0); // Slightly smaller emoji

    final textLength = content.length;

    if (isEmojiText) {
      // Emoji+text: be very conservative to ensure no truncation
      final parts = _splitEmojiAndText(content);
      final textOnly = parts['text'] ?? '';
      final textOnlyLength = textOnly.length;

      if (textOnlyLength <= 3) return 8.0;
      if (textOnlyLength <= 5) return 7.0;
      if (textOnlyLength <= 8) return 6.5;
      return 6.0;
    }

    // Regular text - smaller sizes to prevent truncation
    if (textLength <= 3) return 14.0;
    if (textLength <= 5) return 11.0;
    if (textLength <= 8) return 9.0;
    if (textLength <= 12) return 7.5;
    return 6.5;
  }
}
