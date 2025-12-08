# Signup Flow Test Guide

Testing the refactored server-side auth & onboarding flow using test accounts.

## Test Environment

| Device | Platform | Test Account |
|--------|----------|--------------|
| Android Emulator | Pixel 5 | test1@togetherremind.com |
| Chrome | Web | test2@togetherremind.com |

## Pre-Test Setup

### Step 1: Backup Jokke & Testi-Y (one-time)

```bash
cd /Users/joakimachren/Desktop/togetherremind/api
npx tsx scripts/backup_jokke_testiy.ts
```

This saves their info to `scripts/jokke_testiy_backup.json` for future reference.

### Step 2: Reset Test Accounts

```bash
cd /Users/joakimachren/Desktop/togetherremind/api
npx tsx scripts/setup_test_accounts.ts
```

This deletes any existing test1/test2 accounts and their data.

### Step 3: Clear Local App Data

**Android Emulator:**
```bash
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
```

**Chrome:**
1. Open Chrome DevTools (F12)
2. Application tab → Storage → Clear site data

### Step 4: Launch Both Apps

```bash
# Terminal 1: Android Emulator
~/Library/Android/sdk/emulator/emulator -avd Pixel_5 &
sleep 10
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind

# Terminal 2: Chrome
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d chrome --dart-define=BRAND=togetherRemind
```

Or use the shortcut:
```bash
/runtogether
```

---

## Test Scenarios

### Scenario 1: Fresh Signup (Both Users)

**Goal:** Verify complete signup flow with server-side user creation.

#### Android (test1@togetherremind.com)

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | App launches | Shows OnboardingScreen | First-run detection |
| 2 | Tap "Get Started" | Shows AuthScreen | Navigation |
| 3 | Enter `test1@togetherremind.com` | Email accepted | Email validation |
| 4 | Tap "Continue (Dev Mode)" | Navigates to NameEntryScreen | Dev OTP bypass, completeSignup API |
| 5 | Enter name "AndroidUser" | Name accepted | Name validation |
| 6 | Tap "Continue" | Shows PairingScreen | updateName API, user saved |

✅ **Check:** User should exist in database with correct name

#### Chrome (test2@togetherremind.com)

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | App launches | Shows OnboardingScreen | First-run detection |
| 2 | Tap "Get Started" | Shows AuthScreen | Navigation |
| 3 | Enter `test2@togetherremind.com` | Email accepted | Email validation |
| 4 | Tap "Continue (Dev Mode)" | Navigates to NameEntryScreen | Dev OTP bypass |
| 5 | Enter name "ChromeUser" | Name accepted | Name validation |
| 6 | Tap "Continue" | Shows PairingScreen | updateName API |

---

### Scenario 2: Pairing with 6-Digit Code

**Goal:** Verify pairing flow creates couple and Partner objects correctly.

#### Android: Create Pairing Code

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | On PairingScreen | Shows "Share Your Code" tab | Default tab |
| 2 | Tap "Generate Code" | Shows 6-digit code (e.g., "123456") | generatePairingCode API |
| 3 | Note the code | Code visible for 15 minutes | Code expiration |

#### Chrome: Join with Code

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | On PairingScreen | Shows "Share Your Code" tab | Default tab |
| 2 | Tap "Enter Code" tab | Shows code input field | Tab switch |
| 3 | Enter the 6-digit code | Code accepted | Code validation |
| 4 | Tap "Join" | Shows HomeScreen | joinWithCode API, Partner.fromJson |
| 5 | Check partner name | Shows "AndroidUser" | Partner data from server |

#### Android: Verify Pairing

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | Wait ~30 seconds | App detects pairing via polling | getStatus polling |
| 2 | Auto-navigates | Shows HomeScreen | Auth wrapper partner detection |
| 3 | Check partner name | Shows "ChromeUser" | Partner sync from server |

✅ **Check:** Both users see each other's names correctly

---

### Scenario 3: Logout and Login (Returning User)

