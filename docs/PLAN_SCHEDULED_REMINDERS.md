# Plan: Scheduled Reminder Notifications

## Problem Statement

Currently, reminders are sent **immediately** regardless of the selected delivery time (Now, 1 Hour, 8 PM, 8 AM). The `scheduledFor` parameter is passed to the Cloud Function but not used for actual delayed delivery.

## Proposed Solution: Firebase Cloud Tasks

Use Google Cloud Tasks (integrated with Firebase Functions) to schedule delayed FCM notification delivery.

---

## Implementation Steps

### Step 1: Enable Cloud Tasks API

Run in terminal:
```bash
gcloud services enable cloudtasks.googleapis.com --project=togetherremind
```

### Step 2: Create Cloud Tasks Queue

```bash
gcloud tasks queues create reminder-queue --location=us-central1 --project=togetherremind
```

### Step 3: Update `functions/package.json`

Add Cloud Tasks dependency:
```json
{
  "dependencies": {
    "firebase-admin": "^13.6.0",
    "firebase-functions": "^6.6.0",
    "@google-cloud/tasks": "^5.5.0"
  }
}
```

### Step 4: Modify `functions/index.js`

**4a. Add a new `scheduleReminder` Cloud Function** that:
- Receives reminder data from Flutter app
- Calculates delay from `scheduledFor` timestamp
- If delay <= 0 (send now), calls `sendReminderNotification` directly
- If delay > 0, creates a Cloud Task with the scheduled time

**4b. Add a new `sendReminderNotification` HTTP endpoint** that:
- Receives the task payload when triggered by Cloud Tasks
- Sends the FCM notification (existing notification logic)
- This is what Cloud Tasks will call at the scheduled time

### Step 5: Update Flutter App

**5a. Modify `reminder_service.dart`:**
- Change callable function from `sendReminder` to `scheduleReminder`
- Pass timezone offset so server can correctly interpret local times

**5b. Update UI feedback in `send_reminder_screen.dart`:**
- Show appropriate message: "Reminder sent!" vs "Reminder scheduled for 8 PM"

---

## Code Changes Detail

### `functions/index.js` - New Functions

```javascript
const { CloudTasksClient } = require('@google-cloud/tasks');
const tasksClient = new CloudTasksClient();

const PROJECT_ID = 'togetherremind';
const LOCATION = 'us-central1';
const QUEUE_NAME = 'reminder-queue';

/**
 * Schedule a reminder for future delivery
 */
exports.scheduleReminder = functions.https.onCall(async (request) => {
  const { partnerToken, senderName, reminderText, reminderId, scheduledFor, timezoneOffset } = request.data;

  // Parse scheduled time
  const scheduledDate = new Date(scheduledFor);
  const now = new Date();
  const delayMs = scheduledDate.getTime() - now.getTime();

  // If scheduled for now or past, send immediately
  if (delayMs <= 60000) { // Within 1 minute
    return await sendReminderNow(partnerToken, senderName, reminderText, reminderId);
  }

  // Create Cloud Task for future delivery
  const parent = tasksClient.queuePath(PROJECT_ID, LOCATION, QUEUE_NAME);

  const task = {
    httpRequest: {
      httpMethod: 'POST',
      url: `https://${LOCATION}-${PROJECT_ID}.cloudfunctions.net/sendReminderNotification`,
      body: Buffer.from(JSON.stringify({
        partnerToken,
        senderName,
        reminderText,
        reminderId,
      })).toString('base64'),
      headers: {
        'Content-Type': 'application/json',
      },
    },
    scheduleTime: {
      seconds: Math.floor(scheduledDate.getTime() / 1000),
    },
  };

  const [response] = await tasksClient.createTask({ parent, task });

  return {
    success: true,
    scheduled: true,
    taskName: response.name,
    scheduledFor: scheduledFor,
  };
});

/**
 * HTTP endpoint called by Cloud Tasks to send the actual notification
 */
exports.sendReminderNotification = functions.https.onRequest(async (req, res) => {
  const { partnerToken, senderName, reminderText, reminderId } = req.body;

  // Send FCM notification (same logic as current sendReminder)
  const message = {
    token: partnerToken,
    notification: {
      title: `Reminder from ${senderName || 'Your Partner'}`,
      body: reminderText,
    },
    // ... rest of message config
  };

  await admin.messaging().send(message);
  res.status(200).send({ success: true });
});
```

### `app/lib/services/reminder_service.dart` - Changes

```dart
static Future<bool> sendReminder(Reminder reminder) async {
  // ... existing validation ...

  // Call Cloud Function to schedule the reminder
  final callable = _functions.httpsCallable('scheduleReminder');
  await callable.call({
    'partnerToken': partnerToken,
    'senderName': user.name ?? 'Your Partner',
    'reminderText': reminder.text,
    'reminderId': reminder.id,
    'scheduledFor': reminder.scheduledFor.toUtc().toIso8601String(), // UTC time
    'timezoneOffset': DateTime.now().timeZoneOffset.inMinutes,
  });

  // ... rest of method ...
}
```

---

## Alternative Approaches Considered

### Option A: Client-Side Local Notifications (NOT recommended)
- Use Flutter `flutter_local_notifications` to schedule locally
- **Problem**: Only works when app is installed; partner wouldn't receive it

### Option B: Firebase Scheduled Functions (NOT recommended)
- Use `functions.pubsub.schedule()`
- **Problem**: Designed for recurring tasks, not one-off scheduled events

### Option C: Firestore TTL + Trigger (Complex alternative)
- Store reminder in Firestore with TTL
- Use Firestore trigger on expiration
- **Problem**: More complex, less precise timing

**Chosen: Cloud Tasks** - Purpose-built for delayed job execution, precise timing, and integrates well with Firebase Functions.

---

## Timezone Handling

- Flutter app sends `scheduledFor` as **UTC ISO8601 string**
- Cloud Function calculates delay from current server time
- This ensures consistent behavior regardless of user timezone

---

## Deployment Steps

1. Enable Cloud Tasks API
2. Create reminder queue
3. Update `functions/package.json`
4. Run `cd functions && npm install`
5. Update `functions/index.js` with new functions
6. Deploy: `firebase deploy --only functions`
7. Update Flutter app with new service code
8. Build and deploy app

---

## Testing Plan

1. Test "Now" - should send immediately
2. Test "1 Hour" - set a reminder, wait 1 hour, verify delivery
3. Test "8 PM Tonight" - schedule for 8 PM, verify at 8 PM
4. Test "8 AM Tomorrow" - schedule overnight, verify in morning
5. Test timezone edge cases (user travels while reminder pending)

---

## Cost Considerations

- Cloud Tasks: First 1 million tasks/month free
- Firebase Functions: Standard billing applies when task triggers
- Expected usage: Very low (personal couple app)

---

## Rollback Plan

If issues occur, can revert to immediate sending by:
1. Changing Flutter app to call original `sendReminder` function
2. Original function still works for immediate delivery
