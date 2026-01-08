import 'package:flutter/material.dart';

/// Displays tier emoji as a PNG image for reliable color rendering.
///
/// Text-based emojis can render in grayscale due to font inheritance issues.
/// This widget uses PNG images from Twemoji for consistent color display.
class Us2TierEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  final double opacity;

  const Us2TierEmoji({
    super.key,
    required this.emoji,
    this.size = 24,
    this.opacity = 1.0,
  });

  /// Map emoji to image asset filename
  static const _emojiToImage = {
    '🏕️': 'cabin.png',
    '🏕': 'cabin.png',
    '🏖️': 'beach.png',
    '🏖': 'beach.png',
    '⛵': 'yacht.png',
    '🏔️': 'mountain.png',
    '🏔': 'mountain.png',
    '🏰': 'castle.png',
    '👑': 'crown.png',
  };

  @override
  Widget build(BuildContext context) {
    final cleanEmoji = emoji.replaceAll('\uFE0F', '');
    final imageName = _emojiToImage[emoji] ?? _emojiToImage[cleanEmoji];

    if (imageName == null) {
      // Fallback to text emoji if no image mapping exists
      return Text(emoji, style: TextStyle(fontSize: size));
    }

    Widget image = Image.asset(
      'assets/brands/us2/images/tiers/$imageName',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (opacity < 1.0) {
      image = Opacity(opacity: opacity, child: image);
    }

    return SizedBox(
      width: size,
      height: size,
      child: image,
    );
  }
}
