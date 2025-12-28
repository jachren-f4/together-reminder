# Us 2.0 Emoji Assets Inventory

This document lists all emojis used in Us 2.0 branded screens and widgets that should be replaced with custom PNG assets.

**Scope:** All Us 2.0 screens from `docs/US2_BRAND_TRACKING.md`, excluding Linked game screens.

**Excludes:**
- Linked screens (linked_intro_screen.dart, linked_game_screen.dart, linked_completion_screen.dart)
- Debug/logging statements
- Debug menu tabs

---

## Summary: Unique Emojis Required

### Core UI Emojis (High Priority)
| Emoji | Name | Primary Usage |
|-------|------|---------------|
| 💕 | Two Hearts | Default partner avatar, love/pairing |
| 💎 | Gem | LP (Love Points) indicator |
| 💗 | Growing Heart | Progress heart in connection bar |
| ✨ | Sparkles | Celebration, highlights, rewards |
| 🔓 | Unlocked | Feature unlock celebrations |
| ✓ | Checkmark | Completion indicators |

### Game Type Emojis
| Emoji | Name | Game/Feature |
|-------|------|--------------|
| 🧩 | Puzzle Piece | Classic Quiz |
| 🎯 | Target | Welcome Quiz, Goals |
| 💑 | Couple | Affirmation Quiz |
| ❤️ | Red Heart | Affirmation Quiz (alternate) |
| 🤔 | Thinking Face | You or Me |
| 🤝 | Handshake | You or Me (alternate) |
| 🔍 | Magnifying Glass | Word Search |
| 👟 | Running Shoe | Steps Together |
| 👣 | Footprints | Steps Together (alternate) |

### Arena/Tier Emojis
| Emoji | Name | Arena Level |
|-------|------|-------------|
| 🏕️ | Camping | Cozy Cabin (Tier 1) |
| 🏖️ | Beach | Sandy Shores (Tier 2) |
| ⛵ | Sailboat | Sailing Serenity (Tier 3) |
| 🏔️ | Snow Mountain | Alpine Peak (Tier 4) |
| 🏰 | Castle | Royal Palace (Tier 5) |
| 🏆 | Trophy | General achievement |
| 👑 | Crown | Max arena/achievement |

### Leaderboard Medals
| Emoji | Name | Position |
|-------|------|----------|
| 🥇 | Gold Medal | 1st Place |
| 🥈 | Silver Medal | 2nd Place |
| 🥉 | Bronze Medal | 3rd Place |

### Poke/Notification Emojis
| Emoji | Name | Usage |
|-------|------|-------|
| 💫 | Dizzy/Sparkle | Default poke |
| 👋 | Waving Hand | Poke greeting |
| 🫶 | Heart Hands | Poke option |
| 😘 | Kissing Face | Poke option |
| 🥰 | Smiling with Hearts | Poke option |
| 😊 | Smiling Face | Poke option |
| 🤗 | Hugging Face | Poke option |
| 📱 | Mobile Phone | Notification indicator |

### Reminder Emojis
| Emoji | Name | Reminder Type |
|-------|------|---------------|
| 🏠 | House | "I'm home" |
| ☕ | Coffee | "Coffee?" / 1 hour |
| 🛒 | Shopping Cart | "Pick up milk" |
| ⚡ | Lightning | "Now" timing |
| 🌙 | Moon | "8 PM" timing |
| ☀️ | Sun | "8 AM" timing |
| ⏰ | Alarm Clock | Scheduled reminder |
| 💌 | Love Letter | Reminder sent |

### Avatar/Profile Emojis
| Emoji | Name | Usage |
|-------|------|-------|
| 👤 | Person Silhouette | Default/unknown user |
| 👩 | Woman | Female avatar |
| 👨 | Man | Male avatar |
| 😊 | Smiling Face | Default user emoji |
| 😎 | Cool Face | Avatar option |
| 😇 | Angel Face | Avatar option |
| 😄 | Grinning Face | Avatar option |
| 🙂 | Slightly Smiling | Avatar option |
| 😁 | Beaming Face | Avatar option |
| 🤩 | Star Eyes | Avatar option |
| 😋 | Face Savoring | Avatar option |
| 🥳 | Party Face | Avatar option |
| 😏 | Smirking Face | Avatar option |

