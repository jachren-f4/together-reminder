import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    _authService.authStateStream.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Set app context for services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.setAppContext(context);
      LovePointService.setAppContext(context);
    });

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
          return const OnboardingScreen();
        }
    }
  }
}
