# Love Points System

## Quick Reference

| Item | Location |
|------|----------|
| LP Service | `lib/services/love_point_service.dart` |
| LP Model | `lib/models/love_point_transaction.dart` |
| LP Counter Widget | `lib/widgets/lp_counter.dart` |
| LP Intro Overlay | `lib/widgets/lp_intro_overlay.dart` |
| API LP Route | `api/app/api/sync/love-points/route.ts` |
| LP Award Utility | `api/lib/lp/award.ts` |
| DB Column | `couples.total_lp` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                Single Source of Truth                            │
│                                                                  │
│                    couples.total_lp                              │
│                   (couple-level, not per-user)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
    Game Complete       Unlock Bonus       Steps Together
    (30 LP each)         (5 LP each)        (15-30 LP)
          │                   │                   │
          └───────────────────┼───────────────────┘
                              ▼
                      Server Awards LP
                              │
                              ▼
                      Client Syncs LP
```

---

## LP Rewards

| Activity | LP Reward | File |
|----------|-----------|------|
| Classic Quiz | 30 | `quiz-match/submit/route.ts` |
| Affirmation Quiz | 30 | `quiz-match/submit/route.ts` |
| You or Me | 30 | `you-or-me-match/submit/route.ts` |
| Linked Puzzle | 30 | `linked/submit/route.ts` |
| Word Search | 30 | `word-search/submit/route.ts` |
| Steps Together | 15-30 | `steps/route.ts` |
| Feature Unlock | 5 | `unlocks/complete/route.ts` |

**Max Daily LP:** 165-180 LP (depending on steps)

---

## Tier System (Arenas)

| Tier | Name | Emoji | LP Range | Floor |
|------|------|-------|----------|-------|
| 1 | Cozy Cabin | 🏕️ | 0 - 999 | 0 |
| 2 | Beach Villa | 🏖️ | 1,000 - 2,499 | 1,000 |
| 3 | Yacht Getaway | ⛵ | 2,500 - 4,999 | 2,500 |
| 4 | Mountain Penthouse | 🏔️ | 5,000 - 9,999 | 5,000 |
| 5 | Castle Retreat | 🏰 | 10,000+ | 10,000 |

**Floor Protection:** LP cannot drop below the floor of your current tier.

---

## Key Rules

### 1. Server Awards LP (NEVER Client)
LP is always awarded server-side when games complete:

```dart
// ❌ WRONG - causes double-counting
await LovePointService.awardPoints(amount: 30, reason: 'quiz');

// ✅ CORRECT - sync from server
await LovePointService.fetchAndSyncFromServer();
```

### 2. Shared Utility for LP Awards
All game APIs use the shared `awardLP` function:

```typescript
// In api/lib/lp/award.ts
export async function awardLP(
  coupleId: string,
  amount: number,
  reason: string,
  relatedId?: string
): Promise<void> {
  await query(
    `UPDATE couples SET total_lp = total_lp + $1 WHERE id = $2`,
    [amount, coupleId]
  );
  // Also insert transaction record for history
}
```

### 3. Sync After Game Completion
Every game completion screen must sync LP:

```dart
Future<void> _handleCompletion() async {
  // LP is server-authoritative - sync from server
  await LovePointService.fetchAndSyncFromServer();

  if (!mounted) return;
  Navigator.of(context).pushReplacement(ResultsScreen(...));
}
```

### 4. LP Counter Auto-Updates
Use callback pattern for automatic UI updates:

```dart
// In main.dart
LovePointService.setAppContext(context);

// In home screen
@override
void initState() {
  LovePointService.setLPChangeCallback(() {
    if (mounted) setState(() {});
  });
}
```

### 5. Pre-load for Returning Users
Prevent "0 LP" flash by pre-loading:

```dart
// In auth completion (auth_screen.dart or otp_verification_screen.dart)
if (result.isPaired) {
  await LovePointService.fetchAndSyncFromServer();  // Prevent flash
}
```

---

## Common Bugs & Fixes

### 1. LP Counter Shows 0
**Symptom:** Home screen shows 0 LP briefly before updating.

**Cause:** LP not pre-loaded before navigation.

**Fix:** Pre-load in auth completion:
```dart
await LovePointService.fetchAndSyncFromServer();
```

### 2. Double LP Awards
**Symptom:** LP increases by 60 instead of 30 for one game.

**Cause:** Client awarding LP locally AND server awarding.

**Fix:** Remove all client-side LP awards:
```dart
// Delete any calls like:
await LovePointService.awardPoints(...);
```

### 3. Partners Have Different LP
**Symptom:** One partner shows 500 LP, other shows 470 LP.

**Cause:** One device hasn't synced recently.

**Fix:** Both devices sync from same source:
```dart
// LP is couple-level, not per-user
await LovePointService.fetchAndSyncFromServer();
// Both get same value from couples.total_lp
```

### 4. LP Not Updating After Game
**Symptom:** Complete game but LP counter unchanged.

**Cause:** Callback not set or sync not called.

**Fix:** Ensure sync is called:
```dart
// In game completion handler
await LovePointService.fetchAndSyncFromServer();
```

### 5. Notification Banner Not Showing
**Symptom:** LP updates but no "+30 LP" banner.

**Cause:** App context not set.

**Fix:** Set context in main:
```dart
LovePointService.setAppContext(context);
```

---

## Debugging Tips

### Check LP State
```dart
final user = StorageService().getUser();
debugPrint('Local LP: ${user?.lovePoints}');
debugPrint('Tier: ${user?.arenaTier}');
```

### Force Sync
```dart
await LovePointService.fetchAndSyncFromServer();
final user = StorageService().getUser();
debugPrint('Synced LP: ${user?.lovePoints}');
```

### View API Response
```bash
curl "https://api-joakim-achrens-projects.vercel.app/api/sync/love-points" \
  -H "Authorization: Bearer <token>"
```

### Check Database
```sql
SELECT total_lp FROM couples WHERE id = 'couple-uuid';
```

---

## API Reference

### GET /api/sync/love-points
Get current LP for couple.

**Response:**
```json
{
  "success": true,
  "totalLp": 450
}
```

### POST /api/sync/love-points
Manual LP sync (rarely used).

**Response:** Same as GET.

---

## UI Components

### LP Counter
```dart
LPCounter(
  onTap: () => _showLPDetails(),
)
```

### LP Notification Banner
Auto-shown when LP changes:
```dart
ForegroundNotificationBanner.show(
  context: context,
  message: '+30 LP',
  icon: Icons.favorite,
  duration: Duration(seconds: 3),
);
```

### LP Intro Overlay
First-time explanation of LP system:
```dart
if (widget.showLpIntro) {
  LPIntroOverlay.show(context);
}
```

---

## File Reference

| File | Purpose |
|------|---------|
| `love_point_service.dart` | LP sync, tier calculation |
| `love_point_transaction.dart` | Transaction model |
| `lp_counter.dart` | Home screen LP display |
| `lp_intro_overlay.dart` | First-time LP explanation |
| `foreground_notification_banner.dart` | "+30 LP" toast |
| `award.ts` | Server-side LP award utility |
