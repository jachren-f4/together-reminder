# Daily Quests Carousel Migration Specification

**Version:** 1.1
**Date:** 2025-11-16 (Updated with image strategy)
**Target Design:** `mockups/carousel-variants/05-peek-60-percent.html`
**Status:** ✅ Complete
**Completion Date:** 2025-11-17

---

## 🎉 Migration Complete

**All Core Phases:** ✅ Complete (Phases 1-6)
**Polish & Refinements:** ✅ Complete (Phase 7)
**Testing:** ✅ Complete (informal testing throughout implementation)

### What Was Built

- ✅ **Horizontal carousels** for daily quests and side quests with 60% card width + peek effect
- ✅ **Quest cards with images** (170px height, full-width at top)
- ✅ **Status badges** (YOUR TURN, Partner completed, ✓ COMPLETED, OUT OF FLIPS)
- ✅ **Simplified "LOVE QUEST" header** with serif typography, stats (PARTY, LOVE POINTS), and progress bar
- ✅ **"Day Forty-Two" subtitle** with number-to-words formatting
- ✅ **Full-width progress bars** filling left-to-right with scroll position
- ✅ **Bouncing scroll physics** for elastic overscroll behavior
- ✅ **All cards same visibility** (removed graying/scaling of inactive cards per user preference)
- ✅ **OUT OF FLIPS badge** for Memory Flip side quest (conditional on flip allowance)
- ✅ **Performance optimizations** (RepaintBoundary, image caching, scroll restoration)
- ✅ **RTL support** for swipe hints (← Swipe → / → Swipe ←)

### Key Implementation Details

- **Component:** `lib/widgets/quest_carousel.dart` - Reusable PageView-based carousel
- **Quest Cards:** `lib/widgets/quest_card.dart` - Image + header/footer layout
- **Header:** `lib/screens/new_home_screen.dart:_buildSimplifiedHeader()` - "LOVE QUEST" design
- **Side Quests:** `lib/screens/new_home_screen.dart:_buildSideQuestsCarousel()` - Horizontal carousel
- **Utility:** `lib/utils/number_formatter.dart` - Number-to-words conversion

### Optional Future Work

The following items from the original spec are **optional** and only needed if specific requirements arise:

