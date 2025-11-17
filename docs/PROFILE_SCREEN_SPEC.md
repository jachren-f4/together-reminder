# Profile Screen - Implementation Specification

**Version:** 1.0
**Design Reference:** `mockups/profilescreen/12-clean-minimal.html`
**Target:** Flutter Mobile App
**Last Updated:** 2025-11-17

---

## Overview

The Profile Screen displays the couple's progression metrics in a clean, minimal layout. It focuses on Love Points, Day Streak, current Arena tier, and progress toward the next arena.

**Key Principles:**
- Edge-to-edge design (no outer borders on mobile)
- Minimal, focused content - only essential progression metrics
- Clear visual hierarchy with distinct sections
- Supports both portrait and landscape orientations

---

## Screen Structure

```
┌─────────────────────────────────┐
│ 1. Header (Black)               │
├─────────────────────────────────┤
│ 2. Hero Stats (Gradient BG)     │
├─────────────────────────────────┤
│ 3. Current Arena                │
├─────────────────────────────────┤
│ 4. Progress to Next Arena       │
└─────────────────────────────────┘
```

---

## Section 1: Header

### Design Specs

**Background:** `#000000` (solid black)
**Text Color:** `#FFFFFF` (white)
**Padding:** `24px vertical, 20px horizontal`
**Alignment:** Center

### Content

1. **Title:** "Progress"
   - Font: `AppTheme.headlineFont`
   - Size: `32px`
   - Weight: `400` (normal)
   - Letter Spacing: `2px`
   - Transform: `UPPERCASE`
   - Margin Bottom: `8px`

2. **Subtitle:** Partner names (e.g., "Joakim & Taija")
   - Font: `AppTheme.bodyFont`
   - Size: `14px`
   - Style: `italic`
   - Opacity: `0.9`

### Implementation Notes

```dart
// Get partner name from storage
final partner = StorageService().getPartner();
final user = StorageService().getUser();
final subtitle = user != null && partner != null
    ? '${user.name} & ${partner.name}'
    : 'Your Progress';
```

### Edge Cases
- **No partner:** Show "Your Progress" instead of names
- **Long names:** Truncate with ellipsis if combined length > 30 chars

---

## Section 2: Hero Stats

### Design Specs

**Background:** Linear gradient
- Start: `#FAFAFA` (top-left)
- End: `#F0F0F0` (bottom-right)
- Angle: `135deg`

**Border Bottom:** `2px solid #000000`
**Padding:** `24px vertical, 20px horizontal`

### Layout

**Grid:** 3 columns: `1fr | 2px | 1fr`
**Gap:** `20px`
**Alignment:** Center

### Content

#### Left Column: Love Points

**Value:**
- Source: `LovePointService.getStats()['total']`
- Font: `AppTheme.headlineFont`
- Size: `48px`
- Weight: `700` (bold)
- Color: `#000000`
- Margin Bottom: `4px`

**Label:** "Love Points"
- Font: `AppTheme.bodyFont`
- Size: `12px`
- Transform: `UPPERCASE`
- Letter Spacing: `1px`
- Color: `#666666`

#### Center Column: Divider

**Vertical Divider:**
- Width: `2px`
- Height: `60px`
- Color: `#000000`

#### Right Column: Day Streak

**Value:**
- Source: `LovePointService.getStats()['streak']` (via `GeneralActivityStreakService`)
- Font: `AppTheme.headlineFont`
- Size: `48px`
- Weight: `700` (bold)
- Color: `#000000`
- Margin Bottom: `4px`

**Label:** "Day Streak"
- Font: `AppTheme.bodyFont`
- Size: `12px`
- Transform: `UPPERCASE`
- Letter Spacing: `1px`
- Color: `#666666`

### Data Requirements

**General Activity Streak** ✅ Defined
- **Implementation:** `GeneralActivityStreakService` using existing `QuizStreak` model
- **Counts as Active Day:**
  - Complete any daily quest
  - Send a reminder
  - Send a poke
  - Play any game (Word Ladder, Memory Flip)
  - Complete affirmation quiz
  - Complete Daily Pulse
