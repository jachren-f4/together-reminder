# Journal Feature Implementation Plan

## Overview

Replace the existing "Inbox" screen with a new "Journal" feature that serves as a historical record of the couple's quest activity. The Journal displays completed quests in a scrapbook/polaroid style with week-based navigation.

**Reference mockups:**
- `mockups/inbox-2.0/journal-loading.html` - First-time loading/transition screen
- `mockups/inbox-2.0/variant-9-journal.html` - Main journal screen

---

## Week Definition

The Journal uses **Monday-Sunday** weeks (ISO 8601 standard).

**Why Monday-Sunday:**
- ISO 8601 international standard for week numbering
- Most business/productivity apps use this convention
- Aligns with "work week" mental model
- Consistent across locales (US Sunday-start is the exception, not the rule)

**Implementation:**
```dart
/// Get the Monday of the week containing the given date
DateTime getMondayOfWeek(DateTime date) {
  // weekday: Monday=1, Sunday=7
  final daysFromMonday = date.weekday - 1;
  return DateTime(date.year, date.month, date.day - daysFromMonday);
}

/// Get date range for display: "Dec 23 - 29"
String formatWeekRange(DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  if (monday.month == sunday.month) {
    return '${DateFormat('MMM d').format(monday)} - ${sunday.day}';
  }
  return '${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d').format(sunday)}';
}
```

---

## Loading States

The Journal has **two distinct loading states**:

### 1. First-Time Transition Screen (JournalLoadingScreen)
- **When:** Only on the very first Journal open (per device)
- **Purpose:** Introduce the Journal feature with branded animation
- **Visual:** Full-screen with polaroid stack, "Your Journal" → "Our Journal" title morph
- **Duration:** ~3.5s animation, then tap to continue
- **Implementation:** Phase 3

### 2. Week Loading Overlay (WeekLoadingOverlay)
- **When:** Any time week data is being fetched (including initial load after first-time screen)
- **Purpose:** Show progress while fetching entries from server
- **Visual:** Semi-transparent overlay with bouncing polaroid, "Flipping pages..." text
- **Duration:** Until data loads (typically 1-2s)
- **Implementation:** Phase 7

**Flow:**
```
User taps Journal tab
    ↓
Is first time? ──Yes──→ Show JournalLoadingScreen (3.5s + tap)
    │                           ↓
    No                    Mark as opened
    ↓                           ↓
    └──────────────→ Show WeekLoadingOverlay
                            ↓
                    Fetch current week data
                            ↓
                    Hide overlay, show Journal content
                            ↓
User navigates week ──→ Show WeekLoadingOverlay
                            ↓
                    Fetch new week data
                            ↓
                    Hide overlay, show new content
```

---

## Phase 1: Assets & Navigation Rename

### 1.1 Add Journal Icon

Save the new journal icon (coral notebook with heart) to:
```
app/assets/shared/gfx/journal.png
app/assets/shared/gfx/journal_filled.png
```

**Icon specs:**
- Size: 48x48 or 96x96 (2x for retina)
- Format: PNG with transparency
- Style: Coral/pink notebook with embossed heart, matching app color palette

### 1.2 Update Brand Assets

**File:** `app/lib/config/brand/brand_assets.dart`

```dart
// Replace inbox icons with journal icons
static const String journalIcon = '$sharedGfxPath/journal.png';
static const String journalIconFilled = '$sharedGfxPath/journal_filled.png';

// Keep old names as aliases for backwards compatibility during transition
@Deprecated('Use journalIcon instead')
static const String inboxIcon = journalIcon;
@Deprecated('Use journalIconFilled instead')
static const String inboxIconFilled = journalIconFilled;
```

### 1.3 Update Bottom Navigation

**File:** `app/lib/screens/main_screen.dart`

Changes:
- Rename `inboxIcon` → `journalIcon`
- Rename `inboxIconFilled` → `journalIconFilled`
- Change label from `'Inbox'` to `'Journal'`
- Update comment: `Screen indices: Home=0, Journal=1, Poke=2, Profile=3, Settings=4`

```dart
_NavItem(
  iconOutline: BrandAssets.journalIcon,
  iconFilled: BrandAssets.journalIconFilled,
  label: 'Journal',
  isActive: _currentIndex == 1,
  onTap: () => setState(() => _currentIndex = 1),
),
```

### 1.4 Phase 1 Testing

```bash
# Run app and verify:
flutter run -d chrome --dart-define=BRAND=togetherRemind
```

- [ ] Bottom nav shows "Journal" label (not "Inbox")
- [ ] Journal icon displays correctly (coral notebook with heart)
- [ ] Icon has filled variant when tab is active
- [ ] Tapping Journal tab navigates to Journal screen (placeholder OK for now)
- [ ] No console errors about missing assets

---

## Phase 2: Data Models & Service

### 2.1 Journal Entry Model

**New file:** `app/lib/models/journal_entry.dart`

```dart
import 'package:hive/hive.dart';

part 'journal_entry.g.dart';

enum JournalEntryType {
  classicQuiz,
  affirmationQuiz,
  youOrMe,
  linked,
  wordSearch,
  stepsTogether,
}

@HiveType(typeId: 30)
class JournalEntry extends HiveObject {
  @HiveField(0)
  late String entryId;

  @HiveField(1)
  late JournalEntryType type;

  @HiveField(2)
  late String title;  // Quiz name or game title

  @HiveField(3)
  late DateTime completedAt;

  @HiveField(4)
  String? contentId;  // Quiz session ID, match ID, etc.

  // For quizzes: aligned/different counts
  @HiveField(5, defaultValue: 0)
  int alignedCount;

  @HiveField(6, defaultValue: 0)
  int differentCount;

  // For Linked/Word Search: scores
  @HiveField(7, defaultValue: 0)
  int userScore;

  @HiveField(8, defaultValue: 0)
  int partnerScore;

  // For Linked/Word Search: game stats
  @HiveField(9, defaultValue: 0)
  int totalTurns;

  @HiveField(10, defaultValue: 0)
  int userHintsUsed;

  @HiveField(11, defaultValue: 0)
  int partnerHintsUsed;

  // For Word Search: points
  @HiveField(12, defaultValue: 0)
  int userPoints;

  @HiveField(13, defaultValue: 0)
  int partnerPoints;

  // Winner info
  @HiveField(14)
  String? winnerId;
}
```

### 2.2 Weekly Insights Model

**New file:** `app/lib/models/weekly_insights.dart`

```dart
class WeeklyInsights {
  final int totalQuestions;      // Questions explored together
  final int alignedAnswers;      // Aligned perspectives
  final int daysConnected;       // Days with activity (0-7)
  final int dailyQuestsCompleted;
  final int sideQuestsCompleted;
  final int stepsTogetherCompleted;

  int get totalQuestsCompleted =>
    dailyQuestsCompleted + sideQuestsCompleted + stepsTogetherCompleted;
}
```

### 2.3 Journal Service

**New file:** `app/lib/services/journal_service.dart`