**Goal:** Verify user and partner state is restored from server.

#### Android: Logout

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | Go to Profile | Shows profile screen | Navigation |
| 2 | Scroll to bottom | Shows "Sign Out" button | Logout option |
| 3 | Tap "Sign Out" | Confirm dialog appears | Confirmation |
| 4 | Confirm | Returns to AuthScreen | Local data cleared |

#### Android: Login Again

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | Enter `test1@togetherremind.com` | Email field filled | - |
| 2 | Tap "Continue (Dev Mode)" | Brief loading | Auth + getProfile |
| 3 | Auto-navigates | Shows HomeScreen (not NameEntry!) | Existing user detected |
| 4 | Check partner name | Shows "ChromeUser" | Partner restored from server |
| 5 | Check own name | Shows "AndroidUser" | User data restored |

✅ **Check:** User goes directly to HomeScreen, not NameEntryScreen

---

### Scenario 4: Name Change Sync

**Goal:** Verify partner name updates propagate via polling.

#### Chrome: Change Name

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | Go to Profile | Shows profile screen | Navigation |
| 2 | Tap name/edit | Edit name dialog | Edit UI |
| 3 | Change to "ChromeUserUpdated" | Name accepted | updateName API |
| 4 | Save | Profile shows new name | Local update |

#### Android: Verify Name Sync

| Step | Action | Expected Result | Validates |
|------|--------|-----------------|-----------|
| 1 | Go to HomeScreen | Shows current partner name | Current state |
| 2 | Wait 30-60 seconds | Partner name updates | Polling sync |
| 3 | Check partner name | Shows "ChromeUserUpdated" | Server → client sync |

✅ **Check:** Android shows updated partner name without restart

---

## Verification Queries

Run these in the API directory to verify database state:

### Check Users Exist
```bash
npx tsx -e "
import { query } from './lib/db/pool';
async function main() {
  const r = await query(
    \"SELECT id, email, raw_user_meta_data->>'full_name' as name FROM auth.users WHERE email LIKE 'test%@togetherremind.com'\"
  );
  console.table(r.rows);
  process.exit(0);
}
main();
"
```

### Check Couple Exists
```bash
npx tsx -e "
import { query } from './lib/db/pool';
async function main() {
  const r = await query(
    \"SELECT c.id, u1.email as user1, u2.email as user2, c.created_at FROM couples c JOIN auth.users u1 ON c.user1_id = u1.id JOIN auth.users u2 ON c.user2_id = u2.id WHERE u1.email LIKE 'test%' OR u2.email LIKE 'test%'\"
  );
  console.table(r.rows);
  process.exit(0);
}
main();
"
```

### Check Push Tokens
```bash
npx tsx -e "
import { query } from './lib/db/pool';
async function main() {
  const r = await query(
    \"SELECT pt.user_id, u.email, pt.platform, LEFT(pt.fcm_token, 30) as token_prefix FROM user_push_tokens pt JOIN auth.users u ON pt.user_id = u.id WHERE u.email LIKE 'test%'\"
  );
  console.table(r.rows);
  process.exit(0);
}
main();
"
```

---

## Troubleshooting

### User goes to NameEntryScreen on returning login
- **Cause:** User metadata not saved correctly
- **Check:** Run users query above, verify `name` column has value

### Partner name not showing
- **Cause:** Partner.fromJson not parsing correctly
- **Check:** Look at API response in Flutter debug console

### Pairing code not generating
- **Cause:** Auth token issue
- **Check:** Verify user is authenticated, check API logs

### Name change not syncing
- **Cause:** Polling not running
- **Check:** Verify AuthWrapper is calling getStatus periodically

---

## Quick Reset (Start Over)

```bash
# Reset test accounts
cd /Users/joakimachren/Desktop/togetherremind/api
npx tsx scripts/setup_test_accounts.ts

# Clear Android app
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

# Clear Chrome (do manually in DevTools)

# Relaunch
/runtogether
```
