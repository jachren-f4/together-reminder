# White-Label Implementation Task List

> **Timeline:** 3-4 weeks | **Start Date:** _________ | **Target Completion:** _________

---

## Development Strategy: Feature Branch

### Branch Setup
```bash
# Create and switch to white-label branch
git checkout main
git pull origin main
git checkout -b feature/white-label

# All white-label work happens here
# Periodically sync with main to reduce merge conflicts:
git fetch origin main
git merge origin/main
```

### Merge Strategy
1. **Complete crossword feature first** (nearly done - just polish/bug fixes)
2. **Merge crossword to main**
3. **Sync white-label branch with main** (`git merge origin/main`)
4. **Complete white-label Phase 1-2** on feature branch
5. **Test thoroughly** on feature branch
6. **Merge white-label to main** via PR

### Conflict Prevention
- **Don't modify these files on main** while white-label branch exists:
  - `lib/main.dart`
  - `lib/theme/app_theme.dart`
  - `lib/config/theme_config.dart`
  - `pubspec.yaml` (asset declarations)
- **If crossword needs color changes**: Coordinate with white-label branch
- **Sync regularly**: Merge main → feature/white-label weekly to minimize drift

### Rollback Plan
If white-label merge causes issues:
```bash
git revert -m 1 <merge-commit-hash>
```

---

## Task Summary

| Phase | Implementation Tasks | Testing Tasks | Total |
|-------|---------------------|---------------|-------|
| Phase 0: Pre-Work & Branch Setup | 10 | 0 | 10 |
| Phase 1: BrandConfig Foundation | 17 | 15 | 32 |
| Phase 2: Content & Assets | 22 | 18 | 40 |
| Phase 3: Platform Flavors | 20 | 22 | 42 |
| Phase 4: Color Migration | 19 | 27 | 46 |
| Phase 5: Testing & Polish | 24 | 35 | 59 |
| **Total** | **112** | **117** | **229** |

### Testing Philosophy
- **Each phase has a dedicated testing section** - Do NOT skip
- **"STOP HERE" markers** - Prevent moving forward with broken code
- **Regression tests** - Ensure previous phases still work
- **Visual tests** - Colors, layouts, readability
- **Functional tests** - Features work end-to-end

---

## Phase 0: Pre-Work & Branch Setup

### 0.1 Crossword Coordination
- [x] Confirm crossword feature is merged to main (or at stable point) ✅ Nearly done, polish remaining
- [x] Note any files crossword modified that overlap with white-label work ✅ See WHITE_LABEL_BASELINE.md
- [x] Identify any hardcoded colors added by crossword (will need migration later) ✅ 98 Colors.* in linked files

### 0.2 Create Feature Branch
- [x] Ensure main branch is up to date: `git checkout main && git pull` ✅
- [x] Create feature branch: `git checkout -b feature/white-label` ✅ Created 2025-11-26
- [ ] Push branch to remote: `git push -u origin feature/white-label`

### 0.3 Document Current State (Baseline)
- [ ] Take screenshots of current app (for visual regression testing later)
- [x] Note current color count: 737 Colors.*, 151 Color(0x...), 426 AppTheme.* ✅
- [x] Note current asset locations in `pubspec.yaml` ✅ See WHITE_LABEL_BASELINE.md
- [x] Commit baseline documentation ✅ Commit 61bd6e42

**Phase 0 Checkpoint:** Feature branch created, baseline documented, ready to start

---

## Phase 1: BrandConfig Foundation (Days 1-3)

### 1.1 Create Brand Configuration Classes
- [ ] Create directory `app/lib/config/brand/`
- [ ] Create `brand_config.dart` - Main config class with all brand properties
- [ ] Create `brand_colors.dart` - Color palette class with all semantic colors
- [ ] Create `brand_typography.dart` - Typography configuration (fonts)
- [ ] Create `brand_assets.dart` - Asset path helpers per brand
- [ ] Create `content_paths.dart` - JSON content file paths per brand
- [ ] Create `firebase_config.dart` - Firebase credentials per brand
- [ ] Create `brand_loader.dart` - Singleton that reads `--dart-define` and loads config
- [ ] Create `brand_registry.dart` - Static registry of all brand configurations

