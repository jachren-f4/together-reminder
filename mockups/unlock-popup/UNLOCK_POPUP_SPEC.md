# Unlock Popup Specification

This document defines the exact specifications for implementing the unlock popup in Flutter. The coding agent MUST follow these specifications exactly.

## Implementation Status: COMPLETE ✅

**Flutter Widget:** `lib/widgets/unlock_popup.dart`
**Debug Testing:** Debug Menu → "Unlock" tab
**Implemented:** 2025-01-20

---

## Overview

The unlock popup is shown when a user unlocks a new feature/game. It displays:
- Feature image with rounded corners
- "UNLOCKED" badge + category badge
- Feature title
- Description text
- Two stats (LP reward + Mode)
- "Great!" button

---

## Layout Structure

```
┌─────────────────────────────────────┐
│         IMAGE SECTION (240px)       │
│  ┌─────────────────────────────┐    │
│  │    Pulsing Glow Ring        │    │
│  │  ┌─────────────────────┐    │    │
│  │  │   Feature Image     │    │    │
│  │  │   (180x180, r=24)   │    │    │
│  │  └─────────────────────┘    │    │
│  └─────────────────────────────┘    │
│         Gradient fade to white      │
├─────────────────────────────────────┤
│           CONTENT SECTION           │
│                                     │
│     [UNLOCKED]  [CATEGORY]          │
│                                     │
│         Feature Title               │
│                                     │
│      Description text here          │
│                                     │
│      +30          Quiz              │
│   LP Per Game     Mode              │
│                                     │
│    ┌─────────────────────────┐      │
│    │        Great!           │      │
│    └─────────────────────────┘      │
└─────────────────────────────────────┘
```

---

## Dimensions

| Element | Value |
|---------|-------|
| Popup width | 340px |
| Popup border radius | 28px |
| Image section height | 240px |
| Feature image size | 180x180px |
| Feature image border radius | 24px |
| Glow ring size | 200x200px |
| Content padding | 20px top, 24px horizontal, 28px bottom |
| Content margin-top | -20px (overlaps image section) |

---

## Colors

### Backgrounds
| Element | Color |
|---------|-------|
| Overlay behind popup | `rgba(0, 0, 0, 0.6)` / 60% black |
| Popup background | `#FFFFFF` white |
| Image section gradient | `#FFE8E4` → `#FFDDD6` → `#FFD0C5` (top to bottom) |
| Feature image background | `#FFFFFF` white |

### Badges
| Badge | Background | Text Color |
|-------|------------|------------|
| UNLOCKED | Gradient `#FF6B6B` → `#FF9F43` | `#FFFFFF` white |
| Category (QUIZ/PUZZLE/FITNESS) | `#F5F5F5` | `#888888` |

### Text
| Element | Color |
|---------|-------|
| Title | `#2D2D2D` |
| Description | `#777777` |
| Stat value | `#FF6B6B` |
| Stat label | `#999999` |

### Button
| Property | Value |
|----------|-------|
| Background | Gradient `#FF6B6B` → `#FF9F43` (135deg) |
| Text color | `#FFFFFF` white |
| Shadow | `0 10px 30px rgba(255, 107, 107, 0.4)` |

---

## Typography

### Fonts
- **Title font**: Playfair Display (serif)
- **Body font**: Nunito (sans-serif)

### Text Styles
| Element | Font | Size | Weight | Other |
|---------|------|------|--------|-------|
| Badge text | Nunito | 10px | 700 | letter-spacing: 1px |
| Title | Playfair Display | 32px | 700 | - |
| Description | Nunito | 15px | 400 | line-height: 1.6 |
| Stat value | Playfair Display | 20px | 700 | - |
| Stat label | Nunito | 11px | 400 | uppercase, letter-spacing: 0.5px |
| Button text | Nunito | 17px | 700 | - |

---

## Spacing

| Element | Margin/Padding |
|---------|----------------|
| Badge row margin-bottom | 16px |
| Badge padding | 6px 12px |
| Badge border-radius | 20px |
| Badge gap | 8px |
| Title margin-bottom | 12px |
| Description margin-bottom | 24px |
| Stats row gap | 24px |
| Stats row margin-bottom | 24px |
| Button padding | 18px vertical |
| Button border-radius | 16px |

