# Quiz Content Rewrite Plan

## Goal
Transform quiz content from individual "first date" questions to couples-focused developmental questions that work for both new and established couples.

---

## Progress Tracker

### Playful Branch (Target: 20 quizzes)

| Quiz | Title | Status | Dimensions |
|------|-------|--------|------------|
| 001 | Social Energy | ✅ Done | `social_energy` |
| 002 | Risk & Adventure | ✅ Done | `risk_adventure` |
| 003 | Decision Making | ✅ Done | `planning_style` |
| 004 | Entertainment Style | ✅ Done | `novelty_preference` |
| 005 | Creative Expression | ✅ Done | preference discovery |
| 006 | Music & Rhythm | ✅ Done | preference discovery |
| 007 | Social Dynamics | ✅ Done | `support_style`, `social_energy` |
| 008 | Conflict Style | ✅ Done | `conflict_approach` |
| 009 | Teamwork | ✅ Done | `support_style`, `social_energy` |
| 010 | Spontaneity vs. Planning | ✅ Done | `planning_style` |
| 011 | Adventure & Comfort | ✅ Done | `risk_adventure` |
| 012 | Life Philosophy | ✅ Done | preference discovery |
| 013 | Food & Dining | ✅ Done | `novelty_preference`, `planning_style` |
| 014 | Pet Peeves & Quirks | ✅ Done | preference discovery |
| 015 | Morning & Night | ✅ Done | `daily_rhythm` |
| 016 | Technology & Screens | ✅ Done | `social_energy` |
| 017 | Affection & Touch | ✅ Done | preference discovery |
| 018 | Humor & Play | ✅ Done | preference discovery |
| 019 | Lazy Days & Self-Care | ✅ Done | `social_energy` |
| 020 | Traditions & Rituals | ✅ Done | `novelty_preference` |

---

## Dimensions

### Active (in calculator.ts)

| ID | Label | Left Pole | Right Pole |
|----|-------|-----------|------------|
| `social_energy` | Social Energy | Recharge Alone | Energized by People |
| `stress_processing` | How You Process Stress | Internal Processor | External Processor |
| `planning_style` | Planning Style | Spontaneous | Structured |
| `conflict_approach` | Conflict Approach | Space First | Talk It Out |

### Planned (to add to calculator.ts)

| ID | Label | Left Pole | Right Pole | Source |
|----|-------|-----------|------------|--------|
| `risk_adventure` | Risk & Adventure | Play It Safe | Thrill Seeker | quiz_002, quiz_011 |
| `novelty_preference` | Novelty Preference | Comfort & Familiar | New & Discovery | quiz_004, quiz_013, quiz_020 |
| `support_style` | Support Style | Listen First | Give Solutions | quiz_007, quiz_009 |
| `daily_rhythm` | Daily Rhythm | Night Owl | Early Bird | quiz_015 |

---

## Content Principles

### Universally Engaging Questions
Questions must work for couples at ALL stages:
- **New couples (weeks):** Answer based on hopes, early observations, aspirations
- **Established couples (years):** Answer based on patterns, reflection, appreciation

### Question Framing
- ❌ "I prefer..." / "My ideal..." (individual)
- ✅ "For us..." / "I'd love it if we..." / "When we..." (couples-focused)

### Two Question Types
1. **Dimension Questions** - Have `metadata.dimension` and `poleMapping`, contribute to spectrum scoring
2. **Preference Discovery** - No metadata, create "Worth Discussing" discoveries when partners differ

---

## Next Steps

### Phase 1: Playful Branch Content ✅ COMPLETE
- ~~Create quiz_013-020~~ ✅

### Phase 2: Calculator & UI Integration ✅ COMPLETE

**Task 2.1: Add new dimensions to calculator.ts** ✅
- File: `api/lib/us-profile/calculator.ts`
- Added 4 new dimensions:

| Dimension | Left Pole | Right Pole |
|-----------|-----------|------------|
| `risk_adventure` | Play It Safe | Thrill Seeker |
| `novelty_preference` | Comfort & Familiar | New & Discovery |
| `support_style` | Listen First | Give Solutions |
| `daily_rhythm` | Night Owl | Early Bird |

