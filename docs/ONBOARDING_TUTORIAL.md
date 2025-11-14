# TogetherRemind Solo Onboarding - Ultra-Deep Analysis & Plan

## Executive Summary

**Strategy: Let users try the app solo first before pairing with their partner.**

### The Core Problem
TogetherRemind has a classic **cold-start problem**:
- User downloads alone → can't experience ANY features → asks skeptical partner to download → high friction = high drop-off
- Current flow: Name input → **immediately forced to pairing screen** → creates pressure and confusion

### The Solution
**"Show, Don't Tell"** - Let users FEEL the app's value through interactive moments before asking them to bring their partner.

---

## Current State Analysis

### What Exists Now:
1. **Hard Partner Gate**: `hasPartner()` is binary - you're either fully locked out or fully in
2. **All Features Require Partner**: Every game, reminder, poke needs partner's push token
3. **No Tutorial**: No existing tutorial or solo gameplay
4. **Immediate Pressure**: Onboarding → Name → Pairing (30 seconds total)

### Feature Dependency Analysis:

| Feature | Partner Required? | Why? | Solo-Adaptable? |
|---------|------------------|------|-----------------|
| **Reminders** | ✅ Yes | Needs partner push token | ❌ No (core is sending) |
| **Pokes** | ✅ Yes | Needs partner push token | ⚠️ Maybe (could show UI) |
| **Classic Quiz** | ✅ Yes | Two-player sync via RTDB | ✅ **Yes** (answer about self) |
| **Speed Round** | ✅ Yes | Two-player sync via RTDB | ✅ **Yes** (answer about self) |
| **Word Ladder** | ✅ Yes | Turn-based RTDB sync | ✅ **Yes** (solo puzzles) |
| **Memory Flip** | ✅ Yes | Co-op RTDB sync | ✅ **Yes** (solo gameplay) |
| **Daily Pulse** | ✅ Yes | Two-player comparison | ❌ No (core is comparison) |
| **Love Points** | ❌ No | Local tracking | ✅ **Yes** |
| **Badges** | ❌ No | Local achievements | ✅ **Yes** |
| **Profile** | ❌ No | Local settings | ✅ **Yes** |

**Key Insight**: Games can work solo for tutorial/practice with minimal adaptation!

---

## Recommended Strategy: "Warm Onboarding"

### Phase 1: Welcome & Hook (60 seconds)
**Goal**: Emotional connection + value prop clarity

```
Screen 1: Animated Splash
┌─────────────────────────────┐
│         💕 (pulsing)        │
│                             │
│     TogetherRemind          │
│                             │
│  Stay close, even when      │
│       you're apart          │
│                             │
│   [Get Started] button      │
└─────────────────────────────┘

Screen 2: Quick Value Carousel (swipeable)
┌─────────────────────────────┐
│  1/3: "Send sweet reminders"│
│      [Preview animation]    │
│                             │
│  2/3: "Play together daily" │
│      [Game previews]        │
│                             │
│  3/3: "Grow your bond"      │
│      [LP visualization]     │
│                             │
│         • • •               │
│      [Continue]             │
└─────────────────────────────┘

Screen 3: Name + Relationship Context
┌─────────────────────────────┐
│     What's your name?       │
│  [____________]             │
│                             │
│  Relationship status:       │
│  ( ) Dating                 │
│  ( ) Engaged                │
│  ( ) Married                │
│  ( ) It's complicated 😊    │
│                             │
│     [Continue]              │
└─────────────────────────────┘
```

### Phase 2: Interactive Tutorial (3-5 minutes)
**Goal**: Let them PLAY and feel the app's magic

**2A: Mini Quiz Tutorial**
```
"Let's see how well you know yourself! 🧩"

Question 1/3: On a perfect Saturday, I'd rather...
○ Sleep in and relax
○ Adventure outside
○ Spend time with loved ones
○ Work on a project

[Shows scoring animation when selected]
"+10 LP - Great answer!"

After 3 questions:
"Imagine your partner guessing these!
 You matched 85% when you did this together!"
[Mock results screen showing how it works]
```

**2B: Memory Flip Demo** (optional, can be skipped)
```
"Try our memory game - flip cards to find pairs! 🃏"

[2x2 grid, 4 cards, simple solo play]
[Flip two, match animation]

"With your partner, you share the same board and
 work together to find all pairs! Teamwork makes
 the dream work! ✨"
```

