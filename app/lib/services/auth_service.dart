import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/dev_config.dart';
import 'subscription_service.dart';

/// Authentication states
enum AuthState {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

/// Simplified Auth Service using Supabase's built-in session persistence
///
/// Key simplifications:
/// - No custom token storage (Supabase handles it automatically)
/// - No manual session restore (Supabase does it on initialize)
/// - Direct getters for token/userId from Supabase's current session
///
/// Features retained:
/// - Dev mode sign-in (skipOtpVerificationInDev)
/// - Auth state stream for UI updates
/// - Apple Sign-In support
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Supabase client
  SupabaseClient? _supabase;

  // Auth state stream
  final _authStateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateStream => _authStateController.stream;

  // Current auth state
  AuthState _authState = AuthState.initial;
  AuthState get authState => _authState;

  // Cached dev user ID (determined at initialization based on device)
  String? _cachedDevUserId;

  /// Initialize the auth service
  ///
  /// Supabase automatically:
  /// - Persists sessions to local storage
  /// - Restores sessions on app restart
  /// - Refreshes tokens when needed
  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    try {
      // Initialize Supabase (handles session persistence automatically)
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      _supabase = Supabase.instance.client;

      // Listen to auth state changes from Supabase
      _supabase!.auth.onAuthStateChange.listen((data) {
        _handleAuthStateChange(data.event, data.session);
      });

      // Set initial auth state based on current session
      final currentSession = _supabase!.auth.currentSession;
      if (currentSession != null) {
        debugPrint('✅ Session restored automatically by Supabase');
        _updateAuthState(AuthState.authenticated);
      } else {
        debugPrint('ℹ️ No existing session');
        _updateAuthState(AuthState.unauthenticated);
      }

      // Cache dev user ID based on device (for dev auth bypass)
      final shouldBypass = await DevConfig.shouldBypassAuth();
      if (shouldBypass) {
        _cachedDevUserId = await _determineDevUserId();
        debugPrint('🔧 [DEV] Cached dev user ID: $_cachedDevUserId');
      }

      debugPrint('✅ AuthService initialized');
    } catch (e) {
      debugPrint('❌ AuthService initialization failed: $e');
      _updateAuthState(AuthState.unauthenticated);
    }
  }

  // ============================================================================
  // SIMPLE GETTERS (no async, no storage reads)
  // ============================================================================

  /// Get current access token directly from Supabase
  String? get accessToken => _supabase?.auth.currentSession?.accessToken;

  /// Get current user ID directly from Supabase
  String? get userId => _supabase?.auth.currentUser?.id;

  /// Get current user email directly from Supabase
  String? get userEmail => _supabase?.auth.currentUser?.email;

  /// Check if user is authenticated
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Check if user's email is verified
  /// Returns true if Supabase has confirmed the email (via OTP verification)
  bool get isEmailVerified {
    return _supabase?.auth.currentUser?.emailConfirmedAt != null;
  }

  /// Check if an email should bypass magic link verification
  /// Test accounts use password auth for easier testing
  bool shouldBypassMagicLink(String email) {
    // Test email patterns that skip magic link
    if (email.endsWith('@dev.test')) return true;
    if (email.contains('+test')) return true;
    return false;
  }

  // ============================================================================
  // ASYNC GETTERS (for backwards compatibility)
  // ============================================================================

  /// Get current access token (async version for compatibility)
  Future<String?> getAccessToken() async => accessToken;

  /// Get current user ID (async version for compatibility)
  Future<String?> getUserId() async => userId;

  /// Get current user email (async version for compatibility)
  Future<String?> getUserEmail() async => userEmail;

  // ============================================================================
  // AUTH HEADERS
  // ============================================================================

  /// Create Authorization header for API requests
  Future<Map<String, String>> getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Get JWT token from current session
    final token = accessToken;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // In development mode, add X-Dev-User-Id header for auth bypass
    // Only set if there is NO real JWT token (real auth takes priority)
    final devUserId = _cachedDevUserId;
    if (devUserId != null && token == null) {
      headers['X-Dev-User-Id'] = devUserId;
      debugPrint('🔧 [DEV] Adding X-Dev-User-Id header: $devUserId');
    }

    return headers;
  }

  // ============================================================================
  // SIGN IN METHODS
  // ============================================================================

  /// Sign in with email and magic link (sends OTP)
  Future<bool> signInWithMagicLink(String email) async {
    try {
      await _supabase!.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'togetherremind://auth-callback',
      );
      debugPrint('✅ Magic link sent to $email');
      return true;
    } catch (e) {
      debugPrint('❌ Sign in failed: $e');
      return false;
    }
  }

  /// Send verification email to the currently logged-in user
  /// Used from Settings when user wants to verify their account
  Future<bool> sendVerificationEmail() async {
    final email = userEmail;
    if (email == null) {
      debugPrint('❌ Cannot send verification email - no user email');
      return false;
    }
    debugPrint('📧 Sending verification email to $email');
    return await signInWithMagicLink(email);
  }

  /// Sign in/up with password (no OTP required)
  /// Used for new user signup and test account login
  ///
  /// Uses deterministic password based on email hash.
  /// REQUIRES: Supabase Dashboard > Auth > Providers > Email > "Confirm email" = DISABLED
  Future<bool> signInWithPassword(String email) async {
    try {
      _updateAuthState(AuthState.loading);

      // Deterministic password based on email (SHA256 for cross-device stability)
      final emailBytes = utf8.encode(email);
      final hash = sha256.convert(emailBytes);
      final shortHash = hash.toString().substring(0, 12);
      final password = 'DevPass_${shortHash}_2024!';

      debugPrint('🔐 Attempting password sign-in for $email');

      // Try sign-in first (existing user)
      try {
        final signInResponse = await _supabase!.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (signInResponse.session != null) {
          _updateAuthState(AuthState.authenticated);
          debugPrint('✅ Signed in existing user: $email');
          return true;
        }
      } on AuthException catch (e) {
        debugPrint('ℹ️ Sign-in failed: ${e.message}, trying sign-up...');
      }

      // Try sign-up (new user)
      try {
        final signUpResponse = await _supabase!.auth.signUp(
          email: email,
          password: password,
        );

        if (signUpResponse.session != null) {
          _updateAuthState(AuthState.authenticated);
          debugPrint('✅ Created and signed in new user: $email');
          return true;
        } else if (signUpResponse.user != null) {
          // User created but no session - email confirmation might be enabled
          debugPrint('⚠️ No session after signup - retrying sign-in...');

          // Retry sign-in
          try {
            final retryResponse = await _supabase!.auth.signInWithPassword(
              email: email,
              password: password,
            );
            if (retryResponse.session != null) {
              _updateAuthState(AuthState.authenticated);
              debugPrint('✅ Signed in after signup: $email');
              return true;
            }
          } catch (_) {}
        }
      } on AuthException catch (e) {
        debugPrint('❌ Sign-up failed: ${e.message}');
      }

      _updateAuthState(AuthState.unauthenticated);
      return false;
    } catch (e) {
      debugPrint('❌ Password sign-in error: $e');
      _updateAuthState(AuthState.unauthenticated);
      return false;
    }
  }

  /// Verify OTP from magic link
  Future<bool> verifyOTP(String email, String token) async {
    try {
      _updateAuthState(AuthState.loading);

      final response = await _supabase!.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      if (response.session != null) {
        // Supabase automatically persists the session
        _updateAuthState(AuthState.authenticated);
        debugPrint('✅ OTP verified successfully');
        return true;
      }

      _updateAuthState(AuthState.unauthenticated);
      return false;
    } catch (e) {
      debugPrint('❌ OTP verification failed: $e');
      _updateAuthState(AuthState.unauthenticated);
      return false;
    }
  }

  /// Development sign-in that bypasses OTP verification
  ///
  /// Uses password auth with a deterministic password based on email hash.
  /// REQUIRES: Supabase Dashboard > Auth > Providers > Email > "Confirm email" = DISABLED
  Future<bool> devSignInWithEmail(String email) async {
    try {
      _updateAuthState(AuthState.loading);

      // Deterministic password based on email (SHA256 for cross-device stability)
      final emailBytes = utf8.encode(email);
      final hash = sha256.convert(emailBytes);
      final shortHash = hash.toString().substring(0, 12);
      final devPassword = 'DevPass_${shortHash}_2024!';

      debugPrint('🔧 [DEV] Attempting dev sign-in for $email');

      // Try sign-in first (existing user)
      try {
        final signInResponse = await _supabase!.auth.signInWithPassword(
          email: email,
          password: devPassword,
        );

        if (signInResponse.session != null) {
          _updateAuthState(AuthState.authenticated);
          debugPrint('✅ [DEV] Signed in existing user: $email');
          return true;
        }
      } on AuthException catch (e) {
        debugPrint('ℹ️ [DEV] Sign-in failed: ${e.message}, trying sign-up...');
      }

      // Try sign-up (new user)
      try {
        final signUpResponse = await _supabase!.auth.signUp(
          email: email,
          password: devPassword,
          data: {'dev_mode': true},
        );

        if (signUpResponse.session != null) {
          _updateAuthState(AuthState.authenticated);
          debugPrint('✅ [DEV] Created and signed in new user: $email');
          return true;
        } else if (signUpResponse.user != null) {
          // User created but no session - email confirmation is enabled
          debugPrint('⚠️ [DEV] No session - enable "Confirm email" = DISABLED in Supabase');

          // Retry sign-in
          try {
            final retryResponse = await _supabase!.auth.signInWithPassword(
              email: email,
              password: devPassword,
            );
            if (retryResponse.session != null) {
              _updateAuthState(AuthState.authenticated);
              debugPrint('✅ [DEV] Signed in after signup: $email');
              return true;
            }
          } catch (_) {}
        }
      } on AuthException catch (e) {
        debugPrint('❌ [DEV] Sign-up failed: ${e.message}');
      }

      _updateAuthState(AuthState.unauthenticated);
      return false;
    } catch (e) {
      debugPrint('❌ [DEV] Dev sign-in error: $e');
      _updateAuthState(AuthState.unauthenticated);
      return false;
    }
  }

  /// Sign in with Apple
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      _updateAuthState(AuthState.loading);

      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        debugPrint('❌ Apple Sign-In: No ID token received');
        _updateAuthState(AuthState.unauthenticated);
        return {'success': false};
      }

      // Extract display name if provided
      String? displayName;
      if (credential.givenName != null || credential.familyName != null) {
        final parts = [credential.givenName, credential.familyName]
            .where((p) => p != null && p.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          displayName = parts.join(' ');
        }
      }

      final response = await _supabase!.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.session != null) {
        _updateAuthState(AuthState.authenticated);
        debugPrint('✅ Apple Sign-In successful');

        if (displayName != null) {
          await updateDisplayName(displayName);
        }

        return {'success': true, 'displayName': displayName};
      }

      _updateAuthState(AuthState.unauthenticated);
      return {'success': false};
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('⚠️ Apple Sign-In cancelled: ${e.code}');
      _updateAuthState(AuthState.unauthenticated);
      return {'success': false, 'cancelled': e.code == AuthorizationErrorCode.canceled};
    } catch (e) {
      debugPrint('❌ Apple Sign-In error: $e');
      _updateAuthState(AuthState.unauthenticated);
      return {'success': false};
    }
  }

  // ============================================================================
  // SIGN OUT & TOKEN REFRESH
  // ============================================================================

  /// Sign out and clear session
  Future<void> signOut() async {
    try {
      // Log out from RevenueCat first
      await SubscriptionService().logOut();

      await _supabase!.auth.signOut();
      _updateAuthState(AuthState.unauthenticated);
      debugPrint('✅ Signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      _updateAuthState(AuthState.unauthenticated);
    }
  }

  /// Refresh access token
  Future<bool> refreshToken() async {
    try {
      debugPrint('🔄 Refreshing access token...');
      final response = await _supabase!.auth.refreshSession();

      if (response.session != null) {
        debugPrint('✅ Token refreshed successfully');
        return true;
      }

      debugPrint('❌ Token refresh failed');
      await signOut();
      return false;
    } catch (e) {
      debugPrint('❌ Token refresh error: $e');
      await signOut();
      return false;
    }
  }

  /// Handle API 401 responses
  Future<bool> handleUnauthorized() async {
    debugPrint('🔐 Handling 401 - attempting token refresh');
    return await refreshToken();
  }

  // ============================================================================
  // USER PROFILE
  // ============================================================================

  /// Get user's display name from Supabase metadata
  Future<String?> getDisplayName() async {
    try {
      final user = _supabase?.auth.currentUser;
      final metadata = user?.userMetadata;
      final fullName = metadata?['full_name'] as String?;
      return (fullName != null && fullName.isNotEmpty) ? fullName : null;
    } catch (e) {
      debugPrint('Error getting display name: $e');
      return null;
    }
  }

  /// Update user's display name in Supabase metadata
  Future<bool> updateDisplayName(String name) async {
    try {
      final response = await _supabase!.auth.updateUser(
        UserAttributes(data: {'full_name': name}),
      );

      if (response.user != null) {
        debugPrint('✅ Display name updated to: $name');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error updating display name: $e');
      return false;
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  void _updateAuthState(AuthState newState) {
    _authState = newState;
    _authStateController.add(newState);
  }

  void _handleAuthStateChange(AuthChangeEvent event, Session? session) {
    debugPrint('🔐 Auth state changed: $event');

    switch (event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        if (session != null) {
          _updateAuthState(AuthState.authenticated);
        }
        break;
      case AuthChangeEvent.signedOut:
        _updateAuthState(AuthState.unauthenticated);
        break;
      default:
        break;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Determine dev user ID based on platform/device
  Future<String?> _determineDevUserId() async {
    if (kIsWeb) {
      final userId = DevConfig.devUserIdWeb;
      if (userId.contains('REPLACE_WITH')) return null;
      debugPrint('🔧 [DEV] Web platform → using devUserIdWeb');
      return userId;
    }

    if (!kIsWeb && Platform.isIOS) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        final deviceModel = iosInfo.utsname.machine;

        // iPhone 12 models (iPhone13,x) → use devUserIdWeb (partner device)
        if (deviceModel.startsWith('iPhone13,')) {
          debugPrint('🔧 [DEV] iPhone 12 detected → using devUserIdWeb');
          return DevConfig.devUserIdWeb;
        }

        // Other iOS devices → use devUserIdAndroid (primary device)
        debugPrint('🔧 [DEV] Primary iOS device → using devUserIdAndroid');
        return DevConfig.devUserIdAndroid;
      } catch (e) {
        debugPrint('⚠️ [DEV] Could not get iOS device info: $e');
      }
    }

    // Default: Android and fallback
    final userId = DevConfig.devUserIdAndroid;
    if (userId.contains('REPLACE_WITH')) return null;
    return userId;
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}
