# Discovery Relevance System Specification

## Overview

Replace the time-based "Recent Discoveries" with a relevance-scored "Worth Discussing" section that surfaces therapeutically valuable discoveries regardless of when they occurred.

**Goal:** Facilitate meaningful conversations, not just show new content.

---

## Current State

- Section titled "Recent Discoveries"
- Shows 5 most recent discoveries (from newest quizzes)
- No prioritization by importance or engagement status
- Sporadic users see stale content; active users may miss important older discoveries

---

## Proposed State

- Section titled "Worth Discussing" (or "Discoveries to Explore")
- Shows 1 Featured Discovery + 4 Other Discoveries
- Prioritized by relevance score combining stakes, engagement, patterns, and recency
- Adapts to any usage pattern (daily, sporadic, returning)

---

## Relevance Scoring Algorithm

### Input Data Per Discovery

| Field | Source | Description |
|-------|--------|-------------|
| `id` | Existing | Unique discovery identifier |
| `stakesLevel` | Quiz question metadata | 'high', 'medium', 'light' |
| `createdAt` | Quiz completion timestamp | When discovery was generated |
| `viewedAt` | New: client tracking | When user first saw this discovery (null if never) |
| `status` | New: user action | 'unviewed', 'viewed', 'saved', 'tried' |
| `dimensionId` | Quiz question metadata | Which dimension this relates to (nullable) |
| `category` | Existing | emotional, communication, values, etc. |

### Scoring Formula

```
relevanceScore = stakesPoints + engagementPoints + patternPoints + recencyPoints
```

### Scoring Breakdown

#### Stakes Points (0-50)

| Stakes Level | Points | Example Topics |
|--------------|--------|----------------|
| High | 50 | Finances, children, intimacy, career, where to live, in-laws |
| Medium | 25 | Daily routines, social preferences, household, communication |
| Light | 10 | Food, hobbies, entertainment, travel preferences |

**Implementation:** Add `stakesLevel` field to quiz question metadata. Map categories:

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

#### Engagement Points (-40 to +30)

| Status | Points | Rationale |
|--------|--------|-----------|
| `unviewed` | +30 | Never seen, high priority to surface |
| `viewed` | +20 | Saw it but hasn't acted |
| `saved` | +15 | Explicitly saved for later |
| `tried` | -40 | Already discussed, deprioritize |

**Implementation:** Track discovery engagement in new table.

#### Pattern Points (0-25)

| Condition | Points | Rationale |
|-----------|--------|-----------|
| Links to dimension with partner difference > 0.5 | +25 | Part of significant theme |
| 3+ discoveries in same category | +15 | Recurring friction area |
| Neither | +0 | Standalone discovery |

**Implementation:** Join with dimension scores during calculation.

#### Recency Points (0-15)

| Age | Points | Rationale |
|-----|--------|-----------|
| 0-3 days | +15 | Very fresh |
| 4-7 days | +10 | Recent |
| 8-14 days | +5 | Moderate |
| 15+ days | +0 | No penalty, just no boost |

**Implementation:** Calculate from `createdAt` timestamp.

---

## Database Changes

### New Table: `discovery_engagement`

```sql
CREATE TABLE discovery_engagement (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  discovery_id TEXT NOT NULL,  -- Format: "{quizMatchId}_{questionId}"
  user_id UUID NOT NULL REFERENCES auth.users(id),

  -- Engagement tracking
  first_viewed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'unviewed',  -- 'unviewed', 'viewed', 'saved', 'tried'
  status_changed_at TIMESTAMPTZ,

  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(couple_id, discovery_id)
);

CREATE INDEX idx_discovery_engagement_couple ON discovery_engagement(couple_id);
CREATE INDEX idx_discovery_engagement_status ON discovery_engagement(couple_id, status);
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

For existing questions without `stakesLevel`, derive from category using the mapping above.

---

## API Changes

### Modified: GET /api/us-profile

Response changes to `discoveries` array:

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
      "relevanceScore": 120,
      "status": "unviewed",
      "createdAt": "2026-01-01T10:00:00Z",
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
        "relevanceScore": 105,
        "status": "viewed",
        "createdAt": "2025-12-28T14:00:00Z",
        "tryThisAction": "Have a 15-minute conversation about financial priorities this week",
        "timingBadge": { "type": "relaxed", "label": "Best for a quiet evening" }
      }
      // ... 3 more
    ],
    "totalCount": 47,
    "unaddressedCount": 41
  }
}
```

### New: POST /api/us-profile/discovery/{id}/engage

Track discovery engagement:

```json
// Request
{
  "action": "view" | "save" | "unsave" | "tried"
}

// Response
{
  "success": true,
  "discovery": {
    "id": "match_123_q3",
    "status": "tried",
    "statusChangedAt": "2026-01-03T15:30:00Z"
  }
}
```

---

## Backend Implementation

### New File: `api/lib/us-profile/relevance.ts`

```
Functions:
- calculateRelevanceScore(discovery, dimensions, engagementMap) → number
- rankDiscoveries(discoveries, dimensions, engagementMap) → RankedDiscovery[]
- selectFeaturedAndOthers(rankedDiscoveries) → { featured, others }
- getStakesLevel(category, explicitLevel?) → 'high' | 'medium' | 'light'
- getPatternBonus(discovery, dimensions) → number
- getRecencyBonus(createdAt) → number
```

### Modified: `api/lib/us-profile/framing.ts`

Replace:
```typescript
const discoveries = frameDiscoveries(coupleInsights.discoveries).slice(-10).reverse();
```

