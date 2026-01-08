import 'package:flutter/material.dart';
import 'package:togetherremind/config/brand/brand_config.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:togetherremind/models/daily_quest.dart';
import 'package:togetherremind/models/magnet_collection.dart';
import 'package:togetherremind/services/nav_style_service.dart';
import 'us2/us2_widgets.dart';
import 'us2/us2_home_content.dart' show GuidanceCallback;

/// Factory that returns brand-appropriate widgets
///
/// Usage:
/// ```dart
/// // In a screen build method
/// return BrandWidgetFactory.homeContent(
///   user: user,
///   partner: partner,
///   lp: totalLp,
///   quests: quests,
/// );
/// ```
///
/// This factory checks the current brand and returns the appropriate
/// widget implementation. Most brands share the Liia (TogetherRemind)
/// implementation, while Us 2.0 has its own components.
class BrandWidgetFactory {
  /// Get the current brand
  static Brand get _brand => BrandLoader().config.brand;

  /// Whether current brand is Us 2.0
  static bool get isUs2 => _brand == Brand.us2;

  /// Whether current brand uses gradient styling
  static bool get usesGradientStyling => BrandLoader().colors.hasGradientStyling;

  /// Get Us 2.0 home content if this is the Us2 brand
  ///
  /// Returns null for other brands (use default Liia content).
  static Widget? us2HomeContent({
    required String userName,
    required String partnerName,
    required int dayNumber,
    MagnetCollection? magnetCollection,
    VoidCallback? onCollectionTap,
    required List<DailyQuest> dailyQuests,
    required List<DailyQuest> sideQuests,
    required Function(DailyQuest) onQuestTap,
    VoidCallback? onDebugTap,
    GuidanceCallback? getDailyQuestGuidance,
    GuidanceCallback? getSideQuestGuidance,
  }) {
    if (!isUs2) return null;

    return Us2HomeContent(
      userName: userName,
      partnerName: partnerName,
      dayNumber: dayNumber,
      magnetCollection: magnetCollection,
      onCollectionTap: onCollectionTap,
      dailyQuests: dailyQuests,
      sideQuests: sideQuests,
      onQuestTap: onQuestTap,
      onDebugTap: onDebugTap,
      getDailyQuestGuidance: getDailyQuestGuidance,
      getSideQuestGuidance: getSideQuestGuidance,
    );
  }

  /// Get Us 2.0 bottom navigation if this is the Us2 brand
  ///
  /// Returns null for other brands (use default navigation).
  /// Uses the style selected via NavStyleService.
  static Widget? us2BottomNav({
    required int currentIndex,
    required Function(int) onTap,
  }) {
    if (!isUs2) return null;

    final style = NavStyleService.instance.currentStyle;

    switch (style) {
      case Us2NavStyle.dock:
        return Us2BottomNavDock(
          currentIndex: currentIndex,
          onTap: onTap,
        );
      case Us2NavStyle.pill:
        return Us2BottomNavPill(
          currentIndex: currentIndex,
          onTap: onTap,
        );
      case Us2NavStyle.standard:
      default:
        return Us2BottomNav(
          currentIndex: currentIndex,
          onTap: onTap,
        );
    }
  }

  /// Get home screen content widget wrapper
  ///
  /// Wraps content with gradient background for Us 2.0.
  static Widget homeContentWrapper({
    required Widget child,
  }) {
    if (isUs2) {
      return Container(
        decoration: BoxDecoration(
          gradient: BrandLoader().colors.backgroundGradient,
        ),
        child: child,
      );
    }
    return child;
  }

  /// Get a styled card widget appropriate for the brand
  static Widget card({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 16.0,
  }) {
    final colors = BrandLoader().colors;

    if (isUs2) {
      return Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.effectiveCardBackground,
              colors.effectiveCardBackgroundDark,
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: colors.glowPrimary != null
              ? [
                  BoxShadow(
                    color: colors.glowPrimary!.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: child,
      );
    }

    // Default Liia card style
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: child,
    );
  }

  /// Get a gradient button appropriate for the brand
  static Widget gradientButton({
    required String label,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    final colors = BrandLoader().colors;

    if (isUs2) {
      return _Us2GlowButton(
        label: label,
        onPressed: onPressed,
        isEnabled: isEnabled,
      );
    }

    // Default Liia button style
    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.textOnPrimary,
        disabledBackgroundColor: colors.disabled,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Text(label),
    );
  }

  /// Get a section header appropriate for the brand
  static Widget sectionHeader({
    required String title,
  }) {
    final colors = BrandLoader().colors;

    if (isUs2) {
      return _Us2SectionHeader(title: title);
    }

    // Default Liia section header
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

/// Us 2.0 glow button with gradient and glow effect
class _Us2GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isEnabled;

  const _Us2GlowButton({
    required this.label,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  State<_Us2GlowButton> createState() => _Us2GlowButtonState();
}

class _Us2GlowButtonState extends State<_Us2GlowButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = BrandLoader().colors;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (widget.isEnabled) widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _isPressed ? 0 : -2, 0),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isEnabled
                ? [Colors.white, colors.surface]
                : [colors.disabled, colors.disabled],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: widget.isEnabled ? colors.primary : colors.disabled,
            width: 2,
          ),
          boxShadow: widget.isEnabled && colors.glowPrimary != null
              ? [
                  BoxShadow(
                    color: colors.glowPrimary!.withOpacity(_isPressed ? 0.4 : 0.6),
                    blurRadius: _isPressed ? 10 : 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: widget.isEnabled ? colors.primary : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Us 2.0 ribbon-style section header
class _Us2SectionHeader extends StatelessWidget {
  final String title;

  const _Us2SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = BrandLoader().colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Left tail
          Container(
            width: 20,
            height: 30,
            decoration: BoxDecoration(
              color: colors.effectiveRibbonBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
            ),
          ),
          // Main ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: colors.effectiveRibbonBackground,
            ),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                letterSpacing: 2,
                color: colors.textPrimary,
              ),
            ),
          ),
          // Right tail
          Container(
            width: 20,
            height: 30,
            decoration: BoxDecoration(
              color: colors.effectiveRibbonBackground,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
