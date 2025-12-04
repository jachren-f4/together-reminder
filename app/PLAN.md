# Profile Page: Activity Stats & Relationship Timer

**STATUS: IMPLEMENTED**

## Overview

Add two new sections to the profile page based on the provided mockup images:

1. **"Together For" Section** - Shows relationship duration (Years / Months / Days)
2. **"Your Activity" Section** - Shows individual stats for each partner (Activities completed, Current streak days, Couple games won)

**Design Decisions (confirmed with user):**
- Use existing app theme colors (black/white), NOT the purple from mockups
- No share buttons for now
- Anniversary date is editable with modal workflow

---

## Section 1: "Together For" Timer

### States

**State A: No Anniversary Set**
- Card shows "Set up your anniversary date" prompt
- Tapping opens a bottom sheet modal to select date
- Simple, inviting call-to-action

**State B: Anniversary Set**
- Card shows calculated duration: Years | Months | Days
- Pencil icon in header to edit
- Tapping pencil opens bottom sheet with:
  - "Edit your anniversary" option
  - "Delete your anniversary" option
- Delete resets to State A

### Design (using app theme)
- Card background: `AppTheme.primaryBlack`
- Text: `AppTheme.primaryWhite`
- Stat boxes: Slightly lighter/darker variant
- Border: `AppTheme.borderLight` or subtle rounded corners

### Data Requirements

**New data needed:**
- `anniversary_date` - The date the couple's relationship started (user-entered)

**Storage:**
- Supabase: Add `anniversary_date DATE` column to `couples` table
- Hive: Cache in `app_metadata` box under key `anniversary_date`

**API:**
- `GET /api/sync/couple-preferences` - Add `anniversaryDate` to response
- `POST /api/sync/couple-preferences` - Accept `anniversaryDate` parameter
- `DELETE anniversaryDate` - Set to null via POST with `anniversaryDate: null`

