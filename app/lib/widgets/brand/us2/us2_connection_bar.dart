import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/models/magnet_collection.dart';

/// Connection bar showing magnet collection progress
///
/// Features:
/// - Gradient background (pink to orange)
/// - Progress bar with heart indicator
/// - Animated sparkles around heart
/// - Current magnet and next magnet at endpoints
class Us2ConnectionBar extends StatelessWidget {
  final MagnetCollection? collection;
  final VoidCallback? onTap;

  const Us2ConnectionBar({
    super.key,
    this.collection,
    this.onTap,
  });

  // Width reserved for magnet endpoint icons
  static const double _magnetEndpointWidth = 36.0;

  /// Format number with comma separators (e.g., 2460 -> "2,460")
  static String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    final String str = number.toString();
    final int len = str.length;
    if (len <= 3) return str;
    return '${str.substring(0, len - 3)},${str.substring(len - 3)}';
  }

  /// Get cumulative LP required to unlock a specific magnet
  /// Magnet 1: 600, Magnet 2: 1200, Magnet 3: 1800, Magnet 4: 2500, etc.
  /// Public so MagnetCollectionScreen can use it too.
  static int getCumulativeLpForMagnet(int magnetNumber) {
    int cumulative = 0;
    for (int i = 1; i <= magnetNumber; i++) {
      final tier = (i - 1) ~/ 3;
      cumulative += 600 + (tier * 100);
    }
    return cumulative;
  }

  /// Get emoji for magnet based on destination (fallback when no image)
  static String getMagnetEmoji(int magnetId) {
    const emojis = [
      // US Cities (1-7)
      '🎸', // 1: Austin
      '🎬', // 2: Los Angeles
      '🌉', // 3: San Francisco
      '🏙️', // 4: Chicago
      '🌴', // 5: Miami
      '🎷', // 6: New Orleans
      '🗽', // 7: New York
      // Northern Europe (8-14)
      '🎡', // 8: London
      '🗼', // 9: Paris
      '🚲', // 10: Amsterdam
      '🐻', // 11: Berlin
      '🧜', // 12: Copenhagen
      '👑', // 13: Stockholm
      '⛷️', // 14: Oslo
      // Southern Europe (15-21)
      '🏛️', // 15: Barcelona
      '🍕', // 16: Naples
      '🏟️', // 17: Rome
      '🎼', // 18: Vienna
      '🏰', // 19: Prague
      '🚃', // 20: Lisbon
      '🏛️', // 21: Athens
      // Nordic & Mediterranean Dreams (22-25)
      '🦌', // 22: Helsinki
      '🌋', // 23: Reykjavik
      '🔵', // 24: Santorini
      '🏰', // 25: Dubrovnik
      // Exotic World (26-30)
      '🗼', // 26: Tokyo
      '🕌', // 27: Marrakech
      '🦁', // 28: Cape Town
      '💃', // 29: Buenos Aires
      '🚗', // 30: Havana
    ];
    if (magnetId < 1 || magnetId > emojis.length) return '🧲';
    return emojis[magnetId - 1];
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress
    final unlockedCount = collection?.unlockedCount ?? 0;
    final nextMagnetId = collection?.nextMagnetId ?? 1;
    final allUnlocked = collection?.allUnlocked ?? false;
    final currentLp = collection?.currentLp ?? 0;

    // Current magnet (last unlocked, or 0 if none)
    final currentMagnetId = unlockedCount > 0 ? unlockedCount : 0;

    // Next magnet ID (or first if new user)
    final effectiveNextMagnetId = nextMagnetId;

    // Calculate tier-based progress (fills up, resets after each unlock)
    final prevThreshold = unlockedCount > 0 ? getCumulativeLpForMagnet(unlockedCount) : 0;
    final nextThreshold = getCumulativeLpForMagnet(effectiveNextMagnetId);
    final lpInCurrentTier = currentLp - prevThreshold;
    final lpNeededForTier = nextThreshold - prevThreshold;
    final progress = allUnlocked
        ? 1.0
        : lpNeededForTier > 0
            ? (lpInCurrentTier / lpNeededForTier).clamp(0.0, 1.0)
            : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          gradient: Us2Theme.connectionBarGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Us2Theme.connectionBarBorderRadius),
            topRight: Radius.circular(Us2Theme.connectionBarBorderRadius),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OUR JOURNEY',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
                // Total LP (e.g., "2,500 LP")
                Text(
                  allUnlocked
                      ? 'Complete!'
                      : '${_formatNumber(collection?.currentLp ?? 0)} LP',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar with magnet endpoints (no labels per mockup)
            SizedBox(
              height: 50, // Height for magnet + track (no labels)
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final hasLeftMagnet = currentMagnetId > 0;

                  // Per mockup: new users have no left magnet, track starts from left edge
                  // Extra 8px padding moves endpoints inward so heart is visible near ends
                  final trackLeft = hasLeftMagnet ? _magnetEndpointWidth + 16 : 16.0;
                  final trackRight = _magnetEndpointWidth + 16;
                  final trackWidth = totalWidth - trackLeft - trackRight;
                  final heartPosition = trackLeft + (trackWidth * progress);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Left endpoint (current/last magnet) - only if user has unlocked magnets
                      if (hasLeftMagnet)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: _MagnetEndpoint(magnetId: currentMagnetId),
                        ),
                      // Right endpoint (next magnet)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: _MagnetEndpoint(magnetId: effectiveNextMagnetId),
                      ),
                      // Track background - dark semi-transparent
                      Positioned(
                        left: trackLeft,
                        right: trackRight,
                        top: 13, // Center with 36px magnet
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      // Progress fill - gold gradient
                      Positioned(
                        left: trackLeft,
                        top: 13,
                        child: Container(
                          height: 10,
                          width: trackWidth * progress,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFE066), // Gold start
                                Color(0xFFFFB347), // Gold end
                              ],
                            ),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFE066).withValues(alpha: 0.6),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Heart indicator - positioned at progress point
                      Positioned(
                        left: heartPosition - 22,
                        top: -4, // Slightly above track
                        child: _Us2ProgressHeart(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Magnet endpoint - square rounded image (no label per mockup spec)
class _MagnetEndpoint extends StatelessWidget {
  final int magnetId;

  const _MagnetEndpoint({
    required this.magnetId,
  });

  @override
  Widget build(BuildContext context) {
    // Per mockup: 36x36 square with 6px radius, white/semi-transparent border
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _buildMagnetImage(magnetId),
      ),
    );
  }

  Widget _buildMagnetImage(int magnetId) {
    final assetPath = MagnetCollection.getMagnetAssetPath(magnetId);

    // Try to load image, fall back to emoji if not available
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to emoji when image not available
        return Container(
          color: const Color(0xFFFF6B6B),
          child: Center(
            child: Text(
              Us2ConnectionBar.getMagnetEmoji(magnetId),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        );
      },
    );
  }
}

