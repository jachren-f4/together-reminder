# New Onboarding Design Proposal

**Based on analysis of:** Paired app onboarding flow (22 screens)
**Date:** January 2026

---

## Table of Contents

1. [Current vs Proposed Comparison](#current-vs-proposed-comparison)
2. [Competitor Analysis](#competitor-analysis)
3. [Key Design Patterns](#key-design-patterns)
4. [Proposed Us 2.0 Onboarding Flow](#proposed-us-20-onboarding-flow)
5. [Screen-by-Screen Design](#screen-by-screen-design)
6. [Data Collection Strategy](#data-collection-strategy)
7. [Personalization Opportunities](#personalization-opportunities)

---

## Current vs Proposed Comparison

### Current Us 2.0 Flow (11 screens) - RETAIN CORE

```
1. OnboardingScreen (splash)          ← ENHANCE with carousel
2. NameEntryScreen                    ← KEEP (add birthday)
3. AuthScreen                         ← KEEP as-is
4. OtpVerificationScreen              ← KEEP as-is
5. PairingScreen                      ← ENHANCE UI (two-panel)
6. WelcomeQuizIntroScreen             ← KEEP (unique to us!)
7. WelcomeQuizGameScreen              ← KEEP (differentiator)
8. WelcomeQuizWaitingScreen           ← KEEP
9. WelcomeQuizResultsScreen + LP      ← KEEP
10. PaywallScreen                     ← ENHANCE (add comparison before)
11. MainScreen                        ← KEEP
```

### What We RETAIN (Our Differentiators)

| Element | File | Why Keep |
|---------|------|----------|
| **Welcome Quiz flow** | `welcome_quiz_*.dart` | Major differentiator - interactive couple activity before paywall |
| **LP Introduction** | `lp_intro_overlay.dart` | Core gamification - introduces Love Points concept |
| **QR/Code Pairing** | `pairing_screen.dart` | Works well, just needs UI polish |
| **Name collection** | `name_entry_screen.dart` | Already doing this |
| **Email/OTP auth** | `auth_screen.dart`, `otp_verification_screen.dart` | Functional |
| **Already Subscribed** | `already_subscribed_screen.dart` | Important for couple subscriptions |

### What We ADD (From Paired)

| Element | Purpose | Priority |
|---------|---------|----------|
| Value proposition carousel | Build excitement before signup | High |
| Birthday field | Birthday reminders | Medium |
| Anniversary date | Anniversary reminders + context | Medium |
| Two-panel pairing UI | Cleaner "send vs enter" code UX | High |
| Push notification screen | Better permission opt-in | Medium |
| "Without vs With" comparison | Value reinforcement before paywall | High |
| Welcome celebration | Emotional payoff after purchase | Low |

### What We DON'T Add (Skip for Now)

| Element | Why Skip |
|---------|----------|
| Gender selection | Low value, adds friction |
| Relationship status | Nice-to-have, not essential |
| Living situation | Nice-to-have, not essential |
| Children question | Nice-to-have, not essential |
| Attribution question | Can add later via analytics |

---

## Competitor Analysis

### Paired's Onboarding Structure

The Paired app uses a **22-screen onboarding flow** divided into distinct phases:

#### Phase 1: Value Proposition Carousel (Screens 1-3)
- **Screen 1:** "Make connection a daily habit" - Couple embracing with heart speech bubbles
- **Screen 2:** "Build a thriving relationship" - Two people watering a plant together (growth metaphor)
- **Screen 3:** "Paired is made for two" - Couple holding heart puzzle pieces (inclusive: wheelchair user)

**Key insight:** Each screen has a swipeable carousel with progress indicators. The sign-up buttons are always visible at the bottom, allowing users to skip ahead.

#### Phase 2: Account Creation (Screen 4)
- "Welcome to Paired" transition screen
- Explains personalization questionnaire is coming
- Sets expectations for the flow

#### Phase 3: Personal Information (Screens 5-7)
- **Screen 5-6:** First name + Birthday (with validation checkmarks)
- **Screen 7:** Gender selection (Female, Male, Gender queer/Non-binary, Other)

**Key insight:** Uses personalized greetings immediately after collecting name ("Which gender describes you best, Joakim?")

#### Phase 4: Relationship Context (Screens 8-13)
- **Screen 8:** Transition screen - "Get ready to explore your relationship"
- **Screen 9-10:** Anniversary date (with dynamic encouragement message: "We love to see it!")
- **Screen 11:** Relationship status (In a relationship, Engaged, Married, Civil partnership) - with icons
- **Screen 12:** Living situation (Together, Separately nearby, Long distance) - with illustrations
- **Screen 13:** Children (Yes/No with explanation)

**Key insight:** After collecting anniversary date, shows contextual encouragement based on relationship length.

#### Phase 5: Partner Pairing (Screen 14)
- Two-panel design: "I want to invite [Partner]" (purple) and "I have a code from [Partner]" (peach)
- 6-character invite code with copy/share functionality
- Uses partner's name throughout (collected earlier or from partner's name field)

#### Phase 6: Permissions & Marketing (Screens 15-17)
- **Screen 15-16:** Push notification permission (shows example notification mockup)
- **Screen 17:** Email opt-in for anniversary reminders

#### Phase 7: Attribution (Screen 18)
- "How did you hear about Paired?" - 10 options including podcasts, therapist, partner, streaming, app stores, ChatGPT, etc.

#### Phase 8: Value Reinforcement (Screen 19)
- Side-by-side comparison: "Without Paired" vs "With Paired"
- Negative states on left (dark, stormy illustration)
- Positive states on right (hearts, happy couple)

#### Phase 9: Paywall (Screen 20)
- Social proof (5-star review carousel)
- "Free trial enabled" toggle
- Yearly (highlighted as "Most Popular" with 77% savings) vs Monthly
- "One subscription, two accounts" messaging
- "No payment due today" reassurance

#### Phase 10: Welcome Celebration (Screens 21-22)
- Animated crown icon reveal
- "Welcome to Paired Premium!"
- Emphasizes partner gets premium too

---

## Key Design Patterns

### 1. Progressive Personalization
- Collects user's name early, then uses it throughout ("Which gender describes you best, Joakim?")
- Collects partner's name, uses it in pairing screen ("I want to invite Taija")
- Creates emotional investment through personalized copy

### 2. Visual Storytelling
- Every information-collection screen preceded by illustrated "transition" screen
- Diverse couple illustrations (different ethnicities, ages, same-sex couples, disabilities)
- Consistent purple color palette with accent colors (peach for secondary actions)

### 3. Contextual Encouragement
- Dynamic messaging based on user input (e.g., "We love to see it!" for new couples)
- Positive reinforcement after completing sections

### 4. Reduced Friction for Required Fields
- Name field validates with green checkmark immediately
- Date pickers instead of manual entry
- Large tap targets for all options
- Single-select questions advance automatically (no "Next" button needed)

### 5. Skip Options for Optional Steps
- "Skip" link in top-right for non-essential screens
- "Next" link allows bypassing pairing temporarily
- Marketing opt-ins are skippable

### 6. Value Reinforcement Before Paywall
- "Without vs With" comparison creates urgency
- Social proof (reviews) on paywall
- Emphasizes shared subscription value

### 7. Two-Way Pairing Design
- Symmetrical design for "send code" vs "enter code"
- Visual distinction (purple vs peach cards)
- Both options visible simultaneously

---

## Proposed Us 2.0 Onboarding Flow

### Recommended Flow (14 screens - minimal new additions)

```
[Phase 1: Value Proposition] ← NEW
1. Carousel Screen 1: "Grow closer every day"
2. Carousel Screen 2: "Play together, stay together"
3. Carousel Screen 3: "Made for two"

[Phase 2: Account Creation] ← EXISTING (enhanced)
4. NameEntryScreen (add birthday field)
5. AuthScreen (existing)
6. OtpVerificationScreen (existing, if magic link)

[Phase 3: Relationship Context] ← NEW (minimal)
7. Anniversary date (optional, with encouragement)

[Phase 4: Partner Pairing] ← EXISTING (enhanced UI)
8. PairingScreen (two-panel design)

[Phase 5: Permissions] ← NEW
9. Push notifications (with example notification mockup)

[Phase 6: Welcome Quiz] ← EXISTING (keep all 4 screens!)
10. WelcomeQuizIntroScreen
11. WelcomeQuizGameScreen
12. WelcomeQuizWaitingScreen
13. WelcomeQuizResultsScreen + LP Intro Overlay

[Phase 7: Value & Paywall] ← EXISTING (add comparison)
14. "Without vs With" comparison (NEW - before paywall)
15. PaywallScreen (existing, enhanced copy)
    OR AlreadySubscribedScreen

[Phase 8: Welcome]
16. MainScreen (existing)
```

### Key Principle: Enhance, Don't Replace

The Welcome Quiz flow is **unique to Us 2.0** and a major differentiator. Paired has no equivalent. We should:
- Keep it exactly as-is
- Add value proposition BEFORE it (to build anticipation)
- Add value comparison AFTER it (before paywall)

---

## Screen-by-Screen Design

### Screen 1-3: Value Proposition Carousel

**Current state in Us 2.0:** We go straight to sign-up

**Proposed design:**

| Element | Design |
|---------|--------|
| Layout | Full-screen illustration (60%) + Dark content area (40%) |
| Illustration style | Happy couples in Us 2.0 brand style (gold/coral accents) |
| Progress indicator | 3 dots at bottom of illustration area |
| Headlines | Bold, benefit-focused (not feature-focused) |
| CTA buttons | "Sign up with email" (primary) + "Sign up with Apple" (secondary) |
| Navigation | "Log in" link in top-right for returning users |

**Copy suggestions:**
1. "Grow closer, one game at a time" - Couple playing on phones
2. "Daily moments that deepen your bond" - Couple looking at sunset together
3. "Two hearts, one journey" - Puzzle pieces forming heart

### Screen 4-5: Account Creation

**Keep existing:** Our OTP flow works well

**Enhancement:** Add transition screen before OTP explaining what's coming

### Screen 6: Personal Information

**Design:**
- Single screen with name + birthday
- Name field with real-time validation (green checkmark)
- Birthday with date picker (not manual entry)
- Large, rounded input fields (matching Paired's style)
- "Next" button disabled until both fields complete

**Why birthday?**
- Enables birthday notifications/reminders
- Could unlock "birthday month" special content
- Age verification if needed for mature content branches

### Screen 7: Gender (Optional)

**Design:**
- Personalized header: "Which describes you best, [Name]?"
- 4 large selection cards: Female, Male, Non-binary, Prefer not to say
- Auto-advances on selection (no Next button)
- "Skip" in top-right

**Why collect this?**
- Personalize pronouns in app copy
- Analytics for user demographics
- Could inform content recommendations

### Screen 8-9: Relationship Context

**Transition screen:**
- Illustrated couple with magnifying glass (discovery metaphor)
- "Let's learn about your relationship"
- "We'll use this to personalize your experience"

**Anniversary date screen:**
- "When did you become a couple?"
- Date picker
- Dynamic encouragement after selection:
  - < 1 year: "We love to see it! Building good habits early is amazing."
  - 1-5 years: "You've got this! Keep the spark alive."
  - 5-10 years: "A decade of love! Let's keep it growing."
  - 10+ years: "Relationship goals! We're honored to be part of your journey."

### Screen 10-11: Relationship Status & Living Situation

**Relationship status:**
- In a relationship (heart with sparkles icon)
- Engaged (ring icon)
- Married (interlocked hearts icon)
- Other (heart icon)

**Living situation:**
- We live together (toothbrushes in cup illustration)
- We live separately, nearby (two houses illustration)
- Long distance (phone with heart illustration)

**Why collect this?**
- Long-distance couples might benefit from different activity recommendations
- Married vs dating might prefer different question depth
- Could affect "poke" copy and features

### Screen 12: Partner Pairing

**Design (Two-Panel):**

| Top Panel (Gold/Cream) | Bottom Panel (Coral/Peach) |
|------------------------|---------------------------|
| "I want to invite my partner" | "I have a code from my partner" |
| "Your code:" + 6-char code | "Partner's code:" + 6 input boxes |
| "Tap to copy" button | Auto-focus first box |
| "Share your invite code" button | "Pair now" button |

**Key features:**
- Partner's name used if collected ("I want to invite Sarah")
- Code format: XXX-XXX (easy to read aloud)
- Share button opens native share sheet
- "Pair now" validates and connects

### Screen 13: Push Notifications

**Design:**
- Illustrated notification mockup overlaid on couple illustration
- "Never miss a moment with [Partner's name]"
- "Get notified when [Partner] completes an activity"
- "Yes please" button (friendly copy)
- "Skip" in top-right

### Screen 14: Value Comparison

**Design (Side-by-side cards):**

| Without Us 2.0 | With Us 2.0 |
|----------------|-------------|
| (-) Same old routine | (+) Daily surprises together |
| (-) Running out of things to talk about | (+) Endless conversation starters |
| (-) Feeling disconnected | (+) Feel closer every day |
| (-) Not sure how to improve | (+) Fun activities backed by science |

- Left card: Dark/muted colors, sad couple illustration
- Right card: Bright colors, happy couple with hearts

### Screen 15: Paywall

**Design elements:**
- Social proof carousel (App Store reviews)
- "One subscription covers both of you" messaging
- Free trial toggle (enabled by default)
- Plan options:
  - Yearly: "Most Popular" badge, show savings %
  - Monthly: Secondary option
- "Start your 7-day free trial" CTA
- "No payment due today" reassurance text
- Terms/Privacy links at bottom

### Screen 16: Welcome Celebration

**Design:**
- Animated crown/heart icon
- "Welcome to Us 2.0!"
- "Your partner gets premium too when you connect"
- Confetti animation
- "Get started" button

---

## Data Collection Strategy

### Data to Collect (and Why)

| Data Point | Purpose | Required? |
|------------|---------|-----------|
| Name | Personalization, display | Yes |
| Birthday | Birthday reminders, age verification | Yes |
| Gender | Pronouns, analytics | No (optional) |
| Partner's name | Personalized messaging | No (from pairing) |
| Anniversary date | Anniversary reminders, contextual messages | No (optional) |
| Relationship status | Content personalization | No (optional) |
| Living situation | Feature recommendations | No (optional) |
| Has children | Content filtering | No (optional) |
| Attribution | Marketing analytics | No (optional) |

### Data Storage

All collected data should be stored in the `couples` table (for relationship data) or `users` table (for personal data) in Supabase:

- `users.first_name`
- `users.birthday`
- `users.gender` (nullable)
- `couples.anniversary_date` (nullable)
- `couples.relationship_status` (nullable)
- `couples.living_situation` (nullable)
- `couples.has_children` (nullable)

---

## Personalization Opportunities

### Immediate Personalization
- Use name in headers throughout onboarding
- Use partner's name once connected
- Show contextual encouragement based on relationship length

### Post-Onboarding Personalization
- Anniversary reminder notifications
- Birthday content/celebrations
- Long-distance specific features (if applicable)
- Adjust content intensity based on relationship length

### Future Possibilities
- "Relationship timeline" feature using anniversary date
- "Milestones" celebration (1 month, 6 months, 1 year of using app)
- Content branches based on relationship status (engaged couples might see "wedding planning" questions)

---

## Implementation Priority

### Phase 1 (MVP - High Impact)
1. Value proposition carousel (3 screens)
2. Name collection with personalization
3. Improved pairing screen (two-panel design)
4. Value comparison screen before paywall

### Phase 2 (Enhanced)
1. Birthday collection
2. Anniversary date with contextual messaging
3. Push notification permission screen with mockup

### Phase 3 (Full Experience)
1. Gender selection
2. Relationship status & living situation
3. Attribution tracking
4. Welcome celebration animation

---

## Open Questions

1. **Should we collect partner's name before pairing?** Paired does this and uses it for personalization, but it adds friction.

2. **How much relationship data is too much?** Paired asks 5-6 relationship questions. We could start with fewer.

3. **Where does the Welcome Quiz fit?** Currently it's post-onboarding. Should it move into onboarding or stay separate?

4. **Carousel vs single page?** The carousel requires more screens but builds value. Worth the extra friction?

---

## Next Steps

1. Review this proposal and decide on scope
2. Create mockups for priority screens
3. Plan implementation phases
4. Consider A/B testing different flow lengths