With:
```typescript
const engagementMap = await getDiscoveryEngagement(coupleId);
const rankedDiscoveries = rankDiscoveries(
  coupleInsights.discoveries,
  framedDimensions,
  engagementMap
);
const { featured, others } = selectFeaturedAndOthers(rankedDiscoveries);
```

### Category Selection for "Others"

When selecting the 4 "other" discoveries, ensure variety:
1. Take highest scored discovery
2. For remaining 3, prefer different categories than already selected
3. If all top discoveries are same category, still show them (indicates pattern)

---

## Flutter Implementation

### Modified: `UsProfileScreen`

**Section rename:** "Recent Discoveries" → "Worth Discussing"

**Layout change:**

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
│  │  This is a significant topic...     ││
│  │                                     ││
│  │  [Conversation Guide →]             ││
│  └─────────────────────────────────────┘│
│                                         │
│  Other Insights                         │
│  ┌──────────┐ ┌──────────┐             │
│  │ Card 1   │ │ Card 2   │             │
│  └──────────┘ └──────────┘             │
│  ┌──────────┐ ┌──────────┐             │
│  │ Card 3   │ │ Card 4   │             │
│  └──────────┘ └──────────┘             │
│                                         │
│  See all 47 discoveries →               │
└─────────────────────────────────────────┘
```

**Featured card styling:**
- Larger, more prominent
- Gradient border or background tint based on stakes level
- Full conversation guide for high-stakes
- "Try This" action for medium/light stakes

**Other cards styling:**
- Compact 2x2 grid
- Show question + both answers + category badge
- Tap to expand

### New: Engagement Tracking

When user views Us Profile screen:
```dart
// Mark all visible discoveries as "viewed" if currently "unviewed"
for (final discovery in visibleDiscoveries) {
  if (discovery.status == 'unviewed') {
    await _profileService.markDiscoveryViewed(discovery.id);
  }
}
```

When user taps "I tried it":
```dart
await _profileService.markDiscoveryTried(discovery.id);
// Show success feedback
// Card updates to "tried" state (checkmark, muted styling)
```

When user taps "Save for later":
```dart
await _profileService.toggleDiscoverySaved(discovery.id);
// Toggle bookmark icon state
```

### Modified: `UsProfileService`

Add methods:
```dart
Future<void> markDiscoveryViewed(String discoveryId);
Future<void> markDiscoveryTried(String discoveryId);
Future<void> toggleDiscoverySaved(String discoveryId);
```

---

## Contextual Header Labels

Adapt the featured section header based on user context:

| Context | Header | Rationale |
|---------|--------|-----------|
| Has unviewed high-stakes discovery | "This Week's Focus" | Emphasize importance |
| All recent, no high-stakes | "Worth Discussing" | Neutral |
| Returning after 2+ weeks | "Pick Up Where You Left Off" | Acknowledge break |
| All discoveries tried | "Great Progress!" | Celebrate completion |
| Very few discoveries total | "Your First Insights" | Encourage new users |

**Implementation:** Add `contextLabel` to API response based on discovery state analysis.

---

## Migration Plan

### Phase 1: Backend (No UI change yet)
1. Add `discovery_engagement` table
2. Add `stakesLevel` to quiz question metadata (derive from category for existing)
3. Implement relevance scoring in `relevance.ts`
4. Update `/api/us-profile` to return scored discoveries
5. Add `/api/us-profile/discovery/{id}/engage` endpoint

### Phase 2: Flutter UI
1. Update `UsProfileScreen` section layout
2. Add featured discovery card component
3. Add compact discovery card grid
4. Implement engagement tracking (view, save, tried)
5. Add "See all discoveries" navigation

### Phase 3: Polish
1. Add contextual headers
2. Add "tried" celebration feedback
3. Add empty state for couples with few discoveries
4. Test with various usage patterns

---

## Success Metrics

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| Discovery → "I tried it" rate | N/A | 15%+ | `tried` status count / total discoveries |
| High-stakes discovery engagement | Unknown | Higher than light | Compare tried rates by stakes level |
| Return visit to Us Profile | Unknown | Increase | Track profile views per user per week |
| Time in discoveries section | Unknown | Increase | Analytics event timing |

---

## Example Scenarios (Validation)

### Scenario A: Daily Active Couple
- 40 quizzes, 85 discoveries
- Yesterday's high-stakes discovery about finances → **Featured**
- Mix of recent medium + older unviewed high-stakes → **Others**

### Scenario B: Sporadic Couple
- 9 quizzes (8 two weeks ago, 1 yesterday)
- 12-day-old high-stakes about career → **Featured** (beats yesterday's light discovery)
- Mix from both periods → **Others**

### Scenario C: Returning Couple
- 15 quizzes a month ago, 3-week break
- Oldest unviewed high-stakes about intimacy → **Featured**
- Header: "Pick Up Where You Left Off"
- Prompt: "Ready for new discoveries? Start today's quiz →"

### Scenario D: New Couple
- 2 quizzes, 4 discoveries (all light stakes)
- Highest scored light discovery → **Featured**
- Header: "Your First Insights"
- Others show remaining 3

---

## Open Questions

1. **Should "tried" discoveries ever resurface?** Perhaps after 30 days if the underlying dimension still shows difference?

2. **Should we cap how old a featured discovery can be?** Or is "unviewed high-stakes from 60 days ago" still valid to surface?

3. **Should we add a "not relevant" dismiss option?** Lets users hide discoveries that don't resonate.

4. **Should engagement sync between partners?** If Emma marks "tried", should James see it as tried too?

---

*Specification created: January 3, 2026*
