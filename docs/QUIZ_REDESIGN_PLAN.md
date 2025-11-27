# Quiz Screens Editorial Redesign - Implementation Plan

**Created:** 2025-11-27
**Status:** Ready for Implementation
**Mockups:** `mockups/quiz-redesign/`

---

## Overview

Redesign all quiz screens (Classic, Affirmation, You or Me) to match a newspaper/editorial aesthetic. Pure black & white style, all brands.

### White-Label Compatibility

All colors and fonts are sourced from `BrandLoader()` to support future brand customization:

| Editorial Concept | BrandColors Property | Current Value |
|-------------------|---------------------|---------------|
| Ink (black) | `textPrimary` | #1A1A1A |
| Paper (white) | `surface` | #FFFEFD |
| Light gray | `borderLight` | #F0F0F0 |
| Muted text | `textSecondary` | #6E6E6E |
| Shadow | `shadow` | rgba(0,0,0,0.15) |
| Serif font | `typography.serifFontFamily` | Georgia/Playfair |

### Target Style
- **Font:** Brand's configured serif font (via `BrandLoader().typography`)
- **Colors:** Via `BrandLoader().colors` (see mapping above)
- **Borders:** 2px solid `textPrimary`
- **Shadows:** 8px 8px 0 `shadow` - sharp offset
- **Headers:** UPPERCASE with letter-spacing
- **Corners:** Minimal (0-8px radius)
- **No scroll:** Question/game screens must fit viewport

---

## Mockup → Flutter File Mapping

### Classic Quiz (4 screens)

| Mockup | Flutter File | Key Changes |
|--------|--------------|-------------|
| `classic-intro.html` | `lib/screens/quiz_intro_screen.dart` | See below |
| `classic-question.html` | `lib/screens/quiz_question_screen.dart` | See below |
| `classic-waiting.html` | `lib/screens/quiz_waiting_screen.dart` | See below |
| `classic-results.html` | `lib/screens/quiz_results_screen.dart` | See below |

### Affirmation Quiz (4 screens)

| Mockup | Flutter File | Key Changes |
|--------|--------------|-------------|
| `affirmation-intro.html` | `lib/screens/affirmation_intro_screen.dart` | See below |
| `affirmation-question.html` | `lib/screens/quiz_question_screen.dart` | Shared with Classic |
| `affirmation-waiting.html` | `lib/screens/quiz_waiting_screen.dart` | Shared with Classic |
| `affirmation-results.html` | `lib/screens/affirmation_results_screen.dart` | See below |

### You or Me (4 screens)

| Mockup | Flutter File | Key Changes |
|--------|--------------|-------------|
| `you-or-me-intro.html` | `lib/screens/you_or_me_intro_screen.dart` | See below |
| `you-or-me-game.html` | `lib/screens/you_or_me_game_screen.dart` | See below |
| `you-or-me-waiting.html` | `lib/screens/you_or_me_waiting_screen.dart` | See below |
| `you-or-me-results.html` | `lib/screens/you_or_me_results_screen.dart` | See below |

---

## Phase 1: Create Shared Editorial Widgets

Create `lib/widgets/editorial/` directory with reusable components.

### 1.1 `editorial_styles.dart`

Style constants using **white-label color system** (via BrandLoader):

```dart
import '../config/brand/brand_loader.dart';

/// Editorial design system - uses BrandLoader for white-label compatibility
///
/// Color mapping from editorial concept to BrandColors:
/// - ink (black) → textPrimary
/// - paper (white) → surface
/// - inkLight (gray) → borderLight
/// - inkMuted (#666) → textSecondary
class EditorialStyles {
  // Access colors via BrandLoader (not hardcoded)
  static BrandColors get _colors => BrandLoader().colors;

  // Semantic color getters for editorial design
  static Color get ink => _colors.textPrimary;
  static Color get paper => _colors.surface;
  static Color get inkLight => _colors.borderLight;
  static Color get inkMuted => _colors.textSecondary;

  // Borders
  static const double borderWidth = 2.0;
  static BorderSide get border => BorderSide(color: ink, width: borderWidth);

  // Shadows (sharp offset, editorial style)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: _colors.shadow,
      offset: const Offset(8, 8),
      blurRadius: 0,
    ),
  ];

  // Typography - uses brand's configured serif font
  static TextStyle get headline => TextStyle(
    fontFamily: BrandLoader().typography.serifFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: ink,
    letterSpacing: -0.5,
  );

  static TextStyle get labelUppercase => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: ink,
  );
}
```

