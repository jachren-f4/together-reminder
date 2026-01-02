# Us Profile Therapeutic Enhancements Plan

## Overview

Based on a therapeutic review of the Us Profile, this plan implements 6 key recommendations to increase the relationship health impact for couples.

**Primary Design Reference:** `mockups/us-profile-therapeutic/profile-month1-complete.html`

---

## Recommendation Summary

| # | Recommendation | Priority | Complexity | Impact | Status |
|---|----------------|----------|------------|--------|--------|
| 1 | Repair Scripts for Dimension Differences | High | Medium | High | ✅ Done |
| 2 | High-Stakes Discovery Tagging | High | Medium | High | ✅ Done |
| 3 | Conversation Timing Guidance | Medium | Low | Medium | ✅ Done |
| 4 | Growth Edge in Partner Perception | Medium | Medium | Medium | ✅ Done |
| 5 | Professional Help Prompts | Low | Low | Low | ✅ Done |
| 6 | Staged Profile Access Navigation | High | Low | High | ✅ Done |

---

## 1. Repair Scripts for Dimension Differences

### Problem
When couples have significant differences on key dimensions (e.g., conflict style, stress processing), the current UI shows the difference but doesn't help when that difference causes friction in real life.

### Solution
Add a "When This Causes Friction" expandable section to dimensions marked as "different" or "complementary", containing:
- Recognition prompt ("You might notice tension when...")
- Repair script for each partner
- De-escalation tip

### Example Content

**Dimension: Stress Processing (Internal vs External)**

When friction happens:
> "You might notice tension when one of you wants to talk through stress while the other needs quiet time first."

Repair scripts:
- **For Emma (Internal):** "I need some quiet time to process, but I promise we'll talk about this. Can we reconnect in an hour?"
- **For James (External):** "I know you need space right now. I'm here when you're ready. No pressure."

De-escalation tip:
> "Create a signal (like placing a specific object on the table) that means 'I need processing time' without having to explain in the moment."

### UI Location
- Expandable section below each "Key" or "Different" dimension
- Collapsed by default, with subtle "When this causes friction →" link

---

## 2. High-Stakes Discovery Tagging

### Problem
All discoveries are treated equally, but some topics (finances, family planning, intimacy, career priorities) need more careful handling than "have a 10-minute conversation."

### Solution
Tag discoveries by stakes level and provide appropriate scaffolding:

| Stakes Level | Categories | Scaffolding |
|--------------|------------|-------------|
| **Light** | Food, hobbies, entertainment | Simple "Try This" action |
| **Medium** | Social preferences, daily routines, household | "Try This" + timing suggestion |
| **High** | Finances, family, intimacy, career, values | Special card treatment + extended guidance + optional therapist prompt |

### High-Stakes Discovery Card Enhancements
- Different visual treatment (subtle border or icon)
- "This is a big topic" acknowledgment
- Multi-step conversation guide instead of single action
- "Not sure how to start?" → brief guidance
- Optional: "Consider discussing with a counselor" for very sensitive topics

### Example: High-Stakes Discovery

**Topic: Having Children**
> Emma: "I definitely want kids in the next few years"
> James: "I'm still figuring out if I want to be a parent"

Instead of "Try This: Have a 10-minute conversation"

Show:
```
💎 This is a significant topic

This difference touches on life direction and timing.
There's no quick answer, and that's okay.

Suggested approach:
1. Find a relaxed time (not during stress)
2. Start with curiosity: "I'd love to understand what makes you unsure"
3. Share your feelings without pressure to decide
4. It's okay to revisit this multiple times

🤝 Consider: Some couples find it helpful to explore
   big life questions with a counselor present.
```

---

## 3. Conversation Timing Guidance

### Problem
Good conversation starters delivered at bad times (rushing out, after a fight, when tired) backfire and create negative associations.

### Solution
Add contextual timing badges/suggestions to conversation starters:

| Timing Type | Icon | Description |
|-------------|------|-------------|
| **Relaxed moment** | 🌙 | "Best for a quiet evening" |
| **While active** | 🚶 | "Great for a walk together" |
| **Over food** | 🍽️ | "Works well over a meal" |
| **Quick check-in** | ⚡ | "Can be brief - 5 minutes" |
| **Dedicated time** | 📅 | "Set aside 20-30 minutes" |

### UI Treatment
- Small badge/tag on conversation starter cards
- Optional: "When NOT to have this conversation" tooltip

