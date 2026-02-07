# Us 2.0 Variants - Early Thoughts

**Date:** 2025-02-07
**Context:** ~100 Google Play installs, 0 successful pairings. Need to experiment to find product-market fit.

---

## The Problem

Users install the app but nobody completes pairing. The pairing step (entering a partner's code) appears to be a hard wall. We need to test whether the problem is:
- The pairing UX itself (fixable with better design)
- The pairing concept (requiring two devices is too much friction)
- The content/positioning (wrong audience or value prop)

## Proposed Variants

### 1. Pairing Screen A/B Test (within Us 2.0)
- Test a redesigned pairing screen against the current one
- Lowest effort, can run inside the existing app
- Use Firebase Remote Config or server flag
- **Tests:** Is the pairing UX the problem, or is the concept itself?

### 2. Single-Phone Mode (new app)
- Both partners use the same phone to answer questions
- No pairing code, no second install needed
- Turn-taking happens on one device (pass the phone)
- **Tests:** Is the two-device requirement the core blocker?
- **Architecturally interesting:** Changes the core game loop (no partner polling, no pairing)

### 3. Christian Young Couples (new app)
- Quiz content tailored for Christian couples exploring faith and marriage
- Clear niche with strong keyword targeting on Google Play
- Same mechanics, different content and branding
- **Tests:** Does niche positioning improve conversion?

### 4. Spicy / Erotica (new app)
- Content focused on sex and intimacy discovery
- Couples exploring desires, fantasies, boundaries
- **Tests:** Does edgier content drive more engagement?
- **Note:** Google Play content policies need careful navigation

## Recommended Approach: Separate Apps via White-Label System

The existing white-label architecture (`brand_config.dart`, `brand_registry.dart`, Android flavors) is built for this. Each variant becomes a new brand with its own:
- Package ID
- Google Play store listing (independent screenshots, description, keywords)
- Firebase project or app
- Content set
- Clean analytics data

### Why not in-app A/B testing for variants 2-4?
- Radically different experiences need different store listings and target audiences
- No risk of showing wrong content to wrong audience
- Google Play gives independent install/retention data per listing
- Each app iterates independently

### Exception: Variant #1 (pairing A/B test)
This should be an in-app test since it's the same product with a different onboarding flow.

## Priority Order

| Priority | Variant | Rationale |
|----------|---------|-----------|
| **1st** | Single-phone mode | Directly tests biggest hypothesis (is pairing the wall?) |
| **2nd** | Pairing screen A/B | Low effort, runs in parallel within Us 2.0 |
| **3rd** | Christian couples | Clear niche, easy Google Play keyword targeting |
| **4th** | Spicy/erotica | Good niche but needs content policy review first |

## Technical Steps Per New App

```
1. New brand entry in brand_registry.dart
2. New Android flavor in build.gradle
3. New package ID (com.togetherremind.{variant})
4. New Firebase app (within existing project or new)
5. New Google Play listing
6. Brand-specific content and theming
```

## Open Questions

- [ ] Single-phone mode: How does turn-taking UX work? Timer? Honor system? Physical handoff?
- [ ] Single-phone mode: Do we keep any server sync, or is it fully local?
- [ ] Christian variant: Source content from existing faith-based question banks?
- [ ] Spicy variant: What are the exact Google Play content rating implications?
- [ ] Should all variants share the same Supabase backend or separate?
- [ ] How do we measure success? Install-to-first-game-completed funnel?

## Status

- [x] Decide which variant to build first → **Single-phone (hybrid model)**
- [x] Plan UX for single-phone → `single_phone_ux_plan.md`
- [x] Build interactive mockups → `mockups/us20variants/`
- [x] Document mockup decisions → `mockup_decisions.md`
- [ ] Plan implementation for hybrid model
- [ ] Implement in Us 2.0 codebase (same app, not separate brand)
- [ ] Deploy to Google Play
- [ ] Launch and measure

## Key Evolution (2025-02-07)

**Original idea:** Separate apps via white-label system.
**Evolved to:** Hybrid model within the same Us 2.0 app.

The single-phone variant is NOT a separate app anymore. Instead:
- Everyone starts on one phone (no pairing during onboarding)
- Pairing is optional, available anytime from Settings
- After pairing, both modes coexist (single-phone + two-device)
- Same codebase, same Play Store listing, same brand

This is simpler to build, simpler to maintain, and gives better data (one funnel to analyze instead of two separate apps).
