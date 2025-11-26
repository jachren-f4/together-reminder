# White-Label Couples App Architecture Plan

## Goal
Transform TogetherRemind into a white-label platform supporting 2-3 separate App Store listings (e.g., "Holy Couples", "Spicy Couples") with different content, visuals, and identity - deployable in ~15 minutes per brand.

## Requirements Summary
- **Deploy model**: Separate app store listings per brand
- **Scale**: 2-3 brands initially
- **Content management**: Developers only (JSON files in repo)
- **Scope**: Complete separation (content + visuals + identity)
- **Color migration**: Complete (~700+ references) for maximum brand control
- **Asset strategy**: Hybrid - sounds shared, key animations (poke, splash) per-brand
- **Timeline**: 3-4 weeks for solid implementation with proper testing

---

## Recommended Architecture: Flutter Flavors + BrandConfig

### Core Concept
Use Flutter's official **flavor system** (compile-time) combined with a centralized **BrandConfig** singleton that provides brand-specific values throughout the app.

```
Build Command → Flavor → BrandConfig → Colors/Content/Assets/Firebase
```

---

## Phase 1: Foundation (Days 1-3)

### 1.1 Create BrandConfig System

**New directory:** `lib/config/brand/`

```
lib/config/brand/
├── brand_config.dart      # Main config class with all properties
├── brand_registry.dart    # Static definitions for each brand
├── brand_loader.dart      # Singleton that loads correct brand at startup
├── brand_colors.dart      # Color palette per brand
├── brand_assets.dart      # Asset path helpers
└── content_paths.dart     # JSON content file paths
```

**Key pattern:** Brand is selected via `--dart-define=BRAND=holyCouples` at build time, loaded once in `main.dart` before any other initialization.

### 1.2 Update main.dart Initialization

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize brand FIRST
  BrandLoader().initialize();  // Reads --dart-define

  // 2. Firebase with brand-specific config
  await Firebase.initializeApp(
    options: BrandLoader().firebase.toFirebaseOptions(),
  );

  // 3. Set brand typography
  ThemeConfig().setFont(BrandLoader().config.typography.defaultSerifFont);

  // ... rest of initialization
}
```

### 1.3 Migrate AppTheme to Use BrandConfig

**Modify** `lib/theme/app_theme.dart` to delegate to BrandLoader while keeping existing API:

```dart
class AppTheme {
  // Backward-compatible - widgets keep using AppTheme.primaryBlack
  static Color get primaryBlack => BrandLoader().colors.primaryBlack;
  static Color get primaryWhite => BrandLoader().colors.primaryWhite;
  // ... etc
}
```

---

## Phase 2: Content & Assets (Days 4-6)

### 2.1 Restructure Assets (Hybrid Approach)

**New structure:**
```
assets/
├── brands/
│   ├── togetherremind/
│   │   ├── data/
│   │   │   ├── quiz_questions.json
│   │   │   ├── affirmation_quizzes.json
│   │   │   └── you_or_me_questions.json
│   │   ├── images/quests/
│   │   ├── animations/          # Brand-specific animations
│   │   │   ├── poke_send.json
│   │   │   ├── poke_receive.json
│   │   │   ├── poke_mutual.json
│   │   │   └── splash.json
│   │   └── words/
│   ├── holycouples/
│   │   └── ... (same structure, different content)
│   └── spicycouples/
│       └── ...
└── shared/
    ├── sounds/                  # All sounds shared across brands
    ├── animations/              # Generic animations (loading spinners, etc.)
    └── gfx/                     # Common UI graphics
```

**Hybrid rationale:**
- Sounds: Shared (notification sounds, button clicks) - no brand identity
- Key animations: Per-brand (poke, splash) - highly visible brand identity
- Generic animations: Shared (loading, transitions) - functional, not branded

### 2.2 Update Content Services

Modify loading to use brand paths:

```dart
// QuizQuestionBank.initialize()
final path = BrandLoader().content.quizQuestionsPath;
final jsonString = await rootBundle.loadString(path);
```

**Files to modify:**
- `lib/services/quiz_question_bank.dart`
- `lib/services/affirmation_quiz_bank.dart`
- `lib/services/you_or_me_service.dart`
- `lib/services/word_validation_service.dart`

---

## Phase 3: Platform Flavors (Days 7-10)

### 3.1 Android productFlavors

**Modify** `android/app/build.gradle.kts`:

```kotlin
android {
    flavorDimensions += "brand"
    productFlavors {
        create("togetherremind") {
            dimension = "brand"
            applicationId = "com.togetherremind.togetherremind"
            resValue("string", "app_name", "TogetherRemind")
        }
        create("holycouples") {
            dimension = "brand"
            applicationId = "com.togetherremind.holycouples"
            resValue("string", "app_name", "Holy Couples")
        }
        create("spicycouples") {
            dimension = "brand"
            applicationId = "com.togetherremind.spicycouples"
            resValue("string", "app_name", "Spicy Couples")
        }
    }
}
```

**Per-flavor directories:**
```
android/app/src/
├── main/              # Shared Android code
├── togetherremind/
│   ├── google-services.json
│   └── res/mipmap-*/  # App icons
├── holycouples/
│   ├── google-services.json
│   └── res/mipmap-*/
└── spicycouples/
    ├── google-services.json
    └── res/mipmap-*/
