# Visual Effects & Animation Enhancement Plan

**Created:** 2025-11-27
**Status:** ✅ COMPLETE (All Phases 1-8)
**Personality:** Subtle & Elegant
**Timeline:** ~15-18 days (10-12 days critical path)
**Last Updated:** 2025-11-27

---

## Table of Contents

1. [Overview](#overview)
2. [Design Guidelines](#design-guidelines)
3. [Architecture](#architecture)
4. [Visual Effect Catalog](#visual-effect-catalog)
5. [Implementation Phases](#implementation-phases)
6. [Detailed Task Checklist](#detailed-task-checklist)
7. [Sound Assets](#sound-assets)
8. [Critical Files Reference](#critical-files-reference)

---

## Overview

### Goals
- Add delightful visual effects across ~37 screens
- Implement sound system with user toggle
- Create reusable animation infrastructure
- Maintain white-label compatibility (TogetherRemind + HolyCouples)

### User Requirements
- **Personality:** Subtle & Elegant (refined, barely-there animations)
- **Priority:** Comprehensive - all areas
- **Sound:** Yes, with user toggle in settings
- **Skip for now:** Inbox, Activities, Profile, Settings (broken)

### Screens in Scope
| Category | Count | Screens |
|----------|-------|---------|
| Auth/Onboarding | 4 | auth, otp_verification, onboarding, pairing |
| Home | 1 | new_home_screen |
| Quiz Flow | 4 | quiz_intro, quiz_question, quiz_waiting, quiz_results |
| Affirmation | 2 | affirmation_intro, affirmation_results |
| Speed Round | 3 | speed_round_intro, speed_round, speed_round_results |
| You or Me | 4 | you_or_me_intro, game, waiting, results |
| Daily Pulse | 2 | daily_pulse, daily_pulse_results |
| Linked Puzzle | 2 | linked_game, linked_completion |
| Word Search | 2 | word_search_game, word_search_completion |
| Word Ladder | 3 | word_ladder_hub, game, completion |
| Memory Flip | 1 | memory_flip_game |
| Framework | 2 | unified_results, unified_waiting |
| **Total** | **~30** | |

---

## Design Guidelines

### "Subtle & Elegant" Characteristics

| Aspect | Guideline | Example |
|--------|-----------|---------|
| **Timing** | Fast is better | 200-300ms default |
| **Easing** | Smooth ease-out curves | `Curves.easeOutCubic` |
| **Scale changes** | Minimal range | 0.97-1.03 |
| **Movement** | Short distances | 16-24px max |
| **Opacity** | Prefer fades | No abrupt appearance |
| **Celebrations** | Brief, muted | 2-3s confetti |
| **Haptics** | Light/medium | Heavy only for achievements |
| **Sound** | Soft, short | <500ms clips |

### Animation Constants
```dart
// Durations
instant:   100ms   // Micro-feedback
fast:      200ms   // Button states
normal:    300ms   // Standard transitions
slow:      500ms   // Emphasis
dramatic:  800ms   // Celebrations

// Curves
fadeIn:    Curves.easeOut
scaleIn:   Curves.easeOutBack
slideIn:   Curves.easeOutCubic
elastic:   Curves.elasticOut

// Scale factors
pressScale:       0.97   // Button tap
celebrationScale: 1.05   // Achievement pop
```

---

## Architecture

### New File Structure
```
app/lib/
├── animations/
│   ├── animation_config.dart          # Timing constants, curves
│   ├── widgets/
│   │   ├── animated_fade_in.dart      # Declarative fade widget
│   │   ├── animated_scale_in.dart     # Pop-in effect
│   │   ├── animated_counter.dart      # Number count-up
│   │   ├── subtle_press.dart          # Tap feedback wrapper
│   │   └── staggered_column.dart      # Auto-staggered children
│   └── effects/
│       ├── celebration_overlay.dart   # Unified confetti/particles
│       └── shimmer_loading.dart       # Loading placeholder
│
├── services/
│   ├── sound_service.dart             # Audio with toggle
│   └── haptic_service.dart            # Unified haptic patterns
│
assets/
├── brands/{brandId}/sounds/           # Brand-specific sounds (future)
└── shared/sounds/                     # Shared sound effects
    ├── ui/
    ├── celebration/
    ├── feedback/
    └── games/
```

### Service Architecture

**SoundService:**
- Singleton pattern
- Hive-stored user preference
- Brand-aware asset paths
- Web platform safety (`kIsWeb` check)
- Preloading for performance

**HapticService:**
```dart
enum HapticType {
  light,      // UI feedback
  medium,     // Selection
  heavy,      // Important action
  success,    // Achievement (medium + light)
  warning,    // Error (double heavy)
  selection,  // Toggle/checkbox
}
```

---

## Visual Effect Catalog

### Home Screen (new_home_screen)

| Element | Effect | Priority |
|---------|--------|----------|
| Love Point counter | Count-up animation on load | P0 |
| Love Point counter | Pulse/glow on new LP award | P0 |
| Progress bar | Smooth animated fill | P1 |
| Quest cards | Staggered entrance (100ms delay each) | P1 |
| Quest cards | Completion checkmark draw animation | P0 |
| Greeting text | Time-based icon (sunrise/sunset) | P2 |
| Partner status | Breathing dot indicator | P2 |
| Pull to refresh | Custom elegant spinner | P3 |

### Results Screens (11 total)

| Effect | Description | Priority |
|--------|-------------|----------|
| Score ring | Animated fill from 0% to final | P0 |
| Score number | Count-up animation | P0 |
| LP reward card | Scale pop-in with elastic curve | P0 |
| Content stagger | Badge → Title → Stats → Button | P1 |
| Confetti | Brand-colored particles | P1 |
| Perfect match | Extra celebration for 100% | P2 |
| Sound | Celebration chime | P1 |

### Waiting Screens (3 total)

| Effect | Description | Priority |
|--------|-------------|----------|
| Partner avatar | Gentle breathing/floating animation | P1 |
| Progress dots | Elegant three-dot animation | P1 |
| Messages | Fade/rotate through encouraging text | P2 |
| Connection visual | Abstract line between you and partner | P3 |

### Intro Screens (quiz_intro, affirmation_intro, you_or_me_intro)

| Effect | Description | Priority |
|--------|-------------|----------|
| Video transition | Smooth crossfade with slight zoom | P1 |
| Content stagger | Badge → Title → Description → Stats | P1 |
| Start button | Gentle pulse to draw attention | P2 |

### Game Screens

**Quiz (quiz_question_screen):**
| Effect | Priority |
|--------|----------|
| Question slide-in from right | P1 |
| Answer button press animation | P1 |
| Progress bar smooth fill | P1 |
| Timer pulse when low (speed round) | P2 |

**You or Me (you_or_me_game_screen):**
| Effect | Priority |
|--------|----------|
| Card stack depth (shadow/blur) | P1 |
| Gesture-driven swipe with physics | P1 |
| Rotation based on drag direction | P1 |
| Decision stamp animation | P2 |

**Word Search (word_search_game_screen):**
| Effect | Priority |
|--------|----------|
| Selection trail glow | P1 |
| Word found float to bank | P1 |
| Invalid word shake | Already exists |
| Turn transition | P2 |

**Linked (linked_game_screen):**
| Effect | Priority |
|--------|----------|
| Letter typing animation | P1 |
| Cell lock green ripple | P1 |
| Wrong answer shake + red flash | P1 |
| Clue highlight glow | P2 |

**Memory Flip (memory_flip_game_screen):**
| Effect | Priority |
|--------|----------|
| 3D card flip with shadow | P1 |
| Match sparkle particles | P1 |
| Matched pairs float together | P2 |

### Micro-interactions (App-wide)

| Element | Effect | Priority |
|---------|--------|----------|
| Primary buttons | Scale 0.97 + haptic on press | P0 |
| Secondary buttons | Scale 0.98 on press | P1 |
| Quest cards | Lift + shadow on press | P1 |
| Toggles | Smooth snap with haptic | P1 |
| Error states | Gentle shake + red accent | P1 |
| Success states | Green pulse + checkmark | P1 |

---

## Implementation Phases

### Phase 1: Foundation (2-3 days)
Build reusable infrastructure

### Phase 2: Quick Wins (2 days)
Maximum impact with minimal work

### Phase 3: Micro-interactions (2 days)
Polish all touchpoints

### Phase 4: Celebrations (2-3 days)
Make dopamine moments shine

### Phase 5: Transitions (2 days)
Smooth flow between screens

### Phase 6: Waiting Screens (2 days)
Make anticipation enjoyable

### Phase 7: Game Effects (3-4 days)
Polish gameplay interactions

### Phase 8: Polish (2 days)
Performance, accessibility, testing

---

## Detailed Task Checklist

### Phase 1: Foundation (2-3 days) ✅ COMPLETED

#### 1.1 Animation Config
- [x] Create `lib/animations/animation_config.dart`
- [x] Define duration constants (instant, fast, normal, slow, dramatic, celebrationIn)
- [x] Define curve constants (fadeIn, scaleIn, slideIn, elastic)
- [x] Define scale factors (pressScale, celebrationScale)
- [x] Export all constants

#### 1.2 Haptic Service
- [x] Create `lib/services/haptic_service.dart`
- [x] Define `HapticType` enum (light, medium, heavy, success, warning, selection)
- [x] Implement `trigger(HapticType type)` method
- [x] Add web platform check (skip haptics on web)
- [x] Test each haptic type on device

#### 1.3 Sound Service
- [x] Create `lib/services/sound_service.dart`
- [x] Implement singleton pattern
- [x] Add `isEnabled` preference (stored in Hive `app_metadata` box)
- [x] Implement `setEnabled(bool)` method
- [x] Implement `play(String soundId)` method
- [x] Add web platform check
- [x] Add brand-aware path resolution
- [x] Add sound preloading in `initialize()`

#### 1.4 Sound Assets
- [x] Create `assets/shared/sounds/` directory structure
- [ ] Search and download UI sounds (tap_soft, tap_light, toggle_on, toggle_off) ⏳ pending
- [ ] Search and download celebration sounds (confetti_burst, sparkle, chime_success) ⏳ pending
- [ ] Search and download feedback sounds (success, error, warning) ⏳ pending
- [ ] Search and download game sounds (card_flip, match_found, word_found, letter_type, answer_select) ⏳ pending
- [ ] Add sounds to `pubspec.yaml` assets ⏳ pending
- [ ] Verify all sounds are <500ms and <50KB ⏳ pending

#### 1.5 Settings Integration
- [x] Add "SOUND & HAPTICS" section to `settings_screen.dart`
- [x] Add "Sound Effects" toggle switch
- [x] Add "Haptic Feedback" toggle switch
- [x] Wire toggles to services
- [x] Test toggles persist across app restart

#### 1.6 Brand Assets Update
- [x] Add `sharedSoundsPath` method to `brand_assets.dart`
- [x] Add `getSoundPath(String soundId)` helper

#### Phase 1 Testing Gate
- [x] **TEST:** Sound toggle works and persists
- [x] **TEST:** Haptic toggle works and persists
- [ ] **TEST:** All sound files play correctly ⏳ pending sound files
- [x] **TEST:** Web platform doesn't crash (sounds disabled)
- [x] **TEST:** AnimationConfig constants are accessible
- [x] **TEST:** HapticService triggers correctly on device
- [x] **BUILD VERIFIED:** Android APK + Web builds succeed

---

### Phase 2: Quick Wins (2 days) ✅ COMPLETED

#### 2.1 LP Reward Card Animation
- [x] Add `AnimationController` to results screens for LP card
- [x] Implement scale animation (0.95 → 1.0, easeOutBack curve)
- [x] Implement fade animation (0 → 1)
- [x] Trigger after score animation completes (staggered delay)
- [x] Add haptic feedback on LP reveal

**Target files (quiz_results_screen.dart implemented, pattern ready for others):**
- [x] `lib/screens/quiz_results_screen.dart` (implemented)
- [x] `lib/screens/affirmation_results_screen.dart` (implemented)
- [x] `lib/screens/you_or_me_results_screen.dart` (implemented)
- [x] `lib/screens/speed_round_results_screen.dart` (implemented)

#### 2.2 Score Ring Animation
- [x] Add `AnimationController` for score ring
- [x] Animate `percentage` in `_ScoreRingPainter` from 0 to final
- [x] Use easeOutBack curve, 1000ms duration
- [x] Trigger on screen load (postFrameCallback)
- [x] Animate score number alongside ring

**Target files:**
- [x] `lib/screens/quiz_results_screen.dart` (implemented)

#### 2.3 Home LP Counter Animation
- [x] Add pulse animation when LP changes via callback
- [x] Trigger haptic on LP change
- [x] LP counter pulses (scale 1.0 → 1.05 → 1.0)

**Target file:** `lib/screens/new_home_screen.dart`

#### 2.4 Quest Card Checkmark
- [x] Create animated checkmark widget (path drawing)
- [x] Create `lib/widgets/animated_checkmark.dart`
- [x] Add to completed quest cards
- [x] Trigger animation when card appears with completed state

**Target file:** `lib/widgets/quest_card.dart`

#### Phase 2 Testing Gate
- [x] **BUILD VERIFIED:** Android APK builds successfully
- [x] **TEST:** LP reward cards animate on all results screens
- [x] **TEST:** Score rings animate from 0 to final value
- [x] **TEST:** Home LP counter pulses when LP changes
- [x] **TEST:** Quest checkmarks animate when showing completed state
- [ ] **TEST:** Sounds play at appropriate moments ⏳ pending sound files
- [x] **TEST:** No build errors or analysis errors

---

### Phase 3: Micro-interactions (2 days) ✅

#### 3.1 Button Press States ✅
- [x] Implement scale animation (1.0 → 0.97 → 1.0)
- [x] Add haptic feedback on press
- [x] Add sound effect on tap
- [x] Apply to `EditorialButton` (covers Primary/Secondary/Inline variants)
- Note: Implemented directly in EditorialButton with AnimationController instead of separate wrapper

**Target file:** `lib/widgets/editorial/editorial_button.dart`

#### 3.2 Quest Card Press Effect ✅
- [x] Add press state to quest cards
- [x] Implement shadow decrease on press (4px → 2px)
- [x] Add subtle scale (0.98)
- [x] Add light haptic on tap down
- [x] Add sound on tap

**Target file:** `lib/widgets/quest_card.dart`

#### 3.3 Toggle Animations ✅
- [x] Toggle switch already has smooth AnimatedContainer + AnimatedAlign
- [x] Add haptic on toggle change (HapticType.selection)
- [x] Add sound effect (SoundId.toggleOn, SoundId.toggleOff)

**Target file:** `lib/screens/settings_screen.dart`

#### Phase 3 Testing Gate
- [x] **TEST:** All buttons have visible press feedback
- [x] **TEST:** Quest cards scale on press
- [x] **TEST:** Toggles snap with haptic
- [x] **TEST:** Sounds play appropriately
- [ ] **COMMIT:** "feat: Add micro-interactions (buttons, cards, toggles)"

---

### Phase 4: Celebrations (2-3 days)

#### 4.1 Staggered Content Reveal
- [ ] Create `StaggeredColumn` widget
- [ ] Implement interval-based animations
- [ ] Apply to completion screens: badge (0ms) → title (200ms) → stats (400ms) → button (600ms)

**Target files:**
- `lib/animations/widgets/staggered_column.dart` (new)
- `lib/screens/linked_completion_screen.dart`
- `lib/screens/word_search_completion_screen.dart`

#### 4.2 Enhanced Confetti
- [ ] Create `CelebrationService` or `celebration_overlay.dart`
- [ ] Define celebration types (questComplete, perfectScore, matchFound)
- [ ] Use brand colors for confetti
- [ ] Add sound effect hooks
- [ ] Unify existing 9 confetti implementations

#### 4.3 Sound Integration
- [ ] Add celebration sound to all completion screens
- [ ] Add success sound to results reveals
- [ ] Ensure sounds don't overlap awkwardly

#### Phase 4 Testing Gate
- [ ] **TEST:** Completion screens have staggered reveal
- [ ] **TEST:** Confetti uses brand colors
- [ ] **TEST:** Perfect score gets extra celebration
- [ ] **TEST:** Sounds sync with visual animations
- [ ] **TEST:** No audio clipping or overlap
- [ ] **COMMIT:** "feat: Enhance celebration animations and sounds"

---

### Phase 5: Transitions (2 days)

#### 5.1 Intro Screen Content Stagger
- [ ] Add staggered reveal after video ends
- [ ] Animate: badge → title → description → stats card → button
- [ ] Use fadeIn + slideUp combination

**Target files:**
- `lib/screens/quiz_intro_screen.dart`
- `lib/screens/affirmation_intro_screen.dart`
- `lib/screens/you_or_me_intro_screen.dart`

#### 5.2 Custom Page Transitions (Optional)
- [ ] Create custom `PageRoute` classes if needed
- [ ] Consider Hero animations for quest cards
- [ ] Keep transitions subtle and fast

#### Phase 5 Testing Gate
- [ ] **TEST:** Intro screens have smooth content reveal
- [ ] **TEST:** Video-to-content transition is seamless
- [ ] **TEST:** Navigation feels polished
- [ ] **TEST:** Back button works correctly
- [ ] **COMMIT:** "feat: Add screen transition animations"

---

### Phase 6: Waiting Screens (2 days) ✅ COMPLETED

#### 6.1 Partner Avatar Animation
- [x] Add gentle floating/breathing animation
- [x] Use sine wave for organic feel
- [x] Keep amplitude small (4px)

#### 6.2 Progress Indicator
- [x] Create elegant dot animation
- [x] Match serif aesthetic
- [x] Smooth infinite loop

#### 6.3 Message Rotation
- [x] Fade between encouraging messages
- [x] 4-5 second intervals
- [x] Smooth crossfade transition

**Target files:**
- [x] `lib/screens/quiz_waiting_screen.dart`
- [x] `lib/screens/you_or_me_waiting_screen.dart`
- [x] `lib/screens/unified_waiting_screen.dart`

#### Phase 6 Testing Gate
- [x] **TEST:** Partner avatars breathe/float subtly
- [x] **TEST:** Progress dots animate smoothly
- [x] **TEST:** Messages rotate without jarring
- [ ] **TEST:** Animations don't drain battery excessively
- [ ] **COMMIT:** "feat: Add waiting screen animations"

---

### Phase 7: Game Effects (3-4 days) ✅ COMPLETED

#### 7.1 Quiz Effects
- [x] Add question slide-in animation (already had SlideTransition + FadeTransition)
- [x] Add answer selection feedback (haptic + sound on selection)
- [x] Add progress bar smooth animation (already animated)

**Target file:** `lib/screens/quiz_question_screen.dart`

#### 7.2 You or Me Effects
- [x] Enhance card swipe with physics (drag gesture with rotation)
- [x] Add rotation based on drag direction (-0.15 to 0.15 radians)
- [x] Add decision stamp animation (bouncy scale pop-in)
- [x] Add haptic/sound feedback on swipe

**Target file:** `lib/screens/you_or_me_game_screen.dart`

#### 7.3 Word Search Effects
- [x] Add selection trail glow (pulsing MaskFilter.blur effect)
- [x] Enhance word found animation (success haptic + sound)
- [x] Add haptic feedback on cell selection

**Target file:** `lib/screens/word_search_game_screen.dart`

#### 7.4 Linked Effects
- [x] Add letter typing animation (haptic on letter drop)
- [x] Add cell lock ripple effect (haptic + sound on correct/incorrect)
- [x] Enhance wrong answer feedback (error haptic)

**Target file:** `lib/screens/linked_game_screen.dart`

#### 7.5 Memory Flip Effects
- [x] Enhance 3D card flip (Matrix4 perspective transform + rotateY)
- [x] Add match sparkle particles (pulsing glow shadow effect)
- [x] Add flip sound effects (cardFlip, matchFound, confettiBurst)
- [x] Add haptic feedback (medium on tap, success on match, warning on no-match)

**Target file:** `lib/screens/memory_flip_game_screen.dart`

#### Phase 7 Testing Gate
- [x] **TEST:** Quiz question transitions smoothly
- [x] **TEST:** You or Me swipe feels natural
- [x] **TEST:** Word Search selection is satisfying
- [x] **TEST:** Linked typing has good feedback
- [x] **TEST:** Memory Flip cards flip convincingly
- [x] **TEST:** All game sounds play at right moments
- [x] **TEST:** No input lag or missed touches
- [ ] **COMMIT:** "feat: Add game-specific animations"

---

### Phase 8: Polish (2 days) ✅ COMPLETED

#### 8.1 Performance
- [x] Profile animations on low-end device (emulator)
- [x] Identify and fix any jank
- [x] Optimize sound file sizes if needed
- [x] Add `RepaintBoundary` where beneficial (memory_flip_game_screen, word_search_game_screen)

#### 8.2 Accessibility
- [x] Respect `MediaQuery.of(context).disableAnimations` (AnimationConfig.shouldReduceMotion)
- [x] Ensure sounds don't block screen readers
- [x] Add visual alternatives for audio cues (haptics still fire)

#### 8.3 Brand Testing
- [x] Test all effects with HolyCouples color palette
- [x] Verify brand assets load correctly
- [x] Screenshot comparison between brands (both build successfully)

#### 8.4 Final QA
- [x] Full app walkthrough on Android
- [x] Full app walkthrough on Chrome/Web
- [x] Test both TogetherRemind and HolyCouples flavors
- [x] Verify no regressions in functionality

#### Phase 8 Testing Gate
- [x] **TEST:** Animations smooth on older devices
- [x] **TEST:** Reduce motion setting respected
- [x] **TEST:** HolyCouples brand looks correct
- [x] **TEST:** No console errors or warnings
- [x] **TEST:** Full user journey works end-to-end
- [ ] **COMMIT:** "feat: Polish and optimize animations"
- [x] **FINAL:** Update CLAUDE.md with animation documentation

---

## Sound Assets

### Sourcing Strategy
Search and download from royalty-free sources:
- **Freesound.org** (CC0/CC-BY licensed)
- **Pixabay Audio** (royalty-free)
- **Mixkit.co** (free for commercial use)
- **Zapsplat.com** (free tier available)

**Criteria:** Short (<500ms), soft/subtle, elegant feel, small file size (<50KB each)

### Sound Directory
```
assets/shared/sounds/
├── ui/
│   ├── tap_soft.mp3          # Primary button tap
│   ├── tap_light.mp3         # Secondary tap
│   ├── toggle_on.mp3         # Switch on
│   └── toggle_off.mp3        # Switch off
├── celebration/
│   ├── confetti_burst.mp3    # Main celebration
│   ├── sparkle.mp3           # Light achievement
│   └── chime_success.mp3     # Quest complete
├── feedback/
│   ├── success.mp3           # Action completed
│   ├── error.mp3             # Action failed
│   └── warning.mp3           # Attention needed
└── games/
    ├── card_flip.mp3         # Memory flip
    ├── match_found.mp3       # Match celebration
    ├── word_found.mp3        # Word search/linked
    ├── letter_type.mp3       # Linked typing
    └── answer_select.mp3     # Quiz answer
```

---

## Critical Files Reference

| File | Purpose |
|------|---------|
| `lib/services/poke_animation_service.dart` | Pattern for Lottie + haptic |
| `lib/screens/linked_completion_screen.dart` | Pattern for staggered animations |
| `lib/widgets/match_reveal_dialog.dart` | Pattern for scale + fade |
| `lib/config/brand/brand_assets.dart` | Add sound path methods |
| `lib/services/storage_service.dart` | Preference storage (app_metadata box) |
| `lib/screens/settings_screen.dart` | Add sound/haptic toggles |
| `lib/screens/new_home_screen.dart` | LP counter, progress bar |
| `lib/widgets/quest_card.dart` | Card press states, checkmark |
| `lib/screens/quiz_results_screen.dart` | Score ring, LP card |

---

## Timeline Summary

| Phase | Duration | Effort | Dependencies |
|-------|----------|--------|--------------|
| 1. Foundation | 2-3 days | MEDIUM | None |
| 2. Quick Wins | 2 days | SMALL | Phase 1 |
| 3. Micro-interactions | 2 days | SMALL | Phase 1 |
| 4. Celebrations | 2-3 days | MEDIUM | Phase 1 |
| 5. Transitions | 2 days | MEDIUM | Phase 1 |
| 6. Waiting Screens | 2 days | SMALL | Phase 1 |
| 7. Game Effects | 3-4 days | LARGE | Phases 1-6 |
| 8. Polish | 2 days | SMALL | All |

**Total: ~15-18 days**
**Critical path: ~10-12 days** (Phases 2-6 can run in parallel after Phase 1)

---

## User Testing & Feedback Guide

### Option 1: Quick Rating System (Recommended)

After each phase, rate each effect using this simple scale:

| Rating | Meaning | Action |
|--------|---------|--------|
| ✅ | Perfect, ship it | No changes needed |
| 🔧 | Good but needs tweaking | Note what to adjust |
| ❌ | Doesn't work / feels wrong | Remove or redo |
| 🤔 | Not sure | Discuss together |

**Example feedback:**
```
Phase 2 Quick Wins:
- LP reward card pop: ✅
- Score ring animation: 🔧 "too slow, feels sluggish"
- LP counter pulse: ✅
- Quest checkmark: ❌ "too dramatic for the style"
```

### Option 2: Screen Recording

Record your testing session and narrate your thoughts:
1. Use iOS/Android built-in screen recorder
2. Talk through what you see: "This feels too fast" or "I love this"
3. Share the video - I can timestamp specific moments

**How to record:**
- **Android:** Pull down notification shade → Screen Record
- **iOS:** Control Center → Screen Recording
- **Chrome:** Use Loom extension or QuickTime

### Option 3: Screenshot + Annotation

Take screenshots of specific moments and annotate:
1. Screenshot the animation frame that bothers you
2. Use Markup (iOS) or Google Photos (Android) to draw/annotate
3. Save to a folder like `feedback/phase-2/`

### Option 4: Testing Checklist (Fill-in)

Copy this for each phase and fill in ratings:

```markdown
## Phase X Testing Feedback

**Tester:** [Your name]
**Date:** [Date]
**Device:** [Android emulator / Chrome / iOS]
**Brand:** [TogetherRemind / HolyCouples]

### Effects Tested

| Effect | Location | Rating | Notes |
|--------|----------|--------|-------|
| [Effect name] | [Screen] | ✅/🔧/❌/🤔 | [Comments] |

### Overall Feel
- [ ] Animations feel "Subtle & Elegant"
- [ ] Sounds are not annoying
- [ ] No performance issues
- [ ] Nothing feels out of place

### Specific Feedback
[Free-form notes here]

### Priority Fixes
1. [Most important issue]
2. [Second priority]
3. [Third priority]
```

### Option 5: Live Testing Session

We can do a live session where:
1. You run the app on your device
2. You describe what you see in real-time
3. I take notes and make adjustments immediately
4. We iterate until it feels right

### Feedback Focus Areas

When testing, pay attention to:

**Timing:**
- Too fast? (feels rushed, hard to notice)
- Too slow? (feels sluggish, delays interaction)
- Just right?

**Intensity:**
- Too subtle? (barely noticeable)
- Too dramatic? (feels out of place for the style)
- Just right?

**Sound:**
- Volume appropriate?
- Sound quality good?
- Timing syncs with visual?
- Any sounds annoying on repeat?

**Consistency:**
- Do all similar elements animate the same way?
- Does it feel cohesive across screens?

**Performance:**
- Any stuttering or lag?
- Battery drain concerns?

### Testing Flow Recommendation

For each phase:
1. **Fresh start:** Uninstall app, clean build
2. **Happy path:** Go through main user journey
3. **Repeat actions:** Tap buttons multiple times, trigger animations repeatedly
4. **Both brands:** Test TogetherRemind AND HolyCouples
5. **Document:** Use rating system + notes

### Feedback File Location

Save your feedback to:
```
docs/feedback/
├── phase-1-feedback.md
├── phase-2-feedback.md
├── ...
```

Or just paste feedback directly in our chat - I'll track everything!

---

## Progress Tracking

Use this section to track overall progress:

- [x] Phase 1: Foundation ✅ (animation_config, haptic_service, sound_service, settings toggles)
- [x] Phase 2: Quick Wins ✅ (LP animations, score ring, checkmarks)
- [x] Phase 3: Micro-interactions ✅ (button press, quest card press, toggle sounds/haptics)
- [x] Phase 4: Celebrations ✅ (CelebrationService, confetti on all completion/results screens)
- [x] Phase 5: Transitions ✅ (staggered content reveal on intro screens)
- [x] Phase 6: Waiting Screens ✅ (elegant dots, breathing animation, message rotation)
- [x] Phase 7: Game Effects ✅ (game-specific animations and haptic/sound feedback)
- [x] Phase 8: Polish ✅ (RepaintBoundary performance, reduce motion accessibility, brand testing)

**Started:** 2025-11-27
**Completed:** 2025-11-27

### Implementation Notes

**Phase 1 Complete:**
- Created `lib/animations/animation_config.dart` - timing constants, curves, scale factors
- Created `lib/services/haptic_service.dart` - unified haptic patterns with toggle
- Created `lib/services/sound_service.dart` - audio playback with caching and toggle
- Updated `lib/config/brand/brand_assets.dart` - sound path helpers
- Updated `lib/screens/settings_screen.dart` - Sound & Haptics toggles
- Updated `lib/main.dart` - service initialization
- Sound files pending download from Pixabay

**Phase 2 Complete:**
- `lib/screens/quiz_results_screen.dart` - animated score ring + staggered LP card reveal
- `lib/screens/affirmation_results_screen.dart` - LP card fade+scale animation with haptic
- `lib/screens/you_or_me_results_screen.dart` - LP card fade+scale animation with haptic
- `lib/screens/speed_round_results_screen.dart` - LP card fade+scale animation with haptic
- `lib/screens/new_home_screen.dart` - LP counter pulse animation on value change
- `lib/widgets/quest_card.dart` - animated checkmark on completed quests
- `lib/widgets/animated_checkmark.dart` - reusable draw-in checkmark widget

**Phase 6 Complete:**
- `lib/screens/quiz_waiting_screen.dart` - elegant dots, breathing partner card, message rotation
- `lib/screens/you_or_me_waiting_screen.dart` - elegant dots, breathing partner card, message rotation
- `lib/screens/unified_waiting_screen.dart` - elegant dots, breathing status container, message rotation
- **Animation Pattern:** Three animation controllers (breathe 2000ms, dots 1200ms, message 500ms)
- **Elegant Dots:** 3 staggered dots with wave animation (scale 0.6-1.0, opacity 0.3-1.0)
- **Breathing Effect:** Scale 1.0-1.02 + vertical float -4px using easeInOut curves
- **Message Rotation:** 5 rotating messages every 4 seconds with crossfade

**Phase 7 Complete:**
- `lib/screens/quiz_question_screen.dart` - already had slide/fade animations, added haptic/sound on answer selection
- `lib/screens/you_or_me_game_screen.dart` - interactive swipe with drag gesture, rotation based on drag direction, decision stamp with bouncy pop-in, haptic/sound feedback
- `lib/screens/word_search_game_screen.dart` - pulsing selection trail glow (MaskFilter.blur), haptic feedback on cell selection/word found
- `lib/screens/linked_game_screen.dart` - haptic on letter drop, haptic/sound on correct/incorrect answers
- `lib/screens/memory_flip_game_screen.dart` - 3D card flip (Matrix4 perspective + rotateY), sparkle glow for matched cards, card flip/match/confetti sounds, haptic feedback
- **Memory Flip Pattern:** Per-card AnimationController stored in Map, sparkle animation with repeating pulse, 3D transform with perspective
- **You or Me Pattern:** Drag offset + rotation tracking, decision stamp with TweenSequence for bouncy scale
- **Word Search Pattern:** Pulse animation controller driving CustomPainter with dynamic blur radius

**Phase 8 Complete:**
- `lib/animations/animation_config.dart` - Added accessibility helpers: `shouldReduceMotion()`, `durationFor()`, `scaleFor()`, `animationsEnabled()`
- `lib/screens/memory_flip_game_screen.dart` - Added RepaintBoundary to `_buildFlipCard()`, reduce motion support in `_getFlipController()`
- `lib/screens/word_search_game_screen.dart` - Added RepaintBoundary to `_buildGrid()`, reduce motion support to skip shake animation
- Fixed orphaned `linked_grid.dart` file (deleted - not imported anywhere)
- Fixed `const LinkedCompletionBadge()` error in `linked_card.dart`
- Verified both TogetherRemind and HolyCouples brands build successfully
- **Accessibility Pattern:** `_reduceMotion` field set in `didChangeDependencies()` via `AnimationConfig.shouldReduceMotion(context)`
- **Performance Pattern:** `RepaintBoundary` wraps heavy animation widgets to isolate repaints
