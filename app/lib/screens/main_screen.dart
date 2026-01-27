import 'package:flutter/foundation.dart' show kIsWeb;
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
  int _previousIndex = 0; // Track previous index for slide direction

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
      if (_subscriptionService.isPremium) {
        if (mounted) {
          setState(() {
            _isCheckingSubscription = false;
            _showPaywall = false;
          });
        }
        return;
      }

      // Not premium according to cache - check couple subscription from API first
      // This is critical: we must verify with server before showing paywall
      final coupleStatus = await _subscriptionService.checkCoupleSubscription();
      if (coupleStatus?.isActive == true) {
        Logger.debug('Couple subscription active from API', service: 'main');
        if (mounted) {
          setState(() {
            _isCheckingSubscription = false;
            _showPaywall = false;
          });
        }
        return;
      }

      // Also refresh from RevenueCat (for non-web platforms)
      if (!kIsWeb) {
        await _subscriptionService.refreshPremiumStatus();
        if (_subscriptionService.isPremium) {
          if (mounted) {
            setState(() {
              _isCheckingSubscription = false;
              _showPaywall = false;
            });
          }
          return;
        }
      }

      // No active subscription found - show paywall
      if (mounted) {
        setState(() {
          _isCheckingSubscription = false;
          _showPaywall = true;
        });
        Logger.debug('Showing paywall - no active subscription found', service: 'main');
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

  /// Navigate to a tab with slide animation direction tracking
  void _navigateToTab(int index) {
    if (index == _currentIndex) return; // No change
    // Dismiss LP celebration when switching away from home tab
    if (_currentIndex == 0 && index != 0) {
      LpCelebrationService.dismiss();
    }
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
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
      body: ClipRect(
        child: _TabSwitcher(
          currentIndex: _currentIndex,
          previousIndex: _previousIndex,
          skipAnimation: skipAnimation,
          child: _screens[_currentIndex],
        ),
      ),
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
        if (index == _currentIndex) return; // No change
        // Dismiss LP celebration when switching away from home tab
        if (_currentIndex == 0 && index != 0) {
          LpCelebrationService.dismiss();
        }
        setState(() {
          _previousIndex = _currentIndex;
          _currentIndex = index;
        });
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
                  onTap: () => _navigateToTab(0),
                ),
                _NavItem(
                  iconOutline: BrandAssets.journalIcon,
                  iconFilled: BrandAssets.journalIconFilled,
                  label: 'Journal',
                  isActive: _currentIndex == 1,
                  onTap: () => _navigateToTab(1),
                ),
                _PokeNavItem(
                  isActive: _currentIndex == 2,
                  onTap: () => _navigateToTab(2),
                ),
                _NavItem(
                  iconOutline: BrandAssets.profileIcon,
                  iconFilled: BrandAssets.profileIconFilled,
                  label: 'Profile',
                  isActive: _currentIndex == 3,
                  onTap: () => _navigateToTab(3),
                ),
                _NavItem(
                  iconOutline: BrandAssets.settingsIcon,
                  iconFilled: BrandAssets.settingsIconFilled,
                  label: 'Settings',
                  isActive: _currentIndex == 4,
                  onTap: () => _navigateToTab(4),
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

/// Custom tab switcher with smooth bidirectional slide animation
class _TabSwitcher extends StatefulWidget {
  final int currentIndex;
  final int previousIndex;
  final bool skipAnimation;
  final Widget child;

  const _TabSwitcher({
    required this.currentIndex,
    required this.previousIndex,
    required this.skipAnimation,
    required this.child,
  });

  @override
  State<_TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<_TabSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _incomingAnimation;
  late Animation<Offset> _outgoingAnimation;

  Widget? _oldChild;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _setupAnimations(widget.currentIndex > widget.previousIndex);
  }

  void _setupAnimations(bool movingRight) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Incoming: slides from right to center (or left to center)
    _incomingAnimation = Tween<Offset>(
      begin: movingRight ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(curve);

    // Outgoing: slides from center to left (or center to right)
    _outgoingAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: movingRight ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0),
    ).animate(curve);
  }

  @override
  void didUpdateWidget(_TabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentIndex != oldWidget.currentIndex) {
      // Tab changed - start animation
      _oldChild = oldWidget.child;

      final movingRight = widget.currentIndex > oldWidget.currentIndex;
      _setupAnimations(movingRight);

      if (!widget.skipAnimation) {
        _isAnimating = true;
        _controller.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _isAnimating = false;
              _oldChild = null;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skipAnimation || !_isAnimating || _oldChild == null) {
      // No animation needed
      return widget.child;
    }

    // During animation, show both widgets sliding
    return Stack(
      fit: StackFit.expand,
      children: [
        // Old screen sliding out
        SlideTransition(
          position: _outgoingAnimation,
          child: _oldChild!,
        ),
        // New screen sliding in
        SlideTransition(
          position: _incomingAnimation,
          child: widget.child,
        ),
      ],
    );
  }
}
