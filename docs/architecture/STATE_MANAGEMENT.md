# State Management

## Quick Reference

| Item | Location |
|------|----------|
| Storage Service | `lib/services/storage_service.dart` |
| Auth Service | `lib/services/auth_service.dart` |
| User Model | `lib/models/user.dart` |
| Partner Model | `lib/models/partner.dart` |
| Hive Boxes | See "Hive Boxes" section |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    State Management Layers                       │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                Server (Source of Truth)                   │  │
│   │   Supabase: couples, users, matches, quests              │  │
│   └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                  Local Storage (Hive)                     │  │
│   │   Persistent cache, offline access, fast reads           │  │
│   └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │               In-Memory (Service Singletons)              │  │
│   │   Runtime state, callbacks, computed values              │  │
│   └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                  UI (StatefulWidgets)                     │  │
│   │   Screen-local state, animations, form inputs            │  │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Storage Layers

### 1. Supabase (Server)
- **Source of truth** for all persistent data
- Synced via API calls
- Examples: `couples.total_lp`, match state, user profiles

### 2. Hive (Local)
- Local NoSQL database
- Used for caching and offline access
- Auto-persisted to disk
- Examples: User, Partner, DailyQuests, LinkedMatch

### 3. Secure Storage (flutter_secure_storage)
- Encrypted storage for sensitive data
- Auth tokens only
- Examples: JWT access/refresh tokens

### 4. Service Singletons
- In-memory runtime state
- Callbacks for UI updates
- Examples: UnlockService.cachedState, LovePointService.currentLP

---

## Hive Boxes

| Box Name | Type | Purpose |
|----------|------|---------|
| `user` | `User` | Current user profile |
| `partner` | `Partner` | Partner profile |
| `daily_quests` | `DailyQuest` | Quest data by date |
| `quiz_sessions` | `QuizSession` | Quiz match history |
| `linked_matches` | `LinkedMatch` | Linked game state |
| `word_search_matches` | `WordSearchMatch` | Word Search state |
| `you_or_me_sessions` | `YouOrMeSession` | You or Me history |
| `steps_days` | `StepsDay` | Daily step counts |
| `steps_connection` | `StepsConnection` | HealthKit status |
| `app_metadata` | untyped | Flags, seen states |
| `celebrations_seen` | untyped | Per-user celebration flags |

---

## Key Rules

### 1. Hive Field Migration
Always use `defaultValue` for new fields on existing HiveTypes:

```dart
// ✅ CORRECT - won't crash on existing data
@HiveField(10, defaultValue: 'reminder')
String category;

// ❌ WRONG - crashes when reading old data without this field
@HiveField(10)
late String category;
```

After adding fields, regenerate adapters:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Server is Source of Truth for LP
Never modify LP locally. Always sync from server:

```dart
// ❌ WRONG - causes double-counting
user.lovePoints += 30;
await storage.saveUser(user);

// ✅ CORRECT - sync from server
await LovePointService.fetchAndSyncFromServer();
```

### 3. Save to Hive After Server Updates
When server returns new state, save to Hive:

```dart
final response = await api.post('/api/game/linked/submit', ...);
if (response.success) {
  final match = LinkedMatch.fromJson(response.data);
  await StorageService().saveLinkedMatch(match);  // Persist locally
}
```

### 4. Use Stored Connection Status (Not Runtime Checks)
For unreliable platform APIs, use stored status:

```dart
// ❌ WRONG - iOS HealthKit hasPermission() is unreliable
final hasPerms = await health.hasPermissions([HealthDataType.STEPS]);

// ✅ CORRECT - use stored connection status
final connection = storage.getStepsConnection();
if (connection?.isConnected != true) return;
```

### 5. Callback Pattern for UI Updates
Services notify UI via callbacks:

```dart
// In service
static Function()? _onLPChanged;
static void setLPChangeCallback(Function() callback) {
  _onLPChanged = callback;
}

// In widget
@override
void initState() {
  LovePointService.setLPChangeCallback(() {
    if (mounted) setState(() {});
  });
}
```

---

## Core Models

