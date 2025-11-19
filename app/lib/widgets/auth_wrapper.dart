import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/dev_config.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/couple_pairing_service.dart';
import '../models/partner.dart';
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
        debugPrint('✅ Restored partner from database: ${partner.name}');
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
    if (kDebugMode && DevConfig.skipAuthInDev) {
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
