import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/models/cooldown_status.dart';
import 'package:togetherremind/widgets/cooldown_card.dart';

/// Base intro screen layout for Us 2.0 brand
///
/// Used by quiz, affirmation, you-or-me, linked, and word search intro screens.
/// Supports two layout variants:
/// - Simple: emoji + title + description (original)
/// - Card: hero + badges + quiz info card + stats (variant 2)
class Us2IntroScreen extends StatelessWidget {
  // Required
  final String buttonLabel;
  final VoidCallback onStart;

  // Optional navigation
  final VoidCallback? onBack;

  // Simple layout (centered content)
  final String? title;
  final String? description;
  final String? emoji;
  final String? imagePath; // Optional image instead of emoji for simple layout

  // Card layout (variant 2) - scrollable with cards
  final String? heroEmoji;
  final String? heroImagePath;
  final List<String>? badges;
  final String? quizTitle;
  final String? quizDescription;
  final List<(String label, String value, bool highlight)>? stats;
  final String? instructionText;

  // Additional content (badges, partner status, etc.)
  final List<Widget>? additionalContent;

  // Cooldown support
  final CooldownStatus? cooldownStatus;
  final String? activityName; // For cooldown card display

  const Us2IntroScreen({
    super.key,
    required this.buttonLabel,
    required this.onStart,
    this.onBack,
    // Simple layout
    this.title,
    this.description,
    this.emoji,
    this.imagePath,
    // Card layout
    this.heroEmoji,
    this.heroImagePath,
    this.badges,
    this.quizTitle,
    this.quizDescription,
    this.stats,
    this.instructionText,
    // Extras
    this.additionalContent,
    // Cooldown
    this.cooldownStatus,
    this.activityName,
  });

  /// Factory for simple centered layout (original style)
  factory Us2IntroScreen.simple({
    required String title,
    required String description,
    String? emoji,
    String? imagePath,
    required String buttonLabel,
    required VoidCallback onStart,
    VoidCallback? onBack,
    List<Widget>? additionalContent,
    CooldownStatus? cooldownStatus,
    String? activityName,
  }) {
    return Us2IntroScreen(
      title: title,
      description: description,
      emoji: emoji,
      imagePath: imagePath,
      buttonLabel: buttonLabel,
      onStart: onStart,
      onBack: onBack,
      additionalContent: additionalContent,
      cooldownStatus: cooldownStatus,
      activityName: activityName,
    );
  }

  /// Factory for card layout with quiz info (variant 2 style)
  factory Us2IntroScreen.withQuizCard({
    required String buttonLabel,
    required VoidCallback onStart,
    VoidCallback? onBack,
    String? heroEmoji,
    String? heroImagePath,
    List<String> badges = const [],
    String? quizTitle,
    String? quizDescription,
    List<(String, String, bool)>? stats,
    String? instructionText,
    List<Widget>? additionalContent,
    CooldownStatus? cooldownStatus,
    String? activityName,
  }) {
    return Us2IntroScreen(
      buttonLabel: buttonLabel,
      onStart: onStart,
      onBack: onBack,
      heroEmoji: heroEmoji,
      heroImagePath: heroImagePath,
      badges: badges,
      quizTitle: quizTitle,
      quizDescription: quizDescription,
      stats: stats,
      instructionText: instructionText,
      additionalContent: additionalContent,
      cooldownStatus: cooldownStatus,
      activityName: activityName,
    );
  }

