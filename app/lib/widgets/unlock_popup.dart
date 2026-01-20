import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';

/// Feature type for unlock popup content
enum UnlockFeatureType {
  classicQuiz,
  affirmationQuiz,
  youOrMe,
  crossword,
  wordSearch,
  stepsTogether,
}

/// Data model for unlock popup content
class UnlockFeatureData {
  final String imagePath;
  final String categoryBadge;
  final String title;
  final String description;
  final String lpValue;
  final String lpLabel;
  final String modeValue;
  final String modeLabel;

  const UnlockFeatureData({
    required this.imagePath,
    required this.categoryBadge,
    required this.title,
    required this.description,
    required this.lpValue,
    required this.lpLabel,
    required this.modeValue,
    required this.modeLabel,
  });

  /// Get feature data by type (from UNLOCK_POPUP_SPEC.md)
  static UnlockFeatureData fromType(UnlockFeatureType type) {
    switch (type) {
      case UnlockFeatureType.classicQuiz:
        return const UnlockFeatureData(
          imagePath: 'assets/brands/us2/images/quests/classic-quiz-default.png',
          categoryBadge: 'QUIZ',
          title: 'Classic Quiz',
          description: 'Test how well you know each other with fun multiple-choice questions!',
          lpValue: '+30',
          lpLabel: 'LP Per Game',
          modeValue: 'Quiz',
          modeLabel: 'Mode',
        );
      case UnlockFeatureType.affirmationQuiz:
        return const UnlockFeatureData(
          imagePath: 'assets/brands/us2/images/quests/affirmation-default.png',
          categoryBadge: 'QUIZ',
          title: 'Affirmation Quiz',
          description: 'Share loving affirmations and discover what makes your partner feel appreciated!',
          lpValue: '+30',
          lpLabel: 'LP Per Game',
          modeValue: 'Quiz',
          modeLabel: 'Mode',
        );
      case UnlockFeatureType.youOrMe:
        return const UnlockFeatureData(
          imagePath: 'assets/brands/us2/images/quests/you-or-me.png',
          categoryBadge: 'QUIZ',
          title: 'You or Me',
          description: "Who's more likely to...? Answer fun questions about each other and see if you agree!",
          lpValue: '+30',
          lpLabel: 'LP Per Game',
          modeValue: 'Quiz',
          modeLabel: 'Mode',
        );
      case UnlockFeatureType.crossword:
        return const UnlockFeatureData(
          imagePath: 'assets/brands/us2/images/quests/linked.png',
          categoryBadge: 'PUZZLE',
          title: 'Crossword',
          description: 'Solve romantic crossword puzzles together! Take turns filling in the answers.',
          lpValue: '+30',
          lpLabel: 'LP Per Game',
          modeValue: 'Puzzle',
          modeLabel: 'Mode',
        );
      case UnlockFeatureType.wordSearch:
        return const UnlockFeatureData(
          imagePath: 'assets/brands/us2/images/quests/word-search.png',
          categoryBadge: 'PUZZLE',
          title: 'Word Search',
          description: 'Find hidden words together in a fun puzzle! Take turns discovering words as a team.',
          lpValue: '+30',
          lpLabel: 'LP Per Game',
          modeValue: 'Puzzle',
          modeLabel: 'Mode',
        );
      case UnlockFeatureType.stepsTogether:
        return const UnlockFeatureData(
          imagePath: 'assets/brands/us2/images/quests/steps-together.png',
          categoryBadge: 'FITNESS',
          title: 'Steps Together',
          description: 'Track your daily steps and reach goals together! Stay active and earn LP as a couple.',
          lpValue: '+30',
          lpLabel: 'LP Per Day',
          modeValue: 'Sync',
          modeLabel: 'Mode',
        );
    }
  }
}

/// Unlock popup widget following UNLOCK_POPUP_SPEC.md exactly
///
/// Shows when a user unlocks a new feature/game with:
/// - Feature image with rounded corners and pulsing glow ring
/// - "UNLOCKED" badge + category badge
/// - Feature title and description
/// - Two stats (LP reward + Mode)
/// - "Great!" button
class UnlockPopup extends StatefulWidget {
  final UnlockFeatureType featureType;
  final VoidCallback onDismiss;

  const UnlockPopup({
    super.key,
    required this.featureType,
    required this.onDismiss,
  });

