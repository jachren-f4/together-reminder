# Magnet Collection System

> **Status:** Planning
> **Created:** 2025-01-07
> **Replaces:** 5-tier arena system (Cozy Cabin → Castle Retreat)

## Overview

Couples collect travel destination "magnets" (like refrigerator magnets) by earning LP through activities. Each magnet unlocks a new quiz pack. The system is designed to:

1. Create a collectible/progression feel
2. Pace content consumption via 8-hour cooldowns
3. Force engagement across multiple activity types
4. Scale to hundreds of quizzes over time

---

## Core Mechanics

### LP Per Activity

| Activity | LP per play |
|----------|-------------|
| Classic Quiz | 30 |
| Affirmation Quiz | 30 |
| You or Me | 30 |
| Linked | 30 |
| Word Search | 30 |
| Steps (daily) | 30 |

### 8-Hour Batch Cooldown

All activities are gated by an 8-hour cooldown after completing a batch:

```
┌─────────────────────────────────────────────────────────────────┐
│  EVERY 8 HOURS, YOU CAN DO:                                     │
│                                                                  │
│  ├── 2 Classic quizzes        = 60 LP                           │
│  ├── 2 Affirmation quizzes    = 60 LP                           │
│  ├── 2 You-or-Me              = 60 LP                           │
│  ├── 2 Linked puzzles         = 60 LP                           │
│  ├── 2 Word Search puzzles    = 60 LP                           │
│  └── Batch total              = 300 LP                          │
│                                                                  │
│  + Steps (once per day)       = 30 LP                           │
│                                                                  │
│  After completing activities → 8-hour cooldown starts           │
│  After 8 hours → Next batch unlocks                             │
└─────────────────────────────────────────────────────────────────┘
```

**Maximum daily LP (super active):** ~630 LP (2 full batches + steps)

---

## LP Requirements Per Magnet

Progressive requirements that increase as couples advance:

| Magnets | LP Required | Count | Subtotal LP |
|---------|-------------|-------|-------------|
| 1-3 | 600 | 3 | 1,800 |
| 4-6 | 700 | 3 | 2,100 |
| 7-9 | 800 | 3 | 2,400 |
| 10-14 | 900 | 5 | 4,500 |
| 15-30 | 1,000 | 16 | 16,000 |
| **Total** | | **30** | **26,800 LP** |

---

## Timeline Estimates

### Per-Magnet Unlock Time

| Magnets | LP | Super Active | Normal | Casual |
|---------|-----|--------------|--------|--------|
| 1-3 | 600 | ~1 day | ~1.5 days | ~3 days |
| 4-6 | 700 | ~1.1 days | ~1.8 days | ~3.5 days |
| 7-9 | 800 | ~1.3 days | ~2 days | ~4 days |
| 10-14 | 900 | ~1.4 days | ~2.3 days | ~4.5 days |
| 15+ | 1,000 | ~1.6 days | ~2.5 days | ~5 days |

### Total Completion Time (All 30 Magnets)

| Player Type | Daily LP | Total Time |
|-------------|----------|------------|
| Super Active | ~630 LP | ~43 days (6 weeks) |
| Normal Active | ~400 LP | ~67 days (2+ months) |
| Casual | ~200 LP | ~134 days (4.5 months) |

---

## Magnet Destinations (30 Initial)

Organized from local/accessible to European destinations. Ultra-luxury destinations (Maldives, Tahiti, Bali, etc.) reserved for future expansion.

### Local (1-7)

| # | Destination | Emoji | Theme |
|---|-------------|-------|-------|
| 1 | Coffee Shop | ☕ | First date vibes |
| 2 | City Park | 🌳 | Picnic together |
| 3 | Rooftop Bar | 🌃 | City night |
| 4 | Beach Town | 🏖️ | Weekend getaway |
| 5 | Mountain Cabin | 🏕️ | Cozy escape |
| 6 | Vineyard | 🍷 | Wine country |
| 7 | Lake House | 🏡 | Peaceful retreat |

### US Cities (8-18)

| # | Destination | Emoji | Theme |
|---|-------------|-------|-------|
| 8 | Austin | 🎸 | Music & BBQ |
| 9 | Portland | 🌲 | Pacific Northwest |
| 10 | San Diego | 🌊 | Beach vibes |
| 11 | Denver | ⛷️ | Mountain adventure |
| 12 | Nashville | 🎵 | Country music |
| 13 | Chicago | 🌬️ | Windy city |
| 14 | Boston | 🦞 | Historic charm |
| 15 | Miami | 🌴 | Tropical heat |
| 16 | New Orleans | 🎺 | Jazz & beignets |
| 17 | San Francisco | 🌉 | Golden Gate |
| 18 | New York | 🗽 | Big city dreams |