  bool get _useCardLayout => heroEmoji != null || heroImagePath != null || quizTitle != null;
  bool get _isOnCooldown => cooldownStatus?.isOnCooldown ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: Us2Theme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              if (onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _Us2BackButton(onTap: onBack!),
                  ),
                ),
              // Main content - show cooldown card if on cooldown
              Expanded(
                child: _isOnCooldown
                    ? _buildCooldownLayout()
                    : (_useCardLayout ? _buildCardLayout() : _buildSimpleLayout()),
              ),
              // Bottom button - hide when on cooldown
              if (!_isOnCooldown)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Us2StartButton(
                    label: buttonLabel,
                    onPressed: onStart,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Layout shown when activity is on cooldown
  Widget _buildCooldownLayout() {
    return Center(
      child: CooldownCard(
        status: cooldownStatus!,
        activityName: activityName ?? 'quiz',
      ),
    );
  }

  /// Simple centered layout (original)
  Widget _buildSimpleLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image or emoji icon
          if (imagePath != null || emoji != null)
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                gradient: imagePath == null ? Us2Theme.cardGradient : null,
                shape: BoxShape.circle,
                boxShadow: Us2Theme.cardGlowShadow,
              ),
              child: ClipOval(
                child: imagePath != null
                    ? Image.asset(
                        imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(emoji ?? '🎯', style: const TextStyle(fontSize: 60)),
                          );
                        },
                      )
                    : Center(
                        child: Text(emoji!, style: const TextStyle(fontSize: 60)),
                      ),
              ),
            ),
          if (imagePath != null || emoji != null) const SizedBox(height: 32),
          // Title
          if (title != null)
            Text(
              title!,
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Us2Theme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          if (title != null) const SizedBox(height: 16),
          // Description
          if (description != null)
            Text(
              description!,
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: Us2Theme.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          // Additional content
          if (additionalContent != null) ...[
            const SizedBox(height: 24),
            ...additionalContent!,
          ],
        ],
      ),
    );
  }

  /// Card layout with hero, badges, quiz info card, stats (variant 2)
  Widget _buildCardLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image
          if (heroImagePath != null || heroEmoji != null)
            _Us2HeroImage(emoji: heroEmoji, imagePath: heroImagePath),
          if (heroImagePath != null || heroEmoji != null) const SizedBox(height: 20),

          // Badges
          if (badges != null && badges!.isNotEmpty) ...[
            Row(
              children: [
                for (int i = 0; i < badges!.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _Us2Badge(label: badges![i], isPrimary: i == 0),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Quiz Info Card
          if (quizTitle != null || quizDescription != null)
            _Us2QuizInfoCard(
              title: quizTitle,
              description: quizDescription,
            ),
          if (quizTitle != null || quizDescription != null)
            const SizedBox(height: 16),

          // Instruction text
          if (instructionText != null) ...[
            Text(
              instructionText!,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Us2Theme.textMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Stats Card
          if (stats != null && stats!.isNotEmpty) ...[
            _Us2StatsCard(stats: stats!),
            const SizedBox(height: 24),
          ],

          // Additional content
          if (additionalContent != null) ...additionalContent!,
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED US2 COMPONENTS
// =============================================================================

/// Back button with white circle
class _Us2BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _Us2BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: Us2Theme.textDark),
      ),
    );
  }
}

/// Hero image section with emoji or image
class _Us2HeroImage extends StatelessWidget {
  final String? emoji;
  final String? imagePath;

  const _Us2HeroImage({this.emoji, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: imagePath == null
            ? LinearGradient(
                colors: [
                  Us2Theme.primaryBrandPink.withValues(alpha: 0.3),
                  Us2Theme.gradientAccentEnd.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.primaryBrandPink.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imagePath != null
            ? Image.asset(
                imagePath!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to emoji if image fails
                  return Center(
                    child: Text(emoji ?? '🎯', style: const TextStyle(fontSize: 80)),
                  );
                },
              )
            : Center(
                child: Text(emoji ?? '🎯', style: const TextStyle(fontSize: 80)),
              ),
      ),
    );
  }
}

/// Badge (primary = dark, secondary = gradient)
class _Us2Badge extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _Us2Badge({required this.label, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: isPrimary
            ? null
            : const LinearGradient(
                colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
              ),
        color: isPrimary ? Us2Theme.textDark : null,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Quiz info card with title and description
class _Us2QuizInfoCard extends StatelessWidget {
  final String? title;
  final String? description;

  const _Us2QuizInfoCard({this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Us2Theme.primaryBrandPink, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S THEME",
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Us2Theme.primaryBrandPink,
            ),
          ),
          const SizedBox(height: 4),
          if (title != null)
            Text(
              title!,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textDark,
              ),
            ),
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Us2Theme.textMedium,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stats card with rows
class _Us2StatsCard extends StatelessWidget {
  final List<(String label, String value, bool highlight)> stats;

  const _Us2StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                color: const Color(0xFFF0F0F0),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stats[i].$1,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Us2Theme.textMedium,
                    ),
                  ),
                  Text(
                    stats[i].$2,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: stats[i].$3 ? Us2Theme.primaryBrandPink : Us2Theme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Styled start button for intro screens
class Us2StartButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const Us2StartButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  State<Us2StartButton> createState() => _Us2StartButtonState();
}

class _Us2StartButtonState extends State<Us2StartButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _isPressed ? 0 : -2, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: Us2Theme.accentGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: _isPressed
              ? Us2Theme.buttonGlowShadow
              : Us2Theme.buttonHoverGlowShadow,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reward badge for intro screens
class Us2RewardBadge extends StatelessWidget {
  final String text;
  final IconData? icon;

  const Us2RewardBadge({
    super.key,
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Us2Theme.primaryBrandPink.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Us2Theme.primaryBrandPink),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Us2Theme.primaryBrandPink,
            ),
          ),
        ],
      ),
    );
  }
}
