# Flutter Authentication Service Documentation

**Issue #6: AUTH-202**

Complete authentication service for Flutter with secure token storage, background refresh, and API integration.

---

## 🎯 Overview

### What This Provides

1. **Secure Token Storage** - flutter_secure_storage for iOS/Android keychain
2. **Background Token Refresh** - Automatic refresh 5 minutes before expiry
3. **Supabase Integration** - Magic link authentication
4. **API Client** - Automatic JWT token inclusion in requests
5. **Auto-retry Logic** - Handles 401/429 responses gracefully

---

## 📦 Dependencies Added

```yaml
# pubspec.yaml
dependencies:
  http: ^1.1.0
  connectivity_plus: ^5.0.2
  flutter_secure_storage: ^9.0.0
  supabase_flutter: ^2.8.0
  jwt_decoder: ^2.0.1
```

**Install:**
```bash
cd app
flutter pub get
```

---

## 🔐 AuthService

### Initialization

```dart
import 'package:togetherremind/services/auth_service.dart';

// In main() or app initialization
await AuthService().initialize(
  supabaseUrl: 'https://xxxxx.supabase.co',
  supabaseAnonKey: 'your-anon-key',
);
```

### Authentication Flow

**1. Sign In with Magic Link**
```dart
final authService = AuthService();

// Send magic link to email
final success = await authService.signInWithMagicLink(
  'user@example.com',
);

if (success) {
  // Show "Check your email" message
  print('Magic link sent!');
}
```

**2. Verify OTP from Email**
```dart
// User clicks link and gets OTP code
final verified = await authService.verifyOTP(
  email: 'user@example.com',
  token: '123456', // OTP from email
);

if (verified) {
  // User is now authenticated
  print('Authenticated!');
}
```

### Auth State Management

```dart
// Listen to auth state changes
AuthService().authStateStream.listen((state) {
  switch (state) {
    case AuthState.authenticated:
      // Navigate to home screen
      break;
    case AuthState.unauthenticated:
      // Navigate to login screen
      break;
    case AuthState.loading:
      // Show loading indicator
      break;
    case AuthState.initial:
      // Initial state
      break;
  }
});

// Check current auth state
if (AuthService().isAuthenticated) {
  print('User is logged in');
}
```

### Token Management

```dart
// Get access token
final token = await AuthService().getAccessToken();

// Get user info
final userId = await AuthService().getUserId();
final email = await AuthService().getUserEmail();

// Check if token is expiring soon
if (await AuthService().isTokenExpiringSoon()) {
  print('Token will expire soon');
}

// Manually refresh token
final refreshed = await AuthService().refreshToken();
```

### Sign Out

```dart
await AuthService().signOut();
// User is now unauthenticated, tokens cleared
```

---

## 🌐 API Client

### Configuration

```dart
import 'package:togetherremind/services/api_client.dart';

// Configure API base URL
ApiClient().configure(
  baseUrl: 'https://your-api.vercel.app',
);
```

### Making Requests

**1. GET Request**
```dart
final response = await ApiClient().get<Map<String, dynamic>>(
  '/api/sync/daily-quests',
  queryParams: {'date': '2025-11-19'},
);

if (response.success) {
  print('Data: ${response.data}');
} else {
  print('Error: ${response.error}');
}
```

**2. POST Request**
```dart
final response = await ApiClient().post<Map<String, dynamic>>(
  '/api/sync/love-points',
  body: {
    'awards': [
      {
        'id': 'uuid-here',
        'amount': 30,
        'reason': 'Quest completion',
        'related_id': 'quest-123',
      }
    ],
    'last_sync_timestamp': DateTime.now().toIso8601String(),
  },
);

if (response.success) {
  print('Synced: ${response.data}');
}
```

**3. With Custom Parser**
```dart
class Quest {
  final String id;
  final String title;
  
  Quest({required this.id, required this.title});
  
  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: json['id'],
      title: json['title'],
    );
  }
}

final response = await ApiClient().get<List<Quest>>(
  '/api/sync/daily-quests',
  parser: (json) {
    final quests = json['quests'] as List;
    return quests.map((q) => Quest.fromJson(q)).toList();
  },
);
```

### Automatic Features

**1. JWT Token Inclusion**
- Automatically adds `Authorization: Bearer <token>` header
- No manual token management needed

**2. 401 Handling (Token Expired)**
```dart
// API returns 401 → Auto-refresh token → Retry request
final response = await ApiClient().get('/api/protected-endpoint');

// You don't need to handle 401 manually!
// ApiClient automatically:
// 1. Detects 401
// 2. Refreshes token
// 3. Retries the original request
```

**3. 429 Handling (Rate Limited)**
```dart
// API returns 429 → Returns error with retry-after info
final response = await ApiClient().post('/api/auth/verify');

if (!response.success) {
  // "Rate limit exceeded - retry after 45 seconds"
  print(response.error);
}
```

---

## 🔄 Background Token Refresh

### How It Works

