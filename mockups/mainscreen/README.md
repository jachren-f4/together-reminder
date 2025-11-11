# TogetherRemind Main Screen Mockups

This directory contains 8 different layout variants for the main screen, rebalancing games and activities alongside pokes and reminders.

## Variants Overview

### Variant 1: Game First (`variant1_game_first.html`)
**Concept:** Quick actions at top, then prioritized game cards
- Two prominent action buttons (Poke & Reminder) at the top
- Games displayed as horizontal cards with status badges
- Recent activity section below
- **Best for:** Equal emphasis on quick actions and gameplay

### Variant 2: Hero Game Card (`variant2_hero_game.html`)
**Concept:** Featured game takes center stage
- Large hero card for Daily Pulse with dark gradient background
- Other games in 2x2 mini grid
- Quick actions as list items below
- **Best for:** Highlighting the most important daily activity

### Variant 3: Balanced Grid (`variant3_balanced_grid.html`)
**Concept:** Everything in a uniform grid layout
- 2-column grid with equal-sized cards
- Daily Pulse featured (full width, dark background)
- Games, pokes, reminders, inbox all at same visual hierarchy
- Stats bar at bottom showing Love Points, days together, streak
- **Best for:** Democratic layout, no favorites

### Variant 4: Feed Style (`variant4_feed_style.html`)
**Concept:** Social media feed approach
- Vertical feed of activity cards
- Each card has emoji, title, description, and action button
- Highlighted cards (Daily Pulse) with thicker border
- Floating action buttons (Poke & Reminder) in bottom right
- **Best for:** Feeling of constant activity and engagement

### Variant 5: Dashboard (`variant5_dashboard.html`)
**Concept:** Stats-focused dashboard with profile header
- Couple avatars and greeting at top
- Stats grid (Love Points, Streak, Quiz Match %)
- Horizontal scrolling games carousel
- Quick action buttons side-by-side
- Recent activity timeline
- **Best for:** Power users who want to see stats at a glance

### Variant 6: Minimal Cards (`variant6_minimal_cards.html`)
**Concept:** Clean, spacious, centered design
- Large generous padding and whitespace
- Daily Pulse as primary card with button
- Secondary game cards without buttons
- 2x2 grid of quick actions at bottom (Poke, Reminder, Quiz, Inbox)
- **Best for:** Zen, uncluttered experience

### Variant 7: Carousel Focus (`variant7_carousel.html`)
**Concept:** Swipeable carousel of featured activities
- Horizontal scrolling carousel with large game cards
- Daily Pulse featured (dark background)
- Pagination dots showing position
- 4-column quick actions grid below
- **Best for:** Mobile-first, swipe-heavy interaction pattern

### Variant 8: Split View (`variant8_split_view.html`)
**Concept:** Dark hero section + light content section
- Top half: Dark background with featured Daily Pulse
- Bottom half: Light background with game list and actions
- Visual split creates clear hierarchy
- Games as list items with right arrows
- 2x2 quick actions grid
- **Best for:** Strong visual separation between priority and secondary content

---

## Game-Focused Variants (9-12)

These variants emphasize gamification while maintaining the app's elegant black & white aesthetic.

### Variant 9: Game Hub (`variant9_game_hub.html`)
**Concept:** RPG-style level progression and mission system
- Level bar with XP progress at top (dark header)
- Connection Level display with Love Points badge
- "Daily Missions" section with active mission indicator (pulsing dot)
- Mission cards show rewards, progress bars, and completion status
- "Quick Play" grid for secondary actions
- **Best for:** Users motivated by progression systems and daily goals

### Variant 10: Achievement Focused (`variant10_achievement_focused.html`)
**Concept:** Achievement hunter/trophy collector aesthetic
- "Love Fortress" header with achievement badges (streak, level)
- 3-column score grid (Love Points, Match Rate, Completed)
- "Active Challenges" with featured challenge card (dark background)
- Challenge cards show LP rewards, completion bars, and rarity indicators
- New badge indicator (!) on urgent challenges
- **Best for:** Competitive couples who love collecting achievements

