import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';
import '../../models/linked.dart';

/// Gray clue cell with clue content (text, emoji, or image) and arrow indicator
/// Note: This widget is not currently used - clues are rendered inline in LinkedGameScreen
class LinkedClueCell extends StatelessWidget {
  final LinkedClue clue;
  final double size;
  final VoidCallback? onTap;

  const LinkedClueCell({
    super.key,
    required this.clue,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE8E8E8),
              const Color(0xFFD0D0D0),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFB0B0B0),
            width: 0.5,
          ),
        ),
        child: Stack(
          children: [
            // Clue content (varies by type)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(size * 0.06),
                child: _buildClueContent(),
              ),
            ),
            // Arrow indicator
            Positioned(
              right: clue.isAcross ? 2 : null,
              bottom: clue.isDown ? 2 : null,
              left: clue.isAcross ? null : (size / 2) - 5,
              top: clue.isDown ? null : (size / 2) - 5,
              child: _buildArrow(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build clue content based on type
  Widget _buildClueContent() {
    switch (clue.type) {
      case 'emoji':
        return _buildEmojiClue();
      case 'image':
        return _buildImageClue();
      case 'text':
      default:
        return _buildTextClue();
    }
  }

  /// Text clue - dynamically sized based on text length
  Widget _buildTextClue() {
    final displayText = clue.content.toUpperCase();
    final textLength = displayText.length;
    final hasSpace = displayText.contains(' ');

    double fontSize;
    if (textLength <= 4) {
      fontSize = size * 0.25;
    } else if (textLength <= 8) {
      fontSize = size * 0.18;
    } else if (textLength <= 12 || hasSpace) {
      fontSize = size * 0.14;
    } else {
      fontSize = size * 0.10;
    }

    return Center(
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          fontFamily: 'Arial',
          color: BrandLoader().colors.textPrimary,
          height: 1.1,
        ),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Emoji clue - large centered emoji
  Widget _buildEmojiClue() {
    return Center(
      child: Text(
        clue.content,
        style: TextStyle(
          fontSize: size * 0.5,
          height: 1.0,
        ),
      ),
    );
  }

  /// Image clue - load from URL
  Widget _buildImageClue() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        clue.content,
        width: size * 0.88,
        height: size * 0.88,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: size * 0.3,
              height: size * 0.3,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.broken_image,
            size: size * 0.4,
            color: BrandLoader().colors.textSecondary,
          );
        },
      ),
    );
  }

  Widget _buildArrow() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: BrandLoader().colors.textPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Center(
        child: Text(
          clue.isAcross ? '\u25B6' : '\u25BC', // ▶ or ▼
          style: TextStyle(
            fontSize: 7,
            color: BrandLoader().colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
