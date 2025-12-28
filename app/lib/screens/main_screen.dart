import 'package:flutter/material.dart';
import 'package:togetherremind/screens/home_screen.dart';
import 'package:togetherremind/screens/activity_hub_screen.dart';
import 'package:togetherremind/screens/profile_screen.dart';
import 'package:togetherremind/screens/settings_screen.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/config/brand/brand_assets.dart';
import 'package:togetherremind/widgets/poke_bottom_sheet.dart';
import 'package:togetherremind/widgets/brand/brand_widget_factory.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/services/haptic_service.dart';
import 'package:togetherremind/animations/animation_config.dart';
import 'package:togetherremind/config/animation_constants.dart';

/// Main app shell with bottom navigation bar
///
/// Contains tabs for:
/// - HomeScreen (daily quests, side quests)
/// - ActivityHubScreen (inbox)
/// - ProfileScreen
/// - SettingsScreen
class MainScreen extends StatefulWidget {
  final bool showLpIntro;

  const MainScreen({
    super.key,
    this.showLpIntro = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Track whether LP intro has been shown this session
  // This prevents showing it again when switching tabs
  bool _lpIntroConsumed = false;

  // Track whether LP intro is currently visible (hides bottom nav)
  bool _lpIntroVisible = false;

  // Cache screens to prevent recreation on tab switch
  late final List<Widget> _screens;

  // Bottom nav entrance animation
  late AnimationController _bottomNavController;
  late Animation<double> _bottomNavOpacity;
  late Animation<Offset> _bottomNavSlide;
  bool _hasAnimatedBottomNav = false;

  @override
  void initState() {
    super.initState();

    // Setup bottom nav animation
    _bottomNavController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _bottomNavOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bottomNavController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _bottomNavSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _bottomNavController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Create screens once - LP intro only shows on first mount if requested
    _screens = [
      HomeScreen(
        showLpIntro: widget.showLpIntro && !_lpIntroConsumed,
        onLpIntroVisibilityChanged: (visible) {
          if (mounted) {
            setState(() => _lpIntroVisible = visible);
          }
        },
      ),
      const ActivityHubScreen(),
      const ProfileScreen(),
      const SettingsScreen(),
    ];
    // Mark LP intro as consumed after creating the screen
    // Also set initial visibility state
    if (widget.showLpIntro) {
      _lpIntroConsumed = true;
      _lpIntroVisible = true; // Hide bottom nav initially
    }

    // Start bottom nav animation after delay (synced with home screen stagger)
    // Delay matches index 2-3 timing in HomeStaggeredEntrance
    if (AnimationConfig.enableHomeEntranceAnimation && !_lpIntroVisible) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_hasAnimatedBottomNav) {
          _hasAnimatedBottomNav = true;
          _bottomNavController.forward();
        }
      });
    } else {
      _bottomNavController.value = 1.0;
      _hasAnimatedBottomNav = true;
    }
  }

  @override
  void dispose() {
    _bottomNavController.dispose();
    super.dispose();
  }

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
    // Skip animation if reduce motion is enabled
    final skipAnimation = AnimationConstants.shouldReduceMotion(context);

    return Scaffold(
      body: _screens[_currentIndex],
      // Hide bottom nav when LP intro overlay is visible
      bottomNavigationBar: _lpIntroVisible ? null : _buildBottomNav(skipAnimation),
    );
  }

  /// Build the bottom navigation bar (brand-specific)
  Widget _buildBottomNav(bool skipAnimation) {
    // Check for Us 2.0 brand - use custom bottom nav
    final us2Nav = BrandWidgetFactory.us2BottomNav(
      currentIndex: _getUs2NavIndex(_currentIndex),
      onTap: _handleUs2NavTap,
    );

    if (us2Nav != null) {
      return us2Nav;
    }

    // Default Liia bottom nav with animation
    return AnimatedBuilder(
      animation: _bottomNavController,
      builder: (context, child) {
        if (skipAnimation || !AnimationConfig.enableHomeEntranceAnimation) {
          return child!;
        }
        return SlideTransition(
          position: _bottomNavSlide,
          child: Opacity(
            opacity: _bottomNavOpacity.value,
            child: child,
          ),
        );
      },
      child: Container(
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

  /// Convert screen index to Us2 nav index (which has Poke in the middle)
  /// Screens: [Home, Inbox, Profile, Settings] (indices 0-3)
  /// Us2Nav:  [Home, Inbox, Poke, Profile, Settings] (indices 0-4)
  int _getUs2NavIndex(int screenIndex) {
    // Map screen indices to Us2 nav indices
    // 0 (Home) -> 0
    // 1 (Inbox) -> 1
    // 2 (Profile) -> 3
    // 3 (Settings) -> 4
    if (screenIndex <= 1) return screenIndex;
    return screenIndex + 1;
  }

  /// Handle Us2 nav tap (which has Poke at index 2)
  void _handleUs2NavTap(int navIndex) {
    if (navIndex == 2) {
      // Poke - show bottom sheet instead of switching screens
      _showPokeBottomSheet();
      return;
    }

    // Map Us2 nav indices back to screen indices
    // 0 (Home) -> 0
    // 1 (Inbox) -> 1
    // 3 (Profile) -> 2
    // 4 (Settings) -> 3
    int screenIndex = navIndex;
    if (navIndex > 2) {
      screenIndex = navIndex - 1;
    }

    setState(() => _currentIndex = screenIndex);
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
