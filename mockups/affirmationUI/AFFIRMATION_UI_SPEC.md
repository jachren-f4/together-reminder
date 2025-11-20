# Affirmation Quest UI Specification

**Design System:** Editorial/Serif Style
**Color Scheme:** Black & White with Red Accents (hearts)
**Typography:** Georgia/Times New Roman (body), Playfair Display (headings)
**Last Updated:** 2024-11-17

---

## Overview

This document outlines the complete user interface flow for Affirmation Quizzes in TogetherRemind. The design follows an editorial/newspaper aesthetic with a focus on readability, clarity, and emotional connection through typography and layout.

### Design Principles

1. **Editorial Aesthetic:** Inspired by classic newspaper design with serif fonts and black borders
2. **Minimalist Color Palette:** Black, white, and grays with red hearts as the only color accent
3. **Clear Hierarchy:** Strong typography with uppercase section headers and clear visual separation
4. **Progressive Disclosure:** Collapsible sections to reduce cognitive load
5. **Comparison Focus:** Results emphasize both individual scores and couple alignment

---

## Screen Flow

```
Intro Screen → Question 1 → Question 2 → Question 3 → Question 4 → Question 5 → Results (Waiting) → Results (Completed)
```

---

## 1. Intro Screen

**File:** `01-intro-screen.html`
**Purpose:** Introduce the quiz, provide context, and set expectations

### Key Elements

#### Header
- **"QUIZ" Badge:** Black background, white text, 12px font, rounded corners
- **Quiz Title:** "Feel-Good Foundations" in large Playfair Display font (36px)
- **Subtitle:** "Trust & Connection" in smaller italic text (14px, gray)

#### Content Sections

**Goal Section:**
```
Title: GOAL (14px, uppercase, 2px letter-spacing)
Content: "Gain awareness of strength and growth areas in how you connect emotionally as a couple."
```

**Research Section:**
```
Title: RESEARCH (14px, uppercase, 2px letter-spacing)
Content: Category-specific research context (varies by quiz type)
Example: "Research in relationship psychology shows that trust is built through consistent, small positive interactions and mutual understanding."
```

**How It Works Section:**
```
Title: HOW IT WORKS (14px, uppercase, 2px letter-spacing)
Content: Bulleted list
- Rate 5 statements about your relationship
- Taija completes the same quiz
- Reflect on your answers together
- Earn 30 LP when both complete
```

#### Call-to-Action
- **Button:** "GET STARTED" (full width, black bg, white text, 18px padding, rounded)
- **Back Link:** "← Back to Daily Quests" (centered, italic, gray)

### Design Specifications
- Container: 420px max-width
- Border: 2px solid black with 8px shadow offset
- Padding: 32px (header), 32px 24px (content)
- Font sizes: 36px (title), 14px (sections), 16px (body text)

---

## 2. Question Screen (Q1-Q5)

**File:** `02-variant-A-side-labels.html`
**Purpose:** Present quiz questions with 5-point Likert scale input

### Key Elements

#### Header
- **Title:** "QUESTION 1/5" (centered, 16px, uppercase, 2px letter-spacing)
- **Back Button:** Visible from Q2 onwards (← icon, top-left)
- **Progress Bar:** 6px height, black fill showing percentage (20%, 40%, 60%, 80%, 100%)

#### Content
- **Category Badge:** "Trust" (11px, uppercase, pill-shaped, gray background)
- **Question Text:** Large Playfair Display (28px), center-aligned, bold
  - Example: "Our relationship feels grounded in positivity."

#### 5-Point Heart Scale (VARIANT A: SIDE LABELS)
```
Layout:
[Strongly disagree] ♡ ♡ ♡ ♡ ♡ [Strongly agree]
                    1  2  3  4  5
```

**Design Details:**
- Labels positioned on left and right sides of hearts
- Label font: 10px, italic, gray, 65px width
- Heart size: 40px
- Hearts gap: 4px
- Empty hearts: 30% opacity, gray outline (♡)
- Filled hearts: 100% opacity, red solid (♥)
- Interaction: Click to fill from left to selected position
- Hover: Opacity increases to 100%

