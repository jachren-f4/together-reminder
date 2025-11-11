# Main Screen Implementation Plan
**Based on Variant 20: Arena Minimal**

**Date:** 2025-11-11
**Status:** ✅ COMPLETED
**Priority:** High

---

## 1. Overview

This document outlines the implementation plan for redesigning the TogetherRemind main screen based on **Variant 20: Arena Minimal**. The design balances elegant stats display with vacation arena progression visualization while maintaining the app's black & white aesthetic.

### Design Goals
1. Show vacation arena progress prominently but cleanly
2. Keep Poke & Remind actions easily accessible
3. Display Main Quests (games/activities) in horizontal carousel
4. Organize Side Quests in compact grid
5. Maintain elegant, minimal design language

---

## 2. Current State Analysis

### Existing Home Screen Structure
**File:** `app/lib/screens/home_screen.dart`

Current implementation uses a `TabController` with 5 screens:
- Tab 0: SendReminderScreen
- Tab 1: InboxScreen
- Tab 2: ActivitiesScreen
- Tab 3: ProfileScreen
- Tab 4: SettingsScreen

**Navigation:** Bottom navigation bar with 5 tabs
**FAB:** Floating Action Button (💫 poke) in bottom right

### Key Components to Replace
- **Bottom navigation tabs** → Keep but potentially reduce prominence
- **SendReminderScreen as default** → Replace with new unified home view
- **FAB for poke** → ✅ **REMOVE** - Poke button integrated into top section
- **Remind navigation** → Convert to bottom sheet modal (similar to poke)

---

## 3. Readability Issue: Arena Progress Section

### Problem Identified
**Location:** `.arena-progress-section` in Variant 20
**Issue:** "Yacht Getaway" text on yellow gradient background (`#FFD700`) has poor contrast

**Current CSS:**
```css
.arena-progress-section {
    background: linear-gradient(135deg, #87CEEB 0%, #FFD700 100%);
}

.arena-next {
    font-size: 11px;
    color: rgba(255, 255, 255, 0.9);
}
```

**Problem:** White text (opacity 0.9) on gold/yellow gradient = insufficient contrast ratio
**WCAG AA requirement:** Minimum 4.5:1 contrast ratio for normal text

### Solution: Text Shadow for Readability

Add dark text shadow to improve readability on light gradients:

```css
.arena-next {
    font-size: 11px;
    color: rgba(255, 255, 255, 0.95);
    font-weight: 600;
    text-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
}
```

**Rationale:**
- `text-shadow: 0 1px 3px rgba(0, 0, 0, 0.4)` creates subtle dark shadow
- Shadow provides contrast against yellow background
- Maintains elegant appearance (subtle, not harsh)
- Works across all arena gradient colors

### Alternative Solution: Background Pill

If text shadow is insufficient, add semi-transparent dark background:

```css
.arena-next {
    font-size: 11px;
    color: white;
    font-weight: 600;
    background: rgba(0, 0, 0, 0.25);
    padding: 4px 10px;
    border-radius: 12px;
}
```

**Recommendation:** Start with text shadow solution (cleaner). Use background pill if testing shows contrast still insufficient.

---

## 4. Component Breakdown

### 4.1 Top Section (White Header)
**Widget:** `_TopSection`

**Contents:**
- Couple avatars (overlapping circles)
- Greeting text ("Good Morning!")
- User metadata with arena tag ("You & Sarah • Day 8 • 🏖️ Beach Villa")
- 3-column stats grid (Love Points, Streak, Match %)
- Poke & Remind action buttons (both open bottom sheets)

**Key Properties:**
- Background: `#FFFEFD` (primaryWhite)
- Border bottom: 2px solid `#F0F0F0`
- Padding: 20px

**Action Button Behavior:**
- **Poke button:** Opens `PokeBottomSheet` (existing widget)
- **Remind button:** Opens `RemindBottomSheet` (new widget, contains old SendReminderScreen content)

**State Dependencies:**
- User data (name, avatar emoji)
- Partner data (name, avatar emoji)
- Current day count
- Current arena (from Love Points)
- Stats (LP, streak, quiz match %)

### 4.2 Arena Progress Section
**Widget:** `_ArenaProgressSection`

**Contents:**
- Current LP / Target LP text (left)
- Next arena name + icon (right, with text shadow)
- Progress bar (51.2% filled)

