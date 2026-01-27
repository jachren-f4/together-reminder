# New Onboarding Flow Implementation Plan

## Overview

This document provides a detailed implementation plan for the new Us 2.0 onboarding flow. **The coding agent MUST follow the HTML mockups exactly** - both visually and interactively. Do not deviate from the mockups without explicit approval.

**Mockup Location:** `mockups/new-onboarding-flow/`

**Key Principle:** The HTML mockups are the source of truth. When implementing, open the HTML file in a browser and match it pixel-for-pixel.

---

## Table of Contents

1. [Flow Overview](#flow-overview)
2. [Screen-by-Screen Implementation](#screen-by-screen-implementation)
3. [Design System Reference](#design-system-reference)
4. [Technical Implementation Notes](#technical-implementation-notes)
5. [Migration Checklist](#migration-checklist)
6. [Testing Checklist](#testing-checklist)
7. [Debug Screen Browser](#debug-screen-browser)

---

## Flow Overview

### Complete User Journey

```
01. Value Carousel (NEW) ─────────────────────┐
    - 3 swipeable slides with video background │
    - "Get Started" → Name/Birthday            │
    - "Log in" → Existing auth flow            │
                                               ▼
04. Name + Birthday (NEW) ────────────────────┐
    - Collect first name + birthday            │
    - Store locally, sync after auth           │
                                               ▼
05. Email Entry (EXISTING - AuthScreen) ──────┐
    - No changes needed                        │
                                               ▼
06. OTP Verification (EXISTING) ──────────────┐
    - No changes needed                        │
                                               ▼
07. Anniversary Date (NEW) ───────────────────┐
    - Optional anniversary collection          │
    - Dynamic encouragement based on length    │
                                               ▼
08. Pairing Screen (EXISTING) ────────────────┐
    - No changes needed                        │
                                               ▼
09. Push Notifications (NEW) ─────────────────┐
    - Permission request with preview          │
    - Shows example notification mockup        │
                                               ▼
10-13. Welcome Quiz (EXISTING) ───────────────┐
    - Intro → Game → Waiting → Results         │
    - Keep exactly as-is (key differentiator)  │
                                               ▼
14. Value Proposition (NEW) ──────────────────┐
    - Benefits cards grid                      │
    - Shown AFTER LP intro, BEFORE paywall     │
                                               ▼
15. Paywall (EXISTING) ───────────────────────┐
    - No changes needed                        │
                                               ▼
16. Main Screen (EXISTING)
```

### Screen Status Legend

| Status | Meaning |
|--------|---------|
| **NEW** | Create from scratch using mockup |
| **EXISTING** | Keep as-is, no changes |
| **ENHANCED** | Modify existing screen |
| **MOVED** | Relocate in flow, possibly modify |

---

## Screen-by-Screen Implementation

### Screen 01: Value Carousel

**Status:** NEW
**Mockup:** `mockups/new-onboarding-flow/01-carousel.html`
**Flutter File:** `lib/screens/onboarding/value_carousel_screen.dart` (create new)

#### Visual Requirements

**CRITICAL: This screen has a VIDEO BACKGROUND. The video file is at:**
- Source: `app/assets/brands/us2/videos/splash.mp4`
- The video must autoplay, loop, and be muted

**Layout Structure:**
```
┌─────────────────────────────────┐
│  [Log in button - top right]    │
│                                 │
│      VIDEO BACKGROUND           │
│      (splash.mp4)               │
│                                 │
│  ┌───────────────────────────┐  │
│  │   Gradient Overlay        │  │
│  │   (dark at bottom)        │  │
│  ├───────────────────────────┤  │
│  │   Headline (swipeable)    │  │
│  │   Subheadline (swipeable) │  │
│  │                           │  │
│  │   ● ○ ○  (progress dots)  │  │
│  │                           │  │
│  │   [Get Started] button    │  │
│  │   [I already have...]     │  │
│  │                           │  │
│  │   Terms text              │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

**Gradient Overlay (MUST MATCH EXACTLY):**
```css
background: linear-gradient(
    180deg,
    rgba(0, 0, 0, 0.15) 0%,
    rgba(0, 0, 0, 0.05) 30%,
    rgba(0, 0, 0, 0.1) 50%,
    rgba(26, 20, 40, 0.8) 68%,
    rgba(26, 20, 40, 0.98) 100%
);
```

**Text Shadows (for readability over video):**
```css
/* Headline */
text-shadow:
    0 2px 4px rgba(0, 0, 0, 0.4),
    0 4px 12px rgba(0, 0, 0, 0.3),
    0 8px 24px rgba(0, 0, 0, 0.2);

/* Subheadline */
text-shadow:
    0 1px 3px rgba(0, 0, 0, 0.4),
    0 3px 8px rgba(0, 0, 0, 0.3),
    0 6px 16px rgba(0, 0, 0, 0.2);
```

**Slide Content (3 slides):**

| Slide | Headline | Subheadline |
|-------|----------|-------------|
| 1 | "Grow closer, one moment at a time" | "Dedicate a few minutes each day to connect with your partner through quick, fun activities." |
| 2 | "Play together, stay together" | "Discover each other through quizzes, puzzles, and daily challenges designed for couples." |
| 3 | "Two hearts, one journey" | "One subscription covers both of you. Share every activity, track your progress together." |

#### Interaction Requirements

**CRITICAL: All these interactions must be implemented:**

1. **Swipe Navigation:**
   - Horizontal swipe left/right to change slides
   - Drag threshold: 50px minimum to trigger slide change
   - Smooth transition: 0.4s ease-out
   - Elastic snap-back if swipe doesn't meet threshold

2. **Tap Navigation:**
   - Tap on LEFT third of screen → previous slide
   - Tap on RIGHT third of screen → next slide
   - Tap on MIDDLE third → no action (safe zone)
   - Tap detection: <200ms duration AND <10px movement

3. **Dot Navigation:**
   - Tappable dots below content
   - Active dot: wider (48px) with gradient fill
   - Inactive dots: 32px width, 30% white opacity

4. **Swipe Hint:**
   - Shows "Swipe →" text with animated arrow
   - Auto-hides after 4 seconds
   - Hides immediately on first user interaction

5. **Buttons:**
   - "Get Started" → Navigate to Name/Birthday screen
   - "I already have an account" → Navigate to existing AuthScreen (email entry)

6. **Log in Link:**
   - Top-right corner
   - Glassmorphism style (blur background)
   - → Navigate to existing AuthScreen

#### Flutter Implementation Notes

```dart
// Use PageView for swipeable slides
PageView.builder(
  controller: _pageController,
  onPageChanged: (index) => setState(() => _currentPage = index),
  itemCount: 3,
  itemBuilder: (context, index) => _buildSlide(index),
)

// Use video_player package for background video
VideoPlayerController.asset('assets/brands/us2/videos/splash.mp4')
  ..setLooping(true)
  ..setVolume(0)
  ..play();

// GestureDetector for tap zones
GestureDetector(
  onTapUp: (details) {
    final width = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;
    if (tapX < width * 0.33) {
      // Go previous
    } else if (tapX > width * 0.67) {
      // Go next
    }
  },
)
```

---

### Screen 04: Name + Birthday

**Status:** NEW
**Mockup:** `mockups/new-onboarding-flow/04-name-birthday.html`
**Flutter File:** `lib/screens/onboarding/name_birthday_screen.dart` (create new)

#### Visual Requirements

**Layout Structure:**
```
┌─────────────────────────────────┐
│                                 │
│   [Back arrow - top left]       │
│                                 │
│   "Let's get to know you"       │
│   (Playfair Display, 28px)      │
│                                 │
│   ┌───────────────────────────┐ │
│   │  Your first name          │ │
│   │  [Text input field]       │ │
│   └───────────────────────────┘ │
│                                 │
│   ┌───────────────────────────┐ │
│   │  Your birthday            │ │
│   │  [Date picker field]      │ │
│   │  "For birthday surprises" │ │
│   └───────────────────────────┘ │
│                                 │
│   (spacer)                      │
│                                 │
│   [Continue] button             │
│                                 │
└─────────────────────────────────┘
```

**Input Field Styling:**
- Background: white
- Border radius: 16px
- Padding: 20px
- Shadow: `0 4px 20px rgba(0,0,0,0.06)`
- Label: 12px, uppercase, letter-spacing 1.5px, gradient text
- Input text: 18px, #3A3A3A
- Helper text: 13px, #8A8A8A

**Date Picker:**
- Use native iOS/Android date picker
- Display format: "Month Day, Year" (e.g., "January 15, 1990")
- Placeholder: "Select your birthday"

#### Interaction Requirements

1. **Name Input:**
   - Auto-focus on screen load
   - Keyboard type: name
   - Auto-capitalize first letter

2. **Birthday Input:**
   - Tap to open date picker
   - Default to ~25 years ago
   - Min age: 13 years (legal requirement)
   - Max age: 120 years

3. **Continue Button:**
   - Disabled state until name is entered (birthday optional)
   - Store data locally (not yet authenticated)
   - Navigate to AuthScreen (email entry)

4. **Back Button:**
   - Navigate back to Value Carousel

#### Data Storage

```dart
// Store in SharedPreferences temporarily (pre-auth)
// Will be synced to server after authentication
await prefs.setString('pending_user_name', name);
await prefs.setString('pending_user_birthday', birthday.toIso8601String());

// After successful auth, sync to server and clear pending data
```

---

### Screen 07: Anniversary Date

**Status:** NEW
**Mockup:** `mockups/new-onboarding-flow/07-anniversary.html`
**Flutter File:** `lib/screens/onboarding/anniversary_screen.dart` (create new)

#### Visual Requirements

**Layout Structure:**
```
┌─────────────────────────────────┐
│                                 │
│   [Back arrow]     [Skip]       │
│                                 │
│      ♥ ♥  (two overlapping      │
│           heart SVGs)           │
│                                 │
│   "When did you become          │
│    a couple?"                   │
│   (Playfair Display, 28px)      │
│                                 │
│   ┌───────────────────────────┐ │
│   │  [Date picker field]      │ │
│   └───────────────────────────┘ │
│                                 │
│   ┌───────────────────────────┐ │
│   │  Dynamic encouragement    │ │
│   │  message based on length  │ │
│   └───────────────────────────┘ │
│                                 │
│   [Continue] button             │
│                                 │
└─────────────────────────────────┘
```

**Heart Illustration:**
- Two overlapping SVG hearts
- First heart: 60px, rotated -15deg
- Second heart: 70px, rotated 10deg, margin-left -20px
- Both filled with gradient (#FF6B6B → #FF9F43)

**Encouragement Card (appears after date selection):**
- Background: white
- Border-radius: 16px
- Padding: 20px
- Icon + text layout

**Dynamic Messages Based on Relationship Length:**

| Duration | Message |
|----------|---------|
| < 1 year | "A beautiful beginning! Let's make every moment count." |
| 1-3 years | "Still in the honeymoon phase! Keep that spark alive." |
| 3-7 years | "You've built something special. Let's keep growing together." |
| 7-15 years | "A love that stands the test of time. Here's to many more!" |
| 15+ years | "True love! Your dedication is inspiring." |

#### Interaction Requirements

1. **Skip Button:**
   - Top-right corner
   - Skips anniversary collection
   - Navigate to Pairing Screen

2. **Date Picker:**
   - Tap to open
   - Default to 1 year ago
   - Max date: today
   - Min date: 100 years ago

3. **Continue Button:**
   - Enabled after date selection
   - Store anniversary date
   - Navigate to Pairing Screen

---

### Screen 09: Push Notifications Permission

**Status:** NEW
**Mockup:** `mockups/new-onboarding-flow/09-notifications.html`
**Flutter File:** `lib/screens/onboarding/notification_permission_screen.dart` (create new)

#### Visual Requirements

**Layout Structure:**
```
┌─────────────────────────────────┐
│                                 │
│   [Back arrow]                  │
│                                 │
│   🔔 (bell icon, gradient)      │
│                                 │
│   "Never miss a moment"         │
│   (Playfair Display, 28px)      │
│                                 │
│   "Get notified when your       │
│    partner completes..."        │
│                                 │
│   ┌───────────────────────────┐ │
│   │  Example notification     │ │
│   │  preview card             │ │
│   └───────────────────────────┘ │
│                                 │
│   [Enable Notifications]        │
│   [Maybe Later]                 │
│                                 │
└─────────────────────────────────┘
```

**Example Notification Card:**
- Mimics iOS/Android notification appearance
- Shows: App icon, "Us 2.0", time, message
- Message: "Sarah just finished the daily quiz! Time to play together 💕"
- Subtle shadow and rounded corners

#### Interaction Requirements

1. **Enable Notifications:**
   - Request push notification permission
   - On success: Navigate to Welcome Quiz Intro
   - On denial: Navigate to Welcome Quiz Intro anyway (don't block)

2. **Maybe Later:**
   - Skip permission request
   - Navigate to Welcome Quiz Intro
   - Can request permission later from settings

#### Flutter Implementation Notes

```dart
// Use firebase_messaging for permission request
final messaging = FirebaseMessaging.instance;
final settings = await messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);

// Navigate regardless of permission result
Navigator.pushReplacement(context, WelcomeQuizIntroScreen());
```

---

### Screen 14: Value Proposition (Benefits Cards)

**Status:** NEW
**Mockup:** `mockups/new-onboarding-flow/14-comparison.html`
**Flutter File:** `lib/screens/onboarding/value_proposition_screen.dart` (create new)

**PLACEMENT: This screen goes AFTER the LP Intro overlay (shown on Welcome Quiz Results), BEFORE the Paywall.**

#### Visual Requirements

**Layout Structure:**
```
┌─────────────────────────────────┐
│                                 │
│   "WHAT YOU'LL GET" (tag)       │
│                                 │
│   "Everything you need to       │
│    fall in love again"          │
│   (Playfair, "again" = gradient │
│    italic)                      │
│                                 │
│   ┌───────────────────────────┐ │
│   │ Featured Card (full width)│ │
│   │ 💬 Daily conversation     │ │
│   │    starters               │ │
│   └───────────────────────────┘ │
│                                 │
│   ┌─────────┐ ┌─────────┐       │
│   │ ⭐      │ │ 🕐      │       │
│   │ Fun     │ │ 5 min/  │       │
│   │ games   │ │ day     │       │
│   └─────────┘ └─────────┘       │
│                                 │
│   ┌─────────┐ ┌─────────┐       │
│   │ ❤️      │ │ 👥      │       │
│   │ Love    │ │ Synced  │       │
│   │ Points  │ │ together│       │
│   └─────────┘ └─────────┘       │
│                                 │
│   [Get Started] button          │
│                                 │
└─────────────────────────────────┘
```

**Card Styling:**
- Background: white
- Border-radius: 20px
- Padding: 20px 16px
- Shadow: `0 4px 20px rgba(0,0,0,0.06)`
- Top accent line: 4px gradient bar (visible on featured, hover on others)

**Icon Containers:**
- Size: 56x56px (64x64 for featured)
- Border-radius: 16px
- Background: gradient at 12% opacity

**Grid Layout:**
- Featured card: spans full width (2 columns)
- Regular cards: 2-column grid
- Gap: 12px

**Floating Hearts (decorative):**
- 3 small heart SVGs
- Positioned absolutely
- Floating animation (4s ease-in-out infinite)
- Low opacity (0.3-0.6)

#### Benefit Cards Content

| Card | Icon | Title | Description |
|------|------|-------|-------------|
| Featured | Chat bubble | "Daily conversation starters" | "Fun questions that spark meaningful talks and help you learn something new about each other" |
| 1 | Star | "Fun games" | "Play together & grow closer" |
| 2 | Clock | "5 min/day" | "Small habit, big impact" |
| 3 | Heart | "Love Points" | "Track your journey together" |
| 4 | People | "Synced together" | "Always connected with your partner" |

#### Interaction Requirements

1. **Get Started Button:**
   - Navigate to Paywall screen
   - This is the final screen before paywall

2. **Card Hover Effect (optional for mobile):**
   - Top gradient bar fades in on hover
   - Subtle lift effect

---

## Design System Reference

### Colors (MUST USE EXACT VALUES)

```dart
// Us 2.0 Theme Colors - from us2_theme.dart
static const Color bgGradientStart = Color(0xFFFFD1C1);
static const Color bgGradientEnd = Color(0xFFFFF5F0);
static const Color primaryPink = Color(0xFFFF5E62);
static const Color gradientStart = Color(0xFFFF6B6B);
static const Color gradientEnd = Color(0xFFFF9F43);
static const Color cream = Color(0xFFFFF8F0);
static const Color textDark = Color(0xFF3A3A3A);
static const Color textMedium = Color(0xFF5A5A5A);
static const Color textLight = Color(0xFF707070);
```

### Typography

| Element | Font | Size | Weight | Color |
|---------|------|------|--------|-------|
| Headline | Playfair Display | 28px | 700 | textDark or white |
| Subheadline | Nunito | 15px | 400 | textMedium or white@85% |
| Body | Nunito | 14px | 400 | textMedium |
| Label | Nunito | 11-12px | 700 | gradient or textLight |
| Button | Nunito | 16-17px | 700 | white |

### Button Styles

**Primary Button:**
```dart
Container(
  padding: EdgeInsets.symmetric(vertical: 18),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Color(0xFFFF6B6B).withOpacity(0.4),
        blurRadius: 25,
        offset: Offset(0, 8),
      ),
    ],
  ),
)
```

**Secondary Button:**
```dart
Container(
  padding: EdgeInsets.symmetric(vertical: 18),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.2)),
  ),
)
```

### Progress Dots

```dart
// Active dot
Container(
  width: 48,
  height: 4,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
    ),
    borderRadius: BorderRadius.circular(2),
  ),
)

