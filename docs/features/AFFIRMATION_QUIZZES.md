# Affirmation Quiz Content Guide

This document establishes the principles and rules for creating affirmation quiz content from a couples therapy perspective.

---

## Purpose: Affirmation vs Classic Quiz

| Aspect | Classic Quiz | Affirmation Quiz |
|--------|--------------|------------------|
| **Format** | 4 multiple choice options | 5-point Likert scale (Strongly Disagree → Strongly Agree) |
| **Question type** | "What kind?" | "How does this feel?" |
| **Purpose** | Preference discovery | Relationship health assessment |
| **Outcome** | "You prefer X, partner prefers Y" | "This area feels healthy/needs attention" |
| **Therapeutic use** | Bridge style differences | Identify growth areas, track progress over time |

**Classic Quiz asks:** "What's your approach to conflict?"
**Affirmation Quiz asks:** "How safe and connected do you feel when navigating conflict?"

---

## Core Principle: Think Like a Couples Therapist

A seasoned couples therapist doesn't ask direct, evaluative questions. They ask questions that:

1. **Invite reflection** rather than quick judgment
2. **Explore emotional experience** rather than rate satisfaction
3. **Approach sensitive topics indirectly** through feelings and observations
4. **Create safety** rather than trigger shame or defensiveness
5. **Reveal relationship dynamics** rather than individual opinions

### The Therapist's Lens

When writing questions, ask yourself:
- "Would a therapist ask this in session?"
- "Does this question create curiosity or defensiveness?"
- "Am I asking about the emotional experience or just the behavior?"
- "Does this help the couple understand their dynamic?"

---

## Question Writing Rules

### Rule 1: Emotional Experience Over Evaluation

**Bad (evaluative):**
- "I feel satisfied with our physical intimacy"
- "Our communication is good"
- "My needs are met"

**Good (experiential):**
- "Physical closeness with my partner feels nourishing"
- "I feel heard when I share something important"
- "There's space in our relationship for my needs"

**Why:** Evaluative questions trigger defensiveness and comparison. Experiential questions invite reflection on how things actually feel.

---

### Rule 2: Relational Dance Over Individual Satisfaction

**Bad (individual):**
- "I feel attractive"
- "My partner desires me"
- "I'm happy with our sex life"

**Good (relational):**
- "I can sense when my partner is drawn to me"
- "I feel my partner's attention and warmth"
- "In close moments, I feel emotionally connected to my partner"

**Why:** Relationships are co-created. Questions should explore the dynamic between partners, not just one person's satisfaction.

---

### Rule 3: Observational Language Over Direct Claims

**Bad (direct claims):**
- "My partner finds me attractive"
- "My partner listens to me"
- "We have good communication"

**Good (observational):**
- "I notice my partner's interest when we're close"
- "I can see my partner trying to understand me"
- "I feel the effort we both put into understanding each other"

**Why:** Observational language is softer, more accurate, and less likely to trigger "but that's not true!" responses.

---

### Rule 4: Approach Sensitive Topics Through the Side Door

For topics like intimacy, conflict, or vulnerability, don't ask directly about the behavior—ask about the emotional experience surrounding it.

**Bad (front door):**
- "I feel satisfied with our sex life"
- "We fight fairly"
- "I can be vulnerable with my partner"

**Good (side door):**
- "Physical moments with my partner feel emotionally safe"
- "Even in disagreement, I feel respected"
- "I can let my guard down when I'm with my partner"

**Why:** Direct questions about sensitive topics often trigger shame, defensiveness, or socially desirable answers. Side-door questions get at the same underlying health indicator without the baggage.

---

### Rule 5: Focus on Safety, Attunement, and Responsiveness

These three concepts from attachment theory and EFT (Emotionally Focused Therapy) should underpin most questions:

**Safety:** Do I feel secure? Can I be vulnerable? Will I be hurt?
- "I feel emotionally safe when..."
- "I can let my guard down..."
- "I don't worry that..."

**Attunement:** Does my partner notice me? Are they tuned in?
- "I feel seen by my partner when..."
- "My partner notices when I..."
- "I sense my partner paying attention to..."

**Responsiveness:** When I reach out, do they respond? Are they there for me?
- "When I reach for my partner, they..."
- "I feel my partner responds when I..."
- "There's space for me to..."

---

### Rule 6: Use "Soft" Language

**Hard language (avoid):**
- Desire, sex, need, satisfy, attractive, want
- Always, never, enough, should
- Problem, issue, struggle

**Soft language (prefer):**
- Drawn to, close, connection, warmth, closeness
- Often, tend to, usually, sometimes
- Space for, room for, opportunity to

**Examples:**

| Hard | Soft |
|------|------|
| "I feel desired" | "I feel my partner's warmth toward me" |
| "Our sex life is satisfying" | "Physical closeness feels nourishing" |
| "I need more affection" | "There's room for the closeness I'd like" |
| "We never talk about this" | "This topic doesn't come up easily for us" |

---

### Rule 7: Stage Compatibility (3-Month AND 10-Year Test)

Every question must work for:
- **New couples (3 months):** Can answer based on early observations, hopes, current feelings
- **Established couples (10 years):** Can answer based on patterns, history, current state

**Fails the test:**
- "Our years together have deepened our intimacy" (excludes new couples)
- "I'm curious how we'll handle this" (excludes established couples who already know)
- "When we first became intimate..." (early-stage framing)

**Passes the test:**
- "Physical closeness brings us closer emotionally" (works at any stage)
- "I feel safe being vulnerable with my partner" (works at any stage)
- "I believe we can navigate challenges together" (aspirational, works at any stage)

**Safe framings:**
- "I feel..." / "I believe..." / "I trust..." (present feelings/beliefs)
- "...would..." / "...could..." (conditional/hypothetical)
- "I notice..." / "I sense..." (observational)