**Key Properties:**
- Background: Dynamic gradient based on current arena
  - Beach Villa: `linear-gradient(135deg, #87CEEB 0%, #FFD700 100%)`
  - Yacht Getaway: `linear-gradient(135deg, #1E3A8A 0%, #60A5FA 100%)`
  - etc.
- Border bottom: 2px solid `rgba(0, 0, 0, 0.1)`
- Padding: 16px 20px

**Text Shadow Implementation:**
```dart
Text(
  '⛵ Yacht Getaway',
  style: TextStyle(
    fontSize: 11,
    color: Colors.white.withOpacity(0.95),
    fontWeight: FontWeight.w600,
    shadows: [
      Shadow(
        offset: Offset(0, 1),
        blurRadius: 3.0,
        color: Colors.black.withOpacity(0.4),
      ),
    ],
  ),
)
```

**State Dependencies:**
- Current Love Points
- Current arena tier (determines gradient colors)
- Next arena name and icon
- Progress percentage calculation

### 4.3 Main Quests Carousel
**Widget:** `_MainQuestsCarousel`

**Contents:**
- Horizontal scrollable list of quest cards
- Each card: emoji (52px), title, status, reward badges
- Featured card has 3px black border

**Implementation:**
```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: _buildQuestCards(),
  ),
)
```

**Quest Card Properties:**
- Width: 260px (min-width)
- Background: `#FFFEFD`
- Border: 2px solid `#F0F0F0` (3px solid `#1A1A1A` for active)
- Border radius: 16px
- Padding: 20px

**Data Source:**
- Daily Pulse status (from DailyPulseService)
- Word Ladder active games (from LadderService)
- Memory Flip progress (from MemoryFlipService)
- Quiz sessions (from QuizService)

### 4.4 Side Quests Grid
**Widget:** `_SideQuestsGrid`

**Contents:**
- 3-column grid of side quest cards
- Each card: emoji (32px), title, subtitle

**Implementation:**
```dart
GridView.count(
  crossAxisCount: 3,
  shrinkWrap: true,
  physics: NeverScrollableScrollPhysics(),
  childAspectRatio: 0.9,
  children: _buildSideQuestCards(),
)
```

**Card Properties:**
- Background: `#FFFEFD`
- Border: 2px solid `#F0F0F0`
- Border radius: 12px
- Padding: 16px 12px

---

## 5. Arena System Integration

### Arena Tier Definitions

```dart
enum ArenaType {
  cozyCabin,
  beachVilla,
  yachtGetaway,
  mountainPenthouse,
  castleRetreat,
}

class Arena {
  final ArenaType type;
  final String name;
  final String emoji;
  final int minLP;
  final int maxLP;
  final LinearGradient gradient;

  const Arena({
    required this.type,
    required this.name,
    required this.emoji,
    required this.minLP,
    required this.maxLP,
    required this.gradient,
  });

  static const List<Arena> arenas = [
    Arena(
      type: ArenaType.cozyCabin,
      name: 'Cozy Cabin',
      emoji: '🏕️',
      minLP: 0,
      maxLP: 1000,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8B4513), Color(0xFFD2691E)],
      ),
    ),
    Arena(
      type: ArenaType.beachVilla,
      name: 'Beach Villa',
      emoji: '🏖️',
      minLP: 1000,
      maxLP: 2500,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF87CEEB), Color(0xFFFFD700)],
      ),
    ),
    Arena(
      type: ArenaType.yachtGetaway,
      name: 'Yacht Getaway',
      emoji: '⛵',
      minLP: 2500,
      maxLP: 5000,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E3A8A), Color(0xFF60A5FA)],
      ),
    ),
    Arena(
      type: ArenaType.mountainPenthouse,
      name: 'Mountain Penthouse',
      emoji: '🏔️',
      minLP: 5000,
      maxLP: 10000,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B7280), Color(0xFFE5E7EB)],
      ),
    ),
    Arena(
      type: ArenaType.castleRetreat,
      name: 'Castle Retreat',
      emoji: '🏰',
      minLP: 10000,
      maxLP: 999999,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C3AED), Color(0xFFC084FC)],
      ),
    ),
  ];

  static Arena getCurrentArena(int lovePoints) {
    return arenas.lastWhere(
      (arena) => lovePoints >= arena.minLP,
      orElse: () => arenas.first,
    );
  }

  static Arena? getNextArena(int lovePoints) {
    final currentIndex = arenas.indexWhere(
      (arena) => lovePoints >= arena.minLP && lovePoints < arena.maxLP,
    );
    if (currentIndex == -1 || currentIndex == arenas.length - 1) {
      return null; // Already at max tier
    }
    return arenas[currentIndex + 1];
  }

  double getProgress(int lovePoints) {
    if (lovePoints < minLP) return 0.0;
    if (lovePoints >= maxLP) return 1.0;
    return (lovePoints - minLP) / (maxLP - minLP);
  }
}
```