// Inactive dot
Container(
  width: 32,
  height: 4,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.3),
    borderRadius: BorderRadius.circular(2),
  ),
)
```

---

## Technical Implementation Notes

### Navigation Flow Changes

**Current Flow (to be modified):**
```
OnboardingScreen → AuthScreen → OTPScreen → PairingScreen →
WelcomeQuizIntro → WelcomeQuizGame → WelcomeQuizWaiting →
WelcomeQuizResults (with LP intro) → PaywallScreen → MainScreen
```

**New Flow:**
```
ValueCarouselScreen → NameBirthdayScreen → AuthScreen → OTPScreen →
AnniversaryScreen → PairingScreen → NotificationPermissionScreen →
WelcomeQuizIntro → WelcomeQuizGame → WelcomeQuizWaiting →
WelcomeQuizResults (with LP intro) → ValuePropositionScreen →
PaywallScreen → MainScreen
```

### Files to Create

| File | Screen |
|------|--------|
| `lib/screens/onboarding/value_carousel_screen.dart` | 01 |
| `lib/screens/onboarding/name_birthday_screen.dart` | 04 |
| `lib/screens/onboarding/anniversary_screen.dart` | 07 |
| `lib/screens/onboarding/notification_permission_screen.dart` | 09 |
| `lib/screens/onboarding/value_proposition_screen.dart` | 14 |

### Files to Modify

| File | Change |
|------|--------|
| `lib/main.dart` | Update initial route logic |
| `lib/screens/onboarding_screen.dart` | May be replaced by ValueCarouselScreen |
| `lib/screens/welcome_quiz_results_screen.dart` | Navigate to ValuePropositionScreen instead of PaywallScreen |

### Data to Store Pre-Auth

Before authentication, store in SharedPreferences:
- `pending_user_name` (String)
- `pending_user_birthday` (String, ISO8601)

After successful auth, sync to server:
- Update user profile with name and birthday
- Clear pending data from SharedPreferences

### Data to Store Post-Auth

Store anniversary date:
- In Hive (local): `StorageService().saveAnniversaryDate(date)`
- Sync to server: API call to update couple data

---

## Migration Checklist

### Before Starting
- [ ] Read ALL mockup HTML files in browser
- [ ] Compare mockups to current app screens
- [ ] Identify exact differences

### Implementation Order
1. [x] **Create OnboardingScreenBrowser** (debug tool - do this FIRST) ✅
2. [x] Create ValueCarouselScreen (01) with `previewMode` support ✅
3. [x] Create NameBirthdayScreen (04) with `previewMode` support ✅
4. [x] Create AnniversaryScreen (07) with `previewMode` support ✅
5. [x] Create NotificationPermissionScreen (09) with `previewMode` support ✅
6. [x] Create ValuePropositionScreen (14) with `previewMode` support ✅
7. [x] Add Onboarding tab to Debug Menu for easy access ✅
8. [x] Update navigation flow in app ✅
9. [x] Update WelcomeQuizResults to navigate to ValueProposition ✅
10. [ ] Test complete flow end-to-end

### Per-Screen Checklist
For EACH new screen, verify:
- [ ] Colors match mockup exactly
- [ ] Fonts match mockup exactly
- [ ] Spacing/padding matches mockup
- [ ] Animations work as specified
- [ ] All interactions implemented
- [ ] Navigation works correctly
- [ ] Back button behavior correct
- [ ] Data storage working

---

## Testing Checklist

### Happy Path
- [ ] New user: Carousel → Name → Email → OTP → Anniversary → Pairing → Notifications → Quiz → Value Prop → Paywall → Main
- [ ] Returning user: "Log in" → Email → OTP → Main

### Edge Cases
- [ ] Skip anniversary → flow continues
- [ ] Deny notifications → flow continues
- [ ] Back button on each screen
- [ ] App kill and resume at each step
- [ ] Slow network conditions
- [ ] Keyboard behavior on input screens

### Visual QA
- [ ] Compare each screen to mockup side-by-side
- [ ] Test on iPhone SE (small screen)
- [ ] Test on iPhone 14 Pro Max (large screen)
- [ ] Test on Android (Pixel 5)
- [ ] Test in dark mode (if applicable)
- [ ] Test with system font size changes

---

## Debug Screen Browser

### Purpose

To enable easy testing of all new onboarding screens without going through the full user flow (creating accounts, pairing, etc.), we need a debug screen browser accessible from the main screen.

### Access Method

**Double-tap the TOP-LEFT corner of the home screen** (where the greeting text is) to open the Onboarding Screen Browser.

This should be added to the existing debug menu system OR as a separate quick-access feature.

### Implementation

**File to create:** `lib/widgets/debug/tabs/onboarding_preview_tab.dart`

**Or add to existing debug menu:** `lib/widgets/debug/debug_menu.dart`

#### Screen Browser UI

```
┌─────────────────────────────────┐
│                                 │
│   Onboarding Screen Browser     │
│   (Debug Mode)                  │
│                                 │
│   ┌───────────────────────────┐ │
│   │ 01. Value Carousel        │ │
│   │     Video + swipeable     │→│
│   └───────────────────────────┘ │
│                                 │
│   ┌───────────────────────────┐ │
│   │ 04. Name + Birthday       │ │
│   │     Personal info input   │→│
│   └───────────────────────────┘ │
│                                 │
│   ┌───────────────────────────┐ │
│   │ 07. Anniversary Date      │ │
│   │     Relationship context  │→│
│   └───────────────────────────┘ │
│                                 │
│   ┌───────────────────────────┐ │
│   │ 09. Push Notifications    │ │
│   │     Permission request    │→│
│   └───────────────────────────┘ │
│                                 │
│   ┌───────────────────────────┐ │
│   │ 14. Value Proposition     │ │
│   │     Benefits cards        │→│
│   └───────────────────────────┘ │
│                                 │
│   ────────────────────────────  │
│   Complete Flow (All Screens)  →│
│                                 │
└─────────────────────────────────┘
```

#### Flutter Implementation

```dart
// lib/widgets/debug/onboarding_screen_browser.dart