### European Cities (19-30)

| # | Destination | Emoji | Theme |
|---|-------------|-------|-------|
| 19 | London | 🇬🇧 | British charm |
| 20 | Amsterdam | 🇳🇱 | Canals & culture |
| 21 | Berlin | 🇩🇪 | History & nightlife |
| 22 | Paris | 🗼 | City of love |
| 23 | Barcelona | 🇪🇸 | Mediterranean sun |
| 24 | Rome | 🇮🇹 | Ancient romance |
| 25 | Vienna | 🎻 | Classical elegance |
| 26 | Prague | 🏰 | Fairytale city |
| 27 | Lisbon | 🇵🇹 | Coastal beauty |
| 28 | Athens | 🏛️ | Ancient history |
| 29 | Santorini | 🇬🇷 | White & blue |
| 30 | Dubrovnik | 🇭🇷 | Adriatic gem |

### Future Expansion (Year 2+)

Reserved ultra-luxury and exotic destinations:
- Tokyo 🗼
- Bali 🌺
- Phuket 🏝️
- Safari Lodge (Kenya) 🦁
- Maldives 🐚
- Tahiti 🌊
- French Château 🏰
- Northern Lights (Iceland) 🌌
- Amalfi Coast 🇮🇹
- Machu Picchu 🏔️

---

## Quiz Packs Per Magnet

Each magnet unlocks a new quiz pack containing 18 quizzes:

| Quiz Type | Per Pack |
|-----------|----------|
| Classic Quiz | 6 |
| Affirmation Quiz | 6 |
| You or Me | 6 |
| **Total** | **18** |

### Content Requirements

| Magnets | Quiz Packs | Total Quizzes Needed |
|---------|------------|----------------------|
| 30 | 30 | 540 quizzes |
| 50 | 50 | 900 quizzes |
| 100 | 100 | 1,800 quizzes |

**Goal:** 1,000+ quizzes within first year of launch.

---

## Visual Design

### Magnet Assets

Each destination magnet is a **flat illustrated travel poster** image (PNG/JPG) with the destination name built into the artwork. No separate text labels needed.

**Style characteristics:**
- Flat/minimalist illustration style
- Warm, inviting color palette
- Destination name integrated into the design
- Square aspect ratio for grid display
- Works at small sizes (36px) and large sizes (180px)

**Asset location:** `app/assets/brands/us2/images/magnets/`

**Example assets created:** Austin, Miami, Chicago, Barcelona

**Remaining assets needed (26):**
- **Local:** Coffee Shop, City Park, Rooftop, Beach Town, Cabin, Vineyard, Lake House
- **US Cities:** Portland, San Diego, Denver, Nashville, Boston, New Orleans, San Francisco, New York
- **Europe:** London, Amsterdam, Berlin, Paris, Rome, Vienna, Prague, Lisbon, Athens, Santorini, Dubrovnik

---

## UI Components

### 1. Connection Bar (Home Screen)

The existing Connection Bar is updated to show magnet images instead of tier emojis. The bar appears at the top of the home screen.

#### Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  CONNECTION BAR                                    2,460/2,800   │
│                                                                  │
│  [Chicago]  ═══════════════💗✨═══════════════  [Barcelona]     │
│   (current)      gold progress bar                  (next)       │
└─────────────────────────────────────────────────────────────────┘
```

#### Design Specifications

| Element | Specification |
|---------|---------------|
| Background | Gradient: #FF6B6B → #FF9F43 (pink to orange) |
| Border radius | 20px top-left, 20px top-right, 0 bottom |
| Padding | 12px 16px 20px 16px |
| Header label | "CONNECTION BAR" - Nunito 13px bold, white, letter-spacing 1px |
| LP counter | "2,460/2,800" - Nunito 18px bold, white |
| Magnet images | 36x36px, border-radius 6px, 2px white border (50% opacity) |
| Track background | rgba(0,0,0,0.2), height 10px, border-radius 5px |
| Track fill | Gradient #FFE066 → #FFB347 (gold), with glow shadow |
| Heart indicator | 44x44px circle, gradient background, 3px white border, centered 💗 emoji |
| Sparkles | 3x ✨ emojis with staggered fade animation |

#### States

**Mid-Progress (has previous magnet):**
- Left magnet: Current/most recently unlocked destination (full opacity)
- Right magnet: Next destination to unlock (full opacity - NOT grayed out)
- Heart positioned along progress bar based on LP progress

**New User (no magnets yet):**
- NO left magnet displayed
- Track extends from left edge
- Heart positioned at far left (0% progress)
- Right magnet shows first destination (e.g., "Coffee Shop" or "Austin")
- LP counter shows "0/600"

#### Interaction

- Tap anywhere on Connection Bar → Navigate to Collection View

---

### 2. Collection View Screen

A dedicated screen showing all magnets in a grid layout.

#### Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  9:41                                                    100%   │
│                                                                  │
│  [←]  Our Collection                                    [4/30]  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ [Barcelona img]  Next Destination                        │    │
│  │                  Barcelona                               │    │
│  │                  520 / 800 LP                            │    │
│  │  ████████████████████░░░░░░░░░                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────┐  ┌────────┐  ┌────────┐                             │
│  │ Austin │  │ Miami  │  │Chicago │  ← Collected (full color)  │
│  │        │  │        │  │        │                             │
│  └────────┘  └────────┘  └────────┘                             │
│                                                                  │
│  ┌────────┐  ┌────────┐  ┌────────┐                             │
│  │Barcelona│  │  🔒   │  │  🔒   │  ← Current has gold border  │
│  │ (gold) │  │        │  │        │    Locked are grayed       │
│  └────────┘  └────────┘  └────────┘                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Design Specifications

**Header:**
| Element | Specification |
|---------|---------------|
| Back button | 40x40px circle, cream background, pink "←" icon |
| Title | "Our Collection" - Playfair Display 1.5rem bold italic |
| Counter badge | "4/30" - gradient pill (pink→orange), white text, 20px border-radius |

**Progress Section:**
| Element | Specification |
|---------|---------------|
| Background | Cream (#FFF8F0), 20px border-radius, 2px beige border |
| Next magnet preview | 56x56px, 10px border-radius, gold border |
| Label | "NEXT DESTINATION" - 0.7rem uppercase, letter-spacing 1.5px |
| Destination name | Playfair Display 1.2rem bold |
| LP text | "520 / 800 LP" - 0.85rem, pink color |
| Progress bar | 10px height, beige background, pink→orange gradient fill |

**Magnet Grid (Polaroid Style):**
| Element | Specification |
|---------|---------------|
| Grid | 3 columns, 12px gap |
| Card aspect ratio | 1:1 (square) |
| Card background | White |
| Card padding | 6px top/sides, 24px bottom (Polaroid effect) |
| Card border-radius | 4px |
| Card shadow | 0 4px 16px rgba(0,0,0,0.12) |
| Image border-radius | 2px |

**Magnet States:**

| State | Visual Treatment |
|-------|------------------|
| **Collected** | Full color image, white Polaroid frame |
| **Current (collecting)** | Gold border (3px, #C9A875), pulsing gold glow shadow |
| **Locked** | Grayscale image (40% opacity), dark overlay (30% black), 🔒 emoji centered, muted Polaroid frame (#e8e0d8) |

#### Interaction

- Tap collected magnet → Show magnet detail (future: quiz pack info)
- Tap current magnet → Show progress detail
- Tap locked magnet → No action (or show "X LP to unlock" tooltip)
- Scroll → Vertical scroll through all 30 magnets

---

### 3. Profile Section

A compact magnet preview appears on the Profile screen.

#### Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  My Collection                                      View All →  │
│                                                                  │
│  [img1] [img2] [img3] [img4] [🔒]  [🔒]   ← Always 6 badges    │
│                        (gold)                                   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ [Barcelona]  Collecting...                            → │    │
│  │              Barcelona                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

#### Design Specifications

| Element | Specification |
|---------|---------------|
| Container | Cream background, 20px border-radius, 2px beige border |
| Title | "My Collection" - Playfair Display 1rem italic |
| View All link | "View All →" - Nunito 0.8rem, pink color |
| Badge size | 48x48px, 8px border-radius |
| Badge gap | 8px |
| Current badge | Gold border (2px, #C9A875) |
| Locked badges | Grayscale, 40% opacity, dashed gold border |
| "Collecting" card | Gradient background (10% pink→orange), 14px border-radius |

#### Display Logic

**Always shows exactly 6 badges:**
- Display collected magnets first (in order)
- Current magnet (with gold border) next
- Fill remaining slots with locked/grayed badges

**Examples:**
- 4 collected + 1 current → Show 4 + 1 current + 1 locked
- 1 collected → Show 1 + 5 locked
- 10 collected + 1 current → Show most recent 5 + current (scrollable or show last 6)

#### Interaction

- Tap "View All →" → Navigate to Collection View
- Tap "Collecting... Barcelona →" card → Navigate to Collection View
- Tap any badge → Navigate to Collection View

---

### 4. Unlock Celebration Screen

Full-screen celebration when a new magnet is unlocked.

#### Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│              🎊 CONFETTI SHOWER FROM TOP 🎊                      │
│                    (falls in front of content)                   │
│                                                                  │
│              New Destination Unlocked!                           │
│                                                                  │
│                 ┌──────────────────┐                             │
│                 │                  │                             │
│                 │    [Barcelona    │  ← 180x180px, 8px radius   │
│                 │     magnet]      │                             │
│                 │                  │                             │
│                 └──────────────────┘                             │
│                                                                  │
│                  "Mediterranean Sun"                             │
│                                                                  │
│                         18                                       │
│                 NEW QUIZZES UNLOCKED                            │
│                                                                  │
│                 [Add to Collection]                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Design Specifications

**Screen:**
| Element | Specification |
|---------|---------------|
| Background | Gradient: #FFD1C1 → #FFF5F0 (peachy pink) |
| Padding | 40px top/bottom, 20px sides |

**Confetti Animation:**
| Element | Specification |
|---------|---------------|
| Type | Shower falling from top (NOT burst from center) |
| Count | 30 confetti pieces |
| Colors | #FF6B6B (pink), #FFE066 (gold), #FF9F43 (orange), #FFB347 (amber) |
| Shapes | Mix of circles (border-radius: 50%) and squares (border-radius: 2px) |
| Sizes | 7-15px varied |
| Animation | Falls from top (-20px) to bottom (+650px), rotating 720deg |
| Duration | 2.5 seconds, ease-out |
| Delays | Staggered 0-0.25s for natural feel |
| Z-index | 10 (in front of magnet and other content) |
| Trigger | Plays once on screen load |

**Content:**
| Element | Specification |
|---------|---------------|
| Title | "New Destination Unlocked!" - Playfair Display 1.3rem bold italic |
| Magnet image | 180x180px, **8px border-radius** (less rounded), 4px cream border |
| Magnet shadow | 0 12px 40px rgba(0,0,0,0.2) |
| Magnet animation | Scale 0→1.05→1 with slight rotation on load |
| Tagline | Destination theme in quotes - Playfair Display 1.1rem italic |
| Stat value | "18" - Playfair Display 1.8rem bold, pink |
| Stat label | "NEW QUIZZES UNLOCKED" - 0.75rem uppercase, letter-spacing 1px |
| Button | "Add to Collection" - cream/white gradient, pink text, 30px border-radius |

#### Interaction

- **"Add to Collection" tap** → Navigate to Collection View with newly unlocked magnet highlighted
- Screen auto-dismisses after button tap (no back navigation to celebration)

#### Flutter Implementation Notes

```dart
// Confetti can be implemented with:
// 1. confetti package (pub.dev/packages/confetti)
// 2. Custom painter with AnimationController
// 3. Stack of animated Container widgets