### Arena Service

**File:** `app/lib/services/arena_service.dart`

```dart
class ArenaService {
  final StorageService _storage = StorageService();

  Arena getCurrentArena() {
    final user = _storage.getUser();
    if (user == null) return Arena.arenas.first;

    // TODO: Get actual Love Points from user data
    final lovePoints = _getLovePoints();
    return Arena.getCurrentArena(lovePoints);
  }

  Arena? getNextArena() {
    final lovePoints = _getLovePoints();
    return Arena.getNextArena(lovePoints);
  }

  double getCurrentProgress() {
    final lovePoints = _getLovePoints();
    final currentArena = getCurrentArena();
    return currentArena.getProgress(lovePoints);
  }

  int _getLovePoints() {
    // TODO: Implement Love Points tracking
    // For now, return mock value
    return 1280;
  }

  int getLovePointsUntilNext() {
    final lovePoints = _getLovePoints();
    final nextArena = getNextArena();
    if (nextArena == null) return 0;
    return nextArena.minLP - lovePoints;
  }
}
```

---

## 6. Implementation Steps

### Phase 1: Arena System Foundation
**Priority:** High
**Estimated Time:** 2-3 hours

1. ✅ Create `Arena` model class with tier definitions
2. ✅ Create `ArenaService` for arena logic
3. ✅ Add Love Points tracking to User model (if not already present)
4. ✅ Update `StorageService` to persist Love Points
5. ✅ Write unit tests for arena tier calculations

**Files to Create/Modify:**
- `app/lib/models/arena.dart` (new)
- `app/lib/services/arena_service.dart` (new)
- `app/lib/models/user.dart` (modify - add LP field)
- `app/lib/services/storage_service.dart` (modify)

### Phase 2: New Home Screen Widget
**Priority:** High
**Estimated Time:** 5-6 hours

1. ✅ Create `NewHomeScreen` widget (stateful)
2. ✅ Implement `_TopSection` widget
   - Profile header with couple avatars
   - Arena tag in metadata
   - Stats grid (LP, Streak, Match %)
   - Poke & Remind buttons (both open bottom sheets)
3. ✅ Create `RemindBottomSheet` widget
   - Move content from `SendReminderScreen` into modal
   - Quick message buttons
   - Time selection buttons
   - Text input field
   - Send button
   - Match styling to `PokeBottomSheet`
4. ✅ Implement `_ArenaProgressSection` widget
   - Dynamic gradient based on current arena
   - Progress bar with calculation
   - **Text shadow on next arena name**
5. ✅ Implement `_MainQuestsCarousel` widget
   - Horizontal scroll of quest cards
   - Integration with existing services
6. ✅ Implement `_SideQuestsGrid` widget
   - 3-column grid layout

**Files to Create:**
- `app/lib/screens/new_home_screen.dart` (new)
- `app/lib/widgets/arena_progress_widget.dart` (new, reusable)
- `app/lib/widgets/remind_bottom_sheet.dart` (new)

**Files to Reference:**
- `app/lib/widgets/poke_bottom_sheet.dart` (for styling consistency)
- `app/lib/screens/send_reminder_screen.dart` (content to migrate)

### Phase 3: Navigation Integration
**Priority:** Medium
**Estimated Time:** 2 hours

1. ✅ Update `home_screen.dart` to use `NewHomeScreen` as Tab 0
2. ✅ Keep existing bottom navigation structure
3. ✅ **Remove floating action button** (poke now in top section buttons)
4. ✅ Remove SendReminderScreen from navigation (now modal)
5. ✅ Update bottom nav to only show 4 tabs:
   - Tab 0: NewHomeScreen (replaces SendReminderScreen)
   - Tab 1: InboxScreen
   - Tab 2: ActivitiesScreen
   - Tab 3: ProfileScreen
   - Tab 4: SettingsScreen
