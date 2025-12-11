import 'package:flutter/material.dart';
import 'package:togetherremind/screens/new_home_screen.dart';
import 'package:togetherremind/screens/activity_hub_screen.dart';
import 'package:togetherremind/screens/profile_screen.dart';
import 'package:togetherremind/screens/settings_screen.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/config/brand/brand_assets.dart';
import 'package:togetherremind/widgets/poke_bottom_sheet.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/services/haptic_service.dart';

class HomeScreen extends StatefulWidget {
  final bool showLpIntro;

  const HomeScreen({
    super.key,
    this.showLpIntro = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    NewHomeScreen(showLpIntro: widget.showLpIntro),
    const ActivityHubScreen(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  void _showPokeBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PokeBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          border: Border(
            top: BorderSide(color: AppTheme.borderLight, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  iconOutline: BrandAssets.homeIcon,
                  iconFilled: BrandAssets.homeIconFilled,
                  label: 'Home',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  iconOutline: BrandAssets.inboxIcon,
                  iconFilled: BrandAssets.inboxIconFilled,
                  label: 'Inbox',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _PokeNavItem(
                  onTap: _showPokeBottomSheet,
                ),
                _NavItem(
                  iconOutline: BrandAssets.profileIcon,
                  iconFilled: BrandAssets.profileIconFilled,
                  label: 'Profile',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  iconOutline: BrandAssets.settingsIcon,
                  iconFilled: BrandAssets.settingsIconFilled,
                  label: 'Settings',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String iconOutline;
  final String iconFilled;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.iconOutline,
    required this.iconFilled,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          SoundService().tap();
          HapticService().tap();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Image.asset(
                isActive ? iconFilled : iconOutline,
                key: ValueKey(isActive),
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTheme.bodyFont.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _PokeNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const _PokeNavItem({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          SoundService().tap();
          HapticService().tap();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '💫',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              'Poke',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
