# Branch Manifest System Guide

This guide explains how to use the branch-dependent video and image system for quest intro screens and quest cards.

---

## Table of Contents

1. [Overview](#overview)
2. [Branch Structure](#branch-structure)
3. [Manifest File Format](#manifest-file-format)
4. [Adding Branch-Specific Media](#adding-branch-specific-media)
5. [Fallback Chain](#fallback-chain)
6. [File Locations](#file-locations)
7. [Testing Changes](#testing-changes)

---

## Overview

The branch manifest system allows each content branch to have its own:
- **Video** - Plays on the intro screen hero banner
- **Image** - Displays on the quest card in the carousel
- **Emoji** - Fallback when video fails to load (shown in grayscale)
- **Display Name** - Human-readable branch name
- **Description** - Short description of the branch content

### How It Works

1. **Quest Generation**: When daily quests are created, the current branch is determined by the couple's progression and stored on the quest
2. **Intro Screen**: When user taps a quest, the intro screen loads the video path from the branch's manifest
3. **Quest Card**: The image path from the manifest is used for the quest card thumbnail
4. **Fallback**: If manifest is missing or incomplete, default videos/images are used

---

## Branch Structure

### Activity Types with Branches

| Activity Type | Branches | Default Video |
|--------------|----------|---------------|
| Classic Quiz | lighthearted, deeper, spicy | feel-good-foundations.mp4 |
| Affirmation | emotional, practical, spiritual | affirmation.mp4 |
| You or Me | playful, reflective, intimate | getting-comfortable.mp4 |
| Linked | casual, romantic, adult | (no default) |
| Word Search | everyday, passionate, naughty | (no default) |

### Branch Cycling

Branches cycle based on completion count:
- After completing a Classic Quiz, the next one will be from the next branch
- Cycle: lighthearted → deeper → spicy → lighthearted → ...

---

## Manifest File Format

Each branch folder should contain a `manifest.json` file:

```
assets/brands/{brandId}/data/{activity}/{branch}/manifest.json
```

### Example Manifest

```json
{
  "branch": "lighthearted",
  "activityType": "classicQuiz",
  "videoPath": "assets/brands/togetherremind/videos/classic-quiz-lighthearted.mp4",
  "imagePath": "assets/brands/togetherremind/images/quests/classic-quiz-lighthearted.png",
  "fallbackEmoji": "🧩",
  "displayName": "Lighthearted",
  "description": "Fun and easy questions to get you started"
}
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `branch` | Yes | Must match folder name (e.g., "lighthearted") |
| `activityType` | Yes | Must match activity type enum (e.g., "classicQuiz") |
| `videoPath` | No | Full asset path to video file (MP4 format) |
| `imagePath` | No | Full asset path to image file (PNG format) |
| `fallbackEmoji` | No | Emoji shown when video fails (displayed grayscale) |
| `displayName` | No | Human-readable name for the branch |
| `description` | No | Short description of the branch content |

### Activity Type Values

Use these exact strings for `activityType`:
- `classicQuiz`
- `affirmation`
- `youOrMe`
- `linked`
- `wordSearch`

---

## Adding Branch-Specific Media

### Step 1: Create the Video

1. Create your video (recommended: 5-10 seconds, 720p or 1080p)
2. Convert to MP4 format if needed:
   ```bash
   ffmpeg -i input.mov -vcodec h264 -acodec aac output.mp4
   ```
3. Place in `assets/brands/{brandId}/videos/`

### Step 2: Create the Image

1. Create quest card image (recommended: 400x300px, PNG)
2. Place in `assets/brands/{brandId}/images/quests/`

### Step 3: Update the Manifest

Edit the branch's `manifest.json`:

```json
{
  "branch": "deeper",
  "activityType": "classicQuiz",
  "videoPath": "assets/brands/togetherremind/videos/classic-quiz-deeper.mp4",
  "imagePath": "assets/brands/togetherremind/images/quests/classic-quiz-deeper.png",
  "fallbackEmoji": "🧩",
  "displayName": "Deeper",
  "description": "More meaningful questions for connection"
}
```

### Step 4: Register Assets in pubspec.yaml

Ensure the video and image folders are listed in `pubspec.yaml`:

```yaml
assets:
  - assets/brands/togetherremind/videos/
  - assets/brands/togetherremind/images/quests/
  - assets/brands/togetherremind/data/classic-quiz/deeper/
```

### Step 5: Rebuild

```bash
flutter clean && flutter run -d chrome --dart-define=BRAND=togetherRemind
```

---

## Fallback Chain

The system uses a cascading fallback approach:

### Video Fallback Chain

1. **Manifest videoPath** - Branch-specific video from manifest.json
2. **Activity Default Video** - Default video for the activity type (e.g., feel-good-foundations.mp4)
3. **Grayscale Emoji** - Fallback emoji displayed with grayscale filter

### Image Fallback Chain

1. **Manifest imagePath** - Branch-specific image from manifest.json
2. **Quest imagePath** - Image path stored on the quest (from session)
3. **Type-Based Default** - Generic image based on quest type (e.g., classic-quiz-default.png)

### Default Videos by Activity

| Activity | Default Video |
|----------|--------------|
| Classic Quiz | feel-good-foundations.mp4 |
| Affirmation | affirmation.mp4 |
| You or Me | getting-comfortable.mp4 |
| Linked | (emoji only) |
| Word Search | (emoji only) |

### Default Emojis by Activity

| Activity | Emoji |
|----------|-------|
| Classic Quiz | 🧩 |
| Affirmation | ❤️ |
| You or Me | 🤝 |
| Linked | 🔗 |
| Word Search | 🔍 |

---

## File Locations

### Key Files

| File | Purpose |
|------|---------|
| `lib/models/branch_manifest.dart` | BranchManifest model class |
| `lib/services/branch_manifest_service.dart` | Service for loading/caching manifests |
| `lib/models/branch_progression_state.dart` | Branch enum and folder name mappings |
| `lib/models/daily_quest.dart` | DailyQuest model with `branch` field |

### Asset Paths

```
assets/brands/{brandId}/
├── data/
│   ├── classic-quiz/
│   │   ├── lighthearted/
│   │   │   ├── manifest.json
│   │   │   └── questions.json
│   │   ├── deeper/
│   │   │   ├── manifest.json
│   │   │   └── questions.json
│   │   └── spicy/
│   │       └── manifest.json
│   ├── affirmation/
│   │   ├── emotional/
│   │   │   └── manifest.json
│   │   ├── practical/
│   │   │   └── manifest.json
│   │   └── spiritual/
│   │       └── manifest.json
│   └── you-or-me/
│       ├── playful/
│       │   └── manifest.json
│       ├── reflective/
│       │   └── manifest.json
│       └── intimate/
│           └── manifest.json
├── images/
│   └── quests/
│       ├── classic-quiz-default.png
│       ├── affirmation-default.png
│       └── you-or-me.png
└── videos/
    ├── feel-good-foundations.mp4
    ├── affirmation.mp4
    └── getting-comfortable.mp4
```

---

## Testing Changes

### Quick Test

1. Clear Firebase data to generate fresh quests:
   ```bash
   firebase database:remove /daily_quests --force
   ```

2. Run the app:
   ```bash
   flutter run -d chrome --dart-define=BRAND=togetherRemind
   ```

3. Tap on a quest card to verify:
   - Video plays in the intro screen hero banner
   - Video fades to grayscale emoji when complete
   - Quest card shows correct image

### Verify Manifest Loading

Enable logging for the manifest service:

1. Edit `lib/utils/logger.dart`
2. Set `'manifest': true` in `_serviceVerbosity`
3. Run the app and check console for:
   ```
   Loaded manifest for classicQuiz_lighthearted
   ```

### Common Issues

| Issue | Solution |
|-------|----------|
| Video not playing | Check file path in manifest, ensure MP4 format |
| Image not showing | Verify image path, check pubspec.yaml includes the folder |
| Manifest not loading | Check JSON syntax, verify branch/activityType match |
| Web build fails | Run `flutter clean` then rebuild |
| 404 on new assets | Full rebuild required: `flutter clean && flutter run` |

---

## Adding a New Branch

To add a completely new branch (e.g., "adventurous" for Classic Quiz):

### 1. Update Branch Configuration

Edit `lib/models/branch_progression_state.dart`:

```dart
const Map<BranchableActivityType, List<String>> branchFolderNames = {
  BranchableActivityType.classicQuiz: ['lighthearted', 'deeper', 'spicy', 'adventurous'],
  // ... other activities
};
```

### 2. Create Branch Folder

```bash
mkdir -p assets/brands/togetherremind/data/classic-quiz/adventurous
```

### 3. Create Manifest

Create `assets/brands/togetherremind/data/classic-quiz/adventurous/manifest.json`:

```json
{
  "branch": "adventurous",
  "activityType": "classicQuiz",
  "videoPath": "assets/brands/togetherremind/videos/classic-quiz-adventurous.mp4",
  "imagePath": "assets/brands/togetherremind/images/quests/classic-quiz-adventurous.png",
  "fallbackEmoji": "🧩",
  "displayName": "Adventurous",
  "description": "Bold questions for thrill seekers"
}
```

### 4. Add Content

Create `assets/brands/togetherremind/data/classic-quiz/adventurous/questions.json` with quiz questions.

### 5. Update pubspec.yaml

Add the new folder:

```yaml
- assets/brands/togetherremind/data/classic-quiz/adventurous/
```

### 6. Regenerate Hive Adapters (if model changed)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## API Reference

### BranchManifestService

```dart
// Get manifest for a branch
final manifest = await BranchManifestService().getManifest(
  activityType: BranchableActivityType.classicQuiz,
  branch: 'lighthearted',
);

// Get video path with fallback
final videoPath = await BranchManifestService().getVideoPath(
  activityType: BranchableActivityType.classicQuiz,
  branch: 'lighthearted',
);

// Get image path with fallback
final imagePath = await BranchManifestService().getImagePath(
  activityType: BranchableActivityType.classicQuiz,
  branch: 'lighthearted',
);

// Get fallback emoji
final emoji = BranchManifestService().getFallbackEmoji(
  BranchableActivityType.classicQuiz,
);

// Clear cache (for brand switching or testing)
BranchManifestService().clearCache();
```

### BranchManifest Model

```dart
class BranchManifest {
  final String branch;
  final String activityType;
  final String? videoPath;
  final String? imagePath;
  final String? fallbackEmoji;
  final String? displayName;
  final String? description;
}
```

---

**Last Updated:** 2024-11-27