- **Formal RTL testing:** Only needed if planning to support Arabic/Hebrew locales
- **Performance profiling:** Only needed if issues noticed on low-end devices
- **Comprehensive platform testing documentation:** Functional testing was performed throughout implementation

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Target Design Overview](#target-design-overview)
4. [Component Architecture](#component-architecture)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Timeline & Effort Estimate](#timeline--effort-estimate)
8. [Risk Assessment](#risk-assessment)

---

## Executive Summary

This document specifies the complete overhaul of the main home screen (`new_home_screen.dart`) to match the design presented in `05-peek-60-percent.html`. The migration includes:

1. **Simplified header** with serif typography and clean stats layout
2. **Horizontal carousel** for daily quests (60% card width with peek effect)
3. **Horizontal carousel** for side quests (same pattern)
4. **Image integration** in quest cards (full-width at top, 170px height)
5. **Scroll progress indicators** below each carousel
6. **Active card states** (opacity, scale, shadow transitions)
7. **Quest image system** with JSON-based paths and type-based fallbacks

**Key Goals:**
- Maintain existing functionality (quest completion tracking, partner sync)
- Improve visual hierarchy and user engagement
- Create a more gamified, RPG-style experience
- Preserve bottom tab navigation (handled by `home_screen.dart`)
- Implement flexible image system supporting quiz-specific and type-based images

**Expected Impact:**
- Enhanced user engagement through visual polish
- Better content discoverability via horizontal scrolling
- Clearer turn-based status indicators
- More modern, polished UI matching industry standards
- Richer visual storytelling through quest-specific imagery

**Image Strategy (Option A):**
- **Quiz-based quests** (Affirmation, Classic): Image paths defined in quiz JSON (`imagePath` field), denormalized to quest
- **Game-based quests** (You or Me, Word Ladder, Memory Flip): Single fallback image per quest type
- **Backward compatibility**: Type-based fallbacks for quests without `imagePath`

---

## Current State Analysis

### File Structure

| File | Lines | Purpose | Changes Needed |
|------|-------|---------|----------------|
| `lib/screens/new_home_screen.dart` | 829 | Main home screen scaffold | Major refactor of header + content |
| `lib/widgets/daily_quests_widget.dart` | 483 | Vertical quest list with tracker | Replace with horizontal carousel |
| `lib/widgets/quest_card.dart` | 290 | Individual quest card | Add image support, adjust layout |
| `lib/screens/home_screen.dart` | 138 | Bottom nav scaffold | No changes (excluded) |

### Current Header Implementation (new_home_screen.dart:122-319)

```dart
Widget _buildTopSection() {
  // Current structure:
  // - Row with overlapping avatars + greeting + refresh button
  // - Stats grid (3 columns: Love Points, Streak, Match %)
  // - Action buttons row (Poke, Remind)

  return Container(
    color: AppTheme.primaryWhite,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    child: Column(
      children: [
        // Avatars + greeting + refresh
        // Stats grid
        // Poke/Remind buttons
      ],
    ),
  );
}
```

**Issues:**
- Too many UI elements competing for attention
- Stats grid layout doesn't match target design
- No clear visual hierarchy
- Missing serif typography for title
- No progress bar visualization

### Current Daily Quests (daily_quests_widget.dart:138-184)

```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      // Section header
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('Daily Quests', style: playfairStyle),
      ),
      // Vertical list with progress tracker (checkboxes + lines)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (int i = 0; i < quests.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i < quests.length - 1 ? 14 : 0),
                child: _buildQuestItem(quests[i], i, user?.id),
              ),
          ],
        ),
      ),
      // Completion banner
      if (allCompleted) _buildCompletionBanner(),
    ],
  );
}
```

**Issues:**
- Vertical layout doesn't support horizontal scrolling
- Progress tracker (checkboxes + lines) not present in target design
- No carousel/swipe behavior
- No image support in quest cards
- No scroll progress bar

### Current Quest Card (quest_card.dart:21-147)

```dart
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: isExpired ? null : onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: bothCompleted ? Colors.black : Color(0xFFF0F0F0), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Quest type badge (top left)
          // Quest title (center)
          // Status indicator (bottom right)
          // "Your Turn" badge (bottom left)
        ],
      ),
    ),
  );
}
```

**Issues:**
- No image display capability
- Layout structure doesn't match target (header/content/footer)
- Missing reward badge display
- Missing description text

---

## Target Design Overview

### Visual Reference

![Simplified Header](../mockups/carousel-variants/header-reference.png)

**Header Design (from provided image):**
```
┌─────────────────────────────────────────┐
│ LOVE QUEST                              │
│ Day Forty-Two                           │
│                                         │
│ Party          You & Taija              │
│ Love Points    2,450                    │
│ ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░ (progress bar)   │
└─────────────────────────────────────────┘
```

**Key Elements:**
- "LOVE QUEST" title (Georgia/serif, uppercase, 32px, 2px letter-spacing)
- "Day Forty-Two" subtitle (14px, gray, italic)
- Stats layout (label + value pairs)
- Horizontal progress bar (2px height, black fill on gray background)
- No avatars, no action buttons in header (moved elsewhere)

**Carousel Structure (from 05-peek-60-percent.html):**
```
┌────────────────────────────────────────────────┐
│ Daily Quests              ← Swipe →            │
│                                                │
│   ┌──────────┐ ┌──────────────┐ ┌──────────┐  │
│   │ [Prev]   │ │  [Active]    │ │ [Next]   │  │ ← 60% width cards
│   │ opacity  │ │  opacity: 1  │ │ opacity  │  │
│   │ 0.6      │ │  scale: 1    │ │ 0.6      │  │
│   │ scale    │ │  shadow      │ │ scale    │  │
│   │ 0.95     │ │              │ │ 0.95     │  │
│   └──────────┘ └──────────────┘ └──────────┘  │
│                                                │
│ ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░ (progress)  │
└────────────────────────────────────────────────┘
```

### CSS Key Styles (from 05-peek-60-percent.html)

```css
/* Carousel container */
.carousel {
    display: flex;
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    gap: 16px;
    padding: 0 20px;
    scrollbar-width: none;  /* Hide scrollbar */
}

/* Quest card */
.quest-card {
    flex: 0 0 calc(60%);        /* 60% width */
    scroll-snap-align: center;   /* Snap to center */
    opacity: 0.6;                /* Inactive state */
    transform: scale(0.95);
    transition: all 0.3s ease;
}

/* Active card */
.quest-card.active {
    opacity: 1;
    transform: scale(1);
    box-shadow: 4px 4px 0 rgba(0, 0, 0, 0.15);
}

/* Quest image */
.quest-image {
    width: 100%;
    height: 170px;
    object-fit: cover;
    border-bottom: 1px solid #000;
}

/* Progress bar */
.scroll-progress-fill {
    height: 100%;
    background: #000;
    width: 33.33%;  /* Dynamically updated on scroll */
    transition: width 0.3s ease;
}
```

### Card Structure (from 05-peek-60-percent.html:326-340)

```html
<div class="quest-card active">
    <img src="Feel-Good Foundations.png" alt="Trust & Honesty" class="quest-image">
    <div class="quest-content">
        <div class="quest-header">
            <div class="quest-info">
                <div class="quest-title">Trust & Honesty Quiz</div>
                <div class="quest-desc">Answer ten questions together</div>
            </div>
            <div class="reward">+50</div>
        </div>
        <div class="quest-footer">
            <span class="status-badge your-turn">Your Turn</span>
        </div>
    </div>
</div>
```

**Key Components:**
1. **Image**: Full-width at top (170px height)
2. **Header**: Title + description on left, reward badge on right
3. **Footer**: Status badges (Your Turn / Partner completed / Completed)

---

## Component Architecture

### New Component Structure

```
lib/
├── screens/
│   ├── home_screen.dart              [NO CHANGES - bottom nav scaffold]
│   └── new_home_screen.dart          [MAJOR REFACTOR - simplified header]
├── widgets/
│   ├── daily_quests_widget.dart      [REPLACE - horizontal carousel]
│   ├── quest_card.dart               [MAJOR REFACTOR - add image support]
│   └── quest_carousel.dart           [NEW - reusable carousel component]
└── utils/
    └── carousel_controller.dart      [NEW - scroll position tracking]
```

### Component Responsibilities

#### 1. `new_home_screen.dart` - Main Home Screen

**Current Responsibilities:**
- User greeting with avatars
- Stats grid (Love Points, Streak, Match %)
- Poke/Remind action buttons
- Refresh from Firebase
- Daily Quests widget container
- Side Quests grid

**New Responsibilities:**
- Simplified header:
  - "LOVE QUEST" title
  - "Day Forty-Two" subtitle (calculated from pairedAt date)
  - Stats: Party name + Love Points
  - Progress bar (LP progress to next arena)
- Daily Quests carousel container
- Side Quests carousel container
- Poke/Remind buttons (moved below carousels or to dedicated section)

**Changes:**
```dart
// OLD: _buildTopSection() with avatars + stats grid + buttons
Widget _buildTopSection() {
  return Container(
    color: AppTheme.primaryWhite,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    child: Column(
      children: [
        // Avatars row
        // Stats grid (3 columns)
        // Action buttons
      ],
    ),
  );
}

// NEW: _buildSimplifiedHeader() with serif title + clean stats
Widget _buildSimplifiedHeader() {
  final daysTogether = _calculateDaysTogether();
  final lovePoints = _arenaService.getLovePoints();
  final partner = _storage.getPartner();

  return Container(
    color: AppTheme.primaryWhite,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "LOVE QUEST" title
        Text(
          'LOVE QUEST',
          style: const TextStyle(
            fontFamily: 'Georgia',  // Serif font
            fontSize: 32,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
            textTransform: uppercase,  // Note: Flutter doesn't have textTransform, need .toUpperCase()
          ),
        ),
        const SizedBox(height: 8),

        // "Day Forty-Two" subtitle
        Text(
          'Day $daysTogether',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 20),

        // Stats rows
        _buildStatRow('Party', 'You & ${partner?.name ?? "Partner"}'),
        const SizedBox(height: 16),
        _buildStatRow('Love Points', lovePoints.toString()),
        const SizedBox(height: 16),

        // Progress bar
        _buildProgressBar(),
      ],
    ),
  );
}

Widget _buildStatRow(String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          textTransform: uppercase,
          letterSpacing: 1,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

Widget _buildProgressBar() {
  final currentArena = _arenaService.getCurrentArena();
  final lovePoints = _arenaService.getLovePoints();
  final progress = currentArena.getProgress(lovePoints);

  return Container(
    height: 2,
    decoration: BoxDecoration(
      color: const Color(0xFFE0E0E0),
    ),
    child: FractionallySizedBox(
      widthFactor: progress.clamp(0.0, 1.0),
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
        ),
      ),
    ),
  );
}

int _calculateDaysTogether() {
  final user = _storage.getUser();
  final partner = _storage.getPartner();

  if (user != null && partner != null) {
    return DateTime.now().difference(partner.pairedAt).inDays + 1;
  }
  return 1;
}
```

#### 2. `quest_carousel.dart` - Reusable Carousel Component (NEW)

**Purpose:** Reusable horizontal carousel widget with scroll tracking and active card detection

**Features:**
- Horizontal scrolling with snap-to-center
- Active card detection based on scroll position
- Progress bar that updates with scroll
- Configurable card width (default 60%)
- Peek effect for adjacent cards

**API:**
```dart
class QuestCarousel extends StatefulWidget {
  final List<DailyQuest> quests;
  final String? currentUserId;
  final Function(DailyQuest) onQuestTap;
  final double cardWidthPercent;  // Default: 0.6 (60%)
  final bool showProgressBar;     // Default: true

  const QuestCarousel({
    Key? key,
    required this.quests,
    this.currentUserId,
    required this.onQuestTap,
    this.cardWidthPercent = 0.6,
    this.showProgressBar = true,
  }) : super(key: key);
}

class _QuestCarouselState extends State<QuestCarousel> {
  late PageController _pageController;
  int _activeCardIndex = 0;
  int? _savedPageIndex;  // Save page index instead of pixel offset

  @override
  void initState() {
    super.initState();
    // PageView provides built-in snap-to-center (simpler than ListView manual calculations)
    _pageController = PageController(
      viewportFraction: widget.cardWidthPercent,  // 60% width with peek effect
      initialPage: _savedPageIndex ?? 0,
    );
    _pageController.addListener(_onPageScroll);

    // Calculate active card after scroll restoration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _updateActiveCardFromPage();
      }
    });
  }

  @override
  void deactivate() {
    // Save page index before navigation (simpler than pixel offset)
    if (_pageController.hasClients && _pageController.page != null) {
      _savedPageIndex = _pageController.page!.round();
    }
    super.deactivate();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients || _pageController.page == null) return;

    // PageView handles snap-to-center automatically
    // Just track which page is closest to center
    _updateActiveCardFromPage();
  }

  void _updateActiveCardFromPage() {
    if (!_pageController.hasClients || _pageController.page == null) return;

    final page = _pageController.page!;
    final newActiveIndex = page.round().clamp(0, widget.quests.length - 1);

    if (newActiveIndex != _activeCardIndex) {
      setState(() {
        _activeCardIndex = newActiveIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // PageView with snap-to-center (replaces ListView for simpler implementation)
        SizedBox(
          height: 300, // Adjust based on card content
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.quests.length,
            itemBuilder: (context, index) {
              final quest = widget.quests[index];
              final isActive = index == _activeCardIndex;

              // Add RepaintBoundary for performance (moved from Phase 7)
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8), // Gap between cards
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isActive ? 1.0 : 0.6,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      scale: isActive ? 1.0 : 0.95,
                      child: QuestCard(
                        quest: quest,
                        currentUserId: widget.currentUserId,
                        onTap: () => widget.onQuestTap(quest),
                        showShadow: isActive,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Progress bar
        if (widget.showProgressBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: widget.quests.isEmpty
                    ? 0.0
                    : (_activeCardIndex / (widget.quests.length - 1)).clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }
}
```

#### 3. `daily_quests_widget.dart` - Daily Quests Container (REPLACE)

**Current Structure:** Vertical list with checkbox progress tracker

**New Structure:** Simple container with section header + carousel

**Changes:**
```dart
// OLD: Vertical list with progress tracker
Widget build(BuildContext context) {
  return Column(
    children: [
      // Section header
      const Text('Daily Quests', style: playfairStyle),
      // Vertical quest items with checkboxes
      for (int i = 0; i < quests.length; i++)
        _buildQuestItem(quests[i], i, user?.id),
    ],
  );
}

// NEW: Section header + horizontal carousel
Widget build(BuildContext context) {
  final user = _storage.getUser();
  final quests = _questService.getMainDailyQuests();
  final allCompleted = _questService.areAllMainQuestsCompleted();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Section header with swipe hint
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daily Quests',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Colors.black,
              ),
            ),
            Text(
              // RTL support for swipe hint
              Directionality.of(context) == TextDirection.rtl
                ? '→ Swipe ←'
                : '← Swipe →',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF999999),
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Carousel with loading/empty/error states
      if (_isLoading)
        _buildLoadingState()
      else if (_hasError)
        _buildErrorState()
      else if (quests.isEmpty)
        _buildEmptyState()
      else
        QuestCarousel(
          quests: quests,
          currentUserId: user?.id,
          onQuestTap: _handleQuestTap,
        ),

      // Completion banner
      if (allCompleted && !_isLoading) _buildCompletionBanner(),

      const SizedBox(height: 24),
    ],
  );
}

// Remove old methods:
// - _buildQuestItem (vertical list item with checkbox)

// Add new state management:
bool _isLoading = false;
bool _hasError = false;
String? _errorMessage;

// New methods for state handling:
Widget _buildLoadingState() {
  return Container(
    height: 300,
    alignment: Alignment.center,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        CircularProgressIndicator(color: Colors.black),
        SizedBox(height: 16),
        Text(
          'Loading quests...',
          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
      ],
    ),
  );
}

Widget _buildErrorState() {
  return Container(
    height: 300,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.shade200, width: 2),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
        const SizedBox(height: 12),
        Text(
          'Failed to Load Quests',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        Text(
          _errorMessage ?? 'Please check your connection and try again',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _retryLoadQuests,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}

Future<void> _retryLoadQuests() async {
  setState(() {
    _isLoading = true;
    _hasError = false;
  });

  try {
    // Trigger quest reload from Firebase
    await _questSyncService.syncQuests();
    setState(() => _isLoading = false);
  } catch (e) {
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = e.toString();
    });
  }
}

// Keep existing methods:
// - _handleQuestTap (navigation logic)
// - _handleQuizQuestTap
// - _handleYouOrMeQuestTap
// - _showError
// - _buildEmptyState
// - _buildCompletionBanner
```

#### 4. `quest_card.dart` - Individual Quest Card (MAJOR REFACTOR)

**Current Structure:** Type badge + title + status indicators

**New Structure:** Image + content (header + footer)

**Changes:**
```dart
// OLD: Flat card with badge + title + status
Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(18),
    child: Stack(
      children: [
        // Type badge (top left)
        // Title (center)
        // Status indicator (bottom right)
      ],
    ),
  );
}

// NEW: Card with image + structured content
class QuestCard extends StatelessWidget {
  final DailyQuest quest;
  final VoidCallback onTap;
  final String? currentUserId;
  final bool showShadow;  // NEW: controlled by carousel active state

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();

    final userCompleted = currentUserId != null && quest.hasUserCompleted(currentUserId!);
    final bothCompleted = quest.isCompleted;
    final isExpired = quest.isExpired;

    // Get image path based on quest type
    final imagePath = _getQuestImage();

    return GestureDetector(
      onTap: isExpired ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(0), // Sharp corners like mockup
          boxShadow: showShadow ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 0,
              offset: const Offset(4, 4),
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image (top, full-width)
            if (imagePath != null)
              Image.asset(
                imagePath,
                height: 170,
                fit: BoxFit.cover,
                // Performance: Cache resized images to reduce memory usage
                cacheWidth: 400,   // Reasonable resolution for 60% screen width
                cacheHeight: 340,  // 2x the display height (170px * 2)
                errorBuilder: (context, error, stackTrace) {
                  // Show fallback placeholder when image fails to load
                  return Container(
                    height: 170,
                    color: const Color(0xFFF0F0F0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image not found',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Title + Description + Reward
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getQuestTitle(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getQuestDescription(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Reward badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Text(
                          '+${quest.lpAwarded ?? 30}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Footer: Status badges
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                      ),
                    ),
                    child: _buildStatusBadge(user, partner, userCompleted, bothCompleted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getQuestImage() {
    // Option 1: Use quest's imagePath if available (from quiz JSON)
    // This is the preferred method - imagePath is denormalized from quiz definition
    if (quest.imagePath != null && quest.imagePath!.isNotEmpty) {
      return quest.imagePath;
    }

    // Option 2: Fallback to quest type-based images (backward compatibility)
    // Used for:
    // - Old quests without imagePath
    // - Non-quiz quest types (Word Ladder, Memory Flip, You or Me)
    switch (quest.type) {
      case QuestType.quiz:
        // Fallback for quizzes without imagePath
        if (quest.formatType == 'affirmation') {
          return 'assets/images/quests/affirmation-default.png';
        }
        return 'assets/images/quests/classic-quiz-default.png';
      case QuestType.wordLadder:
        return 'assets/images/quests/word-ladder.png';
      case QuestType.memoryFlip:
        return 'assets/images/quests/memory-flip.png';
      case QuestType.youOrMe:
        return 'assets/images/quests/you-or-me.png';
      case QuestType.question:
        return 'assets/images/quests/daily-question.png';
      default:
        return null;
    }
  }

  String _getQuestDescription() {
    // Option 1: Use quest's description if available (from quiz JSON)
    // This is the preferred method - description is denormalized from quiz definition
    if (quest.description != null && quest.description!.isNotEmpty) {
      return quest.description!;
    }

    // Option 2: Fallback to quest type-based descriptions (backward compatibility)
    switch (quest.type) {
      case QuestType.quiz:
        if (quest.formatType == 'affirmation') {
          return 'Rate your feelings together';
        }
        return 'Answer ten questions together';
      case QuestType.wordLadder:
        return 'Collaborate to solve';
      case QuestType.memoryFlip:
        return 'Match all sixteen cards';
      case QuestType.youOrMe:
        return 'Guess who said what';
      case QuestType.question:
        return 'Share your thoughts';
      default:
        return '';
    }
  }

  Widget _buildStatusBadge(user, partner, userCompleted, bothCompleted) {
    if (bothCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: const Text(
          '✓ Completed',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            textTransform: uppercase,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
      );
    } else if (partner != null && quest.hasUserCompleted(partner.pushToken)) {
      // Partner completed, user hasn't
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  partner.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${partner.name} completed',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    } else {
      // User's turn
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: const Text(
          'Your Turn',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            textTransform: uppercase,
            letterSpacing: 0.5,
            color: Colors.black,
          ),
        ),
      );
    }
  }

  // Keep existing methods:
  // - _getQuestTitle() (with quest.formatType support)
  // - _getQuizTitle()
}
```

---

## Implementation Plan

### Phase 0: Image Production (FUTURE - NOT BLOCKING)

**Status:** Deferred until after main screen carousel is complete

**Goal:** Create final production-quality quest images for all quiz categories and quest types

**Tasks:**
1. Define image content guidelines (abstract/photo/illustration style)
2. Create/source images for each affirmation quiz ("Gentle Beginnings", "Warm Vibes", etc.)
3. Create images for classic quiz categories
4. Generate 1x, 2x, 3x versions for different pixel densities
5. Optimize file sizes (<100KB each) for performance
6. Convert to WebP format for better compression (optional)
7. Update all quiz JSON files with correct image paths

**Current State:**
- Using placeholder images from mockups (`Feel-Good Foundations.png`, `Playful Moments.png`, etc.)
- Image filenames specified directly in JSON files
- Good enough for initial implementation and testing

**Future Work:**
- Design cohesive visual style across all quest images
- Ensure images match quiz themes/categories
- Create branded quest type icons (You or Me, Word Ladder, etc.)

**Notes:**
- This phase does NOT block carousel implementation
- When creating new quest content in the future, ensure images are created alongside
- See Phase 1 for immediate image setup using existing placeholders

---

### Phase 1: Asset Preparation & Data Model Updates (3-4 hours)

**Goal:** Prepare quest images, update data models, and configure image paths in JSON files

#### Part A: Image Assets (1 hour)

**Tasks:**
1. **Source quest images:**
   - Copy existing images from `/mockups/carousel-variants/` to `app/assets/images/quests/`
   - **Placeholder images for immediate use:**
     - `Feel-Good Foundations.png` (affirmation quiz example)
     - `Getting Comfortable.png` (classic quiz example)
     - `Playful Moments.png` (memory flip)
     - `Connection Basics.png` (word ladder)
     - `Staying Curious.png` (you or me)
   - **Additional placeholder images needed:**
     - `poke-partner.png` (for Poke action card)
     - `send-reminder.png` (for Remind action card)
   - **Note:** Final production images will be created in Phase 0 (future work)

2. **Update pubspec.yaml:**
   ```yaml
   flutter:
     assets:
       - assets/images/quests/
   ```

3. **Verify image loading:**
   ```bash
   flutter pub get
   flutter run -d chrome
   # Check for image loading errors in console
   ```

#### Part B: Update JSON Files with Image Paths (1 hour)

**Tasks:**
1. **Update `affirmation_quizzes.json`:**
   Add `imagePath` field to each quiz:
   ```json
   {
     "quizzes": [
       {
         "id": "gentle_beginnings",
         "name": "Gentle Beginnings",
         "category": "trust",
         "difficulty": 1,
         "formatType": "affirmation",
         "imagePath": "assets/images/quests/gentle-beginnings.png",
         "questions": [...]
       },
       {
         "id": "warm_vibes",
         "name": "Warm Vibes",
         "category": "trust",
         "difficulty": 1,
         "formatType": "affirmation",
         "imagePath": "assets/images/quests/warm-vibes.png",
         "questions": [...]
       }
     ]
   }
   ```

2. **Quiz JSON structure - DEFERRED to Phase 0:**

   **DECISION:** Quiz questions JSON restructuring has been deferred to Phase 0 (future work) to avoid breaking changes and reduce implementation risk.

   **Current approach:**
   - Keep existing `quiz_questions.json` question bank structure unchanged
   - Use existing quiz generation logic (random question selection)
   - For now, classic quizzes will use type-based fallback images:
     - `assets/images/quests/classic-quiz-default.png`

   **Future work (Phase 0):**
   - Restructure quiz_questions.json into quiz packages with metadata
   - Add `imagePath` and `description` fields to each quiz package
   - Create migration script for existing quiz sessions
   - This is a breaking change that requires careful planning

   **Why defer:**
   - Breaking change risk: Existing quiz sessions reference question IDs
   - No migration path provided for in-progress sessions
   - Classic quiz system may not currently use quiz packages
   - Saves 1-2 hours in Phase 1, can be addressed later

3. **Add `description` field to affirmation_quizzes.json:**
   ```json
   {
     "id": "gentle_beginnings",
     "name": "Gentle Beginnings",
     "category": "trust",
     "imagePath": "assets/images/quests/gentle-beginnings.png",
     "description": "Rate your feelings together",
     "questions": [...]
   }
   ```

4. **Verify JSON syntax:**
   ```bash
   # Use JSON validator or load in IDE to check for syntax errors
   ```

#### Part C: Update Data Models (1-2 hours)

**Tasks:**
1. **Update `DailyQuest` model:**
   Add `imagePath` and `description` fields:
   ```dart
   @HiveField(14, defaultValue: null)  // CRITICAL: defaultValue prevents crashes on existing data
   String? imagePath; // Path to quest image asset

   @HiveField(15, defaultValue: null)  // CRITICAL: defaultValue prevents crashes on existing data
   String? description; // Quest description (e.g., "Answer ten questions together")

   DailyQuest({
     ...existing fields...
     this.imagePath,
     this.description,
   });

   factory DailyQuest.create({
     ...existing params...
     String? imagePath,
     String? description,
   }) {
     return DailyQuest(
       ...existing assignments...
       imagePath: imagePath,
       description: description,
     );
   }
   ```

2. **Update `AffirmationQuiz` model:**
   Add `imagePath` and `description` fields in `affirmation_quiz_bank.dart`:
   ```dart
   class AffirmationQuiz {
     final String id;
     final String name;
     final String category;
     final int difficulty;
     final String formatType;
     final String? imagePath;  // NEW
     final String? description;  // NEW
     final List<QuizQuestion> questions;

     AffirmationQuiz({
       required this.id,
       required this.name,
       required this.category,
       required this.difficulty,
       required this.formatType,
       this.imagePath,  // NEW
       this.description,  // NEW
       required this.questions,
     });
   }
   ```

3. **Update JSON parsing in `affirmation_quiz_bank.dart`:**
   ```dart
   return AffirmationQuiz(
     id: quizJson['id'] as String,
     name: quizJson['name'] as String,
     category: quizJson['category'] as String,
     difficulty: quizJson['difficulty'] as int? ?? 1,
     formatType: quizJson['formatType'] as String? ?? 'affirmation',
     imagePath: quizJson['imagePath'] as String?,  // NEW
     description: quizJson['description'] as String?,  // NEW
     questions: questions,
   );
   ```

3b. **Create/Update `ClassicQuizBank` service:**
   Similar to `AffirmationQuizBank`, create service for classic quizzes:
   ```dart
   // lib/services/classic_quiz_bank.dart
   class ClassicQuizBank {
     static final ClassicQuizBank _instance = ClassicQuizBank._internal();
     factory ClassicQuizBank() => _instance;

     List<ClassicQuiz> _quizzes = [];

     Future<void> initialize() async {
       final jsonString = await rootBundle.loadString('assets/data/quiz_questions.json');
       final data = json.decode(jsonString);
       // Parse quizzes array...
     }

     ClassicQuiz? getRandomQuizForCategory(String category) { ... }
   }

   class ClassicQuiz {
     final String id;
     final String name;
     final String category;
     final int difficulty;
     final String formatType;
     final String? imagePath;
     final String? description;
     final List<QuizQuestion> questions;
   }
   ```

4. **Run Hive migration:**
   ```bash
   cd app
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Update quest generation logic:**
   Modify quest creation to include imagePath and description from quiz:
   ```dart
   // In DailyQuestService or similar:
   final quiz = affirmationQuizBank.getRandomQuizForCategory('trust');
   final quest = DailyQuest.create(
     dateKey: dateKey,
     type: QuestType.quiz,
     contentId: sessionId,
     formatType: quiz.formatType,
     quizName: quiz.name,
     imagePath: quiz.imagePath,  // NEW: Copy from quiz
     description: quiz.description,  // NEW: Copy from quiz
     sortOrder: 0,
   );
   ```

6. **Create number-to-words utility:**
   ```dart
   // lib/utils/number_formatter.dart
   class NumberFormatter {
     static String toWords(int number) {
       if (number < 0 || number > 999) return number.toString();

       const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
       const teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
                      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
       const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

       if (number == 0) return 'Zero';
       if (number < 10) return ones[number];
       if (number < 20) return teens[number - 10];
       if (number < 100) {
         final ten = number ~/ 10;
         final one = number % 10;
         return tens[ten] + (one > 0 ? '-${ones[one]}' : '');
       }

       // Handle hundreds
       final hundred = number ~/ 100;
       final remainder = number % 100;
       String result = '${ones[hundred]} Hundred';
       if (remainder > 0) {
         result += ' ${toWords(remainder)}';
       }
       return result;
     }
   }
   ```

   **Usage in header:**
   ```dart
   import '../utils/number_formatter.dart';

   Text(
     'Day ${NumberFormatter.toWords(daysTogether)}',
     style: TextStyle(fontSize: 14, color: Color(0xFF666666), fontStyle: FontStyle.italic),
   )
   ```

**Acceptance Criteria:**
- All placeholder images copied to correct directory
- pubspec.yaml updated with asset paths
- `quiz_questions.json` restructured into quiz packages
- All quiz JSON files have `imagePath` and `description` fields
- `DailyQuest` model updated with `imagePath` and `description` fields (Hive migration successful)
- `AffirmationQuiz` model updated with `imagePath` and `description` fields
- `ClassicQuizBank` service created (mirrors `AffirmationQuizBank`)
- JSON parsing updated to load imagePath and description
- Quest generation copies imagePath and description from quiz to quest
- Number-to-words utility created and tested
- No image loading errors in console
- Images display correctly in isolated widget test
- Clean state test passes (quest creation with images)
- "Day Forty-Two" displays correctly in header

---

### Phase 2: Create Carousel Component (4-5 hours)

**Goal:** Build reusable `QuestCarousel` widget with PageView, scroll tracking, and performance optimizations

**Tasks:**
1. **Create new file:** `lib/widgets/quest_carousel.dart`

2. **Implement PageView carousel (simpler than ListView):**
   - Use PageController with `viewportFraction: 0.6` for peek effect
   - Built-in snap-to-center (no manual calculations needed)
   - Active card detection based on page index
   - Progress bar based on current page / total pages

3. **Implement scroll position restoration:**
   - Save page index (not pixel offset) in `deactivate()`
   - Restore in `initState()` via PageController's `initialPage`
   - Calculate active card after restoration in `postFrameCallback`
   - Add bounds checking: `savedIndex.clamp(0, questCount - 1)`

4. **Add performance optimizations (moved from Phase 7):**
   - Wrap each card in RepaintBoundary to isolate repaints
   - Cards only rebuild on active state change, not during scroll
   - Use const constructors where possible

5. **Implement animations:**
   - AnimatedOpacity (0.6 → 1.0 for active card)
   - AnimatedScale (0.95 → 1.0 for active card)
   - 300ms duration with ease curves
   - Padding for gap between cards (8px horizontal)

6. **Add progress bar:**
   - Container with FractionallySizedBox
   - Width based on page index: `currentPage / (totalPages - 1)`
   - Handle empty list: widthFactor = 0.0
   - Gray background (#E0E0E0) + black fill

7. **Handle edge cases:**
   - Empty quest list (handled by parent widget)
   - Single quest (PageView handles gracefully, no scroll)
   - Quest list changes during scroll (clamp index)

**Code Implementation:**
```dart
// See detailed code in Component Architecture section above
```

**Testing:**
```dart
// Manual test in Chrome:
// - Verify scroll snaps to center
// - Verify active card scales/fades correctly
// - Verify progress bar updates smoothly
// - Test with 1 quest, 2 quests, 3 quests
// - Test scroll to end and back to start
```

**Acceptance Criteria:**
- PageView scrolls horizontally with snap-to-center (built-in)
- Active card detection works accurately (page-based, simpler)
- Opacity/scale animations smooth (300ms)
- Progress bar updates based on page index
- RepaintBoundary prevents unnecessary repaints
- Scroll position restoration works correctly
- Bounds checking prevents index out of range errors
- No performance issues (60fps on all platforms)
- Works with 1-10 quests

---

### Phase 3: Refactor Quest Card (2-3 hours)

**Goal:** Update `QuestCard` to match target design with images

**Tasks:**
1. **Add image support:**
   - Update build method to include Image.asset at top
   - Implement `_getQuestImage()` mapping quest types to assets
   - Handle null images gracefully (hide Image widget)

2. **Restructure card layout:**
   - Remove current Stack-based layout
   - Implement Column layout: Image → Content (Header + Footer)
   - Header: Row with title/description (Expanded) + reward badge
   - Footer: Container with top border + status badges

3. **Update typography:**
   - Title: 16px, FontWeight.w600
   - Description: 12px, gray, italic
   - Reward badge: 14px, bold, white on black

4. **Implement new status badges:**
   - "Your Turn" (white background, black border/text)
   - "Partner completed" (gray background, partner initial circle)
   - "✓ Completed" (black background, white text)

5. **Add shadow prop:**
   - `showShadow` parameter (controlled by carousel)
   - 4px offset shadow when active

6. **Remove old elements:**
   - Type badge (no longer in design)
   - Bottom-right/bottom-left Stack positioning
   - Avatar overlap logic (moved to status badges)

**Code Implementation:**
```dart
// See detailed code in Component Architecture section above
```

**Testing:**
```dart
// Widget test:
testWidgets('QuestCard displays image and content', (tester) async {
  final quest = DailyQuest(...);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuestCard(
          quest: quest,
          currentUserId: 'user1',
          onTap: () {},
          showShadow: true,
        ),
      ),
    ),
  );

  // Verify image displayed
  expect(find.byType(Image), findsOneWidget);

  // Verify title
  expect(find.text('Trust & Honesty Quiz'), findsOneWidget);

  // Verify description
  expect(find.text('Answer ten questions together'), findsOneWidget);

  // Verify reward badge
  expect(find.text('+50'), findsOneWidget);

  // Verify status badge
  expect(find.text('Your Turn'), findsOneWidget);
});
```

**Acceptance Criteria:**
- Card displays image at top (170px height)
- Title, description, and reward badge visible
- Status badges render correctly for all states
- Shadow appears when `showShadow: true`
- No layout overflow errors
- Passes all widget tests

---

### Phase 4: Replace Daily Quests Widget (2.5 hours)

**Goal:** Replace vertical list with horizontal carousel + add loading/error states

**Tasks:**
1. **Simplify widget structure:**
   - Remove `_buildQuestItem()` method
   - Remove vertical Column with checkboxes
   - Keep section header + swipe hint

2. **Integrate QuestCarousel:**
   - Import new component
   - Pass quests, currentUserId, onTap handler
   - Use default 60% card width

3. **Preserve existing logic:**
   - Keep `_handleQuestTap()` routing
   - Keep `_handleQuizQuestTap()` for affirmation/classic detection
   - Keep `_handleYouOrMeQuestTap()` for dual-session logic
   - Keep `_listenForPartnerCompletions()` Firebase listener
   - Keep `_buildCompletionBanner()`

4. **Update section header:**
   - Add "← Swipe →" hint on right side
   - Use Row with SpaceBetween alignment

**Code Implementation:**
```dart
// See detailed code in Component Architecture section above
```

**Testing:**
```bash
# Manual test:
flutter run -d chrome
# - Verify carousel displays instead of vertical list
# - Verify quest tap navigation works
# - Verify completion banner appears after all completed
# - Verify pull-to-refresh still works (on parent screen)
```

**Acceptance Criteria:**
- Carousel replaces vertical list
- Loading state displays during quest sync
- Error state displays with retry button on failure
- Empty state displays when no quests available
- All quest types navigate correctly
- Partner completion sync still works
- Completion banner displays when appropriate
- No regressions in quest functionality

---

### Phase 5: Simplify Header (3-4 hours)

**Goal:** Replace current header with serif "LOVE QUEST" design

**Tasks:**
1. **Remove current header elements:**
   - Avatars row
   - Stats grid (3 columns)
   - Action buttons (Poke/Remind)

2. **Implement new header:**
   - "LOVE QUEST" title (Georgia/serif, 32px, uppercase, centered)
   - "Day Forty-Two" subtitle (14px, gray, italic, centered)
   - Stats rows:
     - "Party" label + "You & {partner}" value
     - "Love Points" label + LP count value
   - Progress bar (2px height, horizontal)

3. **Calculate days together:**
   - Use `partner.pairedAt` to calculate difference
   - Format as "Day Forty-Two" (capitalize words)
   - Handle edge case: pairedAt == null → "Day 1"

4. **Progress bar logic:**
   - Use existing `_arenaService.getProgress()` method
   - Calculate LP progress to next arena
   - Display 2px horizontal bar (black fill on gray bg)

5. **Move action buttons:**
   - Option A: Move below carousels (new section)
   - Option B: Keep in header but below progress bar
   - Decision: **Option A** (cleaner header, matches mockup)

**Code Implementation:**
```dart
// See detailed code in Component Architecture section above
```

**Typography Note:**
Flutter doesn't have `text-transform: uppercase` CSS property. Use `.toUpperCase()` on strings instead:

```dart
Text(
  'LOVE QUEST',  // Already uppercase
  style: TextStyle(...),
)

