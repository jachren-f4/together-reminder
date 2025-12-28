# Us 2.0 Brand Implementation Tracking

Tracks which screens and components have been updated with Us 2.0 brand styling.

**Brand Detection Pattern:**
```dart
bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

@override
Widget build(BuildContext context) {
  if (_isUs2) return _buildUs2Screen();
  // ... original implementation
}
```

---

## Auth & Onboarding

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Onboarding | `onboarding_screen.dart` | ✅ | Logo, hearts symbol, Get Started button |
| Auth | `auth_screen.dart` | ✅ | Email input, info card, step indicator |
| OTP Verification | `otp_verification_screen.dart` | ✅ | 8-digit boxes, resend link |
| Name Entry | `name_entry_screen.dart` | ✅ | Emoji circle, text input |
| Pairing | `pairing_screen.dart` | ✅ | Code display, partner code input, success state |

## Main Navigation

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Main | `main_screen.dart` | ✅ | Us2BottomNav with colored icons |
| Home | `home_screen.dart` | ✅ | Uses Us2HomeContent widget |
| Activity Hub | `activity_hub_screen.dart` | ❌ | |
| Inbox | `inbox_screen.dart` | ❌ | |
| Profile | `profile_screen.dart` | ✅ | Hero stats, arena, progress bar, activity table |
| Settings | `settings_screen.dart` | ✅ | Partner banner, gradient toggles, picker, steps |

## Welcome Quiz (Onboarding Game)

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Intro | `welcome_quiz_intro_screen.dart` | ✅ | Gradient bg, info card, glow button |
| Game | `welcome_quiz_game_screen.dart` | ✅ | Progress bar, answer options with gradient selection |
| Waiting | `welcome_quiz_waiting_screen.dart` | ✅ | Pulsing emoji, checklist, coming up next |
| Results | `welcome_quiz_results_screen.dart` | ✅ | Score with gradient, question cards with match badges |

## Classic & Affirmation Quiz

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Classic Intro | `quiz_intro_screen.dart` | ✅ | Uses Us2IntroScreen component |
| Affirmation Intro | `affirmation_intro_screen.dart` | ✅ | Uses Us2IntroScreen component |
| Game | `quiz_match_game_screen.dart` | ✅ | Both classic (A/B/C/D) and affirmation (1-5 scale) |
| Waiting | `quiz_match_waiting_screen.dart` | ✅ | Animated dots, partner status |
| Results | `quiz_match_results_screen.dart` | ✅ | Aligned/different counts, question cards |

## You or Me

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Intro | `you_or_me_match_intro_screen.dart` | ✅ | Uses Us2IntroScreen component |
| Game | `you_or_me_match_game_screen.dart` | ✅ | Card swipe preserved, Us2 styling |
| Waiting | `game_waiting_screen.dart` | ✅ | Unified screen, gradient dots, partner card with glow |
| Results | `you_or_me_match_results_screen.dart` | ✅ | Question comparison cards |

## Linked (Crossword Puzzle)

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Intro | `linked_intro_screen.dart` | ✅ | Uses Us2IntroScreen |
| Game | `linked_game_screen.dart` | ✅ | Gold frame, letter tiles, clue cells |
| Completion | `linked_completion_screen.dart` | ✅ | |

## Word Search

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Intro | `word_search_intro_screen.dart` | ✅ | Uses Us2IntroScreen |
| Game | `word_search_game_screen.dart` | ✅ | |
| Completion | `word_search_completion_screen.dart` | ✅ | |

## Steps Together

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Intro | `steps_intro_screen.dart` | ✅ | Gradient bg, white cards, gradient buttons with glow |
| Counter | `steps_counter_screen.dart` | ✅ | Gradient ring (DualRingPainter updated), yesterday claim section |
| Claim | `steps_claim_screen.dart` | ✅ | Hero gradient, partner cards, confetti preserved |

## Daily Pulse

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Question | `daily_pulse_screen.dart` | ❌ | |
| Results | `daily_pulse_results_screen.dart` | ❌ | |

## Other Screens

| Screen | File | Us 2.0 Status | Notes |
|--------|------|:-------------:|-------|
| Send Reminder | `send_reminder_screen.dart` | ✅ | Gradient cards, time picker, quick messages |
| Game Waiting | `game_waiting_screen.dart` | ✅ | Gradient bg, animated partner card, glow buttons |

---

# Overlays, Sheets & Dialogs

**HTML Mockups:** All overlay mockups available in `mockups/us2-*.html` (see `us2-mockups-index.html`)

## Bottom Sheets

