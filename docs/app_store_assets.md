# App Store Assets

This document describes the assets and test data setup for creating App Store screenshots.

## HTML Mockups

Location: `mockups/app_store_screenshots/`

These HTML mockups simulate the Us 2.0 app screens at iPhone 15 Pro dimensions (393x852). Use a browser to view them and take screenshots.

| File | Description |
|------|-------------|
| `01_home_screen.html` | Home screen with daily quests and LP counter |
| `02_classic_quiz.html` | Classic quiz gameplay (multiple choice A-E) |
| `03_affirmation_quiz.html` | Affirmation quiz with 5-heart scale |
| `04_you_or_me.html` | You or Me game with partner names |
| `05_word_search.html` | Word search puzzle gameplay |
| `06_linked.html` | Linked crossword puzzle |
| `07_journal.html` | Journal/memories screen |
| `08_profile.html` | Profile/settings screen |
| `09_value_prop.html` | Value proposition / onboarding benefits |
| `10_steps_together.html` | Steps Together unlock celebration |
| `11_discussion_cards.html` | Discussion cards / conversation starters |
| `12_magnet_collection.html` | Magnet collection view |

### Taking Screenshots from Mockups

The mockups are designed at 393x852 (1x iPhone scale). For App Store screenshots at 1284x2778:

**Option 1: Browser zoom (recommended)**
1. Open HTML file in browser
2. Open DevTools → Device toolbar → set to 393x852
3. Set zoom to 327% (or use browser zoom)
4. Take screenshot with full page capture
5. Resize to exactly 1284x2778 if needed

**Option 2: CSS scale**
1. Edit the mockup's viewport to `width=1284, height=2778`
2. Scale all pixel values by 3.27x
3. Take screenshot at native resolution

**Option 3: Post-process**
1. Take screenshot at 393x852
2. Use image editor to upscale to 1284x2778 with good interpolation

## Live Device Screenshots

For more authentic screenshots, use the test couple script to create a realistic "7 days active" couple.

### Test Couple Setup

**Script:** `api/scripts/setup_app_store_couple.ts`

**Users:**
- Johnny: `test2011@dev.test`
- Julia: `test2015@dev.test`

**Password:** Generated via `getDevPassword()` - shown in script output

**What the script creates:**
- 2 linked users as a couple
- 2,800 LP (3 magnets unlocked, 78% to 4th)
- 7 days of quiz history (classic, affirmation, you_or_me)
- Multiple completed Linked matches
- Multiple completed Word Search matches
- 7 days of steps data with rewards
- All games unlocked
- Full Us Profile with discoveries

### Running the Script

```bash
cd api
npx tsx scripts/setup_app_store_couple.ts
```

### Taking Live Screenshots

1. Run the script to create the test couple
2. Install app on physical device:
   ```bash
   cd app
   flutter run -d <device-id> --dart-define=BRAND=us2 --release
   ```
3. Log in as Johnny (`test2011@dev.test`)
4. Navigate to desired screens and take screenshots
5. Repeat for any screens that look better from Julia's perspective

### Recommended Screenshots

Based on App Store best practices (6.5" and 5.5" displays):

1. **Hero/Home Screen** - Show daily quests and LP
2. **Quiz Gameplay** - Classic or Affirmation mid-question
3. **Results/Match** - Show couple's match percentage
4. **Games** - Word Search or Linked in progress
5. **Journey/Progress** - Magnet collection or LP milestones
6. **Value Prop** - Benefits overview during onboarding

### Device Requirements

- iPhone 15 Pro Max (6.7") for 6.5" screenshots
- iPhone 8 Plus (5.5") for 5.5" screenshots
- Or use iOS Simulator with equivalent dimensions

## Asset Files

The mockups reference images in `mockups/app_store_screenshots/assets/`:

- `austin.jpg`, `barcelona.jpg`, `chicago.jpg`, `miami.jpg` - Magnet images
- `new_classic_quiz.png`, `new_word_search.png`, etc. - Game thumbnails
- `linked.png` - Linked game icon
- `steps-together.png` - Steps Together icon

## App Store Requirements

**Primary screenshot size:** 1284 × 2778 pixels (6.5" display)

This is the main size Apple uses. Other sizes are auto-generated from this.

- Format: PNG or JPEG
- Max 10 screenshots per localization
- No device frames required (Apple adds them)
