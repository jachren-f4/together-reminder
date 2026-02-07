# Single-Mode Mockup Review Checklist

Review each HTML mockup against the actual Flutter screen it represents.
For each file: read the Flutter source, extract exact values, compare to mockup, note discrepancies.

---

## 1. quiz-flow.html

**What it shows:** 5-step interactive quiz flow (intro, P1 questions, handoff, P2 questions, results)

### Step 1: Quiz Intro
- [ ] Compare against `app/lib/widgets/brand/us2/us2_intro_screen.dart` (card layout variant)
- [ ] Compare against `app/lib/screens/quiz_intro_screen.dart:508-522` (how classic quiz calls it)
- [ ] Verify: back button (40x40 white circle, arrow_back icon)
- [ ] Verify: hero image area (full-width, 180px height, 16px border-radius)
- [ ] Verify: badges row (primary=dark bg #3A3A3A, secondary=gradient, 2px border-radius)
- [ ] Verify: quiz info card (white, 12px border-radius, 4px pink left border, "TODAY'S THEME" label)
- [ ] Verify: stats card (white, 12px border-radius, label/value rows with dividers)
- [ ] Verify: instruction text (14px, Nunito, medium text color)
- [ ] Verify: "Begin Quiz" button (gradient, 30px border-radius, full-width, 18px vertical padding)
- [ ] Verify: no emojis used (hero = image placeholder, not emoji)

### Step 2 & 4: Question Screens
- [ ] Compare against `app/lib/screens/quiz_match_game_screen.dart`
- [ ] Verify: top bar layout (progress dots + player chip)
- [ ] Verify: progress dot styles (size, colors, current/filled states)
- [ ] Verify: question card styling (border-radius, padding, shadow)
- [ ] Verify: option card styling (border-radius, selected state colors)
- [ ] Verify: option radio button styling
- [ ] Verify: submit button styling
- [ ] Verify: no emojis used

### Step 3: Handoff Screen
- [ ] Compare against `app/lib/screens/game_waiting_screen.dart`
- [ ] Verify: background color/gradient
- [ ] Verify: avatar display style
- [ ] Verify: typography (title font, subtitle font, sizes)
- [ ] Verify: button styling
- [ ] Verify: no emojis (lock icon = SVG, not emoji; no eyes emoji)

### Step 5: Results Screen
- [ ] Compare against `app/lib/screens/quiz_match_results_screen.dart`
- [ ] Verify: header/title styling
- [ ] Verify: score card layout and styling
- [ ] Verify: LP badge styling
- [ ] Verify: breakdown item styling (match vs different borders)
- [ ] Verify: discuss prompt styling (uses `app/lib/widgets/worth_discussing_card.dart`)
- [ ] Verify: no emojis (confetti = icon/animation, checkmark/cross = styled elements)

---

## 2. home-screen.html

**What it shows:** Home screen with quest cards, connection bar, avatars, bottom nav

- [ ] Compare against `app/lib/widgets/brand/us2/us2_home_content.dart`
- [ ] Compare against `app/lib/widgets/brand/us2/us2_avatar_section.dart`
- [ ] Compare against `app/lib/widgets/brand/us2/us2_connection_bar.dart`
- [ ] Compare against `app/lib/widgets/brand/us2/us2_section_header.dart`
- [ ] Compare against `app/lib/widgets/brand/us2/us2_quest_card.dart`
- [ ] Compare against `app/lib/widgets/brand/us2/us2_bottom_nav.dart`
- [ ] Verify: hero section layout (Stack with fixed heights)
- [ ] Verify: avatar sizes, gradient colors, name badge positioning
- [ ] Verify: connection bar (accent gradient fill, heart icon)
- [ ] Verify: section header (ribbon-style CustomPaint)
- [ ] Verify: quest card structure (image section + content section)
- [ ] Verify: bottom nav icons (Material Icons, not emojis)
- [ ] Verify: no emojis (heart divider = SVG heart_icon.svg, quest icons = PNG images)

---

## 3. quest-card-states.html

**What it shows:** All 7 quest card states (available, pass-to-partner, completed, your-turn, partner-turn, locked, cooldown)

- [ ] Compare against `app/lib/widgets/brand/us2/us2_quest_card.dart`
- [ ] Verify: card dimensions, border-radius, shadows
- [ ] Verify: image section height and styling
- [ ] Verify: content section padding, typography
- [ ] Verify: badge/pill styling for each state
- [ ] Verify: locked state overlay styling
- [ ] Verify: completed state styling (checkmark)
- [ ] Verify: no emojis (use styled elements for icons)

---

## 4. linked-turn-flow.html

**What it shows:** Linked puzzle turn-based flow (grid, clue cells, handoff between turns)

- [ ] Compare against `app/lib/screens/linked_game_screen.dart`
- [ ] Compare against `app/lib/widgets/linked/turn_complete_dialog.dart`
- [ ] Compare against `app/lib/widgets/linked/partner_first_dialog.dart`
- [ ] Verify: grid cell sizes and colors
- [ ] Verify: clue cell rendering (inline at linked_game_screen.dart:468)
- [ ] Verify: answer colors (defined at linked_game_screen.dart:749-775)
- [ ] Verify: blocked/void cell color (#4A2C2A)
- [ ] Verify: rack tile styling
- [ ] Verify: turn indicator / player chip styling
- [ ] Verify: handoff dialog styling
- [ ] Verify: no emojis

---

## ~~5. mode-choice.html~~ — DELETED

**Reason:** Mode selection (same phone vs separate phones) moved to a settings row in `settings-profile.html` instead of a per-game screen. The "Play Mode" setting only appears after both devices are paired. Users shouldn't have to pick a mode every time they play.

---

## 6. partner-name-entry.html

**What it shows:** Onboarding screen where user enters partner's name

- [ ] Compare against `app/lib/screens/name_entry_screen.dart`
- [ ] Compare against `app/lib/screens/onboarding_screen.dart` (for overall onboarding style)
- [ ] Verify: input field styling (border, focus state, padding)
- [ ] Verify: button styling
- [ ] Verify: background gradient
- [ ] Verify: typography (heading font/size, body font/size)
- [ ] Verify: success state animation/overlay
- [ ] Verify: no emojis (heart = SVG heart_icon.svg or styled element)

---

## 7. waiting-handoff.html

**What it shows:** Side-by-side comparison of async waiting (two devices) vs together-mode handoff (one device)

- [ ] Compare against `app/lib/screens/game_waiting_screen.dart` (async side)
- [ ] Verify: waiting screen background, animations (floating dots, rotating messages)
- [ ] Verify: poke button styling
- [ ] Verify: handoff screen dark background (#1A1A2E)
- [ ] Verify: avatar display on handoff
- [ ] Verify: "I'M READY" button styling
- [ ] Verify: no emojis (lock = SVG, wave = remove, eyes = remove)

---

## 8. results-discuss.html

**What it shows:** Side-by-side comparison of async results vs together-mode results with discuss prompts

- [ ] Compare against `app/lib/screens/quiz_match_results_screen.dart`
- [ ] Compare against `app/lib/widgets/worth_discussing_card.dart`
- [ ] Verify: results header styling
- [ ] Verify: score display styling
- [ ] Verify: question breakdown card styling (match vs different indicators)
- [ ] Verify: "Worth Discussing" card styling matches actual widget
- [ ] Verify: LP badge styling
- [ ] Verify: no emojis (confetti = styled/animated, discuss = styled bubble, phone = SVG)

---

## 9. settings-profile.html

**What it shows:** Settings and profile screens with phantom partner display and upgrade options

- [ ] Compare against `app/lib/screens/settings_screen.dart`
- [ ] Compare against `app/lib/screens/profile_screen.dart`
- [ ] Verify: settings list item styling (height, padding, dividers, chevrons)
- [ ] Verify: profile header layout (avatar, name, email)
- [ ] Verify: section grouping / card styling
- [ ] Verify: toggle switch styling
- [ ] Verify: typography matches actual screens
- [ ] Verify: no emojis

---

## 10. upgrade-prompt.html

**What it shows:** Upgrade prompts shown when phantom users try restricted features

- [ ] Compare against `app/lib/widgets/unlock_popup.dart` (similar modal pattern)
- [ ] Verify: modal overlay styling (backdrop blur, dimming)
- [ ] Verify: card/dialog styling (border-radius, padding, shadow)
- [ ] Verify: button styling
- [ ] Verify: typography
- [ ] Verify: no emojis

---

## 11. index.html

**What it shows:** Hub page linking to all mockups (navigation only)

- [ ] Verify: no emojis in card previews (use styled icons or descriptive text)
- [ ] Low priority - this is just a navigation page

---

## Global Checks (apply to ALL mockups)

- [ ] Text colors: `--text-dark: #3A3A3A`, `--text-med: #5A5A5A`, `--text-light: #707070`
- [ ] Background gradient: `#FFD1C1 → #FFF5F0`
- [ ] Primary pink: `#FF5E62`
- [ ] Accent gradient: `#FF6B6B → #FF9F43`
- [ ] Card salmon: `#FF7B6B → #FF6B5B`
- [ ] Cream: `#FFF8F0`, Beige: `#F5E6D8`
- [ ] Avatar Joakim: `#FF6B6B → #FF5E62`
- [ ] Avatar Taija: `#6C9CE9 → #45B7D1`
- [ ] Fonts: Pacifico (logo), Playfair Display (headings), Nunito (body)
- [ ] Zero emojis used anywhere - all icons are SVG/styled elements
- [ ] Button border-radius matches actual app (30px for primary start buttons, varies by context)
