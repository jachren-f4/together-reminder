# Us Profile Page - Data Plan

**Status:** Ready for review before implementation
**Last Updated:** 2025-12-29
**Mockup Reference:** `mockups/us-profile/variant-9-action-focused.html`

This document outlines all data points displayed on the Us profile page, how they are derived, what quiz questions are needed to populate them, and implementation phases with testing tasks.

---

## Design Philosophy: Action Over Information

After analyzing each data point for relationship health benefit, we've prioritized features that:
1. **Drive behavior change** - Not just "interesting" but actionable
2. **Prevent real conflicts** - Focus on stress, conflict, finances, family
3. **Track actions, not engagement** - "Did you try it?" not "How many quizzes?"
4. **Avoid harmful labels** - Tendencies, not personality types

**Highest-value features (⭐⭐⭐⭐⭐):**
- "Try This" action suggestions attached to discoveries
- Financial and family value alignment
- Stress processing and conflict approach dimensions
- Conversation starters with context

**Deprioritized/removed:**
- Vanity metrics (questions explored count)
- Low-actionability dimensions (decision making, change tolerance)
- Fixed personality labels (attachment "types")

---

## Table of Contents

1. [Action Stats](#1-action-stats-replaces-journey-stats)
2. [How You Navigate Together (4 Key Dimensions)](#2-how-you-navigate-together-reduced-to-4-key-dimensions)
3. [Love Languages](#3-love-languages)
4. [Connection Tendencies](#4-connection-tendencies-reframed-from-attachment-styles)
5. [Shared Values](#5-shared-values)
6. [Discoveries Over Time](#6-discoveries-over-time)
7. [Recent Discoveries](#7-recent-discoveries)
8. [Through Partner's Eyes](#8-through-partners-eyes)
9. [Conversation Starters](#9-conversation-starters)
10. [Data Storage Schema](#10-data-storage--database-schema)
11. [Data Update Frequency](#11-data-update-frequency)
12. [Question Tagging System](#12-question-tagging-system)
13. [Implementation Phases](#13-implementation-phases)
14. [Hard Questions & Potential Pitfalls](#14-hard-questions--potential-pitfalls)
15. [Recommended Principles](#15-recommended-principles)

---

## 1. Action Stats (Replaces "Journey Stats")

**Display:** Three metrics focused on actions taken, not engagement vanity metrics.

| Metric | Description | Why it matters |
|--------|-------------|----------------|
| Insights Acted On | "Try This" suggestions marked as done | Tracks behavior change, not just awareness |
| Conversations Had | Prompts marked as "We discussed this" | Real interaction, not generated prompts |
| This Week's Focus | Current actionable insight to try | Keeps one thing top of mind |

**Data Source:** Action tracking on discoveries and conversation starters.

**Calculation (Implementation Practice):**
- `insights_acted_on`: Count of `couple_discoveries` where `acted_on = true`
- `conversations_had`: Count of `conversation_starters` where `discussed = true`
- `current_focus`: Most recent unacted discovery with highest relevance score

**Why we changed this:**
- "Questions Explored" rewarded app usage, not relationship health (⭐⭐)
- "Discoveries Made" implied more differences = better (wrong)
- New metrics reward actual behavior change (⭐⭐⭐⭐⭐)

---

## 2. How You Navigate Together (Reduced to 4 Key Dimensions)

**Display:** Dual-position sliders showing where each partner falls on the most actionable dimensions.

### Dimensions to Measure (Prioritized by Relationship Health Impact)

| Dimension | Left Pole | Right Pole | Why it matters | Grade |
|-----------|-----------|------------|----------------|-------|
| Stress Processing | Need space first | Want to talk it out | Prevents daily friction, #1 practical insight | ⭐⭐⭐⭐⭐ |
| Conflict Approach | Process then discuss | Address immediately | Predicts repair success (Gottman research) | ⭐⭐⭐⭐⭐ |
| Planning Style | Embrace spontaneity | Prefer to plan ahead | Affects daily logistics, prevents resentment | ⭐⭐⭐⭐ |
| Social Energy | Recharge alone | Recharge with others | Helps plan social life, prevents friction | ⭐⭐⭐ |

### Removed Dimensions (Low Actionability)

| Dimension | Why removed |
|-----------|-------------|
| Decision Making (analytical vs intuitive) | Interesting but rarely actionable in daily life |
| Change Tolerance (stability vs novelty) | Trait awareness without clear behavior change |

These can return if we find ways to attach actionable "Try This" suggestions.

### How to Calculate Position (0-100 scale)

Each dimension needs **3-5 tagged questions** across quizzes.

**Calculation (Implementation Practice):**
- For each dimension, find all questions tagged with that dimension in `question_metadata`
- For each answered question, check if user's answer maps to "left" (0) or "right" (1) pole via `answer_mapping`
- Calculate: (sum of right-pole answers) / (total dimension questions answered) × 100
- Store result in `user_dimension_scores` table with question_count for confidence indicator

### Example Questions Per Dimension (4 Kept)

**Stress Processing (⭐⭐⭐⭐⭐):**
- "When upset, the first thing you need is..." → (A) Time alone to think (B) Someone to talk to
- "After a hard day, you want your partner to..." → (A) Give you space (B) Ask what's wrong
- "You process problems best by..." → (A) Thinking quietly (B) Talking through them
- "When stressed about work, you typically..." → (A) Need to decompress alone first (B) Want to vent immediately

**Conflict Approach (⭐⭐⭐⭐⭐):**
- "When annoyed at your partner, you..." → (A) Wait for it to pass (B) Bring it up right away
- "Difficult conversations should be..." → (A) Given time to process first (B) Had as soon as needed
- "After a disagreement, you need..." → (A) Space before reconnecting (B) To resolve it immediately
- "When your partner does something that bothers you..." → (A) You wait to see if it happens again (B) You mention it right away

**Planning Style (⭐⭐⭐⭐):**
- "For vacations, you prefer..." → (A) Flexible itinerary (B) Detailed schedule
- "Weekend plans are usually made..." → (A) Day-of (B) A week ahead
- "When making dinner plans, you..." → (A) Decide when hungry (B) Plan in advance

**Social Energy (⭐⭐⭐):**
- "After a long week, your ideal Saturday is..." → (A) Quiet day at home (B) Brunch with friends
- "At a party, you typically..." → (A) Find a few people to talk deeply with (B) Float around meeting everyone
- "A weekend with lots of social plans feels..." → (A) Draining (B) Energizing

### Tagging Format

Each quiz question needs metadata stored in `question_metadata` table:
- `question_id`: Unique identifier matching the quiz content file
- `dimension`: Which dimension this measures (e.g., "social_energy")
- `answer_mapping`: JSONB mapping each answer option to "left" or "right" pole

Example metadata row: question about ideal Saturday with answer A mapping to "left" pole (recharge alone) and answer B mapping to "right" pole (recharge with others).

---

## 3. Love Languages

**Display:** Side-by-side bar charts comparing both partners across 5 love languages.

### The Five Love Languages

| Language | Description | Indicator Questions |
|----------|-------------|---------------------|
| Words of Affirmation | Verbal compliments, encouragement | Values hearing "I love you", compliments, encouragement |
| Quality Time | Undivided attention, togetherness | Values focused attention, shared activities |
| Acts of Service | Helpful actions, easing burden | Values partner doing tasks, helping out |
| Receiving Gifts | Thoughtful presents, symbols | Values surprises, remembering occasions |
| Physical Touch | Affection, physical closeness | Values hugs, holding hands, physical presence |

### How to Calculate (0-100 scale per language)

**Option A: Ranking Questions**
Ask users to rank all 5 in preference order (drag to reorder):
1. Hearing "I love you" and compliments
2. Spending focused time together
3. When my partner helps with tasks
4. Thoughtful gifts or surprises
5. Physical affection like hugs

**Scoring:** Rank 1 = 100, Rank 2 = 75, Rank 3 = 50, Rank 4 = 25, Rank 5 = 10

**Option B: Forced Choice Pairs**
Classic love languages test format - 15 A/B questions covering all pairs:
- "Would you prefer: (A) A heartfelt compliment OR (B) A long hug"
- "Would you prefer: (A) Help with chores OR (B) A surprise gift"

Each choice adds points to that language. Final scores normalized to 0-100.

**Option C: Scenario Questions (Integrated into regular quizzes)**
Tag existing/new questions with love language relevance in `question_metadata`:
- `love_language` column indicates which language this question measures
- For multi-answer questions, store `answer_love_language_mapping` (JSONB) mapping each answer to a language

Example question: "The best birthday gift would be..." with 5 answers, each mapping to a different love language:
- "A handwritten love letter" → words_of_affirmation
- "A full day together, no phones" → quality_time
- "Partner handles all my tasks that day" → acts_of_service
- "A surprise I've always wanted" → receiving_gifts
- "Breakfast in bed with cuddles" → physical_touch

### Recommended Approach

Use **Option C (Scenario Questions)** integrated into regular quizzes:
- Less intrusive than a dedicated test
- Builds data over time
- Can refine accuracy as more questions answered
- Need 2-3 questions per language (10-15 total tagged questions)

---

## 4. Connection Tendencies (Reframed from "Attachment Styles")

**Display:** Current tendencies in THIS relationship, not fixed personality labels.

### Why We Reframed This (⭐⭐ → ⭐⭐⭐⭐)

**Problem with "Attachment Styles":**
- Labels become fixed identity ("I'm avoidant, that's just who I am")
- Can be used as excuses rather than growth opportunities
- Clinical terms misapplied without professional context

**Better approach: Tendencies in this relationship**
- "Right now, in stressful moments, you tend to..."
- Framed as changeable patterns, not personality
- Focus on the dynamic between partners, not individual labels

### Connection Tendency Framework

| Tendency | What it looks like | Strength it brings |
|----------|-------------------|-------------------|
| Seeks Reassurance | Wants to check in frequently, sensitive to distance | Attentive, values connection |
| Needs Processing Space | Prefers time before deep conversations | Thoughtful, avoids reactive responses |
| Direct Expresser | Shares feelings readily, wants immediate resolution | Open, clear communication |
| Gradual Opener | Builds to vulnerable topics slowly | Creates safety, respects pacing |

**Key difference:** No style is "secure" or "insecure" - each brings value.

### Questions to Determine Style

**Closeness Comfort (4 questions):**
- "I'm comfortable depending on my partner" → (Strongly agree to Strongly disagree)
- "I find it easy to share my feelings with my partner" → (Scale)
- "I worry about being too dependent on my partner" → (Scale)
- "I prefer to handle problems on my own before involving my partner" → (Scale)

**Reassurance Needs (4 questions):**
- "When apart, I need to hear from my partner regularly to feel connected" → (Scale)
- "I sometimes worry my partner doesn't love me as much as I love them" → (Scale)
- "I feel secure in my relationship without needing constant reassurance" → (Scale)
- "When my partner is distant, I assume something is wrong" → (Scale)

### Scoring Logic (Implementation Practice)

**Step 1:** Calculate two subscores from answered questions:
- `closeness_comfort`: Average of closeness-tagged questions (1-5 scale)
- `reassurance_needs`: Average of reassurance-tagged questions (1-5 scale)

**Step 2:** Determine style based on thresholds:

| Closeness Comfort | Reassurance Needs | Style |
|-------------------|-------------------|-------|
| ≥ 3.5 | ≤ 3.0 | Secure-Expressive |
| ≥ 3.5 | > 3.0 | Connection-Seeking |
| < 3.5 | ≤ 3.0 | Secure-Reserved |
| < 3.5 | > 3.0 | Independence-Valuing |

Store result in `user_connection_style` table with both subscores for reference.

---

## 5. Shared Values

**Display:** Alignment bars showing percentage agreement on value categories.

### Value Categories

| Category | Description | Example Topics |
|----------|-------------|----------------|
| Honesty & Trust | Truthfulness, transparency | White lies, privacy, keeping secrets |
| Family Priority | Importance of family ties | Extended family, future kids, holidays |
| Adventure & Growth | Risk-taking, trying new things | Travel, career changes, experiences |
| Work-Life Balance | Career vs personal time | Overworking, ambition, presence |
| Financial Philosophy | Spending vs saving | Budgets, splurges, financial goals |
| Social Life | Friend time, social activities | Socializing frequency, friend priority |

### How to Calculate Alignment (Implementation Practice)

Tag each quiz question with a `value_category` in `question_metadata` table.

**Calculation:**
- For each value category, find all questions tagged with that category
- Compare both partners' answers for each question
- Alignment % = (matching answers) / (total answered questions in category) × 100
- Store result in `couple_value_alignment` table with question_count

### Display Logic

| Alignment % | Badge |
|-------------|-------|
| 80-100% | "Aligned" (green) |
| 60-79% | "Mostly aligned" (teal) |
| 40-59% | "Exploring" (purple) - shown as conversation opportunity |
| < 40% | "Different perspectives" (gold) - framed positively |

### Example Tagged Questions

Questions tagged with `value_category` in `question_metadata`:

| Question | Answers | Value Category |
|----------|---------|----------------|
| "Little white lies to spare feelings are..." | Sometimes okay, Never okay | honesty_trust |
| "Holidays should be spent with..." | Extended family, Just us, Mix of both | family_priority |
| "An unexpected bonus should go to..." | Savings, A splurge, Half and half | financial_philosophy |

---

## 6. Discoveries Over Time

**Display:** Bar chart showing discoveries (different answers) per week.

### Data Structure

API returns array of weekly discovery counts:
- `week`: Week identifier (ISO week or "W1", "W2" format)
- `count`: Number of discoveries that week

### Calculation (Implementation Practice)

**Source:** `couple_discoveries` table (populated on quiz completion)

**Query approach:**
- Group discoveries by week of `discovered_at` timestamp
- Count rows per week for this couple
- Return last 6 weeks of data
- Order descending (most recent first)

**Note:** Read from pre-populated `couple_discoveries` table, NOT directly from `quiz_matches`. Discoveries are created when quizzes complete, not on-demand.

---

## 7. Recent Discoveries

**Display:** Cards showing specific differences learned this week.

### Data Structure

`couple_discoveries` table columns:
- `id`: Unique identifier
- `couple_id`: Reference to couples table
- `question_id`: Reference to original question
- `question_text`: Denormalized for display
- `user1_answer`: What first user answered
- `user2_answer`: What second user answered
- `dimension`: Optional - which personality dimension this relates to
- `discovered_at`: Timestamp of discovery
- `framing_text`: Template-based positive framing text

### Framing Templates

Convert raw differences into appreciative insights:

| Pattern | Template |
|---------|----------|
| Opposite preferences | "{Partner1} prefers {A} while {Partner2} enjoys {B}" |
| Need differences | "When stressed, {Partner1} needs {A} while {Partner2} needs {B}" |
| Style differences | "{Partner1}'s approach is {A}, {Partner2}'s is {B}" |

### Example Transformation

**Raw data:**
```json
{
  "question": "After a hard day, you want to...",
  "emma_answer": "Talk about it",
  "james_answer": "Have quiet time first"
}
```

**Displayed as:**
> "When stressed, **James** needs quiet time first while **Emma** wants to talk about it"

---

## 8. Through Partner's Eyes

**Display:** Tags showing traits your partner attributed to you via You or Me questions.

### Data Source

All You or Me questions where partner picked "You":
- Question: "Who is more organized?"
- James answered: "Emma" (meaning Emma is more organized)
- Display to Emma: "James sees you as... More organized"

### Aggregation Logic (Implementation Practice)

**Source:** `quiz_matches` where `quiz_type = 'you_or_me'`

**Query approach:**
- Find all You or Me quizzes for this couple
- For each question, check if partner selected "You" (meaning they attributed trait to current user)
- Collect all traits partner attributed to user
- Return unique list of trait tags

**Note:** Uses `quiz_matches.player1_answers` and `player2_answers` JSONB arrays, NOT deprecated `you_or_me_answers` table.

### Trait Extraction

Each You or Me question maps to a trait:

| Question | Trait Tag |
|----------|-----------|
| "Who is more organized?" | "More organized" |
| "Who is funnier?" | "Funnier" |
| "Who is more patient?" | "More patient" |
| "Who worries more?" | "The worrier" (neutral framing) |
| "Who is more romantic?" | "More romantic" |

### Display Rules

- Show max 5-6 traits
- Prioritize positive/neutral traits
- Update when new You or Me quizzes completed

---

## 9. Conversation Starters

**Display:** Curated prompts based on interesting differences or discoveries.

### Generation Logic

Triggers for conversation starters:
1. **Dimension differences** - When partners are >30 points apart on a slider
2. **Love language gaps** - When one partner scores high on a language the other scores low
3. **Value exploration** - Categories with <60% alignment
4. **Recent discoveries** - Any significant difference in last 2 weeks

### Template System

| Trigger | Template |
|---------|----------|
| Dimension gap | "You differ on {dimension}. Ask {Partner} what their ideal {context} looks like." |
| Love language gap | "{Partner} values {language} highly. Ask what specific {examples} mean the most to them." |
| Value exploring | "You're exploring {category} together. Discuss: {question}" |
| Discovery follow-up | "You learned {Partner} prefers {X}. Ask them why!" |

### Storage

`conversation_starters` table columns:
- `id`: Unique identifier
- `couple_id`: Reference to couples table
- `trigger_type`: One of: dimension, love_language, value, discovery
- `trigger_data`: JSONB containing the underlying data that triggered this starter
- `prompt_text`: The conversation prompt to display
- `context_text`: Additional context explaining why this was suggested
- `created_at`: When the starter was generated
- `dismissed`: Boolean - user dismissed without discussing
- `discussed`: Boolean - user marked as discussed

---

## 10. Data Storage & Database Schema

### Existing Tables We Read From

These tables already exist and contain the source data for profile insights:

| Table | Purpose | Key Columns for Us Profile |
|-------|---------|---------------------------|
| `couples` | Couple records | `id`, `user1_id`, `user2_id`, `total_lp`, `created_at` |
| `quiz_matches` | Completed quizzes (classic, affirmation, you_or_me) | `couple_id`, `quiz_type`, `player1_answers` (JSONB), `player2_answers` (JSONB), `match_percentage`, `completed_at` |
| `welcome_quiz_answers` | Onboarding quiz answers | `couple_id`, `user_id`, `answers` (JSONB with questionId + answer) |

**IMPORTANT:** Do NOT use these deprecated/legacy tables:
- ~~`quiz_sessions`~~ → Use `quiz_matches` instead
- ~~`quiz_answers`~~ → Answers are in `quiz_matches.player1_answers/player2_answers`
- ~~`you_or_me_sessions`~~ → Use `quiz_matches` with `quiz_type = 'you_or_me'`
- ~~`you_or_me_answers`~~ → Answers are in `quiz_matches.player1_answers/player2_answers`

### Question Metadata Location

Question tags (dimension, love_language, value_category) are **embedded directly in quiz JSON files**, NOT in a separate database table. This keeps content and metadata together.

Example quiz question with embedded metadata:
```
Question: "After a long week, your ideal Saturday is..."
Answers: ["Quiet day at home", "Brunch with friends"]
Metadata:
  - dimension: "social_energy"
  - pole_mapping: ["left", "right"]  // First answer = left pole, second = right
```

### New Tables to Create (2 tables only)

| Table | Purpose | Primary Key |
|-------|---------|-------------|
| `us_profile_cache` | All calculated insights for a couple | `couple_id` |
| `conversation_starters` | Generated prompts with action state | `id` |

### us_profile_cache Table Structure

Single row per couple containing all pre-calculated insights:

| Column | Type | Description |
|--------|------|-------------|
| `couple_id` | UUID | Primary key, references couples.id |
| `user1_insights` | JSONB | First user's individual scores |
| `user2_insights` | JSONB | Second user's individual scores |
| `couple_insights` | JSONB | Shared couple-level data |
| `updated_at` | TIMESTAMP | Last recalculation time |

**user1_insights / user2_insights JSONB structure:**
- `dimensions`: Object with score per dimension (0-100) + question_count
- `love_languages`: Object with score per language (0-100) + question_count
- `connection_style`: String label + closeness/reassurance subscores
- `partner_perception_traits`: Array of traits partner attributed to this user

**couple_insights JSONB structure:**
- `value_alignments`: Object with alignment % per category + question_count
- `discoveries`: Array of recent discovery objects (question, answers, framing, date)
- `questions_explored`: Total count
- `total_discoveries`: Total count

### conversation_starters Table Structure

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `couple_id` | UUID | References couples.id |
| `trigger_type` | TEXT | dimension, love_language, value, discovery |
| `data` | JSONB | Trigger data, prompt text, context |
| `dismissed` | BOOLEAN | User dismissed without discussing |
| `discussed` | BOOLEAN | User marked as discussed |
| `created_at` | TIMESTAMP | When generated |

### Data Flow Summary

1. **Source:** Quiz JSON files contain questions with embedded metadata tags
2. **Raw Data:** `quiz_matches` stores player answers as JSONB arrays
3. **Calculation:** On quiz completion, recalculate and update `us_profile_cache`
4. **Generation:** Nightly job creates `conversation_starters` from cache data
5. **Read:** Profile API reads directly from `us_profile_cache` (no calculation)

---

## 11. Data Update Frequency

### When to Recalculate

| Trigger | What to Update | Latency Requirement |
|---------|----------------|---------------------|
| Quiz completion | Full `us_profile_cache` row for this couple | Real-time (in same API call) |
| App open / Profile view | Nothing - read from cache | Instant (no recalc) |
| Nightly (scheduled job) | Generate new `conversation_starters` | Async (within minutes) |
| Algorithm change | All `us_profile_cache` rows | Background job (overnight) |

### Update Strategy

**On Quiz Completion (synchronous):**

When any quiz completes (classic, affirmation, you_or_me), the API handler:

1. Load all `quiz_matches` for this couple
2. Load quiz JSON files to get question metadata (dimensions, love languages, etc.)
3. Recalculate ALL insights for BOTH users:
   - Dimension scores (iterate tagged questions, calculate positions)
   - Love language scores (aggregate tagged answers)
   - Connection style (if enough attachment questions answered)
   - Value alignments (compare partner answers per category)
   - Discoveries (find new differences, generate framing text)
   - Partner perception traits (from You or Me answers)
4. UPSERT single row into `us_profile_cache`
5. Return updated profile in quiz completion response (optional)

**Why recalculate everything?**
- Simpler logic (no incremental updates to debug)
- Single row update is fast
- Ensures consistency across all metrics
- With ~50-100 answered questions max, calculation is <100ms

**Profile API Read (no calculation):**

```
GET /api/us-profile → SELECT * FROM us_profile_cache WHERE couple_id = ?
```
- Single row fetch, return JSONB directly
- Include `updated_at` in response for UI freshness indicator

**Nightly Job (async):**

1. For each couple with `us_profile_cache.updated_at` in last 7 days:
   - Check for dimension gaps >30 points → create starter
   - Check for love language mismatches → create starter
   - Check for value categories <60% aligned → create starter
2. Clean up old/dismissed starters (>30 days)
3. Log job completion

### Cache Staleness Handling

- `us_profile_cache.updated_at` tracks last recalculation
- Profile API returns `lastUpdated` timestamp
- UI shows "Updated today" or "Updated 3 days ago"
- If >7 days stale AND no recent quizzes, show gentle prompt: "Complete a quiz to refresh your insights"

---

## 12. Question Tagging System

### Tag Categories

Each quiz question has metadata embedded directly in the quiz JSON files. Tags include:
- `dimension` - Which personality dimension this measures (e.g., "social_energy")
- `poleMapping` - Array indicating which answer points to which pole (["left", "right"])
- `loveLanguage` - If applicable, which love language this measures
- `valueCategory` - If applicable, which value category this measures
- `attachmentType` - If applicable, "closeness" or "reassurance" for connection style

### JSON File Structure

Quiz questions with embedded metadata in `api/data/quizzes/` files:

```
{
  "id": "classic_047",
  "question": "After a long week, your ideal Saturday is...",
  "answers": ["Quiet day at home", "Brunch with friends"],
  "metadata": {
    "dimension": "social_energy",
    "poleMapping": ["left", "right"],
    "valueCategory": "social_life"
  }
}
```

Questions can have multiple tags (dimension + valueCategory) or none (general questions).

### Tagging Workflow

1. **Audit existing questions** - Review all Classic, Affirmation, You or Me JSON files
2. **Add metadata objects** - Add `metadata` field to questions that map to insights
3. **Identify gaps** - Find dimensions/languages with <3 tagged questions
4. **Create new questions** - Write questions to fill gaps, include metadata
5. **Validate JSON** - Ensure all files parse correctly after edits

### Minimum Question Requirements

| Data Point | Minimum Questions | Recommended |
|------------|-------------------|-------------|
| Each Dimension (4 total) | 3 | 5 |
| Each Love Language (5 total) | 2 | 4 |
| Each Value Category (6 total) | 3 | 5 |
| Connection Tendencies - closeness | 4 | 6 |
| Connection Tendencies - reassurance | 4 | 6 |

**Total tagged questions needed:** ~45-65 across all quiz files

---

## 13. Implementation Phases

### Test Data Reference

For all testing, use the reset script test couple:

| User | Email | User ID |
|------|-------|---------|
| Pertsa | test7001@dev.test | (check via Supabase or reset script output) |
| Kilu | test8001@dev.test | (check via Supabase or reset script output) |
| Couple ID | - | `22222222-2222-2222-2222-222222222222` |

Run `npx tsx scripts/reset_with_test_couple.ts` to reset test data before testing.

---

### Phase 1: Database Setup & Question Tagging

**Goal:** Create the 2 database tables and tag existing quiz questions.

**Database Tasks (2 tables only):**
- [ ] Create `us_profile_cache` table:
  - `couple_id` UUID PRIMARY KEY REFERENCES couples(id)
  - `user1_insights` JSONB NOT NULL DEFAULT '{}'
  - `user2_insights` JSONB NOT NULL DEFAULT '{}'
  - `couple_insights` JSONB NOT NULL DEFAULT '{}'
  - `updated_at` TIMESTAMP DEFAULT NOW()
- [ ] Create `conversation_starters` table:
  - `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
  - `couple_id` UUID REFERENCES couples(id)
  - `trigger_type` TEXT NOT NULL
  - `data` JSONB NOT NULL
  - `dismissed` BOOLEAN DEFAULT FALSE
  - `discussed` BOOLEAN DEFAULT FALSE
  - `created_at` TIMESTAMP DEFAULT NOW()
- [ ] Add index on `conversation_starters(couple_id, dismissed)`

**Question Tagging Tasks:**
- [ ] Audit existing quiz JSON files in `api/data/quizzes/`
- [ ] Add `metadata` object to questions that map to insights
- [ ] Tag ~50-70 questions total across all quiz files
- [ ] Validate all JSON files parse correctly after edits
- [ ] Document which questions map to which dimensions/languages

**Phase 1 Testing:**

Verify tables exist:
```bash
# Check us_profile_cache table created
curl -X GET "https://naqzdqdncdzxpxbdysgq.supabase.co/rest/v1/us_profile_cache?limit=1" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
# Should return empty array []

# Check conversation_starters table created
curl -X GET "https://naqzdqdncdzxpxbdysgq.supabase.co/rest/v1/conversation_starters?limit=1" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
# Should return empty array []
```

Verify JSON files updated (manual check):
- Open quiz JSON files, confirm `metadata` fields present
- Ensure each dimension has 3+ tagged questions
- Ensure each love language has 2+ tagged questions

---

### Phase 2: Profile Calculation Service

**Goal:** Build the service that calculates all insights and updates `us_profile_cache`.

**Calculation Service Tasks:**
- [ ] Create `api/lib/us-profile/calculator.ts` with:
  - Load all `quiz_matches` for couple
  - Load quiz JSON files to get question metadata
  - Calculate dimension scores for both users
  - Calculate love language scores for both users
  - Determine connection styles for both users
  - Calculate value alignments for couple
  - Detect discoveries (different answers)
  - Extract partner perception traits (from You or Me)
- [ ] Create `api/lib/us-profile/framing.ts` with:
  - Template-based discovery framing
  - Positive/neutral language for all insights
- [ ] Integrate calculator into quiz completion handlers:
  - After `quiz_matches` insert, call calculator
  - UPSERT result into `us_profile_cache`

**Data Flow:**
1. Quiz completes → `quiz_matches` row inserted
2. Call `calculateUsProfile(coupleId)`
3. Reads all `quiz_matches` for couple
4. Reads quiz JSON files for metadata
5. Calculates all scores
6. UPSERT single row to `us_profile_cache`

**Phase 2 Testing:**

Reset and have Pertsa/Kilu complete quizzes:
```bash
# Reset test data
cd api && npx tsx scripts/reset_with_test_couple.ts

# Have both users complete 3 quizzes via the app

# Verify us_profile_cache populated
curl -X GET "https://naqzdqdncdzxpxbdysgq.supabase.co/rest/v1/us_profile_cache?couple_id=eq.22222222-2222-2222-2222-222222222222" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
# Should return 1 row with user1_insights, user2_insights, couple_insights populated
```

---

### Phase 3: API Endpoints

**Goal:** Expose profile data via REST endpoints.

**API Endpoints to Create:**

| Endpoint | Method | Returns |
|----------|--------|---------|
| `/api/us-profile` | GET | Full profile from cache (single query) |
| `/api/us-profile/conversation-starters` | GET | Active starters for couple |
| `/api/us-profile/conversation-starters/:id/dismiss` | POST | Mark as dismissed |
| `/api/us-profile/conversation-starters/:id/discussed` | POST | Mark as discussed |

**Implementation Practices:**
- Main endpoint is single SELECT from `us_profile_cache`
- Return JSONB directly, Flutter parses the structure
- Include `updatedAt` for staleness indicator
- Starters endpoint filters: `dismissed = false`

**Response Structure for `/api/us-profile`:**
```
{
  "user": {
    "dimensions": { "social_energy": { "score": 65, "questionCount": 4 }, ... },
    "loveLanguages": { "quality_time": { "score": 85, "questionCount": 3 }, ... },
    "connectionStyle": { "style": "secure_expressive", "closeness": 4.2, "reassurance": 2.8 },
    "partnerPerceptionTraits": ["organized", "patient", "funny"]
  },
  "partner": { ... same structure ... },
  "couple": {
    "valueAlignments": { "honesty_trust": { "alignment": 80, "questionCount": 4 }, ... },
    "discoveries": [ { "question": "...", "userAnswer": "A", "partnerAnswer": "B", "framing": "...", "date": "..." } ],
    "questionsExplored": 47,
    "totalDiscoveries": 12
  },
  "updatedAt": "2025-12-29T10:00:00Z"
}
```

**Phase 3 Testing:**

```bash
# Test main profile endpoint
curl -X GET "https://api-joakim-achrens-projects.vercel.app/api/us-profile" \
  -H "Authorization: Bearer PERTSA_JWT_TOKEN"
# Expected: Full profile object with user, partner, couple sections

# Test conversation starters
curl -X GET "https://api-joakim-achrens-projects.vercel.app/api/us-profile/conversation-starters" \
  -H "Authorization: Bearer PERTSA_JWT_TOKEN"
# Expected: Array of starter objects (may be empty if nightly job hasn't run)

# Test dismiss action
curl -X POST "https://api-joakim-achrens-projects.vercel.app/api/us-profile/conversation-starters/STARTER_ID/dismiss" \
  -H "Authorization: Bearer PERTSA_JWT_TOKEN"
# Expected: { success: true }
```

---

### Phase 4: Flutter UI

**Goal:** Build the Us Profile screen with all visual sections.

---

#### CRITICAL: Follow HTML Mockups Exactly

**The HTML mockups are the source of truth for the Flutter UI implementation.**

| Mockup | Purpose | URL |
|--------|---------|-----|
| `variant-9-action-focused.html` | Mature profile (5+ quizzes) | [View on Vercel](https://us-profile-joakim-achrens-projects.vercel.app/variant-9-action-focused.html) |
| `variant-10-day1-experience.html` | Day 1 experience (1 quiz) | [View on Vercel](https://us-profile-joakim-achrens-projects.vercel.app/variant-10-day1-experience.html) |

**Implementation Rules:**

1. **100% Visual Fidelity** - The Flutter UI must match the HTML mockups pixel-for-pixel on mobile devices
2. **Use Exact Colors** - Copy hex values directly from CSS `:root` variables
3. **Use Exact Fonts** - Pacifico for logo, Playfair Display for headings, Nunito for body
4. **Use Exact Spacing** - Match padding, margins, border-radius values from CSS
5. **Use Exact Component Structure** - Card layouts, section ordering, badge positions must match

**Before Starting Flutter Development:**
1. Open mockup URL on your phone's browser
2. Screenshot each section
3. Use screenshots as direct reference while coding
4. Compare Flutter output to HTML side-by-side on same device

**CSS-to-Flutter Mapping Reference:**

| CSS Property | Flutter Equivalent |
|--------------|-------------------|
| `border-radius: 18px` | `BorderRadius.circular(18)` |
| `padding: 16px` | `EdgeInsets.all(16)` |
| `font-size: 13px` | `fontSize: 13` |
| `font-weight: 700` | `fontWeight: FontWeight.w700` |
| `linear-gradient(135deg, #FF6B6B, #FF9F43)` | `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)])` |
| `box-shadow: 0 2px 8px rgba(0,0,0,0.04)` | `BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black.withOpacity(0.04))` |

---

**Screen Structure:**
- [ ] Create `UsProfileScreen` in `lib/screens/`
- [ ] Create section widgets in `lib/widgets/us_profile/`:
  - `UsActionStats` - Action-focused stats (not journey stats)
  - `UsWeeklyFocus` - This week's focus card with gradient
  - `UsDimensionSliders` - Dual-marker sliders with 4 dimensions
  - `UsDiscoveries` - Discovery cards with prominent "Try This" actions
  - `UsValueAlignment` - Alignment bars with Financial/Family prioritized
  - `UsConnectionTendencies` - Tendencies (not attachment styles)
  - `UsPartnerPerception` - Trait tag chips
  - `UsConversationStarters` - Prompt cards with action buttons
  - `UsLockedSection` - Locked state for Love Languages, etc.

**UI Implementation Practices:**
- Use `UsProfileService` to fetch from single `/api/us-profile` endpoint
- Show loading skeleton while fetching
- Handle empty states per Section 14.11 recommendations (progressive reveal)
- Show confidence indicators (question count badges)
- Implement pull-to-refresh
- Cache profile data locally in Hive for offline viewing
- Show "Last updated" timestamp from `updatedAt`
- **Day 1 vs Mature UI:** Check quiz count to determine which sections to show

**Phase 4 Testing:**

Manual testing on device:
- [ ] Open Us Profile as Pertsa - verify all sections load
- [ ] Open Us Profile as Kilu - verify partner data matches Pertsa's view
- [ ] Pull to refresh - verify data updates
- [ ] Kill app, reopen offline - verify cached data displays
- [ ] Complete new quiz - return to profile, verify scores updated
- [ ] Dismiss conversation starter - verify it disappears
- [ ] Mark starter as discussed - verify state changes

---

### Phase 5: Integration & Polish

**Goal:** End-to-end testing and refinement.

**Integration Testing:**
- [ ] Fresh couple flow: New users → complete 5 quizzes → verify profile populates correctly
- [ ] Progressive reveal: Verify locked sections until thresholds met
- [ ] Score updates: Complete quiz → verify `us_profile_cache` updated immediately
- [ ] Both partners: Verify both see consistent data (same cache row)
- [ ] Edge cases: Zero quizzes, one partner only, very old answers

**Performance Checks:**
- [ ] Profile load time <200ms (single row SELECT)
- [ ] Score recalculation <500ms post-quiz
- [ ] Conversation starter generation <5s (nightly job)

**Final Testing with Pertsa/Kilu:**

```bash
# Reset test data
cd api && npx tsx scripts/reset_with_test_couple.ts

# 1. Have Pertsa complete 3 quizzes via app
# 2. Have Kilu complete same 3 quizzes via app

# Verify full profile exists (single endpoint)
curl -X GET "https://api-joakim-achrens-projects.vercel.app/api/us-profile" \
  -H "Authorization: Bearer PERTSA_JWT_TOKEN"
# Expected: Full profile with user.dimensions, partner.dimensions, couple.discoveries, etc.

# Verify cache row exists in database
curl -X GET "https://naqzdqdncdzxpxbdysgq.supabase.co/rest/v1/us_profile_cache?couple_id=eq.22222222-2222-2222-2222-222222222222" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
# Expected: 1 row with populated JSONB columns

# 3. Have both complete 5 more quizzes
# 4. Re-fetch profile, verify scores updated
# 5. Check UI on both devices matches API data
```

---

## Open Questions

1. **Attachment questions:** Should these be a dedicated mini-quiz during onboarding, or spread across regular quizzes?

2. **Love language test:** Full 15-question forced-choice test vs. scenario questions integrated into regular quizzes?

3. ~~**Update frequency:** Recalculate scores on every quiz completion, or batch nightly?~~ **DECIDED:** Recalculate full profile on every quiz completion. Single cache row makes this fast.

4. **Historical tracking:** Should we show how dimension scores change over time? (Could be interesting but adds complexity)

5. **Partner visibility:** Can Emma see James's full profile, or only shared/comparison views?

6. **Minimum data thresholds:** How many questions needed before showing a dimension? (Suggest: 3 minimum, show "Need more data" otherwise)

---

## Summary

| Section | Data Points | Source | New Questions Needed |
|---------|-------------|--------|---------------------|
| Action Stats | 3 (behavior-focused) | Action tracking | 0 |
| Dimensions | 4 sliders × 2 people | Tagged quiz questions | ~12-20 |
| Love Languages | 5 bars × 2 people | Scenario questions | ~10-15 |
| Connection Tendencies | 2 profiles | Closeness/reassurance questions | ~8-12 |
| Values | 6 categories (Financial/Family prioritized) | Tagged quiz questions | ~15-20 |
| Discoveries | Dynamic list with "Try This" actions | Different answers | 0 (derived) |
| Partner's Eyes | Trait tags (positive only) | You or Me answers | 0 (derived) |
| Conversation Starters | Dynamic list with action tracking | Generated from gaps | 0 (derived) |

**Total new questions to write:** ~45-65 tagged questions across quiz types.

**Key changes from original design:**
- Reduced dimensions from 6 to 4 (removed Decision Making, Change Tolerance)
- Action Stats tracks behavior change, not engagement metrics
- Discoveries include "Try This" suggestions
- Connection Tendencies replaces Attachment Styles (no fixed labels)
- Financial and Family values prioritized (⭐⭐⭐⭐⭐)

---

## 14. Hard Questions & Potential Pitfalls

This section addresses difficult challenges, ethical considerations, and things we might be overlooking. These need resolution before implementation.

### 14.1 Statistical Validity Concerns

**The Small Sample Problem**

| Issue | Risk | Mitigation Options |
|-------|------|---------------------|
| 3-5 questions per dimension is statistically weak | False confidence in measurements | Show confidence indicator: "Based on 3 questions" vs "Based on 12 questions" |
| No margin of error shown | Users trust numbers too much | Display ranges instead of points: "65-75%" not "70%" |
| Single data points treated as personality | Mood/context effects ignored | Weight recent answers, require minimum 5 questions before showing |

**Confidence Thresholds - Proposal:**

| Questions Answered | Display Behavior |
|--------------------|------------------|
| 0-2 | Don't show dimension, show "Need more data" |
| 3-4 | Show with "Early reading" badge, muted colors |
| 5-9 | Show normally with "Developing" indicator |
| 10+ | Show with full confidence |

**Decision needed:** Do we show uncertain data with caveats, or hide it until confident?

**RECOMMENDATION:** Show with caveats. Use the confidence threshold system above. Display "Based on X questions" under every metric. Use visual design (muted colors, dotted lines) to signal uncertainty. Users appreciate transparency more than hidden limitations. Consider a small "?" icon that explains "This will become more accurate as you explore more questions together."

---

### 14.2 Psychological Safety & Ethics

**Labeling Risks**

| Risk | Example | Mitigation |
|------|---------|------------|
| Self-fulfilling prophecy | "I'm labeled avoidant, so I act avoidant" | Avoid fixed labels; use "tendencies" language |
| Partner weaponization | "Your attachment style is why we fight" | Frame all insights as couple-level, not individual blame |
| Hierarchy creation | "Emma is more caring, patient, funny..." | Balance with mutual appreciation; show what each brings |
| Conflict triggering | Low alignment shown as failure | Never show "bad" scores; reframe as "opportunities" |

**Genuinely Incompatible Couples**

What if data reveals serious misalignment?
- 20% values alignment
- Opposite attachment styles
- Zero overlap in love languages

**Options:**
1. **Ignore it** - Only show positive framing regardless (dishonest?)
2. **Soft flag** - "You have different perspectives on X - great conversation opportunity!" (current approach)
3. **Private reflection** - Surface to each user individually, not shared view
4. **Professional referral** - For extreme cases, suggest couples counseling (scope creep?)

**Decision needed:** How honest should we be about incompatibility?

**RECOMMENDATION:** Use "soft flag" approach with a twist. Frame all differences as "exploration opportunities" but add subtle depth:
- Low alignment (20-40%): "You bring different perspectives to X - this is where you can learn the most from each other"
- Very low alignment (<20%): Still positive framing, but add "Consider having a deeper conversation about X"
- Never suggest professional help in-app (scope creep, liability)
- If a user explicitly asks "is this bad?", provide a thoughtful FAQ answer about how differences can strengthen relationships

For the "Through Partner's Eyes" feature specifically: Only show positive/neutral traits (e.g., "organized" not "controlling"). If partner's perception is consistently negative, don't surface it - this isn't the place for that feedback.

---

### 14.3 Social Desirability Bias

People don't answer truthfully - they answer how they want to be seen.

| Bias Type | Example | Detection/Mitigation |
|-----------|---------|----------------------|
| Impression management | Saying "I always communicate openly" when they don't | Use behavioral scenarios, not self-assessments |
| Partner pleasing | Answering what they think partner wants | Emphasize answers are private until both complete |
| Aspirational answers | Answering who they want to be, not who they are | Ask about past behavior, not future intentions |

**Better Question Framing:**

| Weak (Self-Report) | Better (Behavioral) |
|--------------------|---------------------|
| "I'm good at communicating" | "After an argument, you typically... wait a day / talk immediately" |
| "I value quality time" | "Last weekend, you spent most time... with partner / alone / with friends" |
| "I'm not jealous" | "When your partner mentions an attractive coworker, you feel... curious / uncomfortable / nothing" |

**Decision needed:** Rewrite questions as behavioral scenarios?

**RECOMMENDATION:** Yes, prefer behavioral scenarios for new questions. For existing questions, audit and reframe where possible without breaking historical data.

Best practices for question writing:
- Ask about specific past behavior, not general self-perception
- Use "Last time X happened, you..." not "You usually..."
- Provide concrete scenarios with clear choices
- Avoid absolutes ("always", "never")

Example rewrite:
- Before: "I'm a good listener"
- After: "When your partner vents about their day, you typically... (A) Listen quietly until they're done (B) Offer solutions right away (C) Share a similar experience of your own"

This reduces bias AND makes the quiz more engaging (scenarios are more fun than self-assessments).

---

### 14.4 Temporal Validity

**Staleness Problem**

| Factor | Impact | Consideration |
|--------|--------|---------------|
| People change | Answers from 6 months ago may not reflect today | Decay weight on old answers? |
| Mood effects | Bad day = pessimistic answers | Average across time, don't rely on single sessions |
| Relationship phases | Honeymoon answers differ from year-3 answers | Track trends, not absolutes? |
| Major life events | Baby/job loss/moving changes everything | Prompt "Has anything major changed?" periodically |

**Decay Weighting - Proposal:**

```
answer_weight = 1.0 if days_ago < 30
answer_weight = 0.8 if days_ago < 90
answer_weight = 0.6 if days_ago < 180
answer_weight = 0.4 if days_ago > 180
```

**Decision needed:** Implement decay? Or treat all answers equally?

**RECOMMENDATION:** Implement light decay for v1, with option to tune later:
- 0-30 days: 100% weight
- 31-90 days: 90% weight
- 91-180 days: 75% weight
- 180+ days: 60% weight

Don't decay too aggressively - we want enough data points for statistical validity. Show users when their profile was "last updated" (most recent quiz completion), so they understand data isn't stale.

For major life events: Add a "Life Update" feature where users can note "We moved", "Had a baby", "Changed jobs" - and optionally reset specific dimensions. This respects that people change while keeping it user-controlled.

---

### 14.5 The "So What" Problem

Biggest risk: Users see data but don't know what to do with it.

| Insight | Without Action | With Action |
|---------|----------------|-------------|
| "Your love language is Acts of Service" | Cool, I guess? | "Try doing one small task for Emma this week without being asked" |
| "You're 40% aligned on finances" | Is that bad? | "You see money differently. Here's a 10-min conversation guide" |
| "James needs space when stressed" | I knew that | "When you notice James is stressed, try saying: 'I'm here when you're ready'" |

**Actionable Insights Framework:**

Every insight should have:
1. **The data point** - What we measured
2. **What it means** - Plain English interpretation
3. **What to try** - Specific, small action
4. **Conversation starter** - Prompt to discuss together

**Example:**
> **Love Languages Gap Detected**
>
> Emma values Words of Affirmation highly (85%), while James scores lower (45%).
>
> **What this means:** Emma feels most loved when you express appreciation verbally. James may not naturally think to do this.
>
> **Try this week:** James, try telling Emma one specific thing you appreciate about her each day.
>
> **Talk about it:** "What compliments mean the most to you?"

**Decision needed:** Build action/recommendation engine, or just show data?

**RECOMMENDATION:** Absolutely build action/recommendation engine. This is the differentiator between "fun data visualization" and "actually helpful relationship tool."

Start simple with template-based actions:
1. Every insight card has a "Try This" section
2. Every dimension gap generates a conversation starter
3. Weekly email/notification: "Based on your profile, try X this week"

MVP action templates (hand-written, not AI-generated):
- Love language gap → "Try doing [specific example of partner's language]"
- Stress processing difference → "When [partner] seems stressed, remember they need [space/talking]"
- Value exploration → "You see [topic] differently. This week, share one story from your childhood about [topic]"

Future: LLM-generated personalized actions based on specific quiz answers, but curate quality carefully.

---

### 14.6 Validity of Frameworks

**Scientific Backing Concerns:**

| Framework | Scientific Status | Risk |
|-----------|------------------|------|
| Love Languages | Pop psychology, limited peer-reviewed research | Presenting as scientific when it's not |
| Attachment Theory | Clinical psychology, well-researched BUT our simplified version loses nuance | Misapplying clinical concepts |
| Personality Dimensions | Based on Big Five, but our questions aren't validated | Measuring something, but what? |

**Options:**
1. **Don't claim science** - Present as "fun insights" not psychological assessment
2. **Validate our questions** - Run studies to confirm our measurements correlate with established tests (expensive, slow)
3. **Use established tests** - License actual Love Languages quiz, attachment assessments (licensing costs, less fun)
4. **Cite sources carefully** - "Inspired by attachment theory" not "This IS your attachment style"

**Decision needed:** What's our epistemological stance? Fun vs. Scientific?

**RECOMMENDATION:** Position as "fun insights inspired by relationship research" - not clinical assessment.

Specific language guidelines:
- SAY: "Your answers suggest..." NOT "You are..."
- SAY: "Inspired by attachment research" NOT "Your attachment style is..."
- SAY: "Based on the 5 Love Languages concept" NOT "Scientifically validated"
- SAY: "Patterns we've noticed" NOT "Your personality profile"

In the app:
- Add a small info modal accessible from profile header: "How we create these insights"
- Explain: "These patterns are based on your quiz answers and concepts from relationship research. They're meant to spark conversation, not define you."
- Include: "Relationships are complex - these are starting points for understanding, not final answers."

This protects us legally, sets appropriate expectations, and actually makes the feature more trustworthy.

---

### 14.7 Cultural Sensitivity

**Western-Centric Biases:**

| Framework | Bias | Impact |
|-----------|------|--------|
| Love Languages | Assumes individual expression of love | Doesn't capture collective/family-oriented cultures |
| Attachment Theory | Developed in Western nuclear family context | May pathologize cultural differences |
| Independence vs Togetherness | Western bias toward independence as healthy | Interdependence isn't "anxious attachment" |
| Direct Communication | Western preference for directness | Indirect communication isn't "avoidant" |

**Mitigation Options:**
1. Add cultural context questions: "In your family growing up, love was typically shown by..."
2. Avoid value judgments on any style
3. Beta test with diverse couples
4. Consult cultural psychology literature

**Decision needed:** Scope for v1, or address in initial release?

**RECOMMENDATION:** Address in v1 through neutral framing, not cultural customization.

For v1:
- Remove all value judgments from dimension labels (no "healthy" vs "unhealthy")
- Frame EVERY style as having strengths: "Independence-valuing partners bring X; connection-seeking partners bring Y"
- Avoid Western-centric defaults in questions (not everyone has nuclear family, not everyone values individual independence)
- Review questions for assumptions: "When visiting your parents..." assumes parents are alive and accessible

Future consideration:
- Add optional "cultural background" question that adjusts framing
- Research partnerships with diverse relationship counselors
- Beta test with non-Western couples before major marketing in new regions

The key principle: No style is better. Every answer is valid. We're mapping differences, not grading.

---

### 14.8 Privacy & Consent

**Data Visibility Questions:**

| Data Point | Current Assumption | Concern |
|------------|-------------------|---------|
| "How partner sees you" | Both can see | Does James consent to Emma knowing how he rated her? |
| Individual dimension scores | Shared view | Should Emma see James's score before he's seen it himself? |
| Discoveries | Shared | What if one partner doesn't want their answer visible? |
| Conversation starters | Shared | Could reveal sensitive differences |

**Consent Model Options:**

1. **Fully shared** - Everything visible to both (current assumption)
2. **See-your-own-first** - You see your data, then shared view unlocks
3. **Opt-in sharing** - Each insight requires both to agree to share
4. **Anonymized comparison** - "One of you values X, the other Y" without naming

**Breakup Considerations:**
- What happens to couple data when relationship ends?
- Can one partner delete shared history?
- New partner inherits old comparison data?

**Decision needed:** Privacy model for sensitive insights?

**RECOMMENDATION:** Use "See-your-own-first, then shared" model.

Implementation:
1. **Personal insights** (your scores) - You see first, always accessible in a "My View" tab
2. **Partner perception** ("How James sees you") - Both see simultaneously when quiz completes
3. **Comparison views** (sliders with both markers) - Available after both have seen individual results
4. **Discoveries** - Appear for both when both have answered (no opt-out needed, framing is positive)

Privacy controls to add:
- Toggle: "Share my dimension scores with [partner]" (default: on)
- Option to hide specific dimensions: "I'd rather not share my stress processing pattern"
- Clear data: "Reset my profile data" (couple-level reset requires both to agree)

Breakup handling:
- On unpair: All couple-level data (discoveries, alignment) deleted immediately
- Individual data (your dimension scores) stays with you for new relationship
- Option to "Start fresh" - delete everything

This respects autonomy while defaulting to the openness that makes the feature valuable.

---

### 14.9 Engagement vs Accuracy Trade-off

**The Gamification Dilemma:**

| Priority | Approach | Risk |
|----------|----------|------|
| Engagement | Fun questions, badges, progress bars | Undermines psychological validity |
| Accuracy | Clinical-style assessments | Boring, low completion |
| Both | Validated questions disguised as fun | Harder to design |

**Gaming Risks:**
- Users discuss answers before taking quiz
- Users answer to get desired profile
- Users learn which answers map to which labels

**Detection Options:**
- Consistency checks across similar questions
- Time-based anomalies (too fast = not reading)
- Pattern detection for "perfect" profiles

**Decision needed:** How seriously do we take gaming? Ignore, detect, or design against?

**RECOMMENDATION:** Design against gaming through question design; don't build detection systems.

Why detection is overkill:
- Gaming is rare in couple apps (unlike dating apps)
- Partners gaming together isn't really a problem - they're engaging
- Detection systems add complexity and can feel surveillance-y

Design strategies instead:
1. **No "right" answers** - Every option maps to a valid style, not "good" vs "bad"
2. **Behavioral scenarios** - Harder to game than self-assessments ("What did you do?" vs "Are you kind?")
3. **Distributed questions** - Same dimension measured across many quizzes over time
4. **Varied framing** - Ask same concept different ways to triangulate

One simple check to implement:
- If completion time < 3 seconds per question, show gentle prompt: "Take your time - thoughtful answers make better insights"

The goal is self-discovery, not testing. If someone wants to present a certain image, that itself is data about who they want to be.

---

### 14.10 What We're NOT Measuring

**Intentionally Omitted (Sensitive):**
- Sexual compatibility
- Attraction levels
- Fidelity/trust issues
- Abuse indicators

**Possibly Missing (Oversight):**
| Missing Dimension | Why It Matters |
|-------------------|----------------|
| Conflict resolution style | Predicts relationship success better than compatibility |
| Repair attempts | How they reconnect after fights |
| Appreciation expression | Gottman's research: 5:1 positive to negative ratio |
| Shared meaning | Rituals, goals, narratives |
| Life goals alignment | Kids, career, location |
| Extended family dynamics | In-laws, family involvement |
| Division of labor satisfaction | Household/emotional labor |
| Relationship satisfaction | Are they actually happy? |

**Gottman Research Considerations:**

John Gottman's research identifies predictors of divorce:
1. Criticism (vs complaints)
2. Contempt
3. Defensiveness
4. Stonewalling

**Should we measure these?** Could be valuable but risks:
- Surfacing problems couples aren't ready to face
- Requires clinical expertise to handle well
- Scope creep into therapy territory

**Decision needed:** Expand dimensions, or stay in "fun insights" lane?

**RECOMMENDATION:** Stay in "fun insights" lane for v1. Explicitly avoid relationship health assessment.

What we SHOULD add (missing but safe):
- **Appreciation frequency** - "How often do you express gratitude to your partner?" (positive focus)
- **Shared rituals** - "Do you have weekly routines you do together?" (builds connection)
- **Future dreams alignment** - "Where do you see yourselves in 5 years?" (forward-looking)

What we should NOT touch:
- Conflict patterns (Gottman "Four Horsemen") - too clinical, requires expertise to interpret
- Relationship satisfaction scores - dangerous to surface, could become self-fulfilling
- Trust/fidelity indicators - not our lane, too sensitive

The bright line: We help couples understand each other better. We don't diagnose relationship health.

If users want deeper assessment, we can eventually partner with/recommend actual relationship counseling services - but that's a business development discussion, not a product feature.

---

### 14.11 Cold Start Problem & Progressive Value Timeline

**Core Principle:** Users should see actionable value after their FIRST quiz, not after 10+ quizzes.

**The Key Insight:** Show discoveries and actions immediately - not empty charts waiting for data.

**Progressive Value Timeline:**

| After | What They See | Why It Works |
|-------|--------------|--------------|
| **1 quiz** | First discovery + "Try This" action + 1 conversation starter + Action Stats | Immediate value, even with minimal data |
| **3 quizzes** | 1-2 dimension early readings + multiple discoveries + partner perception (if You or Me played) | Profile feels "alive" |
| **5-7 quizzes** | Most dimensions unlocked + value alignments emerging + Love Languages unlocked | Profile feels substantive |
| **10+ quizzes** | Full profile with solid confidence indicators | Deep insights with high accuracy |

**What's Available Immediately (After Quiz 1):**

Even one completed quiz can produce:
- A discovery (if any answer differed between partners)
- A "Try This" suggestion based on that discovery
- A conversation starter generated from the difference
- Action Stats showing "1 insight to act on"

This is better than showing 6 empty dimension sliders with "Need more data."

**Page Structure for Day 1 Success:**

The Us Profile page is structured so the **top section is always valuable**:

1. **Action Stats** (always visible) - Shows "0 insights acted on" day 1, but that's a goal, not emptiness
2. **This Week's Focus** (after 1 discovery) - Generate immediately from first difference found
3. **Recent Discoveries** (after 1 quiz) - Appear as soon as answers differ
4. **Dimensions** (after 3+ questions each) - Progressive unlock with "early reading" indicators
5. **Values** (after 3+ questions per category) - Show as "Exploring..." until threshold
6. **Love Languages** (after 6+ love language questions) - Locked until dedicated questions answered
7. **Connection Tendencies** (after 8+ attachment questions) - Requires specific questions

**Section Unlock Conditions:**

| Section | Unlock Condition | Before Unlock |
|---------|------------------|---------------|
| Action Stats | Always visible | Shows zeros with motivating copy |
| This Week's Focus | 1+ discovery exists | "Complete your first quiz to get your focus" |
| Recent Discoveries | 1+ completed quiz with different answers | "Your first discovery is waiting!" |
| Through Partner's Eyes | 1+ You or Me quiz completed | "Play 'You or Me' to see how [partner] sees you" |
| Dimension Sliders | 3+ questions per dimension | Show locked with "Answer X more to unlock" |
| Love Languages | 6+ love language tagged questions | Locked card with progress bar |
| Values Alignment | 3+ questions per category | Show category as "Exploring..." |
| Connection Tendencies | 8+ attachment questions | Locked until threshold met |

**Key UX Principles:**

1. **Top of page is always valuable** - Never scroll past empty content to find something useful
2. **Actions over data** - "Try This" suggestions matter more than charts
3. **Celebrate unlocks** - "New insight unlocked!" notification when sections become available
4. **Show progress clearly** - "2 more questions to unlock Planning Style"
5. **Early readings are OK** - Show data with confidence indicators rather than hiding it

---

### 14.12 Algorithm Versioning

**When We Change Calculations:**

| Scenario | Problem |
|----------|---------|
| Add new questions | Old scores based on fewer questions |
| Change dimension mapping | Scores shift without new answers |
| Fix calculation bug | Historical comparisons invalid |
| Remove question | Scores recalculated, may change |

**Versioning Options:**
1. **Recalculate everything** - Current = truth, history changes
2. **Snapshot scores** - Store calculated scores, don't recalculate
3. **Version tracking** - "Score v1.2" with migration path
4. **Transparent changelog** - "Your scores updated based on improved algorithm"

**Decision needed:** How do we handle algorithm changes?

**RECOMMENDATION:** Recalculate on change with transparent changelog, but minimize visible disruption.

Implementation:
1. **Store raw answers, not calculated scores** - Always recalculate from source data
2. **Version the algorithm** - Track which version calculated each score
3. **Silent recalculation** - When algorithm changes, recalculate all couples overnight
4. **Notify only on significant change** - If score moves >15 points, show: "Your insights have been updated based on improved analysis"
5. **Changelog in settings** - Technical users can see: "v1.2: Improved love language detection based on new research"

What NOT to do:
- Show "Your score changed from 65% to 72%!" - Creates anxiety
- Keep old scores alongside new - Confuses users
- Require user action to "update" - Adds friction

Principle: The current view is always the best view. Users shouldn't think about versions.

Migration testing: Before any algorithm change, run both old and new on sample data. If >20% of users would see significant changes, reconsider the change or phase it in gradually.

---

### 14.13 Comparison Anxiety

**Benchmark Risks:**

| Feature | Risk |
|---------|------|
| "Average couple is 75% aligned" | Creates anxiety if below |
| Percentile rankings | Competitive mindset |
| Progress over time | Pressure to "improve" |
| Partner comparison | "You're less engaged than Emma" |

**Mitigation:**
- Never show external benchmarks
- Never compare to other couples
- Never rank partners against each other
- Only show personal growth, not relative position

**Decision needed:** Strict no-benchmarks policy, or helpful context?

**RECOMMENDATION:** Strict no-benchmarks policy. Never compare to other couples.

Why this matters:
- "You're in the 40th percentile for communication" creates anxiety
- Couples will fixate on "below average" scores
- Every relationship is unique - comparison is meaningless
- We don't have validated benchmarks anyway

What we show instead:
- **Personal growth**: "You've explored 15 more questions this month"
- **Depth of exploration**: "You've discovered 23 things about each other"
- **Consistency**: "You've connected 12 days in a row"

What we never show:
- Percentile rankings
- "Average couple" comparisons
- Partner-vs-partner rankings ("Emma engages more")
- Score improvement pressure ("Increase your alignment!")

One exception to consider: If we had solid research showing "couples who explore X questions have better outcomes," we could show progress toward that as a goal - but framed as "journey" not "grade."

For v1: No benchmarks, no exceptions. Revisit when/if we have real outcome data.

---

### 14.14 Summary: Decisions Needed

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | Confidence display | Hide uncertain data vs show with caveats | Show with clear "early reading" indicator |
| 2 | Incompatibility handling | Ignore vs soft flag vs professional referral | Soft flag as "exploration opportunity" |
| 3 | Question style | Self-report vs behavioral scenarios | Behavioral scenarios preferred |
| 4 | Answer decay | Equal weight vs time decay | Light decay (0.8 after 90 days) |
| 5 | Actionable insights | Data only vs recommendations | Include specific actions |
| 6 | Scientific claims | Fun insights vs psychological assessment | "Inspired by research" not clinical claims |
| 7 | Cultural adaptation | Western default vs culturally aware | Avoid value judgments, neutral framing |
| 8 | Privacy model | Fully shared vs consent-based | See-your-own-first, then shared |
| 9 | Gaming prevention | Ignore vs detect | Basic consistency checks |
| 10 | Scope | Fun only vs relationship health | Stay in "fun insights" for v1 |
| 11 | Cold start | Empty state vs progressive reveal | Progressive reveal |
| 12 | Algorithm changes | Recalculate vs snapshot | Recalculate with transparent changelog |
| 13 | Benchmarks | No comparison vs helpful context | No external benchmarks, ever |

---

## 15. Recommended Principles

Based on the hard questions above, here are guiding principles for implementation:

### 15.1 Epistemological Humility
- Never claim scientific accuracy we can't deliver
- Use language like "tendency," "pattern," "suggestion" not "you ARE"
- Show uncertainty: "Based on 4 questions"
- Avoid fixed labels that become identity

### 15.2 Relationship-First Framing
- Every insight framed as couple-level, not individual judgment
- Differences are "discoveries" not "problems"
- No winner/loser dynamics
- Both partners bring value

### 15.3 Action-Oriented Output
- Every data point links to a suggested action
- Conversation starters are specific and low-stakes
- Weekly "try this" prompts based on insights
- Progress = depth of exploration, not score improvement

### 15.4 Psychological Safety
- Negative patterns surfaced gently, if at all
- No comparison to other couples
- No ranking partners
- Option to hide/dismiss any insight

### 15.5 Progressive Trust
- Start with fun, low-stakes insights
- Deeper insights unlock with engagement
- User controls what's shared
- Easy to reset/start fresh

### 15.6 Cultural Respect
- No style is "better" or "healthier"
- Acknowledge frameworks have limitations
- Leave room for "this doesn't fit me"
- Feedback mechanism to improve