```dart
class JournalService {
  static final JournalService _instance = JournalService._internal();
  factory JournalService() => _instance;
  JournalService._internal();

  // ===== Week Utilities =====

  /// Get the Monday of the week containing the given date
  static DateTime getMondayOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1; // Monday=1, Sunday=7
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  /// Get display string: "Dec 23 - 29" or "Dec 30 - Jan 5"
  static String formatWeekRange(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    if (monday.month == sunday.month) {
      return '${DateFormat('MMM d').format(monday)} - ${sunday.day}';
    }
    return '${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d').format(sunday)}';
  }

  /// Check if we can navigate to previous week (limit: couple creation date)
  bool canNavigateToPreviousWeek(DateTime currentWeekStart) {
    final coupleCreatedAt = StorageService().getCouple()?.createdAt;
    if (coupleCreatedAt == null) return false;
    final creationWeek = getMondayOfWeek(coupleCreatedAt);
    return currentWeekStart.isAfter(creationWeek);
  }

  /// Check if we can navigate to next week (limit: current week)
  bool canNavigateToNextWeek(DateTime currentWeekStart) {
    final thisWeek = getMondayOfWeek(DateTime.now());
    return currentWeekStart.isBefore(thisWeek);
  }

  // ===== Data Fetching =====

  /// Get entries for a specific week (Monday-Sunday)
  /// Returns entries sorted by completedAt descending
  Future<List<JournalEntry>> getEntriesForWeek(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    // Fetch from local storage + API sync
    // Filter: completedAt >= weekStart && completedAt < weekEnd
  }

  /// Calculate weekly insights for a given week
  Future<WeeklyInsights> getWeeklyInsights(DateTime weekStart) async {
    final entries = await getEntriesForWeek(weekStart);
    // Aggregate data from entries
  }

  /// Get detailed quiz answers for bottom sheet
  Future<List<QuizAnswer>> getQuizAnswers(String sessionId) async {
    // Fetch from quiz session storage
  }

  /// Get Linked game details
  Future<LinkedMatchDetails> getLinkedDetails(String matchId) async {
    // Fetch match with completed words
  }

  /// Get Word Search game details
  Future<WordSearchMatchDetails> getWordSearchDetails(String matchId) async {
    // Fetch match with found words
  }

  // ===== First-Time State =====

  /// Check if first time opening journal (for JournalLoadingScreen)
  bool get isFirstTimeOpening => StorageService().getBool('journal_first_open') ?? true;

  /// Mark journal as opened (after first-time transition completes)
  Future<void> markAsOpened() async {
    await StorageService().setBool('journal_first_open', false);
  }
}
```

### 2.4 Phase 2 Testing

```bash
# Generate Hive adapters:
cd app && flutter pub run build_runner build --delete-conflicting-outputs

# Run unit tests:
flutter test test/unit/journal_service_test.dart
```

**Unit Tests to Write:**
- [ ] `getMondayOfWeek()` returns correct Monday for various dates
- [ ] `getMondayOfWeek()` handles edge cases (Jan 1, Dec 31, leap years)
- [ ] `formatWeekRange()` formats same-month weeks correctly ("Dec 23 - 29")
- [ ] `formatWeekRange()` formats cross-month weeks correctly ("Dec 30 - Jan 5")
- [ ] `canNavigateToPreviousWeek()` returns false for couple's first week
- [ ] `canNavigateToNextWeek()` returns false for current week
- [ ] JournalEntry model serializes/deserializes correctly with Hive
- [ ] WeeklyInsights calculates `totalQuestsCompleted` correctly

**Manual Verification:**
- [ ] No build errors after adding models
- [ ] Hive adapters generated successfully (check `.g.dart` files exist)

---

## Phase 3: Journal Loading Screen

### 3.1 Loading Screen Widget

**New file:** `app/lib/screens/journal_loading_screen.dart`

This screen shows on first journal open and transforms from serif to handwritten style.

**Animation Sequence (total ~3.5s):**

| Time | Element | Animation |
|------|---------|-----------|
| 0.0s | Background gradient | Fade in |
| 0.2s | Polaroid 1 (bottom-left) | stackIn: fly up from below, rotate -12deg |
| 0.4s | Polaroid 2 (bottom-right) | stackIn: fly up from below, rotate 8deg |
| 0.5s | Paper texture | fadeInPaper: opacity 0→1 |
| 0.6s | Polaroid 3 (top) | stackIn: fly up from below, rotate -3deg |
| 0.8s | Tape pieces | tapeIn: scale in with rotation (staggered 0.8s, 1.0s, 1.2s) |
| 1.5s | Title "Your Journal" | morphOut: fade out + scale down |
| 1.5s | Title "Our Journal" | morphIn: fade in + scale up |
| 1.8s | Pen emoji | penWrite: move across title left→right, then fade |
| 2.2s | Subtitle | writeIn: clip-path reveal left→right |
| 2.5s | Loading message | fadeIn |
| 3.0s | "Tap to continue" | fadeIn + bounce loop |
| ∞ | Loading dots | pulse animation (staggered) |
| ∞ | Floating hearts | floatUp animation (staggered, infinite) |

**Key Visual Elements:**
- Background: Linear gradient `#FFD1C1` → `#FFF5F0`
- Paper texture: Repeating horizontal lines (28px spacing, 0.06 opacity)
- 3 mini polaroids stacked with different rotations
- Tape pieces (yellow/gold, 60x20px) positioned randomly
- Floating hearts (💕) rising from bottom

**Fonts:**
- Serif title: Playfair Display (600 weight, 32px)
- Handwritten title: Caveat (600 weight, 48px)
- Subtitle: Caveat (22px)
- Loading message: Caveat (18px)

```dart
class JournalLoadingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const JournalLoadingScreen({super.key, required this.onComplete});
}

class _JournalLoadingScreenState extends State<JournalLoadingScreen>
    with TickerProviderStateMixin {
  // Animation controllers for each element
  late AnimationController _polaroidController;
  late AnimationController _titleMorphController;
  late AnimationController _penController;
  late AnimationController _subtitleController;
  late AnimationController _fadeInController;
  late AnimationController _heartController;
  late AnimationController _dotController;

  // Staggered animation setup...
}
```

### 3.2 Phase 3 Testing

```bash
# Clear app data to trigger first-time experience:
# Chrome: DevTools → Application → Clear site data
# Android: adb shell pm clear com.togetherremind.togetherremind
```

