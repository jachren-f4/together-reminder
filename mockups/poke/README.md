# Poke & Reminder UI Variants

**Purpose:** Exploring different design approaches for integrating Poke and Reminder functionality into the new carousel-based home screen.

**Context:** The carousel migration (CAROUSEL_MIGRATION_SPEC.md) removed the old action buttons from the header. These mockups explore where and how to bring them back.

---

## Variants Overview

### 01 - Bottom Action Grid (Current Implementation)
**File:** `01-bottom-action-grid.html`

```
┌─────────────────────────────┐
│   [Daily Quests Carousel]   │
│   [Side Quests Carousel]    │
├─────────────────────────────┤
│ [💌 Remind] [👆 Poke]       │
│ [📥 Inbox]  [🎮 Activities] │
└─────────────────────────────┘
```

**Pros:**
- ✅ Clear separation from content
- ✅ Equal visual weight for all actions
- ✅ Familiar pattern (matches original mockup)
- ✅ Easy to discover

**Cons:**
- ⚠️ Takes vertical space
- ⚠️ Requires scrolling to access
- ⚠️ Four actions may be too many

**Best for:** Desktop/tablet interfaces where vertical space is plentiful

---

### 02 - Floating Action Button (FAB)
**File:** `02-floating-action-button.html`

```
┌─────────────────────────────┐
│   [Daily Quests Carousel]   │
│   [Side Quests Carousel]    │
│                              │
│                     ┌────┐   │
│                     │ ✨ │◄──── FAB (hover to expand)
│                     └────┘   │
└─────────────────────────────┘
```

**Pros:**
- ✅ Always visible (no scrolling)
- ✅ Saves vertical space
- ✅ Modern mobile pattern
- ✅ Premium feel

**Cons:**
- ⚠️ Hover/tap required to see options
- ⚠️ Can obscure content
- ⚠️ Unfamiliar pattern for some users
- ⚠️ Mobile implementation requires tap-to-expand

**Best for:** Mobile-first designs where vertical space is limited

**Flutter Implementation Notes:**
- Use `FloatingActionButton` with `SpeedDial` package
- Position: `floatingActionButtonLocation: FloatingActionButtonLocation.endFloat`
- Consider accessibility: add semantic labels

---

### 03 - Header Quick Actions
**File:** `03-header-quick-actions.html`

```
┌─────────────────────────────┐
│      LOVE QUEST             │
│      Day Forty-Two          │
│                             │
│   [💌] [👆] [📥] [🎮]       │◄──── Icon buttons
├─────────────────────────────┤
│   [Stats & Progress Bar]    │
│   [Daily Quests Carousel]   │
└─────────────────────────────┘
```

**Pros:**
- ✅ Always visible at top
- ✅ Clean, minimal design
- ✅ No scrolling needed
- ✅ Doesn't compete with quest cards

**Cons:**
- ⚠️ Icons only (discoverability concern)
- ⚠️ Requires tooltips for clarity
- ⚠️ May clutter header
- ⚠️ Small tap targets on mobile (need 44×44 minimum)

**Best for:** Power users who know what the icons mean

**Flutter Implementation Notes:**
- Use `IconButton` widgets with `Tooltip`
- Ensure 44×44 minimum tap target size
- Add semantic labels for screen readers

---

### 04 - Inline Side Quest Cards
**File:** `04-inline-side-quests.html`

```
┌─────────────────────────────┐
│   [Daily Quests Carousel]   │
│                             │
│ Side Quests & Actions       │
│ ┌─────┐ ┌─────┐ ┌─────┐    │
│ │Quest│ │👆   │ │💌   │◄───── Action cards
│ │     │ │Poke │ │Remind│    │   (dark bg)
│ └─────┘ └─────┘ └─────┘    │
└─────────────────────────────┘
```

**Pros:**
- ✅ Natural discovery through scrolling
- ✅ Consistent interaction pattern (tap cards)
- ✅ Premium feel with dark card design
- ✅ Clear visual differentiation