### Example
```
💬 Conversation Starter

"You have different approaches to handling stress.
What helps you feel supported when you're overwhelmed?"

🌙 Best for: A quiet evening at home
⚠️ Avoid: When either of you is already stressed
```

---

## 4. Growth Edge in Partner Perception

### Problem
The "Through Partner's Eyes" section only shows positive traits, missing an opportunity for growth through self-other perception gaps.

### Solution
Add a "Perception Gap" or "Growth Edge" sub-section that shows interesting discrepancies between:
- How you see yourself
- How your partner sees you

### Important Framing
This must be framed as **curiosity-inducing**, not critical:
- "An interesting difference in perception..."
- "Your partner notices something you might not..."
- Never frame as "your partner thinks you're wrong about yourself"

### Example Content

**Current Section: Through James's Eyes**
> James sees you as: Adventurous, Organized, Caring

**New Addition: A Different Perspective**
> You described yourself as "go with the flow" but James sees you as "the organized one" in your relationship.
>
> 💭 This isn't right or wrong - it's interesting! You might ask James: "What makes you see me as organized?"

### Data Source
- Compare answers from "You or Me" games
- Compare self-description questions with partner's description of them
- Only show gaps that are neutral-to-positive (not critical)

---

## 5. Professional Help Prompts

### Problem
Some patterns or discoveries are beyond what an app can address. Couples need to know when professional help would be valuable.

### Solution
Add gentle, non-alarming prompts in specific contexts:

### Trigger Contexts
1. **High-stakes discoveries** with significant gaps (especially: children, major values, intimacy issues)
2. **Repeated "friction" patterns** noted in the same dimension
3. **User manually flags** something as "we're stuck on this"

### UI Treatment
- Never alarming or pathologizing
- Framed as "optimization" not "fixing problems"
- Optional/dismissible
- Links to resources (if available)

### Example Copy

**Subtle prompt (end of high-stakes discovery):**
> 🌱 Some couples find it helpful to explore big life questions with a professional. This isn't about having problems - it's about having support for important conversations.

**For stuck patterns:**
> 💭 Noticed this keeps coming up? Sometimes an outside perspective helps. Couples counseling isn't just for crisis - many couples use it for growth.

---

## 6. Staged Profile Access Navigation

### Problem
The Us Profile is data-dense with insights that change weekly/monthly, not hourly. Putting it directly on the main profile screen risks:
- Cognitive overwhelm when users just want to check tier status
- Devaluing the content by making it feel like "just another settings page"
- Missing the opportunity to create an intentional "reflection moment"

### Solution
Access the Us Profile via a prominent entry card on the regular Profile screen, creating a staged experience.

### Why Staged Access Works

1. **Reduces cognitive overwhelm** — Users arrive when mentally ready to absorb insights, not while quickly checking their tier status

2. **Appropriate for content cadence** — Data changes weekly/monthly, not hourly. A separate entry point creates an "event" feeling: "Let me sit down and review our profile"

3. **Preserves the regular profile's purpose** — Main profile serves operational needs (tier, settings, account). Us Profile is reflective/therapeutic. Separating them matches their different purposes

4. **Creates anticipation** — Similar to Spotify Wrapped or Apple Health insights, the deep data lives in a dedicated view you visit intentionally

### Entry Point Design

```
┌─────────────────────────────────┐
│  Profile Screen                 │
│                                 │
│  [Avatar]  Emma & James         │
│  Tier 2: Kindred Spirits        │
│  ████████░░ 120/150 LP          │
│                                 │
│  ┌─────────────────────────────┐│
│  │  🔮 Us Profile              ││
│  │  Explore your relationship  ││
│  │  insights & discoveries     ││
│  │                      →      ││
│  └─────────────────────────────┘│
│                                 │
│  ⚙️ Settings                    │
│  📬 Notifications               │
│  ...                            │
└─────────────────────────────────┘
```

### Design Considerations

| Element | Treatment |
|---------|-----------|
| **Card style** | Visually distinct from other items (gradient background, subtle glow) |
| **Teaser content** | Show stats like "18 discoveries" to create curiosity |
| **Interaction feel** | Should feel like opening a special section, not navigating to settings |
| **New content badge** | Subtle indicator when something has changed since last visit |
| **Transition** | Consider a meaningful transition animation (slide up, fade reveal) |