---

## Animations

### Glow Ring Pulse
```css
@keyframes pulse {
    0%, 100% { transform: scale(1); opacity: 0.8; }
    50% { transform: scale(1.1); opacity: 0.4; }
}
```
- Duration: 2 seconds
- Timing: ease-in-out
- Iteration: infinite
- Glow color: `rgba(255, 159, 67, 0.3)` radial gradient

---

## Feature-Specific Content

### Classic Quiz
| Property | Value |
|----------|-------|
| Image | `classic-quiz.png` |
| Category badge | QUIZ |
| Title | Classic Quiz |
| Description | Test how well you know each other with fun multiple-choice questions! |
| LP stat | +30 LP Per Game |
| Mode stat | Quiz Mode |

### Affirmation Quiz
| Property | Value |
|----------|-------|
| Image | `affirmation.png` |
| Category badge | QUIZ |
| Title | Affirmation Quiz |
| Description | Share loving affirmations and discover what makes your partner feel appreciated! |
| LP stat | +30 LP Per Game |
| Mode stat | Quiz Mode |

### You or Me
| Property | Value |
|----------|-------|
| Image | `you-or-me.png` |
| Category badge | QUIZ |
| Title | You or Me |
| Description | Who's more likely to...? Answer fun questions about each other and see if you agree! |
| LP stat | +30 LP Per Game |
| Mode stat | Quiz Mode |

### Crossword (Linked)
| Property | Value |
|----------|-------|
| Image | `linked.png` |
| Category badge | PUZZLE |
| Title | Crossword |
| Description | Solve romantic crossword puzzles together! Take turns filling in the answers. |
| LP stat | +30 LP Per Game |
| Mode stat | Puzzle Mode |

### Word Search
| Property | Value |
|----------|-------|
| Image | `word-search.png` |
| Category badge | PUZZLE |
| Title | Word Search |
| Description | Find hidden words together in a fun puzzle! Take turns discovering words as a team. |
| LP stat | +30 LP Per Game |
| Mode stat | Puzzle Mode |

### Steps Together
| Property | Value |
|----------|-------|
| Image | `steps-together.png` |
| Category badge | FITNESS |
| Title | Steps Together |
| Description | Track your daily steps and reach goals together! Stay active and earn LP as a couple. |
| LP stat | +30 LP Per Day |
| Mode stat | Sync Mode |

---

## Shadow Specifications

| Element | Shadow |
|---------|--------|
| Popup | `0 25px 80px rgba(0, 0, 0, 0.3)` |
| Feature image | `drop-shadow(0 15px 40px rgba(255, 107, 107, 0.35))` |
| Button | `0 10px 30px rgba(255, 107, 107, 0.4)` |

---

## Gradient Specifications

| Element | Gradient |
|---------|----------|
| Image section | `linear-gradient(180deg, #FFE8E4 0%, #FFDDD6 50%, #FFD0C5 100%)` |
| Image fade to white | `linear-gradient(180deg, transparent 0%, white 100%)` - height: 80px |
| UNLOCKED badge | `linear-gradient(135deg, #FF6B6B 0%, #FF9F43 100%)` |
| Button | `linear-gradient(135deg, #FF6B6B 0%, #FF9F43 100%)` |
| Glow ring | `radial-gradient(circle, rgba(255, 159, 67, 0.3) 0%, transparent 70%)` |

---

## Implementation Notes

1. **Image handling**: Use `BoxFit.cover` with white background to ensure rounded corners are visible
2. **Font loading**: Ensure Playfair Display and Nunito are loaded (Google Fonts or asset)
3. **Overlay**: Use a semi-transparent barrier behind the popup
4. **Animation**: Implement the glow ring pulse animation using Flutter's animation system
5. **Dismiss**: Popup dismisses when "Great!" button is tapped
6. **Safe area**: Popup should be centered and not affected by safe area insets