### 1.2 Define TogetherRemind Brand (Default)
- [ ] Extract current colors from `app_theme.dart` into `TogetherRemindBrand`
- [ ] Extract current Firebase config from `firebase_options.dart`
- [ ] Define content paths pointing to current `assets/data/` location
- [ ] Define asset paths for current animations/images
- [ ] Test that `BrandLoader().initialize()` loads TogetherRemind by default

### 1.3 Integrate BrandLoader into App Startup
- [ ] Modify `main.dart` - Add `BrandLoader().initialize()` as FIRST init step
- [ ] Modify Firebase initialization to use `BrandLoader().firebase.toFirebaseOptions()`
- [ ] Modify `ThemeConfig` initialization to use brand's default font
- [ ] Verify app still runs correctly with no `--dart-define` (defaults to TogetherRemind)

### 1.4 Update AppTheme to Delegate to BrandConfig
- [ ] Modify `app_theme.dart` - Change static color constants to getters that read from BrandLoader
- [ ] Keep existing `AppTheme.primaryBlack` API (backward compatible)
- [ ] Verify all existing `AppTheme.*` references still work

### 1.5 Phase 1 Testing ✅
> **STOP HERE** - Do not proceed to Phase 2 until all tests pass

**Build Tests:**
- [ ] Run `flutter clean && flutter pub get` - no errors
- [ ] Run `flutter analyze` - no new errors/warnings
- [ ] Run `flutter run -d chrome` - app launches successfully
- [ ] Run `flutter run -d emulator-5554` (Android) - app launches successfully

**Functional Tests:**
- [ ] Home screen loads with correct colors (same as before)
- [ ] Navigate to Activities screen - colors correct
- [ ] Navigate to Inbox screen - colors correct
- [ ] Navigate to Settings screen - colors correct
- [ ] Start a quiz - colors and fonts correct
- [ ] Send a poke - animation plays correctly
- [ ] Check daily quests - cards display correctly

**Regression Tests:**
- [ ] Firebase initializes (check console for errors)
- [ ] FCM token retrieved successfully
- [ ] Hive storage works (data persists across restarts)
- [ ] No new console errors or warnings

**Phase 1 Checkpoint:** App runs identically, but colors now flow through BrandConfig

---

## Phase 2: Content & Asset Restructure (Days 4-6)

### 2.1 Create New Asset Directory Structure
- [ ] Create `app/assets/brands/` directory
- [ ] Create `app/assets/brands/togetherremind/` directory
- [ ] Create `app/assets/brands/togetherremind/data/` directory
- [ ] Create `app/assets/brands/togetherremind/animations/` directory
- [ ] Create `app/assets/brands/togetherremind/images/` directory
- [ ] Create `app/assets/brands/togetherremind/words/` directory
- [ ] Create `app/assets/shared/` directory
- [ ] Create `app/assets/shared/sounds/` directory
- [ ] Create `app/assets/shared/animations/` directory

### 2.2 Move Existing Content to Brand Directory
- [ ] Move `assets/data/quiz_questions.json` → `assets/brands/togetherremind/data/`
- [ ] Move `assets/data/affirmation_quizzes.json` → `assets/brands/togetherremind/data/`
- [ ] Move `assets/data/you_or_me_questions.json` → `assets/brands/togetherremind/data/`
- [ ] Move `assets/words/english_words.json` → `assets/brands/togetherremind/words/`
- [ ] Move `assets/words/finnish_words.json` → `assets/brands/togetherremind/words/`
- [ ] Move brand-specific animations (poke_send, poke_receive, poke_mutual) → `assets/brands/togetherremind/animations/`
- [ ] Move shared sounds → `assets/shared/sounds/`
- [ ] Move quest images → `assets/brands/togetherremind/images/quests/`

### 2.3 Update pubspec.yaml
- [ ] Add `assets/brands/togetherremind/data/` to asset declarations
- [ ] Add `assets/brands/togetherremind/animations/` to asset declarations
- [ ] Add `assets/brands/togetherremind/images/` to asset declarations
- [ ] Add `assets/brands/togetherremind/words/` to asset declarations
- [ ] Add `assets/shared/` to asset declarations
- [ ] Remove old asset paths that have been moved
- [ ] Run `flutter pub get` to verify