### Badge Logic

Show "New" or dot indicator when:
- New discovery since last profile view
- Dimension position changed significantly
- New milestone achieved
- New conversation starter generated

---

## Visual Design Reference

**Primary Reference:** `mockups/us-profile-therapeutic/profile-month1-complete.html`

### Design System (from HTML mockup)

#### Color Palette

| Variable | Value | Usage |
|----------|-------|-------|
| `--bg-gradient-start` | #FFD1C1 | Page background top |
| `--bg-gradient-end` | #FFF5F0 | Page background bottom |
| `--primary-pink` | #FF6B6B | Primary accent, Emma's color |
| `--primary-orange` | #FF9F43 | Secondary accent, gradients |
| `--soft-blue` | #4A8BC9 | James's color |
| `--text-dark` | #3A3A3A | Primary text |
| `--text-medium` | #5A5A5A | Secondary text |
| `--text-light` | #707070 | Tertiary text, labels |
| `--cream` | #FFF8F0 | Card interiors |
| `--beige` | #F5E6D8 | Backgrounds, tracks |
| `--friction-bg` | #FFF0ED | Repair section background |
| `--friction-border` | #FFD4CC | Repair section border |
| `--success-green` | #3D8B40 | Positive indicators |

#### Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Couple names | Playfair Display | 24px | 400 |
| Section titles | Playfair Display | 15px | 400 |
| Body text | Nunito | 12-13px | 400-600 |
| Labels/badges | Nunito | 11-12px | 600-700 |
| Minimum readable | Nunito | 11px | — |

#### Component Styles

**Section Cards:**
- Background: white
- Border radius: 20px
- Padding: 18px
- Shadow: `0 2px 12px rgba(0,0,0,0.04)`

**Dimension Items:**
- Background: var(--cream)
- Border radius: 14px
- Track height: 10px
- Dot size: 16px with 2px white border

**Discovery Cards:**
- Background: var(--cream)
- Border radius: 12px
- Action section: white background inside

**Timing Badges:**
- Border radius: 10px
- Padding: 4px 10px
- Font size: 11px
- Color-coded by timing type (relaxed=purple, quick=green, dedicated=pink)

