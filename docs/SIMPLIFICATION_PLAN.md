# Simplification Plan: Remove Automatic Sync + Unified Firebase Paths

**Date**: 2025-01-13
**Status**: Ready for Implementation
**Estimated Impact**: ~270 lines of code reduction

---

## Overview

This plan removes all automatic synchronization mechanisms (background listeners and polling) in favor of manual refresh, while simultaneously simplifying the Firebase path structure to use shared couple-based paths instead of device-specific paths.

**Key Benefits**:
- Remove ~250 lines of complex async code (listeners, polling, sync logic)
- Simplify Firebase structure by ~100 lines (fallback logic, path complexity)
- Eliminate race conditions and timing issues
- Easier to debug and maintain
- Better battery life (no constant background operations)

**Trade-offs**:
- User must manually refresh to see partner updates
- Adds ~80 lines for refresh UI (buttons, pull-to-refresh, timestamps)

**Net Result**: ~270 lines removed, significantly simpler architecture

---

## Phase 1: Remove All Automatic Sync (~250 lines removed)

### 1.1 Remove Background Listeners from quiz_service.dart

**Current Code (Lines 467-527)**:
```dart
Future<void> startListeningForPartnerSessions() async {
  // ... ~60 lines of listener setup
}
```

**Action**:
- Delete entire `startListeningForPartnerSessions()` method
- Delete all `onChildAdded`, `onChildChanged` listener subscriptions
- Remove `_database` references related to listeners

**Files**: `lib/services/quiz_service.dart`

---

### 1.2 Remove Listener Initialization from main.dart

**Current Code (Line 66)**:
```dart
await QuizService().startListeningForPartnerSessions();
await DailyPulseService().startListeningForPartnerPulses();
```

**Action**:
- Delete these listener initialization calls
- Keep Firebase initialization, just remove listener setup

**Files**: `lib/main.dart`

---

### 1.3 Remove Polling from quiz_waiting_screen.dart

**Current Code (Lines 21, 37-42)**:
```dart
Timer? _pollTimer;

void _startPolling() {
  _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
    _checkSessionStatus();
  });
}
```

**Action**:
- Delete `_pollTimer` field
- Delete `_startPolling()` method
- Keep `_checkSessionStatus()` logic but make it button-triggered only
- Remove automatic polling in `initState()`

**Replacement**: Add manual "Check for Updates" button

```dart
// Add to UI
ElevatedButton.icon(
  onPressed: () async {
    setState(() => _isChecking = true);
    await _checkSessionStatus();
    setState(() => _isChecking = false);
  },
  icon: Icon(_isChecking ? Icons.hourglass_empty : Icons.refresh),
  label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
  ),
)
```

**Files**: `lib/screens/quiz_waiting_screen.dart`

---

### 1.4 Add Manual Refresh to home_screen.dart

**New Code**:

```dart
// Add to AppBar actions
actions: [
  IconButton(
    icon: Icon(_isRefreshing ? Icons.hourglass_empty : Icons.refresh),
    tooltip: 'Refresh from Firebase',
    onPressed: _isRefreshing ? null : _refreshFromFirebase,
  ),
]

// Add state
bool _isRefreshing = false;
DateTime? _lastSyncTime;

// Add refresh method
Future<void> _refreshFromFirebase() async {
  setState(() => _isRefreshing = true);

  try {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user != null && partner != null) {
      // Sync quests from Firebase
      await QuestSyncService(
        storage: _storage,
        questService: _questService,
      ).syncTodayQuests(
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );

      setState(() {
        _lastSyncTime = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Updated from Firebase!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error refreshing: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => _isRefreshing = false);
  }
}

// Add pull-to-refresh wrapper
RefreshIndicator(
  onRefresh: _refreshFromFirebase,
  child: ListView(...), // existing content
)

// Add timestamp display below quests
if (_lastSyncTime != null)
  Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Text(
      'Last updated: ${_formatTimeSince(_lastSyncTime!)}',
      style: TextStyle(fontSize: 12, color: Colors.grey),
      textAlign: TextAlign.center,
    ),
  )

// Add time formatter
String _formatTimeSince(DateTime time) {
  final diff = DateTime.now().difference(time);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} days ago';
}
```

**Files**: `lib/screens/home_screen.dart`

---

## Phase 2: Unified Firebase Paths (~100 lines simplified)

### 2.1 Change Quiz Session Firebase Structure

**Current Structure**:
```
/quiz_sessions/
  /emulator-5554/          ← Alice's device path
    /{sessionId}/
  /web-bob/                ← Bob's device path
    /{sessionId}/
```

**New Structure**:
```
/quiz_sessions/
  /{coupleId}/             ← Shared couple path (e.g., "alice123_bob456")
    /{sessionId}/
```

**Benefits**:
- Single source of truth
- No need to determine partner's device ID
- No fallback logic needed
- Simpler Firebase rules

---

### 2.2 Simplify getSession() in quiz_service.dart

