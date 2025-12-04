# Flutter QA Automation with Claude Code

**Automated UI testing for Flutter apps using screenshots and ADB**

---

## Overview

This document describes how Claude Code can perform QA testing on the TogetherRemind Flutter app by:
1. Taking screenshots of the running app
2. Analyzing the UI visually
3. Tapping buttons and navigating through flows
4. Identifying bugs and issues

This approach mimics how a human QA tester works - look at the screen, decide what to tap, tap it, verify the result.

---

## Prerequisites

### Required Tools

| Tool | Purpose | Location |
|------|---------|----------|
| ADB | Android Debug Bridge for device control | `~/Library/Android/sdk/platform-tools/adb` |
| Android Emulator | Run the Flutter app | `~/Library/Android/sdk/emulator/emulator` |
| Flutter | Build and run the app | System PATH |

### Available Emulators

```bash
~/Library/Android/sdk/emulator/emulator -list-avds
# Output: Pixel_5, Pixel_5_Partner2
```

---

## Quick Start

### 1. Launch Emulator

```bash
~/Library/Android/sdk/emulator/emulator -avd Pixel_5 &
```

### 2. Wait for Boot & Verify

```bash
sleep 20
~/Library/Android/sdk/platform-tools/adb devices
# Should show: emulator-5554  device
```

### 3. Launch Flutter App

```bash
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind
```

### 4. Start QA Loop

```bash
# Take screenshot
~/Library/Android/sdk/platform-tools/adb exec-out screencap -p > /tmp/screenshot.png

# Analyze screenshot (Claude reads the image)

# Tap at coordinates
~/Library/Android/sdk/platform-tools/adb shell input tap X Y

# Repeat
```

---

## ADB Commands Reference

### Screenshots

```bash
# Save screenshot to file
~/Library/Android/sdk/platform-tools/adb exec-out screencap -p > screenshot.png
```

### Input Commands

```bash
# Tap at coordinates
adb shell input tap 540 2000

# Swipe (scroll)
adb shell input swipe 540 1500 540 500    # Scroll up
adb shell input swipe 540 500 540 1500    # Scroll down

# Type text
adb shell input text "hello@example.com"

# Press keys
adb shell input keyevent 4     # Back button
adb shell input keyevent 3     # Home button
adb shell input keyevent 66    # Enter key
```

### Device Info

```bash
# Screen resolution
adb shell wm size
# Output: Physical size: 1080x2340

# Current foreground app
adb shell "dumpsys window | grep -E 'mCurrentFocus'"

# UI hierarchy (limited Flutter support)
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml
```

---

## Coordinate System

The Pixel 5 emulator has resolution **1080x2340**.

### Common UI Element Positions

| Element | Approximate Coordinates |
|---------|------------------------|
| Top-left back button | (70, 120) |
| Center of screen | (540, 1170) |
| Bottom nav - Home | (108, 2200) |
| Bottom nav - Inbox | (324, 2200) |
| Bottom nav - Poke | (540, 2200) |
| Bottom nav - Profile | (756, 2200) |
| Bottom nav - Settings | (972, 2200) |
| Full-width button (bottom) | (540, 2000) |
| Left card "Begin together" | (270, 2050) |
| Right card "Begin together" | (810, 2050) |

### Calculating Coordinates from Screenshots

Screenshots are captured at full resolution (1080x2340). When viewing in Claude:
- The image is scaled down for display
- Use proportional calculation: `actual_coord = (visual_position / image_display_size) * actual_resolution`

---

## QA Test Flow Example

### Test: Complete a Quiz

```bash
# 1. Start from home screen
adb exec-out screencap -p > step1_home.png
# Verify: See "DAILY QUESTS" with quiz cards

# 2. Tap "Begin together" on Lighthearted Quiz
adb shell input tap 270 2050
sleep 2
adb exec-out screencap -p > step2_intro.png
# Verify: See "Getting to Know You" intro screen

# 3. Tap "BEGIN QUIZ"
adb shell input tap 540 2000
sleep 2
adb exec-out screencap -p > step3_quiz.png
# Verify: See first question OR error message

# 4. Answer questions (tap answer options)
# Continue through flow...
```

---

## What Claude Can Detect

### Visual Bugs
- Text overflow/truncation
- Layout misalignment
- Spacing issues
- Wrong colors/theming
- Missing images
- Overlapping elements

### Functional Bugs
- Navigation errors (wrong screen shown)
- Error messages (like connection refused)
- Missing data
- Incorrect state

### UX Issues
- Small touch targets
- Confusing button labels
- Missing loading indicators
- Poor error messages

---

## Example Bug Found

During initial testing, Claude discovered:

**Bug:** Connection refused error when starting quiz

**Screenshot showed:**
```
ClientException with SocketConnection refused
(OS Error: Connection refused, errno = 111),
address = 10.0.2.2, port = 41296,
uri=http://10.0.2.2:3000/api/sync/game/classic/play
```

**Root cause:** Local API server not running

**Fix:** Either start `npm run dev` in `/api` folder, or configure app to use production API

---

## Limitations

### Coordinate-Based Tapping
- Fragile across different screen sizes
- Requires recalculation for different devices
- Can miss small buttons

### Mitigation Strategies
1. Use generous tap areas (center of buttons)
2. Add wait times after taps for UI to settle
3. Verify expected screen after each tap
4. Use UI hierarchy dump when available

### Future Improvements
- Parse `uiautomator dump` for element bounds
- Add Flutter integration tests for deterministic navigation
- Create debug overlay exposing widget positions

---

## Integration with CI/CD

This QA approach could be automated in CI:

```yaml
# .github/workflows/qa-test.yml
jobs:
  qa-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Start emulator
        run: |
          $ANDROID_HOME/emulator/emulator -avd test_device -no-window &
          adb wait-for-device
      - name: Build and install app
        run: flutter build apk && adb install build/app/outputs/apk/debug/app-debug.apk
      - name: Run QA script
        run: ./scripts/qa_test.sh
      - name: Upload screenshots
        uses: actions/upload-artifact@v3
        with:
          name: qa-screenshots
          path: /tmp/qa_screenshots/
```

---

## Files

| File | Purpose |
|------|---------|
| `docs/FLUTTER_QA_AUTOMATION.md` | This documentation |
| `/tmp/flutter_qa_screenshot*.png` | Temporary screenshots during testing |

---

**Last Updated:** 2025-12-04