  /// Show the unlock popup as a dialog
  static Future<void> show(
    BuildContext context, {
    required UnlockFeatureType featureType,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'Unlock Popup',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return UnlockPopup(
          featureType: featureType,
          onDismiss: () => Navigator.of(context).pop(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<UnlockPopup> createState() => _UnlockPopupState();
}

class _UnlockPopupState extends State<UnlockPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Colors from spec (UNLOCK_POPUP_SPEC.md)
  static const _overlayColor = Color(0x99000000); // rgba(0,0,0,0.6)
  static const _imageSectionGradientStart = Color(0xFFFFE8E4);
  static const _imageSectionGradientMid = Color(0xFFFFDDD6);
  static const _imageSectionGradientEnd = Color(0xFFFFD0C5);
  static const _unlockedBadgeStart = Color(0xFFFF6B6B);
  static const _unlockedBadgeEnd = Color(0xFFFF9F43);
  static const _categoryBadgeBg = Color(0xFFF5F5F5);
  static const _categoryBadgeText = Color(0xFF888888);
  static const _titleColor = Color(0xFF2D2D2D);
  static const _descriptionColor = Color(0xFF777777);
  static const _statValueColor = Color(0xFFFF6B6B);
  static const _statLabelColor = Color(0xFF999999);
  static const _glowColor = Color(0x4DFF9F43); // rgba(255,159,67,0.3)

  @override
  void initState() {
    super.initState();

    // Glow ring pulse animation (from spec: 2s duration, ease-in-out, infinite)
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Scale: 1 → 1.1 → 1 (from spec)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    // Opacity: 0.8 → 0.4 → 0.8 (from spec)
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 0.4)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 0.8)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    _pulseController.repeat();

    // Trigger haptic and sound
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        HapticService().trigger(HapticType.success);
        SoundService().play(SoundId.confettiBurst);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = UnlockFeatureData.fromType(widget.featureType);

    return Material(
      color: Colors.transparent,
      child: Container(
        // Overlay: rgba(0,0,0,0.6) from spec
        color: _overlayColor,
        child: Center(
          child: Container(
            // Popup width: 340px, border-radius: 28px from spec
            width: 340,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              // Popup shadow: 0 25px 80px rgba(0,0,0,0.3) from spec
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000), // 30% black
                  blurRadius: 80,
                  offset: Offset(0, 25),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImageSection(data),
                _buildContentSection(data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(UnlockFeatureData data) {
    return Container(
      // Image section height: 240px from spec
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        // Image section gradient from spec
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _imageSectionGradientStart,
            _imageSectionGradientMid,
            _imageSectionGradientEnd,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Gradient fade to white (80px height at bottom) from spec
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 80,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white],
                ),
              ),
            ),
          ),
          // Centered glow ring and image
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated glow ring (200x200px from spec)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Glow: radial gradient rgba(255,159,67,0.3) to transparent from spec
                            gradient: RadialGradient(
                              colors: [
                                _glowColor,
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.7],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Feature image (180x180px, border-radius: 24px from spec)
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    // Image drop shadow: 0 15px 40px rgba(255,107,107,0.35) from spec
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x59FF6B6B), // 35% #FF6B6B
                        blurRadius: 40,
                        offset: Offset(0, 15),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    data.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if image not found
                      return Container(
                        color: _imageSectionGradientMid,
                        child: const Icon(
                          Icons.celebration,
                          size: 80,
                          color: _unlockedBadgeStart,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(UnlockFeatureData data) {
    return Transform.translate(
      // Content margin-top: -20px (overlaps image section) from spec
      offset: const Offset(0, -20),
      child: Container(
        // Content padding: 20px top, 24px horizontal, 28px bottom from spec
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge row (gap: 8px, margin-bottom: 16px from spec)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildUnlockedBadge(),
                const SizedBox(width: 8),
                _buildCategoryBadge(data.categoryBadge),
              ],
            ),
            const SizedBox(height: 16),

            // Title (Playfair Display, 32px, weight 700, color #2D2D2D from spec)
            Text(
              data.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
              textAlign: TextAlign.center,
            ),
            // Title margin-bottom: 12px from spec
            const SizedBox(height: 12),

            // Description (Nunito, 15px, weight 400, line-height 1.6, color #777777 from spec)
            Text(
              data.description,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: _descriptionColor,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            // Description margin-bottom: 24px from spec
            const SizedBox(height: 24),

            // Stats row (gap: 24px, margin-bottom: 24px from spec)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStat(data.lpValue, data.lpLabel),
                const SizedBox(width: 24),
                _buildStat(data.modeValue, data.modeLabel),
              ],
            ),
            const SizedBox(height: 24),

            // Button
            _buildButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedBadge() {
    return Container(
      // Badge padding: 6px 12px, border-radius: 20px from spec
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // UNLOCKED badge: gradient #FF6B6B → #FF9F43 from spec
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_unlockedBadgeStart, _unlockedBadgeEnd],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'UNLOCKED',
        // Badge text: Nunito, 10px, weight 700, letter-spacing 1px, white from spec
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      // Badge padding: 6px 12px, border-radius: 20px from spec
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // Category badge: #F5F5F5 background from spec
        color: _categoryBadgeBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        // Badge text: Nunito, 10px, weight 700, letter-spacing 1px, #888888 from spec
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: _categoryBadgeText,
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        // Stat value: Playfair Display, 20px, weight 700, #FF6B6B from spec
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _statValueColor,
          ),
        ),
        const SizedBox(height: 2),
        // Stat label: Nunito, 11px, uppercase, letter-spacing 0.5px, #999999 from spec
        Text(
          label.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
            color: _statLabelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildButton() {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        width: double.infinity,
        // Button padding: 18px vertical, border-radius: 16px from spec
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          // Button: gradient #FF6B6B → #FF9F43 (135deg) from spec
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_unlockedBadgeStart, _unlockedBadgeEnd],
          ),
          borderRadius: BorderRadius.circular(16),
          // Button shadow: 0 10px 30px rgba(255,107,107,0.4) from spec
          boxShadow: const [
            BoxShadow(
              color: Color(0x66FF6B6B), // 40% #FF6B6B
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          'Great!',
          // Button text: Nunito, 17px, weight 700, white from spec
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
