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

## How Recent Discoveries Work

The "Recent Discoveries" section surfaces moments where partners answered quiz questions differently, revealing interesting differences in perspectives, preferences, or approaches.

### Source of Discovery Content

Discoveries are generated from **completed quiz answers** across all quiz types:

| Quiz Type | Example Question | Answer Choices |
|-----------|------------------|----------------|
| Classic Quiz | "What type of affection makes me feel most connected?" | Holding hands, Hearing 'I love you', Thoughtful surprises, etc. |
| Affirmation | "Hearing 'I love you' regularly is important to me" | Strongly Agree → Strongly Disagree scale |
| You or Me | "Who says 'I love you' more?" | Partner / Self |

When partners select **different answers** to the same question, a discovery is created showing what each person chose.

### Content Variety

The quiz content library provides substantial variety:

- **5 quiz branches** per type: lighthearted, playful, connection, attachment, growth
- **~12 quizzes per branch** with 5 questions each
- **~900 total unique questions** across all quiz types
- **4-5 answer choices** per question

This means couples will encounter fresh questions for months of daily play.

### Discovery Display Format

Each discovery card shows:
- The original question text
- Each partner's answer (using their names)
- A category tag (emotional, communication, values, etc.)
- A "Try This" action suggestion based on the category
- Timing guidance for when to discuss

Example:
> **Question:** "What type of affection makes me feel most connected?"
> - **Emma:** Hearing 'I love you' and compliments
> - **James:** Quality time together
>
> *Try This: Have a 10-minute conversation about this difference tonight*

### Refresh Rate

With the standard 3 quizzes per day (Classic, Affirmation, You or Me):
- **15 questions answered daily** (5 per quiz)
- **~7-8 new discoveries per day** (assuming ~50% different answers)
- **10 most recent shown** in the Recent Discoveries section

The section refreshes with new content after each completed quiz where partners had different answers. Couples doing all daily quests will see fresh discoveries regularly.

### Categories and Stakes Levels

Discoveries are tagged by category and stakes level:

**Categories:**
- Emotional, Communication, Values, Lifestyle, Future, Family, Daily Life

**Stakes Levels:**
- **Light** (food, hobbies) → Simple action suggestion
- **Medium** (routines, social) → Action + timing suggestion
- **High** (finances, family planning, intimacy) → Extended guidance + professional help prompt

High-stakes discoveries receive special treatment with multi-step conversation guides rather than quick action suggestions.

### Example Couples

These examples illustrate how discoveries manifest differently based on couple dynamics.

#### Couple A: "The Opposites Attract"
**Maya (extrovert, spontaneous) & David (introvert, planner)**

After 12 quizzes, they have **28 discoveries** (high difference rate ~58%). Their Recent Discoveries:

| Question | Maya | David |
|----------|------|-------|
| How do you prefer to unwind after a stressful day? | Going out with friends | Quiet time alone |
| What's your ideal weekend morning? | Spontaneous brunch plans | Structured routine at home |
| When facing a big decision... | Go with my gut feeling | Research all options first |
| At a party, I typically... | Work the room, meet everyone | Find one good conversation |
| When stressed, I need... | To talk it through immediately | Space to process alone |
| Planning a vacation means... | Book flights, figure out the rest later | Detailed itinerary in advance |
| How do you show you care? | Quality time together | Acts of service |
| After an argument, I prefer to... | Talk it out right away | Cool down first, then discuss |
| My ideal date night is... | Trying a new restaurant or bar | Cooking together at home |
| When something's bothering me... | I bring it up immediately | I think about it first |

**Profile characteristics:**
- High discovery count indicates many differences to explore
- Discoveries span social energy, planning style, conflict approach
- Try This suggestions focus on compromise and respecting different needs
- Dimension spectrums would show them on opposite ends for several dimensions

---

#### Couple B: "The Aligned Soulmates"
**Priya & Amir (both homebodies, similar values)**

After 12 quizzes, they have **9 discoveries** (low difference rate ~19%). Their Recent Discoveries:

| Question | Priya | Amir |
|----------|-------|------|
| What type of affection makes you feel most connected? | Hearing 'I love you' and compliments | Holding hands or cuddling |
| When celebrating good news... | Call my family first | Celebrate with just us first |
| My favorite way to spend a lazy Sunday... | Reading together in silence | Watching a movie together |
| What makes me feel most appreciated? | When you notice small things I do | When you thank me publicly |
| How do I prefer to receive encouragement? | Verbal praise and affirmation | You believing in me even when I doubt myself |
| When one of us is sick... | I want to be taken care of | I prefer to be left alone to rest |
| Our home should feel... | Cozy and warm | Clean and organized |
| How do you like to handle finances? | Save first, spend what's left | Budget but allow for treats |
| When meeting new people... | I'm friendly but reserved | I warm up slowly |

**Profile characteristics:**
- Low discovery count indicates strong alignment
- Differences are minor preferences, not fundamental values
- Try This suggestions focus on small adjustments and love language nuances
- Dimension spectrums would show them close together on most dimensions
- More value alignment badges and fewer repair script prompts

---

#### Comparison Summary

| Couple | Discoveries (12 quizzes) | Difference Rate | Primary Themes | Stakes Level |
|--------|-------------------------|-----------------|----------------|--------------|
| Maya & David | 28 | ~58% | Social energy, planning, conflict | Medium |
| Priya & Amir | 9 | ~19% | Minor preferences, affection styles | Light |

This demonstrates how the Us Profile adapts to each couple's unique dynamic, providing relevant insights whether they're navigating many differences or fine-tuning an already strong alignment.

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

*Last Updated: January 3, 2026 — Added Recent Discoveries documentation with example couples*