---

## Question Structure Within Each Affirmation

Each affirmation quiz has 5 statements. They should cover different facets, not repeat the same idea:

### Recommended Structure:

1. **Self-experience:** How do I feel in this area?
2. **Partner attunement:** Do I feel seen/noticed by my partner here?
3. **Safety/trust:** Do I feel safe in this area?
4. **Relational dynamic:** How do we navigate this together?
5. **Growth/hope:** Do I feel optimistic about this area?

### Example - "Emotional Connection During Closeness"

1. (Self) "In physically close moments, I feel emotionally present"
2. (Attunement) "I sense my partner is emotionally with me during intimate moments"
3. (Safety) "I can be fully myself during physical closeness"
4. (Dynamic) "Physical and emotional intimacy feel connected for us"
5. (Hope) "I feel our physical connection deepens our emotional bond"

**Not acceptable - 5 variations of the same idea:**
1. "I feel connected during intimacy"
2. "Intimacy makes me feel close"
3. "I feel bonded during physical moments"
4. "Physical closeness creates connection"
5. "I feel intimate connection with my partner"

---

## Therapeutic Metadata Requirements

Every question must include therapeutic metadata:

```json
"metadata": {
  "therapeutic": {
    "rationale": "Why this matters therapeutically (2-3 sentences)",
    "framework": "attachment_theory | gottman | love_languages | eft | positive_psychology | family_systems",
    "whenDifferent": "Guidance when partners rate differently (2-3 sentences)",
    "whenSame": "Guidance when partners align (1-2 sentences)",
    "journalPrompt": "Reflective question for deeper exploration"
  }
}
```

### Framework Reference:

| Framework | Use For |
|-----------|---------|
| `attachment_theory` | Safety, security, vulnerability, reaching for partner |
| `gottman` | Communication, conflict, bids for connection, repair |
| `eft` | Emotional accessibility, responsiveness, engagement |
| `love_languages` | How love is expressed and received |
| `positive_psychology` | Growth, hope, strengths, building positive |
| `family_systems` | Family patterns, boundaries, roles |
| `financial_therapy` | Money-specific dynamics |

---

## Branch-Specific Guidelines

### Intimacy Branch

**Be especially careful with:**
- Stage-compatibility (couples may not have been sexually intimate)
- Shame triggers (body image, desire, performance)
- Direct sexual language (use "physical closeness" not "sex")

**Focus on:**
- Emotional safety during physical vulnerability
- Feeling desired/wanted (through observation, not direct claim)
- Attunement to physical and emotional needs
- Connection between physical and emotional intimacy

**Good intimacy themes:**
- Feeling safe being physically vulnerable
- Sensing partner's warmth and attention
- Emotional presence during physical closeness
- Space for physical needs to be known
- Physical touch as emotional connection

**Avoid:**
- Frequency/quantity questions
- Performance or satisfaction ratings
- Direct questions about sex acts
- Comparison to past or expectations

### Conflict Branch

**Focus on:**
- Safety to disagree
- Feeling heard even in conflict
- Trust that conflict won't damage the relationship
- Repair and reconnection after disagreement

**Avoid:**
- "We fight fairly" (evaluative)
- Questions about who's right/wrong
- Assuming conflict has occurred

### Finances Branch

**Focus on:**
- Emotional experience of money in the relationship
- Safety discussing money
- Feeling like financial teammates
- Trust and transparency

**Avoid:**
- Assuming merged finances
- Questions about amounts or specifics
- Assuming income levels or financial situations

---

## Pre-Submission Checklist

Before finalizing any affirmation quiz:

- [ ] All 5 questions explore different facets (not repetitive)
- [ ] Questions focus on emotional experience, not evaluation
- [ ] Uses observational/soft language
- [ ] Approaches sensitive topics through the side door
- [ ] Passes 3-month AND 10-year stage test
- [ ] No assumptions about living situation, sexual history, merged finances
- [ ] Therapeutic metadata complete on all questions
- [ ] Questions a therapist would actually ask

---

## Examples: Full Reframe

### Topic: Feeling Desired

**Bad Version (direct, evaluative, repetitive):**
1. "I feel attractive to my partner"
2. "My partner finds me desirable"
3. "I feel wanted by my partner"
4. "My partner is physically attracted to me"
5. "I feel my partner desires me"

**Good Version (experiential, observational, varied):**
1. "I can sense when my partner is drawn to me" (observation)
2. "My partner's attention makes me feel warm inside" (emotional experience)
3. "I feel my partner makes space for closeness with me" (relational dynamic)
4. "I can be present in my body when I'm with my partner" (self-experience/safety)
5. "Physical attention from my partner feels genuine and welcome" (attunement + safety)

### Topic: Physical Intimacy Satisfaction

**Bad Version:**
1. "I'm satisfied with our physical intimacy"
2. "Our sex life meets my needs"
3. "We're intimate often enough"
4. "Physical intimacy is good in our relationship"
5. "I feel fulfilled physically"

**Good Version:**
1. "Physical closeness with my partner feels nourishing" (emotional experience)
2. "I feel emotionally connected during intimate moments" (connection)
3. "There's room in our relationship for the closeness I'd like" (space/safety)
4. "I can express what I need physically without fear" (safety to communicate)
5. "Our physical connection reflects our emotional bond" (relational meaning)

---

## Summary: The Therapist Test

Before finalizing any question, ask:

> "Would a skilled, empathetic couples therapist ask this question in a session with a vulnerable couple?"

If the answer is no—if it's too direct, too evaluative, potentially shaming, or doesn't invite reflection—rewrite it.

The goal is questions that help couples **understand and explore** their relationship, not just **rate** it.

---

*Last Updated: January 2026*
