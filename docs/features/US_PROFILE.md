# Us Profile

## Overview

The Us Profile is a relationship insights dashboard that aggregates data from completed quizzes to help couples understand each other better. Key sections:

- **Dimensions** - Where partners fall on key relationship spectrums
- **Worth Discussing** - Discoveries ranked by importance with appreciation system
- **Values Alignment** - Shared values with agreement percentages
- **Partner Perception** - How each partner sees the other (from You or Me answers)
- **Conversation Starters** - Guided discussion prompts

Accessed via entry card on Profile screen, creating an intentional "reflection moment."

---

## Quick Reference

| Item | Location |
|------|----------|
| Us Profile Screen | `lib/screens/us_profile_screen.dart` |
| Us Profile Service | `lib/services/us_profile_service.dart` |
| Worth Discussing Card | `lib/widgets/worth_discussing_card.dart` |
| Profile Entry Card | `lib/screens/profile_screen.dart` (line ~180) |
| API Endpoint | `api/app/api/us-profile/route.ts` |
| Discovery Framing | `api/lib/us-profile/framing.ts` |
| Design Reference | `mockups/us-profile-therapeutic/worth-discussing-v4.html` |
| Test Script | `api/scripts/reset_two_test_couples.ts` |
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
      ├── Worth Discussing Section (ranked discoveries with appreciation)
      ├── Values Section (alignment percentages)
      ├── Partner Perception (trait tags + Growth Edge)
      ├── Conversation Starters (with timing badges)
      └── Growth Milestones (timeline)