**Why this approach:**
- Future brands can customize colors (e.g., sepia paper, navy ink)
- Typography respects brand's configured serif font
- Single source of truth via BrandColors
- Matches existing codebase patterns (see `linked_game_screen.dart`)

### 1.2 `editorial_header.dart`

Combined header with inline progress bar (from question screens):

**Reference:** `classic-question.html` lines 37-97

```dart
class EditorialHeader extends StatelessWidget {
  final String title;
  final String counter; // e.g., "3 of 10"
  final double progress; // 0.0 to 1.0
  final VoidCallback onClose;
}
```

### 1.3 `editorial_button.dart`

Primary (filled) and secondary (outlined) buttons:

**Reference:** `classic-intro.html` lines 265-295

```dart
class EditorialButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isFullWidth;
}
```

### 1.4 `editorial_card.dart`

Card with black border and offset shadow:

**Reference:** `classic-intro.html` lines 131-138

```dart
class EditorialCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool hasShadow;
}
```

### 1.5 `editorial_badge.dart`

Uppercase label badge (e.g., "CLASSIC QUIZ"):

**Reference:** `classic-intro.html` lines 76-87

```dart
class EditorialBadge extends StatelessWidget {
  final String label;
  final bool isInverted; // black bg vs white bg
}
```

---

## Phase 2: Screen-by-Screen Implementation

### 2.1 `classic-intro.html` → `quiz_intro_screen.dart`

**Elements to implement:**

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.header` with back button | AppBar | Replace with custom header, 2px black border bottom |
| `.hero-image` | Image widget | Add 2px black border bottom |
| `.badge` "CLASSIC QUIZ" | Chip | Use `EditorialBadge(isInverted: true)` |
| `.quiz-title` | Text (Playfair) | Keep, ensure 32px size |
| `.quiz-description` | Text | Add `fontStyle: italic`, color #666 |
| `.stats-card` | Container | Use `EditorialCard`, 2px black border |
| `.stats-row` | Row | Border-bottom 1px #e0e0e0 between rows |
| `.section-title` "How It Works" | Text | UPPERCASE, letter-spacing: 2px |
| `.steps` with numbers | Column | Number in 2px black border square |
| `.primary-btn` | FilledButton | Use `EditorialButton(isPrimary: true)` |
| `.reward-hint` | Text | 13px, color #666 |

### 2.2 `classic-question.html` → `quiz_question_screen.dart`

**Elements to implement:**

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.header` combined | AppBar + LinearProgress | Use `EditorialHeader` widget |
| `.progress-bar-bg/fill` | LinearProgressIndicator | 4px height, black fill, gray track |
| Role badge | Container | **REMOVE** (not in compact mockup) |
| Category label | Text | **REMOVE** (not in compact mockup) |
| `.question-text` | Text | 22px, line-height 1.35 |
| `.options` | Column | gap: 8px (reduced from 12px) |
| `.option` | GestureDetector + Container | 2px black border, 14px padding |
| `.option-letter` circle | Container | 32px, 2px border, circular |
| `.option.selected` | - | Background #000, text #fff, letter circle inverted |
| `.primary-btn` | FilledButton | Full width, 14px vertical padding |

**Critical:** Remove footer "Skip" button - only "Next Question"

### 2.3 `classic-waiting.html` → `quiz_waiting_screen.dart`

