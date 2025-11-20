# Dual-Write Architecture Design

**Phase:** 2 - Dual-Write Validation
**Status:** Draft
**Date:** 2025-11-19

---

## 1. Overview

The goal of this phase is to implement a **dual-write system** that writes data to both Firebase Realtime Database (RTDB) and PostgreSQL (Supabase) simultaneously. This ensures data consistency during the migration and allows for a safe, gradual cutover.

We will use **Daily Quests** as the pilot feature for this implementation.

## 2. Sync Strategy

We will adopt a **"Parallel Write, Firebase Primary"** strategy for Phase 2.

### Write Flow (Client-Side)

1.  **Optimistic Update:** Update local Hive storage and UI immediately.
2.  **Firebase Write:** Attempt to write to Firebase RTDB (existing logic).
3.  **Supabase Write:** Independently attempt to write to Supabase via Next.js API (new logic).
4.  **Error Handling:**
    *   If Firebase fails: The operation is considered failed (throw error).
    *   If Supabase fails: Log the error silently (do not block the user). This allows us to validate the new system without disrupting the old one.

### Read Flow

*   **Primary Source:** Continue reading from Firebase RTDB / Local Hive.
*   **Validation Source:** Fetch from Supabase in the background to compare data consistency.

## 3. Implementation Details: Daily Quests

### Modified `QuestSyncService`

The `QuestSyncService` currently handles Firebase syncing. We will enhance it to support dual-write.

```dart
class QuestSyncService {
  final FirebaseDatabase _firebase;
  final ApiClient _apiClient; // New Supabase API Client

  // ...

  Future<void> markQuestCompleted(...) async {
    // 1. Firebase Write (Existing)
    await _firebase.ref(...).update(...);

    // 2. Supabase Write (New)
    try {
      await _apiClient.post('/api/sync/daily-quests/completion', {
        'quest_id': questId,
        'user_id': userId,
        'partner_id': partnerUserId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log error but don't crash
      Logger.error('Supabase dual-write failed', error: e);
    }
  }
}
```

### New Next.js Endpoint

We need a new endpoint in the Next.js API to handle these writes.

*   **Endpoint:** `POST /api/sync/daily-quests/completion`
*   **Logic:**
    1.  Validate JWT.
    2.  Insert/Update `quest_completions` table in Supabase.
    3.  Handle idempotency (ignore duplicate requests).

## 4. Conflict Resolution

Since Firebase is still the primary source of truth, "conflicts" in this phase are actually **divergences**.

*   **Detection:** We will run a background job (or use the `Data Validation Dashboard` - Issue #9) to compare Firebase data vs. Supabase data.
*   **Resolution:** For Phase 2, we will not automatically resolve conflicts. We will log them to understand *why* they happened (e.g., race conditions, logic errors).

## 5. Rollback Strategy

If the dual-write implementation causes performance issues or crashes:

1.  **Feature Flag:** We will wrap the Supabase write logic in a feature flag (e.g., `ENABLE_SUPABASE_DUAL_WRITE`).
2.  **Disable:** If issues arise, we simply set this flag to `false` in the app (via remote config or hardcoded hotfix).
3.  **Data:** No data loss occurs because Firebase is still the primary store.

## 6. Success Criteria

*   [ ] `DailyQuestService` writes to both Firebase and Supabase.
*   [ ] Supabase writes do not block or fail the user experience.
*   [ ] Data consistency is > 99% after 24 hours of running.
