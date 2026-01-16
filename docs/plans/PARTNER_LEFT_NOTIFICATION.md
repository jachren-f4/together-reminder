# Partner Left Notification Plan

**Context:** When a user deletes their account, their partner should see a message explaining what happened on their next app open.

---

## Overview

Store a one-time notification record when a user deletes their account. The partner's app checks for this on startup, shows the message, then clears it.

---

## Implementation Checklist

### Phase 1: Database

- [ ] Create `user_notifications` table in Supabase:
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

- [ ] Update `api/app/api/account/delete/route.ts` to notify partner:
  - Before deleting couple, insert notification for partner:
    ```typescript
    if (partnerId) {
      await client.query(
        `INSERT INTO user_notifications (user_id, type, message) VALUES ($1, $2, $3)`,
        [partnerId, 'partner_left', 'Your partner has left Us 2.0']
      );
    }
    ```

- [ ] Create `GET /api/user/notifications` endpoint:
  - Returns unread notifications for the authenticated user
  - Response: `{ notifications: [{ id, type, message, created_at }] }`

- [ ] Create `POST /api/user/notifications/dismiss` endpoint:
  - Marks notification as read (sets `read_at`)
  - Body: `{ notificationId: string }`

### Phase 3: Flutter App

- [ ] Create `NotificationCheckService` in `lib/services/`:
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

- [ ] Create `PartnerLeftDialog` widget in `lib/widgets/`:
  - Shows message: "Your partner has left Us 2.0"
  - Subtext: "You can pair with someone new to continue."
  - Single "OK" button that dismisses

- [ ] Update app startup flow (in `main.dart` or `app_bootstrap_service.dart`):
  - After user is authenticated and has no couple
  - Check for `partner_left` notification
  - If found, show `PartnerLeftDialog` before routing to pairing
  - On dismiss, call API to mark as read

### Phase 4: Edge Cases

- [ ] Handle case where partner also deletes before seeing notification (notification becomes orphaned - OK, just won't be shown)
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

## Files to Create/Modify

| File | Action |
|------|--------|
| Supabase | CREATE TABLE `user_notifications` |
| `api/app/api/account/delete/route.ts` | MODIFY - Insert partner notification |
| `api/app/api/user/notifications/route.ts` | CREATE - GET notifications |
| `api/app/api/user/notifications/dismiss/route.ts` | CREATE - POST dismiss |
| `app/lib/services/notification_check_service.dart` | CREATE |
| `app/lib/widgets/partner_left_dialog.dart` | CREATE |
| `app/lib/services/app_bootstrap_service.dart` | MODIFY - Check notifications |

---

## Estimated Effort

- Database: 5 min
- API endpoints: 30 min
- Flutter service + dialog: 30 min
- Integration: 15 min
- **Total: ~1.5 hours**
