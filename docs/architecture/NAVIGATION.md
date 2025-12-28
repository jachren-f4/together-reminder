# Navigation Architecture

## Quick Reference

| Item | Location |
|------|----------|
| Auth Wrapper | `lib/widgets/auth_wrapper.dart` |
| Main Screen | `lib/screens/main_screen.dart` |
| Home Screen | `lib/screens/home_screen.dart` |
| Route Observer | `lib/widgets/daily_quests_widget.dart` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       TogetherRemindApp                          │
│                      (MaterialApp root)                          │
│                                                                  │
│   navigatorObservers: [questRouteObserver]                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        AuthWrapper                               │
│                   (Authentication routing)                       │
│                                                                  │
│   Unauthenticated → OnboardingScreen                            │
│   No name → NameEntryScreen                                     │
│   No partner → PairingScreen                                    │
│   Authenticated + paired → MainScreen                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        MainScreen                                │
│                   (Bottom navigation shell)                      │
│                                                                  │
│   Tab 0: HomeScreen (daily quests, side quests)                 │
│   Tab 1: ActivityHubScreen (inbox)                              │
│   Tab 2: ProfileScreen                                          │
│   Tab 3: SettingsScreen                                         │
│   Center: PokeBottomSheet (modal)                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Navigation Flow

### Auth Flow
```
OnboardingScreen
       │
       ▼ (Sign in/up)
AuthScreen
       │
       ▼ (OTP or dev bypass)
OtpVerificationScreen
       │
       ▼ (Verify or bypass)
NameEntryScreen
       │
       ▼ (Enter name)
PairingScreen
       │
       ▼ (Generate or enter code)
MainScreen
```

### Welcome Quiz Flow
```
PairingScreen
       │
       ▼ (Pairing complete)
WelcomeQuizIntroScreen
       │
       ▼ (Start quiz)
WelcomeQuizGameScreen
       │
       ▼ (Submit answers)
WelcomeQuizWaitingScreen
       │
       ▼ (Partner completes)
WelcomeQuizResultsScreen
       │
       ▼ (See results)
MainScreen(showLpIntro: true)
```

### Game Flow (Daily Quest)
```
HomeScreen
       │
       ▼ (Tap quest card)
QuizMatchGameScreen
       │
       ▼ (Submit answers)
QuizMatchWaitingScreen
       │
       ▼ (Partner completes)
QuizMatchResultsScreen
       │
       ▼ (See results)
HomeScreen (via pop)
```

### Side Quest Flow (Linked/Word Search)
```
HomeScreen
       │
       ▼ (Tap side quest)
LinkedIntroScreen / WordSearchIntroScreen
       │
       ▼ (Partner first dialog if applicable)
LinkedGameScreen / WordSearchGameScreen
       │
       ▼ (Turn by turn, polling)
LinkedResultsScreen / WordSearchResultsScreen
       │
       ▼ (Complete)
HomeScreen (via pop)
```

---

## Key Rules

### 1. Always Navigate to MainScreen (Not HomeScreen)
When navigating to home from results screens, use `MainScreen`:

```dart
// ✅ CORRECT - includes bottom nav
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const MainScreen(showLpIntro: true)),
);

// ❌ WRONG - missing bottom nav
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const HomeScreen()),
);
```

### 2. Use pushReplacement for Results → Home
Prevent back navigation to stale game states:

```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const MainScreen()),
);
```

### 3. Use PopScope for Blocking Screens
Prevent back navigation during critical flows:

```dart
PopScope(
  canPop: false,  // User cannot go back
  child: Scaffold(...),
)
```

Used in: `WelcomeQuizIntroScreen`, `WelcomeQuizGameScreen`, etc.

### 4. RouteAware for Refresh on Return
Refresh data when returning from pushed routes:

```dart
class _WidgetState extends State<Widget> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      questRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Returning from a pushed route
    _refreshData();
  }

  @override
  void dispose() {
    questRouteObserver.unsubscribe(this);
    super.dispose();
  }
}
```

### 5. Stop Polling Before Navigation
Cancel polling to prevent callbacks on disposed widgets:

```dart
void _navigateToResults() {
  cancelPolling();  // Stop first
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => ResultsScreen(...)),
  );
}
```

