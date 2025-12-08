# Plan: Server-Side Auth & Onboarding Refactor

**Goal:** Move user profile creation from client to server, eliminating the dual-ID problem and ensuring proper client/server separation.

**Status:** IN PROGRESS

---

## Current Problems

### 1. Client-Side User ID Generation
**File:** `app/lib/screens/name_entry_screen.dart:56-69`

User ID generated with `Uuid().v4()` before Supabase auth creates its own ID, causing mismatch between local storage and server.

### 2. User Created Before Authentication
User saved to Hive storage regardless of auth status, creating orphaned local users and ID mismatches.

### 3. Client Constructs Partner Object
Partner model constructed client-side from API fragments instead of deserializing complete server response.

### 4. Dual ID System with Fallback
Code has `authUserId ?? user?.id` fallback pattern, indicating broken trust in ID sources.

### 5. Missing Server Endpoint for Profile Creation
No endpoint creates user profile data after OTP verification.

---

## Key Decisions

| Item | Decision |
|------|----------|
| User ID generation | Server-side only (from Supabase auth) |
| User profile creation | `POST /api/user/complete-signup` after OTP |
| Name update | `PATCH /api/user/name` |
| Push token sync | Part of `completeSignup()` + separate update endpoint |
| Partner model | `Partner.fromJson()` from API response |
| Partner name polling | Keep current `getStatus()` approach |
| Existing couple restore | `completeSignup()` checks and returns couple + partner |
| Couple initialization | Server-side in pairing endpoints |
| Multi-device support | Full state returned from `completeSignup()` |
| Unpairing | Not exposed in app UI, support-only process |

---

## Implementation Phases

### Phase 1: API Endpoints for User Profile

Create server-side endpoints for user profile management.

#### Step 1.1: Create `POST /api/user/complete-signup`

**File:** `api/app/api/user/complete-signup/route.ts` (NEW)

**Functionality:**
- Extract user ID and email from JWT
- Check if user is already in a couple (returning user)
- Fetch partner info if couple exists
- Accept optional push token in request body
- Save push token to `user_push_tokens` table if provided
- Return complete user state:
  ```json
  {
    "user": { "id", "email", "name", "createdAt" },
    "couple": { "id", "createdAt" } | null,
    "partner": { "id", "name", "email", "avatarEmoji" } | null
  }
  ```
- **Idempotent:** Safe to call multiple times

#### Step 1.2: Create `PATCH /api/user/name`

**File:** `api/app/api/user/name/route.ts` (NEW)

**Functionality:**
- Validate name (non-empty, reasonable length)
- Update `auth.users` metadata (`full_name`)
- Return updated user object

#### Step 1.3: Create `POST /api/user/push-token`

**File:** `api/app/api/user/push-token/route.ts` (NEW)

**Functionality:**
- Accept `{ token, platform }` in body
- Upsert to `user_push_tokens` table
- Return success

#### Step 1.4: Create `GET /api/user/profile`

**File:** `api/app/api/user/profile/route.ts` (NEW)

**Functionality:**
- Fetch user from `auth.users`
- Fetch push token from `user_push_tokens`
- Check couple status
- Return same format as `complete-signup`

#### Phase 1 Testing
- [ ] Call `complete-signup` with new user → returns user, no couple
- [ ] Call `complete-signup` with existing user (no couple) → returns same user
- [ ] Call `complete-signup` with user in couple → returns user + couple + partner
- [ ] Call `name` endpoint → updates `auth.users` metadata
- [ ] Call `push-token` endpoint → creates/updates `user_push_tokens` row
- [ ] Call `profile` endpoint → returns full state

---

### Phase 2: Flutter User Profile Service

Create Flutter service to interact with new API endpoints.

#### Step 2.1: Create `UserProfileService`

**File:** `app/lib/services/user_profile_service.dart` (NEW)

```dart
class UserProfileService {
  /// Complete signup after OTP verification
  /// Returns User and optionally restores couple/partner
  Future<SignupResult> completeSignup({String? pushToken});

  /// Update user's display name
  Future<User> updateName(String name);

  /// Sync push token to server
  Future<void> syncPushToken(String token, String platform);

  /// Get full profile from server (for device switching)
  Future<SignupResult> getProfile();
}

class SignupResult {
  final User user;
  final String? coupleId;
  final Partner? partner;
}
```

