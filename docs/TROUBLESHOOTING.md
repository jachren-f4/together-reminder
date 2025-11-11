# Troubleshooting Guide

Common issues and solutions for TogetherRemind development.

---

## Hot Reload Not Working

**Symptom:** Code changes not appearing after hot reload

**Solution:**
```bash
ps aux | grep flutter       # Find process ID
kill <pid>                  # Kill process
flutter run -d <device-id>  # Restart
```

**Why:** Hot reload may not pick up all UI changes, especially for complex widget trees or state management changes.

---

## CocoaPods GoogleUtilities Conflict

**Symptom:** Build fails with "CocoaPods could not find compatible versions for pod GoogleUtilities"

**Root Cause:** mobile_scanner < 7.0 uses GoogleMLKit which requires GoogleUtilities < 8.0, conflicting with Firebase's requirement for GoogleUtilities 8.x

**Solution:**

1. Ensure `mobile_scanner: ^7.0.0` in pubspec.yaml (v7.0+ required for Firebase compatibility)
2. Clean and rebuild:

```bash
flutter clean && rm -rf ios/Pods ios/Podfile.lock
pod repo update
flutter pub get
flutter run -d <device-id>
```

---

## iOS Notifications Not Showing

**Symptom:** Push notifications not appearing on iOS devices

