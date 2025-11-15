# TogetherRemind - Home Screen UI/UX Audit & Cleanup Plan

**Date:** 2025-11-14
**Scope:** Home screen analysis, consistency audit, and quick-win improvements
**Focus:** Unused elements, font inconsistencies, design system standardization

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current Architecture](#current-architecture)
3. [Critical Issues Found](#critical-issues-found)
4. [Detailed UI/UX Consistency Audit](#detailed-uiux-consistency-audit)
5. [Implementation Plan - Quick Wins](#implementation-plan---quick-wins)
6. [Additional Recommendations](#additional-recommendations)

---

## Executive Summary

### Key Findings

The TogetherRemind home screen is **functional and well-structured** but suffers from:
- **Unused/disabled features** visible to users (2 "Coming Soon" cards)
- **Font inconsistencies** (hardcoded fonts vs theme, varying sizes)
- **Design system gaps** (6+ border radius values, hardcoded colors)
- **Hardcoded values** ("2 new" inbox count, static text)
- **Visual hierarchy issues** (greeting too small, stats lack emphasis)

### Impact

These inconsistencies create a **less polished user experience** and make the codebase **harder to maintain**. Fixing them will:
- ✅ Remove confusion from disabled features
- ✅ Improve visual consistency and professionalism
- ✅ Make future development easier with standardized design tokens
- ✅ Enhance accessibility and readability

### Estimated Effort

**Quick Wins: 1-2 hours** of focused cleanup work

---

## Current Architecture

### File Structure

Your app uses **tab-based navigation** with the home screen split across two files:

1. **`lib/screens/home_screen.dart`** (129 lines)
   - Bottom navigation container
   - 5 tabs: Home, Inbox, Activities, Profile, Settings
   - Simple `setState()` for tab switching

2. **`lib/screens/new_home_screen.dart`** (829 lines)
   - Actual home content
   - Top section (avatars, greeting, stats)
   - Daily quests integration
   - Side quests grid
   - Pull-to-refresh functionality

### Main Components

**Top Section (lines 122-319)**
- Overlapping avatars (user + partner)
- Time-based greeting ("Good morning...")
- Partner name + days together
- Stats grid (Love Points, Streak, Match %)
- Action buttons (Poke, Remind)

**Daily Quests (lines 489-490)**
- Uses `DailyQuestsWidget` component
- Shows 3 daily quests with progress tracker
- Real-time partner completion sync via Firebase
- Auto-awards 30 LP when both complete

**Side Quests Grid (lines 511-765)**
- 3×3 grid of mini-activities
- Only Inbox is functional
- "Would You" and "Challenge" show "Coming Soon"

### Services Used

```dart
StorageService _storage         // Hive local storage
ArenaService _arenaService      // Love Points & arena progression
DailyPulseService _pulseService // Daily streak tracking
QuizService _quizService        // Quiz session management
LadderService _ladderService    // Word Ladder game state
MemoryFlipService _memoryService // Memory Flip game state
```

### Design System

**File:** `lib/config/app_theme.dart`

**Color System:**
- Primary Black: `#1A1A1A`
- Primary White: `#FFFEFD`
- Background Gray: `#FAFAFA`
- Border Light: `#F0F0F0`

**Typography:**
- Headlines: Playfair Display (serif, elegant)
- Body: Inter (sans-serif, modern)
- Material 3 design system

---

## Critical Issues Found

### 1. Love Points Counter Doesn't Auto-Update ⚠️

**Impact:** High (User Confusion)
**File:** `lib/screens/new_home_screen.dart:255`

**Problem:**
When users earn LP (e.g., completing a quest together), the counter at the top doesn't update until they navigate away and back. This is a **documented limitation** (see `CLAUDE.md:8-20`).

**Root Cause:**
- No reactive state management (using simple `setState()`)
- Service calls in build method read cached values
- LP awarded in background (Firebase listener)

**Current Workaround:**
Notification banner shows "+30 LP 💰" for 3 seconds as immediate feedback.

**Recommendation:**
Implement `ValueListenableBuilder` for Love Points to enable real-time updates.

---

### 2. Monolithic Widget (829 lines)

**Impact:** Medium (Developer Productivity)
**File:** `lib/screens/new_home_screen.dart`

**Problem:**
- All UI logic in one massive file
- Service calls scattered throughout build methods
- Hard to maintain, test, and navigate

**Recommendation:**
Refactor into smaller widgets:
- `HomeTopSection` (avatars, greeting, stats)
- `StatCard` (reusable component)
- `ActionButtons` (Poke/Remind)
- `SideQuestsGrid` (activity cards)

---

### 3. Hardcoded "2 new" Inbox Count

**Impact:** High (User Trust)
**File:** `lib/screens/new_home_screen.dart:698`

**Current Code:**
```dart
_buildSideQuestCard(
  emoji: '📝',
  title: 'Inbox',
  subtitle: '2 new',  // HARDCODED - never changes
  onTap: () => Navigator.push(...),
),
```

**Problem:**
Shows "2 new" regardless of actual inbox state. Users lose trust in the app's accuracy.

**Fix:**
```dart
final unreadCount = _activityService.getUnreadCount();
subtitle: unreadCount > 0 ? '$unreadCount new' : 'No new items',
```

---

### 4. Debug Dialog Accessible in Production

**Impact:** Medium (Security/UX)
**File:** `lib/screens/new_home_screen.dart:191-197`

**Current Code:**
```dart
GestureDetector(
  onDoubleTap: () {
    showDialog(
      context: context,
      builder: (context) => const DebugQuestDialog(),
    );
  },
  child: Text(_getGreeting(), ...),
),
```

**Problem:**
- Debug dialog shows Firebase RTDB data
- Accessible via double-tap on greeting (no visual indicator)
- Could confuse users or expose internal data

**Fix:**
```dart
onDoubleTap: kDebugMode ? () { /* debug dialog */ } : null,
```

---

## Detailed UI/UX Consistency Audit

### 1. UNUSED/DISABLED FEATURES

#### 1.1 Side Quests - Coming Soon Features

**File:** `lib/screens/new_home_screen.dart`
**Lines:** 704-716

**Current Implementation:**
```dart
_buildSideQuestCard(
  emoji: '💭',
  title: 'Would You',
  subtitle: 'Soon',
  onTap: null, // Coming soon
),
_buildSideQuestCard(
  emoji: '🎭',
  title: 'Challenge',
  subtitle: 'Daily',
  onTap: null, // Coming soon
),
```

**Problem:**
- Two disabled features visible to users
- No visual indication they're disabled beyond "Soon" subtitle
- Takes up valuable screen real estate
- Sets expectation that never gets met

**Recommendation:**
- **Option A:** Remove entirely until ready to launch
- **Option B:** Add visual disabled state (opacity: 0.5, grayscale filter)
- **Option C:** Add "COMING SOON" badge overlay with rounded corners

**Priority:** 🔴 High

---

#### 1.2 Activities Screen - Disabled Features

**File:** `lib/screens/activities_screen.dart`
**Lines:** 240-263

**Current Implementation:**
```dart
_buildActivityCard(
  emoji: '🎯',
  title: 'Timeline Challenge',
  lpRange: 'Coming Soon',
  isActive: false,
  onTap: null,
),
_buildActivityCard(
  emoji: '🎯',
  title: 'Daily Challenge',
  lpRange: 'Coming Soon',
  isActive: false,
  onTap: null,
),
```

**Problem:**
Two placeholder activities visible but non-functional.

**Recommendation:**
Remove from production build or use feature flag for beta testing.

**Priority:** 🟡 Medium

---

#### 1.3 Daily Pulse in Activity Hub

**File:** `lib/screens/activity_hub_screen.dart`
**Line:** 110

**Current Implementation:**
```dart
case ActivityType.dailyPulse:
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Daily Pulse coming soon!')),
  );
```

**Problem:**
Feature shows in activity feed but displays "coming soon" message when tapped.

**Recommendation:**
Filter out from activity feed if not implemented, or implement proper navigation.

**Priority:** 🟡 Medium

---

#### 1.4 Commented-Out Arena Progress Bar

**File:** `lib/screens/new_home_screen.dart`
**Lines:** 53-54, 351-483

**Current Implementation:**
```dart
// LP Progress bar removed per user request
// _buildArenaProgressSection(),

// ... 132 lines of unused method below ...
```

**Problem:**
- Large unused method still in codebase (132 lines)
- Unclear if temporary or permanent removal
- Clutters file and creates confusion

**Recommendation:**
- Remove method entirely if feature abandoned
- Or move to separate branch/file if planned to restore

**Priority:** 🟢 Low (cleanup)

---

### 2. FONT INCONSISTENCIES

#### 2.1 Mixed Font Usage - Quest Section Title

**File:** `lib/widgets/daily_quests_widget.dart`
**Lines:** 138-146

**Current Implementation:**
```dart
const Text(
  'Daily Quests',
  style: TextStyle(
    fontFamily: 'Playfair Display',  // ❌ Hardcoded instead of AppTheme
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: Colors.black,  // ❌ Should use AppTheme.textPrimary
  ),
),
```

**Problem:**
- Direct hardcoded font family instead of using design system
- Inconsistent with other sections that use `AppTheme.headlineFont`
- Makes future theme changes harder

**Fix:**
```dart
Text(
  'Daily Quests',
  style: AppTheme.headlineFont.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppTheme.textPrimary,
  ),
),
```

**Priority:** 🔴 High

---

#### 2.2 Inconsistent Section Header Sizing

**Current State Across Screens:**

| Location | Font | Size | Line |
|----------|------|------|------|
| "Side Quests" | `AppTheme.headlineFont` | 20px | `new_home_screen.dart:514` |
| "Daily Quests" | Hardcoded Playfair | 28px | `daily_quests_widget.dart:138` |
| "Activity Hub" | `AppTheme.headlineFont` | 32px | `activity_hub_screen.dart:169` |
| "Your Progress" | `AppTheme.headlineFont` | 32px | `profile_screen.dart:32` |

**Problem:**
Section headers have inconsistent sizing (20px vs 28px vs 32px) with no clear hierarchy.

**Recommendation:**
Standardize all major section headers to **28px** and define in theme:

```dart
// Add to app_theme.dart
static TextStyle get sectionHeader => headlineFont.copyWith(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
  color: textPrimary,
);
```

Then use consistently:
```dart
Text('Daily Quests', style: AppTheme.sectionHeader)
Text('Side Quests', style: AppTheme.sectionHeader)
```

**Priority:** 🔴 High

---

#### 2.3 Emoji Text Styles - No Font Family

**Files:** Multiple (`new_home_screen.dart`, `daily_quests_widget.dart`)
**Lines:** 165, 179, 290, 307, 634, 739

**Current Implementation:**
```dart
Text('💕', style: TextStyle(fontSize: 28))  // No fontFamily specified
Text('💎', style: TextStyle(fontSize: 20))
Text('💫', style: TextStyle(fontSize: 20))
```

**Problem:**
Emojis using default `TextStyle` without explicit font handling. Could cause rendering inconsistencies across platforms (iOS vs Android).

**Recommendation:**
Define consistent emoji style in theme:

```dart
// Add to app_theme.dart
static TextStyle emojiStyle(double size) => TextStyle(
  fontSize: size,
  fontFamily: null,  // Explicit system emoji font
);
```

**Priority:** 🟢 Low

---

### 3. DESIGN SYSTEM INCONSISTENCIES

#### 3.1 Border Width Variations

**File:** `lib/screens/new_home_screen.dart`

**Current Usage:**

| Element | Border Width | Line |
|---------|--------------|------|
| Avatar borders | 2px | 162, 176 |
| Active quest card | 3px | 625 |
| Inactive quest card | 2px | 625 |
| Side quest cards | 2px | 732 |
| Quest cards (quest_card.dart) | 2px | 42 |

**Problem:**
Inconsistent border widths (2px vs 3px) without clear pattern or purpose.

**Recommendation:**
```dart
// Define in app_theme.dart
static const double borderWidthStandard = 2.0;
static const double borderWidthActive = 3.0;
static const double borderWidthSubtle = 1.0;
```

**Priority:** 🟡 Medium

---

#### 3.2 Border Radius Variations

**File:** `lib/screens/new_home_screen.dart`

**Current Usage:**

| Element | Border Radius | Line |
|---------|---------------|------|
| Arena badges | 8px, 12px | 221, 427 |
| Stat cards | 10px | 326 |
| Quest carousel cards | 16px | 628 |
| Side quest cards | 12px | 734 |
| Reward badges | 5px | 667 |

**Problem:**
**5 different border radius values** (5px, 8px, 10px, 12px, 16px) with no clear hierarchy or system.

**Recommendation:**
```dart
// Define in app_theme.dart
static const double radiusSmall = 8.0;    // Badges, chips
static const double radiusMedium = 12.0;  // Small cards
static const double radiusLarge = 16.0;   // Main cards
static const double radiusXLarge = 20.0;  // Hero elements
```

Then replace:
```dart
// Before
BorderRadius.circular(10)  // Random value

// After
BorderRadius.circular(AppTheme.radiusMedium)  // Semantic value
```

**Priority:** 🔴 High

---

#### 3.3 Padding Inconsistencies

**File:** `lib/screens/new_home_screen.dart`

**Current Usage:**

| Element | Padding | Line |
|---------|---------|------|
| Top section | `fromLTRB(20, 16, 20, 20)` | 146 |
| Badge | `symmetric(horizontal: 8, vertical: 2)` | 218 |
| Stat card | `all(12)` | 323 |
| Quest card | `all(20)` | 621 |
| Reward badge | `symmetric(horizontal: 7, vertical: 2)` | 664 |
| Side quest | `all(16)` | 729 |

**Problem:**
- Inconsistent horizontal badge padding (7px vs 8px)
- Card padding varies (12px, 16px, 20px) without system

**Recommendation:**
```dart
// Define in app_theme.dart
static const EdgeInsets paddingSmall = EdgeInsets.all(12);
static const EdgeInsets paddingMedium = EdgeInsets.all(16);
static const EdgeInsets paddingLarge = EdgeInsets.all(20);
static const EdgeInsets paddingBadge = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 4,
);
```

**Priority:** 🟡 Medium

---

#### 3.4 Color Usage - Hardcoded Values

**File:** `lib/widgets/quest_card.dart`
**Lines:** 41, 63, 108, 130

**Current Implementation:**
```dart
border: Border.all(
  color: bothCompleted
    ? Colors.black  // ❌ Should use AppTheme.primaryBlack
    : const Color(0xFFF0F0F0),  // ❌ Hardcoded hex
),

// "Your Turn" badge
backgroundColor: const Color(0xFFF59E0B),  // ❌ Hardcoded orange

// "Expired" badge
backgroundColor: Colors.grey.shade400,  // ❌ Not in theme
```

**Problem:**
Mix of `AppTheme` colors and hardcoded hex values. Orange badge doesn't use existing `AppTheme.accentOrange`.

**Fix:**
```dart
border: Border.all(
  color: bothCompleted
    ? AppTheme.primaryBlack
    : AppTheme.borderLight,
),

// "Your Turn" badge
backgroundColor: AppTheme.accentOrange,

// "Expired" badge
backgroundColor: AppTheme.borderLight,  // Or define disabledGray
```

**Priority:** 🔴 High

---

#### 3.5 Activity Hub - Custom Color System

**File:** `lib/screens/activity_hub_screen.dart`
**Lines:** 325-338

**Current Implementation:**
```dart
Color _getTypeColor() {
  switch (activity.type) {
    case ActivityType.quiz:
      return const Color(0xFFF5E6D3); // Beige - not in theme
    case ActivityType.wordLadder:
      return const Color(0xFFE6DDF5); // Light purple - not in theme
    case ActivityType.poke:
      return const Color(0xFFFFE6F0); // Light pink - not in theme
    case ActivityType.reminder:
      return const Color(0xFFE6F3FF); // Light blue - not in theme
  }
}
```

**Problem:**
Entirely separate color palette not defined in design system. Impossible to maintain consistency.

**Recommendation:**
Add to `app_theme.dart`:

```dart
// Activity type colors
static const Color activityQuiz = Color(0xFFF5E6D3);
static const Color activityGame = Color(0xFFE6DDF5);
static const Color activitySocial = Color(0xFFFFE6F0);
static const Color activityReminder = Color(0xFFE6F3FF);
```

Then use:
```dart
case ActivityType.quiz: return AppTheme.activityQuiz;
case ActivityType.wordLadder: return AppTheme.activityGame;
```

**Priority:** 🟡 Medium

---

### 4. HARDCODED VS DYNAMIC VALUES

#### 4.1 Quest Titles - Static Logic

**File:** `lib/widgets/quest_card.dart`
**Lines:** 261-275

**Current Implementation:**
```dart
String _getQuizTitle(int sortOrder) {
  const titles = [
    'Getting to Know You',
    'Deeper Connection',
    'Understanding Each Other',
  ];

  if (sortOrder >= 0 && sortOrder < titles.length) {
    return titles[sortOrder];
  }

  return 'Relationship Quiz #${sortOrder + 1}';
}
```

**Problem:**
- Static array limits to 3 titles
- Falls back to generic "Relationship Quiz #4" after 3rd
- Comment says "will cycle through" but doesn't actually cycle

**Recommendation:**
Implement true cycling:
```dart
return titles[sortOrder % titles.length];
```

Or store titles in quiz question data for data-driven approach.

**Priority:** 🟢 Low

---

#### 4.2 Days Together Calculation

**File:** `lib/screens/new_home_screen.dart`
**Lines:** 128-131

**Current Implementation:**
```dart
int daysTogether = 1;  // Default to 1 if unpaired
if (user != null && partner != null) {
  daysTogether = DateTime.now().difference(partner.pairedAt).inDays + 1;
}
```

**Problem:**
Defaults to `1` if unpaired. Edge case handling unclear.

**Recommendation:**
```dart
final daysTogether = (user != null && partner != null)
    ? DateTime.now().difference(partner.pairedAt).inDays + 1
    : 0;  // Or hide the stat entirely if unpaired
```

**Priority:** 🟢 Low

---

#### 4.3 Quiz Match Percentage Display

**File:** `lib/screens/new_home_screen.dart`
**Lines:** 134-139

**Current Implementation:**
```dart
final completedSessions = _quizService.getCompletedSessions();
int quizMatch = 0;
if (completedSessions.isNotEmpty) {
  final lastSession = completedSessions.first;
  quizMatch = lastSession.matchPercentage ?? 0;
}
```

**Problem:**
- Shows match % from most recent quiz only (not average)
- Displays "0%" if no quizzes completed (misleading)
- No indication this is "last quiz" vs "average"

**Recommendation:**
```dart
// Option 1: Show "—" for no data
final quizMatch = completedSessions.isNotEmpty
    ? (completedSessions.first.matchPercentage ?? 0)
    : null;

// In UI:
Text(quizMatch != null ? '$quizMatch%' : '—')

// Option 2: Add subtitle
Text('Based on last quiz', style: caption)
```

**Priority:** 🟡 Medium

---

#### 4.4 Completion Banner - Static Text

**File:** `lib/widgets/daily_quests_widget.dart`
**Lines:** 270-308

**Current Implementation:**
```dart
Text(
  'Way to go! You\'ve completed your Daily Quests',
  style: TextStyle(...),
),
```

**Problem:**
Generic message with no personalization or context about LP earned.

**Recommendation:**
```dart
Text(
  'Amazing! You earned ${totalLPEarned} LP today 💰',
  style: TextStyle(...),
),
```

**Priority:** 🟢 Low (nice-to-have)

---

### 5. VISUAL HIERARCHY ISSUES

#### 5.1 Greeting Text Too Small

**File:** `lib/screens/new_home_screen.dart`
**Lines:** 200-203

**Current Implementation:**
```dart
Text(
  _getGreeting(),  // "Good morning, Joakim"
  style: AppTheme.headlineFont.copyWith(
    fontSize: 18,  // ❌ Too small for primary greeting
    fontWeight: FontWeight.w600,
  ),
),
```

**Problem:**
- Greeting is fontSize 18
- "Daily Quests" section header below is fontSize 28
- Greeting should be more prominent as primary user welcome

**Fix:**
```dart
style: AppTheme.headlineFont.copyWith(
  fontSize: 24,  // Match other primary headers
  fontWeight: FontWeight.w600,
),
```

**Priority:** 🟡 Medium

---

#### 5.2 Stat Card Values Need More Emphasis

**File:** `lib/screens/new_home_screen.dart`
**Lines:** 332-335

**Current Implementation:**
```dart
Text(
  value,  // "1250 LP", "7 days", "85%"
  style: AppTheme.headlineFont.copyWith(
    fontSize: 20,  // Same size as label below
    fontWeight: FontWeight.w600,
  ),
),
```

**Problem:**
- Stat values (Love Points: "1250") same size as labels below
- Profile screen shows LP as fontSize 42 (inconsistent)
- Numbers should be the focus, not the labels

**Comparison:**
- Home screen LP: 20px
- Profile screen LP: 42px

**Fix:**
```dart
style: AppTheme.headlineFont.copyWith(
  fontSize: 24,  // Make numbers more prominent
  fontWeight: FontWeight.w700,  // Bolder for emphasis
),
```

**Priority:** 🟡 Medium

---

#### 5.3 Side Quest Visual Weight Mismatch

**Files:**
- `new_home_screen.dart:634` - Main quest emoji = fontSize 46
- `new_home_screen.dart:739` - Side quest emoji = fontSize 30

**Context:**
Main Quests carousel was removed per user request (line 508 comment). Side quests now serve as primary activity navigation but styled as secondary.

**Problem:**
Visual hierarchy doesn't match functional importance.

**Recommendation:**
- Increase side quest emoji to fontSize 36-40
- Increase card padding from 16px to 20px
- Make cards more prominent now that they're primary navigation

**Priority:** 🟢 Low

---

#### 5.4 Quest Type Badge - No Visual Distinction

**File:** `lib/widgets/quest_card.dart`
**Lines:** 59-74

**Current Implementation:**
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: Colors.black,  // All badges use black
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    _getQuestTypeName(),  // "QUIZ", "WORD LADDER", etc.
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  ),
),
```

**Problem:**
- All quest type badges use black background
- No visual distinction between quest types
- Could use activity type colors from Activity Hub for consistency

**Recommendation:**
```dart
color: _getQuestTypeColor(),

Color _getQuestTypeColor() {
  switch (quest.type) {
    case QuestType.quiz: return AppTheme.activityQuiz;
    case QuestType.wordLadder: return AppTheme.activityGame;
    case QuestType.memoryFlip: return AppTheme.activityGame;
    default: return AppTheme.primaryBlack;
  }
}
```

**Priority:** 🟢 Low (nice-to-have)

---

### 6. ADDITIONAL ISSUES

#### 6.1 TODO Comments - Missing Navigation

**File:** `lib/widgets/daily_quests_widget.dart`
**Lines:** 318-332

**Current Implementation:**
```dart
case QuestType.wordLadder:
  // TODO: Navigate to Word Ladder screen
  break;

case QuestType.memoryFlip:
  // TODO: Navigate to Memory Flip screen
  break;

case QuestType.question:
  // TODO: Navigate to Question screen
  break;

case QuestType.game:
  // TODO: Navigate to Game screen
  break;
```

**Problem:**
Quest cards appear tappable but some types have no navigation implementation. Confusing UX.

**Investigation Needed:**
- Word Ladder screen exists at `lib/screens/word_ladder_game_screen.dart`
- Memory Flip screen exists at `lib/screens/memory_flip_game_screen.dart`

**Recommendation:**
Implement navigation for existing screens:
```dart
case QuestType.wordLadder:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WordLadderGameScreen(quest: quest),
    ),
  );
  break;
```

**Priority:** 🔴 High (broken functionality)

---

## Implementation Plan - Quick Wins

**Estimated Time:** 1-2 hours
**Approach:** Focus on highest-impact, lowest-effort changes

---

### Phase 1: Remove Unused/Disabled Elements (30 min)

#### Task 1.1: Clean Up Side Quests Grid
**File:** `lib/screens/new_home_screen.dart`

**Changes:**
1. Remove "Would You" card (lines 704-709)
2. Remove "Challenge" card (lines 710-715)
3. Convert 3×3 grid to vertical list or 1×3 row
4. Fix hardcoded "2 new" inbox count:

```dart
// Add method to get actual count
int _getInboxCount() {
  final activities = _storage.getActivities();
  return activities.where((a) => !a.isRead).length;
}

// Update card
_buildSideQuestCard(
  emoji: '📝',
  title: 'Inbox',
  subtitle: _getInboxCount() > 0
    ? '${_getInboxCount()} new'
    : 'No new items',
  onTap: () => Navigator.push(...),
),
```

**Priority:** 🔴 Critical

---

#### Task 1.2: Remove Debug Features from Production
**File:** `lib/screens/new_home_screen.dart`

**Change:**
```dart
// Add import at top
import 'package:flutter/foundation.dart' show kDebugMode;

// Update gesture detector (line 191)
GestureDetector(
  onDoubleTap: kDebugMode ? () {
    showDialog(
      context: context,
      builder: (context) => const DebugQuestDialog(),
    );
  } : null,
  child: Text(_getGreeting(), ...),
),
```

**Priority:** 🔴 Critical

---

#### Task 1.3: Delete Commented Code
**File:** `lib/screens/new_home_screen.dart`

**Changes:**
1. Delete lines 351-483 (unused `_buildArenaProgressSection()` method)
2. Delete comment on lines 53-54

**Priority:** 🟢 Low (cleanup)

---

### Phase 2: Fix Font Inconsistencies (20 min)

#### Task 2.1: Standardize Section Headers

**Step 1:** Add to `lib/config/app_theme.dart`:
```dart
static TextStyle get sectionHeader => headlineFont.copyWith(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
  color: textPrimary,
);
```

**Step 2:** Update `lib/widgets/daily_quests_widget.dart` (line 138):
```dart
Text(
  'Daily Quests',
  style: AppTheme.sectionHeader,  // Use theme constant
),
```

**Step 3:** Update `lib/screens/new_home_screen.dart` (line 514):
```dart
Text(
  'Side Quests',
  style: AppTheme.sectionHeader,  // Use theme constant
),
```

**Priority:** 🔴 High

---

#### Task 2.2: Fix Visual Hierarchy

**File:** `lib/screens/new_home_screen.dart`

**Change 1:** Increase greeting size (line 200):
```dart
style: AppTheme.headlineFont.copyWith(
  fontSize: 24,  // Was 18
  fontWeight: FontWeight.w600,
),
```

**Change 2:** Emphasize stat values (line 332):
```dart
style: AppTheme.headlineFont.copyWith(
  fontSize: 24,  // Was 20
  fontWeight: FontWeight.w700,  // Was w600
),
```

**Priority:** 🟡 Medium

---

### Phase 3: Design System Constants (25 min)

#### Task 3.1: Add Missing Theme Constants

**File:** `lib/config/app_theme.dart`

**Add these constants:**
```dart
// Border Radius
static const double radiusSmall = 8.0;    // Badges, chips
static const double radiusMedium = 12.0;  // Small cards
static const double radiusLarge = 16.0;   // Main cards

// Padding
static const EdgeInsets paddingSmall = EdgeInsets.all(12);
static const EdgeInsets paddingMedium = EdgeInsets.all(16);
static const EdgeInsets paddingLarge = EdgeInsets.all(20);
static const EdgeInsets paddingBadge = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 4,
);