- **Reset Logic:**
  - Resets at midnight local time
  - 2-hour grace period (12:00 AM - 2:00 AM counts as previous day)
  - Must complete at least one activity per day
  - Missing a day = streak resets to 0
- **Storage:** Uses existing `quiz_streaks` Hive box with type `'general_activity'`

### Implementation Notes

```dart
// Get stats from LovePointService (includes streak from GeneralActivityStreakService)
final stats = LovePointService.getStats();
final lovePoints = stats['total'] ?? 0;
final dayStreak = stats['streak'] ?? 0;
```

### Edge Cases
- **Zero streak:** Display "0" (not hide)
- **Large numbers:** Format with commas (e.g., "2,450")
- **Negative LP:** Should not happen (floor protection), but display as "0" if it does

---

## Section 3: Current Arena

### Design Specs

**Background:** `#FFFFFF` (white)
**Border Bottom:** `1px solid #E0E0E0`
**Padding:** `20px`

### Layout

**Grid:** 2 columns: `auto | 1fr`
**Gap:** `20px`
**Alignment:** Center

### Content

#### Left: Arena Emoji

**Size:** `72px`
**Source:** Arena configuration (see Arena Emoji Mapping below)

#### Right: Arena Details

**Tier Badge:**
- Background: `#000000`
- Color: `#FFFFFF`
- Padding: `4px horizontal, 10px vertical`
- Font Size: `11px`
- Weight: `600` (semi-bold)
- Transform: `UPPERCASE`
- Letter Spacing: `1px`
- Margin Bottom: `8px`
- Text: "TIER X OF 5"

**Arena Name:**
- Font: `AppTheme.headlineFont`
- Size: `28px`
- Weight: `700` (bold)
- Color: `#000000`
- Text: Arena name (e.g., "Blossom Fields")

### Arena Emoji Mapping

**Data Source:** `lib/services/arena_service.dart` and `lib/models/arena.dart`

**Vacation Theme Arenas:**

| Tier | LP Range | Arena Name | Emoji | Notes |
|------|----------|------------|-------|-------|
| 1 | 0-1,000 | Cozy Cabin | 🏕️ | Starting tier |
| 2 | 1,000-2,500 | Beach Villa | 🏖️ | |
| 3 | 2,500-5,000 | Yacht Getaway | ⛵ | |
| 4 | 5,000-10,000 | Mountain Penthouse | 🏔️ | |
| 5 | 10,000+ | Castle Retreat | 🏰 | Max tier |

### Implementation Notes

```dart
final stats = LovePointService.getStats();
final currentArena = stats['currentArena'];
final tier = stats['tier'];

// Display
final emoji = currentArena['emoji']; // e.g., "🌸"
final arenaName = currentArena['name']; // e.g., "Blossom Fields"
final tierText = 'Tier $tier of 5';
```

### Edge Cases
- **Max tier reached:** Still show "Tier 5 of 5"
- **Arena emoji missing:** Use fallback "🏆"
- **Arena name missing:** Use fallback "Current Arena"

---

## Section 4: Progress to Next Arena

### Design Specs

**Background:** `#FFFFFF` (white)
**Padding:** `20px`
**No border bottom** (last section on screen)

### Layout

**Vertical Stack:**
1. Progress Info Row (flex horizontal)
2. Progress Visual Row (flex horizontal)

### Content

#### Progress Info Row

**Layout:** Flex row with space-between

**Left - Label:**
- Text: "Next: [Arena Name]"
- Font: `AppTheme.bodyFont`
- Size: `14px`
- Weight: `600` (semi-bold)
- Color: `#000000`

**Right - Remaining LP:**
- Text: "[X] LP remaining"
- Font: `AppTheme.bodyFont`
- Size: `12px`
- Weight: `600` (semi-bold)
- Color: `#666666`

**Margin Bottom:** `12px`

#### Progress Visual Row

**Layout:** Flex row with gap `12px`

**Left - Progress Bar:**
- Flex: `1` (takes remaining space)
- Height: `16px`
- Background: `#E0E0E0`
- Border: `2px solid #000000`
- Border Radius: `0` (sharp corners)

