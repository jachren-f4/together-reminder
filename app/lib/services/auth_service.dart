import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/dev_config.dart';
import '../config/supabase_config.dart';

/// Authentication states
enum AuthState {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

/// Auth Service for managing Supabase authentication
/// 
/// Features:
/// - Secure token storage
/// - Background token refresh (5 min before expiry)
/// - Local JWT expiry detection
/// - Cross-device token sync
/// - Automatic retry on auth failures
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Secure storage for tokens
  final _secureStorage = const FlutterSecureStorage();
  
  // Supabase client
  SupabaseClient? _supabase;
  
  // Auth state stream
  final _authStateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateStream => _authStateController.stream;
  
  // Current auth state
  AuthState _authState = AuthState.initial;
  AuthState get authState => _authState;
  
  // Background refresh timer
  Timer? _refreshTimer;
  
  // Storage keys
  static const _keyAccessToken = 'supabase_access_token';
  static const _keyRefreshToken = 'supabase_refresh_token';
  static const _keyTokenExpiry = 'supabase_token_expiry';
  static const _keyUserId = 'supabase_user_id';
  static const _keyUserEmail = 'supabase_user_email';

  // Cached dev user ID (determined at initialization based on device)
  String? _cachedDevUserId;

  /// Initialize the auth service
  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    try {
      // Initialize Supabase
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      
      _supabase = Supabase.instance.client;
      
      // Listen to auth state changes from Supabase
      _supabase!.auth.onAuthStateChange.listen((data) {
        _handleAuthStateChange(data.event, data.session);
      });
      
      // Try to restore previous session
      await _restoreSession();
      
      // Start background refresh timer
      _startRefreshTimer();

      // Cache dev user ID based on device (for dev auth bypass)
      // Only on simulators/web, not physical devices
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

  /// Get current access token
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: _keyAccessToken);
    } catch (e) {
      debugPrint('Error reading access token: $e');
      return null;
    }
  }

  /// Get current user ID
  Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: _keyUserId);
    } catch (e) {
      debugPrint('Error reading user ID: $e');
      return null;
    }
  }

  /// Get current user email
  Future<String?> getUserEmail() async {
    try {
      return await _secureStorage.read(key: _keyUserEmail);
    } catch (e) {
      debugPrint('Error reading user email: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Check if token is expiring soon (within 5 minutes)
  Future<bool> isTokenExpiringSoon() async {
    try {
      final expiryStr = await _secureStorage.read(key: _keyTokenExpiry);
      if (expiryStr == null) return true;
      
      final expiry = DateTime.parse(expiryStr);
      final now = DateTime.now();
      final timeUntilExpiry = expiry.difference(now);
      
      // Refresh if expires within 5 minutes
      return timeUntilExpiry.inMinutes < 5;
    } catch (e) {
      debugPrint('Error checking token expiry: $e');
      return true; // Assume expiring to trigger refresh
    }
  }

  /// Sign in with email and magic link
  Future<bool> signInWithMagicLink(String email) async {
    try {
      // Don't change global auth state - let the UI handle loading
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
        await _saveSession(response.session!);
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
  /// Uses Supabase's signUp which auto-confirms when email confirmation is disabled
  /// or uses a known test password for existing users
  ///
  /// WARNING: Only use this for development testing!
  ///
  /// REQUIRES: In Supabase Dashboard > Authentication > Providers > Email:
  /// - Set "Confirm email" to DISABLED for this to work
  Future<bool> devSignInWithEmail(String email) async {
    try {
      _updateAuthState(AuthState.loading);

      // Use a deterministic password based on email for dev testing
      final devPassword = 'DevPass_${email.hashCode.abs()}_2024!';

      debugPrint('🔧 [DEV] Attempting dev sign-in for $email');
      debugPrint('🔧 [DEV] Using password: $devPassword');

      // First try to sign in (for existing users)
      try {
        debugPrint('🔧 [DEV] Trying signInWithPassword...');
        final signInResponse = await _supabase!.auth.signInWithPassword(
          email: email,
          password: devPassword,
        );

        if (signInResponse.session != null) {
          await _saveSession(signInResponse.session!);
          _updateAuthState(AuthState.authenticated);
          debugPrint('✅ [DEV] Signed in existing user: $email');
          return true;
        }
        debugPrint('⚠️ [DEV] SignIn returned null session');
      } on AuthException catch (signInError) {
        debugPrint('ℹ️ [DEV] Sign-in failed: ${signInError.message}');
        debugPrint('ℹ️ [DEV] Trying sign-up...');
      }

      // If sign-in fails, try to sign up (for new users)
      try {
        debugPrint('🔧 [DEV] Trying signUp...');
        final signUpResponse = await _supabase!.auth.signUp(
          email: email,
          password: devPassword,
          data: {'dev_mode': true},
        );

        debugPrint('🔧 [DEV] SignUp result - user: ${signUpResponse.user?.id}, hasSession: ${signUpResponse.session != null}');

        if (signUpResponse.session != null) {
          await _saveSession(signUpResponse.session!);
          _updateAuthState(AuthState.authenticated);
          debugPrint('✅ [DEV] Created and signed in new user: $email');
          return true;
        } else if (signUpResponse.user != null) {
          // User created but no session - email confirmation is ENABLED in Supabase
          debugPrint('⚠️ [DEV] User created but no session - EMAIL CONFIRMATION IS ENABLED');
          debugPrint('⚠️ [DEV] To fix: Go to Supabase Dashboard > Authentication > Providers > Email');
          debugPrint('⚠️ [DEV] Set "Confirm email" to DISABLED');

          // Still try to sign in (might work if user was previously confirmed)
          try {
            debugPrint('🔧 [DEV] Trying signIn after signup...');
            final retryResponse = await _supabase!.auth.signInWithPassword(
              email: email,
              password: devPassword,
            );

            if (retryResponse.session != null) {
              await _saveSession(retryResponse.session!);
              _updateAuthState(AuthState.authenticated);
              debugPrint('✅ [DEV] Signed in after signup: $email');
              return true;
            }
          } on AuthException catch (retryError) {
            debugPrint('❌ [DEV] Retry sign-in failed: ${retryError.message}');
          }
        }
      } on AuthException catch (signUpError) {
        debugPrint('❌ [DEV] Sign-up failed: ${signUpError.message}');

        // Check if user exists with different password (e.g., created via OTP before)
        if (signUpError.message.contains('already registered') ||
            signUpError.message.contains('already been registered')) {
          debugPrint('ℹ️ [DEV] User exists - may need to confirm email or use different password');
        }
      }

      _updateAuthState(AuthState.unauthenticated);
      debugPrint('❌ [DEV] Dev sign-in failed for $email');
      debugPrint('💡 [DEV] TIP: Disable "Confirm email" in Supabase Dashboard');
      return false;
    } catch (e) {
      debugPrint('❌ [DEV] Dev sign-in error: $e');
      _updateAuthState(AuthState.unauthenticated);
      return false;
    }
  }

  /// Development sign-in with detailed logs returned for UI display
  /// Same as devSignInWithEmail but returns logs for debug overlay
  ///
  /// Returns: {'success': bool, 'logs': List<String>}
  Future<Map<String, dynamic>> devSignInWithEmailWithLogs(String email) async {
    final logs = <String>[];

    void log(String message) {
      logs.add(message);
      debugPrint(message);
    }

    try {
      _updateAuthState(AuthState.loading);

      final devPassword = 'DevPass_${email.hashCode.abs()}_2024!';

      log('Starting dev sign-in for $email');
      log('Password: $devPassword');

      // First try to sign in (for existing users)
      try {
        log('Trying signInWithPassword...');
        final signInResponse = await _supabase!.auth.signInWithPassword(
          email: email,
          password: devPassword,
        );

        if (signInResponse.session != null) {
          await _saveSession(signInResponse.session!);
          _updateAuthState(AuthState.authenticated);
          log('SUCCESS: Signed in existing user');
          log('User ID: ${signInResponse.session!.user.id}');
          return {'success': true, 'logs': logs};
        }
        log('signInWithPassword returned null session');
      } on AuthException catch (signInError) {
        log('signIn failed: ${signInError.message}');
        log('statusCode: ${signInError.statusCode}');
      }

      // If sign-in fails, try to sign up (for new users)
      try {
        log('Trying signUp...');
        final signUpResponse = await _supabase!.auth.signUp(
          email: email,
          password: devPassword,
          data: {'dev_mode': true},
        );

        log('signUp result:');
        log('  user id: ${signUpResponse.user?.id}');
        log('  hasSession: ${signUpResponse.session != null}');
        log('  email confirmed: ${signUpResponse.user?.emailConfirmedAt}');

        if (signUpResponse.session != null) {
          await _saveSession(signUpResponse.session!);
          _updateAuthState(AuthState.authenticated);
          log('SUCCESS: Created and signed in new user');
          return {'success': true, 'logs': logs};
        } else if (signUpResponse.user != null) {
          log('WARNING: User created but NO SESSION');
          log('This means EMAIL CONFIRMATION is ENABLED in Supabase');
          log('Fix: Supabase Dashboard > Auth > Providers > Email');
          log('     Set "Confirm email" to DISABLED');

          // Try to sign in again
          try {
            log('Retrying signIn after signup...');
            final retryResponse = await _supabase!.auth.signInWithPassword(
              email: email,
              password: devPassword,
            );

            if (retryResponse.session != null) {
              await _saveSession(retryResponse.session!);
              _updateAuthState(AuthState.authenticated);
              log('SUCCESS: Signed in after signup');
              return {'success': true, 'logs': logs};
            }
            log('Retry also returned null session');
          } on AuthException catch (retryError) {
            log('Retry signIn failed: ${retryError.message}');
          }
        }
      } on AuthException catch (signUpError) {
        log('signUp failed: ${signUpError.message}');
        log('statusCode: ${signUpError.statusCode}');

        if (signUpError.message.contains('already registered') ||
            signUpError.message.contains('already been registered')) {
          log('User exists with different password');
          log('Calling API to update password...');

          // User was created via OTP - call API to update password
          final updated = await _updatePasswordViaApi(email, devPassword, log);

          if (updated) {
            log('Password updated, retrying signIn...');
            try {
              final retryResponse = await _supabase!.auth.signInWithPassword(
                email: email,
                password: devPassword,
              );

              if (retryResponse.session != null) {
                await _saveSession(retryResponse.session!);
                _updateAuthState(AuthState.authenticated);
                log('SUCCESS: Signed in after password update');
                log('User ID: ${retryResponse.session!.user.id}');
                return {'success': true, 'logs': logs};
              }
              log('signIn after password update returned null session');
            } on AuthException catch (retryError) {
              log('signIn after password update failed: ${retryError.message}');
            }
          }
        }
      }

      _updateAuthState(AuthState.unauthenticated);
      log('FAILED: Dev sign-in unsuccessful');
      return {'success': false, 'logs': logs};
    } catch (e) {
      log('ERROR: $e');
      _updateAuthState(AuthState.unauthenticated);
      return {'success': false, 'logs': logs};
    }
  }

  /// Call API to update user password for existing OTP users
  /// Only used in dev mode when sign-in fails because user was created via OTP
  Future<bool> _updatePasswordViaApi(
    String email,
    String password,
    void Function(String) log,
  ) async {
    try {
      final apiUrl = SupabaseConfig.apiUrl;
      log('API URL: $apiUrl');

      final response = await http.post(
        Uri.parse('$apiUrl/api/dev/update-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      log('API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log('Password updated for user: ${data['userId']}');
        return true;
      } else {
        final error = jsonDecode(response.body);
        log('API error: ${error['error']}');
        if (error['details'] != null) {
          log('Details: ${error['details']}');
        }
        return false;
      }
    } catch (e) {
      log('API call failed: $e');
      return false;
    }
  }

  /// Sign in with Apple
  ///
  /// Returns a map with 'success' bool and optional 'displayName' if provided by Apple
  /// Apple only provides name on first sign-in, so we capture it for profile setup
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      _updateAuthState(AuthState.loading);

      // Generate a random nonce for security
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      // Request Apple credentials
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

      // Extract display name if provided (only on first sign-in)
      String? displayName;
      if (credential.givenName != null || credential.familyName != null) {
        final parts = [credential.givenName, credential.familyName]
            .where((p) => p != null && p.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          displayName = parts.join(' ');
          debugPrint('📝 Apple provided name: $displayName');
        }
      }

      // Sign in to Supabase using the Apple ID token
      final response = await _supabase!.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.session != null) {
        await _saveSession(response.session!);
        _updateAuthState(AuthState.authenticated);
        debugPrint('✅ Apple Sign-In successful');

        // If Apple provided a name, update the user metadata
        if (displayName != null) {
          await updateDisplayName(displayName);
        }

        return {
          'success': true,
          'displayName': displayName,
        };
      }

      debugPrint('❌ Apple Sign-In: No session received from Supabase');
      _updateAuthState(AuthState.unauthenticated);
      return {'success': false};
    } on SignInWithAppleAuthorizationException catch (e) {
      // User cancelled or other Apple-specific error
      debugPrint('⚠️ Apple Sign-In cancelled or failed: ${e.code} - ${e.message}');
      _updateAuthState(AuthState.unauthenticated);
      return {'success': false, 'cancelled': e.code == AuthorizationErrorCode.canceled};
    } catch (e) {
      debugPrint('❌ Apple Sign-In error: $e');
      _updateAuthState(AuthState.unauthenticated);
      return {'success': false};
    }
  }

  /// Generate a cryptographically secure nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Refresh access token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _keyRefreshToken);
      
      if (refreshToken == null) {
        debugPrint('⚠️ No refresh token available');
        await signOut();
        return false;
      }
      
      debugPrint('🔄 Refreshing access token...');
      
      final response = await _supabase!.auth.refreshSession();
      
      if (response.session != null) {
        await _saveSession(response.session!);
        debugPrint('✅ Token refreshed successfully');
        return true;
      }
      
      debugPrint('❌ Token refresh failed - no session');
      await signOut();
      return false;
    } catch (e) {
      debugPrint('❌ Token refresh error: $e');
      
      // If refresh fails, sign out user
      await signOut();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase!.auth.signOut();
      await _clearSession();
      _updateAuthState(AuthState.unauthenticated);
      debugPrint('✅ Signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      // Clear session anyway
      await _clearSession();
      _updateAuthState(AuthState.unauthenticated);
    }
  }

  /// Create Authorization header for API requests
  Future<Map<String, String>> getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Get JWT token (if available)
    final token = await getAccessToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // In development mode, add X-Dev-User-Id header for auth bypass
    // Only set if we cached a dev user ID (i.e., we're on simulator/web, not physical device)
    final devUserId = _getDevUserId();
    if (devUserId != null) {
      headers['X-Dev-User-Id'] = devUserId;
      debugPrint('🔧 [DEV] Adding X-Dev-User-Id header: $devUserId');
    }

    return headers;
  }

  /// Get cached development user ID (sync, for use in getAuthHeaders)
  /// Returns user1_id (TestiY) for primary device, user2_id (Jokke) for secondary
  String? _getDevUserId() {
    return _cachedDevUserId;
  }

  /// Determine development user ID based on platform and device
  /// Called once at initialization to cache the result
  ///
  /// Device mapping:
  /// - Android emulator / Joakim's iPhone 14 → TestiY (devUserIdAndroid)
  /// - Web/Chrome / Onni's iPhone 12 → Jokke (devUserIdWeb)
  Future<String?> _determineDevUserId() async {
    // Check if running on Web (Chrome)
    if (kIsWeb) {
      final userId = DevConfig.devUserIdWeb;
      if (userId.contains('REPLACE_WITH')) {
        debugPrint('⚠️ [DEV] devUserIdWeb not configured in DevConfig');
        return null;
      }
      debugPrint('🔧 [DEV] Web platform → using Jokke (devUserIdWeb)');
      return userId;
    }

    // Check iOS device model to determine which user
    if (!kIsWeb && Platform.isIOS) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        final deviceName = iosInfo.name;
        final deviceModel = iosInfo.utsname.machine; // e.g., "iPhone13,2" for iPhone 12
        debugPrint('🔧 [DEV] iOS device: name=$deviceName, model=$deviceModel');

        // iPhone 12 models: iPhone13,1 (mini), iPhone13,2 (regular), iPhone13,3 (Pro), iPhone13,4 (Pro Max)
        // iPhone 14 models: iPhone14,7 (regular), iPhone14,8 (Plus), iPhone15,2 (Pro), iPhone15,3 (Pro Max)
        // Use iPhone 12 (iPhone13,x) for Jokke (the partner)
        if (deviceModel.startsWith('iPhone13,')) {
          debugPrint('🔧 [DEV] iPhone 12 detected → using Jokke (devUserIdWeb)');
          return DevConfig.devUserIdWeb;
        }

        // Also check device name as fallback
        if (deviceName.toLowerCase().contains('onni') ||
            deviceName.toLowerCase().contains('12')) {
          debugPrint('🔧 [DEV] Onni\'s device or iPhone 12 → using Jokke (devUserIdWeb)');
          return DevConfig.devUserIdWeb;
        }

        // iPhone 14 and others get TestiY
        debugPrint('🔧 [DEV] Primary iOS device → using TestiY (devUserIdAndroid)');
        return DevConfig.devUserIdAndroid;
      } catch (e) {
        debugPrint('⚠️ [DEV] Could not get iOS device info: $e');
      }
    }

    // Default to Android user ID for Android and fallback
    final userId = DevConfig.devUserIdAndroid;
    if (userId.contains('REPLACE_WITH')) {
      debugPrint('⚠️ [DEV] devUserIdAndroid not configured in DevConfig');
      return null;
    }
    return userId;
  }

  /// Get current user's display name from Supabase metadata
  ///
  /// Returns null if user is not authenticated or has no name set
  Future<String?> getDisplayName() async {
    try {
      if (_supabase == null) return null;

      final user = _supabase!.auth.currentUser;
      if (user == null) return null;

      final metadata = user.userMetadata;
      if (metadata == null) return null;

      final fullName = metadata['full_name'] as String?;
      return (fullName != null && fullName.isNotEmpty) ? fullName : null;
    } catch (e) {
      debugPrint('Error getting display name: $e');
      return null;
    }
  }

  /// Update user's display name in Supabase metadata
  ///
  /// This syncs the local name to Supabase so other users can see it
  Future<bool> updateDisplayName(String name) async {
    try {
      if (_supabase == null) {
        debugPrint('❌ Supabase not initialized');
        return false;
      }

      final response = await _supabase!.auth.updateUser(
        UserAttributes(
          data: {'full_name': name},
        ),
      );

      if (response.user != null) {
        debugPrint('✅ Display name updated to: $name');
        return true;
      }

      debugPrint('❌ Failed to update display name');
      return false;
    } catch (e) {
      debugPrint('❌ Error updating display name: $e');
      return false;
    }
  }

  /// Handle API 401 responses (unauthorized)
  /// 
  /// Call this when you receive a 401 from the API
  /// Returns true if token was refreshed successfully
  Future<bool> handleUnauthorized() async {
    debugPrint('🔐 Handling 401 - attempting token refresh');
    return await refreshToken();
  }

  // Private methods

  void _updateAuthState(AuthState newState) {
    _authState = newState;
    _authStateController.add(newState);
  }

  void _handleAuthStateChange(AuthChangeEvent event, Session? session) {
    debugPrint('🔐 Auth state changed: $event');
    
    switch (event) {
      case AuthChangeEvent.signedIn:
        if (session != null) {
          _saveSession(session);
          _updateAuthState(AuthState.authenticated);
        }
        break;
      case AuthChangeEvent.signedOut:
        _clearSession();
        _updateAuthState(AuthState.unauthenticated);
        break;
      case AuthChangeEvent.tokenRefreshed:
        if (session != null) {
          _saveSession(session);
          _updateAuthState(AuthState.authenticated);
        }
        break;
      case AuthChangeEvent.userUpdated:
        if (session != null) {
          _saveSession(session);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _saveSession(Session session) async {
    try {
      // Save tokens
      await _secureStorage.write(
        key: _keyAccessToken,
        value: session.accessToken,
      );
      
      await _secureStorage.write(
        key: _keyRefreshToken,
        value: session.refreshToken,
      );
      
      // Calculate and save expiry
      final expiresAt = DateTime.now().add(
        Duration(seconds: session.expiresIn ?? 3600),
      );
      await _secureStorage.write(
        key: _keyTokenExpiry,
        value: expiresAt.toIso8601String(),
      );
      
      // Save user info
      if (session.user != null) {
        await _secureStorage.write(
          key: _keyUserId,
          value: session.user!.id,
        );
        
        await _secureStorage.write(
          key: _keyUserEmail,
          value: session.user!.email ?? '',
        );
      }
      
      debugPrint('✅ Session saved securely');
    } catch (e) {
      debugPrint('❌ Error saving session: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: _keyTokenExpiry);
      await _secureStorage.delete(key: _keyUserId);
      await _secureStorage.delete(key: _keyUserEmail);
      
      debugPrint('✅ Session cleared');
    } catch (e) {
      debugPrint('❌ Error clearing session: $e');
    }
  }

  Future<void> _restoreSession() async {
    try {
      final accessToken = await _secureStorage.read(key: _keyAccessToken);
      final storedRefreshToken = await _secureStorage.read(key: _keyRefreshToken);

      if (accessToken == null || storedRefreshToken == null) {
        debugPrint('ℹ️ No saved session found');
        _updateAuthState(AuthState.unauthenticated);
        return;
      }
      
      // Check if token is expired
      if (await isTokenExpiringSoon()) {
        debugPrint('🔄 Token expiring soon, refreshing...');
        final refreshed = await refreshToken();
        
        if (refreshed) {
          _updateAuthState(AuthState.authenticated);
        } else {
          _updateAuthState(AuthState.unauthenticated);
        }
      } else {
        debugPrint('✅ Session restored from storage');
        _updateAuthState(AuthState.authenticated);
      }
    } catch (e) {
      debugPrint('❌ Error restoring session: $e');
      _updateAuthState(AuthState.unauthenticated);
    }
  }

  void _startRefreshTimer() {
    // Cancel existing timer
    _refreshTimer?.cancel();
    
    // Check for token expiry every 60 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (timer) async {
        if (_authState == AuthState.authenticated) {
          if (await isTokenExpiringSoon()) {
            debugPrint('🔄 Token expiring soon - refreshing in background');
            await refreshToken();
          }
        }
      },
    );
    
    debugPrint('✅ Background refresh timer started');
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _authStateController.close();
  }
}
