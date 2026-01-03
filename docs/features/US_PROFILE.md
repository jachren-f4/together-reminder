# Us Profile

## Overview

The Us Profile is a relationship insights dashboard that aggregates data from completed quizzes and games to help couples understand each other better. It provides therapeutic value through:
- **Dimensions** - Where partners fall on key relationship spectrums
- **Discoveries** - Insights about differences and commonalities
- **Values Alignment** - Shared values with agreement percentages
- **Partner Perception** - How each partner sees the other
- **Growth Edge** - Perception gaps that reveal hidden strengths
- **Conversation Starters** - Guided discussion prompts

The profile is accessed via a dedicated entry card on the Profile screen, creating an intentional "reflection moment" rather than casual browsing.

---

## Quick Reference

| Item | Location |
|------|----------|
| Us Profile Screen | `lib/screens/us_profile_screen.dart` |
| Us Profile Service | `lib/services/us_profile_service.dart` |
| Profile Entry Card | `lib/screens/profile_screen.dart` (line ~180) |
| API Endpoint | `api/app/api/us-profile/route.ts` |
| Design Reference | `mockups/us-profile-therapeutic/profile-month1-complete.html` |
| Therapeutic Plan | `docs/plans/US_PROFILE_THERAPEUTIC_ENHANCEMENTS.md` |

---

## User Flow

```
Profile Screen
      │
      ▼ (tap "Us Profile" entry card)
      │
┌─────┴─────────────────────────────────────┐
│  Slide-up transition (350ms)               │
│  with fade effect                          │
└─────┬─────────────────────────────────────┘
      │
      ▼
Us Profile Screen
      │
      ├── Header (avatars, names, journey day, stat pills)
      ├── Dimensions Section (spectrums with repair scripts)
      ├── Discoveries Section (filterable by category)
      ├── Values Section (alignment percentages)
      ├── Partner Perception (trait tags + Growth Edge)
      ├── Conversation Starters (with timing badges)
      ├── Actions Section (insights acted on, conversations)
      └── Growth Milestones (timeline)
```

---

## Data Model

### UsProfile
```dart
class UsProfile {
  final ProfileHeader header;
  final List<Dimension> dimensions;
  final List<FramedDiscovery> discoveries;
  final List<SharedValue> values;
  final PartnerPerception? userPerception;    // How user is seen by partner
  final PartnerPerception? partnerPerception; // How partner is seen by user
  final List<ConversationStarter> conversationStarters;
  final List<GrowthMilestone> milestones;
  final List<GrowthEdge> growthEdges;         // Perception gaps
}
```

### Key Sub-Models

| Model | Purpose |
|-------|---------|
| `ProfileHeader` | Couple names, journey day count, total quizzes/discoveries |
| `Dimension` | Spectrum position (0-100) for both partners, label, description |
| `FramedDiscovery` | Insight with stakes level, category, timing badge, action suggestion |
| `SharedValue` | Value name, alignment percentage, question count |
| `PartnerPerception` | List of trait tags one partner sees in the other |
| `ConversationStarter` | Prompt text, timing type, avoid scenarios |
| `GrowthMilestone` | Title, description, completion date, status |
| `GrowthEdge` | Self-view vs partner-view comparison with curiosity prompt |

### UsProfileQuickStats
Used by the entry card for teaser display:
```dart
class UsProfileQuickStats {
  final int discoveryCount;
  final int dimensionCount;
  final int? valueAlignmentPercent;
  final bool hasData;
  final bool hasNewContent;  // True if content changed since last view
}
```

---

## API Endpoint

### GET /api/us-profile

Returns the full profile data for a couple.

**Response:**
```json
{
  "header": {
    "userName": "Emma",
    "partnerName": "James",
    "journeyDays": 30,
    "totalQuizzes": 30,
    "totalDiscoveries": 18
  },
  "dimensions": [...],
  "discoveries": [...],
  "values": [...],
  "userPerception": { "traits": ["Adventurous", "Caring"] },
  "partnerPerception": { "traits": ["Thoughtful", "Steady"] },
  "conversationStarters": [...],
  "milestones": [...],
  "growthEdges": [...]
}
```

---

## UI Sections

### 1. Header
- Couple avatars with gradient border
- Names and journey day count ("Day 30 of your journey")
- Stat pills: quizzes, discoveries, conversations

### 2. Dimensions Section
Each dimension shows:
- Title and info button (expandable description)
- Spectrum track with partner position dots (Emma = pink, James = blue)
- Position labels (e.g., "Internal" ← → "External")
- **Repair Scripts** (expandable) for dimensions marked "different":
  - Recognition prompt
  - Partner-specific repair scripts
  - De-escalation tip

### 3. Discoveries Section
- Filter tabs: All, Lifestyle, Values, Future
- Discovery cards with:
  - Stakes badge (High = red styling)
  - Category and timing badges
  - Partner quotes showing their answers
  - "Try This" action suggestion
  - **High-stakes guidance** for sensitive topics
  - **Professional help prompt** (for high-stakes discoveries)