#### Step 2.2: Integrate with `ApiClient`

Ensure `UserProfileService` uses existing `ApiClient` for auth headers.

#### Phase 2 Testing
- [ ] `completeSignup()` creates User in Hive with server-provided ID
- [ ] `completeSignup()` with existing couple restores Partner in Hive
- [ ] `updateName()` updates both server and local storage
- [ ] `syncPushToken()` successfully updates server

---

### Phase 3: Refactor OTP Verification Flow

Update the OTP verification to call server for profile creation.

#### Step 3.1: Update `otp_verification_screen.dart`

**Changes:**
- After `verifyOTP()` succeeds, call `userProfileService.completeSignup()`
- Pass FCM token if available
- If couple/partner returned, save to storage
- Then navigate to root

#### Step 3.2: Update `auth_screen.dart` (dev mode)

**Changes:**
- After `devSignInWithEmail()` succeeds, call `userProfileService.completeSignup()`
- Same flow as OTP verification

#### Phase 3 Testing
- [ ] New user OTP flow → User created with Supabase auth ID (not random UUID)
- [ ] Returning user OTP flow → User restored, couple/partner restored if exists
- [ ] Dev mode flow → Same behavior as OTP flow
- [ ] FCM token synced to server during signup

---

### Phase 4: Refactor Name Entry Screen

Remove client-side user creation, use API for name update.

#### Step 4.1: Update `name_entry_screen.dart`

**Remove:**
- `import 'package:uuid/uuid.dart'`
- `Uuid().v4()` call
- `placeholder_token` creation
- Direct `User()` construction with random ID
- `storageService.saveUser()` with random ID

**Add:**
- Get existing user from storage (created in Phase 3)
- Call `userProfileService.updateName(name)`
- Handle case where user doesn't exist (shouldn't happen, but defensive)

#### Step 4.2: Update flow logic

**Current flow:**
1. Enter name → Create User with random UUID → Save to Hive → Navigate to AuthScreen

**New flow:**
1. User already created (from OTP) with correct ID
2. Enter name → Call API to update name → Navigate

**Note:** The screen order may need adjustment. Currently: Name → Auth → OTP
After refactor, user needs to be authenticated before name entry works.

**Decision:** Keep current screen order but handle both cases:
- If user exists (authenticated, returning user): Update name via API
- If user doesn't exist (new user, pre-auth): Store name temporarily, apply after OTP

#### Phase 4 Testing
- [ ] New user: Enter name → Name stored temporarily → After OTP, name applied via API
- [ ] Returning user (has account, no name): Enter name → API call → Name updated
- [ ] No `Uuid().v4()` calls anywhere in the file
- [ ] No `placeholder_token` strings created

---

### Phase 5: Refactor Partner Model

Update Partner to be created from server responses.

#### Step 5.1: Add `Partner.fromJson()` factory

**File:** `app/lib/models/partner.dart`

```dart
factory Partner.fromJson(Map<String, dynamic> json, DateTime pairedAt) {
  return Partner(
    id: json['id'] as String,
    name: json['name'] as String,
    pushToken: json['pushToken'] as String? ?? '',
    pairedAt: pairedAt,
    avatarEmoji: json['avatarEmoji'] as String? ?? '💕',
  );
}

Map<String, dynamic> toJson() {
  return {
    'id': id,
    'name': name,
    'pushToken': pushToken,
    'avatarEmoji': avatarEmoji,
  };
}
```

#### Step 5.2: Update API responses

**Files:**
- `api/app/api/couples/join/route.ts`
- `api/app/api/couples/pair-direct/route.ts`
- `api/app/api/couples/status/route.ts`

Add `partner` object to responses (keep old fields for backward compatibility):
```json
{
  "coupleId": "...",
  "partnerId": "...",
  "partnerName": "...",
  "partnerEmail": "...",
  "partner": {
    "id": "...",
    "name": "...",
    "email": "...",
    "pushToken": "...",
    "avatarEmoji": "💕"
  }
}
```

#### Step 5.3: Update `couple_pairing_service.dart`