**Animation Testing (manual, compare to HTML mockup):**
- [ ] Background gradient matches mockup (#FFD1C1 → #FFF5F0)
- [ ] Polaroids stack in correct order with proper rotations
- [ ] Paper texture lines appear after polaroids
- [ ] Tape pieces scale in at correct times
- [ ] "Your Journal" → "Our Journal" title morph is smooth
- [ ] Pen emoji moves across title correctly
- [ ] Subtitle reveals left-to-right (clip animation)
- [ ] Loading dots pulse with stagger
- [ ] Floating hearts animate continuously
- [ ] "Tap to continue" bounces after delay

**Timing Verification:**
- [ ] Full animation completes in ~3.5s before tap prompt
- [ ] Animations respect `AnimationConfig.shouldReduceMotion()`

**Functional Testing:**
- [ ] Tapping screen calls `onComplete` callback
- [ ] Screen only shows on first Journal open
- [ ] Second Journal open skips directly to main screen
- [ ] Callback triggers week data load

---

## Phase 4: Main Journal Screen

### 4.1 Journal Screen Structure

**New file:** `app/lib/screens/journal_screen.dart`

```dart
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
}

class _JournalScreenState extends State<JournalScreen> {
  final _journalService = JournalService();

  DateTime _currentWeekStart = JournalService.getMondayOfWeek(DateTime.now());
  bool _isLoadingWeek = false;      // WeekLoadingOverlay
  bool _showFirstTimeScreen = false; // JournalLoadingScreen

  List<JournalEntry> _entries = [];
  WeeklyInsights? _insights;

  @override
  void initState() {
    super.initState();
    _showFirstTimeScreen = _journalService.isFirstTimeOpening;

    // Don't load data yet if showing first-time screen
    // The first-time screen callback will trigger the load
    if (!_showFirstTimeScreen) {
      _loadWeek(_currentWeekStart);
    }
  }

  /// Load entries for a week (shows WeekLoadingOverlay)
  Future<void> _loadWeek(DateTime weekStart) async {
    setState(() {
      _currentWeekStart = weekStart;
      _isLoadingWeek = true;
    });

    try {
      final entries = await _journalService.getEntriesForWeek(weekStart);
      final insights = await _journalService.getWeeklyInsights(weekStart);

      if (mounted) {
        setState(() {
          _entries = entries;
          _insights = insights;
          _isLoadingWeek = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeek = false);
      // Handle error
    }
  }

  void _goToPreviousWeek() {
    if (!_journalService.canNavigateToPreviousWeek(_currentWeekStart)) return;
    final previousWeek = _currentWeekStart.subtract(const Duration(days: 7));
    _loadWeek(previousWeek);
  }

  void _goToNextWeek() {
    if (!_journalService.canNavigateToNextWeek(_currentWeekStart)) return;
    final nextWeek = _currentWeekStart.add(const Duration(days: 7));
    _loadWeek(nextWeek);
  }

  @override
  Widget build(BuildContext context) {
    // First-time opening: show intro animation screen
    if (_showFirstTimeScreen) {
      return JournalLoadingScreen(
        onComplete: () async {
          await _journalService.markAsOpened();
          setState(() => _showFirstTimeScreen = false);
          // Now load the current week (will show WeekLoadingOverlay)
          _loadWeek(_currentWeekStart);
        },
      );
    }

    // Normal view with optional week loading overlay
    return Scaffold(
      body: Stack(
        children: [
          _buildPaperBackground(),
          CustomScrollView(
            slivers: [
              _buildHeader(),
              _buildWeekNavigation(),
              _buildWeeklyInsights(),
              _buildTapHint(),
              ..._buildDaySections(),
              SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
          // Week loading overlay (bouncing polaroid)
          WeekLoadingOverlay(
            targetWeekLabel: JournalService.formatWeekRange(_currentWeekStart),
            visible: _isLoadingWeek,
          ),
        ],
      ),
    );
  }
}
```

### 4.2 Paper Background

```dart
Widget _buildPaperBackground() {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8F0), // cream
      gradient: RadialGradient(
        center: Alignment.topCenter,
        radius: 1.0,
        colors: [
          const Color(0xFFFFD1C1).withOpacity(0.4),
          Colors.transparent,
        ],
      ),
    ),
    child: CustomPaint(
      painter: PaperLinesPainter(), // Horizontal lines every 28px
    ),
  );
}
```

### 4.3 Header

```dart
Widget _buildHeader() {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Text(
        'Our Journal',
        style: TextStyle(
          fontFamily: 'Caveat',
          fontSize: 42,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2D2D2D),
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
```

### 4.4 Week Navigation with Tape Decoration

```dart
Widget _buildWeekNavigation() {
  return SliverToBoxAdapter(
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Tape background (slightly rotated)
        Transform.rotate(
          angle: -0.017, // -1 degree
          child: Container(
            width: 220,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFDC96).withOpacity(0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Navigation row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavButton(Icons.chevron_left, _goToPreviousWeek, !_canGoPrevious),
            const SizedBox(width: 16),
            Text(
              _formatWeekDates(_currentWeekStart),
              style: TextStyle(
                fontFamily: 'Caveat',
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            _buildNavButton(Icons.chevron_right, _goToNextWeek, !_canGoNext),
          ],
        ),
      ],
    ),
  );
}
```

### 4.5 Weekly Insights Card

```dart
Widget _buildWeeklyInsights() {
  if (_insights == null) return const SliverToBoxAdapter(child: SizedBox());

  return SliverToBoxAdapter(
    child: Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInsightsHeader(),
          const SizedBox(height: 16),
          _buildInsightCard(
            icon: '🎯',
            headline: 'Learning About Each Other',
            detail: 'You explored ${_insights!.totalQuestions} questions together this week, with ${_insights!.alignedAnswers} aligned perspectives',
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            icon: '📅',
            headline: '${_insights!.daysConnected} Days Connected',
            detail: 'You checked in together on ${_insights!.daysConnected} out of 7 days this week',
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            icon: '🎮',
            headline: '${_insights!.totalQuestsCompleted} Quests Completed',
            detail: '${_insights!.dailyQuestsCompleted} Daily Quests, ${_insights!.sideQuestsCompleted} Side Quests, and ${_insights!.stepsTogetherCompleted} Steps Together',
          ),
        ],
      ),
    ),
  );
}
```

### 4.6 Day Sections with Polaroids

```dart
List<Widget> _buildDaySections() {
  // Group entries by day
  final entriesByDay = _groupEntriesByDay(_entries);
  final today = DateTime.now();

  return entriesByDay.entries.map((entry) {
    final date = entry.key;
    final dayEntries = entry.value;
    final isToday = _isSameDay(date, today);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDaySeparator(date, isToday: isToday),
          _buildPolaroidGrid(dayEntries),
        ],
      ),
    );
  }).toList();
}

Widget _buildDaySeparator(DateTime date, {bool isToday = false}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
    child: Row(
      children: [
        Text(
          DateFormat('EEEE, MMM d').format(date),
          style: TextStyle(
            fontFamily: 'Caveat',
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomPaint(
            painter: DashedLinePainter(), // 6px dash, 6px gap
          ),
        ),
        if (isToday) ...[
          const SizedBox(width: 12),
          Text(
            'Today',
            style: TextStyle(
              fontFamily: 'Caveat',
              fontSize: 16,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ],
    ),
  );
}
```

### 4.7 Phase 4 Testing

**Layout Testing:**
- [ ] "Our Journal" header displays in Caveat font
- [ ] Week navigation shows tape decoration behind dates
- [ ] Left arrow disabled when on couple's first week
- [ ] Right arrow disabled when on current week
- [ ] Week dates format correctly ("Dec 23 - 29")
- [ ] Weekly insights card shows all 3 insight rows
- [ ] Day separators show with dashed line
- [ ] "Today" label appears only for current day
- [ ] Paper background has subtle horizontal lines

**Empty State Testing (E1, E2):**
- [ ] New user sees "Your story starts here" message
- [ ] Empty historical week shows "No memories this week"
- [ ] Weekly insights hidden when no entries

**Navigation Testing:**
- [ ] Arrow taps trigger week loading
- [ ] Week loading overlay appears during fetch
- [ ] Scroll resets to top when changing weeks (E32)
- [ ] Rapid arrow taps are debounced (E31)

**Edge Cases:**
- [ ] Mid-week couple (E3): Only shows days from creation
- [ ] Day with 3+ entries shows horizontal scroll (E11)

---

## Phase 5: Polaroid Card Widget

### 5.1 Polaroid Card

**New file:** `app/lib/widgets/journal/journal_polaroid.dart`

```dart
class JournalPolaroid extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final int index; // For rotation variation

  // Rotation based on index: odd = -2deg, even = 1.5deg
  double get _rotation => index.isOdd ? -2 * pi / 180 : 1.5 * pi / 180;

  // Colors per type
  static const _typeColors = {
    JournalEntryType.classicQuiz: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
    JournalEntryType.affirmationQuiz: [Color(0xFFFCE4EC), Color(0xFFF8BBD9)],
    JournalEntryType.youOrMe: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
    JournalEntryType.linked: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
    JournalEntryType.wordSearch: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    JournalEntryType.stepsTogether: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
  };

  // Emoji per type
  static const _typeEmojis = {
    JournalEntryType.classicQuiz: '📝',
    JournalEntryType.affirmationQuiz: '💕',
    JournalEntryType.youOrMe: '🤔',
    JournalEntryType.linked: '🔗',
    JournalEntryType.wordSearch: '🔍',
    JournalEntryType.stepsTogether: '👟',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: _rotation,
        child: Container(
          width: 170,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 40),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildImageArea(),
              const SizedBox(height: 10),
              _buildCaption(),
              const SizedBox(height: 4),
              _buildType(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    final colors = _typeColors[entry.type]!;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            // Center emoji
            Center(
              child: Text(
                _typeEmojis[entry.type]!,
                style: const TextStyle(fontSize: 40),
              ),
            ),
            // Time badge (top right)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DateFormat('h:mm a').format(entry.completedAt),
                  style: TextStyle(
                    fontSize: 9,
                    color: const Color(0xFF666666),
                  ),
                ),
              ),
            ),
            // Result tag (bottom center)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(child: _buildResultTag()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTag() {
    String text;

    if (entry.type == JournalEntryType.linked ||
        entry.type == JournalEntryType.wordSearch) {
      text = 'You ${entry.userScore} · Partner ${entry.partnerScore}';
    } else {
      text = '${entry.alignedCount} aligned';
      if (entry.differentCount > 0) {
        text += ' · ${entry.differentCount} different';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2D2D2D),
        ),
      ),
    );
  }

  Widget _buildCaption() {
    return Text(
      entry.title,
      style: TextStyle(
        fontFamily: 'Caveat',
        fontSize: 16,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildType() {
    return Text(
      _getTypeName(entry.type),
      style: TextStyle(
        fontSize: 10,
        color: const Color(0xFF666666),
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}
```

### 5.2 Phase 5 Testing

**Visual Testing (compare to HTML mockup):**
- [ ] Polaroid has white frame with bottom padding for caption
- [ ] Polaroid rotates based on index (alternating angles)
- [ ] Shadow matches mockup (subtle, offset down)
- [ ] Gradient background matches type colors
- [ ] Emoji centered in image area
- [ ] Time badge in top-right corner
- [ ] Result tag in bottom center of image area

**Type-Specific Testing:**
- [ ] Classic Quiz: Pink gradient, 📝 emoji, "X aligned · Y different" text
- [ ] Affirmation Quiz: Pink/rose gradient, 💕 emoji
- [ ] You or Me: Orange/peach gradient, 🤔 emoji
- [ ] Linked: Blue gradient, 🔗 emoji, "You X · Partner Y" scores
- [ ] Word Search: Green gradient, 🔍 emoji, "You X · Partner Y" scores
- [ ] Steps Together: Purple gradient, 👟 emoji

**Edge Cases:**
- [ ] Long title truncates to 2 lines with ellipsis (E12)
- [ ] Long partner name truncates (E13)
- [ ] Tapping polaroid triggers `onTap` callback

---

## Phase 6: Detail Bottom Sheet

### 6.1 Journal Detail Sheet

**New file:** `app/lib/widgets/journal/journal_detail_sheet.dart`

```dart
class JournalDetailSheet extends StatefulWidget {
  final JournalEntry entry;

  static Future<void> show(BuildContext context, JournalEntry entry) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalDetailSheet(entry: entry),
    );
  }
}

class _JournalDetailSheetState extends State<JournalDetailSheet> {
  // Swipe-to-dismiss support
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dy);
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset > 80) {
          Navigator.pop(context);
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragOffset.clamp(0, double.infinity)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildHeader() {
    // Type-colored emoji badge
    // Title in Caveat
    // Subtitle (type name)
    // Date/time metadata
    // Result/score summary badge
  }

  Widget _buildBody() {
    switch (widget.entry.type) {
      case JournalEntryType.linked:
        return _buildLinkedDetails();
      case JournalEntryType.wordSearch:
        return _buildWordSearchDetails();
      default:
        return _buildQuizDetails();
    }
  }
}
```

### 6.2 Quiz Detail Content

```dart
Widget _buildQuizDetails() {
  return FutureBuilder<List<QuizAnswer>>(
    future: JournalService().getQuizAnswers(widget.entry.contentId!),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const CircularProgressIndicator();

      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: snapshot.data!.length,
        itemBuilder: (context, index) {
          final answer = snapshot.data![index];
          return _buildAnswerCard(answer, index + 1);
        },
      );
    },
  );
}

Widget _buildAnswerCard(QuizAnswer answer, int number) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8F0),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question with number badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNumberBadge(number),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                answer.question,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Answer bubbles
        Row(
          children: [
            Expanded(child: _buildAnswerBubble('You', answer.userAnswer, answer.isAligned)),
            const SizedBox(width: 10),
            Expanded(child: _buildAnswerBubble(partnerName, answer.partnerAnswer, answer.isAligned)),
          ],
        ),
        const SizedBox(height: 12),
        // Match badge
        _buildMatchBadge(answer.isAligned),
      ],
    ),
  );
}
```

### 6.3 Linked/Word Search Detail Content

```dart
Widget _buildLinkedDetails() {
  return FutureBuilder<LinkedMatchDetails>(
    future: JournalService().getLinkedDetails(widget.entry.contentId!),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const CircularProgressIndicator();
      final details = snapshot.data!;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Words Solved Together'),
            _buildWordsGrid(details.words),
            const SizedBox(height: 20),
            _buildSectionTitle('Final Score'),
            _buildScoreCards(details.userScore, details.partnerScore, 'words found'),
            const SizedBox(height: 16),
            _buildWinnerBadge(details.userScore, details.partnerScore),
            const SizedBox(height: 16),
            _buildStatsRow(details.totalTurns, details.totalHintsUsed),
          ],
        ),
      );
    },
  );
}

Widget _buildWordsGrid(List<CompletedWord> words) {
  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: words.map((w) => _buildWordChip(w.word, w.foundByName)).toList(),
  );
}

Widget _buildWordChip(String word, String foundBy) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8F0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(word, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 2),
        Text(foundBy, style: TextStyle(fontSize: 10, color: Color(0xFF666666))),
      ],
    ),
  );
}
```

### 6.4 Phase 6 Testing

**Sheet Interaction:**
- [ ] Sheet slides up from bottom smoothly
- [ ] Sheet has rounded top corners
- [ ] Drag handle visible at top (beige pill)
- [ ] Swipe down dismisses sheet
- [ ] Tapping outside sheet dismisses it
- [ ] Sheet respects max height (85% screen)

**Quiz Details Testing:**
- [ ] Header shows emoji, title, type, date/time
- [ ] Each question shows number badge
- [ ] "You" answer always on left (E27)
- [ ] Partner's name (not "Partner") shown on right
- [ ] Aligned answers show "Aligned" badge
- [ ] Different answers show "Different" badge
- [ ] 100% aligned shows special message (E15)
- [ ] 0% aligned shows "Beautifully different" (E15)

**Linked Details Testing:**
- [ ] "Words Solved Together" section with word chips
- [ ] Each word chip shows word + who found it
- [ ] Score cards show words found per person
- [ ] Tied scores show "🤝 Perfect tie!" (E14)
- [ ] Stats row shows total turns and hints used

**Word Search Details Testing:**
- [ ] All 12 words displayed with finder names
- [ ] Score shows both words found AND points
- [ ] Winner badge or tie message

**Error Handling:**
- [ ] Missing data shows "Details unavailable" (E17)
- [ ] Loading indicator while fetching details

---

## Phase 7: Week Loading Overlay

### 7.1 Week Loading Animation

**New file:** `app/lib/widgets/journal/week_loading_overlay.dart`

```dart
class WeekLoadingOverlay extends StatefulWidget {
  final String targetWeekLabel;
  final bool visible;

  const WeekLoadingOverlay({
    super.key,
    required this.targetWeekLabel,
    required this.visible,
  });
}

class _WeekLoadingOverlayState extends State<WeekLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    // Bounce: translateY 0 → -8 → 0
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 50),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 50),
    ]).animate(_bounceController);

    // Rotation: -3deg → 3deg → -3deg
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -3, end: 3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 3, end: -3), weight: 50),
    ]).animate(_bounceController);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: Container(
          color: const Color(0xFFFFF8F0).withOpacity(0.92),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBouncingPolaroid(),
                const SizedBox(height: 24),
                _buildLoadingText(),
                const SizedBox(height: 12),
                _buildWeekLabel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBouncingPolaroid() {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Transform.rotate(
            angle: _rotationAnimation.value * pi / 180,
            child: Container(
              width: 120,
              height: 140,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD1C1), Color(0xFFFFF5F0)],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(child: Text('📖', style: TextStyle(fontSize: 36))),
                    // Shimmer effect
                    _buildShimmer(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    // Diagonal shimmer animation from top-left to bottom-right
  }

  Widget _buildLoadingText() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Flipping pages',
          style: TextStyle(
            fontFamily: 'Caveat',
            fontSize: 24,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        _buildAnimatedDots(),
      ],
    );
  }

  Widget _buildAnimatedDots() {
    // Three dots with staggered blink animation
  }
}
```

### 7.2 Phase 7 Testing

**Animation Testing:**
- [ ] Overlay fades in smoothly (300ms)
- [ ] Polaroid bounces up and down continuously
- [ ] Polaroid rotates slightly with bounce
- [ ] "Flipping pages..." text in Caveat font
- [ ] Dots animate with stagger (blink effect)
- [ ] Week label shows target week range

**Behavior Testing:**
- [ ] Overlay blocks interaction with content behind
- [ ] Overlay appears during week navigation
- [ ] Overlay appears during initial week load (after first-time screen)
- [ ] Overlay fades out when data loads
- [ ] Overlay respects reduced motion settings

**Timeout Testing (E20):**
- [ ] After 10s, show "Taking longer than expected..."
- [ ] After 20s, show error with retry button
- [ ] Retry button triggers fresh data fetch

---

## Phase 8: Font Setup

### 8.1 Add Google Fonts

**File:** `app/pubspec.yaml`

```yaml
dependencies:
  google_fonts: ^6.1.0
```

Or bundle fonts locally:

```yaml
fonts:
  - family: Caveat
    fonts:
      - asset: assets/fonts/Caveat-Medium.ttf
        weight: 500
      - asset: assets/fonts/Caveat-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/Caveat-Bold.ttf
        weight: 700
  - family: Playfair Display
    fonts:
      - asset: assets/fonts/PlayfairDisplay-Regular.ttf
      - asset: assets/fonts/PlayfairDisplay-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/PlayfairDisplay-Italic.ttf
        style: italic
```

### 8.2 Font Helper

**New file:** `app/lib/config/journal_fonts.dart`

```dart
class JournalFonts {
  static TextStyle get header => TextStyle(
    fontFamily: 'Caveat',
    fontSize: 42,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF2D2D2D),
  );

  static TextStyle get weekDates => TextStyle(
    fontFamily: 'Caveat',
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get dayLabel => TextStyle(
    fontFamily: 'Caveat',
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get polaroidCaption => TextStyle(
    fontFamily: 'Caveat',
    fontSize: 16,
  );

  static TextStyle get sheetTitle => TextStyle(
    fontFamily: 'Caveat',
    fontSize: 26,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get sectionTitle => TextStyle(
    fontFamily: 'Caveat',
    fontSize: 22,
  );

  static TextStyle get insightsTitle => TextStyle(
    fontFamily: 'Playfair Display',
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
}
```

### 8.3 Phase 8 Testing

```bash
# Verify fonts load correctly:
flutter run -d chrome --dart-define=BRAND=togetherRemind
```

**Font Rendering:**
- [ ] Caveat displays as handwritten cursive
- [ ] Playfair Display displays as elegant serif
- [ ] All font weights render correctly (400, 500, 600, 700)
- [ ] Italic variant works for Playfair Display
- [ ] No "missing font" fallback to system font

**Performance:**
- [ ] Fonts load quickly (no visible flash of unstyled text)
- [ ] If using google_fonts: Check network tab for font downloads
- [ ] If bundling locally: Verify assets included in build

**Cross-Platform:**
- [ ] Fonts render correctly on iOS
- [ ] Fonts render correctly on Android
- [ ] Fonts render correctly on Web

---

## Phase 9: API Integration

### 9.1 Journal API Endpoints

**New endpoints needed:**

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/journal/week?start={date}` | Get entries for a week |
| GET | `/api/journal/insights?start={date}` | Get weekly insights |
| GET | `/api/journal/quiz/{sessionId}` | Get quiz answers |
| GET | `/api/journal/linked/{matchId}` | Get linked game details |
| GET | `/api/journal/word-search/{matchId}` | Get word search details |

### 9.2 API Files to Create

```
api/app/api/journal/
├── week/route.ts
├── insights/route.ts
├── quiz/[sessionId]/route.ts
├── linked/[matchId]/route.ts
└── word-search/[matchId]/route.ts
```

### 9.3 Phase 9 Testing

```bash
# Test API endpoints locally:
cd api && npm run dev

# Test with curl:
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/journal/week?start=2024-12-23"
```

**Endpoint Testing:**

| Endpoint | Test Case | Expected |
|----------|-----------|----------|
| `/week` | Valid week with entries | Returns entry array |
| `/week` | Empty week | Returns empty array `[]` |
| `/week` | Future week | Returns empty array |
| `/week` | Week before couple created | Returns 400 error |
| `/insights` | Week with mixed entries | Correct aggregation |
| `/quiz/{id}` | Valid session | All Q&A with alignment |
| `/quiz/{id}` | Invalid session | 404 error |
| `/linked/{id}` | Completed match | Words, scores, stats |
| `/word-search/{id}` | Completed match | Words, points, stats |

**Authentication Testing:**
- [ ] Endpoints require valid JWT
- [ ] User can only access their couple's data
- [ ] Partner can access same entries (E27 consistency)

**Data Integrity:**
- [ ] Entries sorted by completedAt descending
- [ ] Only fully completed quests returned (E5)
- [ ] Linked/Word Search only returned when game complete (E6)

**Performance:**
- [ ] Week endpoint responds < 500ms
- [ ] Insights calculation handles 50+ entries

**Error Handling:**
- [ ] Invalid date format returns 400
- [ ] Missing auth returns 401
- [ ] Server error returns 500 with message

---

## Edge Cases & Empty States

This section covers scenarios that could cause UI issues or confusion.

---

### Empty States

#### E1: Brand New User (No Completed Quests)
**Scenario:** User opens Journal immediately after pairing, before completing any quests.

**Solution:** Show an encouraging empty state with illustration:
```dart
Widget _buildEmptyWeekState() {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Faded polaroid outline illustration
        _buildEmptyPolaroidIllustration(),
        const SizedBox(height: 24),
        Text(
          'Your story starts here',
          style: JournalFonts.header.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 12),
        Text(
          'Complete quests together to fill\nyour journal with memories',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Caveat',
            fontSize: 20,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 24),
        // Optional: CTA button to go to Home
        _buildGoToQuestsButton(),
      ],
    ),
  );
}
```

**Weekly Insights:** Hide the insights card entirely when no entries exist.

#### E2: Week With No Entries (Historical Empty Week)
**Scenario:** User navigates to an old week where no quests were completed (vacation, busy week, etc.)

**Solution:** Different empty state than E1 - acknowledge the gap without judgment:
```dart
Widget _buildHistoricalEmptyState(DateTime weekStart) {
  return Center(
    child: Column(
      children: [
        Text('📖', style: TextStyle(fontSize: 48, opacity: 0.5)),
        const SizedBox(height: 16),
        Text(
          'No memories this week',
          style: JournalFonts.dayLabel,
        ),
        const SizedBox(height: 8),
        Text(
          'Sometimes life gets busy—\nthat's okay!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Caveat',
            fontSize: 18,
            color: Color(0xFF666666),
          ),
        ),
      ],
    ),
  );
}
```

#### E3: Couple Created Mid-Week
**Scenario:** Couple pairs on Thursday. Their first week (Mon-Sun) only has Thu-Sun as possible days.

**Solution:**
- Don't show Mon-Wed as empty days—only show days from couple creation onwards
- Weekly insights should say "3 days connected out of 4 possible" not "out of 7"
- First week navigation should stop at creation week (already handled in `canNavigateToPreviousWeek`)

```dart
int _getPossibleDaysInWeek(DateTime weekStart) {
  final coupleCreatedAt = StorageService().getCouple()?.createdAt;
  final weekEnd = weekStart.add(const Duration(days: 7));

  if (coupleCreatedAt != null && coupleCreatedAt.isAfter(weekStart)) {
    // Couple created mid-week
    return weekEnd.difference(coupleCreatedAt).inDays.clamp(1, 7);
  }
  return 7;
}
```

#### E4: Only Steps Together Entries
**Scenario:** Week where user only completed Steps Together (no quiz/game polaroids).

**Solution:** Steps Together should have its own polaroid style, but consider:
- Steps might complete multiple times per week (daily)
- Could show as single "weekly steps" summary polaroid OR individual daily entries
- **Recommendation:** Show as a single weekly summary polaroid with total steps/days completed

---

### Partial Completion States

#### E5: Quiz Waiting for Partner
**Scenario:** User completed a quiz but partner hasn't answered yet. Should it appear in Journal?

**Solution:** **No** - only show fully completed quests in Journal.
- Journal shows memories, not pending items
- Pending items belong on Home screen quest cards
- Add `status` field to JournalEntry or only create entries on full completion

```dart
// In quiz completion flow - only create journal entry when BOTH complete
if (quizSession.userCompleted && quizSession.partnerCompleted) {
  await _journalService.createEntry(
    type: JournalEntryType.classicQuiz,
    contentId: quizSession.id,
    completedAt: quizSession.completedAt!, // When second person finished
    // ... other fields
  );
}
```

#### E6: Linked/Word Search In Progress
**Scenario:** Linked game started Monday, still in progress Thursday. Turn-based game spans multiple days.

**Solution:**
- Don't show in Journal until game completes
- `completedAt` = when the final turn was played (game finished)
- Show under the day it was completed, not started

#### E7: You or Me Partial (One Person Answered)
**Scenario:** Similar to E5 - one person answered You or Me questions.

**Solution:** Same as E5 - only create Journal entry when both partners complete.

---

### Timing Edge Cases

#### E8: Quest Completed at Day Boundary
**Scenario:** Quest completed at 11:59 PM Sunday vs 12:01 AM Monday.

**Solution:** Use `completedAt` timestamp and group by calendar day in **user's local timezone**.

```dart
/// Group entries by LOCAL date (not UTC)
Map<DateTime, List<JournalEntry>> _groupEntriesByDay(List<JournalEntry> entries) {
  final grouped = <DateTime, List<JournalEntry>>{};

  for (final entry in entries) {
    // Convert to local and strip time component
    final localDate = entry.completedAt.toLocal();
    final dayKey = DateTime(localDate.year, localDate.month, localDate.day);

    grouped.putIfAbsent(dayKey, () => []).add(entry);
  }

  return grouped;
}
```

**Important:** Store `completedAt` as UTC in database, convert to local for display.

#### E9: Partners in Different Timezones
**Scenario:** User in NYC (EST), partner in London (GMT). Quiz completed at 11 PM GMT = 6 PM EST. Which day?

**Solution:** Each user sees entries grouped by THEIR local timezone.
- This means the same quiz might appear on different days for each partner
- This is acceptable—it's "when I experienced it" not "when it happened universally"
- Alternative: Use couple's "home timezone" setting (more complex)

**Recommendation:** Use viewer's local timezone. Add note to insights if helpful.

#### E10: Week Boundary for Insights
**Scenario:** Calculating "days connected" when partners have different timezones.

**Solution:** Use UTC for server-side calculations of insights to ensure consistency.
- "Days with activity" = distinct UTC dates with completed entries
- Both partners see same insight numbers (server-calculated)

---

### Display Edge Cases

#### E11: Many Entries on One Day
**Scenario:** Couple completes 6+ quests on a single day (ambitious!). Grid overflows.

**Solution:** Use horizontal scrolling row for days with 3+ entries:
```dart
Widget _buildPolaroidGrid(List<JournalEntry> entries) {
  if (entries.length <= 2) {
    // Side by side
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: entries.mapIndexed((i, e) => JournalPolaroid(entry: e, index: i)).toList(),
    );
  }

  // Horizontal scroll for 3+
  return SizedBox(
    height: 220,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: entries.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: JournalPolaroid(entry: entries[index], index: index),
      ),
    ),
  );
}
```

#### E12: Long Quiz/Game Names
**Scenario:** Quiz titled "Understanding Your Partner's Love Language Preferences" overflows polaroid.

**Solution:**
- Max 2 lines for title on polaroid
- Ellipsis overflow
- Full title shown in bottom sheet header

```dart
Text(
  entry.title,
  style: JournalFonts.polaroidCaption,
  textAlign: TextAlign.center,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)
