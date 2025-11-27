# White-Label Brand Creation Guide

This guide explains how to add a new brand to the TogetherRemind white-label platform.

---

## Table of Contents

1. [Overview](#overview)
2. [Backend Architecture](#backend-architecture)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Brand Creation](#step-by-step-brand-creation)
5. [Asset Requirements](#asset-requirements)
6. [Build Commands](#build-commands)
7. [Testing](#testing)
8. [App Store Submission](#app-store-submission)
9. [Troubleshooting](#troubleshooting)

---

## Overview

Each brand in the white-label system is a separate app with:
- **Unique bundle ID** (separate App Store listing)
- **Custom color palette** (primary, background, accent colors)
- **Brand-specific content** (quiz questions, animations, images)
- **Separate Firebase project** (for user data isolation)

Brands share the same codebase but are built with different configurations using Flutter flavors.

---

## Backend Architecture

### Architecture Options

| Approach | Database | Firebase | API | Pros | Cons | Best For |
|----------|----------|----------|-----|------|------|----------|
| **Shared Everything** | Same DB with `brand_id` column | Same project | Same deployment | Simple, cheap | No data isolation, single point of failure | MVP, testing |
| **Shared Code, Separate Data** | Separate Supabase per brand | Separate Firebase per brand | Same codebase, env-driven | Data isolation, independent scaling | More setup per brand | Production |
| **Fully Isolated** | Everything separate | Everything separate | Separate deployments | Complete isolation, sellable | Expensive, maintenance overhead | Enterprise |

### Recommended: Shared Code, Separate Data

For production white-label apps, we recommend **separate backend instances per brand** with **shared codebase**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    SHARED CODEBASE                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Flutter App (lib/)  │  API (api/)  │  Cloud Functions   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ TogetherRemind  │  │   HolyCouples   │  │   Brand N...    │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ Firebase Proj A │  │ Firebase Proj B │  │ Firebase Proj N │
│ Supabase Proj A │  │ Supabase Proj B │  │ Supabase Proj N │
│ API Deploy A    │  │ API Deploy B    │  │ API Deploy N    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Why Separate Backends Per Brand?

1. **Data Isolation** - Couples data never mixes between brands
2. **FCM Tokens** - Push notifications route to correct users
3. **Analytics** - Track brand performance independently
4. **Compliance** - Meet regional data residency requirements
5. **Scalability** - Scale high-traffic brands independently
6. **Exit Strategy** - Can sell/transfer individual brands

### Configuration Per Brand

Each brand needs its own:

| Service | Configuration | Location |
|---------|---------------|----------|
| **Firebase** | Project credentials | `BrandFirebaseConfig` in brand_registry.dart |
| **Supabase** | Project URL + anon key | `BrandConfig.supabaseUrl`, `supabaseAnonKey` |
| **API** | Base URL | `BrandConfig.apiBaseUrl` |
| **FCM** | google-services.json | `android/app/src/{brand}/` |
| **APNs** | GoogleService-Info.plist | `ios/Firebase/{Brand}/` |

### Database Schema Considerations

If using shared database (MVP approach), add `brand_id` to key tables.

**Migration file:** `api/supabase/migrations/014_white_label_brand_id.sql`

```bash
# Apply the migration
cd api
supabase db push
```

The migration adds `brand_id` column to all key tables:
- `couples`, `couple_invites`
- `daily_quests`, `quest_completions`
- `quiz_sessions`, `quiz_answers`, `quiz_progression`
- `you_or_me_sessions`, `you_or_me_answers`, `you_or_me_progression`
- `memory_puzzles`
- `love_point_awards`, `user_love_points`
- `linked_puzzles`, `word_search_puzzles` (if they exist)

**Helper function for RLS:**
```sql
-- Set brand for current request
SET LOCAL app.brand_id = 'holycouples';

-- Query filtered by brand
SELECT * FROM couples WHERE brand_id = get_current_brand_id();
```

### API Multi-Tenancy

For shared API deployment, accept brand from request:

```typescript
// Middleware to extract brand
export function brandMiddleware(req: Request) {
  const brand = req.headers['x-brand-id'] || 'togetherremind';
  // Validate brand exists
  // Set database connection for brand
  return brand;
}
```

### Firebase RTDB Path Namespacing

For shared Firebase (not recommended for production):

```
/brands/{brandId}/daily_quests/{coupleId}/...
/brands/{brandId}/quiz_sessions/...
/brands/{brandId}/lp_awards/...
```

### Environment Configuration Example

**Production setup with separate backends:**

```bash
# .env.togetherremind
SUPABASE_URL=https://abc123.supabase.co
SUPABASE_ANON_KEY=eyJ...
FIREBASE_PROJECT=togetherremind-prod
API_BASE_URL=https://api.togetherremind.com

# .env.holycouples
SUPABASE_URL=https://xyz789.supabase.co
SUPABASE_ANON_KEY=eyJ...
FIREBASE_PROJECT=holycouples-prod
API_BASE_URL=https://api.holycouples.com
```

### Scalability Considerations

| Scale | Users/Brand | Recommendation |
|-------|-------------|----------------|
| **Small** | < 10K | Shared database with brand_id |
| **Medium** | 10K - 100K | Separate Supabase, shared Firebase |
| **Large** | 100K+ | Fully separate infrastructure |
| **Enterprise** | 1M+ | Dedicated cloud accounts per brand |

### Cost Optimization

| Service | Free Tier | Cost at Scale | Strategy |
|---------|-----------|---------------|----------|
| **Firebase RTDB** | 1GB storage, 10GB/mo transfer | $5/GB storage | Use Supabase for large data |
| **Supabase** | 500MB DB, 1GB storage | $25/mo pro | Separate projects only when needed |
| **Cloud Functions** | 2M invocations/mo | $0.40/million | Share deployment, route by brand |
| **FCM** | Free unlimited | Free | Always separate per brand |

### Migration Path

**Phase 1 (MVP):** All brands share TogetherRemind backend
- Quick to launch new brands
- Use brand_id for data filtering
- Single deployment to maintain

**Phase 2 (Growth):** Separate Firebase per brand
- Critical for push notification isolation
- Keep shared Supabase with brand_id
- Separate google-services.json per brand

**Phase 3 (Scale):** Fully separate infrastructure
- Independent Supabase projects
- Independent API deployments
- Can scale/price brands independently

---

## Prerequisites

Before creating a new brand, ensure you have:

1. **Firebase Project** - Create a new Firebase project for the brand
   - Enable: Authentication, Realtime Database, Cloud Functions, Cloud Messaging
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

2. **App Store Accounts** - Access to Apple Developer and Google Play Console

3. **Brand Assets** - Logo, colors, content (see [Asset Requirements](#asset-requirements))

---

## Step-by-Step Brand Creation

### Step 1: Add Brand to Enum

Edit `lib/config/brand/brand_config.dart`:

```dart
enum Brand {
  togetherRemind,
  holyCouples,
  yourNewBrand,  // Add your brand here
}
```

Update the `brandId` getter:

```dart
String get brandId {
  switch (brand) {
    case Brand.togetherRemind:
      return 'togetherremind';
    case Brand.holyCouples:
      return 'holycouples';
    case Brand.yourNewBrand:
      return 'yournewbrand';  // lowercase, no spaces
  }
}
```

### Step 2: Create Brand Configuration

Edit `lib/config/brand/brand_registry.dart`:

```dart
static final Map<Brand, BrandConfig> _brands = {
  Brand.togetherRemind: _togetherRemindConfig,
  Brand.holyCouples: _holyCouplesConfig,
  Brand.yourNewBrand: _yourNewBrandConfig,  // Add mapping
};

// Add your brand configuration
static final _yourNewBrandConfig = BrandConfig(
  brand: Brand.yourNewBrand,
  appName: 'Your New Brand',
  appTagline: 'Your tagline here',
  bundleIdAndroid: 'com.yourcompany.yournewbrand',
  bundleIdIOS: 'com.yourcompany.yournewbrand',
  colors: const BrandColors(
    // Primary palette
    primary: Color(0xFF1A1A1A),
    primaryLight: Color(0xFF3A3A3A),
    primaryDark: Color(0xFF000000),
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFEFD),

    // Text hierarchy
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6E6E6E),
    textTertiary: Color(0xFFAAAAAA),
    textOnPrimary: Color(0xFFFFFEFD),

    // Accent colors
    accentGreen: Color(0xFF22c55e),
    accentOrange: Color(0xFFf59e0b),

    // UI elements
    border: Color(0xFF1A1A1A),
    borderLight: Color(0xFFF0F0F0),
    divider: Color(0xFFE5E5E5),
    shadow: Color(0x26000000),
    overlay: Color(0x80000000),

    // Semantic colors
    success: Color(0xFF22c55e),
    error: Color(0xFFef4444),
    warning: Color(0xFFf59e0b),
    info: Color(0xFF3b82f6),

    // Interactive states
    disabled: Color(0xFFCCCCCC),
    highlight: Color(0xFFF5F5F5),
    selected: Color(0xFFE8E8E8),
  ),
  typography: const BrandTypography(
    defaultSerifFont: SerifFont.georgia,
    bodyFontFamily: 'Inter',
  ),
  assets: const BrandAssets('yournewbrand'),
  content: const ContentPaths('yournewbrand'),
  firebase: const BrandFirebaseConfig(
    projectId: 'your-firebase-project',
    storageBucket: 'your-firebase-project.firebasestorage.app',
    databaseURL: 'https://your-firebase-project-default-rtdb.firebaseio.com',
    messagingSenderId: 'YOUR_SENDER_ID',
    androidApiKey: 'YOUR_ANDROID_API_KEY',
    androidAppId: 'YOUR_ANDROID_APP_ID',
    iosApiKey: 'YOUR_IOS_API_KEY',
    iosAppId: 'YOUR_IOS_APP_ID',
    iosBundleId: 'com.yourcompany.yournewbrand',
    webApiKey: 'YOUR_WEB_API_KEY',
    webAppId: 'YOUR_WEB_APP_ID',
    webAuthDomain: 'your-firebase-project.firebaseapp.com',
  ),
  apiBaseUrl: 'https://api.yournewbrand.com',
);
```

### Step 3: Create Asset Directory

```bash
mkdir -p assets/brands/yournewbrand/{data,animations,images/quests,words}
```

Copy or create the required content files (see [Asset Requirements](#asset-requirements)).

### Step 4: Update pubspec.yaml

Add asset paths:

```yaml
flutter:
  assets:
    # ... existing brands ...
    # Brand-specific content (YourNewBrand)
    - assets/brands/yournewbrand/data/
    - assets/brands/yournewbrand/animations/
    - assets/brands/yournewbrand/images/quests/
    - assets/brands/yournewbrand/words/
```

### Step 5: Android Flavor Setup

Edit `android/app/build.gradle.kts`:

```kotlin
productFlavors {
    // ... existing flavors ...
    create("yournewbrand") {
        dimension = "brand"
        applicationId = "com.yourcompany.yournewbrand"
        resValue("string", "app_name", "Your New Brand")
    }
}
```

Create Firebase config directory:

```bash
mkdir -p android/app/src/yournewbrand
# Copy your google-services.json here
cp /path/to/google-services.json android/app/src/yournewbrand/
```

### Step 6: iOS Configuration

Create xcconfig file at `ios/config/yournewbrand.xcconfig`:

```
// YourNewBrand flavor configuration
PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.yournewbrand
PRODUCT_NAME = Your New Brand
BRAND = yourNewBrand
GOOGLE_SERVICE_INFO_PLIST = Firebase/YourNewBrand/GoogleService-Info.plist
```

Create Firebase directory:

```bash
mkdir -p ios/Firebase/YourNewBrand
# Copy your GoogleService-Info.plist here
cp /path/to/GoogleService-Info.plist ios/Firebase/YourNewBrand/
```

### Step 7: Create Convenience Script

Create `scripts/run_yournewbrand.sh`:

```bash
#!/bin/bash
flutter run \
    --flavor yournewbrand \
    --dart-define=BRAND=yourNewBrand \
    $@
```

Make it executable: `chmod +x scripts/run_yournewbrand.sh`

### Step 8: Update Build Script

Edit `scripts/build_all_release.sh`:

```bash
BRANDS=(
  "togetherremind:togetherremind:togetherRemind"
  "holycouples:holycouples:holyCouples"
  "yournewbrand:yournewbrand:yourNewBrand"  # Add this line
)
```

### Step 9: Validate Assets

```bash
./scripts/validate_brand_assets.sh yournewbrand
```

---

## Asset Requirements

### Required Directory Structure

```
assets/brands/yournewbrand/
├── data/
│   ├── quiz_questions.json      # 180 classic quiz questions
│   ├── affirmation_quizzes.json # 6 affirmation quiz sets
│   └── you_or_me_questions.json # 60 you-or-me questions
├── animations/
│   ├── poke_send.json           # Lottie animation
│   ├── poke_receive.json        # Lottie animation
│   └── poke_mutual.json         # Lottie animation
├── images/
│   └── quests/
│       ├── classic-quiz-default.png
│       ├── affirmation-default.png
│       ├── you-or-me.png
│       ├── memory-flip.png
│       ├── word-ladder.png
│       └── ... (other quest images)
└── words/
    └── english_words.json       # Word validation dictionary
```

### JSON File Formats

**quiz_questions.json** (array):
```json
[
  {
    "id": "q1",
    "question": "What is your partner's favorite color?",
    "options": ["Red", "Blue", "Green", "Yellow"]
  }
]
```

**affirmation_quizzes.json**:
```json
{
  "quizzes": [
    {
      "id": "affirmation_1",
      "name": "Connection Basics",
      "questions": [
        {
          "id": "a1_q1",
          "text": "I feel heard when my partner listens to me"
        }
      ]
    }
  ]
}
```

**you_or_me_questions.json**:
```json
{
  "questions": [
    {
      "id": "yom_1",
      "question": "Who is more likely to plan a surprise date?"
    }
  ]
}
```

---

## Build Commands

### Debug Builds

```bash
# Android
flutter run --flavor yournewbrand --dart-define=BRAND=yourNewBrand -d emulator-5554

# iOS
flutter run --flavor yournewbrand --dart-define=BRAND=yourNewBrand -d <device-id>

# Web
flutter run --dart-define=BRAND=yourNewBrand -d chrome
```

### Release Builds

```bash
# Android APK
flutter build apk --release --flavor yournewbrand --dart-define=BRAND=yourNewBrand

# Android App Bundle (for Play Store)
flutter build appbundle --release --flavor yournewbrand --dart-define=BRAND=yourNewBrand

# iOS
flutter build ios --release --flavor yournewbrand --dart-define=BRAND=yourNewBrand
```

### Build All Brands

```bash
./scripts/build_all_release.sh
```

---

## Testing

### 1. Asset Validation
```bash
./scripts/validate_brand_assets.sh yournewbrand
```

### 2. Build Test
```bash
flutter build apk --debug --flavor yournewbrand --dart-define=BRAND=yourNewBrand
```

### 3. Visual Verification
- Launch app and verify colors match brand palette
- Check all screens for correct theming
- Verify quest images display correctly

### 4. Content Verification
- Start a Classic Quiz - questions should load from brand content
- Start an Affirmation Quiz - verify brand-specific questions
- Send a poke - verify animations play

### 5. Firebase Verification
- Verify app connects to correct Firebase project
- Test push notifications
- Test data sync between devices

---

## App Store Submission

### Google Play Store

1. **App Bundle**: Use `flutter build appbundle --release --flavor yournewbrand`
2. **Bundle ID**: Must match `bundleIdAndroid` in BrandConfig
3. **App Name**: Configured via `resValue` in build.gradle.kts

### Apple App Store

1. **Archive**: Build in Xcode with correct scheme
2. **Bundle ID**: Must match `bundleIdIOS` in BrandConfig
3. **Provisioning**: Create separate provisioning profiles per brand

---

## Troubleshooting

### "No matching client found for package name"
- Ensure `google-services.json` has correct package name
- Verify the client array includes your bundle ID

### Assets not loading
- Run `flutter clean && flutter pub get`
- Verify asset paths in pubspec.yaml
- Run `./scripts/validate_brand_assets.sh`

### Colors not changing
- Ensure `--dart-define=BRAND=yourNewBrand` is passed
- Check brand is registered in BrandRegistry
- Verify BrandLoader is initialized in main.dart

### Firebase initialization failed
- Verify Firebase config values in BrandConfig
- Check GoogleService-Info.plist / google-services.json paths
- Ensure Firebase project has required services enabled

---

## Quick Reference

| Item | Location |
|------|----------|
| Brand enum | `lib/config/brand/brand_config.dart` |
| Brand config | `lib/config/brand/brand_registry.dart` |
| Color definitions | `lib/config/brand/brand_colors.dart` |
| Android flavors | `android/app/build.gradle.kts` |
| iOS config | `ios/config/{brand}.xcconfig` |
| Assets | `assets/brands/{brand}/` |
| Run scripts | `scripts/run_{brand}.sh` |
| Validation | `scripts/validate_brand_assets.sh` |
