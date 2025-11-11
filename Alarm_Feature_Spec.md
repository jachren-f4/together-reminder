# ⏰ Couples App – iOS Alarm Feature Specification (AlarmKit Integration)

### Objective
Allow one partner (User A) to **trigger or schedule a system-level alarm** on the other partner’s iPhone (User B), using Apple’s **AlarmKit** (iOS 26 +).  
Both users must have the app installed and paired. The alarm rings on the receiver’s device even if the app is closed or the phone is locked.

---

## 1. System Overview

| Component | Purpose |
|------------|----------|
| **AlarmKit** | Native iOS 26 framework for third-party system alarms. |
| **Push Notifications (APNs)** | Used to send alarm requests from partner A → partner B. |
| **Local Handling** | Partner B’s app receives the push, validates it, and registers a local AlarmKit alarm. |
| **Token Exchange** | Push tokens are shared securely during pairing so each device can reach the other directly. |

No persistent backend database is required.

---

## 2. Data Flow

1. **Pairing**
   - App A and B exchange push tokens via QR or deep-link handshake.  
   - Each saves the partner’s token locally (`Keychain` preferred).

2. **Create Alarm**
   - User A selects:
     - Message (string)  
     - Time (ISO 8601)  
     - Optional sound / repeat toggle  
   - App A sends a **push notification** payload through a lightweight Cloud Function:
     ```json
     {
       "toToken": "<partner_push_token>",
       "type": "alarm_request",
       "message": "Wake up from your nap 😴",
       "time": "2025-11-06T16:45:00+02:00"
     }
     ```

3. **Receive Alarm Request**
   - App B receives `alarm_request` via APNs.  
   - Background push handler wakes the app and executes:
     ```swift
     AlarmCenter.shared.scheduleAlarm(
         identifier: UUID().uuidString,
         time: targetDate,
         title: "From \(partnerName)",
         message: message,
         sound: .default
     )
     ```
   - The alarm is registered in the system clock via **AlarmKit**, appearing in the Clock app if permitted.

4. **Trigger Time**
   - iOS presents full-screen AlarmKit alert (vibration + sound).  
   - Title = partner’s name; subtitle = message text.  
   - Buttons: **Dismiss**, **Snooze**, optional **❤️ Reply** (opens app).

---

## 3. Required Permissions

| Framework | Permission | Purpose |
|------------|-------------|----------|
| **AlarmKit** | `NSAlarmUsageDescription` in Info.plist | Explain why the app sets alarms. |
| **Push Notifications** | `UNUserNotificationCenter` | Receive partner alarm requests. |
| **Background Modes** | `remote-notification` | Allow handling alarm requests when app closed. |

---

## 4. Edge-Case Behavior

- **Expired Push Token:** prompt re-pairing.  
- **Do Not Disturb / Focus:** AlarmKit can override silent mode only if user allows in system settings.  
- **Timezone Shift:** store UTC and convert on schedule.  
- **iOS < 26:** fallback to local notification (no full alarm).

---

## 5. Security & Privacy

- Payloads contain only minimal text + timestamp.  
- Encrypt payload with AES before sending.  
- Partner identity stored locally; no central user DB.  
- Pair revocation removes stored tokens & cancels pending alarms.

---

## 6. Example Use Case

> **Scenario:** Partner A knows B is taking a nap.  
> A opens the app → sets alarm *“Wake up from your nap ❤️”* at 16:45 → sends.  
> At 16:45, Partner B’s iPhone rings as a full system alarm with the custom message and **❤️ Got it** button.

---

## 7. 🔍 App Store & Implementation Checklist

To comply with Apple requirements and ensure smooth App Store approval:

1. **Target iOS 26 +** to access AlarmKit APIs.  
2. **Include proper Info.plist keys:**
   - `NSAlarmUsageDescription` → explain clearly, e.g. *“Allows your partner to schedule gentle alarms for you.”*  
3. **Enable Background Modes** → `remote-notification`.  
4. **Register for Push Notifications** → `UNUserNotificationCenter` request authorization on first launch.  
5. **Describe Alarm Use in Review Notes** → specify alarms are user-initiated and consent-based (partner pairing required).  
6. **Test Edge Cases:**
   - Locked device  
   - Silent / Focus mode  
   - Device restart  
   - Network loss / expired tokens  
7. **No Additional Entitlement Needed** beyond these steps — AlarmKit is open to all developers as of iOS 26.  
8. **Be Transparent with Users:** onboarding screen explaining consent (partner can send alarms only if both have the app).

---
