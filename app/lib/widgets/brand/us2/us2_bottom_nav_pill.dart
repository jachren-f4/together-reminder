import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/services/haptic_service.dart';

/// Us 2.0 pill-expand bottom navigation bar
///
/// Features:
/// - Active item expands into pill with label
/// - Custom emoji graphics
/// - Smooth animations
/// - Items spread evenly across full width
class Us2BottomNavPill extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const Us2BottomNavPill({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PillNavItem(
                imagePath: 'assets/brands/us2/nav/home_v1.png',
                label: 'Home',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _PillNavItem(
                imagePath: 'assets/brands/us2/nav/journal.png',
                label: 'Journal',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _PillNavItem(
                imagePath: 'assets/brands/us2/nav/Poke_v2.png',
                label: 'Poke',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
                isPoke: true,
              ),
              _PillNavItem(
                imagePath: 'assets/brands/us2/nav/profile_v2_transparent.png',
                label: 'Us',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _PillNavItem(
                imagePath: 'assets/brands/us2/nav/Settings_v1.png',
                label: 'Settings',
                isActive: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final String imagePath;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isPoke;

  const _PillNavItem({
    required this.imagePath,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isPoke = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundService().tap();
        HapticService().tap();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          // More visible pill background for active state
          color: isActive
              ? Us2Theme.gradientAccentStart.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            _buildIcon(),
            // Animated label for active item
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: isActive
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        label,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Us2Theme.gradientAccentStart,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final iconSize = 26.0;

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Image.asset(
        imagePath,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        // All icons show at full color
        errorBuilder: (context, error, stackTrace) {
          // Fallback to icon if image fails to load
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
            size: iconSize,
            color: Us2Theme.gradientAccentStart,
          );
        },
      ),
    );
  }
}