import 'package:flutter/material.dart';

class OnboardingScreenBrowser extends StatelessWidget {
  const OnboardingScreenBrowser({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding Screen Browser'),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'DEBUG MODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap any screen to preview it individually.\n'
            'Screens run in preview mode (no data saved).',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _buildScreenTile(
            context,
            number: '01',
            title: 'Value Carousel',
            subtitle: 'Video background + 3 swipeable slides',
            screen: () => const ValueCarouselScreen(previewMode: true),
            isNew: true,
          ),

          _buildScreenTile(
            context,
            number: '04',
            title: 'Name + Birthday',
            subtitle: 'Personal info collection',
            screen: () => const NameBirthdayScreen(previewMode: true),
            isNew: true,
          ),

          _buildScreenTile(
            context,
            number: '07',
            title: 'Anniversary Date',
            subtitle: 'Relationship context + encouragement',
            screen: () => const AnniversaryScreen(previewMode: true),
            isNew: true,
          ),

          _buildScreenTile(
            context,
            number: '09',
            title: 'Push Notifications',
            subtitle: 'Permission request with preview',
            screen: () => const NotificationPermissionScreen(previewMode: true),
            isNew: true,
          ),

          _buildScreenTile(
            context,
            number: '14',
            title: 'Value Proposition',
            subtitle: 'Benefits cards grid',
            screen: () => const ValuePropositionScreen(previewMode: true),
            isNew: true,
          ),

          const Divider(height: 40),

          _buildScreenTile(
            context,
            number: '→',
            title: 'Complete Flow Preview',
            subtitle: 'Run through all screens in sequence',
            screen: () => const ValueCarouselScreen(previewMode: true),
            isNew: false,
            isFlow: true,
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTile(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
    required Widget Function() screen,
    required bool isNew,
    bool isFlow = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: isFlow
                ? const LinearGradient(
                    colors: [Color(0xFF6B8AFF), Color(0xFF43C6FF)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                  ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isNew) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen()),
          );
        },
      ),
    );
  }
}
```

#### Preview Mode for Each Screen

Each new screen should accept a `previewMode` parameter:

```dart
class ValueCarouselScreen extends StatefulWidget {
  final bool previewMode;

