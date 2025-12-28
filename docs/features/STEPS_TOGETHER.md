# Steps Together

## Quick Reference

| Item | Location |
|------|----------|
| Feature Service | `lib/services/steps_feature_service.dart` |
| Health Service | `lib/services/steps_health_service.dart` |
| Sync Service | `lib/services/steps_sync_service.dart` |
| Model | `lib/models/steps_data.dart` |
| Quest Card | `lib/widgets/steps_card.dart` |
| Claim Screen | `lib/screens/steps_claim_screen.dart` |
| API Route | `api/app/api/sync/steps/route.ts` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Steps Together                               │
│                                                                  │
│   iOS-only feature using HealthKit                              │
│   Partners combine daily steps for LP rewards                   │
│                                                                  │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│   │   HealthKit  │    │    Server    │    │   Daily Claim    │  │
│   │   (iOS only) │    │    (sync)    │    │   (yesterday)    │  │
│   └──────────────┘    └──────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Feature States

```dart
enum StepsFeatureState {
  notSupported,       // Android (no HealthKit)
  neitherConnected,   // Neither user has connected
  partnerConnected,   // Partner connected, user hasn't
  waitingForPartner,  // User connected, partner hasn't
  tracking,           // Both connected, showing progress
  claimReady,         // Yesterday's reward available
}
```

---

## LP Rewards

| Combined Steps | LP Reward |
|----------------|-----------|
| 0 - 4,999 | 0 |
| 5,000 - 9,999 | 15 |
| 10,000 - 14,999 | 20 |
| 15,000 - 19,999 | 25 |
| 20,000+ | 30 |

**Claim Window:** Yesterday's steps can be claimed today (midnight reset).

---

## Data Flow

### Connecting HealthKit
```
User taps "Connect Apple Health"
         │
         ▼
_healthService.requestPermission()
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
Granted                      Denied
    │                             │
    ▼                             ▼
Sync to server              Show error
Update connection status
```

### Daily Step Sync
```
App opens / periodic sync
         │
         ▼
_healthService.getTodaySteps()
         │
         ▼
POST /api/sync/steps
  { steps: 5432, date: "2024-12-16" }
         │
         ▼
Server combines with partner steps
         │
         ▼
Return combined data
Update local storage
```

### Claiming Reward
```
User taps "Claim" (claimReady state)
         │
         ▼
POST /api/sync/steps/claim
  { date: "2024-12-15" }
         │
         ▼
Server calculates LP reward
Award LP to couple
         │
         ▼
Mark as claimed
Show celebration
```

---

## Key Rules

### 1. iOS Only
Steps Together only works on iOS due to HealthKit:

```dart
bool get isSupported => Platform.isIOS;
```

### 2. Never Use hasPermission() for Sync Gating
iOS HealthKit `hasPermission()` is unreliable:

```dart
// ❌ WRONG - unreliable on iOS
final hasPerms = await _health.hasPermissions([HealthDataType.STEPS]);
if (!hasPerms) return;

// ✅ CORRECT - use stored connection status
final connection = _storage.getStepsConnection();
if (connection?.isConnected != true) return null;
```

### 3. Partner Status Refresh
Refresh partner status separately from user sync:

```dart
// Lightweight call just for partner status
await stepsService.refreshPartnerStatus();
```

### 4. Auto-Initialize from Storage
Service can auto-initialize if user/partner are in storage:

```dart
Future<bool> ensureInitialized() async {
  if (_isInitialized) return true;
  final user = _storage.getUser();
  final partner = _storage.getPartner();
  if (user == null || partner == null) return false;
  // Initialize with couple ID...
}
```

### 5. Claim Ready Takes Priority
`claimReady` state overrides other connection states:

```dart
// Check for claimable reward first
final yesterday = _storage.getYesterdaySteps();
if (yesterday != null && yesterday.canClaim) {
  return StepsFeatureState.claimReady;
}
// Then check connection states...
```

---

## Common Bugs & Fixes

### 1. Steps Not Syncing
**Symptom:** Connected but steps show 0.

**Cause:** HealthKit permission not actually granted.

**Fix:** Check actual permission in health app, reconnect if needed.

### 2. Partner Status Never Updates
**Symptom:** "Waiting for partner" even after partner connects.

**Cause:** `refreshPartnerStatus()` not called.

**Fix:** Refresh on screen mount:
```dart
@override
void initState() {
  _stepsService.refreshPartnerStatus();
}
```

### 3. Yesterday's Claim Not Showing
**Symptom:** Completed steps yesterday but no claim option today.

**Cause:** Sync didn't run after midnight.

**Fix:** Sync runs on app open, or force sync:
```dart
await _stepsService.syncSteps();
```

### 4. Wrong LP Calculated
**Symptom:** Steps should give 25 LP but shows 15 LP.

**Cause:** Using individual steps instead of combined.

**Fix:** Use `combinedSteps`:
```dart
final lp = StepsDay.calculateLP(stepsDay.combinedSteps);
```

---

## Debugging Tips

### Check Feature State
```dart
final state = StepsFeatureService().getCurrentState();
debugPrint('Steps state: $state');
```

### Check Connection Status
```dart
final connection = StorageService().getStepsConnection();
debugPrint('User connected: ${connection?.isConnected}');
debugPrint('Partner connected: ${connection?.partnerConnected}');
```

### Check Today's Data
```dart
final today = StorageService().getTodaySteps();
debugPrint('My steps: ${today?.mySteps}');
debugPrint('Partner steps: ${today?.partnerSteps}');
debugPrint('Combined: ${today?.combinedSteps}');
```

---

## API Reference

### POST /api/sync/steps
Sync user's steps.

**Request:**
```json
{
  "steps": 5432,
  "date": "2024-12-16"
}
```

**Response:**
```json
{
  "success": true,
  "mySteps": 5432,
  "partnerSteps": 7890,
  "combinedSteps": 13322,
  "partnerConnected": true
}
```

### POST /api/sync/steps/claim
Claim yesterday's reward.

**Request:**
```json
{ "date": "2024-12-15" }
```

**Response:**
```json
{
  "success": true,
  "lpAwarded": 25,
  "combinedSteps": 17500
}
```

---

## File Reference

| File | Purpose |
|------|---------|
| `steps_feature_service.dart` | Main service, state management |
| `steps_health_service.dart` | HealthKit integration |
| `steps_sync_service.dart` | Server sync, polling |
| `steps_data.dart` | StepsDay, StepsConnection models |
| `steps_card.dart` | Side quest card display |
| `steps_claim_screen.dart` | Claim celebration |