**Cons:**
- ⚠️ Mixes actions with quests (cognitive load)
- ⚠️ Less prominent than dedicated section
- ⚠️ May be overlooked during quick scroll
- ⚠️ Carousel complexity (mixed types)

**Best for:** Designs emphasizing visual consistency and exploration

**Flutter Implementation Notes:**
- Extend `QuestCarousel` to support mixed content
- Use sealed class pattern: `sealed class CarouselItem`
- Style action cards distinctly (dark background)

---

### 05 - Minimal Bottom Bar
**File:** `05-minimal-bottom-bar.html`

```
┌─────────────────────────────┐
│   [Daily Quests Carousel]   │
│   [Side Quests Carousel]    │
├─────────────────────────────┤
│ [💌 Remind] [👆 Poke] [📥]  │◄──── Thin bar
└─────────────────────────────┘
```

**Pros:**
- ✅ Clean, streamlined design
- ✅ Focus on core actions (no clutter)
- ✅ Low visual noise
- ✅ Could be sticky (fixed position)

**Cons:**
- ⚠️ Requires scrolling to reach (unless sticky)
- ⚠️ Three actions only (removed Activities)
- ⚠️ May be too subtle

**Best for:** Minimalist designs focusing on essential actions

**Flutter Implementation Notes:**
- Use `Container` with `Row` for buttons
- Consider `SafeArea` for bottom notch/home indicator
- Optional: Make sticky with `Positioned` in `Stack`

---

## Comparison Matrix

| Variant | Visibility | Space Efficiency | Discoverability | Mobile-Friendly | Implementation Complexity |
|---------|-----------|------------------|-----------------|-----------------|--------------------------|
| 01 - Bottom Grid | Medium | Low | High | Good | Low |
| 02 - FAB | High | High | Medium | Excellent | Medium |
| 03 - Header Icons | High | High | Low | Medium | Low |
| 04 - Inline Cards | Medium | Medium | Medium | Excellent | High |
| 05 - Minimal Bar | Medium | High | Medium | Good | Low |

---

## Recommendations

### For Mobile-First Design (Recommended: Variant 02 or 05)
- **Primary:** **Variant 02 (FAB)** - Always accessible, modern pattern
- **Alternative:** **Variant 05 (Minimal Bar)** - Clean, sticky bar at bottom

### For Desktop/Web Focus (Recommended: Variant 01 or 03)
- **Primary:** **Variant 01 (Bottom Grid)** - Clear, discoverable
- **Alternative:** **Variant 03 (Header Icons)** - Clean header, always visible

### For Gamified Experience (Recommended: Variant 04)
- **Primary:** **Variant 04 (Inline Cards)** - Consistent with quest card pattern

### Hybrid Approach (Best of Both Worlds)
**Recommendation:** Combine Variant 03 (Header) + Variant 05 (Bottom Bar)
- **Header:** Small icon buttons for quick access (Poke, Remind)
- **Bottom:** Full section for Inbox and Activities
- **Benefit:** Frequent actions always visible, secondary actions below content

---

## Current App Context

**Existing Bottom Navigation:**
The app already has a bottom tab bar in `home_screen.dart`:
- Home
- Inbox
- Activities

**Implication:**
- Variants 01 and 05 would sit ABOVE the bottom nav bar
- Variant 02 (FAB) would float over the bottom nav bar
- Consider moving Inbox/Activities to bottom bar, leaving Poke/Remind in content

---

## Next Steps

1. **User Testing:** Show mockups to target users, gather feedback
2. **Prototype:** Build selected variant(s) in Flutter
3. **A/B Test:** Deploy multiple variants, measure engagement
4. **Iterate:** Refine based on data

---

**Created:** 2025-11-17
**Based on:** CAROUSEL_MIGRATION_SPEC.md
**Status:** Ready for review