**Progress Fill:**
- Height: `100%` (fills bar height)
- Background: `#000000`
- Width: Percentage based on progress (e.g., `65%`)
- Calculation: `(currentLP - currentArenaMin) / (nextArenaMin - currentArenaMin)`

**Right - Next Arena Emoji:**
- Size: `28px`
- Source: Next arena emoji from arena config

### Data Requirements

**Current Implementation:**
```dart
final stats = LovePointService.getStats();
final nextArena = stats['nextArena'];
final progress = stats['progressToNext']; // 0.0 to 1.0
```

**Progress Calculation:**
```dart
final currentLP = stats['total'];
final currentArenaMin = stats['currentArena']['min'];
final nextArenaMin = nextArena['min'];
final remaining = nextArenaMin - currentLP;
final progressPercent = (currentLP - currentArenaMin) / (nextArenaMin - currentArenaMin);
```

### Special Case: Max Tier Reached

When `nextArena == null` (max tier reached):

**Replace entire section with:**

```
┌─────────────────────────────────┐
│                                 │
│            👑                   │  ← Centered crown emoji (48px)
│      Max Tier Reached!          │  ← Centered text (20px, bold)
│                                 │
└─────────────────────────────────┘
```

**Max Tier Section Specs:**
- Padding: `24px`
- Background: `#FFFFFF`
- Text Color: `#000000`
- Emoji Size: `48px`
- Text Size: `20px`
- Weight: `700` (bold)
- Alignment: Center

### Implementation Notes

```dart
if (nextArena == null) {
  // Show max tier card
  return _buildMaxTierCard();
} else {
  // Show progress to next arena
  return _buildProgressSection(nextArena, progress, remaining);
}
```

### Edge Cases
- **Progress > 100%:** Cap at 100% (should not happen, but defensive coding)
- **Negative progress:** Show 0% (should not happen)
- **Very close to next tier (< 10 LP):** Show "< 10 LP remaining"

---

## Technical Implementation

### File Structure

```
lib/screens/profile_screen.dart
  - ProfileScreen (StatefulWidget)
  - _ProfileScreenState
    - _buildHeader()
    - _buildHeroStats()
    - _buildCurrentArena()
    - _buildProgressSection()
    - _buildMaxTierCard()
```

### Dependencies

**Services:**
- `StorageService` - Get user and partner data
- `LovePointService` - Get LP stats, arena info, progress, streak
- `GeneralActivityStreakService` - Track and calculate day streak

**Theme:**
- `AppTheme.headlineFont` - For titles and large numbers
- `AppTheme.bodyFont` - For labels and body text
- `AppTheme.primaryBlack` - `#000000`
- `AppTheme.textSecondary` - `#666666`
- `AppTheme.borderLight` - `#E0E0E0`
- `AppTheme.backgroundGray` - `#FAFAFA`

### Scaffold Structure

```dart
Scaffold(
  backgroundColor: AppTheme.primaryWhite, // Not backgroundGray
  body: SafeArea(
    child: SingleChildScrollView( // Allow scrolling on small screens
      child: Column(
        children: [
          _buildHeader(),
          _buildHeroStats(),
          _buildCurrentArena(),
          _buildProgressSection(),
        ],
      ),
    ),
  ),
)
```

**Why SingleChildScrollView:**
- Handles small screens gracefully
- Prevents overflow on devices with small heights
- Allows keyboard to push content up if needed (future text inputs)

---

## Missing Features & Action Items

### 1. Day Streak Tracking

**Status:** ✅ Implemented (using GeneralActivityStreakService)

**Implementation Details:**
- Uses existing `QuizStreak` model (typeId: 15) with type `'general_activity'`
- Stored in `quiz_streaks` Hive box
- Tracks ANY activity: quests, reminders, pokes, games
- Resets at midnight local time with 2-hour grace period
- Integrated into `LovePointService.getStats()`

**Data Model:** (Already exists)
```dart
@HiveType(typeId: 15)
class QuizStreak extends HiveObject {
  @HiveField(0)
  late String type; // 'general_activity'

  @HiveField(1)
  late int currentStreak;

  @HiveField(2)
  late int longestStreak;

  @HiveField(3)
  late DateTime lastCompletedDate;

  @HiveField(4, defaultValue: 0)
  int totalCompleted;
}
```