**Stakes Badges:**
- Border radius: 6px
- High stakes: red background (#FFEBEE), red text (#E53935)

**Repair Sections:**
- Trigger: dashed border, expands on tap
- Content: friction-bg background
- Scripts: white cards inside
- Tip: gradient background with lightbulb icon

#### Interaction Patterns

| Interaction | Behavior |
|-------------|----------|
| Info buttons | Expand/collapse with arrow rotation |
| Repair triggers | Dashed → solid border, expand content |
| Filter tabs | Gradient background when active |
| Cards | Subtle hover lift on web |

### Content Structure (Month 1 State)

The mockup shows a couple at Day 30 with:

| Section | Content |
|---------|---------|
| **Header** | Avatars, names, "Day 30 of your journey", stat pills (30 quizzes, 18 discoveries, 5 convos) |
| **Dimensions** | 4 of 6 unlocked, 2 locked with progress bar |
| **Discoveries** | 18 total with filter tabs (All, Lifestyle, Values, Future, Acted On) |
| **Values** | 4 shared values with alignment percentages |
| **Partner Perception** | Trait tags for each partner's view of the other |
| **Conversation Starters** | 2 starters with timing badges |
| **Actions** | Grid showing "Insights Acted On" and "Conversations Started" |
| **Growth** | Milestone timeline (completed + pending) |

---

## Implementation Phases

### Phase 1: HTML Mockups ✅ COMPLETE
- [x] Mockup 1: Repair Scripts on Dimensions → `mockups/us-profile-therapeutic/repair-scripts.html`
- [x] Mockup 2: High-Stakes Discovery Card → `mockups/us-profile-therapeutic/high-stakes-discovery.html`
- [x] Mockup 3: Conversation Timing Badges → `mockups/us-profile-therapeutic/conversation-timing.html`
- [x] Mockup 4: Growth Edge Perception Section → `mockups/us-profile-therapeutic/growth-edge.html`
- [x] Mockup 5: Professional Help Prompt Variants → `mockups/us-profile-therapeutic/professional-help-prompts.html`
- [x] Mockup 6: Lifecycle Stages (Day 2 → Month 1 → Year 1) → `mockups/us-profile-therapeutic/profile-lifecycle-stages.html`
- [x] Mockup 7: **Complete Month 1 Profile** → `mockups/us-profile-therapeutic/profile-month1-complete.html` ⭐ MAIN REFERENCE

### Long-Term Value Planning
See `docs/plans/LONG_TERM_VALUE_REQUIREMENTS.md` for content and feature requirements to support Year 1+ users.

### Phase 2: Content Development
- [ ] Write repair scripts for all 6 core dimensions
- [ ] Categorize all discovery categories by stakes level
- [ ] Write timing guidance for conversation starter types
- [ ] Define rules for "growth edge" display
- [ ] Write professional help prompt variants

### Phase 3: API Updates
- [ ] Add `stakesLevel` to discovery framing
- [ ] Add `repairScripts` to dimension framing
- [ ] Add `timingGuidance` to conversation starters
- [ ] Add perception gap calculation
- [ ] Add stuck pattern detection (future)

### Phase 4: Flutter Implementation - Navigation & Entry Point
- [x] Create Us Profile entry card on Profile screen
- [x] Add gradient background and glow effect to entry card
- [x] Show teaser stats (discoveries count, new indicator)
- [x] Implement "new content" badge logic
- [x] Add transition animation to Us Profile screen
- [x] Track `lastProfileViewedAt` for badge logic

### Phase 5: Flutter Implementation - Us Profile Screen
- [x] Create `UsProfileScreen` with scrollable layout
- [x] Implement header with avatars, names, journey day, stat pills
- [x] Build section card component (white, rounded, shadowed)
- [x] Build dimension items with spectrum track and dots
- [x] Implement repair script expandable sections
- [x] Build discovery cards with stakes-aware styling
- [x] Add filter tabs with gradient active state
- [x] Implement timing badges (color-coded by type)
- [x] Build values alignment section with progress bars
- [x] Build partner perception section with trait tags
- [x] Create conversation starter cards
- [x] Build actions grid (insights acted on, conversations started)
- [x] Create growth milestone timeline
- [x] Add info button expand/collapse pattern
- [x] Add professional help prompts to high-stakes discoveries

### Phase 6: Design System Implementation
Reference `mockups/us-profile-therapeutic/profile-month1-complete.html` for exact values:
- [x] Add Us Profile colors to BrandColors (see Visual Design Reference section)
- [x] Add Playfair Display font for section titles
- [x] Create reusable components matching mockup styles
- [x] Ensure minimum 11px font size for mobile readability
- [x] Implement interaction patterns (info expand, repair expand, filter tabs)
- [x] Fix text colors to match mockup (darker for readability)
- [x] Add discovery action buttons (I tried it / Save for later)

---

## Content Examples Needed

### Repair Scripts (6 dimensions)
1. Stress Processing (internal vs external)
2. Planning Style (spontaneous vs structured)
3. Social Energy (introvert vs extrovert)
4. Conflict Style (address immediately vs cool down first)
5. Space Needs (together time vs independence)
6. Support Style (fix it vs listen)

### High-Stakes Categories
- Family planning / children
- Financial philosophy
- Career priorities
- Intimacy / physical affection
- Religious / spiritual values
- Where to live
- Relationship with in-laws

### Timing Categories
- Light topics → any calm moment
- Medium topics → dedicated relaxed time
- Heavy topics → planned, both prepared, no time pressure

---

## Success Metrics

1. **Engagement:** Do users expand repair script sections?
2. **Action completion:** Do high-stakes discoveries lead to "We discussed this" at similar rates to light topics?
3. **Sentiment:** Do users report feeling "supported" vs "overwhelmed" in feedback?
4. **Retention:** Do these features correlate with continued app usage?

---

## Open Questions

1. Should repair scripts be shown proactively or only when user indicates friction?
2. How do we detect "stuck patterns" without invasive tracking?
3. Should we partner with actual therapy services for referrals?
4. How do we handle if users report serious issues (safety concerns)?

---

*Plan created: December 30, 2024*
*Updated: January 2, 2026 — Added staged navigation pattern, visual design reference from HTML mockup*
*Updated: January 2, 2026 — Completed Phase 4-6 implementation (entry card, new badge, transition, professional help prompts, action buttons)*
*Updated: January 2, 2026 — Completed Recommendation 4: Growth Edge in Partner Perception (GrowthEdge model, UI section, all 6 recommendations now complete)*