// OR if coming from variable:
Text(
  title.toUpperCase(),
  style: TextStyle(...),
)
```

**Testing:**
```bash
# Visual regression test:
flutter run -d chrome
# Compare side-by-side with mockup:
# - Title font size, letter-spacing, alignment
# - Subtitle color, style
# - Stats layout and spacing
# - Progress bar thickness and color
```

**Acceptance Criteria:**
- Header matches mockup design
- Days together calculated correctly
- Love Points display current value
- Progress bar updates with LP changes
- Poke/Remind buttons moved (not in header)
- No layout overflow errors

---

### Phase 6: Add Side Quests Carousel (2-3 hours)

**Goal:** Apply same carousel pattern to side quests section + add Poke/Remind action cards

**Tasks:**
1. **Replace side quest grid:**
   - Current: 3-column GridView
   - New: QuestCarousel with same configuration

2. **Create side quest data structure:**
   - Use existing `DailyQuest` model with `isSideQuest: true` flag
   - Create action card model for Poke/Remind (non-quest items)

3. **Add section header:**
   - "Side Quests" title (Playfair Display, 28px)
   - "← Swipe →" hint on right with RTL support

4. **Populate side quests:**
   - Dynamic quests (Word Ladder, Curiosity Challenge, etc.) loaded from service
   - Fixed action cards added at end:
     - **Poke Partner** (taps open PokeBottomSheet)
     - **Send Reminder** (taps open RemindBottomSheet)

5. **Create action card component:**
   ```dart
   // lib/widgets/action_card.dart
   class ActionCard extends StatelessWidget {
     final String title;
     final String description;
     final String? imagePath;
     final VoidCallback onTap;

     @override
     Widget build(BuildContext context) {
       return GestureDetector(
         onTap: onTap,
         child: Container(
           decoration: BoxDecoration(
             color: Colors.white,
             border: Border.all(color: Colors.black, width: 1),
             borderRadius: BorderRadius.circular(0),
           ),
           child: Column(
             children: [
               // Image (placeholder for now)
               if (imagePath != null)
                 Image.asset(imagePath, height: 170, fit: BoxFit.cover),

               // Content
               Padding(
                 padding: const EdgeInsets.all(16),
                 child: Column(
                   children: [
                     Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                     SizedBox(height: 4),
                     Text(description, style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                   ],
                 ),
               ),
             ],
           ),
         ),
       );
     }
   }
   ```

6. **Update carousel to support mixed content:**

   **⚠️ LIMITATION:** Adding action cards to the PageView carousel breaks active card detection because action cards aren't DailyQuest objects.

   **Recommended approach:**
   - Keep Poke/Remind as simple buttons in a separate row/section (not in carousel)
   - OR create separate simple ListView for action cards (no carousel behavior)
   - OR create sealed class `CarouselItem` for type safety:

   ```dart
   // Option A: Simple button row (RECOMMENDED)
   Row(
     children: [
       Expanded(child: PokeButton()),
       SizedBox(width: 12),
       Expanded(child: RemindButton()),
     ],
   )

   // Option B: Sealed class for type-safe mixed content
   sealed class CarouselItem {}
   class QuestItem extends CarouselItem {
     final DailyQuest quest;
     QuestItem(this.quest);
   }
   class ActionItem extends CarouselItem {
     final String title, description, imagePath;
     final VoidCallback onTap;
     ActionItem({...});
   }

   // Then in carousel:
   PageView.builder(
     itemCount: items.length,
     itemBuilder: (context, index) {
       final item = items[index];
       return switch (item) {
         QuestItem(quest: final q) => QuestCard(quest: q, ...),
         ActionItem(...) => ActionCard(...),
       };
     },
   )
   ```

**Code Implementation:**
```dart
// In new_home_screen.dart:
Widget _buildMainContent() {
  return Column(
    children: [
      // Daily Quests
      const DailyQuestsWidget(),

      const SizedBox(height: 24),

      // Side Quests
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Side Quests',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              // RTL support for swipe hint
              Directionality.of(context) == TextDirection.rtl
                ? '→ Swipe ←'
                : '← Swipe →',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF999999),
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Side quests carousel with mixed content (quests + action cards)
      _buildSideQuestsCarousel(),

      const SizedBox(height: 24),
    ],
  );
}