**Task 2.2: Dimension Unlock Tracking** ✅
- Migration: `api/supabase/migrations/033_dimension_unlocks.sql`
- Added `dimension_unlocks` JSONB column to `couples` table
- Tracks ISO timestamp when each dimension first gets data points
- Updated `api/lib/us-profile/cache.ts` to record unlock timestamps

**Task 2.3: Update Us Profile UI** ✅
- File: `app/lib/services/us_profile_service.dart` - Added `unlockedAt` field and `isRecentlyUnlocked` getter
- File: `app/lib/screens/us_profile_screen.dart` - Added "NEW" badge for dimensions unlocked within 7 days
- Flat list layout with NEW badge (per user preference)

### Phase 3: Lighthearted Branch Rewrite 🔲 TODO

**Current state:** Need to audit existing lighthearted quizzes
**Target:** 20 quizzes (matching playful branch size)
**Tone:** Fun but slightly more reflective than playful

Proposed topics (to be evaluated):
1. Dream vacations & travel styles
2. Gift giving & receiving
3. Love languages exploration
4. Celebration styles
5. Comfort foods & nostalgia
6. Childhood memories
7. Future dreams together
8. How we met / early memories (for established) or hopes (for new)
9. Favorite seasons & weather
10. Home & living space preferences
... (to be expanded after audit)

### Phase 4: Deeper Branches 🔲 FUTURE

See "Future: Psychological Frameworks" section below for:
- Connection branch (gentle attachment exploration)
- Attachment branch (attachment-theory informed)
- Growth branch (schema-aware patterns)

---

## Future: Psychological Frameworks for Deeper Branches

### Attachment Theory (Bowlby/Ainsworth)

**The four attachment styles:**

| Style | Core Pattern | In Relationships |
|-------|--------------|------------------|
| Secure | Comfortable with intimacy & independence | Can balance closeness and autonomy |
| Anxious | Fears abandonment, seeks reassurance | May need more closeness, worry about partner's feelings |
| Avoidant | Values independence, uncomfortable with too much closeness | May pull back when things get intense |
| Fearful-Avoidant | Wants closeness but fears it | Push-pull dynamic, conflicted |

**Potential dimensions:**
- `closeness_comfort` - Needs Space ↔ Needs Closeness
- `reassurance_needs` - Self-Assured ↔ Needs Reassurance

**Best for:** Attachment branch, Connection branch

---

### Jeffrey Young's Lifetraps (Schema Therapy)

**18 Early Maladaptive Schemas in 5 domains:**

1. **Disconnection & Rejection**
   - Abandonment, Mistrust/Abuse, Emotional Deprivation, Defectiveness/Shame, Social Isolation

2. **Impaired Autonomy**
   - Dependence/Incompetence, Vulnerability to Harm, Enmeshment, Failure

3. **Impaired Limits**
   - Entitlement/Grandiosity, Insufficient Self-Control

4. **Other-Directedness**
   - Subjugation, Self-Sacrifice, Approval-Seeking

5. **Overvigilance & Inhibition**
   - Negativity/Pessimism, Emotional Inhibition, Unrelenting Standards, Punitiveness

**Application:**
- Explains WHY certain discoveries are high-stakes
- Informs repair scripts in Us Profile
- Questions that help couples recognize patterns WITHOUT clinical labels

**Best for:** Growth branch, Attachment branch

---

### Implementation Principles

1. **Frame as exploration, not diagnosis** - We're not clinicians labeling people
2. **Use gentle, couples-focused language** - Not clinical terminology
3. **Keep playful/lighthearted branches light** - Save depth for appropriate branches
4. **Focus on patterns, not pathology** - "When we've been apart..." not "Do you have anxious attachment?"

**Example - Good framing:**
> "When we've been apart for a while, I find myself..."
> - Excited to reconnect and hear everything
> - A little anxious until I know we're okay
> - Enjoying the independence, then happy to see you
> - Needing a moment to readjust before diving in

**Example - Bad framing:**
> "Do you have an anxious attachment style?"

---

## Branch Order

1. ✅ Playful (20/20 complete)
2. 🔲 Lighthearted (next up)
3. 🔲 Connection (can touch attachment gently)
4. 🔲 Attachment (attachment-theory informed)
5. 🔲 Growth (schema-aware patterns)

---

*Last Updated: January 7, 2026 — Phase 1 & 2 complete*