```
Every 60 seconds:
  ↓
Check if token expires within 5 minutes
  ↓
If yes: Refresh token automatically
  ↓
Continue checking
```

**Benefits:**
- User never experiences auth failures
- Seamless experience across app sessions
- Handles long app sessions (hours)

**Implementation:**
```dart
// Starts automatically in AuthService.initialize()
// Timer checks every 60 seconds
// Refreshes if expiry < 5 minutes

// No manual intervention needed!
```

---

## 💾 Secure Token Storage

### What's Stored

| Key | Value | Purpose |
|-----|-------|---------|
| `supabase_access_token` | JWT token | API authentication |
| `supabase_refresh_token` | Refresh token | Token renewal |
| `supabase_token_expiry` | ISO timestamp | Expiry tracking |
| `supabase_user_id` | UUID | User identification |
| `supabase_user_email` | Email | User info |

### Storage Location

- **iOS:** Keychain (encrypted)
- **Android:** EncryptedSharedPreferences (AES-256)
- **Secure:** Only this app can access the tokens

### Session Persistence

```dart
// Session is automatically restored on app restart
await AuthService().initialize(...);

// If valid token exists:
// → AuthState.authenticated

// If token expired:
// → Auto-refresh → AuthState.authenticated

// If refresh fails:
// → AuthState.unauthenticated
```

---

## 🧪 Testing

### Manual Testing

```dart
// 1. Test sign in
void testSignIn() async {
  final result = await AuthService().signInWithMagicLink(
    'test@example.com',
  );
  
  print('Magic link sent: $result');
}

// 2. Test OTP verification
void testVerifyOTP() async {
  final result = await AuthService().verifyOTP(
    email: 'test@example.com',
    token: '123456',
  );
  
  print('Verified: $result');
}

// 3. Test API request
void testApiRequest() async {
  final response = await ApiClient().get('/api/health');
  
  print('Health check: ${response.success}');
  print('Data: ${response.data}');
}

// 4. Test token refresh
void testRefresh() async {
  final result = await AuthService().refreshToken();
  
  print('Token refreshed: $result');
}

// 5. Test 401 handling
void test401Handling() async {
  // Make request with expired token
  // Should automatically refresh and retry
  final response = await ApiClient().get('/api/auth/verify');
  
  print('Response: ${response.success}');
}
```

### Integration Testing

```dart
// test/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherremind/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('should initialize successfully', () async {
      await AuthService().initialize(
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: 'test-key',
      );
      
      expect(AuthService().authState, AuthState.initial);
    });
    
    test('should handle sign in', () async {
      final result = await AuthService().signInWithMagicLink(
        'test@example.com',
      );
      
      expect(result, isTrue);
    });
  });
}
```

---

## 🚨 Error Handling

### Auth Errors

```dart
try {
  await AuthService().signInWithMagicLink('invalid-email');
} catch (e) {
  // Handle error
  print('Auth error: $e');
}
```

### API Errors

```dart
final response = await ApiClient().get('/api/endpoint');

if (!response.success) {
  switch (response.error) {
    case 'No internet connection':
      // Show offline message
      break;
    case 'Rate limit exceeded':
      // Show rate limit message
      break;
    case 'Authentication failed':
      // Redirect to login
      break;
    default:
      // Show generic error
      break;
  }
}
```

### Network Errors

```dart
// ApiClient automatically handles:
// - SocketException (no internet)
// - HttpException (HTTP errors)
// - Timeout (if configured)

// Returns ApiResponse.error() with descriptive message
```

---

## 🔧 Configuration

### Environment-Specific URLs

```dart
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://your-api-staging.vercel.app',
  );
  
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xxxxx.supabase.co',
  );
}

// Usage
ApiClient().configure(baseUrl: AppConfig.apiBaseUrl);
```

### Flutter Run with Environment

```bash
# Staging
flutter run --dart-define=API_BASE_URL=https://api-staging.vercel.app

# Production
flutter run --dart-define=API_BASE_URL=https://api.vercel.app
```

---

## 📱 Platform-Specific Setup

### iOS Configuration

**Add to `ios/Runner/Info.plist`:**
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>togetherremind</string>
    </array>
  </dict>
</array>
```

### Android Configuration

**Add to `android/app/src/main/AndroidManifest.xml`:**
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data
    android:scheme="togetherremind"
    android:host="auth-callback" />
</intent-filter>
```

---

## 📚 Related Documentation

- [JWT Middleware](../api/AUTH_MIDDLEWARE.md) - Backend authentication
- [API README](../api/README.md) - API setup
- [Migration Plan](../docs/MIGRATION_TO_NEXTJS_POSTGRES.md) - Overall architecture

---

## ✅ Checklist

**Issue #6 Acceptance Criteria:**
- [x] AuthService with secure storage implemented
- [x] Background token refresh functional
- [x] Local JWT expiry detection working
- [x] Authentication error handling complete
- [x] API client with auto-retry implemented
- [x] Cross-device token sync supported (via Supabase)
- [x] Documentation complete

**Status:** ✅ Production Ready