### 2.4 Update Content Services to Use Brand Paths
- [ ] Modify `quiz_question_bank.dart` - Use `BrandLoader().content.quizQuestionsPath`
- [ ] Modify `affirmation_quiz_bank.dart` - Use `BrandLoader().content.affirmationQuizzesPath`
- [ ] Modify `you_or_me_service.dart` - Use `BrandLoader().content.youOrMeQuestionsPath`
- [ ] Modify `word_validation_service.dart` - Use `BrandLoader().content.englishWordsPath` etc.
- [ ] Test content loading still works

### 2.5 Update Animation/Asset References
- [ ] Modify `poke_animation_service.dart` - Use `BrandLoader().assets.pokeSendAnimation` etc.
- [ ] Update any other hardcoded animation paths

### 2.6 Phase 2 Testing ✅
> **STOP HERE** - Do not proceed to Phase 3 until all tests pass

**Build Tests:**
- [ ] Run `flutter clean && flutter pub get` - no errors
- [ ] Run `flutter analyze` - no new errors/warnings
- [ ] Run `flutter run -d chrome` - app launches successfully
- [ ] Run `flutter run -d emulator-5554` (Android) - app launches successfully

**Content Loading Tests:**
- [ ] Start Classic Quiz - questions load correctly
- [ ] Start Affirmation Quiz - questions load correctly
- [ ] Start You or Me game - questions load correctly
- [ ] Start Word Ladder - word validation works (English words recognized)
- [ ] Verify quiz question count matches expected (180 questions)

**Animation Tests:**
- [ ] Send a poke - poke_send animation plays
- [ ] Receive a poke (from partner) - poke_receive animation plays
- [ ] Mutual poke - poke_mutual animation plays
- [ ] Check any other Lottie animations in the app

**Asset Tests:**
- [ ] Quest images load on daily quest cards
- [ ] Navigation icons display correctly
- [ ] Any sounds play correctly (if applicable)

**Regression Tests:**
- [ ] All Phase 1 tests still pass
- [ ] No "asset not found" errors in console
- [ ] App startup time hasn't significantly increased

**Phase 2 Checkpoint:** All content loads from new brand-specific paths

---

## Phase 3: Platform Flavors (Days 7-10)

### 3.1 Android productFlavors Setup
- [ ] Modify `android/app/build.gradle.kts` - Add `flavorDimensions` and `productFlavors`
- [ ] Define `togetherremind` flavor with applicationId `com.togetherremind.togetherremind`
- [ ] Define `holycouples` flavor with applicationId `com.togetherremind.holycouples`
- [ ] Define `spicycouples` flavor with applicationId `com.togetherremind.spicycouples`
- [ ] Create `android/app/src/togetherremind/` directory
- [ ] Move existing `google-services.json` to `android/app/src/togetherremind/`
- [ ] Create `android/app/src/togetherremind/res/` and copy existing app icons
- [ ] Update `AndroidManifest.xml` to use `@string/app_name` instead of hardcoded name

### 3.2 Test Android Flavor Build
- [ ] Run `flutter run --flavor togetherremind --dart-define=BRAND=togetherRemind`
- [ ] Verify app launches correctly on Android emulator
- [ ] Verify app name shows correctly
- [ ] Verify Firebase initializes correctly

### 3.3 iOS Schemes Setup
- [ ] Create `ios/config/` directory
- [ ] Create `ios/config/TogetherRemind.xcconfig` with bundle ID and settings
- [ ] Create `ios/config/HolyCouples.xcconfig` with bundle ID and settings
- [ ] Create `ios/config/SpicyCouples.xcconfig` with bundle ID and settings
- [ ] Create `ios/Firebase/TogetherRemind/` directory
- [ ] Move existing `GoogleService-Info.plist` to `ios/Firebase/TogetherRemind/`
- [ ] Modify Xcode project to include xcconfig files
- [ ] Create separate schemes in Xcode for each flavor
- [ ] Update `Info.plist` to use variables: `$(PRODUCT_BUNDLE_IDENTIFIER)`, `$(PRODUCT_NAME)`

### 3.4 Test iOS Flavor Build
- [ ] Run `flutter run --flavor TogetherRemind --dart-define=BRAND=togetherRemind` on iOS device
- [ ] Verify app launches correctly
- [ ] Verify app name shows correctly
- [ ] Verify Firebase initializes correctly