### UI Components
- `_buildTogetherForSection()` - Main card widget
- `_showSetAnniversaryModal()` - Bottom sheet for initial setup
- `_showEditAnniversaryModal()` - Bottom sheet with Edit/Delete options
- Date picker (Flutter's built-in or custom)

### Duration Calculation
```dart
int years = 0, months = 0, days = 0;
// Calculate exact years, months, days from anniversaryDate to now
// Use package like `age_calculator` or manual calculation
```

---

## Section 2: "Your Activity" Stats

### Design (using app theme)
- Card background: `AppTheme.primaryBlack`
- "Your Activity" title in white
- Three columns: Activities completed | Current streak days | Couple games won
- Two rows (one per partner) with avatar initials and colored pill values
- User 1 pill: Light color (e.g., `AppTheme.primaryWhite` with opacity)
- User 2 pill: Accent color (e.g., `AppTheme.accentOrange` or similar)

### Layout
```
+------------------------------------------+
|  Your Activity                           |
|                                          |
|       [✓]            [🔥]        [🏆]    |
|   Activities      Current     Couple     |
|   completed    streak days  games won    |
|                                          |
|  [J]   [ 31 ]        [ - ]      [ 2 ]   |
|  [T]   [ 13 ]        [ - ]      [ 1 ]   |
+------------------------------------------+
```

### Data Requirements

**Activities Completed (per user):**
- Count of all completed quests/games by each user
- Source: `quest_completions` table, count per `user_id`

**Current Streak Days (per user):**
- Per-user activity streak
- Source: Calculate from `quest_completions` by date
- "-" if no streak data available

**Couple Games Won (per user):**
- Count of games where user scored higher than partner
- Source: Calculate from session tables where scores are comparable
- Games: quiz_sessions (matching answers), you_or_me (harder to define "win")
- For MVP: Count games where user had more "correct" answers than partner

### API Endpoint

Create new endpoint: `GET /api/sync/couple-stats`

Response:
```json
{
  "anniversaryDate": "2024-02-03",
  "user1": {
    "id": "uuid",
    "name": "Joakim",
    "initial": "J",
    "activitiesCompleted": 31,
    "currentStreakDays": 5,
    "coupleGamesWon": 2
  },
  "user2": {
    "id": "uuid",
    "name": "Taija",
    "initial": "T",
    "activitiesCompleted": 13,
    "currentStreakDays": 3,
    "coupleGamesWon": 1
  }
}
```

---

## Implementation Steps

### Step 1: Database Migration
- Add `anniversary_date` column to `couples` table in Supabase
- File: `api/supabase/migrations/026_couple_anniversary.sql`

```sql
ALTER TABLE couples ADD COLUMN anniversary_date DATE;
```

### Step 2: Update couple-preferences API
- Add `anniversaryDate` to GET response
- Accept `anniversaryDate` in POST body (including null to delete)
- File: `api/app/api/sync/couple-preferences/route.ts`

### Step 3: Create couple-stats API
- Create `GET /api/sync/couple-stats` endpoint
- Queries:
  - `couples.anniversary_date`
  - `quest_completions` COUNT per user
  - Calculate streak from completion dates
  - Calculate games won from session tables
- File: `api/app/api/sync/couple-stats/route.ts`

### Step 4: Flutter Service
- Create `CoupleStatsService` to fetch and cache stats
- Methods:
  - `fetchStats()` - Get all stats from API
  - `setAnniversaryDate(DateTime?)` - Set or clear anniversary
  - `getAnniversaryDate()` - Get cached anniversary
- File: `lib/services/couple_stats_service.dart`

### Step 5: Profile Screen UI
- Add `_buildTogetherForSection()` widget
  - Handle both "not set" and "set" states
- Add `_buildYourActivitySection()` widget
- Add modal bottom sheets for anniversary management
- File: `lib/screens/profile_screen.dart`

### Step 6: Anniversary Modal Screens
- `_showSetAnniversaryModal()` - Date picker for initial setup
- `_showEditAnniversaryModal()` - Options: Edit / Delete
- Use `showModalBottomSheet` with custom content
- File: Same as profile_screen.dart (or extract to separate widget)

---

## Visual Design Details (App Theme)

### Card Style
- Background: `AppTheme.primaryBlack`
- Border radius: 16px
- Padding: 20px
- Border: Optional 2px `AppTheme.borderLight`

### Stat Boxes (inner boxes for numbers)
- Background: Slightly different shade (e.g., `Color(0xFF1A1A1A)`)
- Border radius: 12px
- Padding: 12px vertical

### Typography
- Section title: `AppTheme.headlineFont`, 24px, white
- Stat labels: `AppTheme.bodyFont`, 14px, white with 70% opacity
- Stat values: `AppTheme.headlineFont`, 32px, white, bold

### User Pills
- User 1 (current user): Light background (white/cream)
- User 2 (partner): Accent color (peach/salmon like mockup or theme accent)
- Border radius: 20px (pill shape)
- Text: Dark for readability

### Icons (for Activity section headers)
- Activities: Checkmark in speech bubble (or simple checkmark)
- Streak: Flame icon (🔥 or Material Icons.local_fire_department)
- Games won: Trophy icon (🏆 or Material Icons.emoji_events)

---

## Files to Create/Modify

### New Files
1. `api/supabase/migrations/026_couple_anniversary.sql`
2. `api/app/api/sync/couple-stats/route.ts`
3. `lib/services/couple_stats_service.dart`

### Modified Files
1. `api/app/api/sync/couple-preferences/route.ts` - Add anniversary support
2. `lib/screens/profile_screen.dart` - Add new sections

---

## Order of Implementation

1. Database migration (anniversary_date column)
2. Update couple-preferences API (anniversary CRUD)
3. Create couple-stats API endpoint
4. Flutter CoupleStatsService
5. Profile screen "Together For" section (both states)
6. Profile screen "Your Activity" section
7. Anniversary modal bottom sheets
8. Testing & polish