| Component | File | Us 2.0 Status | Mockup |
|-----------|------|:-------------:|:------:|
| Poke | `widgets/poke_bottom_sheet.dart` | ✅ | ✅ `us2-poke-bottom-sheet.html` |
| Remind | `widgets/remind_bottom_sheet.dart` | ✅ | ✅ `us2-remind-bottom-sheet.html` |
| Leaderboard | `widgets/leaderboard_bottom_sheet.dart` | ✅ | ✅ `us2-leaderboard-bottom-sheet.html` |

## Full-Screen Overlays

| Component | File | Us 2.0 Status | Mockup |
|-----------|------|:-------------:|:------:|
| LP Intro | `widgets/lp_intro_overlay.dart` | ✅ | ✅ `us2-lp-intro-overlay.html` |
| Unlock Celebration | `widgets/unlock_celebration.dart` | ✅ | ✅ `us2-unlock-celebration.html` |
| Poke Animation | `services/poke_animation_service.dart` | ❌ | — |

## Dialogs

| Component | File | Us 2.0 Status | Mockup |
|-----------|------|:-------------:|:------:|
| Match Reveal | `widgets/match_reveal_dialog.dart` | ✅ | ✅ `us2-match-reveal-dialog.html` |
| Poke Response | `widgets/poke_response_dialog.dart` | ✅ | ✅ `us2-poke-response-dialog.html` |
| Turn Complete | `widgets/linked/turn_complete_dialog.dart` | ✅ | ✅ `us2-turn-complete-dialog.html` |
| Partner First | `widgets/linked/partner_first_dialog.dart` | ✅ | ✅ `us2-partner-first-dialog.html` |

## Inline Overlays

| Component | File | Us 2.0 Status | Mockup |
|-----------|------|:-------------:|:------:|
| Quest Guidance | `widgets/quest_guidance_overlay.dart` | ✅ | ✅ `us2-quest-guidance-overlay.html` |
| Flash Overlay | `widgets/animations/flash_overlay_widget.dart` | ❌ | — |

---

## Us 2.0 Shared Components

These components provide Us 2.0 styling that can be reused across screens.

| Component | File | Description |
|-----------|------|-------------|
| Us2Theme | `config/brand/us2_theme.dart` | Colors, gradients, typography, shadows |
| Us2HomeContent | `widgets/brand/us2/us2_home_content.dart` | Home screen content |
| Us2IntroScreen | `widgets/brand/us2/us2_intro_screen.dart` | Base intro screen template |
| Us2QuestCard | `widgets/brand/us2/us2_quest_card.dart` | Quest card with salmon gradient |
| Us2ConnectionBar | `widgets/brand/us2/us2_connection_bar.dart` | LP progress bar with heart |
| Us2Logo | `widgets/brand/us2/us2_logo.dart` | Pacifico font logo with glow |
| Us2SectionHeader | `widgets/brand/us2/us2_section_header.dart` | Ribbon-style section headers |
| Us2GlowButton | `widgets/brand/us2/us2_glow_button.dart` | Button with pink glow shadow |

---

## Progress Summary

### Screens

| Category | Total | Done | Remaining |
|----------|:-----:|:----:|:---------:|
| Auth & Onboarding | 5 | 5 | 0 |
| Main Navigation | 6 | 4 | 2 |
| Welcome Quiz | 4 | 4 | 0 |
| Classic & Affirmation Quiz | 5 | 5 | 0 |
| You or Me | 4 | 4 | 0 |
| Linked | 3 | 3 | 0 |
| Word Search | 3 | 3 | 0 |
| Steps Together | 3 | 3 | 0 |
| Daily Pulse | 2 | 0 | 2 |
| Other Screens | 2 | 2 | 0 |
| **Total Screens** | **37** | **33** | **4** |

### Overlays & Dialogs

| Category | Total | Done | Remaining |
|----------|:-----:|:----:|:---------:|
| Bottom Sheets | 3 | 3 | 0 |
| Full-Screen Overlays | 3 | 2 | 1 |
| Dialogs | 4 | 4 | 0 |
| Inline Overlays | 2 | 1 | 1 |
| **Total Overlays** | **12** | **10** | **2** |

### Overall Progress

- **Screens:** 33/37 (89%)
- **Overlays:** 10/12 (83%)
- **Combined:** 43/49 (88%)

---

## Implementation Notes

### Color Palette (Us2Theme)
- Background gradient: `#FFD1C1` → `#FFF5F0` (peach)
- Primary pink: `#FF5E62`
- Accent gradient: `#FF6B6B` → `#FF9F43` (pink to orange)
- Card salmon: `#FF7B6B`
- Cream: `#FFF8F0`
- Gold (for LP): `#C9A875`

### Typography
- Logo: Pacifico
- Headings: Playfair Display
- Body: Nunito

### Key Patterns
1. Gradient backgrounds on all screens
2. Rounded cards with subtle shadows
3. Gold-toned LP badges
4. Pink glow effects on buttons
5. Consistent header with close button + title

---

*Last updated: 2025-12-27*