**Current Code (Lines 631-660)** - 3-tier fallback:
```dart
Future<QuizSession?> getSession(String sessionId) async {
  // 1. Try local storage
  var session = _storage.getQuizSession(sessionId);
  if (session != null) return session;

  // 2. Try own Firebase path
  final myEmulatorId = await DevConfig.emulatorId;
  session = await _loadSessionFromFirebase(sessionId, myEmulatorId);
  if (session != null) {
    _storage.saveQuizSession(session);
    return session;
  }

  // 3. Try partner's Firebase path
  final partnerEmulatorId = /* complex logic */;
  session = await _loadSessionFromFirebase(sessionId, partnerEmulatorId);
  if (session != null) {
    _storage.saveQuizSession(session);
    return session;
  }

  return null;
}
```

**New Code** - Simple 2-tier:
```dart
Future<QuizSession?> getSession(String sessionId) async {
  // 1. Try local storage first
  var session = _storage.getQuizSession(sessionId);
  if (session != null) {
    debugPrint('✅ Session found in local cache: $sessionId');
    return session;
  }

  // 2. Check shared Firebase path
  try {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null || partner == null) return null;

    final coupleId = _generateCoupleId(user.id, partner.pushToken);
    final sessionRef = _database
        .child('quiz_sessions')
        .child(coupleId)
        .child(sessionId);

    final snapshot = await sessionRef.get();

    if (snapshot.exists && snapshot.value != null) {
      final sessionData = snapshot.value as Map<dynamic, dynamic>;
      session = QuizSession.fromMap(sessionData);

      // Cache locally
      await _storage.saveQuizSession(session);

      debugPrint('✅ Session loaded from Firebase: $sessionId');
      return session;
    }
  } catch (e) {
    debugPrint('❌ Error loading session from Firebase: $e');
  }

  debugPrint('⚠️  Session not found: $sessionId');
  return null;
}

// Helper method
String _generateCoupleId(String userId1, String userId2) {
  final sortedIds = [userId1, userId2]..sort();
  return '${sortedIds[0]}_${sortedIds[1]}';
}
```

**Files**: `lib/services/quiz_service.dart`

---

### 2.3 Update _syncSessionToRTDB() in quiz_service.dart

**Current Code (Lines 141-158)**:
```dart
Future<void> _syncSessionToRTDB(QuizSession session) async {
  final emulatorId = await DevConfig.emulatorId;
  final sessionRef = _database
      .child('quiz_sessions')
      .child(emulatorId)  // ← Device-specific path
      .child(session.id);

  await sessionRef.set(sessionData);
}
```

**New Code**:
```dart
Future<void> _syncSessionToRTDB(QuizSession session) async {
  try {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null || partner == null) {
      debugPrint('⚠️  Cannot sync: user or partner not found');
      return;
    }

    final coupleId = _generateCoupleId(user.id, partner.pushToken);
    final sessionRef = _database
        .child('quiz_sessions')
        .child(coupleId)  // ← Shared couple path
        .child(session.id);

    final sessionData = {
      'id': session.id,
      'userId': session.userId,
      'partnerId': session.partnerId,
      'questId': session.questId,
      'questions': session.questions.map((q) => q.toMap()).toList(),
      'answers': session.answers?.map((a) => a.toMap()).toList(),
      'status': session.status,
      'isCompleted': session.isCompleted,
      'lpEarned': session.lpEarned,
      'matchPercentage': session.matchPercentage,
      'completedAt': session.completedAt?.millisecondsSinceEpoch,
      'createdAt': session.createdAt.millisecondsSinceEpoch,
    };

    await sessionRef.set(sessionData);
    debugPrint('✅ Session synced to Firebase: ${session.id} at /quiz_sessions/$coupleId/${session.id}');
  } catch (e) {
    debugPrint('❌ Error syncing session to Firebase: $e');
    rethrow;
  }
}
```

**Files**: `lib/services/quiz_service.dart`

---

### 2.4 Update Firebase Security Rules (database.rules.json)