### Status/Feedback Emojis
| Emoji | Name | Usage |
|-------|------|-------|
| ⚠️ | Warning | Error/warning states |
| ❌ | Cross Mark | Failure/mismatch |
| ✅ | Check Mark | Success/complete |
| 🔥 | Fire | Streak indicator |
| 😢 | Crying Face | Empty/sad state |
| 🎉 | Party Popper | Celebration |
| 💡 | Light Bulb | Hint/tip |
| 📧 | Email | Auth/verification |
| 📭 | Empty Mailbox | Empty inbox |
| 🔒 | Locked | Locked content |

### You or Me Game Emojis
| Emoji | Name | Usage |
|-------|------|-------|
| 🙋 | Person Raising Hand | "Me" answer |
| 🙋‍♀️ | Woman Raising Hand | "You" answer |

### Activity Type Emojis
| Emoji | Name | Activity |
|-------|------|----------|
| 📝 | Memo | Affirmation activity |
| 💭 | Thought Bubble | Daily pulse |
| 🔮 | Crystal Ball | Daily pulse predictions |
| 👫🏾 | Couple | Us 2.0 home couples |
| 🎮 | Game Controller | Games |
| ❓ | Question Mark | Unknown activity |
| 💝 | Heart with Ribbon | Default/fallback |
| 🌍 | Globe | Global leaderboard |
| 🤍 | White Heart | LP neutral |

### Guidance/Onboarding Emojis
| Emoji | Name | Usage |
|-------|------|-------|
| 👆 | Pointing Up | Tap guidance |
| ♥ | Heart Suit | Logo heart accent |

---

## Detailed Location Reference

### Home Screen (`lib/screens/home_screen.dart`)
- Line 511: `💕` - Liia brand logo heart
- Line 525: `💎` - LP diamond indicator
- Line 636: `💫` - Poke sparkle
- Line 653: `💕` - Hearts
- Line 716: `🏆` - Max arena trophy
- Line 911: `🧩` - Classic quiz emoji
- Line 918: `🔥` - Streak fire
- Line 925: `🎯` - Target emoji

### Onboarding Screen (`lib/screens/onboarding_screen.dart`)
- Line 217: `♥` - Heart accent
- Line 256: `💕` - Two hearts button
- Line 275: `💖` - Sparkling heart button

### Auth Screen (`lib/screens/auth_screen.dart`)
- Line 260: `⚠️` - Warning icon
- Line 354: `📧` - Email icon
- Line 454: `⚠️` - Warning icon
- Line 496: `✨` - Sparkles text

### OTP Verification Screen (`lib/screens/otp_verification_screen.dart`)
- Line 292: `⚠️` - Warning icon
- Line 409: `📧` - Email icon
- Line 493: `⚠️` - Warning icon

### Quiz Intro Screen (`lib/screens/quiz_intro_screen.dart`)
- Line 487: `🧩` - Hero emoji (Us2)
- Line 651: `🧩` - Emoji icon (Liia)

### Affirmation Intro Screen (`lib/screens/affirmation_intro_screen.dart`)
- Line 463: `💑` - Hero emoji (Us2)
- Line 627: `❤️` - Heart icon (Liia)

### You or Me Screens
**Intro (`lib/screens/you_or_me_match_intro_screen.dart`):**
- Line 454: `🤔` - Hero emoji (Us2)
- Line 618: `🤝` - Handshake icon (Liia)

**Game (`lib/screens/you_or_me_match_game_screen.dart`):**
- Line 716: `🙋` - "Me" button
- Line 730: `🙋‍♀️` - "You" button
- Line 1120: `🙋` - "Me" button (Us2)
- Line 1135: `🙋‍♀️` - "You" button (Us2)

**Results (`lib/screens/you_or_me_match_results_screen.dart`):**
- Line 390: `💕` - Match hearts
- Line 698: `✓` - Aligned checkmark

### Word Search Screens
**Intro (`lib/screens/word_search_intro_screen.dart`):**
- Line 234: `♥` - Heart accent
- Line 286: `🔍` - Magnifying glass emoji

**Game (`lib/screens/word_search_game_screen.dart`):**
- Line 946: `💗` - Hint heart
- Line 1548: `💡` - Hint bulb
- Line 1670: `💡` - Hint icon

**Completion (`lib/screens/word_search_completion_screen.dart`):**
- Line 164: `✓` - Checkmark