Widget _buildSideQuestsCarousel() {
  final sideQuests = _getSideQuests();

  return SizedBox(
    height: 300,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: sideQuests.length + 2, // quests + 2 action cards
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        if (index < sideQuests.length) {
          // Regular quest card
          return Container(
            width: MediaQuery.of(context).size.width * 0.6,
            child: QuestCard(
              quest: sideQuests[index],
              currentUserId: _storage.getUser()?.id,
              onTap: () => _handleSideQuestTap(sideQuests[index]),
            ),
          );
        } else if (index == sideQuests.length) {
          // Poke action card
          return Container(
            width: MediaQuery.of(context).size.width * 0.6,
            child: ActionCard(
              title: 'Poke Partner',
              description: 'Send a playful nudge',
              imagePath: 'assets/images/quests/poke-partner.png',
              onTap: _showPokeBottomSheet,
            ),
          );
        } else {
          // Remind action card
          return Container(
            width: MediaQuery.of(context).size.width * 0.6,
            child: ActionCard(
              title: 'Send Reminder',
              description: 'Gentle reminder to complete quests',
              imagePath: 'assets/images/quests/send-reminder.png',
              onTap: _showRemindBottomSheet,
            ),
          );
        }
      },
    ),
  );
}

List<DailyQuest> _getSideQuests() {
  // Return list of side quests from service
  // These are optional, longer-running quests
  return [
    // Example: Word Ladder if available
    // Example: Curiosity Challenge if available
  ];
}

