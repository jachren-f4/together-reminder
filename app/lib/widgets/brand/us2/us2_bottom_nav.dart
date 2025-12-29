import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/services/haptic_service.dart';

/// Us 2.0 styled bottom navigation bar
///
/// Based on mockup:
/// - Each item has a unique color
/// - Active item uses gradient
/// - Poke has special gold/yellow styling
/// - White background with shadow
class Us2BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const Us2BottomNav({
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                color: Us2Theme.gradientAccentStart,
                gradientColors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.book_rounded,
                label: 'Journal',
                color: const Color(0xFFFF9F43), // Orange
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.waving_hand_rounded,
                label: 'Poke',
                color: const Color(0xFFFFD700), // Gold
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
                isSpecial: true,
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                color: const Color(0xFF4CAF50), // Green
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                color: const Color(0xFF9C27B0), // Purple
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<Color>? gradientColors;
  final bool isActive;
  final VoidCallback onTap;
  final bool isSpecial;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    this.gradientColors,
    required this.isActive,
    required this.onTap,
    this.isSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    final useGradient = isActive && gradientColors != null;

    return GestureDetector(
      onTap: () {
        SoundService().tap();
        HapticService().tap();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with color or gradient
            useGradient
                ? ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: gradientColors!,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Icon(
                      icon,
                      size: 26,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    icon,
                    size: 26,
                    color: isActive || isSpecial ? color : color.withOpacity(0.7),
                  ),
            const SizedBox(height: 4),
            // Label
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive || isSpecial
                    ? color
                    : const Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
