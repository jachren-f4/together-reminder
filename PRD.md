# Couples Reminder App – Product Requirements Document (PRD)
**Date:** 2025-11-06  

## 1. Overview
**App Name (working title):** TogetherRemind  

### Purpose
Help couples send quick, caring reminders and nudges to each other’s phones — blending utility with emotional connection.

### Target Users
- Couples who want to stay coordinated (shared tasks, errands, support)
- Partners who want to send caring nudges, reminders, or love notes
- People who use reminder/timer apps and want a “couple mode” twist

### Value Proposition
> “Send your partner a reminder in seconds – no email, no calendar, no fuss.”

Builds connection and accountability via small interactions that show care.

---

## 2. Core Features (MVP)

### 1. Pairing / Linking
- Users connect via invite link, QR code, or short code.
- Once paired, both devices store each other’s ID locally.
- Minimal signup or authentication.

### 2. Send Reminder to Partner
- UI: “What to remind?” text field + quick time chips (“in 15 min”, “tomorrow morning”, etc.).
- Confirmation: “Reminder sent to [PartnerName].”
- Partner receives push notification with unique tone or animation.
- Receiver can tap “Done” or “Snooze”.

### 3. History Feed
- Shows sent and received reminders with timestamps and statuses.

### 4. Custom Notification & Vibe
- Unique sound or icon for partner reminders.
- Cute animations for sending events.

### 5. Optional Solo Mode
- Send reminders to self.

### 6. Settings
- Default reminder durations, sounds, unlink partner, privacy options.

---

## 3. Technical Considerations
- **No/Minimal Backend:** Device-to-device pairing + push via minimal relay (cloud function).
- **Push Notifications:** APNs (iOS) and FCM (Android).
- **Pairing:** Exchange push tokens via QR/deep link.
- **Storage:** Local database (Hive/SQLite/SwiftData).
- **Security:** Local encryption for reminder data.
- **UI:** Minimal, delightful, emoji-friendly interface.

---

## 4. Success Metrics
- Pairing completion rate
- Sent-to-received ratio
- 7- and 30-day retention
- Engagement (reminders/user/week)
- App Store rating ≥ 4.5

---

## 5. Roadmap

| Phase | Focus | Features |
|-------|--------|-----------|
| 1 | MVP | Pairing, reminders, notifications, feed |
| 2 | Delight | Voice input, animations, smart defaults |
| 3 | Expansion | Shared Pomodoro, widgets, family mode |

---

## 6. Name Ideas

| Name | Rationale |
|------|------------|
| **TogetherRemind** | Simple, emotional, direct |
| **CoupleNudge** | Playful and short |
| **RemindUs** | Inclusive and memorable |

**Availability:** Verify on App Store, domain, and social handles.

---

## 7. Next Steps
1. Run competitor and name availability checks.
2. Pick final name and reserve in App Store Connect.
3. Build wireframe prototype (onboarding → pairing → reminder → notification).
4. Implement push token pairing architecture.
5. Test with real couples.
6. Define monetization strategy.
7. Develop branding (colors, icon, tone).

---

## 8. Appendix
### Tech Stack Suggestion
- **Frontend:** Flutter
- **Storage:** Hive or Isar
- **Notifications:** Firebase Cloud Messaging / Apple Push Notification Service
- **Relay:** Cloud Function (optional, no database)
- **Encryption:** Local AES for reminder data

---

**Prepared for:** Joakim Achrén  
**Stage:** Concept / Pre-seed  
**User ID:** 110a3887-23ad-4c17-a0d4-775e06070dd3  