```

#### E13: Long Partner Name
**Scenario:** Partner named "Christopher Alexander" - doesn't fit in answer bubbles.

**Solution:**
- Use first name only in polaroid badges ("Chris 3 · You 2")
- Full name in bottom sheet if needed
- Ellipsis for names > 12 characters on polaroid

```dart
String _getDisplayName(String fullName, {int maxLength = 12}) {
  final firstName = fullName.split(' ').first;
  if (firstName.length <= maxLength) return firstName;
  return '${firstName.substring(0, maxLength - 1)}…';
}
```

#### E14: Tied Scores in Games
**Scenario:** Linked ends 3-3, Word Search ends 6-6.

**Solution:** Show tie explicitly, don't show winner badge:
```dart
Widget _buildWinnerBadge(int userScore, int partnerScore) {
  if (userScore == partnerScore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D8), // Neutral beige
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🤝', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text('Perfect tie!', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  // ... winner logic
}
```

#### E15: All Answers Aligned (or All Different)
**Scenario:** Quiz where couple matched 100% or 0%.

**Solution:** Special messaging for extremes:
```dart
String _getAlignmentSummary(int aligned, int different) {
  final total = aligned + different;

  if (different == 0) {
    return '💯 Perfect alignment! All $total answers matched';
  }
  if (aligned == 0) {
    return '🌈 Beautifully different! $total unique perspectives';
  }
  return '$aligned aligned · $different different';
}
```

#### E16: Zero Scores (Game Abandoned?)
**Scenario:** Linked game shows 0-0 or Word Search has 0 words found.

**Solution:** This shouldn't happen if game completed properly. Add validation:
```dart
// Don't create entry if no meaningful data
if (linkedMatch.player1Score == 0 && linkedMatch.player2Score == 0) {
  Logger.warn('Skipping journal entry for empty Linked match', service: 'journal');
  return;
}
```

---

### Data Integrity Edge Cases

#### E17: Session Data Missing
**Scenario:** User taps polaroid to see details, but quiz session was deleted/corrupted.

**Solution:** Graceful degradation in bottom sheet:
```dart
Widget _buildQuizDetails() {
  return FutureBuilder<List<QuizAnswer>?>(
    future: _journalService.getQuizAnswers(widget.entry.contentId!),
    builder: (context, snapshot) {
      if (snapshot.hasError || snapshot.data == null) {
        return _buildDetailsMissing();
      }
      if (snapshot.data!.isEmpty) {
        return _buildDetailsMissing();
      }
      // ... normal rendering
    },
  );
}