// Activity Type Colors (from Activity Hub)
static const Color activityQuiz = Color(0xFFF5E6D3);
static const Color activityGame = Color(0xFFE6DDF5);
static const Color activitySocial = Color(0xFFFFE6F0);
static const Color activityReminder = Color(0xFFE6F3FF);
```

**Priority:** 🔴 High

---

#### Task 3.2: Replace Hardcoded Values

**Focus Areas:**

**File:** `lib/widgets/quest_card.dart`

Replace hardcoded colors:
```dart
// Line 41
border: Border.all(
  color: bothCompleted ? AppTheme.primaryBlack : AppTheme.borderLight,
),

// Line 63
backgroundColor: AppTheme.accentOrange,  // Was Color(0xFFF59E0B)
```

**File:** `lib/screens/new_home_screen.dart`

Replace border radius values:
```dart
// Line 326 (stat cards)
borderRadius: BorderRadius.circular(AppTheme.radiusMedium),

// Line 734 (side quest cards)
borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
```

**Priority:** 🟡 Medium

---

### Phase 4: Final Polish (15 min)

#### Task 4.1: Improve Quiz Match Display

**File:** `lib/screens/new_home_screen.dart`

**Update lines 134-139:**
```dart
final completedSessions = _quizService.getCompletedSessions();
final int? quizMatch = completedSessions.isNotEmpty
    ? (completedSessions.first.matchPercentage ?? 0)
    : null;