### User
```dart
@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String pushToken;
  @HiveField(2) DateTime createdAt;
  @HiveField(3) String? name;
  @HiveField(4, defaultValue: 0) int lovePoints;
  @HiveField(5, defaultValue: 1) int arenaTier;
  @HiveField(6, defaultValue: 0) int floor;
  @HiveField(8, defaultValue: '😊') String avatarEmoji;
}
```

### Partner
```dart
@HiveType(typeId: 1)
class Partner extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) String pushToken;
  @HiveField(2) DateTime pairedAt;
  @HiveField(3) String? avatarEmoji;
  @HiveField(4, defaultValue: '') String id;  // UUID for completion tracking
}
```

---

## Storage Service Patterns

### Reading Data
```dart
final storage = StorageService();

// Get current user
final user = storage.getUser();

// Get partner
final partner = storage.getPartner();

// Get today's quests
final quests = storage.getTodayQuests();

// Get active game match
final match = storage.getActiveLinkedMatch();
```

### Writing Data
```dart
// Save user
await storage.saveUser(user);

// Save partner
await storage.savePartner(partner);

// Save quest
await storage.saveDailyQuest(quest);

// Update existing HiveObject
quest.isCompleted = true;
await quest.save();  // Direct save on HiveObject
```

### Clearing Data
```dart
// Clear specific box
await storage.clearAllReminders();

// Clear all data (logout)
await storage.clearAllData();

// Clear steps data (debug)
await storage.clearAllStepsData();
```

---

## Auth State

### Token Storage (Secure)
```dart
// In auth_service.dart
final _storage = FlutterSecureStorage();

Future<void> _saveTokens(String access, String refresh) async {
  await _storage.write(key: 'access_token', value: access);
  await _storage.write(key: 'refresh_token', value: refresh);
}

Future<String?> getAccessToken() async {
  return await _storage.read(key: 'access_token');
}
```

### Session Restoration
```dart
// Check if logged in
final token = await authService.getAccessToken();
final isLoggedIn = token != null;

// Get user from Hive (fast)
final user = storage.getUser();
final isPaired = storage.hasPartner();
```

---

## Common Bugs & Fixes

### 1. Hive Adapter Not Registered
**Symptom:** `HiveError: Cannot read, unknown typeId`

**Cause:** Adapter not registered before opening box.

**Fix:** Register in `StorageService.init()`:
```dart
if (!Hive.isAdapterRegistered(27)) {
  Hive.registerAdapter(StepsDayAdapter());
}
```

### 2. Field Missing After Model Update
**Symptom:** App crashes reading existing data.

**Cause:** New field added without `defaultValue`.

**Fix:** Add defaultValue:
```dart
@HiveField(10, defaultValue: false)
bool newFlag;
```

### 3. Stale Data After Server Update
**Symptom:** UI shows old data despite server change.

**Cause:** Not saving server response to Hive.

**Fix:** Always save after API success:
```dart
if (response.success) {
  await storage.saveLinkedMatch(match);
  setState(() {});
}
```

### 4. State Lost After Hot Restart
**Symptom:** In-memory state gone after restart.

**Cause:** Using only in-memory state, not Hive.

**Fix:** Read from Hive on init:
```dart
@override
void initState() {
  super.initState();
  final match = storage.getActiveLinkedMatch();
  if (match != null) _gameState = GameState.fromMatch(match);
}
```

### 5. Partner ID Empty
**Symptom:** `userCompletions` check fails for partner.

**Cause:** Partner saved without ID field.

**Fix:** Use `Partner.fromJson()` with proper ID:
```dart
final partner = Partner.fromJson(json, pairedAt);
// Ensures partner.id is populated
```

---

## Initialization Order

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(...);      // 1. Firebase first
  await StorageService.init();            // 2. Hive boxes
  await NotificationService.initialize(); // 3. FCM handlers
  await MockDataService.injectIfNeeded(); // 4. Dev data
  runApp(MyApp());
}
```

---

## File Reference

| File | Purpose |
|------|---------|
| `storage_service.dart` | Hive box management |
| `auth_service.dart` | Secure token storage |
| `love_point_service.dart` | LP state + callbacks |
| `unlock_service.dart` | Unlock state caching |
| `models/*.dart` | Hive-annotated models |
| `models/*.g.dart` | Generated adapters |
