import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/services/haptic_service.dart';

/// Us 2.0 dock-style bottom navigation bar
///
/// macOS-inspired dock with:
/// - Glassmorphism floating bar
/// - Magnification effect on active item
/// - Custom emoji graphics
class Us2BottomNavDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const Us2BottomNavDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _DockNavItem(
                      imagePath: 'assets/brands/us2/nav/home_v1.png',
                      label: 'Home',
                      isActive: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    _DockNavItem(
                      imagePath: 'assets/brands/us2/nav/journal.png',
                      label: 'Journal',
                      isActive: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    _DockNavItem(
                      imagePath: 'assets/brands/us2/nav/Poke_v2.png',
                      label: 'Poke',
                      isActive: currentIndex == 2,
                      onTap: () => onTap(2),
                      isPoke: true,
                    ),
                    _DockNavItem(
                      imagePath: 'assets/brands/us2/nav/profile_v2_transparent.png',
                      label: 'Us',
                      isActive: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                    _DockNavItem(
                      imagePath: 'assets/brands/us2/nav/Settings_v1.png',
                      label: 'Settings',
                      isActive: currentIndex == 4,
                      onTap: () => onTap(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockNavItem extends StatelessWidget {
  final String imagePath;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isPoke;

  const _DockNavItem({
    required this.imagePath,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isPoke = false,
  });

  @override
  Widget build(BuildContext context) {
    // macOS dock magnification effect
    final size = isActive ? 48.0 : 36.0;
    final translateY = isActive ? -6.0 : 0.0;

    return GestureDetector(
      onTap: () {
        SoundService().tap();
        HapticService().tap();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 52,
        alignment: Alignment.center,
        transform: Matrix4.translationValues(0, translateY, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with magnification
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              decoration: isActive
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Us2Theme.glowPink.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : null,
              child: _buildIcon(size),
            ),
            // Active indicator dot
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isActive ? 4 : 0,
              height: isActive ? 4 : 0,
              decoration: BoxDecoration(
                color: Us2Theme.gradientAccentStart,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(double size) {
    return Image.asset(
      imagePath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // All icons show at full color
      errorBuilder: (context, error, stackTrace) {
        IconData fallbackIcon;
        switch (label) {
          case 'Home':
            fallbackIcon = Icons.home_rounded;
            break;
          case 'Journal':
            fallbackIcon = Icons.book_rounded;
            break;
          case 'Poke':
            fallbackIcon = Icons.waving_hand_rounded;
            break;
          case 'Us':
            fallbackIcon = Icons.people_rounded;
            break;
          case 'Settings':
            fallbackIcon = Icons.settings_rounded;
            break;
          default:
            fallbackIcon = Icons.circle;
        }
        return Icon(
          fallbackIcon,
          size: size * 0.7,
          color: Us2Theme.gradientAccentStart,
        );
      },
    );
  }
}