**Activity Triggers:**
- Quest completion → `daily_quest_service.dart`
- Reminder sent → `reminder_service.dart`
- Poke sent → `poke_service.dart`
- Word Ladder completed → `word_ladder_service.dart`
- Memory Flip completed → `memory_flip_service.dart`
- Daily Pulse completed → `daily_pulse_service.dart`

### 2. Arena Configuration Validation

**Status:** ⚠️ Needs Verification

**Action:**
- Review `arena_service.dart` to confirm tier emojis match spec
- Verify tier LP thresholds are correct
- Ensure all 5 tiers are defined
- Test edge cases (exactly at tier boundary)

### 3. Number Formatting

**Status:** ⚠️ Needs Implementation

**Requirements:**
- Format large LP values with commas (e.g., "2,450" not "2450")
- Use `NumberFormat` from `intl` package

**Implementation:**
```dart
import 'package:intl/intl.dart';

final formatter = NumberFormat('#,###');
final formattedLP = formatter.format(stats['total']);
```

### 4. Loading States

**Status:** ❌ Not Implemented

**Requirements:**
- Show loading indicator while fetching stats
- Handle case where `getStats()` returns null/empty
- Graceful fallback if services unavailable

### 5. Refresh Mechanism

**Status:** ❌ Not Implemented

**Requirements:**
- Pull-to-refresh gesture to update stats
- Auto-refresh when returning to screen from background
- Listen to LP changes via ValueNotifier/Stream

**Implementation:**
```dart
RefreshIndicator(
  onRefresh: () async {
    setState(() {
      // Trigger rebuild with fresh data
    });
  },
  child: SingleChildScrollView(...),
)
```

### 6. Accessibility

**Status:** ❌ Not Implemented

**Requirements:**
- Semantic labels for screen readers
- Sufficient color contrast (already met with black on white)
- Support for large text sizes (test with accessibility settings)

---

## Visual Refinements to Consider

### 1. Divider Lines

**Current:** 1px solid borders between sections

**Consider:**
- Use `Divider()` widget with proper color
- Ensure consistent thickness across sections
- Test on different screen densities (1dp vs 2dp)

### 2. Arena Emoji Consistency

**Current:** Using Unicode emojis

**Consider:**
- Ensure emojis render consistently across iOS/Android
- Test on older devices (some emojis may not render)
- Fallback to image assets if emoji support is inconsistent

### 3. Progress Bar Fill Animation

**Consider:**
- Animate progress bar fill on screen load
- Use `AnimatedContainer` with duration ~800ms
- Easing: `Curves.easeOutCubic`

### 4. Gradient Implementation

**Current Spec:** `linear-gradient(135deg, #FAFAFA 0%, #F0F0F0 100%)`

