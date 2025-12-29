import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:togetherremind/models/journal_entry.dart';
import 'package:togetherremind/config/journal_fonts.dart';

/// A polaroid-style card widget for displaying journal entries.
///
/// Features:
/// - White frame with shadow (polaroid aesthetic)
/// - Gradient background based on entry type
/// - Type-specific emoji
/// - Time badge (top-right)
/// - Result tag (bottom-center)
/// - Slight rotation for visual interest
class JournalPolaroid extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final int index;

  const JournalPolaroid({
    super.key,
    required this.entry,
    required this.onTap,
    this.index = 0,
  });

  /// Rotation based on index: odd = -2deg, even = 1.5deg
  double get _rotation => index.isOdd
      ? -2 * math.pi / 180
      : 1.5 * math.pi / 180;

  /// Gradient colors per type
  static const Map<JournalEntryType, List<Color>> _typeColors = {
    JournalEntryType.classicQuiz: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
    JournalEntryType.affirmationQuiz: [Color(0xFFFCE4EC), Color(0xFFF8BBD9)],
    JournalEntryType.welcomeQuiz: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    JournalEntryType.youOrMe: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
    JournalEntryType.linked: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
    JournalEntryType.wordSearch: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
    JournalEntryType.stepsTogether: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: _rotation,
        child: Container(
          width: 150,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(31), // ~0.12 opacity
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageArea(),
              Flexible(child: _buildCaptionArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    final colors = _typeColors[entry.type] ??
        [const Color(0xFFE0E0E0), const Color(0xFFBDBDBD)];

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            // Center emoji
            Center(
              child: Text(
                entry.typeEmoji,
                style: const TextStyle(fontSize: 40),
              ),
            ),
            // Time badge (top right)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(204), // ~0.8 opacity
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DateFormat('h:mm a').format(entry.completedAt.toLocal()),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ),
            // Result tag (bottom center)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(child: _buildResultTag()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTag() {
    String text;

    if (entry.isGame) {
      // Linked or Word Search - show scores
      text = 'You ${entry.userScore} - ${entry.partnerScore} Partner';
    } else if (entry.isSteps) {
      // Steps Together - show combined steps
      final percentage = entry.stepGoal > 0
          ? ((entry.combinedSteps / entry.stepGoal) * 100).round()
          : 0;
      text = '$percentage% of goal';
    } else {
      // Quiz-type - show aligned/different
      text = '${entry.alignedCount} aligned';
      if (entry.differentCount > 0) {
        text += ' - ${entry.differentCount} different';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D2D2D),
        ),
      ),
    );
  }

  Widget _buildCaptionArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.title,
            style: JournalFonts.polaroidCaption,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            entry.typeName,
            style: JournalFonts.polaroidType,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
