import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/dev_config.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/app_bootstrap_service.dart';
import '../screens/onboarding/value_carousel_screen.dart';
import '../screens/name_entry_screen.dart';
import '../screens/partner_name_entry_screen.dart';
import '../screens/main_screen.dart';
import '../services/notification_service.dart';
import 'editorial/editorial_styles.dart';
import 'brand/us2/us2_logo.dart';

/// Auth wrapper that handles authentication state and navigation
///
/// Navigation flow:
/// - Unauthenticated → OnboardingScreen
/// - Authenticated, no name → NameEntryScreen
/// - Authenticated, has name, no partner → PairingScreen
/// - Authenticated, has name, has partner → Bootstrap → MainScreen
///
/// Session persistence is handled by Supabase automatically.
/// Initialization is handled by AppBootstrapService before showing MainScreen.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  final _storageService = StorageService();
  final _secureStorage = const FlutterSecureStorage();
  final _bootstrapService = AppBootstrapService.instance;

  // Dev bypass state
  bool _hasCheckedBypass = false;
  bool _shouldBypassAuth = false;

  @override
  void initState() {
    super.initState();

    // Check if we should bypass auth (simulators/web only)
    _checkBypassStatus();

    // Clear stale iOS Keychain data if needed
    _clearStaleKeychainDataIfNeeded();

    // Listen to auth state changes
    _authService.authStateStream.listen((state) {
      if (mounted) {
        // Reset bootstrap when auth state changes (e.g., logout)
        if (state == AuthState.unauthenticated) {
          _bootstrapService.reset();
        }
        setState(() {});
      }
    });

    // Listen to bootstrap state changes
    _bootstrapService.addListener(_onBootstrapStateChanged);
  }

  @override
  void dispose() {
    _bootstrapService.removeListener(_onBootstrapStateChanged);
    super.dispose();
  }

  void _onBootstrapStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Clear stale iOS Keychain data that persisted after app uninstall
  ///
  /// iOS Keychain survives app uninstalls. If the Keychain has app flags
  /// but Supabase has no session, clear the stale flags.
  Future<void> _clearStaleKeychainDataIfNeeded() async {
    // Skip on web - localStorage is cleared on reinstall
    if (kIsWeb) return;

    // Wait a moment for Supabase to restore session
    await Future.delayed(const Duration(milliseconds: 500));

    final hasCompletedOnboarding = await _secureStorage.read(key: 'has_completed_onboarding');

    // If Keychain says onboarding completed but Supabase has no session,
    // the user likely reinstalled the app - clear stale data
    if (hasCompletedOnboarding == 'true' && !_authService.isAuthenticated) {
      debugPrint('🔄 Clearing stale Keychain data (flags but no Supabase session)');
      await _secureStorage.delete(key: 'has_completed_onboarding');
      await _secureStorage.delete(key: 'couple_id');
      await _secureStorage.delete(key: 'pending_user_name');
    }
  }

  /// Check if auth should be bypassed (only on simulators/web, not physical devices)
  Future<void> _checkBypassStatus() async {
    final shouldBypass = await DevConfig.shouldBypassAuth();
    if (mounted) {
      setState(() {
        _shouldBypassAuth = shouldBypass;
        _hasCheckedBypass = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set app context for NotificationService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.setAppContext(context);
    });

    // Wait for bypass check to complete
    if (!_hasCheckedBypass) {
      return _buildLoadingScreen('Loading...');
    }

    // Dev mode: Skip auth entirely for faster development
    // Only bypasses on simulators/emulators/web, NEVER on physical devices
    if (_shouldBypassAuth && _authService.authState != AuthState.authenticated) {
      if (_storageService.hasPartner()) {
        return _buildWithBootstrap();
      } else {
        return const ValueCarouselScreen();
      }
    }

    // Check auth state from Supabase (session is restored automatically)
    switch (_authService.authState) {
      case AuthState.authenticated:
        // User is authenticated - proceed to routing
        break;

      case AuthState.initial:
      case AuthState.loading:
        return _buildLoadingScreen('Loading...');

      case AuthState.unauthenticated:
        // Not authenticated - show new onboarding carousel
        return const ValueCarouselScreen();
    }

    // User is authenticated - check if they have a name
    final user = _storageService.getUser();
    final hasName = user != null && user.name != null && user.name!.isNotEmpty;

    if (!hasName) {
      // Authenticated but no name - show name entry
      return const NameEntryScreen();
    }

    // Check partner status
    if (_storageService.hasPartner()) {
      // Has partner - bootstrap and show MainScreen
      return _buildWithBootstrap();
    } else {
      // No local partner - try bootstrap to restore from server
      // Bootstrap will fetch user/partner from server if needed
      if (!_bootstrapService.isReady && _bootstrapService.state == BootstrapState.initial) {
        // Start bootstrap to try restoring partner from server
        _bootstrapService.bootstrap();
        return _buildLoadingScreen('Checking pairing status...');
      }

      if (_bootstrapService.isBootstrapping) {
        return _buildLoadingScreen(_bootstrapService.statusMessage);
      }

      // Bootstrap finished - check again if partner was restored
      if (_storageService.hasPartner()) {
        return const MainScreen();
      }

      // Still no partner after bootstrap - show partner name entry (single-phone mode)
      // This screen creates the phantom partner, then navigates to AnniversaryScreen
      return const PartnerNameEntryScreen();
    }
  }

  /// Build MainScreen after ensuring bootstrap is complete
  Widget _buildWithBootstrap() {
    // Start bootstrap if not started
    if (_bootstrapService.state == BootstrapState.initial) {
      _bootstrapService.bootstrap();
    }

    // Show loading while bootstrap is in progress
    if (!_bootstrapService.isReady) {
      if (_bootstrapService.state == BootstrapState.error) {
        return _buildErrorScreen();
      }
      return _buildLoadingScreen(_bootstrapService.statusMessage);
    }

    // Bootstrap complete - show MainScreen
    return const MainScreen();
  }

  /// Build loading screen with newspaper-style branding
  Widget _buildLoadingScreen(String message) {
    final brandName = BrandLoader().config.appName;
    final isUs2 = BrandLoader().config.brand == Brand.us2;

    if (isUs2) {
      return _buildUs2LoadingScreen(brandName, message);
    }

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Masthead
              Text(
                'PREPARING TODAY\'S EDITION',
                style: TextStyle(
                  fontFamily: EditorialStyles.headline.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                  color: EditorialStyles.inkMuted,
                ),
              ),
              const SizedBox(height: 8),

              // Brand name
              Text(
                brandName,
                style: TextStyle(
                  fontFamily: EditorialStyles.headline.fontFamily,
                  fontSize: 42,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                  color: EditorialStyles.ink,
                ),
              ),

              // Divider
              Container(
                width: 48,
                height: 2,
                margin: const EdgeInsets.symmetric(vertical: 20),
                color: EditorialStyles.ink,
              ),

              // Status text
              Text(
                message,
                style: TextStyle(
                  fontFamily: EditorialStyles.headline.fontFamily,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: EditorialStyles.inkMuted,
                ),
              ),
              const SizedBox(height: 32),

              // Animated print lines
              const _PrintLinesAnimation(),
            ],
          ),
        ),
      ),
    );
  }

  /// Us 2.0 styled loading screen
  Widget _buildUs2LoadingScreen(String brandName, String message) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: Us2Theme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Logo with heart at top, centered
                const Us2Logo(),

                const Spacer(),

                // Loading content in center
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status text
                      Text(
                        message,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Us2Theme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Animated gradient dots
                      const _Us2LoadingDots(),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build error screen with retry button
  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _bootstrapService.errorMessage ?? 'Please try again',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _bootstrapService.retry();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated print lines that fade in and out like a newspaper being printed
class _PrintLinesAnimation extends StatefulWidget {
  const _PrintLinesAnimation();

  @override
  State<_PrintLinesAnimation> createState() => _PrintLinesAnimationState();
}

class _PrintLinesAnimationState extends State<_PrintLinesAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Line widths for the print effect
  static const List<double> _lineWidths = [90, 130, 110, 70];
  // Staggered delays for each line
  static const List<double> _delays = [0.0, 0.13, 0.27, 0.4];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_lineWidths.length, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Calculate opacity with staggered delay
            final progress = (_controller.value - _delays[index]) % 1.0;
            // Sine wave for smooth fade in/out
            final opacity = (progress < 0.5)
                ? (progress * 2) // Fade in
                : (1.0 - (progress - 0.5) * 2); // Fade out
            final clampedOpacity = (opacity * 0.85 + 0.15).clamp(0.15, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                width: _lineWidths[index],
                height: 2,
                color: EditorialStyles.ink.withValues(alpha: clampedOpacity),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Us 2.0 animated loading dots with gradient colors
class _Us2LoadingDots extends StatefulWidget {
  const _Us2LoadingDots();

  @override
  State<_Us2LoadingDots> createState() => _Us2LoadingDotsState();
}

class _Us2LoadingDotsState extends State<_Us2LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 24,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final offset = index * 0.33;
              final animValue = (_controller.value + offset) % 1.0;
              final wave = animValue < 0.5
                  ? animValue * 2
                  : 2.0 - (animValue * 2);
              final easedWave = Curves.easeInOut.transform(wave);
              final scale = 0.6 + (0.4 * easedWave);
              final opacity = 0.4 + (0.6 * easedWave);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: Us2Theme.accentGradient,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