### 3.5 Create Convenience Build Scripts
- [ ] Create `scripts/run_togetherremind.sh`
- [ ] Create `scripts/run_holycouples.sh`
- [ ] Create `scripts/run_spicycouples.sh`
- [ ] Create `scripts/build_all_release.sh`
- [ ] Make scripts executable (`chmod +x`)

### 3.6 Phase 3 Testing ✅
> **STOP HERE** - Do not proceed to Phase 4 until all tests pass

**Android Flavor Tests:**
- [ ] Run `./scripts/run_togetherremind.sh` - app launches on Android
- [ ] Verify app name shows "TogetherRemind" in app drawer
- [ ] Verify correct bundle ID in Settings > Apps
- [ ] Firebase initializes correctly (check console)
- [ ] FCM notifications work (send test notification)
- [ ] All content loads correctly
- [ ] All features work (quiz, poke, quests)

**iOS Flavor Tests:**
- [ ] Run flavor on iOS device - app launches
- [ ] Verify app name shows correctly on home screen
- [ ] Verify correct bundle ID in Settings > General > iPhone Storage
- [ ] Firebase initializes correctly
- [ ] Push notifications work (send test notification)
- [ ] All content loads correctly
- [ ] All features work (quiz, poke, quests)

**Build Script Tests:**
- [ ] `./scripts/run_togetherremind.sh` works without errors
- [ ] Scripts have correct permissions (executable)

**Cross-Platform Consistency:**
- [ ] Same content appears on Android and iOS
- [ ] Same colors/fonts on Android and iOS
- [ ] No platform-specific bugs introduced

**Regression Tests:**
- [ ] All Phase 1 tests still pass
- [ ] All Phase 2 tests still pass
- [ ] Building WITHOUT flavor flags still works (backward compatibility check)

**Phase 3 Checkpoint:** Can build and run TogetherRemind flavor on both platforms

---

## Phase 4: Complete Color Migration (Days 10-16)

### 4.1 Expand Semantic Color System
- [ ] Add to `BrandColors`: `success`, `error`, `warning`, `info`
- [ ] Add to `BrandColors`: `shadow`, `overlay`, `divider`
- [ ] Add to `BrandColors`: `disabled`, `highlight`, `selected`
- [ ] Add to `BrandColors`: game-specific colors (if needed per brand)
- [ ] Update `AppTheme` with getters for all new semantic colors
- [ ] Define all semantic colors for TogetherRemind brand

### 4.2 Create Color Migration Helper Script
- [ ] Create script to find all `Colors.*` usages: `scripts/find_hardcoded_colors.sh`
- [ ] Run script and save output to `docs/COLOR_MIGRATION_AUDIT.md`
- [ ] Group files by color reference count

### 4.3 Migrate High-Priority Files (Screens)
- [ ] Migrate `linked_game_screen.dart` (33 refs)
- [ ] Migrate `new_home_screen.dart` (24 refs)
- [ ] Migrate `memory_flip_game_screen.dart` (15 refs)
- [ ] Migrate `activities_screen.dart`
- [ ] Migrate `inbox_screen.dart`
- [ ] Migrate `settings_screen.dart`
- [ ] Migrate `pairing_screen.dart`
- [ ] Migrate all other screen files in `lib/screens/`

### 4.4 Migrate High-Priority Files (Widgets)
- [ ] Migrate `quest_card.dart` (26 refs)
- [ ] Migrate `daily_quests_widget.dart`
- [ ] Migrate `poke_bottom_sheet.dart`
- [ ] Migrate `poke_response_dialog.dart`
- [ ] Migrate `five_point_scale.dart`
- [ ] Migrate all other widget files in `lib/widgets/`

### 4.5 Migrate Game-Specific Files
- [ ] Migrate `lib/widgets/linked/` directory (all files)
- [ ] Migrate `lib/widgets/memory_flip/` directory (if exists)
- [ ] Migrate result screens for all games

### 4.6 Migrate Remaining Files
- [ ] Migrate all files in `lib/widgets/debug/` (lower priority)
- [ ] Migrate any remaining files with `Colors.*` references
- [ ] Migrate any files with hardcoded `Color(0x...)` values