**Checklist:**
1. Upload APNs .p8 key to Firebase Console (Cloud Messaging settings)
2. Add `GoogleService-Info.plist` to `ios/Runner/`
3. Enable "Push Notifications" capability in Xcode
4. Enable "Background Modes → Remote notifications" in Xcode
5. Test on **real device** (simulator doesn't support push notifications)
6. Verify notification categories configured in `ios/Runner/AppDelegate.swift`

**Additional Checks:**
- Ensure `FirebaseAppDelegateProxyEnabled = false` in Info.plist
- Verify bundle ID matches Firebase Console: `com.togetherremind.togetherremind`
- Check device notification settings (System Settings → Notifications → TogetherRemind)

---

## Hive Box Already Open

**Symptom:** `HiveError: Box has already been opened` exception

**Solution:**
```dart
if (!Hive.isBoxOpen('reminders')) {
  await Hive.openBox('reminders');
}
```

**Prevention:** Use singleton pattern for StorageService to ensure boxes are opened only once.

---

## Bundle ID Mismatch (iOS)

**Symptom:** Firebase authentication or push notifications fail on iOS with bundle ID errors

**Context:** iOS Bundle ID was changed to `com.togetherremind.togetherremind2` during security remediation to rotate exposed Firebase API keys.

**Solution:**

### If using .togetherremind2 bundle ID:
1. Firebase Console → Project Settings → iOS App
2. Add new iOS app with bundle ID: `com.togetherremind.togetherremind2`
3. Download new `GoogleService-Info.plist`
4. Replace file in `ios/Runner/`
5. Update APNs .p8 key for new app in Firebase Console

### To revert to original bundle ID:
1. In Xcode: Target → General → Bundle Identifier
2. Change from `com.togetherremind.togetherremind2` to `com.togetherremind.togetherremind`
3. Ensure `GoogleService-Info.plist` matches bundle ID
4. Clean build: `flutter clean && cd ios && pod install && cd ..`
5. Rebuild app

**Verification:**
```bash
# Check current bundle ID in Xcode project
grep -A 1 "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj

# Check Firebase config bundle ID
grep -A 1 "BUNDLE_ID" ios/Runner/GoogleService-Info.plist
```

---

## API Key Rotation (Firebase)

**Symptom:** Exposed Firebase API keys need rotation after security incident

**Context:** Firebase API keys in `GoogleService-Info.plist` and `google-services.json` were accidentally committed to git.

**Solution:**

### 1. Rotate API Keys (Google Cloud Console)

**For iOS (API Key in GoogleService-Info.plist):**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. APIs & Services → Credentials
4. Find the API key (matches `API_KEY` in GoogleService-Info.plist)
5. Click API key → "Regenerate Key" or create new key
6. Restrict key:
   - Application restrictions: iOS apps
   - Bundle IDs: `com.togetherremind.togetherremind` (or `.togetherremind2`)
   - API restrictions: Enable only necessary APIs (FCM, RTDB)
7. Download new `GoogleService-Info.plist` from Firebase Console
8. Replace `ios/Runner/GoogleService-Info.plist`

**For Android (API Key in google-services.json):**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. APIs & Services → Credentials
4. Find the Android API key (matches `current_key` in google-services.json)
5. Regenerate or create new key
6. Restrict key:
   - Application restrictions: Android apps
   - Package names: `com.togetherremind.togetherremind`
   - API restrictions: Enable only necessary APIs (FCM, RTDB)
7. Download new `google-services.json` from Firebase Console
8. Replace `android/app/google-services.json`

### 2. Delete Exposed Keys
1. In Google Cloud Console → Credentials
2. Delete old compromised API keys
3. Verify deletion takes effect (may take 5-10 minutes)

### 3. Update Git History (if committed)

**Option A: BFG Repo-Cleaner (recommended for large repos):**
```bash
# Install BFG
brew install bfg

# Clone a fresh copy
git clone --mirror git@github.com:username/togetherremind.git

# Remove files from history
bfg --delete-files GoogleService-Info.plist togetherremind.git
bfg --delete-files google-services.json togetherremind.git

# Clean up
cd togetherremind.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (WARNING: destructive)
git push --force
```

**Option B: git filter-branch (for smaller repos):**
```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch ios/Runner/GoogleService-Info.plist android/app/google-services.json" \
  --prune-empty --tag-name-filter cat -- --all

git push --force --all
git push --force --tags
```

**Option C: Change bundle ID (quick alternative):**
- Change iOS bundle ID to `com.togetherremind.togetherremind2`
- Create new Firebase iOS app with new bundle ID
- Old exposed keys become useless (restricted to old bundle ID)

### 4. Verify Protection

**Check .gitignore:**
```bash
# Ensure these are in .gitignore
echo "ios/Runner/GoogleService-Info.plist" >> .gitignore
echo "android/app/google-services.json" >> .gitignore
git add .gitignore
git commit -m "Add Firebase config files to gitignore"
```

**Verify not tracked:**
```bash
git status
# Should NOT show GoogleService-Info.plist or google-services.json
```

### 5. Team Communication
1. Notify all team members of key rotation
2. Each member must download new credential files from Firebase Console
3. Update CI/CD secrets with new credentials
4. Monitor Firebase Console for unauthorized access attempts

### Prevention
- **Never** commit credential files to git
- Use `.gitignore` from day one
- Enable Firebase App Check for additional security
- Restrict API keys by bundle ID/package name
- Use environment-specific Firebase projects (dev/staging/prod)
- Rotate keys quarterly as best practice

---

## Firebase Build Failures

**Symptom:** Build fails with Firebase-related errors

**Solution:**
```bash
flutter clean && rm -rf ios/Pods ios/Podfile.lock
pod repo update
flutter pub get
flutter run -d <device-id>
```

**Additional Checks:**
- Verify `mobile_scanner` version is 7.0.0+ in pubspec.yaml
- Ensure `GoogleService-Info.plist` is in `ios/Runner/`
- Ensure `google-services.json` is in `android/app/`
- Check Firebase dependencies are up to date

---

## QR Scanner Not Working

**Symptom:** Camera doesn't open or QR codes aren't detected

**Checklist:**
1. Add camera permissions to `Info.plist` (iOS) and `AndroidManifest.xml` (Android)
2. Request runtime permission in code
3. Test on **real device** (camera not available on simulators)
4. Verify `mobile_scanner: ^7.0.0` in pubspec.yaml

**iOS Info.plist:**
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan QR codes for pairing</string>
```

**Android AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
```

---

## Mock Data on Real Devices

**Symptom:** Mock partner data appears on physical devices

**Cause:** Old hardcoded `_forceSimulatorMode` flag (now removed in recent versions)

**Solution:** Already fixed in current codebase - uses `device_info_plus` detection

**Verification:**
```bash
# Check logs for device detection
flutter run -d <device-id>
# Look for: "isPhysicalDevice: true" on real devices
```

**Manual Override (if needed):**
```dart
// lib/config/dev_config.dart
static const bool enableMockPairing = false;
```

---

## UI Overflow Errors

**Symptom:** "RenderFlex overflowed" errors in debug console

**Known Fixed Issues:**
- Send reminder screen: Fixed GridView sizing (`lib/screens/send_reminder_screen.dart:27`)
- Poke screen: Fixed emoji button sizing (`lib/widgets/poke_bottom_sheet.dart:303`)

**General Solution:**
- Use `Expanded`, `Flexible`, or `SingleChildScrollView` widgets
- Set explicit size constraints on containers
- Use `LayoutBuilder` for dynamic sizing

---

## Quiz Results Showing Wrong Answers

**Symptom:** "You" shows partner's answers and vice versa in quiz results

**Cause:** Using `userIds[0]` and `userIds[1]` without checking current user ID

**Solution:** Look up answers by current user ID:
```dart
// ❌ WRONG
final myAnswer = answers[userIds[0]];

// ✅ CORRECT
final myAnswer = answers[user.id];
```

**Location:** `lib/screens/quiz_results_screen.dart:290-382`

---

## Cloud Function Errors

**Symptom:** Cloud Function calls fail with various errors

**Common Issues:**

### "runtime field is required"
```bash
# Add to firebase.json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs20"
  }
}
```

### "Your project must be on the Blaze plan"
- Upgrade Firebase project to Blaze plan in Firebase Console
- Cloud Functions require pay-as-you-go billing

### "parameter is required"
**Cause:** Using v1 function signature instead of v2

**Solution:** Check function signature uses `(request)` not `(data, context)`:
```javascript
// ✅ CORRECT (v2)
exports.myFunction = functions.https.onCall(async (request) => {
  const { param1, param2 } = request.data;
});

// ❌ WRONG (v1)
exports.myFunction = functions.https.onCall(async (data, context) => {
  const { param1, param2 } = data;
});
```

---

## Xcode Cannot Find Simulator (macOS 26.1+)

**Symptom:** "Unable to find a destination matching the provided destination specifier"

**Cause:** Xcode compatibility issue with iOS simulator runtimes on macOS 26.1+

**Workarounds:**
1. Use physical device: `flutter run -d 00008110-00011D4A340A401E`
2. Update Xcode to latest version
3. Use older iOS simulator runtime (iOS 18 or earlier)
4. Check available simulators: `xcrun simctl list devices`

---

## Chrome Testing Best Practices (Web Platform)

**Symptom:** Hot reload doesn't work properly on Chrome web builds

**Context:** Chrome maintains Hive/IndexedDB state even after Flutter process dies, causing stale state issues.

**Solution - Full Restart:**
```bash
# 1. Kill BOTH Flutter processes AND Chrome instances
pkill -f "flutter run"
pkill -f "chrome"

# 2. Clean build (optional but recommended for major changes)
cd app && flutter clean
flutter pub get

# 3. Start fresh Flutter instance
flutter run -d chrome
```

**Quick Restart (without clean):**
```bash
# Kill BOTH Flutter and Chrome
pkill -f "flutter run" && pkill -f "chrome"

# Start fresh
cd app && flutter run -d chrome
```

**When to use full clean:**
- After updating dependencies
- After modifying data models (Hive types)
- After major UI restructuring
- When hot reload repeatedly fails
- When seeing inexplicable errors

**Why this is necessary:**
- Hot reload (`r`) often doesn't update UI changes on Chrome
- Hot restart (`R`) sometimes maintains stale state
- Chrome instances maintain Hive/IndexedDB state even after Flutter process dies
- Multiple Chrome tabs can interfere with each other
- Killing only Flutter leaves Chrome with stale connections and cached state

**Testing Checklist:**
- [ ] Kill BOTH Flutter processes AND Chrome instances
- [ ] Start fresh `flutter run -d chrome`
- [ ] Verify data loaded correctly (check console)
- [ ] Navigate through app to verify UI updates
- [ ] Test feature functionality

---

**Last Updated:** 2025-11-11