Widget _buildDetailsMissing() {
  return Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      children: [
        Text('📝', style: TextStyle(fontSize: 48, opacity: 0.5)),
        const SizedBox(height: 16),
        Text(
          'Details unavailable',
          style: JournalFonts.sectionTitle,
        ),
        const SizedBox(height: 8),
        Text(
          'The detailed answers for this quiz\ncouldn\'t be loaded',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF666666)),
        ),
      ],
    ),
  );
}
```

#### E18: Partner Name Changed
**Scenario:** Partner was "Alex" when quiz completed, now "Alexandra".

**Solution:**
- Store partner name at completion time in JournalEntry
- OR always fetch current name (shows updated name everywhere)
- **Recommendation:** Use current name - journal should feel "alive"

#### E19: Offline Mode / Sync Pending
**Scenario:** User completes quest offline, opens Journal before sync.

**Solution:**
- Create local JournalEntry immediately on completion
- Mark with `syncStatus: pending`
- Show in Journal with subtle indicator (optional)
- Sync when online, update any server-generated fields

```dart
@HiveField(15, defaultValue: 'synced')
String syncStatus; // 'pending', 'synced', 'failed'
```

#### E20: API Timeout During Week Load
**Scenario:** Network slow, week data takes >10s to load.

**Solution:**
- Show loading overlay with timeout
- After 10s, show "Taking longer than expected..." message
- After 20s, show error state with retry button

```dart
Future<void> _loadWeek(DateTime weekStart) async {
  setState(() => _isLoadingWeek = true);

  try {
    final entries = await _journalService
        .getEntriesForWeek(weekStart)
        .timeout(const Duration(seconds: 15));
    // ...
  } on TimeoutException {
    if (mounted) {
      setState(() {
        _isLoadingWeek = false;
        _loadError = 'Connection slow. Pull down to retry.';
      });
    }
  }
}
```

---

### Performance Edge Cases

#### E21: Very Old Couple (100+ Weeks of History)
**Scenario:** Couple using app for 2+ years has massive history.

**Solution:**
- Lazy load weeks on navigation (already planned)
- Don't pre-fetch adjacent weeks
- Consider pagination in API: `/api/journal/week?start=2024-01-01&limit=50`
- Cache recently viewed weeks locally

#### E22: Week With 50+ Entries
**Scenario:** Power users completing many quests per day.

**Solution:**
- Horizontal scroll per day (E11)
- Consider collapsing: "Tuesday - 8 memories" with expand
- Bottom sheet list should use `ListView.builder` for performance

---

### First-Time Experience Edge Cases

#### E23: Journal Opened Before Welcome Quiz
**Scenario:** User taps Journal tab before completing Welcome Quiz (still in onboarding).

**Solution:**
- This shouldn't happen if nav is hidden during onboarding
- If it can happen: show empty state E1
- Consider: lock Journal tab until first quest complete?

#### E24: First Week Only Has Welcome Quiz
**Scenario:** User completed Welcome Quiz, opens Journal. Only entry is Welcome Quiz.

**Solution:**
- Welcome Quiz SHOULD appear in Journal as first memory
- Shows the journey beginning
- Special treatment? "Your first memory together! 🎉" badge on polaroid

```dart
bool _isFirstEntry(JournalEntry entry) {
  // Check if this is the earliest entry for the couple
  return entry.type == JournalEntryType.welcomeQuiz;
}