### 4.7 Phase 4 Testing ✅
> **STOP HERE** - Do not proceed to Phase 5 until all tests pass

**Color Audit Tests:**
- [ ] Run `./scripts/find_hardcoded_colors.sh` - 0 `Colors.*` in non-debug files
- [ ] Run `grep -r "Color(0x" lib/ --include="*.dart" | wc -l` - minimal hardcoded hex colors
- [ ] All colors now reference `AppTheme.*` or `BrandLoader().colors.*`

**Visual Tests - Main Screens:**
- [ ] Home screen - all colors correct, readable text
- [ ] Activities screen - all colors correct
- [ ] Inbox screen - all colors correct
- [ ] Settings screen - all colors correct
- [ ] Pairing screen - all colors correct

**Visual Tests - Game Screens:**
- [ ] Linked game screen - all cell colors, borders, text readable
- [ ] Memory Flip screen - card colors, match highlights correct
- [ ] Word Ladder screen - input fields, keyboard, validation colors
- [ ] Quiz screens - answer buttons, progress indicators
- [ ] Results screens - scores, graphs, share buttons

**Visual Tests - Widgets:**
- [ ] Quest cards - borders, backgrounds, text hierarchy
- [ ] Poke dialogs - buttons, animations blend with colors
- [ ] Navigation bar - icons, selection states
- [ ] Buttons - enabled, disabled, pressed states
- [ ] Input fields - borders, focus states, error states

**Contrast & Accessibility:**
- [ ] Text readable on all backgrounds
- [ ] Interactive elements clearly visible
- [ ] Error/success states distinguishable
- [ ] No color-only information (icons/text support)

**Build Tests:**
- [ ] Run `flutter analyze` - no new errors/warnings
- [ ] Build TogetherRemind flavor - succeeds
- [ ] App startup time unchanged

**Regression Tests:**
- [ ] All Phase 1-3 tests still pass
- [ ] No visual differences from before migration (same colors)
- [ ] All animations still work
- [ ] All interactive elements respond correctly

**Phase 4 Checkpoint:** All colors flow through BrandConfig, no hardcoded colors in main UI

---

## Phase 5: Testing & Polish (Days 17-21)

### 5.1 Create Second Brand for Testing
- [ ] Create `HolyCouplesBrand` class with different color palette
- [ ] Create `assets/brands/holycouples/` directory structure
- [ ] Copy TogetherRemind content as placeholder (to be replaced with real content later)
- [ ] Create placeholder app icons for holycouples
- [ ] Create `android/app/src/holycouples/` with placeholder `google-services.json`
- [ ] Add HolyCouples to `BrandRegistry`

### 5.2 Test Multi-Brand Building
- [ ] Build and run TogetherRemind flavor on Android
- [ ] Build and run HolyCouples flavor on Android
- [ ] Verify different colors appear for each flavor
- [ ] Verify different content loads for each flavor (when content differs)
- [ ] Build and run TogetherRemind flavor on iOS
- [ ] Build and run HolyCouples flavor on iOS

### 5.3 Test Feature Functionality Per Brand
- [ ] Test quiz flow on TogetherRemind
- [ ] Test quiz flow on HolyCouples
- [ ] Test poke flow on both brands
- [ ] Test daily quests on both brands
- [ ] Test all mini-games on both brands

### 5.4 Create Asset Validation Script
- [ ] Create `scripts/validate_brand_assets.sh`
- [ ] Script checks: all required JSON files exist per brand
- [ ] Script checks: all required image directories exist
- [ ] Script checks: JSON schema is valid
- [ ] Run validation on all brands

### 5.5 Documentation
- [ ] Create `docs/WHITE_LABEL_GUIDE.md` - Step-by-step brand creation guide
- [ ] Document: Required assets checklist
- [ ] Document: Firebase project setup per brand
- [ ] Document: App Store submission checklist per brand
- [ ] Document: Build commands reference
- [ ] Update main `CLAUDE.md` with white-label info

### 5.6 Final Cleanup
- [ ] Remove any temporary/debug code
- [ ] Verify no sensitive credentials in committed code
- [ ] Update `.gitignore` if needed for brand-specific files
- [ ] Run `flutter analyze` - fix any issues
- [ ] Run full test suite (if exists)

### 5.7 Phase 5 Final Testing ✅
> **Complete all tests before declaring white-label implementation done**