### Welcome Quiz Screens
**Intro (`lib/screens/welcome_quiz_intro_screen.dart`):**
- Line 128: `💕` - Hearts
- Line 174: `🎯` - Target
- Line 368: `💕` - Hearts (Us2)
- Line 394: `🎯` - Target (Us2)

**Waiting (`lib/screens/welcome_quiz_waiting_screen.dart`):**
- Line 235: `💡` - Tip bulb
- Line 594: `💡` - Tip bulb (Us2)

**Results (`lib/screens/welcome_quiz_results_screen.dart`):**
- Line 155: `🎯` - Target
- Line 478: `🎯` - Target (Us2)

### Quiz Match Screens
**Waiting (`lib/screens/quiz_match_waiting_screen.dart`):**
- Line 275: `👤` - Default partner avatar

### Profile Screen (`lib/screens/profile_screen.dart`)
- Line 242: `🏆` - Arena trophy
- Line 246: `🏆` - Arena trophy
- Line 324: `🏆` - Next arena
- Line 412: `👑` - Crown
- Line 1166: `🏆` - Arena
- Line 1168: `🏆` - Arena
- Line 1238: `🏆` - Next arena
- Line 1328: `👑` - Crown (Us2)
- Line 1437: `✏️` - Edit
- Line 1552: `✓` - Activities completed
- Line 1553: `🔥` - Streak
- Line 1554: `🏆` - Games won
- Line 1687: `🚪` - Logout

### Settings Screen (`lib/screens/settings_screen.dart`)
- Line 219: `😊😎🥰😇🤗😄🙂😁🤩😋🥳😏` - Avatar emoji picker
- Line 519: `👟` - Steps icon
- Line 838: `💕` - Hearts
- Line 1140: `👟` - Steps icon (Us2)
- Line 1211: `❤️` - Heart

### Steps Intro Screen (`lib/screens/steps_intro_screen.dart`)
- Line 149: `👣` - Footprints
- Line 158: `👣` - Footprints

### Pairing Screen (`lib/screens/pairing_screen.dart`)
- Line 169: `💕` - Default partner emoji
- Line 1185: `💕` - Partner emoji
- Line 1322: `💕` - Hearts
- Line 1703: `💕` - Hearts (Us2)

### Name Entry Screen (`lib/screens/name_entry_screen.dart`)
- Line 202: `👋` - Waving hand

### Main Screen (`lib/screens/main_screen.dart`)
- Line 333: `💫` - Poke nav item

### Inbox Screen (`lib/screens/inbox_screen.dart`)
- Line 112: `💫` - Pokes label
- Line 131: `📭` - Empty mailbox
- Line 305: `💫` - Poke prefix

### Send Reminder Screen (`lib/screens/send_reminder_screen.dart`)
- Line 32: `💕` - "Love you!"
- Line 33: `🏠` - "I'm home"
- Line 34: `☕` - "Coffee?"
- Line 35: `🛒` - "Pick up milk"
- Line 39: `⚡` - "Now"
- Line 40: `☕` - "1 Hour"
- Line 41: `🌙` - "8 PM"
- Line 42: `☀️` - "8 AM"
- Line 160: `⏰`/`✨` - Scheduled/sent
- Line 227: `✕` - Close
- Line 675: `💌` - Letter (Us2)
- Line 767: `💕` - Hearts (Us2)
- Line 1199: `⏰`/`✨` - Scheduled/sent (Us2)

### Daily Pulse Screen (`lib/screens/daily_pulse_screen.dart`)
- Line 112: `👤` - Default avatar
- Line 140: `🔥` - Streak
- Line 409: `🔮` - Crystal ball (Us2)
- Line 437: `🔥` - Streak (Us2)
- Line 647: `✅`/`❌` - Match/mismatch
- Line 714: `🔥` - Streak
- Line 809: `✓`/`✗` - Match/mismatch

### Daily Pulse Results (`lib/screens/daily_pulse_results_screen.dart`)
- Line 166: `💕`/`🤔` - Match/not quite

### Activity Hub Screen (`lib/screens/activity_hub_screen.dart`)
- Line 224: `📭` - Empty mailbox

---

## Us 2.0 Brand Widgets

### Us2 Logo (`lib/widgets/brand/us2/us2_logo.dart`)
- Line 33: `♥` - Heart accent