**Elements to implement:**

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.header` | AppBar | 2px black border, custom close button |
| `.status-icon` spinning | AnimatedIcon | 120px circle, 3px border, CSS spin animation |
| `.status-title` | Text | 28px, font-weight 400 |
| `.status-description` | Text | 16px italic, color #666, max-width 280px |
| `.partner-card` | Container | `EditorialCard` with shadow |
| `.partner-avatar` | CircleAvatar | 56px, 2px border, emoji inside |
| `.partner-status` | Text | 13px italic, "In progress..." |
| Partner progress bar | - | **REMOVED** (no longer showing X of Y) |
| `.poke-btn` | OutlinedButton | `EditorialButton(isPrimary: false)` with icon |
| `.secondary-btn` | TextButton | `EditorialButton(isPrimary: false)` |

### 2.4 `classic-results.html` → `quiz_results_screen.dart`

**Elements to implement:**

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.score-hero` | Container | Center aligned, 40px padding |
| `.score-ring` | CircularProgressIndicator | 160px, 4px stroke, conic gradient simulation |
| `.score-value` | Text | 48px bold |
| `.score-message` | Text | 18px italic |
| `.stats-grid` | Row | 3 columns, 2px black border each |
| `.section-title` | Text | UPPERCASE, letter-spacing 2px |
| `.answer-card` | Container | 2px border, different bg for match/mismatch |
| `.answer-card.match` | - | Background #f8f8f8 |
| `.match-indicator` | Row | Checkmark in black circle or X in outlined circle |
| `.reward-card` | Container | Black background, white text, centered |
| Footer buttons | Row | "Share" + "Done" buttons |

**New functionality:** Share button needs `share_plus` integration

### 2.5 `affirmation-intro.html` → `affirmation_intro_screen.dart`

Similar to classic-intro with these differences:

| Difference | Implementation |
|------------|----------------|
| Badge text | "AFFIRMATION" |
| Stats: "Statements" not "Questions" | Text change |
| Scale preview section | Show 5 numbered circles with labels |

### 2.6 `affirmation-question.html` → `quiz_question_screen.dart`

**Conditional rendering when `questionType == 'scale'`:**

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.statement-card` | Container | 2px border, 4px shadow, centered text |
| `.statement-text` | Text | 20px italic |
| `.scale` (5 circles) | `FivePointScaleWidget` | Restyle: 48px circles, 2px black border |
| `.scale-circle` | Container | Numbers 1-5, black fill when selected |
| `.scale-text` | Text | 9px uppercase labels below each |

**File to update:** `lib/widgets/five_point_scale.dart`

### 2.7 `affirmation-waiting.html` → `quiz_waiting_screen.dart`

Additional element vs classic waiting:

| HTML Element | Implementation |
|--------------|----------------|
| `.your-score-card` | Show user's score (21/25) before partner comparison |

**New functionality:** Pass and display user's score on waiting screen

### 2.8 `affirmation-results.html` → `affirmation_results_screen.dart`

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.score-fraction` | Text | "21/25" format, 64px main number |
| `.score-rating` | Text | "Excellent" - UPPERCASE |
| `.comparison-card` | Container | 2px border, two columns |
| `.waiting-badge` | Container | Gray background if partner pending |
| `.answer-card` | Container | Statement + rating dots |
| `.rating-visual` | Row | 5 dots, filled = black, empty = outline |

### 2.9 `you-or-me-intro.html` → `you_or_me_intro_screen.dart`

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.badge` | Container | "YOU OR ME" black badge |
| `.example-card` | Container | 2px border, 4px shadow |
| `.example-btn` | Row of buttons | "You" / "Partner" toggle demo |
| `.instructions` | Column | Numbered steps with square borders |

### 2.10 `you-or-me-game.html` → `you_or_me_game_screen.dart`

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.header` combined | Custom header | Use `EditorialHeader` |
| `.card-stack` | Stack + AnimatedBuilder | Max height 280px, 2px borders |
| `.question-card.front` | Top card | 6px shadow |
| `.question-card.behind` | Second card | translateY(6px), scale(0.97), opacity 0.5 |
| `.question-label` | Text | 10px uppercase "Who is more likely to..." |
| `.question-text` | Text | 24px italic |
| `.answer-btn` | GestureDetector | 2px border, emoji 28px, text 14px uppercase |
| `.or-divider` | Text | 11px, color #999 |

**Critical:** No footer - answer buttons auto-advance to next question