Use `Partner.fromJson()` in:
- `joinWithCode()`
- `pairDirect()` (called internally, returns Partner)
- `getStatus()` - update `CoupleStatus` to include Partner

#### Phase 5 Testing
- [ ] `Partner.fromJson()` correctly parses API response
- [ ] `joinWithCode()` returns Partner with all fields from server
- [ ] `pairDirect()` returns Partner with all fields from server
- [ ] API responses include both old and new format (backward compatible)

---

### Phase 6: Refactor Pairing Screen

Remove client-side Partner construction and dual ID fallback.

#### Step 6.1: Remove Partner construction in `pairing_screen.dart`

**Current (lines 79-88, 244-250, 341-346):**
```dart
final partner = Partner(
  name: status.partnerName ?? ...,
  pushToken: '',
  ...
);
```

**New:**
```dart
// Partner already created by CouplePairingService
// Just save and navigate
```

#### Step 6.2: Remove dual ID fallback

**Current (lines 164-180):**
```dart
final authUserId = await authService.getUserId();
final user = _storageService.getUser();
final userId = authUserId ?? user?.id;
```

**New:**
```dart
final userId = await authService.getUserId();
if (userId == null) {
  Logger.error('Not authenticated', service: 'pairing');
  return;
}
```

#### Step 6.3: Update QR code generation

Use only auth service user ID, remove Hive fallback.

#### Phase 6 Testing
- [ ] QR code pairing (scanner side) → Partner saved from API response
- [ ] QR code pairing (displayer side, via polling) → Partner saved from API response
- [ ] Remote code pairing (enter code) → Partner saved from API response
- [ ] Remote code pairing (generate code, wait) → Partner saved from API response
- [ ] No manual `Partner()` construction in pairing_screen.dart
- [ ] No `userId ?? user?.id` fallback patterns

---

### Phase 7: Refactor Auth Wrapper

Clean up scattered User creation logic.

#### Step 7.1: Update `_ensureCoupleIdSaved()`

**Current:** Creates User manually if missing
**New:** Call `userProfileService.getProfile()` if User missing

#### Step 7.2: Update `_checkAndRestorePairingStatus()`

**Current:** Creates User and Partner manually
**New:** This should rarely be needed since `completeSignup()` handles it
Remove duplicate logic, keep only as fallback

#### Step 7.3: Simplify state checks

With `completeSignup()` returning full state, auth_wrapper can be simpler:
- Authenticated + has User in storage → check partner → HomeScreen or PairingScreen
- Authenticated + no User → call `getProfile()` to restore
- Not authenticated → OnboardingScreen or AuthScreen

#### Phase 7 Testing
- [ ] Fresh install → OnboardingScreen
- [ ] After OTP → User in storage with correct ID
- [ ] Clear app data, re-login → User and couple restored from server
- [ ] No manual User construction in auth_wrapper.dart

---

### Phase 8: Server-Side Couple Initialization

Move quest generation and LP initialization to server.

#### Step 8.1: Update pairing endpoints

**Files:**
- `api/app/api/couples/join/route.ts`
- `api/app/api/couples/pair-direct/route.ts`

**Add after couple creation:**
```typescript
// Initialize couple data
await initializeCoupleData(coupleId);
```

#### Step 8.2: Create `initializeCoupleData()` utility

**File:** `api/lib/couple/initialize.ts` (NEW)

```typescript
export async function initializeCoupleData(coupleId: string) {
  // 1. Initialize quiz progression
  // 2. Initialize you-or-me progression
  // 3. Initialize LP (couples.total_lp = 0)
  // 4. Set first_player_id (default to user2)
  // 5. Generate first day's quests
}
```

#### Step 8.3: Remove client-side initialization

**File:** `app/lib/screens/pairing_screen.dart`

Remove `_initializeDailyQuestsAndNavigate()` quest generation logic.
Keep navigation, remove quest generation (server handles it).

#### Phase 8 Testing
- [ ] New couple created → Quiz progression row exists
- [ ] New couple created → You-or-me progression row exists
- [ ] New couple created → `couples.total_lp = 0`
- [ ] New couple created → Daily quests generated for today
- [ ] Client pairing flow doesn't generate quests (server already did)

---

### Phase 9: Push Token Integration