// Key points:
// - Trigger confetti on initState or after build
// - Use IgnorePointer for confetti container
// - Ensure confetti renders above magnet (Stack ordering or z-index)
```

---

## User Flow

### Complete Unlock Flow

```
Activity Completion
        │
        ▼
┌─────────────────┐
│ LP Awarded      │
│ Check if unlock │
└────────┬────────┘
         │
    LP >= threshold?
         │
    ┌────┴────┐
    │         │
   No        Yes
    │         │
    ▼         ▼
Return    ┌─────────────────┐
to Home   │ Unlock          │
          │ Celebration     │
          │ Screen          │
          └────────┬────────┘
                   │
                   ▼ (tap "Add to Collection")
          ┌─────────────────┐
          │ Collection View │
          │ (new magnet     │
          │  highlighted)   │
          └────────┬────────┘
                   │
                   ▼ (tap back or navigate away)
          ┌─────────────────┐
          │ Home Screen     │
          │ (Connection Bar │
          │  updated)       │
          └─────────────────┘
```

### Entry Points to Collection View

| Location | Trigger | Notes |
|----------|---------|-------|
| Connection Bar | Tap anywhere | Home screen top |
| Profile Section | Tap "View All →" | Profile screen |
| Profile Section | Tap any badge | Profile screen |
| Profile Section | Tap "Collecting..." card | Profile screen |
| Unlock Celebration | Tap "Add to Collection" | After unlock |

---

## Technical Implementation

### Database Schema

```sql
-- New table for magnet collection
CREATE TABLE couple_magnets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  couple_id UUID NOT NULL REFERENCES couples(id),
  magnet_id INTEGER NOT NULL,
  unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(couple_id, magnet_id)
);