### 6. Pass showLpIntro for LP Introduction
After Welcome Quiz, pass flag to show LP introduction:

```dart
// In welcome_quiz_results_screen.dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (_) => const MainScreen(showLpIntro: true),
  ),
);
```

MainScreen hides bottom nav during LP intro overlay.

---

## Screen Types

### 1. Shell Screens
Contain navigation structure:
- `MainScreen` - Bottom navigation tabs
- `AuthWrapper` - Auth state routing

### 2. Content Screens
Display in tabs:
- `HomeScreen` - Daily quests, side quests
- `ActivityHubScreen` - Inbox
- `ProfileScreen` - User profile
- `SettingsScreen` - App settings

### 3. Flow Screens
Linear progression:
- Auth flow: `OnboardingScreen` → `AuthScreen` → `OtpVerificationScreen` → `NameEntryScreen` → `PairingScreen`
- Welcome quiz: `Intro` → `Game` → `Waiting` → `Results`
- Daily quest: `Game` → `Waiting` → `Results`
- Side quest: `Intro` → `Game` → `Results`

### 4. Modal Sheets
Overlays:
- `PokeBottomSheet` - Send pokes
- `RemindBottomSheet` - Send reminders
- `LeaderboardBottomSheet` - View leaderboard
- `DebugMenu` - Development tools

---

## Bottom Navigation

### Tabs
| Index | Screen | Icon |
|-------|--------|------|
| 0 | HomeScreen | Home |
| 1 | ActivityHubScreen | Inbox |
| - | PokeBottomSheet | Poke (center) |
| 2 | ProfileScreen | Profile |
| 3 | SettingsScreen | Settings |

### LP Intro Handling
Bottom nav is hidden when LP intro overlay is visible:

```dart
// In main_screen.dart
bottomNavigationBar: _lpIntroVisible ? null : Container(...)

// HomeScreen notifies parent via callback
widget.onLpIntroVisibilityChanged?.call(visible);
```

---

## Navigation Patterns

### Push (Add to stack)
```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => NewScreen()),
);
```

### Push Replacement (Replace current)
```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => NewScreen()),
);
```

### Pop (Go back)
```dart
Navigator.of(context).pop();
```

### Pop Until (Clear stack)
```dart
Navigator.of(context).popUntil((route) => route.isFirst);
```

### Show Modal
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => const PokeBottomSheet(),
);
```

---

## Common Bugs & Fixes

### 1. Missing Bottom Nav After Game
**Symptom:** Home screen shows without bottom navigation.

**Cause:** Navigated to `HomeScreen` instead of `MainScreen`.

**Fix:** Always navigate to `MainScreen`:
```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const MainScreen()),
);
```

### 2. Back Button Returns to Game
**Symptom:** User can go back to completed game.

**Cause:** Used `push` instead of `pushReplacement`.

**Fix:** Use `pushReplacement` from results:
```dart
Navigator.of(context).pushReplacement(...);
```

### 3. Quest Card Not Refreshing
**Symptom:** Quest shows old state after completing.

**Cause:** `didPopNext` not triggered or not subscribed.

**Fix:** Subscribe to route observer:
```dart
questRouteObserver.subscribe(this, route);
```

### 4. setState After Dispose
**Symptom:** Error "setState called after dispose".

**Cause:** Polling callback fires after navigation.

**Fix:** Stop polling before navigation:
```dart
cancelPolling();
Navigator.of(context).pushReplacement(...);
```

### 5. LP Intro Shows Again
**Symptom:** LP intro overlay shows on every tab switch.

**Cause:** `showLpIntro` flag not consumed.

**Fix:** Track consumption in MainScreen:
```dart
bool _lpIntroConsumed = false;
// Only pass to HomeScreen once
showLpIntro: widget.showLpIntro && !_lpIntroConsumed,
```

---

## File Reference

| File | Purpose |
|------|---------|
| `auth_wrapper.dart` | Auth state routing |
| `main_screen.dart` | Bottom navigation shell |
| `home_screen.dart` | Home tab content |
| `daily_quests_widget.dart` | Route observer definition |
| `*_intro_screen.dart` | Game intro screens |
| `*_game_screen.dart` | Game play screens |
| `*_waiting_screen.dart` | Partner wait screens |
| `*_results_screen.dart` | Game results screens |