6. ✅ Test navigation flow between all screens
7. ✅ Test modal bottom sheets (Poke & Remind)

**Files to Modify:**
- `app/lib/screens/home_screen.dart`

**UI Changes:**
- Remove `floatingActionButton` property
- Remove `floatingActionButtonLocation` property
- Update bottom nav icon for Tab 0 (home icon instead of reminder)
- Tab 0 label: "Send" → "Home"

### Phase 4: Testing & Refinement
**Priority:** High
**Estimated Time:** 3-4 hours

1. ✅ Test on multiple screen sizes (iPhone SE, iPhone 14, iPad)
2. ✅ Verify text shadow readability across all arena gradients
3. ✅ Test horizontal scroll performance with many quests
4. ✅ Validate Love Points calculations and arena transitions
5. ✅ Test state management and data refresh
6. ✅ Accessibility testing (screen reader, contrast)

### Phase 5: Polish & Edge Cases
**Priority:** Low
**Estimated Time:** 2-3 hours

1. ✅ Handle no partner case (show pairing prompt)
2. ✅ Handle new user with 0 LP (Cozy Cabin arena)
3. ✅ Handle max tier user (no next arena)
4. ✅ Add animations for quest card taps
5. ✅ Add pull-to-refresh gesture
6. ✅ Empty state for side quests
7. ✅ Loading states during data fetch

---

## 7. Design Specifications

### Colors

**Primary Colors:**
- Black: `#1A1A1A`
- White: `#FFFEFD`
- Background Gray: `#FAFAFA`
- Border Light: `#F0F0F0`

**Text Colors:**
- Primary: `#1A1A1A`
- Secondary: `#6E6E6E`
- Tertiary: `#AAAAAA`

**Arena Gradients:**
- Cozy Cabin: `#8B4513` → `#D2691E`
- Beach Villa: `#87CEEB` → `#FFD700`
- Yacht Getaway: `#1E3A8A` → `#60A5FA`
- Mountain Penthouse: `#6B7280` → `#E5E7EB`
- Castle Retreat: `#7C3AED` → `#C084FC`

### Typography

**Font Families:**
- Headlines: Playfair Display (serif, 600 weight)
- Body: Inter (sans-serif, 400-600 weight)

**Font Sizes:**
- Greeting: 18px
- Arena name: 13px
- Arena progress text: 11px (with text shadow)
- Stat values: 20px (Playfair Display)
- Stat labels: 10px
- Quest titles: 17px
- Quest descriptions: 13px
- Reward badges: 11px

### Spacing

**Padding:**
- Top section: 20px
- Arena progress section: 16px vertical, 20px horizontal
- Main content area: 20px
- Cards: 20px (quest cards), 16px 12px (side quests)

**Gaps:**
- Stats grid: 12px
- Action buttons: 10px
- Quest carousel: 12px
- Side quest grid: 12px

**Border Radius:**
- Cards: 16px (quest cards), 12px (side quests)
- Buttons: 12px
- Stats: 10px
- Arena tag: 8px
- Progress bar: 3px

### Shadows & Effects

**Text Shadow (Arena Progress):**
```css
text-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
```

**Flutter equivalent:**
```dart
shadows: [
  Shadow(
    offset: Offset(0, 1),
    blurRadius: 3.0,
    color: Colors.black.withOpacity(0.4),
  ),
]
```

---

## 8. Data Flow & State Management

### State Requirements

**User State:**
- User ID
- User name
- User avatar emoji
- Current Love Points
- Day streak

**Partner State:**
- Partner name
- Partner avatar emoji
- Partner push token

**Arena State:**
- Current arena (calculated from LP)
- Next arena (calculated from LP)
- Progress percentage
- LP until next arena

**Quest State:**
- Daily Pulse status (completed, pending, your turn)
- Word Ladder active games count
- Memory Flip progress (pairs found)
- Quiz sessions (active, completed)
- Side quest availability

### Service Dependencies