/// Animated heart with sparkles
class _Us2ProgressHeart extends StatefulWidget {
  @override
  State<_Us2ProgressHeart> createState() => _Us2ProgressHeartState();
}

class _Us2ProgressHeartState extends State<_Us2ProgressHeart>
    with TickerProviderStateMixin {
  late List<AnimationController> _sparkleControllers;
  late List<Animation<double>> _sparkleAnimations;

  @override
  void initState() {
    super.initState();

    // Create 3 staggered sparkle animations
    _sparkleControllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: Us2Theme.sparkleAnimationDuration),
        vsync: this,
      )..repeat();
    });

    _sparkleAnimations = _sparkleControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;
      // Stagger the animations
      Future.delayed(Duration(milliseconds: index * 500), () {
        if (mounted) controller.forward();
      });
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _sparkleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Us2Theme.progressHeartSize,
      height: Us2Theme.progressHeartSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Heart circle
          Container(
            width: Us2Theme.progressHeartSize,
            height: Us2Theme.progressHeartSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Us2Theme.gradientAccentStart,
                  Us2Theme.gradientAccentEnd,
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Us2Theme.glowPink.withValues(alpha: 0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('💗', style: TextStyle(fontSize: 20)),
            ),
          ),
          // Sparkles
          _buildSparkle(0, -8, -8),
          _buildSparkle(1, 30, -5),
          _buildSparkle(2, 35, 25),
        ],
      ),
    );
  }

  Widget _buildSparkle(int index, double left, double top) {
    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _sparkleAnimations[index],
        builder: (context, child) {
          return Opacity(
            opacity: _sparkleAnimations[index].value,
            child: Transform.scale(
              scale: 0.8 + (_sparkleAnimations[index].value * 0.4),
              child: const Text('✨', style: TextStyle(fontSize: 14)),
            ),
          );
        },
      ),
    );
  }
}