// In polaroid, show special badge
if (_isFirstEntry(entry)) {
  Positioned(
    top: -8,
    left: -8,
    child: _buildFirstMemoryBadge(),
  ),
}
```

---

### Device & Account Edge Cases

#### E25: App Reinstall / New Device
**Scenario:** User reinstalls app or logs in on new device. Local Hive data is gone.

**Solution:**
- JournalEntry data should be server-authoritative, not just local
- On login, fetch journal entries from server
- `isFirstTimeOpening` should be per-device (local) OR synced (server)
- **Recommendation:** Keep first-time animation local (per device) - it's a nice surprise on new devices too

```dart
// First-time flag is device-local, not synced
// New device = new first-time experience
bool get isFirstTimeOpening =>
    StorageService().getBool('journal_first_open_${deviceId}') ?? true;
```

#### E26: Partner Breaks Up / Account Deleted
**Scenario:** Partner deletes account or couple unlinks. What happens to Journal?

**Solution:**
- Journal entries remain as memories (don't delete)
- Partner name could show as "Your Partner" or preserved name
- Scores/data remain intact
- Consider: read-only mode after break-up?

**Important:** This is a product decision - clarify before implementation.

#### E27: Both Partners View Same Entry
**Scenario:** Both partners tap the same quiz polaroid. Are answer positions consistent?

**Solution:**
- "You" always refers to the viewer
- "Partner" always refers to the other person
- Answer bubbles: Left = You, Right = Partner (consistent for both viewers)
- Each person sees themselves on the left

```dart
// In bottom sheet
final isUser = answer.userId == currentUserId;
return Row(
  children: [
    // Always "You" on left
    _buildAnswerBubble('You', isUser ? answer.response : partnerAnswer),
    _buildAnswerBubble(partnerName, isUser ? partnerAnswer : answer.response),
  ],
);
```

---

### Content Edge Cases

#### E28: Duplicate Quiz Names
**Scenario:** Couple completes "Communication Quiz" twice in same week (re-assigned after streak break).

**Solution:**
- Each entry is unique by `contentId` (session ID)
- Same title is fine - they're different instances
- Time badge distinguishes them

#### E29: Very Short Quiz (1-2 Questions)
**Scenario:** Quiz with only 2 questions - insights feel sparse.

**Solution:**
- Still show normally, but summary adapts:
  - "2 aligned" not "2/2 aligned" (avoid percentages for small n)
- Bottom sheet still works with 1-2 cards

#### E30: Steps Together No Permission
**Scenario:** Steps Together entry exists but user revoked HealthKit permission.

**Solution:**
- Entry still shows (it's a memory of that day)
- If they tap for details and data is unavailable, show E17 state
- Don't retroactively delete entries

---

### UX Polish Edge Cases

#### E31: Rapid Week Navigation
**Scenario:** User rapidly taps prev/next arrows (impatient user).

**Solution:**
- Debounce navigation: ignore taps while `_isLoadingWeek` is true
- Or: Cancel previous fetch when new navigation starts

```dart
CancelableOperation<void>? _currentFetch;