#### Footer
- **Action Button:** "Next Question" (Q1-Q4) or "Submit Answers" (Q5)
  - Disabled state: Gray background, light text, not clickable
  - Enabled state: Black background, white text, clickable
- **Back Link:** "← Previous Question" (disabled on Q1, enabled Q2-Q5)

### Design Specifications
- Container: 420px max-width, min-height 600px
- Scale container: Full width with 8px horizontal padding
- Heart scale total width: ~280px (adjusts to fit with labels)

---

## 3. Results Screen - Waiting State

**File:** `04-waiting-variant-B-card-styles.html`
**Purpose:** Show user's results while waiting for partner to complete

### Key Elements

#### Header
- Standard: "QUIZ RESULTS" (16px, uppercase, centered)

#### Quiz Identity
- **Title:** "Feel-Good Foundations" (28px, Playfair Display, center-aligned)
- **Category Badge:** "Trust" (11px, uppercase, pill-shaped)

#### Your Results Section

**Score Display:**
- Circular progress indicator (200px diameter)
  - Background: Light gray ring
  - Progress: Black ring showing percentage
  - Center text:
    - Percentage: 88% (48px, Playfair Display, bold)
    - Average: 4.4/5.0 (16px, gray)

**Status Card (VARIANT B: DIFFERENT CARD STYLES):**
```
Design: Double border (3px solid), gray background (#f9f9f9), square corners
Padding: 20px
Alignment: Center
Text: "Awaiting Taija's answers" (14px, semi-bold)
```

#### Your Answers Section (COLLAPSIBLE)

**Header (VARIANT B: SHADOW EFFECT):**
```
Design: Single border (2px solid), rounded corners (12px)
Shadow: 3px 3px 0 rgba(0, 0, 0, 0.1)
Hover: Shadow increases, slight translate effect
Background: White
Padding: 16px
Icon: ▼ (rotates 180° when expanded)
```

**Content (Hidden by Default):**
- List of 5 answer cards
- Each card shows:
  - Question number (small, uppercase, gray)
  - Question text (14px)
  - Heart rating display (5 hearts, filled/empty)
  - Score value (24px, bold) e.g., "5/5", "4/5"

### Design Specifications
- Status card uses double border to differentiate from collapsible section
- Collapsible has drop shadow effect for interactive feel
- Clear visual separation through border styles and shadows

---

## 4. Results Screen - Completed State

**File:** `05-results-variant-B-combined-circle.html`, `05-results-video-variant-A-full-width.html`
**Purpose:** Show comparison between both partners' results with match statistics

### Visual Layout Hierarchy

**Top-to-bottom structure:**
```
┌─────────────────────────────────────┐
│ Header: "QUIZ RESULTS"              │
├─────────────────────────────────────┤
│ Celebration Video (full-width)      │
├─────────────────────────────────────┤
│ Content Container:                  │
│  ┌───────────────────────────────┐  │
│  │ Quiz Title + Category Badge   │  │
│  ├───────────────────────────────┤  │
│  │ Your Scores Section:          │  │
│  │  • Dual score circles         │  │
│  │  • Agreement rate stats box   │  │
│  ├───────────────────────────────┤  │
│  │ Compare Answers Section:      │  │
│  │  • Question 1 (matched)       │  │
│  │  • Question 2 (different)     │  │
│  │  • Question 3 (matched)       │  │
│  │  • Question 4 (different)     │  │
│  │  • Question 5 (matched)       │  │
│  ├───────────────────────────────┤  │
│  │ Done Button                   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Key Elements

#### Header
- Reward banner: "+30 Love Points Earned!" (black bg, white text, auto-hides after 3s)
- Standard header: "QUIZ RESULTS"

#### Celebration Video (VARIANT A: FULL-WIDTH BANNER)
```
Position: Between header and quiz identity
File: celebration.mov (fixed video for all affirmation quizzes)
Design: Full-width edge-to-edge banner

