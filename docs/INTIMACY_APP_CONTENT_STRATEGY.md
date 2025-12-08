# Intimacy-Focused Couples App - Content Strategy

**Date:** 2025-12-08
**Status:** Exploratory

---

## Overview

Evaluation of content viability for a niche couples app focused on intimacy, sensuality, and sexual wellness. This would be a white-label variant alongside TogetherRemind (general) and HolyCouples (religious).

---

## Content Categories

| Category | Example Content Types | Content Depth | Priority |
|----------|----------------------|---------------|----------|
| Desire Discovery | Fantasy quizzes, turn-on mapping, curiosity scales, arousal patterns | Deep | High |
| Communication | How to ask for what you want, feedback frameworks, boundary discussions, consent conversations | Deep | High |
| Compatibility | Libido matching, timing preferences, initiation styles, responsive vs spontaneous desire | Moderate | High |
| Exploration Prompts | "Would you try...", scenario cards, truth-or-dare variants, role-play generators | Very Deep | High |
| Educational | Technique guides, anatomy, pleasure psychology, health and wellness | Deep | Medium |
| Scheduling & Planning | Date night generators, anticipation builders, mood syncing, intimacy calendars | Moderate | Medium |
| Relationship Context | New parents, long-distance, stress periods, vacation intimacy, rekindling | Moderate | Low |

---

## Market Validation

### Existing Apps in Space

| App | Focus | Model | Notes |
|-----|-------|-------|-------|
| Coral | Sexual wellness education | Subscription | Individual + couples content |
| Dipsea | Audio erotica & wellness | Subscription | Story-based, primarily individual |
| Rosy | Women's sexual health | Subscription | Medical/wellness angle |
| Lasting | Couples therapy | Subscription | General relationship, some intimacy |

### Our Differentiator

Most sexual wellness apps are **individual-focused**. The "together" aspect - where both partners engage simultaneously with matching/comparison mechanics - is underserved.

**Existing game formats that translate well:**
- "You or Me" - Perfect for preference discovery
- Quiz matching - Reveals alignment and differences
- Daily quests - Builds habit and anticipation
- Love Points - Gamification drives engagement

---

## Content Volume Estimate

Based on current TogetherRemind structure (hundreds of quizzes):

| Content Type | Potential Volume | Reusability |
|--------------|------------------|-------------|
| Desire discovery quizzes | 50-100+ | High (branching) |
| Communication prompts | 100+ | Medium |
| Exploration scenarios | 200+ | Low (variety needed) |
| Educational modules | 30-50 | High |
| Date night ideas | 100+ | Medium |
| Discussion starters | 150+ | Medium |

**Verdict:** Sufficient content depth for a full app. The exploration/scenario category alone could sustain high engagement.

---

## Constraints & Considerations

### App Store Guidelines

**Apple App Store:**
- No explicitly sexual content in screenshots/marketing
- Educational/wellness framing required
- Age rating: 17+ likely required
- In-app content more lenient than store listing

**Google Play:**
- Similar restrictions on store presence
- "Sexual content" policy requires careful navigation
- Wellness/health framing helps

### Recommended Approach

1. **Position as "intimacy wellness"** not "sexual content"
2. **Educational tone** with playful delivery
3. **Age verification** at onboarding
4. **Tasteful UI** - suggestive not explicit
5. **Consent-forward** messaging throughout

### Tone Calibration

| Approach | Risk | Engagement |
|----------|------|------------|
| Clinical/medical | Low | Lower |
| Educational + playful | Low | High |
| Suggestive/flirty | Medium | High |
| Explicitly sexual | High (rejection) | N/A |

**Sweet spot:** Educational foundation with playful, permission-giving tone.

---

## Content Structure Adaptation

### Current TogetherRemind Structure
```
Quiz Types:
- Classic Quiz (matching answers)
- Affirmation Quiz (feel-good content)
- You or Me (preference reveal)
- Linked (word puzzles)
- Word Search (casual game)
```

### Proposed Intimacy App Structure
```
Quiz Types:
- Desire Quiz (what turns you on - matching)
- Appreciation Quiz (what you love about partner's body/touch)
- Would You Try (exploration preferences - You or Me format)
- Fantasy Match (scenario preferences)
- Communication Check-in (relationship health)

New Formats to Consider:
- Scenario Cards (randomized prompts)
- Countdown/Anticipation timers
- Private message prompts
- Challenge progression tracks
```

---

## Brand Naming Ideas

| Name | Tone | Domain Check Needed |
|------|------|---------------------|
| IntimateUs | Warm, inclusive | Yes |
| Kindred Flame | Poetic | Yes |
| Spark Together | Playful | Yes |
| Between Us | Private, intimate | Yes |
| Closer | Simple, direct | Yes |

---

## Next Steps

- [ ] Review existing quiz content structure for adaptation patterns
- [ ] Research App Store approval requirements in detail
- [ ] Define minimum viable content set for launch
- [ ] Design age verification flow
- [ ] Create sample quiz content for tone validation
- [ ] Evaluate competitor apps hands-on

---

## Open Questions

1. What's the right balance between free and premium content?
2. Should educational content be gated or free (trust-building)?
3. How explicit can in-app content be vs store listing?
4. Partner with sex educators/therapists for credibility?
5. How to handle LGBTQ+ inclusivity in content?

---

## References

- TogetherRemind white-label guide: `docs/WHITE_LABEL_GUIDE.md`
- Brand configuration: `lib/config/brand/brand_config.dart`
- Current quiz structure: `lib/services/quiz_service.dart`
