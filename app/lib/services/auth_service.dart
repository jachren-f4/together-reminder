import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/dev_config.dart';

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
      // Also cache in release mode if allowAuthBypassInRelease is enabled
      final canBypass = kDebugMode || DevConfig.allowAuthBypassInRelease;
      if (canBypass && DevConfig.skipAuthInDev) {
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

    // In development mode (or with allowAuthBypassInRelease), add X-Dev-User-Id header for auth bypass
    // This allows testing with different users on different devices
    final canBypass = kDebugMode || DevConfig.allowAuthBypassInRelease;
    if (canBypass && DevConfig.skipAuthInDev) {
      final devUserId = _getDevUserId();
      if (devUserId != null) {
        headers['X-Dev-User-Id'] = devUserId;
        debugPrint('🔧 [DEV] Adding X-Dev-User-Id header: $devUserId');
      }
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
