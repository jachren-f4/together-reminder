# Daily Quests System

## Quick Reference

| Item | Location |
|------|----------|
| Quest Model | `lib/models/daily_quest.dart` |
| Quest Service | `lib/services/daily_quest_service.dart` |
| Quest Initialization | `lib/services/quest_initialization_service.dart` |
| Quest Sync | `lib/services/quest_sync_service.dart` |
| Quest Type Manager | `lib/services/quest_type_manager.dart` |
| Daily Quests Widget | `lib/widgets/daily_quests_widget.dart` |
| Quest Carousel | `lib/widgets/quest_carousel.dart` |
| API Sync Route | `api/app/api/sync/daily-quests/route.ts` |
| API Completion Route | `api/app/api/sync/daily-quests/completion/route.ts` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Daily Quest System                           │
│                                                                  │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│   │ 3 Daily      │    │ Side Quests  │    │ Quest Carousel   │  │
│   │ Quests       │    │ (Linked, WS) │    │ (UI Widget)      │  │
│   └──────────────┘    └──────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
   QuestInitService     QuestSyncService    QuestTypeManager
          │                   │                   │
          └───────────────────┼───────────────────┘
                              ▼
                        Supabase API
                   (daily_quests table)
```

---

## Quest Types

### Main Daily Quests (3 per day)
| Slot | Type | Description |
|------|------|-------------|
| 0 | Classic Quiz | Even track positions (0, 2) |
| 1 | Affirmation Quiz | Odd track positions (1, 3) |
| 2 | You or Me | Separate progression track |

### Side Quests (Unlockable)
| Type | Unlock Requirement |
|------|-------------------|
| Linked | Complete all 3 daily quests once |
| Word Search | Complete Linked once |
| Steps Together | Complete Word Search once |

---

## Data Flow

### Quest Generation Flow
```
App Startup / PairingScreen
         │
         ▼
QuestInitializationService.ensureQuestsInitialized()
         │
    ┌────┴────┐
    ▼         ▼
Check Hive   API: GET /daily-quests?date=YYYY-MM-DD
    │              │
    │         ┌────┴────────────────┐
    │         ▼                     ▼
    │    Quests Exist          No Quests
    │         │                     │
    │         ▼                     ▼
    │    Load to Hive       QuestTypeManager.generateDailyQuests()
    │         │                     │
    │         │                     ▼
    │         │             POST /daily-quests
    │         │                     │
    └─────────┴─────────────────────┘
                    │
                    ▼
              Hive Storage
```

### Quest Completion Flow
```
User Completes Game
         │
         ▼
Game-Specific API (e.g., POST /quiz-match/submit)
         │
         ├──> Awards LP (server-side)
         ├──> Updates match status
         │
         ▼
Waiting Screen / Results Screen
         │
         ├──> Updates local quest.userCompletions
         ├──> Syncs LP from server
         │
         ▼
Navigate back to Home
         │
         ▼
didPopNext() triggers refresh
         │
         ├──> _pollingService.pollNow()
         ├──> _fetchUnlockState()
         ├──> setState()
```

---

## Key Rules

### 1. Quest Initialization Entry Points
Only TWO places should call `ensureQuestsInitialized()`:

```dart
// 1. PairingScreen after successful pairing
await _questService.ensureQuestsInitialized();

// 2. NewHomeScreen for returning users (app reinstall)
await _questService.ensureQuestsInitialized();
```

**DO NOT** call from `main.dart` - User/Partner not restored yet.

### 2. Server-Side Idempotency
API uses `ON CONFLICT DO NOTHING` for race conditions:

```typescript
// Both devices can safely upload - first one wins
INSERT INTO daily_quests (...)
ON CONFLICT (couple_id, date_key, sort_order) DO NOTHING
```

No arbitrary delays needed.

### 3. Quest Title Display
Use denormalized metadata, NOT session lookups:

```dart
// ✅ CORRECT - Use synced metadata
return quest.quizName ?? 'Affirmation Quiz';

// ❌ WRONG - Session lookup fails on partner's device
final session = StorageService().getQuizSession(quest.contentId);
return session?.quizName;
```

### 4. RouteAware for Refresh
`DailyQuestsWidget` uses `RouteAware` to refresh when returning from games:

```dart
@override
void didPopNext() {
  // Called when returning from quiz/waiting/results screens
  _pollingService.pollNow();
  _fetchUnlockState();
  setState(() {});
}
```

### 5. Initial Load Anti-Flash
Prevent "No Daily Quests Yet" flash with loading state:

```dart
bool _isInitialLoad = true;

// Wait up to 3 seconds for quests to appear
for (int i = 0; i < 15; i++) {
  await Future.delayed(const Duration(milliseconds: 200));
  if (_questService.getMainDailyQuests().isNotEmpty) {
    setState(() => _isInitialLoad = false);
    return;
  }
}
```

### 6. Quest Slot Mapping
Progression tracks map to specific quiz types:

```dart
// Slot 0: Classic Quiz (even positions)
// Track 0, Position 0 → Classic (favorites)
// Track 0, Position 2 → Classic (personality)

