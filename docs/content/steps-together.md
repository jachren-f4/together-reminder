# Steps Together

## Overview

Steps Together is a side quest that tracks physical activity through step counting. Partners share their daily steps and work toward shared goals.

### How It Works

1. App connects to HealthKit (iOS) or Google Fit (Android)
2. Daily step counts are synced to the server
3. Partners can see each other's step progress
4. Shared goals create motivation and accountability

### Health-Based Connection

Unlike puzzle games, Steps Together connects the relationship to physical wellness:
- Encourages healthy habits
- Creates shared accountability
- Daily touchpoint through activity

---

## Value Proposition

**"Stay active together—even apart—by sharing your daily steps and supporting each other's health."**

### What Makes Steps Together Valuable

| Aspect | Value |
|--------|-------|
| Health motivation | External accountability helps maintain habits |
| Daily connection | Another reason to check in on your partner |
| Shared goals | Working toward something together |
| Non-competitive option | Support, not competition (though competition can be enabled) |

### The Goal

Through Steps Together, couples should:
- Stay more active knowing their partner can see
- Feel supported in health goals
- Have daily health as a shared conversation topic

---

## Features

### Step Tracking

| Feature | Description |
|---------|-------------|
| Daily sync | Steps automatically pulled from health APIs |
| Partner visibility | See your partner's steps for the day |
| Historical data | View past days' step counts |
| Progress indicators | Visual representation of daily goal progress |

### Goals & Rewards

| Feature | Description |
|---------|-------------|
| Daily goal | Configurable step target (default: 10,000) |
| Couple goal | Combined steps from both partners |
| LP rewards | Earn Love Points for hitting goals |

---

## LP Reward Structure

Steps Together awards LP based on goal completion:

| Achievement | LP Reward |
|-------------|-----------|
| Personal daily goal | 15 LP |
| Couple combined goal | 30 LP |

Note: LP claiming for steps uses a different pattern than other activities. See `lib/services/steps_service.dart` for details.

---

## Content Considerations

Unlike quiz-based activities, Steps Together doesn't have "content" to write. The value comes from:

1. **UI/UX Design**: Making step visualization engaging
2. **Notification Strategy**: Encouraging without nagging
3. **Goal Calibration**: Achievable but motivating targets
4. **Celebration Moments**: Acknowledging achievements

### Messaging Guidelines

| Context | Tone | Example |
|---------|------|---------|
| Goal achieved | Celebratory | "You both crushed it today!" |
| Partner ahead | Encouraging | "Your partner is at 8,000 steps—catch up!" |
| Behind on goal | Supportive | "Still time to get moving together" |
| Streak milestone | Proud | "7-day streak! You're building great habits" |

---

## Technical Reference

### Key Constraints

- **iOS HealthKit**: Requires explicit permission, may not always return data
- **Never gate on permissions**: Don't use `hasPermission()` for sync decisions—it's unreliable
- **Background sync**: Steps sync when app opens, not continuously

### File Locations

| Location | Purpose |
|----------|---------|
| `lib/services/steps_service.dart` | Step tracking and sync |
| `lib/widgets/steps/steps_quest_card.dart` | Steps UI component |
| `docs/features/STEPS_TOGETHER.md` | Feature documentation |

### Sync Pattern

```dart
// ✅ CORRECT: Check stored connection status
final connection = _storage.getStepsConnection();
if (connection?.isConnected != true) return null;

// ❌ WRONG: Don't rely on permission check
final hasPerms = await _health.hasPermissions([HealthDataType.STEPS]);
```

---

**Last Updated:** 2025-12-17
