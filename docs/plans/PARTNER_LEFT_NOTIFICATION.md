# Partner Left Notification Plan

**Context:** When a user deletes their account, their partner should see a message explaining what happened on their next app open.

---

## Overview

Store a one-time notification record when a user deletes their account. The partner's app checks for this on startup, shows the message, then clears it.

---

## Implementation Checklist

### Phase 1: Database

- [x] Create `user_notifications` table in Supabase:
  ```sql
  CREATE TABLE user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
  );

  CREATE INDEX idx_user_notifications_user_id ON user_notifications(user_id);
  ```

### Phase 2: API Changes

- [x] Update `api/app/api/account/delete/route.ts` to delete couple entirely (DONE)
  - Changed from setting `user1_id`/`user2_id` to NULL (violated NOT NULL constraint)
  - Now deletes the couple row when user deletes account

- [x] Update `api/app/api/account/delete/route.ts` to notify partner:
  - Before deleting couple, insert notification for partner:
    ```typescript
    if (partnerId) {
      await client.query(
        `INSERT INTO user_notifications (user_id, type, message) VALUES ($1, $2, $3)`,
        [partnerId, 'partner_left', 'Your partner has left Us 2.0']
      );
    }
    ```

- [x] Create `GET /api/user/notifications` endpoint:
  - Returns unread notifications for the authenticated user
  - Response: `{ notifications: [{ id, type, message, created_at }] }`

- [x] Create `POST /api/user/notifications/dismiss` endpoint:
  - Marks notification as read (sets `read_at`)
  - Body: `{ notificationId: string }`

### Phase 3: Flutter App

- [x] Create `UserNotificationService` in `lib/services/`:
  ```dart
  class NotificationCheckService {
    Future<List<UserNotification>> checkForNotifications() async {
      // Call GET /api/user/notifications
    }

    Future<void> dismissNotification(String id) async {
      // Call POST /api/user/notifications/dismiss
    }
  }
  ```

- [x] Create `PartnerLeftDialog` widget in `lib/widgets/`:
  - Shows message: "Your partner has left Us 2.0"
  - Subtext: "You can pair with someone new to continue."
  - Single "OK" button that dismisses

- [x] Update app startup flow (in `pairing_screen.dart`):
  - PairingScreen checks for `partner_left` notification in initState
  - If found, shows `PartnerLeftDialog` before allowing pairing
  - On dismiss, calls API to mark as read

### Phase 4: Edge Cases

- [x] Handle case where partner also deletes before seeing notification (notification becomes orphaned - OK, just won't be shown)
- [ ] Clean up old notifications periodically (optional - add `created_at < NOW() - INTERVAL '30 days'` cleanup)

---

## User Flow

1. User A deletes their account
2. API inserts notification for User B (partner)
3. API deletes couple and User A's data
4. User B opens app
5. App detects no couple, checks for notifications
6. Finds `partner_left` notification
7. Shows dialog: "Your partner has left Us 2.0"
8. User B taps "OK"
9. App dismisses notification via API
10. App routes to pairing screen

---

## Files Created/Modified

| File | Action |
|------|--------|
| Supabase | CREATED TABLE `user_notifications` |
| `api/app/api/account/delete/route.ts` | MODIFIED - Insert partner notification |
| `api/app/api/user/notifications/route.ts` | CREATED - GET notifications |
| `api/app/api/user/notifications/dismiss/route.ts` | CREATED - POST dismiss |
| `app/lib/services/user_notification_service.dart` | CREATED |
| `app/lib/widgets/partner_left_dialog.dart` | CREATED |
| `app/lib/screens/pairing_screen.dart` | MODIFIED - Check notifications on mount |

---

## Estimated Effort

- Database: 5 min
- API endpoints: 30 min
- Flutter service + dialog: 30 min
- Integration: 15 min
- **Total: ~1.5 hours**