// Slot 1: Affirmation Quiz (odd positions)
// Track 0, Position 1 → Affirmation (trust)
// Track 0, Position 3 → Affirmation (emotional_support)

// Slot 2: You or Me (separate progression)
// Uses YouOrMeQuestProvider with own tracking
```

---

## Common Bugs & Fixes

### 1. Quests Not Appearing
**Symptom:** Home screen shows "No Daily Quests Yet" indefinitely.

**Causes:**
- User/Partner not in Hive (not paired)
- Network error during sync
- Quest generation failed

**Fix:** Check `quest-init` service logs:
```dart
Logger.debug('...', service: 'quest-init');
```

### 2. Partner Sees Different Quests
**Symptom:** Partners have mismatched quest IDs.

**Cause:** Race condition in quest upload.

**Fix:** Server handles with `ON CONFLICT DO NOTHING`. If persists:
```dart
// QuestSyncService replaces local with server quests
if (supabaseQuestIds.difference(localQuestIds).isEmpty...) {
  // Clear local and reload from server
}
```

### 3. Quest Status Not Updating
**Symptom:** Quest shows "Your turn" after completion.

**Cause:** Hive not updated after game completion.

**Fix:** Ensure game screens update local quest:
```dart
quest.userCompletions ??= {};
quest.userCompletions![userId] = true;
await quest.save();
```

### 4. You or Me Locked After Quiz
**Symptom:** You or Me shows locked even after completing both quizzes.

**Cause:** Unlock state not refreshed.

**Fix:** `didPopNext()` must call `_fetchUnlockState()`:
```dart
@override
void didPopNext() {
  _pollingService.pollNow();
  _fetchUnlockState();  // This line
  setState(() {});
}
```

### 5. Quest Cards Not Rebuilding
**Symptom:** Visual state stale after returning from game.

**Cause:** Missing `setState()` or RouteObserver not subscribed.

**Fix:**
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final route = ModalRoute.of(context);
  if (route != null) {
    questRouteObserver.subscribe(this, route);  // Must subscribe
  }
}
```

---

## Debugging Tips

### Check Quest State
```dart
final quests = StorageService().getTodayQuests();
for (final q in quests) {
  debugPrint('Quest: ${q.id}');
  debugPrint('  Type: ${q.type}');
  debugPrint('  Status: ${q.status}');
  debugPrint('  Completions: ${q.userCompletions}');
}
```

### Force Quest Regeneration
1. Clear local quests in Debug Menu
2. Delete from Supabase: `DELETE FROM daily_quests WHERE date_key = '2024-12-16'`
3. Restart app

### Verify Sync
Enable logging:
```dart
// In quest_sync_service.dart
Logger.debug('...', service: 'quest');
```

### Check API Response
```bash
curl -X GET "https://api-joakim-achrens-projects.vercel.app/api/sync/daily-quests?date=2024-12-16" \
  -H "Authorization: Bearer <token>"
```

---

## Quest Model Reference

```dart
class DailyQuest extends HiveObject {
  String id;           // UUID
  QuestType type;      // quiz, youOrMe, linked, wordSearch, steps
  String contentId;    // Reference to content (session, puzzle, etc.)
  String dateKey;      // YYYY-MM-DD
  int sortOrder;       // 0, 1, 2 for main quests
  String status;       // pending, in_progress, completed, expired
  bool isSideQuest;    // true for Linked, Word Search, Steps
  String? formatType;  // 'classic' or 'affirmation' for quizzes
  String? quizName;    // Display name for quest card
  String? branch;      // Content branch (lighthearted, meaningful, etc.)

  Map<String, bool>? userCompletions;  // userId -> completed
  DateTime? completedAt;
  int lpAwarded;
}
```

---

## API Reference

### GET /api/sync/daily-quests
Fetch quests for a date.

**Query:** `?date=YYYY-MM-DD`

**Response:**
```json
{
  "success": true,
  "quests": [
    {
      "id": "uuid",
      "questType": "quiz",
      "contentId": "quiz:classic:2024-12-16",
      "sortOrder": 0,
      "formatType": "classic",
      "quizName": "Relationship Favorites"
    }
  ]
}
```

### POST /api/sync/daily-quests
Upload generated quests.

**Body:**
```json
{
  "dateKey": "2024-12-16",
  "quests": [...]
}
```

---

## File Reference

| File | Purpose |
|------|---------|
| `daily_quest.dart` | Hive model for quests |
| `daily_quest_service.dart` | Quest CRUD and completion logic |
| `quest_initialization_service.dart` | Centralized init (sync + generate) |
| `quest_sync_service.dart` | Supabase sync logic |
| `quest_type_manager.dart` | Quest generation with providers |
| `quest_utilities.dart` | Date key helpers |
| `daily_quests_widget.dart` | Home screen quest display |
| `quest_carousel.dart` | Horizontal swipe carousel |
| `quest_card.dart` | Individual quest card UI |

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-16 | Fixed quest card text - "Answer ten questions" → "Answer five questions" |
| 2025-12-16 | Initial documentation |
