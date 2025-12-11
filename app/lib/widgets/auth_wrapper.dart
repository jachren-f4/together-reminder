import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/dev_config.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/couple_pairing_service.dart';
import '../services/user_profile_service.dart';
import '../screens/auth_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/name_entry_screen.dart';
import '../screens/pairing_screen.dart';
import '../screens/home_screen.dart';
import '../services/notification_service.dart';
import '../services/love_point_service.dart';

/// Auth wrapper that handles authentication state and navigation
///
/// Shows:
/// - AuthScreen if not authenticated
/// - OnboardingScreen if authenticated but no partner
/// - HomeScreen if authenticated and has partner
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  final _storageService = StorageService();
  final _couplePairingService = CouplePairingService();
  final _secureStorage = const FlutterSecureStorage();

  bool _isCheckingPairingStatus = false;
  bool _hasCheckedPairingStatus = false;

  // Dev bypass state - determined async in initState
  bool _hasCheckedBypass = false;
  bool _shouldBypassAuth = false;

  // First run check - determines if user should see onboarding first
  bool _hasCheckedFirstRun = false;
  bool _isFirstRun = true;

  @override
  void initState() {
    super.initState();

    // Check if we should bypass auth (async, but fast)
    _checkBypassStatus();

    // Check if this is a first run (no onboarding completed yet)
    _checkFirstRun();

    // Listen to auth state changes
    _authService.authStateStream.listen((state) {
      if (mounted) {
        // Reset pairing check when auth state changes
        if (state == AuthState.authenticated) {
          _hasCheckedPairingStatus = false;
          // Re-check first run flag - user may have completed onboarding during auth flow
          _checkFirstRun();
        }
        setState(() {});
      }
    });
  }

  /// Check if user has completed onboarding before
  /// Also validates Keychain state against auth state to handle iOS Keychain persistence
  Future<void> _checkFirstRun() async {
    final hasCompletedOnboarding = await _secureStorage.read(key: 'has_completed_onboarding');

    // iOS Keychain survives app uninstalls. If Keychain says "completed" but user
    // is not authenticated, clear the stale Keychain data to ensure fresh onboarding.
    if (hasCompletedOnboarding == 'true' && _authService.authState == AuthState.unauthenticated) {
      debugPrint('🔄 Clearing stale Keychain data (onboarding flag but no auth)');
      await _clearStaleKeychainData();
      if (mounted) {
        setState(() {
          _isFirstRun = true;
          _hasCheckedFirstRun = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isFirstRun = hasCompletedOnboarding != 'true';
        _hasCheckedFirstRun = true;
      });
    }
  }

  /// Clear stale Keychain data that persisted after app uninstall
  Future<void> _clearStaleKeychainData() async {
    try {
      await _secureStorage.delete(key: 'has_completed_onboarding');
      await _secureStorage.delete(key: 'couple_id');
      // Clear any other onboarding-related keys
      await _secureStorage.delete(key: 'supabase_access_token');
      await _secureStorage.delete(key: 'supabase_refresh_token');
      debugPrint('✅ Stale Keychain data cleared');
    } catch (e) {
      debugPrint('⚠️ Error clearing stale Keychain data: $e');
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

  /// Ensure coupleId and User are saved (for quest sync)
  Future<void> _ensureCoupleIdSaved() async {
    try {
      // Sync push token to server (handles token refresh between sessions)
      NotificationService.syncTokenToServer();

      // Ensure User object exists in storage (required for quest generation)
      // Use UserProfileService to fetch from server if missing
      if (_storageService.getUser() == null) {
        try {
          final userProfileService = UserProfileService();
          await userProfileService.getProfile();
          debugPrint('✅ User restored from server');
        } catch (e) {
          debugPrint('⚠️ Could not restore user from server: $e');
        }
      }

      // Check if coupleId already exists
      final existingCoupleId = await _secureStorage.read(key: 'couple_id');
      if (existingCoupleId != null) {
        debugPrint('✅ CoupleId already saved: $existingCoupleId');
        // Still sync partner data from server (handles name changes)
        // getStatus() now syncs partner to Hive if changed
        await _couplePairingService.getStatus();
        _hasCheckedPairingStatus = true;
        return;
      }

      // Fetch from API and save
      final status = await _couplePairingService.getStatus();
      if (status != null) {
        await _secureStorage.write(key: 'couple_id', value: status.coupleId);
        debugPrint('✅ CoupleId saved: ${status.coupleId}');
      }
      _hasCheckedPairingStatus = true;
    } catch (e) {
      debugPrint('❌ Error ensuring coupleId: $e');
      _hasCheckedPairingStatus = true;
    }
  }

  /// Check if user is paired in database and restore partner if so
  Future<void> _checkAndRestorePairingStatus() async {
    if (_isCheckingPairingStatus || _hasCheckedPairingStatus) return;

    setState(() {
      _isCheckingPairingStatus = true;
    });

    try {
      // First, ensure User is restored from server if missing
      if (_storageService.getUser() == null) {
        try {
          final userProfileService = UserProfileService();
          final result = await userProfileService.getProfile();
          debugPrint('✅ User restored from server: ${result.user.name}');

          // getProfile also restores partner if user is paired
          if (result.isPaired && result.coupleId != null) {
            await _secureStorage.write(key: 'couple_id', value: result.coupleId!);
            debugPrint('✅ Partner restored from profile: ${result.partner?.name}');
            debugPrint('✅ Restored couple ID: ${result.coupleId}');
          }
        } catch (e) {
          debugPrint('⚠️ Could not restore user from server: $e');
        }
      } else {
        // User exists but no partner - check pairing status
        final status = await _couplePairingService.getStatus();
        if (status != null && mounted) {
          // getStatus() already saves Partner to Hive
          await _secureStorage.write(key: 'couple_id', value: status.coupleId);
          debugPrint('✅ Restored partner from status: ${status.partnerName}');
          debugPrint('✅ Restored couple ID: ${status.coupleId}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking pairing status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPairingStatus = false;
          _hasCheckedPairingStatus = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set app context for services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.setAppContext(context);
      LovePointService.setAppContext(context);
    });

    // Wait for bypass and first run checks to complete
    if (!_hasCheckedBypass || !_hasCheckedFirstRun) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Dev mode: Skip auth entirely for faster development
    // Only bypasses on simulators/emulators/web, NEVER on physical devices
    if (_shouldBypassAuth) {
      if (_storageService.hasPartner()) {
        return const HomeScreen();
      } else {
        return const OnboardingScreen();
      }
    }

    // Check auth state FIRST - if authenticated, skip first run check
    // This handles the case where user completed OTP but app still has old first-run flag
    switch (_authService.authState) {
      case AuthState.authenticated:
        // User is authenticated - proceed to partner check (skip first run)
        break; // Fall through to partner check below

      case AuthState.initial:
      case AuthState.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case AuthState.unauthenticated:
        // Not authenticated - always show OnboardingScreen
        // Note: We don't use _isFirstRun here because iOS Keychain persists
        // after app uninstall, causing stale flags to skip onboarding
        return const OnboardingScreen();
    }

    // At this point, user is authenticated - check if user has a name
    final user = _storageService.getUser();
    final hasName = user != null && user.name != null && user.name!.isNotEmpty;

    if (!hasName) {
      // User is authenticated but has no name - show name entry screen
      return const NameEntryScreen();
    }

    // Check partner status
    if (_storageService.hasPartner()) {
      // Also ensure coupleId is saved (for quest sync)
      if (!_hasCheckedPairingStatus) {
        _ensureCoupleIdSaved();
      }
      return const HomeScreen();
    } else {
      // No local partner - check if paired in database
      if (!_hasCheckedPairingStatus) {
        // Trigger async check
        _checkAndRestorePairingStatus();
        // Show loading while checking
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking pairing status...'),
              ],
            ),
          ),
        );
      }
      // Already checked and no partner - show pairing screen
      return const PairingScreen();
    }
  }
}
