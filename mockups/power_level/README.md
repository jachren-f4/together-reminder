# Power Level Memory Challenge - Design Mockups

HTML mockups for the Power Level Memory Challenge feature, designed to match TogetherRemind's minimalist black & white aesthetic.

## Overview

A competitive memory challenge where couples test their recall of past quiz answers. Players answer 5 questions about their previous quiz responses, with correct answers charging their "power level." The player with the highest power level wins!

## Files

- **`index.html`** - Hub page with navigation to all screens
- **`intro.html`** - Eligibility check and challenge intro
- **`question.html`** - Question screen during gameplay
- **`waiting.html`** - Loading state after player completion
- **`clash.html`** - Beam struggle animation
- **`results.html`** - Victory/defeat screens with stats

## Design System

### Color Palette

```css
--background: #FAFAFA;        /* Page background */
--card-bg: #FFFEFB;           /* Card backgrounds */
--text-primary: #1A1A1A;      /* Primary text/black */
--text-secondary: #6E6E6E;    /* Secondary text/gray */
--border: #F0F0F0;            /* Light gray borders */
--success-green: #22C55E;     /* Success states */
--warning-orange: #F59E0B;    /* Warning/defeat states */
```

### Typography

**Playfair Display (Serif) - Headlines:**
- Font sizes: 20px, 24px, 28px, 32px, 36px, 48px, 64px
- Font weights: 600, 700
- Letter spacing: -0.5px to -0.2px
- Usage: Headlines, large numbers, power levels

**Inter (Sans-Serif) - Body:**
- Font sizes: 11px, 12px, 13px, 14px, 15px, 17px
- Font weights: 400, 500, 600
- Letter spacing: Default (0.5px for uppercase labels)
- Usage: Body text, buttons, labels

### Component Styles

**Cards:**
```css
background: #FFFEFB;
border: 2px solid #F0F0F0;
border-radius: 16px (standard) or 24px (modals);
padding: 24px;
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
```

**Buttons:**
```css
/* Primary */
background: #1A1A1A;
color: white;
border-radius: 12px;
padding: 16px;
font-size: 17px;
font-weight: 600;

/* Secondary */
background: #FAFAFA;
color: #1A1A1A;
border: 2px solid #F0F0F0;
```

**Badges:**
```css
background: rgba(34, 197, 94, 0.1);
border: 1px solid rgba(34, 197, 94, 0.3);
border-radius: 8px;
padding: 6px 12px;
font-size: 11px;
font-weight: 600;
text-transform: uppercase;
letter-spacing: 0.5px;
```

**Stat Boxes:**
```css
background: #FAFAFA;
border-radius: 12px;
padding: 16px;
/* Playfair Display for values, Inter for labels */
```

### Spacing System

Consistent increments: `4px`, `8px`, `12px`, `16px`, `20px`, `24px`, `32px`, `40px`, `48px`

## Feature Specifications

### Eligibility Requirements
- **Minimum Quizzes:** 10 completed quizzes
- **Question Pool:** Generated from quiz history
- **Unlock State:** Dynamic based on quiz count

### Gameplay Mechanics
- **Question Count:** 5 questions per challenge
- **Power Level Formula:** Base (500) + (200 × correct answers) + speed bonus
- **Answer Options:** 4 multiple choice per question
- **Historical Context:** Shows original quiz name and date

### Rewards
- **Victory:** +50 LP
- **Defeat:** +20 LP
- **Stats Tracked:** Correct answers, accuracy %, power level, average time

### Screen Flow
1. **Intro** → Eligibility check
2. **Question** → 5 questions (charging phase)
3. **Waiting** → Loading after completion
4. **Clash** → Beam struggle animation
5. **Results** → Victory/defeat with stats

## Design Rationale

### Why Black & White Minimal?
- **Brand Consistency:** Matches TogetherRemind's existing design language
- **Focus on Content:** Minimal distractions from gameplay
- **Readability:** High contrast for accessibility
- **Timeless:** Won't feel dated

### Why Playfair Display + Inter?
- **Contrast:** Serif headlines with sans-serif body creates hierarchy
- **Elegance:** Playfair Display adds sophistication to power levels
- **Readability:** Inter is highly legible at small sizes
- **Pairing:** Well-established typographic combination

### Why Minimal Shadows?
- **Flat Design:** Aligns with modern UI trends
- **Borders Over Shadows:** Creates cleaner separation
- **Performance:** Fewer shadows = better rendering
- **Consistency:** Matches existing TogetherRemind screens

## Implementation Notes

### Key Differences from JRPG Mockups
The previous JRPG-style mockups (`mockups/jrpg/5_power_level_showdown.html` and `mockups/jrpg/5b_power_level_memory.html`) featured:
- Bold colors (blues, reds, golds)
- Heavy shadows and gradients
- "Energy beam" visual effects
- Gaming-style UI elements

These new mockups replace that aesthetic with:
- Black & white minimal palette
- Subtle borders and minimal shadows
- Clean typography-focused design
- Matches actual app's visual language

### Responsive Design
- **Mobile-First:** Optimized for 375px-768px viewports
- **Flexible Grids:** CSS Grid for 2-column layouts
- **Scalable Text:** Relative units where appropriate
- **Touch Targets:** 44px minimum (iOS guidelines)

### Animation Considerations
- **Clash Screen:** Emoji rotation for "beam struggle"
- **Waiting Screen:** Subtle spinner animation
- **Power Meters:** Optional pulsing effect on active player
- **All Animations:** CSS-based, no JavaScript required

## Future Considerations

### Potential Enhancements
- **Dark Mode:** Invert colors (#1A1A1A background, #FFFEFB text)
- **Accessibility:** ARIA labels for screen readers
- **Localization:** RTL support for Arabic/Hebrew
- **Sound Effects:** Optional audio cues for power-ups

### Performance Optimizations
- **Font Loading:** Preconnect to Google Fonts
- **CSS Animations:** Use `transform` for GPU acceleration
- **Image Sprites:** If adding icons/illustrations
- **Lazy Loading:** For background animations

## References

**Extracted from TogetherRemind Flutter Code:**
- `app/lib/screens/you_or_me_results_screen.dart` - Results screen patterns
- `app/lib/screens/affirmation_results_screen.dart` - Stats visualization
- `app/lib/widgets/daily_quests_widget.dart` - Card design system
- `app/lib/screens/quiz_intro_screen.dart` - Intro screen patterns

**Spec Document:**
- `docs/POWER_LEVEL_MEMORY_CHALLENGE_SPEC.md` - Feature requirements

---

**Version:** 1.0
**Created:** 2025-11-16
**Design System Source:** TogetherRemind Flutter App (app/lib/screens/)