**Current Rules**:
```json
{
  "rules": {
    "quiz_sessions": {
      "$emulatorId": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

**New Rules**:
```json
{
  "rules": {
    "quiz_sessions": {
      "$coupleId": {
        ".read": true,
        ".write": true,
        ".indexOn": ["createdAt", "status"]
      }
    }
  }
}
```

**Deployment**:
```bash
firebase deploy --only database
```

**Files**: `database.rules.json`

---

### 2.5 Clean Up Complexity in quiz_service.dart

**Remove**:
- `_loadSessionFromFirebase()` method (if it becomes unnecessary)
- Complex partner path determination logic
- `partnerIndex` and `partnerEmulatorId` logic (where applicable)

**Simplify**:
- All methods that reference `emulatorId` for session paths
- Change to use `coupleId` consistently

---

## Implementation Checklist

### Phase 1: Remove Automatic Sync
- [ ] Delete `startListeningForPartnerSessions()` from `quiz_service.dart`
- [ ] Remove listener calls from `main.dart`
- [ ] Remove `_pollTimer` and `_startPolling()` from `quiz_waiting_screen.dart`
- [ ] Add "Check for Updates" button to `quiz_waiting_screen.dart`
- [ ] Add refresh button to `home_screen.dart` AppBar
- [ ] Add pull-to-refresh to `home_screen.dart`
- [ ] Add "Last updated" timestamp to `home_screen.dart`
- [ ] Test manual refresh on home screen
- [ ] Test manual check on waiting screen

### Phase 2: Unified Firebase Paths
- [ ] Update `getSession()` to use couple path
- [ ] Update `_syncSessionToRTDB()` to use couple path
- [ ] Add `_generateCoupleId()` helper method
- [ ] Remove 3-tier fallback logic
- [ ] Update Firebase security rules
- [ ] Deploy new security rules to Firebase
- [ ] Clean up unused `_loadSessionFromFirebase()` complexity
- [ ] Remove unnecessary `emulatorId` logic

### Testing
- [ ] Test quest generation: Alice generates → Bob refreshes → Sees same quests
- [ ] Test quest completion: Bob completes → Alice refreshes → Status updates
- [ ] Test quiz flow: Bob completes → Waiting screen → Alice completes → Bob checks → Both see results
- [ ] Test pull-to-refresh on home screen
- [ ] Test timestamp updates correctly
- [ ] Test error handling (network errors, Firebase errors)
- [ ] Verify Firebase RTDB shows data at `/quiz_sessions/{coupleId}/`
- [ ] Verify no data at old paths `/quiz_sessions/emulator-5554/` or `/quiz_sessions/web-bob/`

### Documentation Updates
- [ ] Update `docs/QUIZ_SYNC_SYSTEM.md` to reflect manual refresh model
- [ ] Remove sections about automatic listeners
- [ ] Add section about manual refresh UX
- [ ] Update flow chart to show manual refresh steps
- [ ] Update `CLAUDE.md` with new architecture notes
- [ ] Document the new Firebase path structure

---

## Expected Code Changes Summary

### Files Modified (8 total):

1. **lib/services/quiz_service.dart** (~200 lines changed)
   - Remove: `startListeningForPartnerSessions()` method
   - Simplify: `getSession()` from 3-tier to 2-tier
   - Update: `_syncSessionToRTDB()` to use couple path
   - Add: `_generateCoupleId()` helper

2. **lib/main.dart** (~2 lines removed)
   - Remove: Listener initialization calls

3. **lib/screens/quiz_waiting_screen.dart** (~30 lines changed)
   - Remove: `_pollTimer`, `_startPolling()`
   - Add: "Check for Updates" button
   - Keep: `_checkSessionStatus()` as manual trigger

4. **lib/screens/home_screen.dart** (~60 lines added)
   - Add: Refresh button in AppBar
   - Add: `_refreshFromFirebase()` method
   - Add: Pull-to-refresh wrapper
   - Add: "Last updated" timestamp
   - Add: `_formatTimeSince()` helper

5. **database.rules.json** (~5 lines changed)
   - Update: Path from `$emulatorId` to `$coupleId`

6. **docs/QUIZ_SYNC_SYSTEM.md** (~100 lines updated)
   - Update: Flow chart for manual refresh
   - Remove: Listener documentation
   - Add: Manual refresh UX patterns

7. **CLAUDE.md** (~20 lines updated)
   - Update: Architecture overview
   - Document: Manual refresh pattern

8. **docs/SIMPLIFICATION_PLAN.md** (this file)
   - New: Complete implementation plan

---

## Rollback Plan

If issues arise after deployment:

1. **Quick rollback** (if Firebase rules cause issues):
   ```bash
   git checkout HEAD~1 database.rules.json
   firebase deploy --only database
   ```

2. **Full rollback** (if code changes cause issues):
   ```bash
   git revert HEAD
   # Or
   git reset --hard <previous-commit>
   ```

3. **Preserve new Firebase structure**: If couple-based paths work well but manual refresh has issues, can keep Phase 2 and revert only Phase 1.

---

## Success Metrics

After implementation, verify:

✅ **Code Reduction**: ~270 lines removed
✅ **Build Success**: No compilation errors
✅ **Manual Refresh Works**: Users can refresh and see partner updates
✅ **Firebase Structure**: Data appears at `/quiz_sessions/{coupleId}/`
✅ **No Automatic Polling**: Battery usage reduced
✅ **Quiz Completion Flow**: Both users can complete quiz and see results
✅ **Error Handling**: Graceful errors on network failures
✅ **UX Clarity**: Users understand when data is stale

---

## Timeline Estimate

- **Phase 1**: 1-2 hours (remove automatic sync, add manual refresh UI)
- **Phase 2**: 1 hour (update Firebase paths, deploy rules)
- **Testing**: 1 hour (full end-to-end testing)
- **Documentation**: 30 minutes (update docs)

**Total**: ~3.5-4.5 hours

---

**Last Updated**: 2025-01-13
**Status**: Ready for implementation