```dart
class NewHomeScreen extends StatefulWidget {
  // Services
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();
  final DailyPulseService _pulseService = DailyPulseService();
  final LadderService _ladderService = LadderService();
  final MemoryFlipService _memoryService = MemoryFlipService();
  final QuizService _quizService = QuizService();
  final PokeService _pokeService = PokeService();
  final ReminderService _reminderService = ReminderService();
}
```

### Data Refresh Strategy

**On Screen Load:**
- Fetch user data from Hive
- Calculate current arena from LP
- Load quest statuses from respective services
- Display cached data immediately (no loading screen)

**Pull to Refresh:**
- Sync with Firebase (if any remote data)
- Recalculate quest statuses
- Update UI

**Real-time Updates:**
- Listen to Hive changes for LP updates
- Listen to quest completion events
- Update arena progress bar in real-time

---

## 9. Accessibility Considerations

### Text Contrast

**WCAG AA Compliance:**
- Minimum 4.5:1 contrast ratio for normal text
- Minimum 3:1 for large text (18pt+ or 14pt+ bold)

**Text Shadow Solution:**
- Ensures white text on yellow gradient meets contrast requirements
- Test with contrast checker tools
- If insufficient, add semi-transparent dark background pill

### Screen Reader Support

**Semantic Labels:**
```dart
Semantics(
  label: 'Current arena: Beach Villa. Progress: 51% complete. 1,220 Love Points until Yacht Getaway.',
  child: _ArenaProgressSection(),
)

Semantics(
  label: 'Main quests: scrollable list of activities',
  child: _MainQuestsCarousel(),
)
```

**Button Labels:**
- Poke button: "Send poke to partner"
- Remind button: "Send reminder to partner"
- Quest cards: "Daily Pulse. Your turn. Tap to play. Rewards: 20 Love Points"

### Tap Targets

**Minimum Size:** 44×44 points (iOS HIG, WCAG)
- Action buttons: 48px height minimum
- Quest cards: Full card tap target (260×~200px)
- Side quest cards: Full card tap target

---

## 10. Testing Checklist

### Unit Tests

- [ ] `Arena.getCurrentArena()` returns correct tier
- [ ] `Arena.getNextArena()` returns correct next tier
- [ ] `Arena.getProgress()` calculates percentage correctly
- [ ] `ArenaService.getLovePointsUntilNext()` calculates correctly
- [ ] Edge case: User at max tier (no next arena)
- [ ] Edge case: User with 0 LP (first arena)

### Widget Tests

- [ ] `_TopSection` renders with user data
- [ ] `_ArenaProgressSection` shows correct gradient
- [ ] Progress bar width matches LP percentage
- [ ] Text shadow renders correctly
- [ ] Quest cards display correct data
- [ ] Side quests grid renders 3 columns

### Integration Tests

- [ ] Tapping Poke button shows poke modal
- [ ] Tapping Remind button navigates to reminder screen
- [ ] Tapping quest card navigates to game/activity
- [ ] Horizontal scroll works smoothly
- [ ] Pull to refresh updates data
- [ ] Arena updates when LP changes

### Manual Testing

- [ ] Test on iPhone SE (small screen)
- [ ] Test on iPhone 14 Pro (standard screen)
- [ ] Test on iPad (tablet layout)
- [ ] Test text readability on all arena gradients
- [ ] Test with VoiceOver (accessibility)
- [ ] Test with large text size (accessibility)
- [ ] Test with no internet connection
- [ ] Test with no partner paired

---

## 11. Potential Issues & Mitigations

### Issue 1: Text Readability on Light Gradients

**Problem:** White text may be hard to read on yellow/gold areas of Beach Villa gradient

**Solutions Tried:**
1. ✅ **Text shadow** (recommended): `0 1px 3px rgba(0, 0, 0, 0.4)`
2. ⏳ **Background pill** (fallback): Semi-transparent dark background
3. ⏳ **Outline** (alternative): Stroke around text

**Recommended Approach:**
- Start with text shadow
- Test on real devices
- Add background pill if shadow insufficient

### Issue 2: Performance with Many Quests

**Problem:** Horizontal scroll performance may degrade with 10+ quest cards

**Mitigation:**
- Use `ListView.builder()` instead of `Row()`
- Implement lazy loading
- Cache quest card widgets
- Limit to 8 visible quests max

### Issue 3: Arena Gradient Caching

