# Us 2.0 Brand Guide

Comprehensive design system and implementation guide for the Us 2.0 brand variant.

---

## Table of Contents

1. [Brand Identity](#brand-identity)
2. [Colors](#colors)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Components](#components)
6. [Navigation](#navigation)
7. [Animations & Motion](#animations--motion)
8. [Implementation Guide](#implementation-guide)
9. [Implementation Status](#implementation-status)

---

## Brand Identity

### Philosophy

Us 2.0 is a warm, romantic, and playful couples app. The design evokes feelings of:

- **Warmth** - Coral/peach tones create an inviting, cozy atmosphere
- **Romance** - Pink gradients and heart motifs reinforce the couples focus
- **Playfulness** - Rounded shapes, emoji graphics, and subtle animations add delight
- **Elegance** - Serif typography (Playfair Display) adds sophistication

### Personality Keywords

`Warm` · `Romantic` · `Playful` · `Inviting` · `Modern` · `Elegant`

### Logo

The "Us 2.0" logo uses:
- **Font:** Pacifico (cursive script)
- **Color:** White with multi-layered glow shadow
- **Accent:** Small red heart positioned top-right

```dart
// Logo implementation
Us2Logo(onDoubleTap: openDebugMenu)
```

---

## Colors

### Primary Palette

| Name | Hex | Usage |
|------|-----|-------|
| **Primary Pink** | `#FF5E62` | Primary brand color, CTAs |
| **Gradient Start** | `#FF6B6B` | Gradient buttons, accents |
| **Gradient End** | `#FF9F43` | Gradient buttons, accents (orange) |
| **Card Salmon** | `#FF7B6B` | Quest card backgrounds |

### Background Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Background Light** | `#FFF5F0` | Screen backgrounds (gradient end) |
| **Background Peach** | `#FFD1C1` | Screen backgrounds (gradient start) |
| **Cream** | `#FFF8F0` | Card backgrounds, input fields |
| **Beige** | `#F5E6D8` | Section headers, dividers |

### Text Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Text Dark** | `#2D2D2D` | Primary text, headings |
| **Text Medium** | `#666666` | Secondary text, descriptions |
| **Text Light** | `#999999` | Tertiary text, hints, captions |

### Accent Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Gold** | `#C9A875` | LP badges, premium features |
| **Success** | `#4CAF50` | Success states, checkmarks |
| **Error** | `#FF5252` | Error states, warnings |

### Glow Effects

| Name | Color | Opacity | Usage |
|------|-------|---------|-------|
| **Glow Pink** | `#FF6B6B` | 50-80% | Button shadows, active states |
| **Glow Orange** | `#FF9F43` | 40-60% | Secondary glows |

### Gradients

```dart
// Background gradient (vertical, top to bottom)
Us2Theme.backgroundGradient
// Colors: [#FFD1C1, #FFF5F0]

// Accent gradient (horizontal or diagonal)
Us2Theme.accentGradient
// Colors: [#FF6B6B, #FF9F43]

// Progress bar fill
Us2Theme.progressGradient
// Colors: [#FF6B6B, #FF9F43]
```

### Usage Guidelines

| Context | Color Choice |
|---------|--------------|
| Screen background | `backgroundGradient` |
| Primary buttons | `accentGradient` with `glowPink` shadow |
| Secondary buttons | White/cream with pink border |
| Cards | White or `cream` background |
| Active nav items | `accentGradient` text/icon |
| Inactive nav items | `textLight` or muted version |
| LP/Points display | `gold` color |

---

## Typography

### Font Families

| Font | Package | Usage |
|------|---------|-------|
| **Pacifico** | Google Fonts | Logo only |
| **Playfair Display** | Google Fonts | Headings, titles |
| **Nunito** | Google Fonts | Body text, UI elements |

### Type Scale

| Style | Font | Size | Weight | Usage |
|-------|------|------|--------|-------|
| **Logo** | Pacifico | 52px | Regular | App logo |
| **H1** | Playfair Display | 32px | SemiBold (600) | Screen titles |
| **H2** | Playfair Display | 26px | SemiBold (600) | Section titles |
| **H3** | Playfair Display | 20px | SemiBold (600) | Card titles |
| **Body Large** | Nunito | 16px | Regular (400) | Primary body text |
| **Body** | Nunito | 14px | Regular (400) | Standard body text |
| **Body Small** | Nunito | 13px | Regular (400) | Secondary text |
| **Caption** | Nunito | 12px | Regular (400) | Hints, timestamps |
| **Button** | Nunito | 16px | Bold (700) | Button labels |
| **Nav Label** | Nunito | 13px | Bold (700) | Navigation labels |

### Text Styles

```dart
// Heading with gradient partner name
RichText(
  text: TextSpan(
    style: GoogleFonts.playfairDisplay(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: Us2Theme.textDark,
    ),
    children: [
      TextSpan(text: 'Poke '),
      TextSpan(
        text: partnerName,
        style: GoogleFonts.playfairDisplay(
          fontStyle: FontStyle.italic,
          foreground: Paint()
            ..shader = Us2Theme.accentGradient.createShader(...),
        ),
      ),
    ],
  ),
)
```

---

## Spacing & Layout

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Tight spacing, icon gaps |
| `sm` | 8px | Related elements |
| `md` | 12px | Standard gaps |
| `lg` | 16px | Section padding |
| `xl` | 20px | Screen margins |
| `xxl` | 24px | Large section gaps |
| `xxxl` | 32px | Major section dividers |

### Screen Layout

```
┌─────────────────────────────────────┐
│         SafeArea (top)              │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │     Content Area                ││
│  │     padding: 20px horizontal    ││
│  │                                 ││
│  │                                 ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│         Bottom Navigation           │
│         SafeArea (bottom)           │
└─────────────────────────────────────┘
```

### Border Radius

| Element | Radius |
|---------|--------|
| Buttons | 16px |
| Cards | 20-24px |
| Bottom sheets | 24px (top only) |
| Input fields | 12px |
| Emoji selector items | 14-16px |
| Nav bar (dock style) | 28px |
| Pill nav active item | 24px |

---

## Components

### Buttons

#### Primary Button (Glow Button)

Full-width gradient button with pink glow shadow.

```dart
Container(
  width: double.infinity,
  height: 56,
  decoration: BoxDecoration(
    gradient: Us2Theme.accentGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Us2Theme.glowPink,
        blurRadius: 25,
        offset: Offset(0, 8),
      ),
    ],
  ),
  child: Center(
    child: Text('Button Label', style: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    )),
  ),
)
```

**States:**
- **Normal:** Full gradient + glow
- **Disabled:** 40% opacity gradient, no glow
- **Loading:** Circular progress indicator (white)

#### Secondary Button

White/cream button with pink border.

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: Us2Theme.gradientAccentStart, width: 2),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Text('Label', style: TextStyle(
    color: Us2Theme.gradientAccentStart,
  )),
)
```

### Cards

#### Quest Card

Salmon gradient background with image header.

```dart
Us2QuestCard(
  quest: quest,
  onTap: () => navigateToQuest(quest),
)
```

**Structure:**
- Image section (top) - 180px height
- Content section (salmon gradient)
- Title (Playfair Display)
- Description (Nunito italic)
- Action button

#### Info Card

White card with subtle shadow for informational content.

```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.9),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 20,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: content,
)
```

### Input Fields

```dart
Container(
  decoration: BoxDecoration(
    color: Us2Theme.cream,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Us2Theme.beige, width: 2),
  ),
  child: TextField(
    style: GoogleFonts.nunito(fontSize: 16),
    decoration: InputDecoration(
      hintText: 'Placeholder',
      hintStyle: TextStyle(color: Us2Theme.textLight),
      border: InputBorder.none,
      contentPadding: EdgeInsets.all(16),
    ),
  ),
)
```

### Section Headers

Ribbon-style headers with Playfair Display italic text.

```dart
Us2SectionHeader(title: 'DAILY QUESTS')
```

### Connection Bar (LP Progress)

Gradient progress bar showing Love Points progress.

```dart
Us2ConnectionBar(
  currentLp: 120,
  nextTierLp: 150,
)
```

---

## Navigation

Us 2.0 includes three bottom navigation variants, switchable from the debug menu.

### Standard Navigation

Default style with gradient text on active items.

**File:** `us2_bottom_nav.dart`

```dart
Us2BottomNav(
  currentIndex: currentIndex,
  onTap: (index) => setIndex(index),
)
```

**Characteristics:**
- White background with shadow
- Active item: gradient-colored icon + label
- Inactive items: muted gray
- Poke item always has gradient coloring

### Dock Navigation (macOS Style)

Floating dock with glassmorphism and magnification effect.

**File:** `us2_bottom_nav_dock.dart`

```dart
Us2BottomNavDock(
  currentIndex: currentIndex,
  onTap: (index) => setIndex(index),
)
```

**Characteristics:**
- Floating bar with rounded corners (28px radius)
- Glassmorphism effect (backdrop blur)
- Active item scales up (36px → 48px)
- Active item lifts up (-6px translateY)
- Pink glow shadow on active item
- Small dot indicator below active icon
- Margin from screen edges (20px)

### Pill Navigation (Expand Style)

Active item expands into pill shape with animated label.

**File:** `us2_bottom_nav_pill.dart`

```dart
Us2BottomNavPill(
  currentIndex: currentIndex,
  onTap: (index) => setIndex(index),
)
```

**Characteristics:**
- White background with shadow
- Active item expands into pill shape
- Label appears with fade animation
- Pill has subtle pink background (12% opacity)
- Items spread evenly with `spaceAround`

### Nav Style Switching

Users can switch nav styles from the debug menu (Actions tab).

```dart
// Service for persisting nav style preference
NavStyleService.instance.setStyle(Us2NavStyle.dock);

// Reading current style
final style = NavStyleService.instance.currentStyle;
```

**Available styles:**
- `Us2NavStyle.standard` - Default
- `Us2NavStyle.dock` - macOS dock style
- `Us2NavStyle.pill` - Pill expand style

### Navigation Items

| Index | Screen | Icon Asset |
|-------|--------|------------|
| 0 | Home | `home_v1.png` |
| 1 | Inbox | `Inbox_v1.png` |
| 2 | Poke | `Poke_v2.png` |
| 3 | Profile (Us) | `profile_v2_transparent.png` |
| 4 | Settings | `Settings_v1.png` |

**Asset location:** `assets/brands/us2/nav/`

---

## Animations & Motion

### Duration Guidelines

| Animation Type | Duration | Curve |
|----------------|----------|-------|
| Micro-interactions | 150ms | `easeOut` |
| State changes | 200ms | `easeOutCubic` |
| Screen transitions | 300ms | `easeOutCubic` |
| Entrance animations | 400ms | `easeOutCubic` |
| Complex sequences | 500-800ms | Custom |

### Common Animations

#### Button Press

```dart
AnimatedContainer(
  duration: Duration(milliseconds: 150),
  transform: Matrix4.translationValues(0, isPressed ? 0 : -2, 0),
  // Shadow increases on hover/focus
)
```

#### Nav Item Magnification (Dock)

```dart
AnimatedContainer(
  duration: Duration(milliseconds: 180),
  curve: Curves.easeOutCubic,
  width: isActive ? 48 : 36,
  height: isActive ? 48 : 36,
  transform: Matrix4.translationValues(0, isActive ? -6 : 0, 0),
)
```

#### Pill Expand (Pill Nav)

```dart
AnimatedContainer(
  duration: Duration(milliseconds: 200),
  padding: EdgeInsets.symmetric(
    horizontal: isActive ? 14 : 10,
  ),
)

AnimatedSize(
  duration: Duration(milliseconds: 200),
  child: isActive ? Label() : SizedBox.shrink(),
)
```

#### Fade + Slide Entrance

```dart
SlideTransition(
  position: Tween<Offset>(
    begin: Offset(0, 0.3),
    end: Offset.zero,
  ).animate(controller),
  child: FadeTransition(
    opacity: controller,
    child: content,
  ),
)
```

### Glow Pulse (Connection Bar Heart)

```dart
// 3 sparkles with staggered delays: 0ms, 500ms, 1000ms
AnimationController(duration: Duration(milliseconds: 1500))..repeat();

Transform.scale(
  scale: Tween(begin: 0.8, end: 1.2).animate(curved),
  child: Opacity(
    opacity: Tween(begin: 0.3, end: 1.0).animate(curved),
    child: sparkle,
  ),
)
```

---

## Implementation Guide

### Brand Detection Pattern

```dart
bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

@override
Widget build(BuildContext context) {
  if (_isUs2) return _buildUs2Content();
  return _buildLiiaContent();
}
```

### Using Us2Theme

```dart
import 'package:togetherremind/config/brand/us2_theme.dart';

// Colors
Us2Theme.gradientAccentStart  // #FF6B6B
Us2Theme.gradientAccentEnd    // #FF9F43
Us2Theme.textDark             // #2D2D2D
Us2Theme.cream                // #FFF8F0

// Gradients
Us2Theme.backgroundGradient
Us2Theme.accentGradient

// Glow colors
Us2Theme.glowPink
Us2Theme.glowOrange
```

### Using Google Fonts

```dart
import 'package:google_fonts/google_fonts.dart';

// Headings
GoogleFonts.playfairDisplay(
  fontSize: 28,
  fontWeight: FontWeight.w600,
  color: Us2Theme.textDark,
)

// Body text
GoogleFonts.nunito(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: Us2Theme.textMedium,
)

// Logo (rarely used directly)
GoogleFonts.pacifico(fontSize: 52)
```

### Reusable Components

```dart
// Home screen content
Us2HomeContent(
  userName: 'Name',
  partnerName: 'Partner',
  dayNumber: 15,
  currentLp: 120,
  nextTierLp: 150,
  dailyQuests: quests,
  sideQuests: sideQuests,
  onQuestTap: (quest) => navigate(quest),
  onDebugTap: () => openDebugMenu(),
)

// Intro screens (Quiz, You or Me, Linked, Word Search)
Us2IntroScreen(
  title: 'Quiz Time',
  description: 'Answer questions about your relationship',
  emoji: '💕',
  onStart: () => startGame(),
)

// Quest cards
Us2QuestCard(quest: quest, onTap: onTap)

// Section headers
Us2SectionHeader(title: 'DAILY QUESTS')

// Connection bar
Us2ConnectionBar(currentLp: lp, nextTierLp: nextTier)

// Logo with debug tap
Us2Logo(onDoubleTap: openDebugMenu)
```

---

## Implementation Status

### Screens

| Category | Total | Done | Remaining |
|----------|:-----:|:----:|:---------:|
| Auth & Onboarding | 5 | 5 | 0 |
| Main Navigation | 6 | 5 | 1 |
| Welcome Quiz | 4 | 4 | 0 |
| Classic & Affirmation Quiz | 5 | 5 | 0 |
| You or Me | 4 | 4 | 0 |
| Linked | 3 | 3 | 0 |
| Word Search | 3 | 3 | 0 |
| Steps Together | 3 | 3 | 0 |
| Daily Pulse | 2 | 0 | 2 |
| Other Screens | 3 | 3 | 0 |
| **Total Screens** | **38** | **35** | **3** |

### Overlays & Dialogs

| Category | Total | Done | Remaining |
|----------|:-----:|:----:|:---------:|
| Bottom Sheets | 3 | 3 | 0 |
| Full-Screen Overlays | 3 | 2 | 1 |
| Dialogs | 4 | 4 | 0 |
| Inline Overlays | 2 | 1 | 1 |
| **Total Overlays** | **12** | **10** | **2** |

### Remaining Work

**Screens:**
- [ ] Activity Hub (`activity_hub_screen.dart`)
- [ ] Daily Pulse Question (`daily_pulse_screen.dart`)
- [ ] Daily Pulse Results (`daily_pulse_results_screen.dart`)

**Overlays:**
- [ ] Poke Animation (`poke_animation_service.dart`)
- [ ] Flash Overlay (`flash_overlay_widget.dart`)

### Overall Progress

- **Screens:** 35/38 (92%)
- **Overlays:** 10/12 (83%)
- **Combined:** 45/50 (90%)

---

## File Reference

### Core Theme Files

| File | Purpose |
|------|---------|
| `config/brand/us2_theme.dart` | Colors, gradients, typography constants |
| `config/brand/brand_loader.dart` | Brand detection and loading |
| `config/brand/brand_registry.dart` | Brand configurations |

### Component Files

| File | Purpose |
|------|---------|
| `widgets/brand/us2/us2_home_content.dart` | Home screen layout |
| `widgets/brand/us2/us2_intro_screen.dart` | Intro screen template |
| `widgets/brand/us2/us2_quest_card.dart` | Quest card |
| `widgets/brand/us2/us2_connection_bar.dart` | LP progress bar |
| `widgets/brand/us2/us2_logo.dart` | Logo with glow |
| `widgets/brand/us2/us2_section_header.dart` | Ribbon headers |
| `widgets/brand/us2/us2_glow_button.dart` | Gradient button |
| `widgets/brand/us2/us2_bottom_nav.dart` | Standard nav |
| `widgets/brand/us2/us2_bottom_nav_dock.dart` | Dock-style nav |
| `widgets/brand/us2/us2_bottom_nav_pill.dart` | Pill-expand nav |

### Service Files

| File | Purpose |
|------|---------|
| `services/nav_style_service.dart` | Nav style preference persistence |

### Asset Directories

| Path | Contents |
|------|----------|
| `assets/brands/us2/nav/` | Navigation icons (PNG) |
| `assets/brands/us2/images/` | Character images, misc |

---

*Last updated: 2025-12-28*
*Current build: 1.0.0+29*