-- Track cooldown state
CREATE TABLE couple_cooldowns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  couple_id UUID NOT NULL REFERENCES couples(id),
  activity_type TEXT NOT NULL, -- 'quiz_batch', 'linked_batch', 'wordsearch_batch'
  cooldown_until TIMESTAMP WITH TIME ZONE NOT NULL,
  UNIQUE(couple_id, activity_type)
);

-- Or simpler: JSONB on couples table
ALTER TABLE couples ADD COLUMN cooldowns JSONB DEFAULT '{}';
-- Example: {"quiz_batch": "2025-01-07T16:00:00Z", "linked_batch": "2025-01-07T18:00:00Z"}
```

### Magnet Configuration

```typescript
// api/lib/magnets/config.ts
export const MAGNETS = [
  { id: 1, name: 'Coffee Shop', emoji: '☕', region: 'local' },
  { id: 2, name: 'City Park', emoji: '🌳', region: 'local' },
  // ... etc
];

export function getLPRequirement(magnetId: number): number {
  if (magnetId <= 3) return 600;
  if (magnetId <= 6) return 700;
  if (magnetId <= 9) return 800;
  if (magnetId <= 14) return 900;
  return 1000;
}

export function getTotalLPForMagnet(magnetId: number): number {
  let total = 0;
  for (let i = 1; i <= magnetId; i++) {
    total += getLPRequirement(i);
  }
  return total;
}
```

### Cooldown Logic

```typescript
// api/lib/cooldowns/check.ts
export async function canPlayActivity(
  coupleId: string,
  activityType: 'quiz' | 'linked' | 'wordsearch'
): Promise<{ canPlay: boolean; cooldownEndsAt: Date | null; remainingInBatch: number }> {
  // Check cooldown
  // Return remaining plays in current batch (0-2)
  // Return cooldown end time if locked
}

export async function recordPlay(
  coupleId: string,
  activityType: 'quiz' | 'linked' | 'wordsearch'
): Promise<void> {
  // Increment batch counter
  // If batch complete (2 plays), set 8hr cooldown
}
```

---

## Migration Plan

### Phase 1: Backend
1. Add magnet config and LP requirement functions
2. Add cooldown tracking to database
3. Update activity endpoints to check/set cooldowns
4. Add magnet unlock endpoint

### Phase 2: Flutter
1. Replace tier display with magnet collection
2. Add cooldown indicators to activity cards
3. Create magnet unlock celebration
4. Add collection view screen

### Phase 3: Content
1. Organize existing quizzes into packs
2. Create additional quizzes to fill 30 packs (540 quizzes)
3. Associate quiz packs with magnets

---

## Open Questions

1. **Existing users:** How to migrate couples with existing LP to new system?
   - Option A: Convert LP to magnets (e.g., 1000 LP = magnets 1-2 unlocked)
   - Option B: Fresh start, existing LP carries over as bonus

2. **Partial batches:** If user does 1 of 2 allowed activities, when does cooldown start?
   - Option A: Cooldown starts after first activity (harsh)
   - Option B: Cooldown starts after batch complete OR 8hrs from first activity

3. **Steps integration:** Should steps also have batch limits, or remain daily?
   - Current thinking: Steps stay daily (natural gate from health data)

4. **UI for cooldowns:** How prominent should cooldown timers be?
   - Subtle countdown on locked activities
   - "Next batch in 3h 45m" message

---

## Related Documents

- `docs/features/LOVE_POINTS.md` - Current LP system (to be updated)
- `docs/plans/QUIZ_CONTENT_REWRITE.md` - Quiz content strategy
- `docs/plans/CONTENT_SCALING_STRATEGY.md` - Content scaling plans

---

## Mockups & Assets

### HTML Mockup

**Location:** `mockups/magnet-collection/collection-view.html`

Interactive mockup showing:
- Collection View screen (Polaroid grid)
- Connection Bar states (mid-progress + new user)
- Profile Section preview
- Unlock Celebration screen with confetti animation

Open in browser to see animations and interactions.

### Magnet Image Assets

**Location:** `mockups/magnet-collection/`

Current assets:
- `austin.jpg` - Austin, TX
- `miami.jpg` - Miami, FL
- `chicago.jpg` - Chicago, IL
- `barcelona.jpg` - Barcelona, Spain

Style: Flat illustrated travel posters with destination names built into artwork.

---

## Changelog

| Date | Change |
|------|--------|
| 2025-01-07 | Initial document created |
| 2025-01-07 | Added comprehensive UI/UX specifications |
| 2025-01-07 | Added mockup with Connection Bar, Collection View, Profile Section, Celebration Screen |
| 2025-01-07 | Finalized confetti animation (shower from top, in front of content) |