### Us2 Home Content (`lib/widgets/brand/us2/us2_home_content.dart`)
- Line 221: `💑` - Couple fallback
- Line 226: `❓` - Unknown type
- Line 228: `👫🏾` - Couple
- Line 230: `🎮` - Game
- Line 232: `🤔` - You or Me
- Line 234: `🔗` - Linked (excluded)
- Line 236: `🔍` - Word Search
- Line 238: `👟` - Steps
- Line 246: `✓` - Completed

### Us2 Quest Card (`lib/widgets/brand/us2/us2_quest_card.dart`)
- Line 311: `🔒` - Locked
- Line 419: `🔒` - Locked icon
- Line 511: `✨` - Reward
- Line 790: `✨` - Reward
- Line 801: `✨` - Reward

### Us2 Avatar Section (`lib/widgets/brand/us2/us2_avatar_section.dart`)
- Line 85: `👤` - Default avatar

### Us2 Connection Bar (`lib/widgets/brand/us2/us2_connection_bar.dart`)
- Line 203: `💗` - Progress heart
- Line 226: `✨` - Sparkle

### Us2 Intro Screen (`lib/widgets/brand/us2/us2_intro_screen.dart`)
- Line 81: `🤔` - Default hero emoji

---

## Other Widgets

### Poke Bottom Sheet (`lib/widgets/poke_bottom_sheet.dart`)
- Line 20: `👋` - Default emoji
- Line 214: `📱` - Phone icon
- Line 236: `💫` - Poke option
- Line 238: `❤️` - Poke option
- Line 240: `👋` - Poke option
- Line 242: `🫶` - Poke option
- Line 366: `👋❤️😘🥰😊🤗💕✨` - Poke options

### Poke Response Dialog (`lib/widgets/poke_response_dialog.dart`)
- Line 42: `❤️`/`❌` - Success/failure
- Line 79: `🙂` - Acknowledged
- Line 163: `❤️` - Poke back
- Line 172: `🙂` - Acknowledge
- Line 269: `❤️` - Poke back (Us2)
- Line 278: `🙂` - Acknowledge (Us2)

### Remind Bottom Sheet (`lib/widgets/remind_bottom_sheet.dart`)
- Lines 38-48: Same reminder emojis as send_reminder_screen
- Line 752: `✨` - Sent confirmation

### Leaderboard Bottom Sheet (`lib/widgets/leaderboard_bottom_sheet.dart`)
- Line 331: `💎` - LP indicator
- Line 387: `😢` - Empty state
- Line 493: `💎` - LP
- Line 536: `🏆` - Trophy
- Line 682: `😢` - Empty state (Us2)
- Lines 888-892: `🥇🥈🥉` - Medal positions
- Line 970: `🏆` - Trophy (Us2)
- Line 997: `🌍` - Globe
- Line 1028: `🎉` - Celebration
- Line 1053: `🏆` - Tier emoji

### LP Intro Overlay (`lib/widgets/lp_intro_overlay.dart`)
- Line 184: `✨` - Sparkle
- Line 504: `💎` - Diamond
- Line 616: `✨` - "Complete quests"
- Line 617: `🎯` - "Reach milestones"
- Line 618: `💕` - "Build connection"

### Quest Guidance Overlay (`lib/widgets/quest_guidance_overlay.dart`)
- Line 112: `✨` - Sparkle
- Line 247: `👆` - Tap pointer
- Line 274: `👆` - Tap pointer

### Unlock Celebration (`lib/widgets/unlock_celebration.dart`)
- Line 267: `🤔` - You or Me
- Line 269: `🔗` - Linked (excluded)
- Line 271: `🔍` - Word Search
- Line 273: `👟` - Steps
- Line 275: `✨` - Default
- Line 322: `🔓` - Unlocked

### Match Reveal Dialog (`lib/widgets/match_reveal_dialog.dart`)
- Line 97: `✨` - Sparkle
- Line 168: `💎` - LP indicator
- Line 250: `✨` - Sparkle (Us2)
- Line 328: `💎` - LP indicator (Us2)

### Daily Quests Widget (`lib/widgets/daily_quests_widget.dart`)
- Line 393: `✅` - Completed

### Steps Quest Card (`lib/widgets/steps/steps_quest_card.dart`)
- Line 185: `👟` - Running shoe

### Daily Pulse Widget (`lib/widgets/daily_pulse_widget.dart`)
- Line 53: `📅` - Calendar
- Line 69: `🔥` - Streak
- Line 144: `🎉` - Completed