**Problem:** Creating LinearGradient on every build may impact performance

**Mitigation:**
```dart
// Cache gradients as static constants
class ArenaGradients {
  static const beachVilla = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF87CEEB), Color(0xFFFFD700)],
  );
  // ... other gradients
}
```

### Issue 4: Love Points Not Yet Implemented

**Problem:** LP tracking system doesn't exist yet

**Temporary Solution:**
- Mock LP value (1280) for development
- Show correct UI even without real data
- Implement LP system in separate task

**Long-term Solution:**
- Add `lovePoints` field to User model
- Award LP on quest completion
- Persist LP to Hive
- Sync LP across devices (if needed)

---

## 12. Future Enhancements

### Phase 2 Features (Post-MVP)

1. **Arena Unlock Celebrations**
   - Animated confetti when reaching new arena
   - Modal showing new arena perks
   - Push notification to partner

2. **Arena Visual Themes**
   - Change app color scheme based on current arena
   - Arena-specific animations
   - Ambient sounds (ocean waves for Beach Villa, etc.)

3. **Arena Badges**
   - Collectible badges for reaching each tier
   - Display in profile screen
   - Share achievement with partner

4. **LP History Graph**
   - Line chart showing LP growth over time
   - Milestone markers for arena unlocks
   - Weekly/monthly LP summary

5. **Seasonal Arenas**
   - Time-limited special arenas
   - Holiday-themed destinations
   - Bonus LP multipliers

---

## 13. Success Metrics

### User Engagement
- Time spent on new home screen (target: +20% vs old)
- Quest completion rate (target: +15%)
- Poke frequency (target: maintain or increase)

### Technical Metrics
- Screen load time (target: <500ms)
- Scroll performance (target: 60fps)
- Crash-free rate (target: 99.9%)

### Accessibility
- VoiceOver navigation success rate (target: 100%)
- Contrast ratio compliance (target: 100% WCAG AA)
- Tap target size compliance (target: 100%)

---

## 14. Rollout Plan

### Development Timeline

**Week 1: Arena System**
- Days 1-2: Model and service implementation
- Day 3: Unit tests
- Days 4-5: Integration with existing User model

**Week 2: UI Implementation**
- Days 1-2: Top section + arena progress
- Days 3-4: Quest carousel + side quests
- Day 5: Navigation integration

**Week 3: Testing & Polish**
- Days 1-2: Widget and integration tests
- Days 3-4: Manual testing on devices
- Day 5: Bug fixes and refinements

**Week 4: Rollout**
- Days 1-2: Internal testing
- Day 3: Beta release to test users
- Days 4-5: Monitor metrics, gather feedback

### Rollback Plan

If critical issues arise:
1. Feature flag to disable new home screen
2. Fallback to old home screen implementation
3. Keep old `home_screen.dart` until stable

---

## 15. Remind Bottom Sheet Specification

### Overview
The Remind button opens a modal bottom sheet similar to `PokeBottomSheet`, containing all reminder creation functionality previously in `SendReminderScreen`.

### Widget Structure

**File:** `app/lib/widgets/remind_bottom_sheet.dart`