Container:
- Width: 100%
- Background: Black (#000)
- Border-bottom: 2px solid black
- Overflow: hidden

Video:
- Width: 100%
- Height: auto
- Display: block
- Autoplay: true
- Loop: true
- Muted: true
- Playsinline: true (for mobile compatibility)
```

**Design Notes:**
- The video shows a couple celebrating, providing positive reinforcement
- Edge-to-edge presentation maximizes impact and visual engagement
- Same celebration video used across all affirmation quizzes for consistency
- Future: Video variety may be introduced later in the project

#### Quiz Identity
- **Title:** "Feel-Good Foundations" (28px, Playfair Display, center-aligned)
- **Category Badge:** "Trust" (11px, uppercase, pill-shaped, gray background)

#### Your Scores Section

**Dual Score Circles:**
```
Layout: Side-by-side, centered
Each circle: 140px diameter

Left Circle (You):
- Label: "YOU" (10px, uppercase, gray)
- Percentage: 88% (32px, Playfair Display, bold)
- Average: 4.4/5.0 (12px, gray)
- Progress ring: Black, 88% filled

Right Circle (Taija):
- Label: "TAIJA" (10px, uppercase, gray)
- Percentage: 92% (32px, Playfair Display, bold)
- Average: 4.6/5.0 (12px, gray)
- Progress ring: Black, 92% filled
```

**Match Statistics Box:**
```
Border: 3px solid black
Background: Light gray (#f9f9f9)
Padding: 20px
Border-radius: 12px

Content:
- Title: "AGREEMENT RATE" (12px, uppercase, gray)
- Score: 60% (48px, Playfair Display, bold)
- Progress bar: 8px height, black fill at 60%
- Description: "3 out of 5 questions matched" (13px, italic, gray)

Match Calculation:
- 60% = 3 matched questions ÷ 5 total questions
- Matched = exact score match between partners
```

#### Compare Answers Section

**Section Title:**
- Text: "Compare answers" (14px, uppercase, bold, 2px letter-spacing)
- Center-aligned
- Margin-bottom: 16px

**All 5 Comparison Cards:**

**Question 1 (MATCHED):**
```
Question: "Our relationship feels grounded in positivity."
You: 5/5 (5 filled hearts)
Taija: 5/5 (5 filled hearts)
Badge: "PERFECT MATCH"
Style: 3px border, gray background
```

**Question 2 (Different):**
```
Question: "I feel good about the way we interact."
You: 4/5 (4 filled, 1 empty)
Taija: 5/5 (5 filled hearts)
Badge: None
Style: 2px border, white background
```

**Question 3 (MATCHED):**
```
Question: "I trust my partner completely."
You: 5/5 (5 filled hearts)
Taija: 5/5 (5 filled hearts)
Badge: "PERFECT MATCH"
Style: 3px border, gray background
```

**Question 4 (Different):**
```
Question: "We communicate openly about our feelings."
You: 4/5 (4 filled, 1 empty)
Taija: 5/5 (5 filled hearts)
Badge: None
Style: 2px border, white background
```

**Question 5 (MATCHED):**
```
Question: "I feel valued and appreciated in our relationship."
You: 4/5 (4 filled, 1 empty)
Taija: 4/5 (4 filled, 1 empty)
Badge: "PERFECT MATCH"
Style: 3px border, gray background
```

**Card Structure (General):**
```
Matched cards:
- Border: 3px solid black (thicker)
- Background: Light gray (#f9f9f9)
- Badge: "PERFECT MATCH" (black bg, white text, 10px)

Different cards:
- Border: 2px solid black (standard)
- Background: White
- No badge

Content (all cards):
- Question number (12px, uppercase, gray)
- Question text (14px, semi-bold, line-height 1.4)
- Answer row 1 (You):
  - Label: "YOU" (11px, uppercase, gray)
  - Hearts: 5 hearts at 18px each, filled (♥) or empty (♡)
  - Score: e.g., "4/5" (20px, bold)
- Answer row 2 (Partner):
  - Label: "TAIJA" (11px, uppercase, gray)
  - Hearts: 5 hearts at 18px each, filled (♥) or empty (♡)
  - Score: e.g., "5/5" (20px, bold)
- Divider: 1px solid #e0e0e0 between rows
- Padding: 16px
- Border-radius: 12px
- Margin-bottom: 16px
```

### Design Specifications
- 3 out of 5 cards shown as "matched" (highlighted)
- 2 out of 5 cards shown as "different" (standard)
- Match calculation: Exact score match = perfect match
- Agreement rate: (matches / total questions) × 100

---

## Design System Reference

### Typography

```css
/* Body Text */
font-family: 'Georgia', 'Times New Roman', serif;
font-size: 14-16px;
line-height: 1.4-1.6;

/* Headings */
font-family: 'Playfair Display', 'Georgia', serif;
font-size: 28-48px;
font-weight: 700;
line-height: 1-1.2;

/* Labels/Small Text */
font-size: 10-12px;
text-transform: uppercase;
letter-spacing: 1-2px;
```

### Color Palette

```css
/* Primary Colors */
--black: #000;
--white: #fff;

/* Grays */
--gray-100: #fafafa;
--gray-200: #f9f9f9;
--gray-300: #f0f0f0;
--gray-400: #e0e0e0;
--gray-600: #666;
--gray-700: #999;
--gray-800: #ccc;

/* Accent */
--heart-red: #dc143c;
```

### Spacing Scale

```
4px   - Minimal gap (hearts)
8px   - Small gap
12px  - Medium gap
16px  - Standard padding
20px  - Large padding
24px  - Section padding
32px  - Major sections
48px  - Screen sections
```

### Border & Shadow

```css
/* Standard Border */
border: 2px solid #000;
border-radius: 12px;

/* Emphasized Border */
border: 3px solid #000;

/* Container Shadow */
box-shadow: 8px 8px 0 rgba(0, 0, 0, 0.1);

/* Interactive Shadow */
box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.1);
```

---

## Interaction Patterns

### Heart Scale Selection
1. User clicks any heart (1-5)
2. All hearts from left to clicked position fill with red
3. Hearts to the right remain empty/gray
4. Action button enables (changes from gray to black)
5. User can change selection by clicking different heart
6. Hover shows preview by increasing opacity

### Collapsible Section
1. Default: Collapsed (content hidden, ▼ icon)
2. Click header to toggle
3. Expand: Smooth max-height animation, icon rotates 180°
4. Content fades in during expansion
5. Collapse: Reverse animation

### Progress Bar
1. Fills left-to-right as user advances through questions
2. Each question: 20% increment (5 questions total)
3. Smooth transition animation (0.3s ease)

---

## Responsive Behavior

### Container Width
- Maximum: 420px
- Minimum: 320px
- Padding: 20px on viewport edges

### Heart Scale Adjustments
- Maintains 5 hearts visible at all times
- Reduces heart size on very small screens (min 36px)
- Labels reduce to 9px font on small screens

### Text Wrapping
- Question text: Max 2-3 lines before wrapping
- Labels: Fixed width with line breaks for "Strongly disagree/agree"
- Titles: Center-aligned, wraps naturally

---

## Accessibility Notes

### Color Contrast
- All text meets WCAG AA standards
- Black on white: 21:1 ratio
- Gray (#666) on white: 5.74:1 ratio
- Hearts use both color (red) and shape (filled vs outline) for accessibility

### Interactive Elements
- All clickable areas minimum 44x44px touch target
- Focus states visible on all interactive elements
- Keyboard navigation supported (Tab, Enter, Arrow keys)

### Screen Reader Support
- Semantic HTML structure (header, section, nav)
- ARIA labels for progress indicators
- ARIA live regions for dynamic content
- Heart scale announces "X out of 5 selected"

---

## Animation Specifications

### Transitions
```css
/* Standard */
transition: all 0.2s ease;

/* Slow */
transition: all 0.3s ease;

/* Progress */
transition: stroke-dashoffset 1s ease;
```

### Keyframes
```css
/* Reward Banner Slide */
@keyframes slideDown {
  from { transform: translateY(-100%); }
  to { transform: translateY(0); }
}
```

---

## File Structure

```
/mockups/affirmationUI/
├── AFFIRMATION_UI_SPEC.md (this file)
├── 01-intro-screen.html (selected)
├── 02-variant-A-side-labels.html (selected)
├── 02-variant-B-individual-labels.html
├── 02-variant-C-arrow-gradient.html
├── 03-question-screen-q5.html
├── 04-waiting-variant-B-card-styles.html (selected)
├── 04-waiting-variant-A-solid-status.html
├── 04-waiting-variant-C-minimal-status.html
├── 05-results-variant-B-combined-circle.html (selected)
├── 05-results-variant-A-side-by-side.html
└── 05-results-variant-C-stacked-stats.html
```

---

## Implementation Notes for Flutter

### Widget Structure
```
AffirmationIntroScreen
  └── SingleChildScrollView
      ├── QuizBadge
      ├── Title (Playfair Display custom font)
      ├── Section widgets (Goal, Research, How it works)
      └── CTAButton

QuizQuestionScreen
  └── Column
      ├── AppBar (with back button after Q1)
      ├── LinearProgressIndicator (custom styled)
      ├── CategoryBadge
      ├── QuestionText (Playfair Display)
      ├── FivePointHeartScale (custom widget)
      │   ├── SideLabels (positioned)
      │   └── HeartRow (interactive)
      └── BottomActionBar

AffirmationResultsWaitingScreen
  └── SingleChildScrollView
      ├── QuizHeader
      ├── CircularProgressIndicator (custom painted)
      ├── StatusCard (variant B: double border)
      ├── CollapsibleAnswersSection (animated)
      │   ├── AnimatedContainer (for expansion)
      │   └── AnswerCardsList
      └── DoneButton

AffirmationResultsCompletedScreen
  └── SingleChildScrollView
      ├── RewardBanner (auto-dismiss after 3s)
      ├── QuizHeader
      ├── DualScoreCircles (custom painted)
      ├── MatchStatisticsBox
      ├── ComparisonCardsList
      │   ├── MatchedCard (highlighted)
      │   └── DifferentCard (standard)
      └── DoneButton
```

### Custom Widgets to Create
1. **FivePointHeartScale** - Interactive heart selector with side labels
2. **CircularScoreIndicator** - Custom painted circular progress with center text
3. **CollapsibleSection** - Animated expand/collapse container
4. **MatchedComparisonCard** - Highlighted card with perfect match badge
5. **RewardBanner** - Auto-dismissing animated banner

### Font Setup
```yaml
# pubspec.yaml
fonts:
  - family: PlayfairDisplay
    fonts:
      - asset: fonts/PlayfairDisplay-Bold.ttf
        weight: 700
```

### Theme Extensions
```dart
TextTheme(
  // Headings
  displayLarge: TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 48,
    fontWeight: FontWeight.w700,
  ),
  // Body
  bodyMedium: TextStyle(
    fontFamily: 'Georgia',
    fontSize: 14,
  ),
  // Labels
  labelSmall: TextStyle(
    fontFamily: 'Georgia',
    fontSize: 10,
    letterSpacing: 1.2,
  ),
)
```

---

## Future Enhancements

### Potential Features
- [ ] Animated transitions between questions
- [ ] Sound effects for heart selection
- [ ] Haptic feedback on selection
- [ ] Share results as image
- [ ] Historical comparison (track progress over time)
- [ ] Category insights page
- [ ] Couples discussion prompts based on mismatched answers

### Design Variations to Explore
- [ ] Dark mode variant
- [ ] Alternative color accents
- [ ] Landscape layout optimizations
- [ ] Tablet-specific layouts
- [ ] Animation presets (subtle vs. playful)

---

**Document Version:** 1.0
**Created:** 2024-11-17
**Author:** Design System
**Status:** Approved for Implementation