### Classic Quiz Results Content (`lib/widgets/results_content/classic_quiz_results_content.dart`)
- Line 71: `🏆` - Perfect sync badge
- Line 83: `🏆` - Perfect sync badge
- Line 208: `💎` - LP diamond
- Line 276: `💡` - Insight bulb

### Animated Checkmark (`lib/widgets/animated_checkmark.dart`)
- Line 156: `✓` - Checkmark

---

## Models with Default Emojis

### User Model (`lib/models/user.dart`)
- Default avatar emoji: `😊`

### Partner Model (`lib/models/partner.dart`)
- Default avatar emoji: `💕`

### Arena Model (`lib/models/arena.dart`)
- Tier 1: `🏕️` - Cozy Cabin
- Tier 2: `🏖️` - Sandy Shores
- Tier 3: `⛵` - Sailing Serenity
- Tier 4: `🏔️` - Alpine Peak
- Tier 5: `🏰` - Royal Palace

### Branch Manifest Model (`lib/models/branch_manifest.dart`)
- Default fallback: `💝`

### Activity Item Model (`lib/models/activity_item.dart`)
- Affirmation: `📝`
- Poke: `💫`
- Pulse: `💭`
- Quiz: `🎯`
- YouOrMe: `🤔`
- Default: `💗`

---

## Services with Hardcoded Emojis

### Love Point Service (`lib/services/love_point_service.dart`)
Arena tiers: `🏕️`, `🏖️`, `⛵`, `🏔️`, `🏰`
LP indicator: `🤍`

### Branch Manifest Service (`lib/services/branch_manifest_service.dart`)
- Classic Quiz: `🧩`
- Affirmation: `❤️`
- You or Me: `🤝`
- Word Search: `🔍`
- Default: `💝`

### Poke Animation Service (`lib/services/poke_animation_service.dart`)
- Default: `💫`
- Heart: `❤️`
- Party: `🎉`
- Dual poke: `💕`

### Dev Config (`lib/config/dev_config.dart`)
- Mock partner: `🧑‍💻`
- Female: `👩`
- Male: `👨`

---

## Priority Asset Creation Order

### Phase 1: Core UI (Most Visible)
1. `💎` - LP diamond (appears in header, results, leaderboard)
2. `💕` - Two hearts (default partner, pairing, love)
3. `✨` - Sparkles (celebrations, rewards, hints)
4. `💗` - Growing heart (connection bar)
5. `✓` - Checkmark (completion everywhere)

### Phase 2: Game Icons
6. `🧩` - Classic Quiz
7. `🎯` - Welcome Quiz / Goals
8. `💑` - Affirmation Quiz
9. `🤔` - You or Me
10. `🔍` - Word Search
11. `👟` - Steps Together

### Phase 3: Arena Tiers
12. `🏕️` - Tier 1
13. `🏖️` - Tier 2
14. `⛵` - Tier 3
15. `🏔️` - Tier 4
16. `🏰` - Tier 5
17. `🏆` - Trophy
18. `👑` - Crown

### Phase 4: Interaction
19. `💫` - Default poke
20. `👋` - Wave poke
21. `❤️` - Heart poke/affirmation
22. `🫶` - Heart hands poke
23. `🙂` - Acknowledge

### Phase 5: Status/Feedback
24. `🔥` - Streak fire
25. `💡` - Hints/tips
26. `🔒` - Locked
27. `🔓` - Unlocked
28. `⚠️` - Warning
29. `❌` - Error/failure
30. `✅` - Success

### Phase 6: Leaderboard
31. `🥇` - 1st place
32. `🥈` - 2nd place
33. `🥉` - 3rd place
34. `🌍` - Global

### Phase 7: Reminders
35. `💌` - Love letter
36. `⏰` - Scheduled
37. `🏠` - Home
38. `☕` - Coffee
39. `🌙` - Night
40. `☀️` - Morning

### Phase 8: Avatars
41. `😊` - Default user
42. `👤` - Unknown user
43. Full avatar set: `😎🥰😇🤗😄🙂😁🤩😋🥳😏`

---

## Technical Notes

### Asset Organization
```
assets/brands/us2/emojis/
├── core/
│   ├── diamond.png
│   ├── two_hearts.png
│   ├── sparkles.png
│   └── ...
├── games/
│   ├── puzzle_piece.png
│   ├── target.png
│   └── ...
├── arenas/
│   ├── tier_1_cabin.png
│   └── ...
├── pokes/
│   └── ...
├── status/
│   └── ...
└── avatars/
    └── ...
```