### Variant 11: Quest Board (`variant11_quest_board.html`)
**Concept:** Fantasy tavern quest board
- Castle emoji (🏰) header with "Quest Board" title
- 4-column player stats bar (LP, Level, Streak, Completed)
- Quest cards with rarity badges (Daily, Active, Legendary)
- Large quest icons with borders, progress chains, and accept buttons
- "Main Quests" (games) vs "Side Quests" (quick actions) separation
- **Best for:** Fantasy RPG fans, creates sense of adventure

### Variant 12: Arcade Style (`variant12_arcade_style.html`)
**Concept:** Retro arcade cabinet selection screen
- Dark background (#1A1A1A) with monospace scoreboard
- "Insert Coin" blinking text, retro game aesthetic
- Score display in arcade-style digits (00127)
- Game "slots" with screen borders, difficulty bars (pips), and play buttons
- Pressed button effect on play buttons (shadow shift)
- Quick actions as arcade cabinet buttons at bottom
- **Best for:** Nostalgic, playful aesthetic; makes activities feel like arcade games

## Design System Used

All variants use the TogetherRemind design system:
- **Colors:**
  - Primary Black: `#1A1A1A`
  - Primary White: `#FFFEFD`
  - Background Gray: `#FAFAFA`
  - Border Light: `#F0F0F0`
  - Text Secondary: `#6E6E6E`
  - Text Tertiary: `#AAAAAA`
- **Typography:**
  - Headlines: Playfair Display (serif, 600 weight)
  - Body: Inter (sans-serif, 400-600 weight)
- **Borders:** 2px solid borders with `#F0F0F0`
- **Border Radius:** 12-20px for cards and buttons
- **No gradients** except for dark-to-dark on black elements

## How to View

Open any HTML file in a web browser. The mockups are self-contained with embedded CSS and web fonts.

## Recommendations

**For balanced game/reminder experience:** Variant 1, 3, or 5
**For game-first experience:** Variant 2, 7, or 8
**For minimal aesthetic:** Variant 6
**For engagement-focused:** Variant 4
**For gamification/progression focus:** Variant 9, 10, 11, or 12

### Detailed Recommendations by Use Case:

- **If you want RPG progression feel:** Variant 9 (Game Hub) or Variant 11 (Quest Board)
- **If you want achievement hunting:** Variant 10 (Achievement Focused)
- **If you want playful/nostalgic:** Variant 12 (Arcade Style)
- **If you want maximum game emphasis but stay elegant:** Variant 2 (Hero Game Card) or Variant 7 (Carousel)
- **If you want social feed engagement:** Variant 4 (Feed Style)
- **If you want zen simplicity:** Variant 6 (Minimal Cards)

---

## Hybrid Variants (13-16)

These variants combine elements from Variant 5 (Dashboard with stats header) and Variant 11 (Quest categorization), creating an elegant non-game header with quest-based content organization.

### Variant 13: Hybrid Elegant (`variant13_hybrid_elegant.html`)
**Concept:** Clean combination of dashboard stats + quest carousel
- Variant 5-style header: Couple avatars, greeting, 3-column stats (LP, Streak, Match)
- Prominent Poke & Remind buttons below stats
- Horizontal scrolling "Main Quests" carousel (games/activities)
- 2-column "Side Quests" grid for secondary actions
- **Best for:** Balance between elegant stats display and quest organization

### Variant 14: Hybrid Compact (`variant14_hybrid_compact.html`)
**Concept:** Space-efficient version with condensed stats
- White header section with all info condensed
- Smaller avatars, compact 3-column stats with light gray backgrounds
- Action buttons in header section
- Horizontal "Main Quests" carousel
- 3-column "Side Quests" grid (more compact)
- **Best for:** Maximizing content visibility, information density

### Variant 15: Hybrid Vertical (`variant15_hybrid_vertical.html`)
**Concept:** Generous spacing with large emoji cards
- Standard dashboard header (Variant 5 style)
- Poke & Remind buttons prominent
- Large quest cards (56px emoji) in horizontal scroll
- Spacious padding and margins throughout
- 2-column side quests with ample breathing room
- **Best for:** Premium, luxurious feel with generous whitespace

### Variant 16: Hybrid Refined (`variant16_hybrid_refined.html`)
**Concept:** Polished premium version
- White header with light gray stat cards (vs white)
- Elegant 18px border radius on main quest cards (vs 16px)
- 64px emojis on main quest cards (largest of all variants)
- 2x2 side quest grid (4 items instead of 2)
- Playfair Display used for quest names (not just headers)
- **Best for:** Most refined, premium aesthetic

## User Feedback Notes

✅ **Liked from Variant 5:**
- Header showing Love Points, Streak, and Quiz Match scores (not game-like)
- Poke and Remind buttons positioned high up
- Horizontal carousel for active games

✅ **Liked from Variant 11:**
- "Main Quests" vs "Side Quests" terminology and organization
- All activities categorized as quests (games, quizzes, etc.)

❌ **Did not like:**
- Castle emoji (🏰) and "Quest Board" naming
- Preferred arena concept from vacation-arenas.html (Beach Villa, Yacht Getaway, etc.)

**Arena Integration Opportunity:**
Consider showing current arena tier in header (e.g., "Beach Villa" or yacht icon) to indicate progression through vacation destinations as LP increases.

---

## Arena Variants (17-20)

These variants are based on Variant 14 (Hybrid Compact) with vacation arena visualization integrated. Each shows the current arena (Beach Villa 🏖️) and progress toward the next destination (Yacht Getaway ⛵).

### Variant 17: Arena Subtle (`variant17_arena_subtle.html`)
**Concept:** Minimal arena indicator at top
- Compact gradient badge showing current arena (Beach Villa)
- Progress text: "1,280 / 2,500 LP • Next: Yacht Getaway ⛵"
- Beach villa gradient colors (sky blue to gold)
- Standard Variant 14 layout below
- **Best for:** Subtle arena presence without dominating the header

### Variant 18: Arena Banner (`variant18_arena_banner.html`)
**Concept:** Full-width arena header with gradient background
- Large beach villa gradient banner at top
- Palm tree decoration (opacity 0.3)
- Progress bar showing LP toward next arena
- Playfair Display 24px arena name
- Compact profile/stats/actions in white section below
- **Best for:** Maximum arena emphasis, immersive vacation theme

### Variant 19: Arena Integrated (`variant19_arena_integrated.html`)
**Concept:** Arena as fourth stat
- Arena badge pill next to greeting ("🏖️ Beach Villa")
- Fourth stat box with gradient background showing next arena
- "⛵ Next Arena • 1,220 LP" in gradient stat card
- Beach villa colors integrated into stats grid
- **Best for:** Arena treated as equal to other stats (LP, Streak, Match)

### Variant 20: Arena Minimal (`variant20_arena_minimal.html`)
**Concept:** Arena tag + separate progress bar
- Small arena tag in user metadata line ("🏖️ Beach Villa")
- Separate full-width gradient progress section between header and content
- Progress bar showing 51.2% completion
- Clean separation: white header → gradient progress → white content
- **Best for:** Clean separation, arena progress given dedicated space

## Arena Gradient Colors (from vacation-arenas.html)

Each arena has distinct gradient colors:
- **Cozy Cabin** 🏕️: Brown to orange `#8B4513` → `#D2691E`
- **Beach Villa** 🏖️: Sky blue to gold `#87CEEB` → `#FFD700`
- **Yacht Getaway** ⛵: Navy to light blue `#1E3A8A` → `#60A5FA`
- **Mountain Penthouse** 🏔️: Gray to light gray `#6B7280` → `#E5E7EB`
- **Castle Retreat** 🏰: Purple to light purple `#7C3AED` → `#C084FC`

## Next Steps

1. Review all variants (especially arena variants 17-20)
2. Select favorite approach(es) for arena visualization
3. Discuss which activities should be prioritized
4. Consider combining elements from multiple variants
5. Decide on arena tier thresholds and rewards
6. Implement in Flutter with proper state management