// In stat card (line 268):
_buildStatCard(
  label: 'Match',
  value: quizMatch != null ? '$quizMatch%' : '—',
),
```

**Priority:** 🟡 Medium

---

#### Task 4.2: Fix Quest Type Navigation TODOs

**File:** `lib/widgets/daily_quests_widget.dart`

**Replace TODOs with actual navigation (lines 318-332):**

```dart
case QuestType.wordLadder:
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WordLadderGameScreen(quest: quest),
    ),
  );
  if (result == true && mounted) setState(() {});
  break;

case QuestType.memoryFlip:
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MemoryFlipGameScreen(quest: quest),
    ),
  );
  if (result == true && mounted) setState(() {});
  break;

// For unimplemented types:
case QuestType.question:
case QuestType.game:
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Coming soon!')),
  );
  break;
```

**Priority:** 🔴 High

---

## Additional Recommendations

### Beyond Quick Wins (Future Improvements)

#### 1. Reactive Love Points Counter
**Effort:** 3-4 hours
**Impact:** High

Implement `ValueListenableBuilder` for real-time LP updates:

```dart
// In love_point_service.dart
final ValueNotifier<int> lovePointsNotifier = ValueNotifier(0);

void _updateLovePoints(int newValue) {
  lovePointsNotifier.value = newValue;
  // existing save logic
}