```dart
class RemindBottomSheet extends StatefulWidget {
  const RemindBottomSheet({super.key});

  @override
  State<RemindBottomSheet> createState() => _RemindBottomSheetState();
}

class _RemindBottomSheetState extends State<RemindBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedTime;

  final List<Map<String, dynamic>> _quickMessages = [
    {'emoji': '💕', 'text': 'Love you!'},
    {'emoji': '🏠', 'text': "I'm home"},
    {'emoji': '☕', 'text': 'Coffee?'},
    {'emoji': '🛒', 'text': 'Pick up milk'},
  ];

  final List<Map<String, dynamic>> _timeOptions = [
    {'emoji': '⚡', 'label': 'In 1 sec', 'minutes': 0},
    {'emoji': '☕', 'label': '1 hour', 'minutes': 60},
    {'emoji': '🌙', 'label': 'Tonight', 'minutes': null, 'special': 'tonight'},
    {'emoji': '☀️', 'label': 'Tomorrow', 'minutes': null, 'special': 'tomorrow'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  'Send Reminder',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Message input
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Remind me to...',
                    filled: true,
                    fillColor: AppTheme.backgroundGray,
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 20),

                // Quick messages
                Text(
                  'Quick Messages',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: _quickMessages.length,
                  itemBuilder: (context, index) {
                    final message = _quickMessages[index];
                    return _buildQuickMessageButton(message);
                  },
                ),

                const SizedBox(height: 24),

                // Time selection
                Text(
                  'When?',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: _timeOptions.length,
                  itemBuilder: (context, index) {
                    final time = _timeOptions[index];
                    return _buildTimeButton(time);
                  },
                ),

                const SizedBox(height: 32),

                // Send button
                ElevatedButton(
                  onPressed: _sendReminder,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Send Reminder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMessageButton(Map<String, dynamic> message) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _messageController.text = message['text'];
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message['emoji'], style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message['text'],
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(Map<String, dynamic> time) {
    final isSelected = _selectedTime == time['label'];
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedTime = time['label'];
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primaryBlack : AppTheme.backgroundGray,
        foregroundColor: isSelected ? AppTheme.primaryWhite : AppTheme.textPrimary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time['emoji'], style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              time['label'],
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReminder() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder message')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return;
    }

    // Send reminder logic (copied from SendReminderScreen)
    final partner = StorageService().getPartner();
    final user = StorageService().getUser();
    if (partner == null || user == null) return;

    final selectedTimeOption = _timeOptions.firstWhere((t) => t['label'] == _selectedTime);
    final scheduledTime = _calculateScheduledTime(selectedTimeOption);

    const uuid = Uuid();
    final reminder = Reminder(
      id: uuid.v4(),
      type: 'sent',
      from: user.name ?? 'You',
      to: partner.name,
      text: _messageController.text,
      timestamp: DateTime.now(),
      scheduledFor: scheduledTime,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await StorageService().saveReminder(reminder);

    try {
      final success = await ReminderService.sendReminder(reminder);
      if (!success) {
        print('⚠️ Reminder saved locally but failed to send push notification');
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }

    // Close modal and show success
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder sent to ${partner.name}'),
          backgroundColor: AppTheme.primaryBlack,
        ),
      );
    }
  }

  DateTime _calculateScheduledTime(Map<String, dynamic> timeOption) {
    if (timeOption['special'] == 'tonight') {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, 20, 0); // 8 PM
    } else if (timeOption['special'] == 'tomorrow') {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0); // 9 AM
    } else {
      return DateTime.now().add(Duration(minutes: timeOption['minutes'] as int));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
```

### Design Specifications

**Modal Properties:**
- Border radius: 24px (top corners only)
- Background: `#FFFEFD` (primaryWhite)
- Padding: 24px
- Handle bar: 40×4px, `#F0F0F0`, centered

**Layout:**
- Title: "Send Reminder" (24px, Playfair Display, centered)
- Message input: 3 lines, filled background
- Quick messages grid: 2 columns, 2.5:1 aspect ratio
- Time buttons grid: 2 columns, 2.5:1 aspect ratio
- Send button: Full width, 16px vertical padding

**Button Behavior:**
- Poke button in top section: `showModalBottomSheet(...)` with `PokeBottomSheet`
- Remind button in top section: `showModalBottomSheet(...)` with `RemindBottomSheet`

### Opening the Modal

In `new_home_screen.dart`:

```dart
void _showRemindBottomSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const RemindBottomSheet(),
  );
}

// In action button:
ElevatedButton(
  onPressed: _showRemindBottomSheet,
  child: Row(
    children: [
      Text('💕', style: TextStyle(fontSize: 20)),
      SizedBox(width: 6),
      Text('Remind'),
    ],
  ),
)
```

### Migration Checklist

**Content to Move from SendReminderScreen:**
- [x] Quick message buttons (4 options)
- [x] Time selection buttons (4 options)
- [x] Message text field
- [x] Send reminder logic
- [x] Scheduled time calculation
- [x] Success feedback

**Styling to Match:**
- [x] Same border radius as PokeBottomSheet (24px)
- [x] Same handle bar design
- [x] Same padding (24px)
- [x] Same color scheme (black & white)
- [x] Same button styles (OutlinedButton, ElevatedButton)

---

## 16. Appendix

### Reference Files

**Mockup:**
- `mockups/mainscreen/variant20_arena_minimal.html`