void _goToPreviousWeek() {
  _currentFetch?.cancel();
  final previousWeek = _currentWeekStart.subtract(Duration(days: 7));
  _currentFetch = CancelableOperation.fromFuture(_loadWeek(previousWeek));
}
```

#### E32: Scroll Position When Navigating Weeks
**Scenario:** User scrolls to bottom of Week 1, navigates to Week 2. Where should scroll be?

**Solution:**
- Reset to top when navigating weeks
- Use `ScrollController.jumpTo(0)` after week loads

```dart
final _scrollController = ScrollController();

Future<void> _loadWeek(DateTime weekStart) async {
  // ... load data ...
  if (mounted) {
    _scrollController.jumpTo(0);
    setState(() { /* ... */ });
  }
}
```

#### E33: Pull-to-Refresh
**Scenario:** User pulls down to refresh current week.

**Solution:**
- Wrap content in `RefreshIndicator`
- Re-fetch current week data
- Don't show full loading overlay for refresh (too jarring)

```dart
RefreshIndicator(
  onRefresh: () => _loadWeek(_currentWeekStart, showOverlay: false),
  child: CustomScrollView(...),
)
```

#### E34: Deep Link to Specific Entry
**Scenario:** Push notification says "See your quiz results!" - should deep link to that entry.

**Solution:**
- Deep link format: `app://journal?entryId=xxx` or `app://journal?week=2024-01-01&entryId=xxx`
- Navigate to Journal, load correct week, auto-open bottom sheet