**2C: Love Points Explanation**
```
"You just earned 25 Love Points! 💎"

[Animated LP counter going up]

"Earn LP by:
 • Playing games together
 • Sending reminders
 • Daily check-ins

 Use LP to unlock badges & customize your space!"
```

### Phase 3: The Pair Prompt (Soft Ask)
**Goal**: Make pairing feel exciting, not mandatory

```
┌─────────────────────────────┐
│      Ready for the          │
│      best part? 💕          │
│                             │
│  Everything you just tried  │
│  is WAY more fun with your  │
│  partner!                   │
│                             │
│  [Yes, let's pair! 🎉]     │
│                             │
│  [Not yet, explore more]    │
│                             │
│  (You can pair anytime!)    │
└─────────────────────────────┘
```

### Phase 4A: Solo Exploration Mode (if they defer)
**Goal**: Let them browse, maintain engagement, nudge to pair

**Home Screen (Solo Mode)**
```
┌─────────────────────────────┐
│  👋 Welcome back, Alex!     │
│                             │
│  💕 Invite Your Partner     │
│  [Unlock all features!]     │
│                             │
│  🧩 Activities              │
│  ├─ Classic Quiz 🔒         │
│  │  "Pair to unlock"        │
│  ├─ Memory Flip 🔒          │
│  │  "Pair to unlock"        │
│  └─ Try Tutorial ✅         │
│                             │
│  💎 Your Progress           │
│  25 LP earned               │
│  Tutorial Master badge      │
│                             │
│  [Browse Features]          │
│  [Invite Partner Now]       │
└─────────────────────────────┘
```

**What They Can Do Solo:**
- ✅ View all activity descriptions & previews
- ✅ Replay tutorial games
- ✅ Edit profile (name, avatar emoji)
- ✅ Browse quiz question bank ("Preview questions you'll answer together")
- ✅ Read "How It Works" for each feature
- ✅ See LP/badges system
- ❌ Can't start real games (grayed out with "Pair to unlock" badges)

**Gentle Nudges:**
- After 1 day: Push notification "Missing someone? 👋 Invite your partner!"
- After browsing 3+ screens: "Ready to experience this together?"
- Persistent "Invite Partner" card at top of every screen

### Phase 4B: Pairing Flow (when ready)
**Goal**: Smooth transition, celebrate the moment

```
[Current PairingScreen with QR + Remote code]

On successful pairing:
┌─────────────────────────────┐
│    🎉 ✨ 💕 ✨ 🎉         │
│                             │
│   Together at last!         │
│                             │
│  [Confetti animation]       │
│                             │
│   +50 LP Bonus              │
│   "First Step Together"     │
│                             │
│  [Start playing!]           │
└─────────────────────────────┘
```

---

## Technical Implementation Plan

### 1. Data Model Changes

**User model** (`app/lib/models/user.dart`):
```dart
@HiveType(typeId: 2)
class User extends HiveObject {
  // ... existing fields ...

  @HiveField(8, defaultValue: false)
  bool hasCompletedOnboarding;

  @HiveField(9, defaultValue: false)
  bool hasSeenTutorial;

  @HiveField(10)
  String? relationshipStatus; // 'dating', 'engaged', 'married', 'complicated'

  @HiveField(11)
  DateTime? anniversaryDate;
}
```

**StorageService additions** (`app/lib/services/storage_service.dart`):
```dart
bool hasCompletedOnboarding() {
  return getUser()?.hasCompletedOnboarding ?? false;
}

Future<void> markOnboardingComplete() async {
  final user = getUser();
  if (user != null) {
    user.hasCompletedOnboarding = true;
    await user.save();
  }
}
```

### 2. New Screens

**Create these new files:**
1. `app/lib/screens/onboarding_flow_screen.dart` - Multi-step onboarding coordinator
2. `app/lib/screens/welcome_carousel_screen.dart` - Value prop slides
3. `app/lib/screens/tutorial_quiz_screen.dart` - Solo quiz tutorial (3 questions)
4. `app/lib/screens/tutorial_memory_screen.dart` - Solo memory game tutorial
5. `app/lib/screens/solo_exploration_screen.dart` - "Waiting room" UI for unpaired users
6. `app/lib/screens/pair_prompt_screen.dart` - Soft ask to pair

### 3. Navigation Flow Changes