  const ValueCarouselScreen({
    super.key,
    this.previewMode = false,
  });

  // ...
}
```

**When `previewMode: true`:**
- Navigation buttons show a "Back to Browser" option instead of real navigation
- Data is NOT saved to storage
- Permission requests are skipped (just show UI)
- Shows a small "PREVIEW MODE" indicator at the top

```dart
// In each screen's build method:
if (widget.previewMode) {
  return Stack(
    children: [
      _buildScreenContent(),
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'PREVIEW MODE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
```

#### Adding to Home Screen

Add double-tap gesture to the greeting area in `home_screen.dart`:

```dart
// In lib/screens/home_screen.dart or lib/widgets/brand/us2/us2_home_content.dart

GestureDetector(
  onDoubleTap: () {
    // Only in debug mode
    if (kDebugMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardingScreenBrowser(),
        ),
      );
    }
  },
  child: _buildGreetingSection(), // existing greeting widget
)
```

### Checklist for Debug Browser

- [x] Create `OnboardingScreenBrowser` widget ✅
- [x] Add `previewMode` parameter to all 5 new screens ✅
- [x] Implement preview mode behavior (no data save, back button) ✅
- [x] Add "PREVIEW MODE" indicator banner ✅
- [x] Added Onboarding tab to Debug Menu (double-tap Us2 logo) ✅
- [x] Test each screen can be opened individually ✅
- [ ] Test "Complete Flow" option works

### Usage Instructions

1. **Open the app** and navigate to the home screen
2. **Double-tap the top-left corner** (greeting area)
3. **Tap any screen** to preview it
4. **Use back button** to return to the browser
5. **Tap "Complete Flow"** to test all screens in sequence

This allows you to:
- Test individual screens without full onboarding
- Compare screens to HTML mockups easily
- Report specific issues per screen
- Iterate quickly during development

---

## Important Reminders for Coding Agent

1. **CREATE DEBUG BROWSER FIRST** - Before implementing screens, create the OnboardingScreenBrowser so screens can be tested individually
2. **ADD previewMode TO ALL NEW SCREENS** - Every new screen must accept `previewMode` parameter for debug testing
3. **ALWAYS open the HTML mockup in a browser** before implementing each screen
4. **Match colors EXACTLY** - use the hex values from this doc, not approximations
5. **Match spacing EXACTLY** - padding, margins, gaps should be pixel-perfect
6. **Implement ALL interactions** - swipe, tap, animations, transitions
7. **Test navigation** - every button should go to the correct screen
8. **Don't skip the video** - Screen 01 MUST have the video background
9. **Don't skip animations** - floating hearts, swipe hint, progress dots
10. **Store data correctly** - pre-auth data goes to SharedPreferences, post-auth to Hive/server
11. **Keep existing screens unchanged** - AuthScreen, OTPScreen, PairingScreen, WelcomeQuiz screens
12. **Place ValueProposition correctly** - AFTER LP intro, BEFORE paywall

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-01-22 | 1.0 | Initial implementation plan |
| 2025-01-22 | 1.1 | Added Debug Screen Browser section for easy testing |
| 2026-01-22 | 2.0 | Implementation complete (screens 1-9 done) |

## Implementation Notes (2026-01-22)

### Files Created

| File | Purpose |
|------|---------|
| `lib/screens/onboarding/value_carousel_screen.dart` | Screen 01: Video carousel |
| `lib/screens/onboarding/name_birthday_screen.dart` | Screen 04: Name + birthday |
| `lib/screens/onboarding/anniversary_screen.dart` | Screen 07: Anniversary date |
| `lib/screens/onboarding/notification_permission_screen.dart` | Screen 09: Push notifications |
| `lib/screens/onboarding/value_proposition_screen.dart` | Screen 14: Benefits cards |
| `lib/widgets/debug/onboarding_screen_browser.dart` | Standalone debug browser |
| `lib/widgets/debug/tabs/onboarding_preview_tab.dart` | Debug menu tab |

### Files Modified

| File | Change |
|------|--------|
| `lib/screens/otp_verification_screen.dart` | New users → AnniversaryScreen (instead of PairingScreen) |
| `lib/screens/pairing_screen.dart` | After pairing → NotificationPermissionScreen (instead of WelcomeQuizIntro) |
| `lib/screens/welcome_quiz_results_screen.dart` | LP dismiss → ValuePropositionScreen (instead of PaywallScreen) |
| `lib/widgets/debug/debug_menu.dart` | Added Onboarding tab as first tab |

### Navigation Flow (Implemented)

```
ValueCarouselScreen → NameBirthdayScreen → AuthScreen → OTPScreen →
AnniversaryScreen → PairingScreen → NotificationPermissionScreen →
WelcomeQuizIntroScreen → WelcomeQuizGameScreen → WelcomeQuizWaitingScreen →
WelcomeQuizResultsScreen (with LP intro) → ValuePropositionScreen →
PaywallScreen → MainScreen
```

### Debug Access

Access the debug menu by double-tapping the Us2 logo on the home screen. The **Onboarding** tab is the first tab and allows previewing all new onboarding screens in preview mode.
