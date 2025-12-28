# Screen Inventory

Quick reference of all screens in the app.

## Auth & Onboarding

| Screen | File | Description |
|--------|------|-------------|
| Onboarding | `onboarding_screen.dart` | Entry screen with Apple/OTP sign-in options |
| Auth | `auth_screen.dart` | Email entry for OTP authentication |
| OTP Verification | `otp_verification_screen.dart` | Enter OTP code sent to email |
| Name Entry | `name_entry_screen.dart` | User enters their display name |
| Pairing | `pairing_screen.dart` | Generate or enter partner pairing code |

## Main Navigation

| Screen | File | Description |
|--------|------|-------------|
| Main | `main_screen.dart` | Bottom nav shell (Home, Activity, Profile, Settings) |
| Home | `home_screen.dart` | Daily quests, side quests, LP counter |
| Activity Hub | `activity_hub_screen.dart` | Activity feed with filters (all, your turn, unread, completed) |
| Inbox | `inbox_screen.dart` | Reminders and pokes inbox |
| Profile | `profile_screen.dart` | User profile and stats |
| Settings | `settings_screen.dart` | App settings and preferences |

## Welcome Quiz (Onboarding Game)

| Screen | File | Description |
|--------|------|-------------|
| Intro | `welcome_quiz_intro_screen.dart` | Introduction to Welcome Quiz |
| Game | `welcome_quiz_game_screen.dart` | Answer quiz questions |
| Waiting | `welcome_quiz_waiting_screen.dart` | Wait for partner to complete |
| Results | `welcome_quiz_results_screen.dart` | Show match results |

## Classic & Affirmation Quiz

| Screen | File | Description |
|--------|------|-------------|
| Classic Intro | `quiz_intro_screen.dart` | Introduction to Classic Quiz |
| Affirmation Intro | `affirmation_intro_screen.dart` | Introduction to Affirmation Quiz |
| Game | `quiz_match_game_screen.dart` | Shared quiz gameplay (both types) |
| Waiting | `quiz_match_waiting_screen.dart` | Wait for partner to complete |
| Results | `quiz_match_results_screen.dart` | Show match results |

## You or Me

| Screen | File | Description |
|--------|------|-------------|
| Intro | `you_or_me_match_intro_screen.dart` | Introduction to You or Me game |
| Game | `you_or_me_match_game_screen.dart` | Answer "You" or "Me" questions |
| Waiting | `you_or_me_match_waiting_screen.dart` | Wait for partner to complete |
| Results | `you_or_me_match_results_screen.dart` | Show comparison results |

## Linked (Crossword Puzzle)

| Screen | File | Description |
|--------|------|-------------|
| Intro | `linked_intro_screen.dart` | Introduction to Linked puzzle |
| Game | `linked_game_screen.dart` | Turn-based crossword puzzle gameplay |
| Completion | `linked_completion_screen.dart` | Puzzle completed celebration |

## Word Search

| Screen | File | Description |
|--------|------|-------------|
| Intro | `word_search_intro_screen.dart` | Introduction to Word Search |
| Game | `word_search_game_screen.dart` | Find hidden words gameplay |
| Completion | `word_search_completion_screen.dart` | Puzzle completed celebration |

## Steps Together

| Screen | File | Description |
|--------|------|-------------|
| Intro | `steps_intro_screen.dart` | Introduction to Steps Together feature |
| Counter | `steps_counter_screen.dart` | View step counts and progress |
| Claim | `steps_claim_screen.dart` | Claim LP rewards for steps |

## Daily Pulse

| Screen | File | Description |
|--------|------|-------------|
| Question | `daily_pulse_screen.dart` | Daily question - answer about self or predict partner |
| Results | `daily_pulse_results_screen.dart` | Show if prediction matched |

## Other Screens

| Screen | File | Description |
|--------|------|-------------|
| Send Reminder | `send_reminder_screen.dart` | Create and send reminder to partner |
| Data Validation | `debug/data_validation_screen.dart` | Debug tool for validating data |

---

# Overlays, Sheets & Dialogs

These UI components appear on top of screens rather than being screens themselves.

## Bottom Sheets

Slide up from the bottom of the screen.

| Component | File | Description |
|-----------|------|-------------|
| Poke | `widgets/poke_bottom_sheet.dart` | Send emoji poke to partner with rate limiting |
| Remind | `widgets/remind_bottom_sheet.dart` | Send reminder with quick messages and scheduling |
| Leaderboard | `widgets/leaderboard_bottom_sheet.dart` | View global, country, and tier leaderboards |

## Full-Screen Overlays

Cover the entire screen with modal content.

| Component | File | Description |
|-----------|------|-------------|
| LP Intro | `widgets/lp_intro_overlay.dart` | First-time Love Points introduction after Welcome Quiz |
| Unlock Celebration | `widgets/unlock_celebration.dart` | Celebration when a new feature is unlocked |
| Poke Animation | `services/poke_animation_service.dart` | Lottie animations for send/receive/mutual pokes |

## Dialogs

Centered modal boxes requiring user action.

| Component | File | Description |
|-----------|------|-------------|
| Match Reveal | `widgets/match_reveal_dialog.dart` | Auto-dismissing reveal of match result with emoji/quote |
| Poke Response | `widgets/poke_response_dialog.dart` | Respond to received poke with option to poke back |
| Turn Complete | `widgets/linked/turn_complete_dialog.dart` | Linked game - your turn is done, partner's turn next |
| Partner First | `widgets/linked/partner_first_dialog.dart` | Linked/Word Search - partner goes first on this puzzle |
| Edit Name | (inline in `profile_screen.dart`) | Text input dialog to change display name |
| Choose Avatar | (inline in `settings_screen.dart`) | Emoji picker to change avatar |
| Logout Confirm | (inline in `profile_screen.dart`) | Confirm sign out action |

## Inline Overlays

Appear on top of specific widgets rather than full-screen.

| Component | File | Description |
|-----------|------|-------------|
| Quest Guidance | `widgets/quest_guidance_overlay.dart` | "Start Here" ribbon and floating hand pointer for onboarding |
| Flash Overlay | `widgets/animations/flash_overlay_widget.dart` | Brief screen flash effect for dramatic transitions |

## Banners & Toasts

Brief feedback that auto-dismisses.

| Component | File | Description |
|-----------|------|-------------|
| Notification Banner | `widgets/foreground_notification_banner.dart` | Top banner for push notifications received in foreground |
| Snackbars | (various screens) | Brief feedback messages at bottom of screen |

---

## Summary

### Screens

| Category | Count |
|----------|-------|
| Auth & Onboarding | 5 |
| Main Navigation | 6 |
| Welcome Quiz | 4 |
| Classic & Affirmation Quiz | 5 |
| You or Me | 4 |
| Linked | 3 |
| Word Search | 3 |
| Steps Together | 3 |
| Daily Pulse | 2 |
| Other Screens | 2 |
| **Total Screens** | **37** |

### Overlays & Dialogs

| Category | Count |
|----------|-------|
| Bottom Sheets | 3 |
| Full-Screen Overlays | 3 |
| Dialogs | 7 |
| Inline Overlays | 2 |
| Banners & Toasts | 2 |
| **Total Overlays** | **17** |

---

*Last updated: 2025-12-25*
