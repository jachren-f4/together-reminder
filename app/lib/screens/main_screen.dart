import 'package:flutter/material.dart';
import 'package:togetherremind/screens/home_screen.dart';
import 'package:togetherremind/screens/journal_screen.dart';
import 'package:togetherremind/screens/poke_screen.dart';
import 'package:togetherremind/screens/profile_screen.dart';
import 'package:togetherremind/screens/settings_screen.dart';
import 'package:togetherremind/screens/paywall_screen.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/config/brand/brand_assets.dart';
import 'package:togetherremind/widgets/brand/brand_widget_factory.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/services/haptic_service.dart';
import 'package:togetherremind/services/nav_style_service.dart';
import 'package:togetherremind/services/subscription_service.dart';
import 'package:togetherremind/animations/animation_config.dart';
import 'package:togetherremind/config/animation_constants.dart';
import 'package:togetherremind/utils/logger.dart';
import 'package:togetherremind/services/lp_celebration_service.dart';

/// Main app shell with bottom navigation bar
///
/// Contains tabs for:
/// - HomeScreen (daily quests, side quests)
/// - ActivityHubScreen (journal) - TODO: Replace with JournalScreen
/// - PokeScreen (send pokes)
/// - ProfileScreen
/// - SettingsScreen
///
/// Screen indices: Home=0, Journal=1, Poke=2, Profile=3, Settings=4
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

  // Subscription state - show paywall if not premium
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isCheckingSubscription = true;
  bool _showPaywall = false;

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
    _checkSubscriptionStatus();

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
      const JournalScreen(),
      const PokeScreen(),
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

    // Listen to nav style changes (Us 2.0) to rebuild bottom nav immediately
    NavStyleService.instance.addListener(_onNavStyleChanged);

    // Listen to subscription changes (e.g., user subscribes from another device)
    _subscriptionService.addListener(_onSubscriptionChanged);
  }

  /// Check if user has active subscription
  Future<void> _checkSubscriptionStatus() async {
    try {
      // First check cached status (fast)
      final isPremium = _subscriptionService.isPremium;

      if (isPremium) {
        // User has premium, show app content
        if (mounted) {
          setState(() {
            _isCheckingSubscription = false;
            _showPaywall = false;
          });
        }
        return;
      }

      // Not premium according to cache, do a fresh check from RevenueCat
      await _subscriptionService.refreshPremiumStatus();
      final freshIsPremium = _subscriptionService.isPremium;

      if (mounted) {
        setState(() {
          _isCheckingSubscription = false;
          _showPaywall = !freshIsPremium;
        });

        if (_showPaywall) {
          Logger.debug('Showing paywall - user subscription lapsed or not active', service: 'main');
        }
      }
    } catch (e) {
      Logger.error('Failed to check subscription status', error: e, service: 'main');
      // On error, default to showing content (don't lock out users due to network issues)
      if (mounted) {
        setState(() {
          _isCheckingSubscription = false;
          _showPaywall = false;
        });
      }
    }
  }

  /// Called when subscription status changes
  void _onSubscriptionChanged() {
    if (mounted) {
      final isPremium = _subscriptionService.isPremium;
      setState(() {
        _showPaywall = !isPremium;
      });
      Logger.debug('Subscription changed, isPremium: $isPremium', service: 'main');
    }
  }

  /// Called when paywall is completed (user subscribed or restored)
  void _onPaywallComplete(BuildContext ctx) {
    if (mounted) {
      setState(() {
        _showPaywall = false;
      });
      Logger.debug('Paywall completed, showing app content', service: 'main');

      // If we're coming from a pushed screen (like AlreadySubscribedScreen),
      // we need to pop it to return to MainScreen
      if (Navigator.of(ctx).canPop()) {
        Navigator.of(ctx).pop();
      }
    }
  }

  void _onNavStyleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    NavStyleService.instance.removeListener(_onNavStyleChanged);
    _subscriptionService.removeListener(_onSubscriptionChanged);
    _bottomNavController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking subscription
    if (_isCheckingSubscription) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show paywall if user doesn't have active subscription
    if (_showPaywall) {
      return PaywallScreen(
        onContinue: _onPaywallComplete,
        allowSkip: false, // Hard paywall - must subscribe
        isLapsedUser: true, // This is a returning user whose subscription ended
      );
    }

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
      currentIndex: _currentIndex,
      onTap: (index) {
        // Dismiss LP celebration when switching away from home tab
        if (_currentIndex == 0 && index != 0) {
          LpCelebrationService.dismiss();
        }
        setState(() => _currentIndex = index);
      },
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
                  iconOutline: BrandAssets.journalIcon,
                  iconFilled: BrandAssets.journalIconFilled,
                  label: 'Journal',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _PokeNavItem(
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  iconOutline: BrandAssets.profileIcon,
                  iconFilled: BrandAssets.profileIconFilled,
                  label: 'Profile',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _NavItem(
                  iconOutline: BrandAssets.settingsIcon,
                  iconFilled: BrandAssets.settingsIconFilled,
                  label: 'Settings',
                  isActive: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
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
  final bool isActive;
  final VoidCallback onTap;

  const _PokeNavItem({
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
                color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
