# Content Scaling Strategy

## Problem Statement

Long-term users (1 year+) need enough content to avoid repetition while maintaining quality. Current content: ~210 pieces. Needed: 1000+.

---

## Technical Feasibility

### Storage/Transfer Costs (Negligible)

| Metric | Size | Cost Impact |
|--------|------|-------------|
| Single quiz question JSON | ~300 bytes | Negligible |
| 1000 questions total | ~300 KB | Less than one image |
| Annual reads (1M couples × daily) | ~100GB/month | ~$10/month on Supabase |
| Tracking "seen" questions per couple | 1000 rows × couples | Easy with proper indexing |

**Verdict:** Infrastructure is not a constraint. Creation time is.

---

## Content Multiplication Strategies

### 1. Template-Based Generation (10x multiplier)

Create 100 templates that generate 1000+ variations:

```
Template: "What would {partner} do if {scenario}?"

Scenarios (100+):
- they won the lottery
- they had a free weekend alone
- they could live anywhere
- etc.
```

One template → 100 questions instantly.

### 2. Depth Laddering (3x multiplier)

Same topic, three depth levels:

| Level | Question | When to Show |
|-------|----------|--------------|
| 1 | "City or suburbs?" | Month 1 |
| 2 | "What draws you to [their answer]?" | Month 3 |
| 3 | "How would you compromise on this?" | Month 6 |

100 topics × 3 depths = 300 questions that feel like progression.

### 3. Reflection Recycling (∞ content)

After 6 months, resurface old questions as reflection:

> "In June, you said you prefer quiet evenings. Still true, or has this evolved?"

Transforms 500 questions into unlimited content - not repeating, tracking growth.

### 4. The "Daily Question" Model (Wordle-style)

Instead of unlimited consumption:
- One curated question per day (same for all couples)
- Creates shared experience ("Did you do today's question?")
- Only need 365 questions per year
- FOMO drives daily engagement
- Reduces content pressure by 90%

**Downside:** Limits power users. Could offer this + a smaller "bonus" pool.

### 5. Couple-Generated Content

Let couples submit questions:
- "Ask us anything" prompt
- Best submissions get featured
- Creates ownership and engagement
- Crowdsources content creation

### 6. AI-Personalized Questions (Dynamic)

Generate questions based on their profile:

```
Given:
- They disagree on "city vs suburbs"
- Emma values adventure, James values stability

Generate: "Emma, what adventure could you have in a suburban setting?
          James, what stability could a city neighborhood provide?"
```

**Requires:** API call to Claude per question (~$0.001 each)
**Benefit:** Infinite personalized content

---

## Recommended Hybrid Approach

| Layer | Content Type | Volume | Purpose |
|-------|--------------|--------|---------|
| **Core** | Hand-crafted questions | 500 | Quality foundation |
| **Templates** | Variable-based generation | 500+ | Bulk variety |
| **Reflection** | Recycled with context | ∞ | Long-term value |
| **Daily** | One curated question | 365/year | Engagement hook |
| **Dynamic** | AI-personalized | On-demand | Power user depth |

---

## Implementation Phases

### Phase 1: Core Content (Now - Priority)
- [ ] Create 500 hand-crafted questions using AI assistance
- [ ] Batch generate with Claude
- [ ] Human review for quality
- [ ] Tag with category, depth, stakes

### Phase 2: Template System (Month 2)
- [ ] Design 50 question templates
- [ ] Create variable pools (scenarios, topics, etc.)
- [ ] Build template engine
- [ ] Generate 500+ templated questions

### Phase 3: Reflection System (Month 4)
- [ ] Track when questions were last answered per couple
- [ ] Build reflection question generator
- [ ] Resurface after 90+ days with reflection framing
- [ ] A/B test reflection vs new content engagement

### Phase 4: Daily Question Feature (Month 6)
- [ ] Design editorial calendar system
- [ ] Create 365 curated daily questions
- [ ] Build push notification: "Today's question is ready"
- [ ] Add social sharing for daily questions

### Phase 5: AI Personalization (Month 8+)
- [ ] Design personalization prompt templates
- [ ] Build profile-aware question generator
- [ ] Implement caching to reduce API costs
- [ ] A/B test personalized vs static questions

---

## Cost Estimate for Initial 500 Pieces

| Task | Time | Cost |
|------|------|------|
| AI batch generation | 2 hours | ~$5 API costs |
| Human review/editing | 10 hours | Manual effort |
| Category/stakes tagging | 3 hours | Manual effort |
| Database seeding | 1 hour | Dev time |
| **Total** | ~16 hours | ~$5 |

---

## User Consumption Management

### Option A: Unlimited Play (Current)
- Users can play as much as they want
- Risk: Content exhaustion
- Mitigation: Large content pool + reflection recycling

### Option B: Daily Limits with Bonus
- 1 free game per day
- Premium: 3 games per day
- Unlimited on weekends
- Creates anticipation without frustration

### Option C: Energy System (Mobile Game Style)
- Energy regenerates over time
- Watch ad or pay to refill
- **Not recommended** - feels extractive for relationship app

### Recommendation: Option A with smart rotation
- No artificial limits
- Smart content rotation prevents repetition
- Reflection questions extend content life
- Daily Question creates natural engagement rhythm without forcing limits

---

## AI Prompt Templates for Batch Generation

### Classic Quiz Questions
```
Generate 50 unique couple quiz questions for the category "{category}".

Requirements:
- Questions reveal preferences, not test knowledge
- Include both light and meaningful topics
- 2-4 answer options each
- Work for couples of all backgrounds
- Avoid culturally specific references
- Include a mix of stakes levels (light/medium/high)

Format as JSON array:
{
  "question": "...",
  "answers": ["A", "B", "C"],
  "category": "lifestyle",
  "stakes": "light",
  "depth": 1
}
```

### You or Me Questions
```
Generate 50 "You or Me" questions for couples.

Requirements:
- Questions where couples guess who is more likely to do X
- Mix of playful and reflective
- Neither answer should be "better" than the other
- Should spark conversation about why

Format as JSON:
{
  "question": "Who is more likely to...",
  "category": "playful|reflective",
  "stakes": "light|medium"
}
```

---

## Open Questions

1. Should we gate some content behind subscription tiers?
2. How do we handle seasonal content (holidays vary by culture)?
3. Should long-term users get access to "advanced" questions automatically?
4. How do we measure content quality beyond skip rates?

---

*Plan created: January 2, 2026*
*Status: Backlogged - finish profile page first*
