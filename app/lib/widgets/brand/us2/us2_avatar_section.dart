import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';

/// Avatar section showing two characters with badges
///
/// Based on us2-home-v2.html mockup:
/// - Avatars positioned at edges with name badges overlaid at bottom
/// - Left: Partner name (dark text with white glow)
/// - Right: "You & [PartnerName]" (white text with dark glow - highlighted)
class Us2AvatarSection extends StatelessWidget {
  final String userName;
  final String partnerName;

  const Us2AvatarSection({
    super.key,
    required this.userName,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left character (partner)
          Expanded(
            child: _buildCharacter(
              imagePath: 'assets/brands/us2/images/character_female.png',
              label: 'PARTY',
              alignment: Alignment.centerLeft,
              isHighlighted: false,
              leftAlignLabel: true,
            ),
          ),
          // Right character (user + partner)
          Expanded(
            child: _buildCharacter(
              imagePath: 'assets/brands/us2/images/character_male.png',
              label: 'You & $partnerName',
              alignment: Alignment.centerRight,
              isHighlighted: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacter({
    required String imagePath,
    required String label,
    required Alignment alignment,
    bool isHighlighted = false,
    bool leftAlignLabel = false,
  }) {
    return SizedBox(
      height: 235,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Character image
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to emoji if image not found
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Us2Theme.bgGradientStart,
                        Us2Theme.cardSalmon.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Text('👤', style: TextStyle(fontSize: 60)),
                  ),
                );
              },
            ),
          ),
          // Badge label - positioned at bottom
          // leftAlignLabel: align with CONNECTION BAR title (1px from left edge of section)
          Positioned(
            bottom: 10,
            left: leftAlignLabel ? 1 : (alignment == Alignment.centerLeft ? 18 : null),
            right: alignment == Alignment.centerRight ? 0 : null,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: isHighlighted ? Colors.white : const Color(0xFF1A1A1A),
                shadows: isHighlighted
                    ? [
                        // Dark glow for highlighted (white text)
                        const Shadow(
                          blurRadius: 8,
                          color: Color(0xFF1E1E1E),
                          offset: Offset.zero,
                        ),
                        Shadow(
                          blurRadius: 12,
                          color: const Color(0xFF141414).withOpacity(0.9),
                          offset: Offset.zero,
                        ),
                        Shadow(
                          blurRadius: 16,
                          color: const Color(0xFF0A0A0A).withOpacity(0.7),
                          offset: Offset.zero,
                        ),
                      ]
                    : [
                        // White glow for regular (dark text)
                        const Shadow(
                          blurRadius: 6,
                          color: Colors.white,
                          offset: Offset.zero,
                        ),
                        const Shadow(
                          blurRadius: 10,
                          color: Colors.white,
                          offset: Offset.zero,
                        ),
                        Shadow(
                          blurRadius: 14,
                          color: const Color(0xFFFFDCC8).withOpacity(1),
                          offset: Offset.zero,
                        ),
                        Shadow(
                          blurRadius: 20,
                          color: const Color(0xFFFFC8B4).withOpacity(0.9),
                          offset: Offset.zero,
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