### 4. Values Section
- Shared values with circular progress indicators
- Alignment percentage and question count
- Info modal explaining how alignment is calculated

### 5. Partner Perception Section
- "Through [Partner]'s Eyes" showing trait tags
- **Growth Edge** subsection (if available):
  - Side-by-side comparison: "YOU SAID" vs "[PARTNER] SEES"
  - Curiosity-inducing framing (not critical)
  - "Try asking" prompt

### 6. Conversation Starters
- Prompt cards with timing badges:
  - 🌙 Relaxed moment
  - 🚶 While active
  - 🍽️ Over food
  - ⚡ Quick check-in
  - 📅 Dedicated time
- "Avoid" scenarios when applicable

### 7. Actions Section
- Grid showing engagement metrics:
  - Insights Acted On
  - Conversations Started
- **Note:** Currently display-only; action tracking not yet implemented

### 8. Growth Milestones
- Timeline of relationship milestones
- Completed items with dates
- Pending items as goals

---

## Therapeutic Enhancements

The Us Profile implements 6 therapeutic recommendations (see `docs/plans/US_PROFILE_THERAPEUTIC_ENHANCEMENTS.md`):

| Enhancement | Purpose |
|-------------|---------|
| Repair Scripts | Help when dimension differences cause friction |
| High-Stakes Tagging | Special treatment for sensitive topics (finances, family, intimacy) |
| Timing Guidance | When/where to have difficult conversations |
| Growth Edge | Reveal perception gaps without criticism |
| Professional Help Prompts | Gentle nudge toward counseling when appropriate |
| Staged Access | Entry card creates intentional reflection moment |

---

## State Management

### New Content Detection
The service tracks whether content has changed since the user's last visit:

```dart
// Storage keys
_usProfileLastViewedAtKey     // DateTime of last view
_usProfileLastViewedHashKey   // Hash of profile content

// Methods
markProfileViewed()           // Called when profile loads
hasNewContentSinceLastView()  // Compares current hash to stored hash
```

### Entry Card Badge
The "New" badge appears on the Us Profile entry card when:
- New discovery since last view
- Dimension position changed
- New milestone achieved
- New conversation starter generated

---

## Design System

Colors (from `us2_theme.dart` and screen constants):

| Element | Color |
|---------|-------|
| Emma's color | #FF6B6B (pink) |
| James's color | #4A8BC9 (blue) |
| High-stakes badge | #E53935 (red) |
| Accent green | #3D8B40 |
| Accent purple | #7C4DFF |
| Growth Edge bg | #F0F7FF (light blue) |
| Professional help bg | #F5FFF5 (light green) |

Typography:
- Section titles: Playfair Display, 15-16px
- Body text: Nunito, 12-13px
- Minimum readable: 11px

---

## Edge Cases & Gotchas

### 1. Empty State
When a couple has no quiz data, show encouraging message instead of empty sections.

### 2. Locked Dimensions
Some dimensions unlock progressively. Show lock icon and progress for dimensions not yet available.

### 3. Growth Edge Framing
**Critical:** Growth Edge must be framed as curiosity-inducing, never critical. Example:
- ✅ "Your partner notices something you might not..."
- ❌ "Your partner thinks you're wrong about yourself"

### 4. Professional Help Prompts
Must be:
- Non-alarming and non-pathologizing
- Framed as "optimization" not "fixing problems"
- Optional and dismissible
- Only shown on high-stakes discoveries

### 5. Content Hash
The profile content hash for new-content detection includes: dimensions positions, discovery count, values, and milestones. It does NOT include conversation starters (regenerated frequently).

---

## Future Improvements

### Discovery Action Tracking
**Status:** UI removed, backend not implemented

The original design included "I tried it!" and "Save for later" buttons on discoveries:
- **"I tried it!"** - Mark that the user had the suggested conversation
- **"Save for later"** - Bookmark discoveries to revisit

**Implementation would require:**
- `POST /api/us-profile/discovery/{id}/action` endpoint
- `discovery_actions` table in database
- Filter tab for "Acted On" discoveries
- Updated API response with action status per discovery

### Stuck Pattern Detection
Detect when couples repeatedly have friction on the same dimension and proactively surface repair scripts or suggest professional help.

### User Flagging
Allow users to manually flag a discovery as "we're stuck on this" to trigger additional support/resources.

### Couples Coaching Integration
Partner with actual therapy/coaching services for in-app referrals from professional help prompts.

### Journal Integration
Connect discoveries to the Journal feature, allowing couples to document their conversations and track progress over time.

---

## Related Documentation

- [Therapeutic Enhancements Plan](../plans/US_PROFILE_THERAPEUTIC_ENHANCEMENTS.md)
- [Long-Term Value Requirements](../plans/LONG_TERM_VALUE_REQUIREMENTS.md)
- [Quiz Match System](./QUIZ_MATCH.md)
- [You or Me Game](./YOU_OR_ME.md)

---

*Last Updated: January 3, 2026*
