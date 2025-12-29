# API Client

## Quick Reference

| Item | Location |
|------|----------|
| API Client | `lib/services/api_client.dart` |
| Auth Service | `lib/services/auth_service.dart` |
| Supabase Config | `lib/config/supabase_config.dart` |
| Dev Config | `lib/config/dev_config.dart` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       ApiClient (Singleton)                      │
│                                                                  │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│   │  JWT Token   │    │  401 Retry   │    │  Rate Limiting   │  │
│   │  (auto)      │    │  (auto)      │    │  (429 handling)  │  │
│   └──────────────┘    └──────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    https://api-joakim-achrens-projects.vercel.app
```

---

## Usage

### Basic Requests
```dart
final client = ApiClient();

// GET request
final response = await client.get('/api/sync/daily-quests');

// POST request
final response = await client.post('/api/sync/game/classic/play', body: {
  'localDate': '2024-12-16',
});

// Check response
if (response.success) {
  final data = response.data;
} else {
  final error = response.error;
}
```

### With Parser
```dart
final response = await client.get<UserProfile>(
  '/api/users/profile',
  parser: (json) => UserProfile.fromJson(json),
);

if (response.success && response.data != null) {
  final profile = response.data!;
}
```

---

## Key Rules

### 1. Configure on Startup
Configure API client in main.dart:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ApiClient().configure(
    baseUrl: 'https://api-joakim-achrens-projects.vercel.app',
  );

  runApp(MyApp());
}
```

### 2. Automatic Auth Headers
API client automatically adds auth headers:

```dart
// AuthService.getAuthHeaders() returns:
{
  'Content-Type': 'application/json',
  'Authorization': 'Bearer <jwt-token>',  // If logged in
  'X-Dev-User-Id': '<dev-user-id>',       // If dev mode
}
```

### 3. Automatic 401 Retry
On 401, client attempts token refresh and retry:

```dart
// Happens automatically:
// 1. Request returns 401
// 2. Call authService.refreshToken()
// 3. Retry original request with new token
// 4. If still 401, sign out user
```

### 4. Dev Auth Bypass
In development, X-Dev-User-Id header bypasses JWT:

```dart
// Set in dev_config.dart
static const String devUserIdAndroid = 'cd6373bd-...';
static const String devUserIdWeb = '0de0c1eb-...';

// Header only added if no JWT token present
if (devUserId != null && token == null) {
  headers['X-Dev-User-Id'] = devUserId;
}
```

---

## Response Handling

### ApiResponse Structure
```dart
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;
}
```

### Success Check
```dart
final response = await client.get('/api/endpoint');

if (response.success) {
  // Use response.data
} else {
  // Handle response.error
}
```

### Typed Responses
```dart
final response = await client.get<List<Quest>>(
  '/api/sync/daily-quests',
  parser: (json) => (json['quests'] as List)
    .map((q) => Quest.fromJson(q))
    .toList(),
);
```

---

## Common Bugs & Fixes

### 1. "Not authenticated" Error
**Symptom:** API returns 401 even with valid session.

**Cause:** Token not included in request.

**Fix:** Check auth headers:
```dart
final headers = await _authService.getAuthHeaders();
debugPrint('Headers: $headers');
```

### 2. Wrong Base URL
**Symptom:** Network errors or wrong API responses.

**Cause:** Using localhost in production or vice versa.

**Fix:** Check configuration:
```dart
debugPrint('API base: ${ApiClient()._baseUrl}');
```

### 3. Request Timeout
**Symptom:** Requests hang indefinitely.

**Cause:** No timeout configured.

**Fix:** Add timeout:
```dart
http.get(uri, headers: headers)
  .timeout(const Duration(seconds: 30));
```

---

## API Endpoints

### Auth & Users
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/users/signup` | POST | Complete signup |
| `/api/users/profile` | GET | Get user profile |
| `/api/users/profile` | PUT | Update profile |

### Games
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/sync/game/{type}/play` | POST | Start/submit game |
| `/api/sync/linked` | POST | Get Linked match |
| `/api/sync/linked/submit` | POST | Submit Linked turn |
| `/api/sync/word-search` | POST | Get Word Search match |
| `/api/sync/word-search/submit` | POST | Submit Word Search word |

### Data Sync
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/sync/daily-quests` | GET/POST | Quest sync |
| `/api/sync/love-points` | GET/POST | LP sync |
| `/api/sync/steps` | POST | Steps sync |
| `/api/unlocks` | GET | Get unlock state |
| `/api/unlocks/complete` | POST | Notify completion |

---

## File Reference

| File | Purpose |
|------|---------|
| `api_client.dart` | HTTP client with auth |
| `auth_service.dart` | Token management |
| `supabase_config.dart` | API URL config |
| `dev_config.dart` | Dev bypass settings |