### Implementation Approach
1. Create `Us2Emoji` widget that loads PNG from assets
2. Replace direct emoji `Text()` widgets with `Us2Emoji(name: 'diamond')`
3. Fallback to system emoji if asset not found
4. Size variants: 16px, 24px, 32px, 48px, 64px

---

*Last updated: December 2024*

---

## Quick Reference: All Emojis (Comma-Separated)

💕, 💎, 💗, ✨, 🔓, ✓, 🧩, 🎯, 💑, ❤️, 🤔, 🤝, 🔍, 👟, 👣, 🏕️, 🏖️, ⛵, 🏔️, 🏰, 🏆, 👑, 🥇, 🥈, 🥉, 💫, 👋, 🫶, 😘, 🥰, 😊, 🤗, 📱, 🏠, ☕, 🛒, ⚡, 🌙, ☀️, ⏰, 💌, 👤, 👩, 👨, 😎, 😇, 😄, 🙂, 😁, 🤩, 😋, 🥳, 😏, ⚠️, ❌, ✅, 🔥, 😢, 🎉, 💡, 📧, 📭, 🔒, 🙋, 🙋‍♀️, 📝, 💭, 🔮, 👫🏾, 🎮, ❓, 💝, 🌍, 🤍, 👆, ♥, 💖, ✏️, 🚪

---

## Background Removal Instructions

To remove checkered or white backgrounds from emoji assets and save as transparent PNG:

### Using Python with Pillow

```python
from PIL import Image

# Load the image
img = Image.open('path/to/image.jpeg')
img = img.convert('RGBA')
pixels = img.load()
width, height = img.size

def is_background(r, g, b):
    # Check if pixel is grayish (R ≈ G ≈ B) and light colored
    # Catches both white (~255) and light gray (~204) checker patterns
    avg = (r + g + b) / 3
    variance = abs(r - avg) + abs(g - avg) + abs(b - avg)
    
    # Low saturation (grayish) + light colored = background
    if variance < 20 and avg > 180:
        return True
    return False

# Make background pixels transparent
for y in range(height):
    for x in range(width):
        r, g, b, a = pixels[x, y]
        if is_background(r, g, b):
            pixels[x, y] = (r, g, b, 0)  # Set alpha to 0

# Crop to content (remove excess transparent space)
bbox = img.getbbox()
if bbox:
    padding = 5
    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(width, bbox[2] + padding)
    bottom = min(height, bbox[3] + padding)
    img = img.crop((left, top, right, bottom))

# Save as PNG with transparency
img.save('path/to/output.png', 'PNG')
```

### Key Points

1. **Convert to RGBA** - Required for transparency support
2. **Detect background by color** - Check for neutral grays (low saturation) that are light-colored
3. **Set alpha to 0** - Makes the pixel fully transparent
4. **Crop with `getbbox()`** - Removes excess transparent padding around the content
5. **Save as PNG** - JPEG doesn't support transparency

### Adjust Detection Thresholds

- `variance < 20` - How "gray" a pixel must be (increase for more aggressive removal)
- `avg > 180` - How "light" a pixel must be (decrease to catch darker grays)

For images with colored backgrounds, modify `is_background()` to target the specific background color.

---

## Emoji JSON Reference