```dart
void _handleDeepLink(String entryId) async {
  final entry = await _journalService.getEntryById(entryId);
  if (entry != null) {
    final weekStart = JournalService.getMondayOfWeek(entry.completedAt);
    await _loadWeek(weekStart);
    if (mounted) {
      JournalDetailSheet.show(context, entry);
    }
  }
}
```

---

### Summary: Empty State Decision Tree

```
Journal Screen Opens
    ↓
Has any entries ever? ──No──→ E1: "Your story starts here" + CTA
    │
   Yes
    ↓
Current week has entries? ──No──→ E2: "No memories this week" (gentler)
    │
   Yes
    ↓
Show normal Journal view
```

---

### Implementation Priority

| Edge Case | Priority | Complexity | Notes |
|-----------|----------|------------|-------|
| E1 (New user) | **P0** | Low | Must have for launch |
| E2 (Empty week) | **P0** | Low | Must have |
| E5 (Waiting for partner) | **P0** | Low | Core logic - only show completed |
| E27 (Both view same entry) | **P0** | Low | "You" always on left |
| E8 (Timezone local grouping) | **P1** | Medium | Correctness |
| E11 (Many entries/day) | **P1** | Medium | Horizontal scroll |
| E12 (Long names truncate) | **P1** | Low | Text overflow |
| E17 (Missing data) | **P1** | Low | Error handling |
| E25 (App reinstall) | **P1** | Medium | Server-authoritative data |
| E31 (Rapid navigation) | **P1** | Low | Debounce |
| E32 (Scroll reset) | **P1** | Low | UX polish |
| E3 (Mid-week couple) | **P2** | Medium | Partial first week |
| E14 (Tied scores) | **P2** | Low | "Perfect tie!" badge |
| E15 (100% aligned) | **P2** | Low | Special message |
| E20 (API timeout) | **P2** | Medium | Retry UI |
| E21 (Old couple perf) | **P2** | Medium | Lazy loading |
| E33 (Pull to refresh) | **P2** | Low | Nice to have |
| E9 (Different TZ) | **P3** | High | Complex, rare |
| E26 (Breakup) | **P3** | High | Product decision needed |
| E34 (Deep link) | **P3** | Medium | Future feature |

---

## Phase 10: Testing Checklist

### 10.1 Visual Testing

- [ ] First-time loading screen animations play correctly
- [ ] Title morphs from "Your Journal" to "Our Journal"
- [ ] Polaroid cards have correct rotation and shadow
- [ ] Week navigation shows tape decoration
- [ ] Weekly insights card renders correctly
- [ ] Bottom sheet slides up smoothly
- [ ] Swipe-to-dismiss works on bottom sheet
- [ ] Week loading overlay shows bouncing polaroid

### 10.2 Data Testing

- [ ] Entries load for current week
- [ ] Week navigation loads previous weeks
- [ ] Quiz answers display correctly in sheet
- [ ] Linked game shows words with who found each
- [ ] Word Search shows words, scores, and points
- [ ] Weekly insights calculate correctly

### 10.3 Navigation Testing

- [ ] Bottom nav shows "Journal" label with new icon
- [ ] First open shows loading screen, subsequent opens skip it
- [ ] Tapping polaroid opens bottom sheet
- [ ] Back navigation works correctly

### 10.4 Edge Case Testing

**Empty States:**
- [ ] E1: New user sees "Your story starts here" with CTA
- [ ] E2: Empty historical week shows "No memories this week"
- [ ] E3: Mid-week couple only shows days from creation onwards
- [ ] Weekly insights hidden when no entries exist

**Partial Completion:**
- [ ] E5: Quiz waiting for partner does NOT appear in Journal
- [ ] E6: In-progress Linked game does NOT appear until complete
- [ ] E7: Partial You-or-Me does NOT appear until complete

**Display:**
- [ ] E11: Day with 3+ entries shows horizontal scroll
- [ ] E12: Long quiz name truncates with ellipsis (2 lines max)
- [ ] E13: Long partner name truncates on polaroid
- [ ] E14: Tied game scores show "Perfect tie!" badge
- [ ] E15: 100% aligned shows special "Perfect alignment" message

**Error Handling:**
- [ ] E17: Missing session data shows "Details unavailable" gracefully
- [ ] E20: Slow network shows timeout message with retry option

**Timezone:**
- [ ] E8: Entries group by user's local timezone
- [ ] Quest completed at 11:59 PM appears on correct day

### 10.5 Couple Journey Testing

Test the full journey from new user to established couple:

| Stage | Test | Expected |
|-------|------|----------|
| Just paired | Open Journal | E1 empty state with CTA |
| After Welcome Quiz | Open Journal | Single polaroid, "First memory!" badge |
| First full week | Complete all quest types | All polaroid types render correctly |
| Navigate to old week | Arrow left | Week loading overlay, then entries |
| Empty past week | Navigate to vacation week | E2 "No memories this week" |
| Many entries day | Complete 5 quests same day | Horizontal scroll |
| Partner waiting | Complete quiz, partner hasn't | NOT in Journal, stays on Home |

---

## Color Reference

| Name | Hex | Usage |
|------|-----|-------|
| bg-gradient-start | #FFD1C1 | Background gradient top |
| bg-gradient-end | #FFF5F0 | Background gradient bottom |
| accent-pink | #FF6B6B | Accent, badges |
| accent-orange | #FF9F43 | Secondary accent |
| cream | #FFF8F0 | Card backgrounds |
| beige | #F5E6D8 | Dividers, handles |
| ink | #2D2D2D | Primary text |
| ink-light | #666666 | Secondary text |
| tape-color | rgba(255,220,150,0.7) | Week nav decoration |
| classic-quiz | #FFEBEE → #FFCDD2 | Classic quiz polaroid |
| affirmation-quiz | #FCE4EC → #F8BBD9 | Affirmation polaroid |
| you-or-me | #FFF3E0 → #FFE0B2 | You or Me polaroid |
| linked | #E3F2FD → #BBDEFB | Linked polaroid |
| word-search | #E8F5E9 → #C8E6C9 | Word Search polaroid |

---

## File Summary

### New Files (18 files)

```
app/lib/models/
├── journal_entry.dart
├── journal_entry.g.dart (generated)
└── weekly_insights.dart

app/lib/services/
└── journal_service.dart

app/lib/screens/
├── journal_screen.dart
└── journal_loading_screen.dart

app/lib/widgets/journal/
├── journal_polaroid.dart
├── journal_detail_sheet.dart
├── week_loading_overlay.dart
├── paper_lines_painter.dart
└── dashed_line_painter.dart

app/lib/config/
└── journal_fonts.dart

app/assets/shared/gfx/
├── journal.png
└── journal_filled.png

api/app/api/journal/
├── week/route.ts
├── insights/route.ts
├── quiz/[sessionId]/route.ts
├── linked/[matchId]/route.ts
└── word-search/[matchId]/route.ts
```

### Modified Files (3 files)

```
app/lib/config/brand/brand_assets.dart    - Add journal icon constants
app/lib/screens/main_screen.dart          - Rename Inbox → Journal
app/pubspec.yaml                          - Add fonts
```

---

## Implementation Order

1. **Phase 1** - Assets & Navigation (quick win, visible change)
2. **Phase 8** - Font setup (needed for all UI)
3. **Phase 2** - Data models & service
4. **Phase 4** - Main journal screen (basic structure)
5. **Phase 5** - Polaroid card widget
6. **Phase 6** - Detail bottom sheet
7. **Phase 3** - Loading screen (can be added last)
8. **Phase 7** - Week loading overlay
9. **Phase 9** - API integration
10. **Phase 10** - Testing & polish