**Multi-Brand Build Tests:**
- [ ] Build TogetherRemind (Android APK) - succeeds
- [ ] Build TogetherRemind (iOS IPA) - succeeds
- [ ] Build HolyCouples (Android APK) - succeeds
- [ ] Build HolyCouples (iOS IPA) - succeeds
- [ ] Release builds work: `flutter build apk --release --flavor togetherremind`

**Brand Differentiation Tests:**
- [ ] TogetherRemind shows TogetherRemind colors
- [ ] HolyCouples shows HolyCouples colors (different from TogetherRemind)
- [ ] App names are correct in device app list
- [ ] Bundle IDs are different (can install both apps on same device)

**Full Feature Test - TogetherRemind:**
- [ ] Complete onboarding/pairing flow
- [ ] Complete a Classic Quiz
- [ ] Complete an Affirmation Quiz
- [ ] Complete You or Me game
- [ ] Complete Word Ladder game
- [ ] Complete Memory Flip game
- [ ] Complete Linked puzzle
- [ ] Send and receive pokes
- [ ] Daily quests generate and complete
- [ ] Love Points accumulate correctly
- [ ] Settings all work correctly
- [ ] Push notifications work

**Full Feature Test - HolyCouples:**
- [ ] Same feature tests as TogetherRemind (all pass)
- [ ] Content is brand-appropriate (when different content exists)
- [ ] No TogetherRemind branding appears anywhere

**Cross-Device Sync Tests:**
- [ ] Firebase RTDB sync works between partners (same brand)
- [ ] Quiz sessions sync correctly
- [ ] Daily quests sync correctly
- [ ] Pokes delivered correctly

**Edge Cases:**
- [ ] App works offline (graceful degradation)
- [ ] App recovers from background correctly
- [ ] No crashes on low memory
- [ ] Handles network errors gracefully

**Documentation Verification:**
- [ ] WHITE_LABEL_GUIDE.md is accurate and complete
- [ ] Build commands in docs work as documented
- [ ] All scripts work as documented

**Phase 5 Checkpoint:** Two brands build and run correctly, documentation complete

---

## Post-Implementation: First Real Brand

### Create Real Brand Content
- [ ] Design color palette for first new brand
- [ ] Create brand-specific quiz questions (JSON)
- [ ] Create brand-specific affirmation content (JSON)
- [ ] Create brand-specific you-or-me questions (JSON)
- [ ] Create app icons for all densities
- [ ] Create splash screen assets
- [ ] Create brand-specific poke animations (or use shared)
- [ ] Set up Firebase project for new brand
- [ ] Generate `google-services.json` for new brand
- [ ] Generate `GoogleService-Info.plist` for new brand

### Submit to App Stores
- [ ] Build release APK/AAB for new brand
- [ ] Build release IPA for new brand
- [ ] Prepare App Store listing (screenshots, description)
- [ ] Prepare Play Store listing (screenshots, description)
- [ ] Submit to App Store review
- [ ] Submit to Play Store review

---

## Quick Reference: Build Commands

```bash
# TogetherRemind (default brand)
./scripts/run_togetherremind.sh
# or: flutter run --flavor togetherremind --dart-define=BRAND=togetherRemind

# Holy Couples
./scripts/run_holycouples.sh
# or: flutter run --flavor holycouples --dart-define=BRAND=holyCouples

# Spicy Couples
./scripts/run_spicycouples.sh
# or: flutter run --flavor spicycouples --dart-define=BRAND=spicyCouples

# Release builds
flutter build apk --flavor togetherremind --dart-define=BRAND=togetherRemind --release
flutter build appbundle --flavor holycouples --dart-define=BRAND=holyCouples --release
flutter build ipa --flavor spicycouples --dart-define=BRAND=spicyCouples --release
```

---

## Progress Tracking

| Phase | Status | Start Date | End Date | Notes |
|-------|--------|------------|----------|-------|
| Phase 1: BrandConfig | Not Started | | | |
| Phase 2: Content & Assets | Not Started | | | |
| Phase 3: Platform Flavors | Not Started | | | |
| Phase 4: Color Migration | Not Started | | | |
| Phase 5: Testing & Polish | Not Started | | | |

**Last Updated:** _____________