### 2.11 `you-or-me-waiting.html` → `you_or_me_waiting_screen.dart`

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.completed-badge` | Container | Black bg, white text, checkmark |
| `.answers-preview` | Column | List of user's answers (truncated) |
| `.answer-preview-item` | Row | Question text + answer chip |
| `.partner-status-card` | Container | Partner name + "In progress..." |

**New functionality:** Display user's answers preview while waiting

### 2.12 `you-or-me-results.html` → `you_or_me_results_screen.dart`

| HTML Element | Current Flutter | Change Required |
|--------------|-----------------|-----------------|
| `.score-ring` with conic gradient | CustomPainter | 75% filled ring |
| `.stats-grid` 2 columns | Row | "Matched" and "Different" counts |
| `.answer-card` | Container | Question + both answers + match indicator |
| `.choice-value.match` | Container | Black background highlight |
| `.match-indicator.yes` | Container | Black bg with white checkmark |
| `.match-indicator.no` | Container | White bg with black X |

---

## Phase 3: New Functionality Required

| Feature | Screens | Effort | Notes |
|---------|---------|--------|-------|
| Share results | All results screens | Low | `share_plus` already installed |
| Your answers preview | `you-or-me-waiting` | Low | Data already local |
| Your score on waiting | `affirmation-waiting` | Low | Score calculated before waiting |

---

## Implementation Order

### Phase 1: Create shared widgets (`lib/widgets/editorial/`)

**Files:**
- `editorial_styles.dart`
- `editorial_header.dart`
- `editorial_button.dart`
- `editorial_card.dart`
- `editorial_badge.dart`

**Phase 1 Testing:**
- [ ] Widgets compile without errors
- [ ] Create simple test screen importing all widgets
- [ ] Verify BrandLoader colors are applied (not hardcoded)
- [ ] Test with both brands: `--dart-define=BRAND=togetherRemind` and `--dart-define=BRAND=holyCouples`

---

### Phase 2: Classic Quiz flow (template for others)

**Files:**
- `quiz_intro_screen.dart`
- `quiz_question_screen.dart`
- `quiz_waiting_screen.dart`
- `quiz_results_screen.dart`

**Phase 2 Testing:**
- [ ] Launch Classic Quiz from daily quests
- [ ] Intro screen: Stats card, steps, start button work
- [ ] Question screen: Fits viewport without scrolling
- [ ] Question screen: Option selection + Next button work
- [ ] Waiting screen: Poke button sends notification
- [ ] Results screen: Score displays, answer list scrolls
- [ ] Results screen: Share button works
- [ ] Test on Chrome + Android emulator

---

### Phase 3: Affirmation Quiz flow

**Files:**
- `affirmation_intro_screen.dart`
- `five_point_scale.dart` (widget update)
- `affirmation_results_screen.dart`

**Phase 3 Testing:**
- [ ] Launch Affirmation Quiz from daily quests
- [ ] Intro screen: Scale preview displays correctly
- [ ] Question screen: 5-point scale fits viewport
- [ ] Question screen: Scale selection works (1-5)
- [ ] Waiting screen: User's score displays
- [ ] Results screen: Rating dots show correctly
- [ ] Test on Chrome + Android emulator

---

### Phase 4: You or Me flow

**Files:**
- `you_or_me_intro_screen.dart`
- `you_or_me_game_screen.dart`
- `you_or_me_waiting_screen.dart`
- `you_or_me_results_screen.dart`

**Phase 4 Testing:**
- [ ] Launch You or Me from daily quests
- [ ] Intro screen: Example card demo works
- [ ] Game screen: Card stack fits viewport
- [ ] Game screen: Swipe/tap animations preserved
- [ ] Game screen: Auto-advance on selection works
- [ ] Waiting screen: User's answers preview displays
- [ ] Results screen: Match percentage + breakdown correct
- [ ] Test on Chrome + Android emulator

---

## Testing Checklist

- [ ] All question screens fit viewport without scrolling
- [ ] Results screens scroll entire page (not inner list)
- [ ] Share button works on all results screens
- [ ] Poke/Reminder buttons work on waiting screens
- [ ] Animations preserved in You or Me card stack
- [ ] Both brands (TogetherRemind, HolyCouples) render correctly
- [ ] Web, Android, iOS all display correctly

---

## Files Summary

### New Files (5)
```
lib/widgets/editorial/
├── editorial_styles.dart
├── editorial_header.dart
├── editorial_button.dart
├── editorial_card.dart
└── editorial_badge.dart
```

### Files to Modify (10)
```
lib/screens/
├── quiz_intro_screen.dart
├── quiz_question_screen.dart
├── quiz_waiting_screen.dart
├── quiz_results_screen.dart
├── affirmation_intro_screen.dart
├── affirmation_results_screen.dart
├── you_or_me_intro_screen.dart
├── you_or_me_game_screen.dart
├── you_or_me_waiting_screen.dart
└── you_or_me_results_screen.dart

lib/widgets/
└── five_point_scale.dart
```