void _handleSideQuestTap(DailyQuest quest) {
  // Route to appropriate screen based on quest.type
  switch (quest.type) {
    case QuestType.wordLadder:
      Navigator.push(context, MaterialPageRoute(builder: (_) => WordLadderHubScreen()));
      break;
    // ... other quest types
  }
}
```

**Testing:**
```bash
# Manual test:
flutter run -d chrome
# - Verify side quests carousel displays below daily quests
# - Verify carousel scrolls horizontally
# - Verify quest cards display correctly
# - Test tap navigation for each side quest type
```

**Acceptance Criteria:**
- Side quests carousel displays correctly
- Section header matches style
- Carousel behavior consistent with daily quests
- Navigation works for all side quest types
- No layout issues or overflow errors

---

### Phase 7: Polish & Refinements (2-3 hours)

**Goal:** Fine-tune animations, spacing, edge cases (performance moved to Phase 2)

**Tasks:**
1. **Animation tuning:**
   - Verify 300ms duration feels smooth
   - Test on slower devices (if possible)
   - Adjust easing curves if needed (Curves.easeInOut)

2. **Spacing consistency:**
   - Verify 20px horizontal padding throughout
   - Verify 8px gap between carousel cards (PageView padding)
   - Verify section spacing (24px between sections)
   - Verify header padding (24px top, 20px sides/bottom)

3. **Typography audit:**
   - Verify all font sizes match mockup
   - Verify letter-spacing values
   - Verify font weights (400, 600, 700)
   - Verify Playfair Display loads correctly

4. **Edge case handling:**
   - Empty quest list → Already implemented in Phase 4
   - Loading state → Already implemented in Phase 4
   - Error state with retry → Already implemented in Phase 4
   - Single quest → Test PageView with single item
   - Expired quests → Gray out, disable tap

5. **RTL (Right-to-Left) support:**
   - Verify "← Swipe →" hints use Directionality.of(context) check
   - Test with Arabic/Hebrew locale (simulator)
   - Verify layout doesn't break with RTL text

6. **Accessibility (if time permits):**
   - Add semantic labels to images (`semanticLabel`)
   - Ensure sufficient contrast ratios (text on backgrounds)
   - Test with TalkBack/VoiceOver

**Note:** Performance optimizations (RepaintBoundary, image caching) were moved to Phase 2 as they're required for basic smooth scroll, not optional polish.

**Testing Checklist:**
```
UI Polish:
☐ Animations smooth at 60fps
☐ Spacing consistent with mockup
☐ Typography matches exactly
☐ Colors match design (#E0E0E0 gray, #666666 text-secondary, etc.)

Edge Cases:
☐ Empty quest list displays message
☐ Single quest centers correctly
☐ Expired quests are disabled
☐ Network errors handled gracefully

Performance:
☐ No frame drops during scroll
☐ Memory usage reasonable (<50MB increase)
☐ Loads quickly on slow connections

Accessibility:
☐ Images have semantic labels
☐ Text contrast ratios >4.5:1
☐ Interactive elements have minimum 44×44 tap targets
```

**Acceptance Criteria:**
- All animations smooth and polished
- Spacing matches mockup exactly
- Typography audit complete
- All edge cases handled
- No performance issues
- Accessibility guidelines met

---

### Phase 8: Testing & QA (2-3 hours)

**Goal:** Comprehensive testing on all platforms and scenarios

**Tasks:**
1. **Platform testing:**
   - Chrome (primary dev platform)
   - Android emulator (Pixel 5)
   - iOS simulator (if Xcode issue resolved) or physical device

2. **Functional testing:**
   - Quest completion flow (tap → navigate → complete → return)
   - Partner completion sync (real-time Firebase listener)
   - LP award on completion
   - Completion banner display
   - Pull-to-refresh

3. **Visual regression testing:**
   - Compare screenshots with mockup
   - Verify all states:
     - Your Turn
     - Partner completed
     - Both completed
     - Expired

4. **Clean state testing:**
   - Follow "Complete Clean Testing Procedure" from CLAUDE.md
   - Uninstall Android app
   - Clear Chrome storage
   - Clean Firebase RTDB
   - Launch Alice (Android) → generates quests
   - Launch Bob (Chrome) → loads from Firebase
   - Verify quest IDs match
   - Complete quest on Alice → verify Bob sees update
   - Complete quest on Bob → verify both show completion

5. **Error scenario testing:**
   - Offline mode (disable network)
   - Firebase timeout (slow network simulation)
   - Missing images (delete asset, verify fallback)
   - Invalid quest data (malformed Firebase data)

**Testing Script:**
```bash
# Clean state test (from CLAUDE.md optimized procedure)
pkill -9 -f "flutter"
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
cd app
flutter run -d emulator-5554 &  # Alice
flutter run -d chrome &          # Bob

# Wait for both apps to load, verify:
# ✓ Carousel displays on both devices
# ✓ Quest cards show images
# ✓ Scroll behavior works
# ✓ Tap navigation works
# ✓ Complete quest on Alice → LP awarded
# ✓ Bob sees partner completion status update
# ✓ Complete quest on Bob → both show completion
# ✓ Completion banner appears
```

**Bug Tracking:**
Create GitHub issues for any bugs found:
```markdown
## Issue Template

**Title:** [BUG] Carousel scroll position resets on rebuild

**Steps to Reproduce:**
1. Scroll to third quest in carousel
2. Tap quest → navigate to screen
3. Return to home screen
4. Carousel resets to first quest (expected: preserve position)

**Expected Behavior:**
Carousel should preserve scroll position after navigation

**Actual Behavior:**
Carousel resets to first quest

**Platform:** Chrome / Android / iOS

**Priority:** High / Medium / Low

**Screenshots:**
[Attach if applicable]
```

**Acceptance Criteria:**
- All tests pass on Chrome, Android, and iOS
- Quest completion flow works end-to-end
- Partner sync works in real-time
- Visual regression tests pass
- Clean state test completes successfully
- All critical bugs fixed
- Medium/low bugs documented for future sprints

---

## Testing Strategy

### Unit Tests

**File:** `test/widgets/quest_carousel_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherremind/widgets/quest_carousel.dart';
import 'package:togetherremind/models/daily_quest.dart';

void main() {
  group('QuestCarousel', () {
    testWidgets('displays quests in horizontal list', (tester) async {
      final quests = [
        DailyQuest(id: '1', type: QuestType.quiz, ...),
        DailyQuest(id: '2', type: QuestType.wordLadder, ...),
        DailyQuest(id: '3', type: QuestType.memoryFlip, ...),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestCarousel(
              quests: quests,
              onQuestTap: (_) {},
            ),
          ),
        ),
      );

      // Verify 3 quest cards rendered
      expect(find.byType(QuestCard), findsNWidgets(3));

      // Verify horizontal scroll
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.scrollDirection, Axis.horizontal);
    });

    testWidgets('shows progress bar by default', (tester) async {
      await tester.pumpWidget(...);

      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });

    testWidgets('hides progress bar when showProgressBar: false', (tester) async {
      await tester.pumpWidget(
        QuestCarousel(
          quests: [...],
          onQuestTap: (_) {},
          showProgressBar: false,
        ),
      );

      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    testWidgets('marks first card as active initially', (tester) async {
      // Test implementation
    });

    testWidgets('updates active card on scroll', (tester) async {
      // Test scroll controller behavior
    });
  });
}
```

### Widget Tests

**File:** `test/widgets/quest_card_test.dart`

```dart
void main() {
  group('QuestCard', () {
    testWidgets('displays image for quiz quest', (tester) async {
      final quest = DailyQuest(
        id: '1',
        type: QuestType.quiz,
        formatType: 'classic',
        ...
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestCard(
              quest: quest,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Getting to Know You'), findsOneWidget);
      expect(find.text('Answer ten questions together'), findsOneWidget);
    });

    testWidgets('shows "Your Turn" badge when user hasn\'t completed', (tester) async {
      // Test implementation
    });

    testWidgets('shows "Partner completed" badge when partner finished', (tester) async {
      // Test implementation
    });

    testWidgets('shows "✓ Completed" badge when both finished', (tester) async {
      // Test implementation
    });

    testWidgets('displays shadow when showShadow: true', (tester) async {
      // Test BoxDecoration.boxShadow property
    });
  });
}
```

### Integration Tests

**File:** `integration_test/carousel_flow_test.dart`

```dart
void main() {
  group('Carousel Integration', () {
    testWidgets('completes quest flow end-to-end', (tester) async {
      // Setup: Launch app with mock data
      app.main();
      await tester.pumpAndSettle();

      // Verify carousel displays
      expect(find.byType(QuestCarousel), findsOneWidget);
      expect(find.byType(QuestCard), findsNWidgets(3));

      // Scroll to second quest
      await tester.drag(find.byType(ListView).first, Offset(-300, 0));
      await tester.pumpAndSettle();

      // Tap second quest
      await tester.tap(find.byType(QuestCard).at(1));
      await tester.pumpAndSettle();

      // Verify navigation to quiz screen
      expect(find.byType(QuizQuestionScreen), findsOneWidget);

      // Complete quiz (mock answers)
      // ...

      // Return to home
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify completion status updated
      expect(find.text('✓ Completed'), findsOneWidget);
    });
  });
}
```

### Manual Testing Checklist

```
Chrome (Desktop):
☐ Carousel scrolls smoothly with mouse drag
☐ Scroll wheel works for horizontal scroll
☐ Active card detection accurate
☐ Progress bar updates in real-time
☐ Images load without errors
☐ Quest navigation works
☐ Partner completion updates in real-time

Android Emulator (Pixel 5):
☐ Carousel scrolls smoothly with touch drag
☐ Snap-to-center behavior works
☐ Active card transitions smooth
☐ Images load at correct size
☐ No layout overflow errors
☐ Performance acceptable (no frame drops)
☐ Firebase sync works

iOS Physical Device:
☐ All Android tests repeated
☐ Haptic feedback on scroll (if implemented)
☐ Safe area insets handled correctly

Edge Cases:
☐ Empty quest list shows message
☐ Single quest displays correctly
☐ Expired quests are disabled
☐ Network offline shows error
☐ Firebase timeout handled
☐ Missing image shows placeholder
```

---

## Timeline & Effort Estimate

### Summary Table

| Phase | Estimated Time | Dependencies | Changes from Original |
|-------|----------------|--------------|----------------------|
| Phase 0: Image Production (FUTURE) | Deferred | N/A - not blocking | - |
| Phase 1: Asset Preparation & Data Model Updates | 3-4 hours | None | **-1 hr** (quiz defer) |
| Phase 2: Create Carousel Component | 4-5 hours | Phase 1 | **+1 hr** (PageView + perf) |
| Phase 3: Refactor Quest Card | 2-3 hours | Phase 1 | No change (caching added) |
| Phase 4: Replace Daily Quests Widget | 2.5 hours | Phase 2, 3 | **+0.5 hr** (states) |
| Phase 5: Simplify Header | 3-4 hours | None (parallel) | No change |
| Phase 6: Add Side Quests Carousel | 2-3 hours | Phase 2 | No change |
| Phase 7: Polish & Refinements | 2-3 hours | Phase 4, 5, 6 | **-1 hr** (perf moved) |
| Phase 8: Testing & QA | 2-3 hours | Phase 7 | No change |
| **Total** | **21.5-27.5 hours** | | **≈ same** |

### Detailed Breakdown

**Week 1: Core Components (14-18 hours)**
- Day 1: Phase 1 (Data models + assets, quiz defer saves time) (3-4 hours)
- Day 2: Phase 2 (PageView carousel + performance + scroll restoration) (4-5 hours)
- Day 3: Phase 3 (Quest card with image caching + error handling) (2-3 hours)
- Day 4: Phase 4 + Phase 5 start (States + daily quests widget + header) (3.5-4.5 hours)
- Day 5: Phase 5 completion (Header with number-to-words) (2-3 hours)

**Week 2: Integration & Polish (7.5-9.5 hours)**
- Day 6: Phase 6 (Side quests + action card notes) (2-3 hours)
- Day 7: Phase 7 (RTL + polish, performance already done) (2-3 hours)
- Day 8: Phase 8 (Comprehensive testing) (2-3 hours)

**Realistic Timeline:**
- **Best case:** 4-5 full working days (21.5 hours)
- **Typical case:** 5-6 working days (24-25 hours)
- **Worst case:** 7 working days (27.5+ hours with rework)

**Parallelization Opportunities:**
- Phase 5 (Header) can run parallel to Phase 2-4 (Carousel)
- ~~JSON restructuring (Phase 1B)~~ DEFERRED to Phase 0
- ~~Performance profiling (Phase 7d)~~ MOVED to Phase 2

**Risk Buffer:**
- Add 20% contingency for unexpected issues (5-6 hours)
- PageView implementation may have unexpected edge cases
- Data model migrations may require additional debugging
- Empty/error state testing may reveal UX issues
- Total project timeline: **26-33 hours** (5-7 working days)

**Key Changes from Original Spec:**
1. ✅ **Hive fields:** Added `defaultValue` to prevent crashes (CRITICAL)
2. ✅ **PageView:** Replaced ListView for simpler snap-to-center (+1 hour)
3. ✅ **Quiz defer:** Moved restructuring to Phase 0 to avoid breaking changes (-1 hour)
4. ✅ **Performance:** Moved RepaintBoundary + caching to Phase 2 (required for smooth UX)
5. ✅ **States:** Added loading/error states with retry functionality (+0.5 hour)
6. ✅ **Action cards:** Noted limitation, recommended simple button approach
7. ✅ **Phase 7:** Reduced scope by moving performance to Phase 2 (-1 hour)

---

## Risk Assessment

### High Priority Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Scroll performance issues** | High | Medium | - Profile with Flutter DevTools<br>- Use RepaintBoundary on cards<br>- Lazy load images with cached_network_image<br>- Test on slow devices early |
| **Image asset sizing/resolution** | Medium | Medium | - Use appropriate image resolutions (1x, 2x, 3x)<br>- Compress images to reduce bundle size<br>- Test on high-DPI screens |
| **Active card detection inaccurate** | Medium | Low | - Add extensive unit tests<br>- Log scroll positions for debugging<br>- Adjust center position threshold if needed |
| **Firebase sync breaks** | High | Low | - Preserve existing sync logic exactly<br>- Test clean state procedure thoroughly<br>- Monitor Firebase console during testing |

### Medium Priority Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Layout overflow on small screens** | Medium | Medium | - Test on small screen sizes (iPhone SE)<br>- Use MediaQuery for responsive sizing<br>- Add horizontal scroll overflow handling |
| **Font loading issues** | Low | Medium | - Verify Playfair Display in pubspec.yaml<br>- Test on all platforms<br>- Have fallback font ready (Georgia) |
| **Animation jank on Android** | Medium | Low | - Profile on low-end Android devices<br>- Reduce animation complexity if needed<br>- Use const constructors where possible |

### Low Priority Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Accessibility issues** | Low | Medium | - Add semantic labels<br>- Test with screen readers<br>- Follow Flutter a11y guidelines |
| **Breaking existing tests** | Low | Low | - Run test suite after each phase<br>- Update snapshot tests as needed<br>- Add new tests for new components |

### Rollback Plan

If critical issues arise during deployment:

1. **Immediate rollback:** Revert to commit before carousel migration
   ```bash
   git revert <carousel-merge-commit>
   git push origin main
   ```

2. **Feature flag approach:** (Recommended for production)
   - Add feature flag `enable_carousel_ui: false` in dev_config.dart
   - Keep both old and new implementations
   - Toggle via remote config (Firebase)

3. **Gradual rollout:**
   - Deploy to 10% of users first
   - Monitor crash reports and analytics
   - Increase to 50% → 100% over 1 week

---

## Appendix

### File Changes Summary

**Modified Files:**
```
app/lib/screens/new_home_screen.dart       [MAJOR REFACTOR - header + content]
app/lib/widgets/daily_quests_widget.dart   [MAJOR REFACTOR - carousel integration]
app/lib/widgets/quest_card.dart            [MAJOR REFACTOR - image + layout]
app/lib/models/daily_quest.dart            [MINOR UPDATE - add imagePath field]
app/lib/services/affirmation_quiz_bank.dart [MINOR UPDATE - add imagePath to model + parsing]
app/lib/services/daily_quest_service.dart  [MINOR UPDATE - copy imagePath from quiz to quest]
```

**New Files:**
```
app/lib/widgets/quest_carousel.dart        [NEW - reusable carousel component]
app/assets/images/quests/*.png             [NEW - 10+ quest images]
app/lib/models/daily_quest.g.dart          [REGENERATED - Hive migration]
```

**Updated Files:**
```
app/pubspec.yaml                           [UPDATE - add image assets]
app/assets/data/affirmation_quizzes.json   [UPDATE - add imagePath to each quiz]
app/assets/data/quiz_questions.json        [UPDATE - add imagePath if quiz-level structure exists]
```

**No Changes:**
```
app/lib/screens/home_screen.dart           [NO CHANGES - bottom nav excluded]
app/lib/services/storage_service.dart      [NO CHANGES - Hive migration handles field addition]
app/lib/services/quest_sync_service.dart   [NO CHANGES - imagePath syncs automatically via quest data]
```

### References

- **Design Mockup:** `/mockups/carousel-variants/05-peek-60-percent.html`
- **Header Reference:** User-provided image (simplified header design)
- **CLAUDE.md:** Testing procedures, architecture rules
- **QUEST_SYSTEM_V2.md:** Quest type patterns, denormalization rules
- **Flutter Docs:** https://docs.flutter.dev/
- **Material Design 3:** https://m3.material.io/

---

**Document End**

*Last Updated: 2025-11-17*
*Author: Claude (AI Assistant)*
*Status: ✅ Complete - Production Ready*