```json
[
  {"emoji": "💕", "description": "two hearts - love and pairing"},
  {"emoji": "💎", "description": "gem - love points indicator"},
  {"emoji": "💗", "description": "growing heart - connection progress"},
  {"emoji": "✨", "description": "sparkles - celebration and rewards"},
  {"emoji": "🔓", "description": "unlocked - feature unlock"},
  {"emoji": "✓", "description": "checkmark - completion"},
  {"emoji": "🧩", "description": "puzzle piece - classic quiz"},
  {"emoji": "🎯", "description": "target - welcome quiz and goals"},
  {"emoji": "💑", "description": "couple - affirmation quiz"},
  {"emoji": "❤️", "description": "red heart - affirmation alternate"},
  {"emoji": "🤔", "description": "thinking face - you or me game"},
  {"emoji": "🤝", "description": "handshake - you or me alternate"},
  {"emoji": "🔍", "description": "magnifying glass - word search"},
  {"emoji": "👟", "description": "running shoe - steps together"},
  {"emoji": "👣", "description": "footprints - steps alternate"},
  {"emoji": "🏕️", "description": "camping - cozy cabin tier 1"},
  {"emoji": "🏖️", "description": "beach - sandy shores tier 2"},
  {"emoji": "⛵", "description": "sailboat - sailing serenity tier 3"},
  {"emoji": "🏔️", "description": "snow mountain - alpine peak tier 4"},
  {"emoji": "🏰", "description": "castle - royal palace tier 5"},
  {"emoji": "🏆", "description": "trophy - achievement"},
  {"emoji": "👑", "description": "crown - max arena"},
  {"emoji": "🥇", "description": "gold medal - 1st place"},
  {"emoji": "🥈", "description": "silver medal - 2nd place"},
  {"emoji": "🥉", "description": "bronze medal - 3rd place"},
  {"emoji": "💫", "description": "dizzy sparkle - default poke"},
  {"emoji": "👋", "description": "waving hand - poke greeting"},
  {"emoji": "🫶", "description": "heart hands - poke option"},
  {"emoji": "😘", "description": "kissing face - poke option"},
  {"emoji": "🥰", "description": "smiling with hearts - poke option"},
  {"emoji": "😊", "description": "smiling face - default user"},
  {"emoji": "🤗", "description": "hugging face - poke option"},
  {"emoji": "📱", "description": "mobile phone - notification"},
  {"emoji": "🏠", "description": "house - im home reminder"},
  {"emoji": "☕", "description": "coffee - coffee reminder"},
  {"emoji": "🛒", "description": "shopping cart - pick up milk"},
  {"emoji": "⚡", "description": "lightning - now timing"},
  {"emoji": "🌙", "description": "moon - evening timing"},
  {"emoji": "☀️", "description": "sun - morning timing"},
  {"emoji": "⏰", "description": "alarm clock - scheduled reminder"},
  {"emoji": "💌", "description": "love letter - reminder sent"},
  {"emoji": "👤", "description": "person silhouette - unknown user"},
  {"emoji": "👩", "description": "woman - female avatar"},
  {"emoji": "👨", "description": "man - male avatar"},
  {"emoji": "😎", "description": "cool face - avatar option"},
  {"emoji": "😇", "description": "angel face - avatar option"},
  {"emoji": "😄", "description": "grinning face - avatar option"},
  {"emoji": "🙂", "description": "slightly smiling - avatar option"},
  {"emoji": "😁", "description": "beaming face - avatar option"},
  {"emoji": "🤩", "description": "star eyes - avatar option"},
  {"emoji": "😋", "description": "face savoring - avatar option"},
  {"emoji": "🥳", "description": "party face - avatar option"},
  {"emoji": "😏", "description": "smirking face - avatar option"},
  {"emoji": "⚠️", "description": "warning - error state"},
  {"emoji": "❌", "description": "cross mark - failure"},
  {"emoji": "✅", "description": "check mark - success"},
  {"emoji": "🔥", "description": "fire - streak indicator"},
  {"emoji": "😢", "description": "crying face - empty state"},
  {"emoji": "🎉", "description": "party popper - celebration"},
  {"emoji": "💡", "description": "light bulb - hint tip"},
  {"emoji": "📧", "description": "email - auth verification"},
  {"emoji": "📭", "description": "empty mailbox - empty inbox"},
  {"emoji": "🔒", "description": "locked - locked content"},
  {"emoji": "🙋", "description": "person raising hand - me answer"},
  {"emoji": "🙋‍♀️", "description": "woman raising hand - you answer"},
  {"emoji": "📝", "description": "memo - affirmation activity"},
  {"emoji": "💭", "description": "thought bubble - daily pulse"},
  {"emoji": "🔮", "description": "crystal ball - predictions"},
  {"emoji": "👫🏾", "description": "couple - home couples"},
  {"emoji": "🎮", "description": "game controller - games"},
  {"emoji": "❓", "description": "question mark - unknown activity"},
  {"emoji": "💝", "description": "heart with ribbon - default fallback"},
  {"emoji": "🌍", "description": "globe - global leaderboard"},
  {"emoji": "🤍", "description": "white heart - lp neutral"},
  {"emoji": "👆", "description": "pointing up - tap guidance"},
  {"emoji": "♥", "description": "heart suit - logo accent"},
  {"emoji": "💖", "description": "sparkling heart - onboarding"},
  {"emoji": "✏️", "description": "pencil - edit"},
  {"emoji": "🚪", "description": "door - logout"}
]
```