**Update `app/lib/main.dart`:**
```dart
home: Builder(
  builder: (context) {
    final storage = StorageService();

    // Gate 1: Has completed onboarding?
    if (!storage.hasCompletedOnboarding()) {
      return const OnboardingFlowScreen(); // New multi-step flow
    }

    // Gate 2: Has partner?
    if (!storage.hasPartner()) {
      return const SoloExplorationScreen(); // New waiting room
    }

    // Gate 3: Fully paired - normal app
    return const HomeScreen();
  },
)
```

### 4. Feature Gating System

**Create `app/lib/utils/feature_gate.dart`:**
```dart
enum FeatureRequirement {
  none,        // Available to everyone
  onboarding,  // Requires onboarding completion
  partner,     // Requires paired partner
}

class FeatureGate {
  static bool canAccess(FeatureRequirement req) {
    final storage = StorageService();

    switch (req) {
      case FeatureRequirement.none:
        return true;
      case FeatureRequirement.onboarding:
        return storage.hasCompletedOnboarding();
      case FeatureRequirement.partner:
        return storage.hasPartner();
    }
  }

  static Widget gatedButton({
    required FeatureRequirement requirement,
    required String lockedText,
    required VoidCallback onPressed,
    required Widget child,
  }) {
    if (canAccess(requirement)) {
      return ElevatedButton(onPressed: onPressed, child: child);
    } else {
      return ElevatedButton(
        onPressed: null,
        child: Row(children: [child, Text(lockedText)]),
      );
    }
  }
}
```

### 5. Tutorial Quiz Service

**Create `app/lib/services/tutorial_service.dart`:**
```dart
class TutorialService {
  static final List<TutorialQuestion> _questions = [
    TutorialQuestion(
      id: 'tut_1',
      text: 'On a perfect Saturday, I\'d rather...',
      options: [
        'Sleep in and relax',
        'Adventure outside',
        'Spend time with loved ones',
        'Work on a project',
      ],
    ),
    TutorialQuestion(
      id: 'tut_2',
      text: 'My ideal date night involves...',
      options: [
        'Dinner and a movie',
        'Cooking together at home',
        'Something adventurous',
        'Just talking for hours',
      ],
    ),
    TutorialQuestion(
      id: 'tut_3',
      text: 'When I\'m stressed, I cope by...',
      options: [
        'Talking it through',
        'Taking time alone',
        'Physical activity',
        'Distracting myself',
      ],
    ),
  ];

  List<TutorialQuestion> getTutorialQuestions() => _questions;

  Future<void> completeTutorial() async {
    final storage = StorageService();
    final user = storage.getUser();
    if (user != null) {
      user.hasSeenTutorial = true;
      await user.save();

      // Award LP for tutorial completion
      await LovePointService().addPoints(
        25,
        'tutorial_complete',
        'Tutorial completed!',
      );
    }
  }
}

class TutorialQuestion {
  final String id;
  final String text;
  final List<String> options;

  TutorialQuestion({
    required this.id,
    required this.text,
    required this.options,
  });
}
```

### 6. Modified Activities Screen

**Update `app/lib/screens/activities_screen.dart`:**
```dart
Widget _buildActivityCard(...) {
  final hasPartner = _storage.hasPartner();
  final isLocked = !hasPartner;

  return Opacity(
    opacity: isLocked ? 0.5 : 1.0,
    child: InkWell(
      onTap: isLocked
        ? () => _showPairingPrompt(context)
        : onTap,
      child: Container(
        // ... existing card UI ...
        child: Stack(
          children: [
            // ... existing content ...
            if (isLocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('🔒 Pair to unlock'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void _showPairingPrompt(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Pair with your partner'),
      content: Text('This activity is way more fun together! Ready to invite your partner?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Not yet'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PairingScreen()),
            );
          },
          child: Text('Let\'s pair!'),
        ),
      ],
    ),
  );
}
```

---

## UX/UI Design Principles

### Emotional Design
- **Hope over FOMO**: "Soon you'll do this together!" vs "You can't use this"
- **Progress feeling**: Show solo progress (LP, badges from tutorial)
- **Social proof**: "1M+ couples stay connected with TogetherRemind"
- **Celebration moments**: Confetti on pairing, badge animations

### Visual Hierarchy
| State | Visual Treatment |
|-------|------------------|
| **Solo Mode** | Soft pastels, preview states, "Coming soon" vibes |
| **Locked Features** | 50% opacity, 🔒 badge, tap → pairing prompt |
| **Unlocked (Paired)** | Vibrant colors, active states, full saturation |
| **Tutorial** | Guided, highlighted, celebratory animations |

