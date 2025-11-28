import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/dev_config.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/couple_pairing_service.dart';
import '../models/partner.dart';
import '../models/user.dart';
import '../screens/auth_screen.dart';
import '../screens/onboarding_screen.dart';
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

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    _authService.authStateStream.listen((state) {
      if (mounted) {
        // Reset pairing check when auth state changes
        if (state == AuthState.authenticated) {
          _hasCheckedPairingStatus = false;
        }
        setState(() {});
      }
    });
  }

  /// Ensure coupleId and User are saved (for quest sync)
  Future<void> _ensureCoupleIdSaved() async {
    try {
      // Ensure User object exists in storage (required for quest generation)
      if (_storageService.getUser() == null) {
        final userId = await _secureStorage.read(key: 'supabase_user_id');
        final userEmail = await _secureStorage.read(key: 'supabase_user_email');

        if (userId != null) {
          final pushToken = await NotificationService.getToken() ?? '';
          final user = User(
            id: userId,
            pushToken: pushToken,
            createdAt: DateTime.now(),
            name: userEmail?.split('@').first ?? 'User',
          );
          await _storageService.saveUser(user);
          debugPrint('✅ User restored: ${user.name} (${user.id})');
        }
      }

      // Check if coupleId already exists
      final existingCoupleId = await _secureStorage.read(key: 'couple_id');
      if (existingCoupleId != null) {
        debugPrint('✅ CoupleId already saved: $existingCoupleId');
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
      final status = await _couplePairingService.getStatus();
      if (status != null && mounted) {
        // User is paired in database - restore partner locally
        final partner = Partner(
          name: status.partnerName ?? status.partnerEmail?.split('@').first ?? 'Partner',
          pushToken: '', // Will be set up separately
          pairedAt: status.createdAt,
          avatarEmoji: '💕',
        );
        await _storageService.savePartner(partner);

        // Store couple ID for quest generation and sync
        await _secureStorage.write(key: 'couple_id', value: status.coupleId);

        // Also create User object if missing (required for quest generation)
        if (_storageService.getUser() == null) {
          final userId = await _secureStorage.read(key: 'supabase_user_id');
          final userEmail = await _secureStorage.read(key: 'supabase_user_email');

          if (userId != null) {
            final pushToken = await NotificationService.getToken() ?? '';
            final user = User(
              id: userId,
              pushToken: pushToken,
              createdAt: DateTime.now(),
              name: userEmail?.split('@').first ?? 'User',
            );
            await _storageService.saveUser(user);
            debugPrint('✅ User restored: ${user.name} (${user.id})');
          }
        }

        debugPrint('✅ Restored partner from database: ${partner.name}');
        debugPrint('✅ Restored couple ID: ${status.coupleId}');
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

    // Dev mode: Skip auth entirely for faster development
    // Also supports profile builds for physical device testing (walking outside, etc.)
    final canBypass = kDebugMode || DevConfig.allowAuthBypassInRelease;
    if (canBypass && DevConfig.skipAuthInDev) {
      if (_storageService.hasPartner()) {
        return const HomeScreen();
      } else {
        return const OnboardingScreen();
      }
    }

    // Check auth state
    switch (_authService.authState) {
      case AuthState.initial:
      case AuthState.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case AuthState.unauthenticated:
        return const AuthScreen();

      case AuthState.authenticated:
        // User is authenticated, check if they have a partner
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
          // Already checked - show onboarding
          return const OnboardingScreen();
        }
    }
  }
}