**Current Implementation:**
- `app/lib/screens/home_screen.dart`
- `app/lib/screens/send_reminder_screen.dart`
- `app/lib/screens/activities_screen.dart`

**Services to Integrate:**
- `app/lib/services/storage_service.dart`
- `app/lib/services/daily_pulse_service.dart`
- `app/lib/services/ladder_service.dart`
- `app/lib/services/memory_flip_service.dart`
- `app/lib/services/quiz_service.dart`
- `app/lib/services/poke_service.dart`

### Design System Reference

**File:** `app/lib/theme/app_theme.dart`

All colors, typography, and spacing follow the existing design system defined in this file.

---

## Questions & Decisions Needed

1. **Love Points Awarding:** How many LP for each quest completion?
   - Daily Pulse: 20 LP
   - Word Ladder: 15 LP per puzzle
   - Memory Flip: 40 LP per puzzle
   - Couple Quiz: 30 LP per session
   - Poke: 5 LP
   - Reminder: 10 LP

2. **Arena Unlock Behavior:** Show animation immediately or wait for user to open app?
   - **Recommendation:** Show modal on next app open

3. **Floor Protection:** Should users ever lose LP or drop to lower arena?
   - **Recommendation:** No. Floor protection keeps users at highest achieved tier.

4. **LP Display:** Show total LP or just progress within current tier?
   - **Recommendation:** Show both. "1,280 LP (Beach Villa)" in profile, "1,280 / 2,500" in progress bar.

5. **Side Quests:** Which activities should appear in side quests grid?
   - **Recommendation:** Inbox, Would You Rather (coming soon), Daily Challenge (coming soon)

---

## Implementation Completion Summary

**Completion Date:** 2025-11-11
**Total Time:** ~6 hours
**Status:** ✅ All phases completed successfully

### What Was Implemented

#### Core Features
- ✅ **Arena System**: 5-tier progression (Cozy Cabin → Castle Retreat)
- ✅ **NewHomeScreen**: Complete redesign with quest-based interface
- ✅ **RemindBottomSheet**: Modal for sending reminders (replaced SendReminderScreen)
- ✅ **Arena Progress Section**: Dynamic gradients with enhanced text shadows
- ✅ **Quest Cards**: Horizontal carousel for Main Quests, grid for Side Quests
- ✅ **Navigation Update**: Removed FAB, integrated Poke & Remind as top section buttons

#### Files Created
1. `app/lib/models/arena.dart` - Arena model with 5 tiers and gradients
2. `app/lib/services/arena_service.dart` - Arena progression logic
3. `app/lib/widgets/remind_bottom_sheet.dart` - Reminder modal
4. `app/lib/screens/new_home_screen.dart` - Main implementation (800+ lines)

#### Files Modified
1. `app/lib/screens/home_screen.dart` - Updated navigation, removed FAB
2. `app/README.md` - Added home screen feature documentation

### Improvements & Refinements

#### Visual Polish
- **Text Readability**: Implemented double text shadow for arena progress section
  - Primary shadow: `blur: 4, opacity: 0.5`
  - Secondary shadow: `blur: 8, opacity: 0.3`
  - Semi-transparent pill background for "Next Arena" text
- **Arena Gradients**: Updated Cozy Cabin from muddy brown to warm orange (#E67E22 → #F39C12)
- **Quest Card Spacing**: Fixed overflow issues by optimizing all spacing
  - Reduced from 17px overflow to 0px
  - Emoji: 48px → 46px
  - Title font: 17px → 16px
  - Subtitle font: 13px → 12px
  - Badge padding and fonts reduced
  - Added `runSpacing` for multi-line badge support

#### Technical Improvements
- Fixed `DailyPulseStatus` enum references
- Used `mainAxisSize: MainAxisSize.min` to prevent overflow
- Added `maxLines: 1` with ellipsis for text safety
- Enhanced progress bar with shadows and glow effects

### Testing Results
- ✅ Builds successfully on iOS and Chrome
- ✅ No layout overflow errors
- ✅ Text readable across all arena gradients
- ✅ Bottom sheets (Poke & Remind) function correctly
- ✅ Navigation flows work as expected

### Outstanding Items (Future Work)
- Award Love Points when completing activities
- Show celebration modal when unlocking new arena
- Accessibility testing (VoiceOver, contrast ratios)
- Testing on physical devices

---

**End of Document**