### Copy Strategy
| ❌ Avoid | ✅ Use |
|----------|--------|
| "You need a partner" | "This is better with your partner!" |
| "Feature locked" | "Pair to unlock" |
| "Cannot access" | "Coming soon when you pair!" |
| "Invite partner to continue" | "Ready to bring your partner along?" |

---

## Success Metrics

### Onboarding Funnel
1. App opened → 100%
2. Name entered → Target: 90%
3. Tutorial started → Target: 85%
4. Tutorial completed → Target: 75%
5. Pairing initiated → Target: 60%
6. Successfully paired → Target: 50%
7. First activity together → Target: 40%

### Key Questions
- **Time to pair**: How long from install to pairing?
- **Solo engagement**: Do users explore while unpaired?
- **Tutorial completion**: Does it drive pairing intent?
- **Drop-off points**: Where do users abandon?

### A/B Test Ideas
- Tutorial length (3 vs 5 questions)
- Pair prompt timing (immediate vs after tutorial vs after browsing)
- Solo feature preview (full preview vs locked preview)

---

## Implementation Phases

### **Phase 1: MVP (Week 1)** - Core Solo Onboarding
- [ ] Add `hasCompletedOnboarding` flag to User model
- [ ] Create `OnboardingFlowScreen` (name + relationship status)
- [ ] Create `TutorialQuizScreen` (3 questions, solo)
- [ ] Create `PairPromptScreen` (soft ask)
- [ ] Update navigation flow in `main.dart`
- [ ] Award 25 LP for tutorial completion

### **Phase 2: Enhanced (Week 2)** - Solo Exploration
- [ ] Create `SoloExplorationScreen` (waiting room UI)
- [ ] Add feature locks to Activities screen
- [ ] Create welcome carousel with value prop
- [ ] Add "Invite Partner" button/card
- [ ] Implement share sheet for pairing invite
- [ ] Add pairing celebration animation

### **Phase 3: Polish (Week 3)** - Optimization
- [ ] Add tutorial Memory Flip (optional)
- [ ] Add LP/badge visualization
- [ ] Implement reminder notifications for unpaired users
- [ ] Add analytics tracking
- [ ] Question bank preview screen
- [ ] A/B testing framework

---

## Alternative Approaches Considered

### Option A: "Invite First" (Rejected)
**Flow**: Welcome → Generate code immediately → "Send to partner NOW" → Wait together

**Why rejected**: Too aggressive, requires partner availability, no solo value demonstration

### Option B: Full AI Partner (Rejected)
**Flow**: Welcome → Pair with AI bot → Full features → Swap to real partner later

**Why rejected**: Over-engineered, feels fake, migration complexity

### Option C: Pure Demo Mode (Rejected)
**Flow**: Welcome → Video walkthrough → Screenshots of features → Pair to try

**Why rejected**: No engagement, no emotional connection, just marketing

---

## Final Recommendation

**Go with the "Warm Onboarding" strategy** (Phases outlined above).

### Why This Works:
✅ **Low friction** - No pressure, natural flow
✅ **Value demonstration** - They FEEL the app through tutorial
✅ **Respects timing** - Partner doesn't need to be available immediately
✅ **Builds investment** - LP/progress creates sunk cost
✅ **Maintains philosophy** - Still "couples-first" but accessible
✅ **Technically feasible** - Uses existing architecture, minimal new code
✅ **Data-driven** - Easy to measure and optimize

### Core Principle:
**"Show, don't tell. Let users FEEL the app's magic in 3 minutes, then make pairing the natural next step, not a barrier."**

The tutorial acts as a "taste test" - just enough to want more, but clearly better with a partner. Like offering a free sample at a restaurant: you get to try it, but the full experience requires the full commitment (pairing).

---

## Open Questions for Decision

1. **Tutorial length**: 3 questions (quick) or 5 questions (thorough)?
2. **Memory Flip tutorial**: Include it or quiz-only for speed?
3. **Pair prompt timing**: After tutorial immediately, or let them browse first?
4. **Solo LP cap**: Should unpaired users have a max LP (e.g., 50) to incentivize pairing?
5. **Analytics**: What's most important to track first?
6. **Notification cadence**: How aggressive should "invite partner" reminders be?

---

**Last Updated:** 2025-11-12
**Status:** Planning - Ready for Implementation