**Flutter Implementation:**
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFAFAFA),
        Color(0xFFF0F0F0),
      ],
    ),
  ),
)
```

---

## Testing Checklist

### Data States
- [ ] Zero LP
- [ ] Low LP (< 100)
- [ ] Normal LP (1,000-5,000)
- [ ] High LP (> 10,000)
- [ ] Exactly at tier boundary (e.g., 2,000 LP)
- [ ] Max tier reached (5,000+ LP)
- [ ] Zero streak
- [ ] Long streak (> 100 days)

### UI States
- [ ] No partner set
- [ ] Long partner names
- [ ] Small screen (iPhone SE)
- [ ] Large screen (iPad)
- [ ] Dark mode compatibility
- [ ] Landscape orientation
- [ ] Accessibility: Large text enabled
- [ ] Accessibility: Screen reader

### Edge Cases
- [ ] First time user (no data)
- [ ] Negative LP (should not happen, but test floor protection)
- [ ] Missing arena configuration
- [ ] Slow data loading
- [ ] Offline mode

---

## Design Decisions & Rationale

### Why No Recent Activities?

**Decision:** Remove Recent Activities section (present in original profile_screen.dart)

**Rationale:**
- Profile should focus on progression metrics
- Activity feed belongs in dedicated Activity/Inbox screen
- Reduces screen complexity
- Faster load time

### Why Keep It Minimal?

**Decision:** Only show LP, Streak, Arena, Progress

**Rationale:**
- Quick glance value - see progress at a glance
- Prevents information overload
- Encourages users to check frequently
- Supports gamification loop (check → see progress → motivated to complete more)

### Why No Settings/Actions?

**Decision:** No "Edit Profile" or settings buttons

**Rationale:**
- Profile is view-only for progression stats
- Settings should be in dedicated Settings screen
- Keeps focus on metrics, not configuration
- Reduces decision fatigue

---

## Future Enhancements (Not in Scope)

These features are intentionally excluded from v1 but could be added later:

1. **Weekly/Monthly Stats Toggle** - Switch between daily, weekly, monthly views
2. **Comparison with Other Couples** - Leaderboard or percentile ranking
3. **Share Progress** - Export image of progression to share on social media
4. **Goals/Targets** - Set custom LP goals
5. **Historical Chart** - Graph of LP over time
6. **Achievement Showcase** - Show top 3 recent achievements
7. **Partner Activity** - Show what partner completed recently
8. **Streak Milestones** - Special badges for 7-day, 30-day, 100-day streaks

---

## Implementation Timeline

### Phase 1: Core Structure (1-2 hours)
- [ ] Create `profile_screen.dart` file
- [ ] Implement header section
- [ ] Implement hero stats section (with placeholder streak)
- [ ] Implement arena section
- [ ] Implement progress section

### Phase 2: Data Integration (2-3 hours)
- [ ] Connect to `LovePointService`
- [ ] Connect to `StorageService` for user/partner names
- [ ] Implement number formatting
- [ ] Add loading states
- [ ] Handle edge cases (no partner, max tier, etc.)

### Phase 3: Streak Implementation (2-3 hours)
- [ ] Create GeneralActivityStreakService
- [ ] Add to LovePointService.getStats()
- [ ] Integrate with all activity services (6 files)
- [ ] Test reset logic and grace period

### Phase 4: Final QA (30-60 min)
- [ ] Test on Android emulator
- [ ] Test on Chrome
- [ ] Verify LP/streak formatting
- [ ] Test edge cases (max tier, zero values, long names)

**Total Estimated Time:** 7-9 hours
**MVP Scope:** No animations, no pull-to-refresh (add in future)

---

## Open Questions ✅ ALL RESOLVED

1. **Streak Reset Time:** ✅ Midnight local time with 2-hour grace period
2. **Partial Day Credit:** ✅ Yes, activity before midnight (or within grace period) counts
3. **Grace Period:** ✅ Yes, 2-hour window (12:00 AM - 2:00 AM)
4. **Streak Recovery:** ✅ No recovery mechanism in MVP
5. **Multiple Quests:** ✅ Any activity counts once per day for streak
6. **Arena Naming:** ✅ Using vacation theme from existing code (Cozy Cabin → Castle Retreat)
7. **Navigation:** ✅ Already exists in bottom navigation bar

---

## Appendix: Color Palette

All colors used in this screen:

| Color | Hex | Usage |
|-------|-----|-------|
| Black | `#000000` | Header background, text, dividers, borders |
| White | `#FFFFFF` | Section backgrounds, header text |
| Dark Gray | `#666666` | Secondary text, labels |
| Light Gray | `#E0E0E0` | Borders, progress bar background |
| Very Light Gray | `#FAFAFA` | Gradient start |
| Off White | `#F0F0F0` | Gradient end |

---

## References

- **Design Mockup:** `mockups/profilescreen/12-clean-minimal.html`
- **Current Implementation:** `app/lib/screens/profile_screen.dart`
- **Arena Service:** `app/lib/services/arena_service.dart`
- **Love Point Service:** `app/lib/services/love_point_service.dart`
- **Theme Config:** `app/lib/theme/app_theme.dart`

---

**Document Status:** ✅ Ready for Implementation
**Next Step:** Review with team → Begin Phase 1 implementation
