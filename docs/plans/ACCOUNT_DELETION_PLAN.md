# Account Deletion Feature Plan

**Apple Guideline:** 5.1.1(v) - Data Collection and Storage
**Requirement:** Apps that support account creation must also offer account deletion.

---

## Overview

Add a "Delete Account" option to the Settings screen that permanently deletes the user's account and all associated data.

---

## User Flow

1. User navigates to **Settings → Account**
2. User taps **"Delete Account"** button (red, below Sign Out)
3. **Warning dialog** appears explaining:
   - This will permanently delete your account
   - All your data will be removed
   - Your partner will be unpaired
   - This action cannot be undone
4. User must type **"DELETE"** to confirm (prevents accidental deletion)
5. App calls API to delete account
6. On success: Clear local data, navigate to Onboarding screen
7. On failure: Show error message, allow retry

---

## Implementation Checklist

### Phase 1: API Endpoint
- [x] Create `DELETE /api/account/delete` endpoint in `api/app/api/account/delete/route.ts`
- [x] Verify user authentication via JWT
- [x] Delete user's data from all tables:
  - [x] `daily_quests` (user's quests)
  - [x] `quiz_matches` (user's matches)
  - [x] `linked_matches` (user's matches)
  - [x] `word_search_matches` (user's matches)
  - [x] `you_or_me_matches` (user's matches)
  - [x] `step_claims` (user's claims)
  - [x] `steps_daily` (user's steps)
  - [x] `lp_grants` (user's LP grants)
- [x] Update `couples` table:
  - [x] If user is `user1_id`: set `user1_id = NULL`
  - [x] If user is `user2_id`: set `user2_id = NULL`
  - [x] If both users NULL after update: delete couple row
- [x] Delete from `users` table
- [x] Delete from Supabase `auth.users`
- [x] Return success response

### Phase 2: Flutter UI (Settings Screen)
- [x] Add `_buildUs2DeleteAccountButton()` method in `settings_screen.dart`
- [x] Add button to ACCOUNT section (after Sign Out button)
- [x] Style: Red border, red text, trash icon
- [x] Add `_showDeleteAccountConfirmation()` dialog method
- [x] Dialog includes:
  - [x] Warning text explaining consequences
  - [x] TextField requiring user to type "DELETE"
  - [x] Cancel and Delete buttons
  - [x] Delete button disabled until "DELETE" typed
- [x] Add `_performAccountDeletion()` method
- [x] Call API endpoint
- [x] Show loading indicator during deletion
- [x] On success: Clear local data, navigate to OnboardingScreen
- [x] On error: Show error snackbar

### Phase 3: Partner Notification (Optional Enhancement)
- [ ] When account deleted, partner's next app open shows message
- [ ] Message: "Your partner has left Us 2.0"
- [ ] Partner returns to unpaired state (can re-pair with someone else)

### Phase 4: Testing
- [ ] Test deletion flow end-to-end
- [ ] Verify all database tables are cleaned
- [ ] Verify partner is properly unpaired
- [ ] Verify user cannot log back in after deletion
- [ ] Test error handling (network failure, etc.)

---

## Database Tables Affected

| Table | Action |
|-------|--------|
| `auth.users` | DELETE user row |
| `users` | DELETE user row |
| `couples` | SET user column to NULL, delete if both NULL |
| `daily_quests` | DELETE where user_id matches |
| `quiz_matches` | DELETE where user is participant |
| `linked_matches` | DELETE where user is participant |
| `word_search_matches` | DELETE where user is participant |
| `you_or_me_matches` | DELETE where user is participant |
| `step_claims` | DELETE where user_id matches |
| `steps_daily` | DELETE where user_id matches |
| `lp_grants` | DELETE where user_id matches |
| `subscriptions` | Keep (tied to couple, not user) |

---

## UI Mockup (Settings Screen - Account Section)

```
┌─────────────────────────────────────┐
│  ACCOUNT                            │
├─────────────────────────────────────┤
│  ✓ Email Verified                   │
│    user@example.com            ✓    │
├─────────────────────────────────────┤
│  ⎋ Sign Out                    ›    │
├─────────────────────────────────────┤
│  🗑 Delete Account             ›    │  ← NEW (red styling)
└─────────────────────────────────────┘
```

---

## Confirmation Dialog Mockup

```
┌─────────────────────────────────────┐
│         Delete Account?             │
├─────────────────────────────────────┤
│  This will permanently delete your  │
│  account and all your data.         │
│                                     │
│  • All quizzes and game progress    │
│  • Love Points and rewards          │
│  • Your partner will be unpaired    │
│                                     │
│  This cannot be undone.             │
│                                     │
│  Type DELETE to confirm:            │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│     [Cancel]    [Delete Account]    │
│                     (disabled)      │
└─────────────────────────────────────┘
```

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `api/app/api/account/delete/route.ts` | CREATE - API endpoint |
| `app/lib/screens/settings_screen.dart` | MODIFY - Add delete button and dialogs |
| `app/lib/services/api_client.dart` | MODIFY - Add delete method if needed |

---

## Estimated Effort

- API endpoint: ~1 hour
- Flutter UI: ~1 hour
- Testing: ~30 minutes
- **Total: ~2.5 hours**

---

## Security Considerations

1. Require valid JWT authentication
2. Verify user is deleting their own account (not someone else's)
3. Use database transaction to ensure atomic deletion
4. Log deletion for audit purposes (optional)
5. Rate limit endpoint to prevent abuse

---

## Notes

- This is a **hard delete**, not soft delete (per Apple requirements)
- User cannot recover account after deletion
- Partner keeps their account but becomes unpaired
- Subscription tied to couple remains (partner can still use if they subscribed)