// In new_home_screen.dart
ValueListenableBuilder<int>(
  valueListenable: LovePointService.lovePointsNotifier,
  builder: (context, lovePoints, child) {
    return _buildStatCard(
      label: 'Love Points',
      value: lovePoints.toString(),
    );
  },
)
```

---

#### 2. Widget Refactoring
**Effort:** 4-6 hours
**Impact:** Medium (developer productivity)

Break down `new_home_screen.dart` into:
- `lib/widgets/home_top_section.dart`
- `lib/widgets/stat_card.dart`
- `lib/widgets/home_action_buttons.dart`
- `lib/widgets/side_quests_grid.dart`

---

#### 3. Error States & Empty States
**Effort:** 2-3 hours
**Impact:** Medium

Add proper error handling:
- Quest sync failures → Show retry button
- No quests available → Show empty state with illustration
- Partner disconnection → Show reconnecting indicator
- Network timeout → Show offline mode

---

#### 4. Accessibility
**Effort:** 2-3 hours
**Impact:** Medium

Add semantic labels:
```dart
Semantics(
  label: 'Love Points: $lovePoints',
  child: _buildStatCard(...),
)
```

---

#### 5. Performance Optimization
**Effort:** 1-2 hours
**Impact:** Low-Medium

- Add `const` constructors for static widgets
- Extract stat calculations to avoid rebuilding
- Memoize computed values (days together, match %)

---

## Summary

### Priority Matrix

| Priority | Count | Effort | Impact |
|----------|-------|--------|--------|
| 🔴 High | 8 | 1-2 hours | Immediate user/dev value |
| 🟡 Medium | 7 | 2-3 hours | Noticeable improvements |
| 🟢 Low | 6 | 1 hour | Polish & cleanup |

### Expected Outcomes

After implementing quick wins:
- ✅ Cleaner home screen (no unused placeholders)
- ✅ Consistent font usage across all headers
- ✅ Standardized design system (borders, spacing, colors)
- ✅ Better visual hierarchy (greeting and stats more prominent)
- ✅ Dynamic data instead of hardcoded values
- ✅ Production-ready (no debug features visible)
- ✅ Working navigation for all quest types

### Next Steps

1. Review this document
2. Approve quick wins plan
3. Execute Phase 1-4 sequentially
4. Test on both Android and iOS
5. Consider additional recommendations for future sprints

---

**Document Version:** 1.0
**Last Updated:** 2025-11-14
**Author:** Claude Code Analysis