Ensure push tokens are properly synced throughout the flow.

#### Step 9.1: Update `NotificationService`

Add method to sync token when it changes:
```dart
static Future<void> _onTokenRefresh(String token) async {
  final userProfileService = UserProfileService();
  await userProfileService.syncPushToken(token, _getPlatform());
}
```

#### Step 9.2: Remove placeholder tokens

Search and remove all `placeholder_token` occurrences.

#### Step 9.3: Update QR code data

QR code should not include push token (partner fetches from server).

#### Phase 9 Testing
- [ ] FCM token synced to server on app start
- [ ] FCM token synced when refreshed
- [ ] No `placeholder_token` strings in codebase
- [ ] Partner push token fetched from server (not QR code)

---

### Phase 10: Cleanup and Final Testing

#### Step 10.1: Remove dead code

- Remove `uuid` package usage in auth flow
- Remove unused fallback patterns
- Remove any commented-out old code

#### Step 10.2: Update CLAUDE.md

Document the new auth flow and API endpoints.

#### Phase 10 Testing - Full Flow Tests

**Test 1: New User Complete Flow**
- [ ] Fresh install → Onboarding → Enter name → Auth → OTP → Pairing → Home
- [ ] User ID matches Supabase auth ID throughout
- [ ] No random UUIDs generated

**Test 2: Returning User (Same Device)**
- [ ] Sign out → Sign in → OTP → Restored to previous state
- [ ] Partner and couple intact

**Test 3: Returning User (New Device)**
- [ ] Sign in on new device → OTP → Full state restored from server
- [ ] Can continue using app normally

**Test 4: QR Code Pairing**
- [ ] User A shows QR → User B scans → Both paired
- [ ] Partner data correct on both sides
- [ ] Quests generated (server-side)

**Test 5: Remote Code Pairing**
- [ ] User A generates code → User B enters code → Both paired
- [ ] Partner data correct on both sides

**Test 6: Dev Mode**
- [ ] Dev sign-in works same as OTP flow
- [ ] Android emulator + Chrome pairing works

---

## File Changes Summary

### New Files (7)
| File | Purpose |
|------|---------|
| `api/app/api/user/complete-signup/route.ts` | Complete signup, return full state |
| `api/app/api/user/name/route.ts` | Update display name |
| `api/app/api/user/push-token/route.ts` | Sync FCM token |
| `api/app/api/user/profile/route.ts` | Get full profile |
| `api/lib/couple/initialize.ts` | Initialize couple data |
| `app/lib/services/user_profile_service.dart` | Flutter profile service |

### Modified Files (10)
| File | Changes |
|------|---------|
| `app/lib/screens/otp_verification_screen.dart` | Call `completeSignup()` |
| `app/lib/screens/auth_screen.dart` | Call `completeSignup()` in dev mode |
| `app/lib/screens/name_entry_screen.dart` | Remove UUID, use API |
| `app/lib/screens/pairing_screen.dart` | Remove Partner construction |
| `app/lib/models/partner.dart` | Add `fromJson()` |
| `app/lib/services/couple_pairing_service.dart` | Use `Partner.fromJson()` |
| `app/lib/services/notification_service.dart` | Sync token on refresh |
| `app/lib/widgets/auth_wrapper.dart` | Use `UserProfileService` |
| `api/app/api/couples/join/route.ts` | Add partner object, init couple |
| `api/app/api/couples/pair-direct/route.ts` | Add partner object, init couple |

---

## Migration Safety

### Backward Compatibility
- API endpoints return both old and new format
- Flutter client prefers new format, falls back to old
- No database migration needed

### Rollback Plan
1. Revert Flutter app changes
2. API endpoints remain backward compatible
3. No data corruption possible

---

## Progress Tracking

- [ ] Phase 1: API Endpoints
- [ ] Phase 2: Flutter UserProfileService
- [ ] Phase 3: OTP Verification Flow
- [ ] Phase 4: Name Entry Screen
- [ ] Phase 5: Partner Model
- [ ] Phase 6: Pairing Screen
- [ ] Phase 7: Auth Wrapper
- [ ] Phase 8: Server-Side Couple Init
- [ ] Phase 9: Push Token Integration
- [ ] Phase 10: Cleanup and Final Testing
