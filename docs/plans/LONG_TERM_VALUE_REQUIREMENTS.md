# Long-Term Value Requirements for Us Profile

## Overview

Based on the lifecycle stage mockups, this document outlines what content, features, and data architecture are needed to deliver compelling value to couples at 1 year+ of usage.

---

## Content Requirements

### Current State vs. Needed

| Content Type | Current | Needed for Year 1 | Gap |
|--------------|---------|-------------------|-----|
| Classic Quiz Questions | ~50 | 300+ | 250+ |
| Affirmation Questions | ~30 | 150+ | 120+ |
| You or Me Questions | ~40 | 200+ | 160+ |
| Linked Puzzles | ~60 | 200+ | 140+ |
| Word Search Puzzles | ~30 | 150+ | 120+ |
| **Total Content Pieces** | **~210** | **1000+** | **~790** |

### Content Rotation Strategy

To avoid repetition at Year 1:
- **Daily play assumption:** 1-2 games per day
- **Annual plays:** 365-730 games
- **Buffer for variety:** 2x content = 1,500+ content pieces ideal

### Content Categories to Expand

**Phase 1: Foundational (Months 1-3)**
- Light topics: Entertainment, food, hobbies, travel
- Getting-to-know-you: Childhood, favorites, preferences

**Phase 2: Deepening (Months 4-6)**
- Medium topics: Household, routines, social life
- Relationship dynamics: Communication, affection, support

**Phase 3: Significant (Months 7-12)**
- Life direction: Career, finances, living situation
- Future planning: Family, long-term goals
- Values: Core beliefs, priorities, boundaries

**Phase 4: Ongoing (Year 2+)**
- Seasonal content: Holidays, anniversaries, life events
- Life stage content: Moving, job changes, family additions
- Reflective content: "Compare to last year"

---

## Feature Requirements for Long-Term Value

### 1. Longitudinal Tracking (Critical)

Store historical data to show change over time:

```
Database additions needed:
- dimension_history (dimension_id, user_id, position, recorded_at)
- discovery_history (discovery_id, status, acted_on, discussed_at)
- quiz_answer_history (user_id, question_id, answer, answered_at)
```

**Enables:**
- "You've moved closer on Conflict Style since January"
- "This dimension has been consistent all year"
- Year-in-review visualizations

### 2. Insight Engine (High Value)

Analyze patterns across data:

| Insight Type | Example | Data Needed |
|--------------|---------|-------------|
| Growth | "You've moved closer on 3 dimensions" | dimension_history |
| Stability | "Your core values have stayed consistent" | value_scores over time |
| Action tracking | "12 discoveries acted on" | discovery.acted_on flags |
| Conversation count | "28 meaningful conversations" | conversation.logged_at |

### 3. Filtering & Organization

As discoveries grow, users need ways to find them:

- **By category:** Lifestyle, Values, Communication, Future
- **By status:** New, Acted On, Bookmarked, Discussed
- **By time:** This Month, Last 3 Months, All Time
- **By stakes:** Light, Medium, High

### 4. Anniversary & Milestone System

Celebrate relationship milestones:

| Milestone | Content |
|-----------|---------|
| 7 days | "First week together!" |
| 30 days | "One month of discoveries" |
| 100 quizzes | "Century achievement" |
| 6 months | "Half-year reflection" |
| 1 year | "Anniversary review" |

### 5. Year-in-Review Feature

Generate annual summary:
- Quizzes completed per month (chart)
- Top 5 discoveries
- Dimension changes
- Values stability
- Conversations logged
- Shareable summary card

---

## Data Architecture Changes

### New Tables Needed

