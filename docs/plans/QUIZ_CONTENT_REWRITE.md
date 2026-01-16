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

## Quiz Authoring Rules

### Rule 1: Stage Compatibility Check (REQUIRED)

Every question MUST pass this test before being added:

| Check | Question to Ask |
|-------|-----------------|
| **3-month test** | Can a couple dating 3 months answer this meaningfully? |
| **10-year test** | Can a couple married 10 years answer this meaningfully? |
| **Depth scales** | Would both couples find it relevant, just with different depth? |

If ANY check fails → reframe the question.

---

### Rule 2: Green Light vs Red Flag Framings

#### Green Light Framings (use these)

| Type | Examples | Why it works |
|------|----------|--------------|
| **Personal values/beliefs** | "My view on X is..." / "I believe..." | Beliefs are timeless |
| **Preferences/tendencies** | "I tend to..." / "I prefer..." | About you, not relationship stage |
| **Aspirational** | "I'd love for us to..." / "I hope we..." | Hopes work at any stage |
| **Invitation to discuss** | "The conversation I want to have..." | Always more to discuss |
| **Current feelings** | "Right now, I feel..." | Present tense, always valid |
| **Ongoing patterns** | "When it comes to X, I usually..." | Patterns exist at all stages |

#### Red Flag Framings (avoid these)

| Type | Examples | Problem |
|------|----------|---------|
| **Hypothetical discovery** | "If one of us had..." / "If I found out..." | Assumes you don't know yet |
| **Future-unknown** | "I'm curious how we'll..." / "I wonder if we'll..." | Established couples already know |
| **First-time disclosure** | "I'd want to know..." / "I'd want you to tell me..." | Implies info not yet shared |
| **Merged-life assumed** | "When we budget..." / "Our savings..." | Doesn't work for new couples |
| **Early-stage only** | "What first attracted me..." / "When we met..." | May feel irrelevant to established couples |

---

### Rule 3: Question Reframing Examples

| Bad (stage-specific) | Good (works for all) |
|----------------------|----------------------|
| "If one of us had debt, I'd want..." | "When it comes to debt, my view is..." |
| "I'm curious how we'll handle money..." | "The money conversation I want to have is..." |
| "When we first combine finances..." | "For everyday spending, I think we should..." |
| "I'd want to know what you earn..." | "When it comes to knowing what my partner earns, I feel..." |
| "How will we split expenses?" | "When it comes to treating each other, I believe..." |

---

### Rule 4: Therapeutic Metadata Requirements

Every question MUST have therapeutic metadata with these fields:

```json
"therapeutic": {
  "rationale": "Why this question matters (2-3 sentences)",
  "framework": "gottman | financial_therapy | attachment_theory | etc.",
  "whenDifferent": "Guidance when partners differ (2-3 sentences)",
  "whenSame": "Guidance when partners align (2-3 sentences)",
  "journalPrompt": "Reflection question for deeper exploration"
}
```

---

### Rule 5: Dimension Questions Guidelines

- Use **existing dimensions** from calculator.ts whenever possible
- Only propose new dimensions if truly necessary and reusable across multiple quizzes
- Each quiz should have **1-2 dimension questions max**, rest should be Preference Discovery
- Dimension questions need `poleMapping` array matching the 4 choices

---

### Rule 6: Pre-Submission Checklist

Before finalizing any quiz, verify:

- [ ] All 5 questions pass the 3-month AND 10-year test
- [ ] No red flag framings used
- [ ] Questions are couples-focused, not individual
- [ ] Therapeutic metadata complete on all questions
- [ ] Dimension questions use existing dimensions (or new dimension is justified)
- [ ] Quiz works for couples who haven't merged finances/living/etc.

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

### Phase 3: Lighthearted Branch Audit ✅ COMPLETE

**Audit Result:** Already high quality - no rewrite needed

**Findings:**
- 100% therapeutic metadata coverage (100 occurrences across 20 files)
- Couples-focused question framing throughout
- Dimension questions with proper poleMapping
- Full therapeutic objects on all questions (rationale, framework, whenDifferent, whenSame, journalPrompt)

**Sample quizzes verified:**
- quiz_001: "How We Show Up" - support styles, emotional presence
- quiz_005: "Dreams & Wishes" - aspirations, change orientation
- quiz_010: "Travel & Adventure" - travel preferences, planning styles
- quiz_015: "Fun & Play" - playfulness, competition, novelty
- quiz_020: "Our Story" - relationship narrative, shared history

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

### Original Branches
1. ✅ **Playful** (20/20 complete) - Full therapeutic metadata
2. ✅ **Lighthearted** (20 quizzes) - Audited, high quality, 100% therapeutic metadata
3. ✅ **Connection** (20 quizzes) - Audited, high quality, 100% therapeutic metadata
4. ✅ **Attachment** (20 quizzes) - Audited, high quality, 100% therapeutic metadata
5. ✅ **Growth** (20 quizzes) - Fully rewritten, couples-focused, 100% therapeutic metadata

### New Branches (Added Jan 2026)
6. ✅ **Finances** (15/15 complete) - Money, spending, financial values
7. ✅ **Intimacy** (15/15 complete) - Physical/emotional intimacy, desire, connection
8. ✅ **Conflict** (15/15 complete) - Repair, resolution, Gottman-informed

### Summary

| Branch | Quizzes | Questions | Status |
|--------|---------|-----------|--------|
| Playful | 20 | 100 | ✅ Complete |
| Lighthearted | 20 | 100 | ✅ Complete |
| Connection | 20 | 100 | ✅ Complete |
| Attachment | 20 | 100 | ✅ Complete |
| Growth | 20 | 100 | ✅ Complete |
| Finances | 15 | 75 | ✅ Complete |
| Intimacy | 15 | 75 | ✅ Complete |
| Conflict | 15 | 75 | ✅ Complete |
| **Total** | **145** | **725** | **8/8 complete** |

---

*Last Updated: January 13, 2026 — All 8 branches complete! Lighthearted branch audited and confirmed high quality (145 quizzes, 725 questions total)*
