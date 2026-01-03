# Discovery Relevance System Specification

## Overview

Replace the time-based "Recent Discoveries" with a relevance-scored "Worth Discussing" section that surfaces therapeutically valuable discoveries regardless of when they occurred.

**Goal:** Facilitate meaningful conversations, not just show new content.

---

## Current State

- Section titled "Recent Discoveries"
- Shows 5 most recent discoveries (from newest quizzes)
- No prioritization by importance or engagement
- Sporadic users see stale content; active users may miss important older discoveries

---

## Proposed State

- Section titled "Worth Discussing"
- Shows 1 Featured Discovery + 4 Other Discoveries
- Prioritized by relevance score combining stakes, likes, patterns, and recency
- Simple "Like" interaction to show appreciation (no task-like "tried" tracking)
- Social dynamic: see what your partner found meaningful
- Adapts to any usage pattern (daily, sporadic, returning)

---

## The "Like" Model

### Why "Like" Instead of "Tried"

| "Tried" (task-based) | "Like" (appreciation-based) |
|----------------------|----------------------------|
| "I completed this conversation" | "This resonated with me" |
| Implies work is done | Implies it's meaningful |
| Feels like homework | Feels like engagement |
| Unlikely to be used | Natural, familiar interaction |
| No social component | Creates sharing between partners |

### How Likes Work