```sql
-- Historical dimension tracking
CREATE TABLE dimension_snapshots (
  id UUID PRIMARY KEY,
  couple_id UUID REFERENCES couples(id),
  dimension_id TEXT,
  user1_position FLOAT,
  user2_position FLOAT,
  snapshot_date DATE,
  quiz_count_at_time INT
);

-- Discovery interactions
CREATE TABLE discovery_interactions (
  id UUID PRIMARY KEY,
  discovery_id UUID,
  interaction_type TEXT, -- 'viewed', 'acted_on', 'bookmarked', 'discussed'
  interacted_at TIMESTAMP,
  notes TEXT
);

-- Conversation logging
CREATE TABLE logged_conversations (
  id UUID PRIMARY KEY,
  couple_id UUID,
  starter_id UUID, -- links to conversation starter
  logged_at TIMESTAMP,
  duration_minutes INT,
  felt_helpful BOOLEAN
);

-- Milestones
CREATE TABLE couple_milestones (
  id UUID PRIMARY KEY,
  couple_id UUID,
  milestone_type TEXT,
  reached_at TIMESTAMP,
  celebrated BOOLEAN
);
```

### API Changes

New endpoints needed:
- `GET /api/us-profile/history?dimension=stress_processing`
- `GET /api/us-profile/year-review?year=2025`
- `POST /api/discoveries/{id}/mark-acted-on`
- `GET /api/milestones`

---

## Implementation Phases

### Phase 1: Foundation (Now)
- [ ] Add `acted_on` flag to discoveries
- [ ] Add `bookmarked` flag to discoveries
- [ ] Create milestone tracking table

### Phase 2: History (Month 1)
- [ ] Implement dimension snapshots (weekly)
- [ ] Implement discovery interaction logging
- [ ] Build basic "changes over time" view

### Phase 3: Content Expansion (Months 2-4)
- [ ] Generate 200+ new quiz questions (AI-assisted)
- [ ] Add category tagging to all content
- [ ] Implement content freshness rotation

### Phase 4: Insights (Months 5-6)
- [ ] Build insight engine
- [ ] Implement pattern detection
- [ ] Add personalized recommendations

### Phase 5: Celebration (Ongoing)
- [ ] Implement milestone system
- [ ] Build year-in-review generator
- [ ] Add shareable summary cards

---

## Content Generation Strategy

### AI-Assisted Content Creation

Use Claude to generate quiz questions in batches:

**Prompt template:**
```
Generate 20 unique couple quiz questions for the category "{category}".

Requirements:
- Questions should reveal preferences, not test knowledge
- Include both light and meaningful topics
- Answers should be 2-4 options
- Questions should work for couples of all backgrounds
- Avoid culturally specific references

Format: JSON with question, answers, category, stakes_level
```

### Quality Assurance
1. AI generates batch
2. Human reviews for sensitivity/appropriateness
3. Stakes level assigned
4. Therapeutic value assessed
5. Added to content pool

### Content Tagging System

Every content piece should have:
- `category`: lifestyle, values, communication, future, intimacy
- `stakes_level`: light, medium, high
- `timing_suggestion`: quick, relaxed, dedicated
- `dimension_tags`: which dimensions it informs
- `freshness_weight`: how often to show

---

## Success Metrics

### Year 1 Retention Indicators

| Metric | Target | Measures |
|--------|--------|----------|
| Weekly active couples | 50%+ | Engagement |
| Discoveries per month | 3-5 new | Content freshness |
| Conversations logged | 4+ per month | Therapeutic value |
| Dimension updates | Monthly | Profile accuracy |
| Year-in-review views | 80%+ | Feature adoption |

### Content Health Metrics

| Metric | Target | Action if Below |
|--------|--------|-----------------|
| Repeat content rate | <10% per month | Add more content |
| Question skip rate | <5% | Review question quality |
| Discovery engagement | >50% clicked | Improve framing |

---

## Open Questions

1. **Content velocity:** Can we generate 200+ quality questions per quarter?
2. **Storage costs:** Historical data will grow - what's the retention policy?
3. **Privacy:** How long do we keep detailed interaction history?
4. **Personalization:** Should long-term users get "harder" questions?
5. **Seasonal content:** How do we handle holidays across cultures?

---

*Document created: January 2, 2026*
*Related mockup: `mockups/us-profile-therapeutic/profile-lifecycle-stages.html`*