```

### 3.2 iOS Schemes

Create `.xcconfig` files per brand:
```
ios/config/
├── TogetherRemind.xcconfig
├── HolyCouples.xcconfig
└── SpicyCouples.xcconfig
```

Each defines:
- `PRODUCT_BUNDLE_IDENTIFIER`
- `PRODUCT_NAME`
- `FIREBASE_CONFIG_FILE` (path to GoogleService-Info.plist)

### 3.3 Build Commands

```bash
# TogetherRemind
flutter run --flavor togetherremind --dart-define=BRAND=togetherRemind

# Holy Couples
flutter run --flavor holycouples --dart-define=BRAND=holyCouples

# Spicy Couples (Release)
flutter build appbundle --flavor spicycouples --dart-define=BRAND=spicyCouples
```

---

## Phase 4: Complete Color Migration (Days 10-16)

### Current State
- 738 `Colors.*` references across 70 files
- 148 `Color(0x...)` hardcoded values across 22 files
- 426 `AppTheme.*` references (good pattern to follow)

### Complete Migration Strategy

Given the goal of maximum brand control, we'll migrate ALL color references systematically.

**Week 1: Create semantic color system**

Add to `BrandColors`:
```dart
class BrandColors {
  // Primary palette
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color background;
  final Color surface;

  // Text hierarchy
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnPrimary;

  // Semantic colors
  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  // UI elements
  final Color border;
  final Color borderLight;
  final Color divider;
  final Color shadow;
  final Color overlay;

  // Interactive states
  final Color disabled;
  final Color highlight;
  final Color selected;
}
```

**Week 2: Systematic file migration**

Batch processing by file count (highest first):
1. `linked_game_screen.dart` (33 refs)
2. `quest_card.dart` (26 refs)
3. `new_home_screen.dart` (24 refs)
4. `memory_flip_game_screen.dart` (15 refs)
5. All remaining 66 files

**Migration pattern:**
```dart
// Before
color: Colors.white
color: Colors.black.withOpacity(0.5)
color: Colors.grey.shade400

// After
color: AppTheme.surface
color: AppTheme.shadow
color: AppTheme.textTertiary
```

---

## Phase 5: Testing & Polish (Days 17-21)

### Build Testing
- Test each flavor builds correctly on Android emulator
- Test each flavor builds correctly on iOS device
- Verify content loads from correct brand paths
- Verify Firebase connects to correct project per brand
- Test FCM notifications work per brand

### Convenience Tooling
Create build scripts in `scripts/`:
```bash
scripts/
├── run_togetherremind.sh     # flutter run --flavor togetherremind --dart-define=BRAND=togetherRemind
├── run_holycouples.sh        # flutter run --flavor holycouples --dart-define=BRAND=holyCouples
├── build_all_release.sh      # Build all flavors for release
└── validate_brand_assets.sh  # Check all brands have required assets
```

### Documentation
Create `docs/WHITE_LABEL_GUIDE.md`:
- Step-by-step: How to create a new brand
- Required assets checklist (icons, animations, content)
- Firebase project setup per brand
- App Store submission checklist per brand

---

## Critical Files to Modify

| File | Change |
|------|--------|
| `lib/main.dart` | Add BrandLoader init before Firebase |
| `lib/theme/app_theme.dart` | Delegate colors to BrandLoader |
| `lib/services/quiz_question_bank.dart` | Use brand content paths |
| `lib/services/affirmation_quiz_bank.dart` | Use brand content paths |
| `lib/services/you_or_me_service.dart` | Use brand content paths |
| `lib/firebase_options.dart` | Return brand-specific options |
| `android/app/build.gradle.kts` | Add productFlavors |
| `pubspec.yaml` | Register new asset paths |

---

## Estimated Timeline (3-4 Weeks)

| Phase | Days | Duration | Risk |
|-------|------|----------|------|
| **Phase 1:** BrandConfig system | 1-3 | 3 days | Low |
| **Phase 2:** Content & asset restructure | 4-6 | 3 days | Low |
| **Phase 3:** Android productFlavors | 7-8 | 2 days | Low |
| **Phase 3:** iOS schemes | 9-10 | 2 days | Medium |
| **Phase 4:** Semantic color system | 10-12 | 3 days | Low |
| **Phase 4:** Complete color migration | 13-16 | 4 days | Medium |
| **Phase 5:** Testing all flavors | 17-19 | 3 days | Medium |
| **Phase 5:** Documentation & scripts | 20-21 | 2 days | Low |
| **Total** | | **~21 days (4 weeks)** | |

### Risk Mitigation

| Risk | Mitigation |
|------|------------|
| iOS scheme complexity | Use xcconfig files; document thoroughly |
| Color migration breaks UI | Migrate incrementally, test after each batch |
| Firebase project setup | Create projects early in Phase 1 |
| Content JSON drift between brands | Create validation script to ensure schema consistency |

---

## Key Decisions Made

1. **Color migration scope**: Complete (~700+ refs) for maximum brand control
2. **Asset strategy**: Hybrid - sounds shared, key animations per-brand
3. **Firebase**: Separate project per brand (required for App Store isolation)
4. **Timeline**: 3-4 weeks for solid implementation with proper testing