**For the liker:**
- Tap heart → marks "I found this meaningful"
- Discovery becomes less prominent for them (they've engaged)
- Can unlike to reverse

**For their partner:**
- Sees badge: "Emma found this meaningful"
- Discovery becomes MORE prominent (partner cares about this)
- Social nudge without pressure

**Mutual likes:**
- Both partners liked → shown with special styling
- Lower priority for both (mutual acknowledgment complete)
- Could surface in a "Discoveries you both loved" section

---

## Relevance Scoring Algorithm

### Scoring Formula

```
relevanceScore = stakesPoints + likePoints + patternPoints + recencyPoints
```

### Scoring Breakdown

#### Stakes Points (0-50)

| Stakes Level | Points | Example Topics |
|--------------|--------|----------------|
| High | 50 | Finances, children, intimacy, career, where to live, in-laws |
| Medium | 25 | Daily routines, social preferences, household, communication |
| Light | 10 | Food, hobbies, entertainment, travel preferences |

**Category mapping:**

```
HIGH_STAKES_CATEGORIES = [
  'finances', 'financial_philosophy',
  'family_planning', 'children',
  'intimacy', 'physical_affection',
  'career', 'career_priorities',
  'living_location', 'relocation',
  'in_laws', 'extended_family',
  'religion', 'spirituality',
  'life_goals', 'future_direction'
]

MEDIUM_STAKES_CATEGORIES = [
  'communication', 'conflict',
  'daily_routines', 'household',
  'social', 'friendships',
  'work_life_balance', 'stress',
  'emotional_support', 'trust'
]

LIGHT_STAKES_CATEGORIES = [
  'food', 'dining',
  'hobbies', 'leisure',
  'entertainment', 'media',
  'travel', 'vacations',
  'aesthetics', 'preferences'
]
```

#### Like Points (-15 to +30)

| Scenario | Points for User | Rationale |
|----------|-----------------|-----------|
| Neither liked | +0 | Neutral baseline |
| I liked it | -15 | I've engaged, show me other things |
| Partner liked it | +30 | Partner found this meaningful, I should see it |
| Both liked it | -10 | Mutual acknowledgment, can deprioritize |

This creates a discovery "passing" dynamic between partners.

#### Pattern Points (0-25)

| Condition | Points | Rationale |
|-----------|--------|-----------|
| Links to dimension with partner difference > 0.5 | +25 | Part of significant theme |
| 3+ discoveries in same category | +15 | Recurring topic area |
| Neither | +0 | Standalone discovery |

#### Recency Points (0-15)

| Age | Points | Rationale |
|-----|--------|-----------|
| 0-3 days | +15 | Very fresh |
| 4-7 days | +10 | Recent |
| 8-14 days | +5 | Moderate |
| 15+ days | +0 | No penalty, just no boost |

---

## Database Changes

### New Table: `discovery_likes`

```sql
CREATE TABLE discovery_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  discovery_id TEXT NOT NULL,  -- Format: "{quizMatchId}_{questionId}"
  user_id UUID NOT NULL REFERENCES auth.users(id),
  liked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(couple_id, discovery_id, user_id)
);

CREATE INDEX idx_discovery_likes_couple ON discovery_likes(couple_id);
CREATE INDEX idx_discovery_likes_discovery ON discovery_likes(couple_id, discovery_id);
```

### Quiz Question Metadata Update

Add `stakesLevel` to question definitions:

```json
{
  "id": "quiz_005_q3",
  "text": "How do you feel about having children?",
  "choices": ["Definitely want kids", "Open to it", "Unsure", "Don't want kids"],
  "category": "family_planning",
  "stakesLevel": "high"
}
```

For existing questions without explicit `stakesLevel`, derive from category using the mapping above.

---

## API Changes

### Modified: GET /api/us-profile

Response structure for discoveries:

```json
{
  "discoveries": {
    "featured": {
      "id": "match_123_q3",
      "questionText": "How do you feel about having children?",
      "user1Answer": "Definitely want kids soon",
      "user2Answer": "Still figuring it out",
      "category": "family_planning",
      "stakesLevel": "high",
      "relevanceScore": 95,
      "createdAt": "2026-01-01T10:00:00Z",
      "likes": {
        "user1Liked": false,
        "user2Liked": true,
        "partnerLikedLabel": "Emma found this meaningful"
      },
      "conversationGuide": {
        "acknowledgment": "This is a significant topic. There's no quick answer, and that's okay.",
        "steps": [
          "Find a relaxed time (not during stress)",
          "Start with curiosity: \"I'd love to understand your perspective\"",
          "Share your feelings without pressure to decide",
          "It's okay to revisit this multiple times"
        ],
        "professionalPrompt": "Some couples find it helpful to explore big life questions with a counselor."
      },
      "timingBadge": { "type": "dedicated", "label": "Set aside 20-30 minutes" }
    },
    "others": [
      {
        "id": "match_119_q2",
        "questionText": "When money is tight, I prefer to...",
        "user1Answer": "Cut back on everything",
        "user2Answer": "Prioritize what matters, cut the rest",
        "category": "finances",
        "stakesLevel": "high",
        "relevanceScore": 75,
        "createdAt": "2025-12-28T14:00:00Z",
        "likes": {
          "user1Liked": true,
          "user2Liked": true,
          "mutualLike": true
        },
        "tryThisAction": "Have a 15-minute conversation about financial priorities this week",
        "timingBadge": { "type": "relaxed", "label": "Best for a quiet evening" }
      }
      // ... 3 more
    ],
    "totalCount": 47,
    "contextLabel": "Worth Discussing"
  }
}
```

### New: POST /api/us-profile/discovery/{id}/like

Toggle like on a discovery:

```json
// Request (empty body - toggles current state)
POST /api/us-profile/discovery/match_123_q3/like

// Response
{
  "success": true,
  "liked": true,
  "discovery": {
    "id": "match_123_q3",
    "likes": {
      "user1Liked": true,
      "user2Liked": false,
      "partnerLikedLabel": null
    }
  }
}
```

---

## Backend Implementation

### New File: `api/lib/us-profile/relevance.ts`

```
Functions:
- calculateRelevanceScore(discovery, dimensions, likesMap, userId) → number
- rankDiscoveries(discoveries, dimensions, likesMap, userId) → RankedDiscovery[]
- selectFeaturedAndOthers(rankedDiscoveries) → { featured, others }
- getStakesLevel(category, explicitLevel?) → 'high' | 'medium' | 'light'
- getPatternBonus(discovery, dimensions) → number
- getRecencyBonus(createdAt) → number
- getLikeBonus(likes, userId) → number
```

### Modified: `api/lib/us-profile/framing.ts`

Replace:
```typescript
const discoveries = frameDiscoveries(coupleInsights.discoveries).slice(-10).reverse();
```

With:
```typescript
const likesMap = await getDiscoveryLikes(coupleId);
const rankedDiscoveries = rankDiscoveries(
  coupleInsights.discoveries,
  framedDimensions,
  likesMap,
  userId
);
const { featured, others } = selectFeaturedAndOthers(rankedDiscoveries);
```

### Category Selection for "Others"

When selecting the 4 "other" discoveries:
1. Take highest scored discovery
2. For remaining 3, prefer different categories than already selected
3. If all top discoveries are same category, still show them (indicates pattern)

---

## Flutter Implementation

### Modified: `UsProfileScreen`

**Section rename:** "Recent Discoveries" → "Worth Discussing"

**Layout:**

```
┌─────────────────────────────────────────┐
│  Worth Discussing                       │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │  🔶 THIS WEEK'S FOCUS               ││
│  │                                     ││
│  │  "How do you feel about children?"  ││
│  │                                     ││
│  │  Emma: "Definitely want kids soon"  ││
│  │  James: "Still figuring it out"     ││
│  │                                     ││
│  │  💬 Emma found this meaningful      ││
│  │                                     ││
│  │  This is a significant topic...     ││
│  │                                     ││
│  │  ♡ Like                             ││
│  └─────────────────────────────────────┘│
│                                         │
│  Other Insights                         │
│  ┌──────────────────────────────────┐  │
│  │ "When money is tight..."         │  │
│  │ Emma: Cut back  James: Prioritize│  │
│  │ ♥ You both liked this            │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │ "Ideal weekend morning..."       │  │
│  │ Emma: Spontaneous  James: Routine│  │
│  │ ♡ Like                           │  │
│  └──────────────────────────────────┘  │
│  (... 2 more cards)                    │
│                                         │
│  See all 47 discoveries →               │
└─────────────────────────────────────────┘
```

### Like Button States

| State | Icon | Label | Color |
|-------|------|-------|-------|
| Not liked | ♡ (outline) | "Like" | Gray |
| I liked | ♥ (filled) | "Liked" | Pink/Red |
| Partner liked | ♡ (outline) | "Like" + badge above | Gray + badge |
| Both liked | ♥ (filled) | "You both liked this" | Pink with glow |

### Partner Like Badge

When partner has liked a discovery the user hasn't:

```
┌─────────────────────────────────────┐
│  💬 Emma found this meaningful      │  ← Subtle badge
│                                     │
│  "How do you handle stress?"        │
│  ...                                │
│                                     │
│  ♡ Like                             │
└─────────────────────────────────────┘
```

### Like Interaction

```dart
void _onLikeTapped(String discoveryId) async {
  HapticFeedback.lightImpact();

  // Optimistic update
  setState(() {
    _toggleLocalLike(discoveryId);
  });

  // API call
  try {
    await _profileService.toggleDiscoveryLike(discoveryId);
  } catch (e) {
    // Revert on error
    setState(() {
      _toggleLocalLike(discoveryId);
    });
  }
}
```

### Modified: `UsProfileService`

Add method:
```dart
Future<bool> toggleDiscoveryLike(String discoveryId);
```

---

## Contextual Header Labels

Adapt the featured section header based on context:

| Context | Header | Rationale |
|---------|--------|-----------|
| Partner liked a high-stakes discovery | "Emma Found This Meaningful" | Direct social prompt |
| Has unliked high-stakes discovery | "Worth Discussing" | Neutral importance |
| Returning after 2+ weeks | "Pick Up Where You Left Off" | Acknowledge break |
| All discoveries mutually liked | "You're In Sync!" | Celebrate alignment |
| Very few discoveries total | "Your First Insights" | Encourage new users |

---

## Migration Plan

### Phase 1: Backend
1. Add `discovery_likes` table
2. Add `stakesLevel` to quiz question metadata (derive from category for existing)
3. Implement relevance scoring in `relevance.ts`
4. Update `/api/us-profile` to return scored discoveries with like state
5. Add `/api/us-profile/discovery/{id}/like` endpoint

### Phase 2: Flutter UI
1. Update `UsProfileScreen` section layout
2. Add featured discovery card component with like button
3. Add compact discovery card list with like buttons
4. Add partner like badges
5. Add "See all discoveries" navigation

### Phase 3: Polish
1. Add contextual headers based on like state
2. Add mutual like celebration styling
3. Add empty state for couples with few discoveries
4. Test with various usage patterns

---

## Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Like rate | 20%+ of discoveries get at least one like | likes / total discoveries |
| Partner like engagement | 50%+ of partner-liked discoveries get viewed | Track if user sees discoveries partner liked |
| Mutual like rate | 10%+ discoveries liked by both | mutual likes / total discoveries |
| Return visits to Us Profile | Increase week-over-week | Profile view events per user |

---

## Example Scenarios

### Scenario A: Daily Active Couple
- 40 quizzes, 85 discoveries
- Emma liked 12 discoveries, James liked 8, 4 mutual
- James opens Us Profile:
  - **Featured:** High-stakes discovery Emma liked yesterday (partner signal + stakes + recency)
  - **Others:** Mix of Emma-liked + new unlocked discoveries

### Scenario B: Sporadic Couple
- 9 quizzes (8 two weeks ago, 1 yesterday)
- Emma liked 3 discoveries from two weeks ago
- James opens Us Profile:
  - **Featured:** Emma's liked high-stakes discovery from 12 days ago (partner signal trumps recency)
  - **Others:** Mix including yesterday's, but Emma-liked surfaces higher

### Scenario C: Returning Couple
- 15 quizzes a month ago, 3-week break
- Several discoveries liked by partner but unseen
- James opens Us Profile:
  - **Header:** "Pick Up Where You Left Off"
  - **Featured:** Partner-liked discovery from before break
  - **Prompt:** "Ready for new discoveries? Start today's quiz →"

### Scenario D: Highly Aligned Couple
- 30 quizzes, only 15 discoveries (few differences)
- 10 mutual likes
- **Header:** "You're In Sync!"
- **Featured:** Remaining non-mutual-liked discovery
- **Section:** "Discoveries You Both Loved" showing mutual likes

---

## Open Questions

1. **Should mutual likes ever resurface?** Perhaps in a nostalgia "Remember when..." feature?

2. **Should we notify partner when you like a discovery?** Push notification: "James found a discovery meaningful" could drive engagement but might feel intrusive.

3. **Should there be a "See what Emma liked" view?** Let partners explore each other's liked discoveries.

4. **Cap on featured discovery age?** Or is "partner-liked high-stakes from 60 days ago" still valid to surface?

---

*Specification created: January 3, 2026*
*Updated: January 3, 2026 — Replaced "tried/saved" model with simpler "Like" model*