```

---

## Data Model

### UsProfile
```dart
class UsProfile {
  final ProfileHeader header;
  final List<Dimension> dimensions;
  final DiscoverySection discoveries;         // Ranked discoveries with context
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
| `DiscoverySection` | Container with `featured`, `others`, `totalCount`, `contextLabel` |
| `FramedDiscovery` | Insight with stakes level, relevance score, appreciation state, conversation prompt |
| `DiscoveryAppreciation` | Tracks `userAppreciated`, `partnerAppreciated`, `mutualAppreciation` |
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

## Dimension Definitions

Dimensions are personality spectrums calculated from quiz answers. Each question with `metadata.dimension` and `metadata.poleMapping` contributes to positioning users on these spectrums.

**Code location:** `api/lib/us-profile/calculator.ts`

### Active Dimensions

| Dimension ID | Label | Left Pole | Right Pole |
|--------------|-------|-----------|------------|
| `social_energy` | Social Energy | Recharge Alone | Energized by People |
| `stress_processing` | How You Process Stress | Internal Processor | External Processor |
| `planning_style` | Planning Style | Spontaneous | Structured |
| `conflict_approach` | Conflict Approach | Space First | Talk It Out |

### Planned Dimensions (to be added)

| Dimension ID | Label | Left Pole | Right Pole | Source Quiz |
|--------------|-------|-----------|------------|-------------|
| `risk_adventure` | Risk & Adventure | Play It Safe | Thrill Seeker | playful/quiz_002, quiz_011 |
| `novelty_preference` | Novelty Preference | Comfort & Familiar | New & Discovery | playful/quiz_004, quiz_013, quiz_020 |
| `support_style` | Support Style | Listen First | Give Solutions | playful/quiz_007, quiz_009 |
| `daily_rhythm` | Daily Rhythm | Night Owl | Early Bird | playful/quiz_015 |

### How Pole Mapping Works

In quiz JSON files:
```json
{
  "metadata": {
    "dimension": "social_energy",
    "poleMapping": ["right", "left", null, null, null]
  }
}
```

- Array index = choice index (0-4)
- `"left"` = contributes to left pole
- `"right"` = contributes to right pole
- `null` = doesn't contribute to this dimension

User's position on each dimension is calculated as: `(rightCount - leftCount) / totalAnswers`

### Dimension Questions vs Preference Discovery

Not all quiz questions have dimension metadata. Questions serve two purposes:

| Type | Has Metadata? | Purpose |
|------|---------------|---------|
| **Dimension Questions** | Yes | Position users on personality spectrums (e.g., introvert ↔ extrovert) |
| **Preference Discovery** | No | Surface differences in tastes/preferences that spark conversation |

**Preference Discovery questions** (no metadata) still create "Worth Discussing" discoveries when partners answer differently, but don't contribute to dimension scoring. These are ideal for:
- Lifestyle preferences (home decor, social media, gift styles)
- Taste differences (entertainment, food, aesthetics)
- Topics without a clear spectrum (no "right" or "left" pole)

Example preference discovery question (playful/quiz_005):
```json
{
  "text": "The gifts that mean the most to me are...",
  "choices": [
    "Handmade or personalized - showing thought and effort",
    "Surprises - something unexpected",
    "Practical things I actually need",
    "Experiences we can enjoy together"
  ],
  "category": "preferences"
  // No metadata - pure preference discovery
}
```

This creates interesting discoveries without forcing answers onto a spectrum.

---

## UI Sections

### 1. Header
- Couple avatars with gradient border
- Names and journey day count ("Day 30 of your journey")
- Stat pills: quizzes completed, discoveries found

### 2. Dimensions Section
Each dimension shows:
- Title and info button (expandable description)
- Spectrum track with partner position dots (Emma = pink, James = blue)
- Position labels (e.g., "Internal" ← → "External")
- **Repair Scripts** (expandable) for dimensions marked "different":
  - Recognition prompt
  - Partner-specific repair scripts
  - De-escalation tip

### 3. Worth Discussing Section
- Contextual header from API (e.g., "Here are 5 moments that stood out...")
- No filter tabs — users scroll through the full list
- Discovery cards display:
  - Category label (uppercase, top-left)
  - **Question text** (provides context for answers)
  - Partner answers as `Name: answer` on separate lines
  - Conversation prompt (italic, gold left-border)
  - Appreciation button with partner/mutual indicators
- Ordered by: stakes level → appreciation state → recency

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

### 7. Growth Milestones
- Timeline of relationship milestones
- Completed items with dates
- Pending items as goals

---

## How Worth Discussing Works

The "Worth Discussing" section surfaces moments where partners answered quiz questions differently, ranked by relevance to help couples focus on what matters most.

### Source of Discovery Content

Discoveries are generated from **completed quiz answers** across all quiz types:

| Quiz Type | Example Question | Answer Choices |
|-----------|------------------|----------------|
| Classic Quiz | "What type of affection makes me feel most connected?" | Holding hands, Hearing 'I love you', Thoughtful surprises, etc. |
| Affirmation | "Hearing 'I love you' regularly is important to me" | Strongly Agree → Strongly Disagree scale |
| You or Me | "Who says 'I love you' more?" | Partner / Self |

When partners select **different answers** to the same question, a discovery is created showing what each person chose.

### Content Variety

Quiz content is organized by branches (lighthearted, playful, connection, attachment, growth) with multiple quizzes per branch, each containing 5 questions. Couples encounter fresh questions for months of daily play.

### Relevance Ranking

Discoveries are sorted by a relevance score calculated from:

1. **Stakes Level** (highest priority)
   - High stakes: +100 points (finances, family planning, intimacy, career)
   - Medium stakes: +50 points (communication, conflict, routines)
   - Light stakes: +10 points (food, hobbies, entertainment)

2. **Appreciation State** (encourages engagement)
   - Partner appreciated but user hasn't: +30 points
   - User appreciated but partner hasn't: +10 points
   - Mutual appreciation: +5 points (settled, less urgent)

3. **Recency** (tiebreaker)
   - Newer discoveries rank higher among same relevance

### Discovery Card Format

Each discovery card displays:
1. **Question text** — The original question (provides context)
2. **Partner answers** — Each answer on its own line (`Name: answer`)
3. **Conversation prompt** — Category-aware insight to spark discussion
4. **Appreciation button** — Toggle to signal importance to partner

**Conversation prompts** are category-specific and deterministic (same discovery → same prompt). Examples:
- Finances: *"Different approaches to money can complement each other — or create tension."*
- Stress: *"When stressed, you have different needs. Understanding that can help you support each other."*

### Appreciation System

Users can "appreciate" discoveries to:
- Signal to their partner that this topic matters to them
- Help the system surface discoveries the partner should see
- Track which discoveries have been acknowledged by both

**Appreciation states:**
| State | Display |
|-------|---------|
| Neither appreciated | "Appreciate" button (outline) |
| User appreciated | "Appreciated" button (filled pink) |
| Partner appreciated (not user) | "♥ Emma appreciates this" indicator + button |
| Both appreciated | "You both appreciate this" badge |

### Categories and Stakes Levels

Discoveries are tagged by category and stakes level:

**Categories:**
- finances, family_planning, career, intimacy, living_location, in_laws (high stakes)
- communication, conflict, stress, emotional_support, trust, social (medium stakes)
- lifestyle, food, entertainment, hobbies, travel, aesthetics, leisure (light stakes)

**Stakes Levels:**
- **High** — Fundamental life decisions that require deep understanding
- **Medium** — Daily dynamics that affect relationship quality
- **Light** — Preference differences that are interesting but not critical

### Example Test Couples

Two test couples are available via `api/scripts/reset_two_test_couples.ts`:

#### Couple 1: Pertsa & Kilu (Aligned Soulmates)

| Attribute | Value |
|-----------|-------|
| Emails | test7001@dev.test / test8001@dev.test |
| Discoveries | 8 (minor lifestyle differences) |
| Match Rate | ~90% |
| Use Case | Testing aligned couple experience |

**Sample discoveries (all light stakes):**
- Lazy Sunday: "Reading together in silence" vs "Watching a movie together"
- Appreciation: "Verbal acknowledgment" vs "Small thoughtful gestures"
- Vacation style: "Beach relaxation" vs "Cultural exploration"

**Profile characteristics:**
- Low discovery count indicates strong alignment
- Differences are minor preferences, not fundamental values
- Dimension spectrums show them close together on most dimensions
- More value alignment badges and fewer repair script prompts

---

#### Couple 2: Bob & Alice (Opposites Attract)

| Attribute | Value |
|-----------|-------|
| Emails | test7002@dev.test / test8002@dev.test |
| Discoveries | 25 (8 high, 10 medium, 7 light stakes) |
| Match Rate | ~20% |
| Use Case | Testing discovery ranking, stakes categorization |

**Sample high-stakes discoveries:**
- Children: "Definitely want kids in the next few years" vs "Still figuring out if parenthood is for me"
- Finances: "Cut back on everything equally" vs "Prioritize what matters, cut the rest completely"
- Career: "Career comes first in these years" vs "Family time is non-negotiable"
- Living: "City center, close to everything" vs "Quiet suburbs with nature"

**Sample medium-stakes discoveries:**
- Stress: "Being alone with my thoughts" vs "Talking to someone about it"
- Conflict: "Time alone to process" vs "To talk it through immediately"
- Weekends: "Quiet time at home" vs "Going out with friends"

**Profile characteristics:**
- High discovery count indicates many differences to explore
- Discoveries span social energy, planning style, conflict approach
- High-stakes discoveries surface first due to relevance ranking
- Dimension spectrums show them on opposite ends for several dimensions

---

#### Comparison Summary

| Couple | Discoveries | Stakes Breakdown | Primary Themes |
|--------|-------------|------------------|----------------|
| Pertsa & Kilu | 8 | All light | Minor preferences, affection styles |
| Bob & Alice | 25 | 8 high, 10 medium, 7 light | Life goals, conflict, social energy |

This demonstrates how the "Worth Discussing" section adapts to each couple's dynamic, surfacing high-stakes topics first for couples with fundamental differences while showing lighter fare for well-aligned couples.

---

## Therapeutic Enhancements

Key therapeutic features:

| Feature | Purpose |
|---------|---------|
| Repair Scripts | Help when dimension differences cause friction |
| Stakes-Based Ranking | High-stakes discoveries (finances, family) surface first |
| Appreciation System | Partners signal which topics matter to them |
| Category-Aware Prompts | Insightful prompts tailored to topic type |
| Growth Edge | Reveal perception gaps with curiosity framing |
| Timing Badges | Suggest when to discuss (relaxed moment, dedicated time, etc.) |

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

Colors (from `us2_theme.dart`):

| Element | Color |
|---------|-------|
| User 1 (pink) | #FF6B6B |
| User 2 (blue) | #4A8BC9 |
| Accent gold | #F4C55B |
| Accent purple | #7C4DFF |
| High-stakes border | #FFB8A8 |

Typography: Playfair Display (headings), Nunito (body)

---

## Edge Cases & Gotchas

1. **Empty State** — Show encouraging message when no quiz data exists
2. **Locked Dimensions** — Show lock icon and progress for dimensions not yet unlocked
3. **Growth Edge Framing** — Must be curiosity-inducing, never critical:
   - ✅ "Your partner notices something you might not..."
   - ❌ "Your partner thinks you're wrong about yourself"
4. **Content Hash** — For new-content detection, includes dimensions, discoveries, values, milestones (NOT conversation starters)

---

## Future Improvements

- **Mutual Appreciation Celebrations** — Celebrate when both partners appreciate same discovery
- **Discussion Tracking** — Mark discoveries as "discussed"
- **Stuck Pattern Detection** — Surface help when couples repeatedly struggle on same topic
- **Journal Integration** — Connect discoveries to Journal for tracking conversations

---

## Related Documentation

- [Therapeutic Enhancements Plan](../plans/US_PROFILE_THERAPEUTIC_ENHANCEMENTS.md)
- [Long-Term Value Requirements](../plans/LONG_TERM_VALUE_REQUIREMENTS.md)
- [Quiz Match System](./QUIZ_MATCH.md)
- [You or Me Game](./YOU_OR_ME.md)

---

*Last Updated: January 3, 2026 — Removed Actions section, added question text display to discoveries, streamlined documentation*
