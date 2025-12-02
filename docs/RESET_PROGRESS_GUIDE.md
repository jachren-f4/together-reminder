# Reset Progress Guide

Complete guide for wiping all user/couple progress in TogetherRemind.

---

## Quick Start

```bash
# Full reset (recommended)
cd /Users/joakimachren/Desktop/togetherremind
./scripts/reset_all_progress.sh
```

This wipes **everything** for the dev test couple and prompts for confirmation.

---

## What Gets Reset

| Storage | Data Cleared |
|---------|--------------|
| **Supabase** | Daily quests, quiz matches, game matches (Linked, Word Search, Memory), LP awards, progression tracking, leaderboard |
| **Android Hive** | All local cached data (via app uninstall) |
| **Chrome Hive** | All local cached data (IndexedDB auto-cleared by script) |

---

## Running the Scripts

### Option 1: Full Reset (All Storage)

```bash
cd /Users/joakimachren/Desktop/togetherremind
./scripts/reset_all_progress.sh
```

For a specific couple:
```bash
./scripts/reset_all_progress.sh "your-couple-uuid-here"
```

### Option 2: Supabase Only

```bash
cd /Users/joakimachren/Desktop/togetherremind/api
npx tsx scripts/reset_couple_progress.ts

# For specific couple:
npx tsx scripts/reset_couple_progress.ts "your-couple-uuid-here"
```

### Option 3: Android Hive Only

```bash
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
```

### Option 4: Chrome Hive Only

The full reset script automatically clears Chrome IndexedDB. For manual clearing:

- Option A: DevTools → Application → Storage → "Clear site data"
- Option B: `chrome://settings/siteData` → Search "localhost" → Delete
- Option C: Delete IndexedDB directly:
  ```bash
  # Close Chrome first
  pkill -9 "Google Chrome"
  # Remove localhost IndexedDB
  rm -rf ~/Library/Application\ Support/Google/Chrome/Default/IndexedDB/*localhost*
  ```

---

## Verification

### 1. Verify Supabase Data is Cleared

The reset script prints verification automatically. To check manually:

```bash
cd /Users/joakimachren/Desktop/togetherremind/api

# Start the API server (needed for DB connection)
npm run dev &

# In another terminal, run verification queries:
npx tsx -e "
import { query } from './lib/db/pool';

const COUPLE_ID = '11111111-1111-1111-1111-111111111111';

async function verify() {
  const checks = [
    { name: 'daily_quests', q: 'SELECT COUNT(*) FROM daily_quests WHERE couple_id = \$1' },
    { name: 'quiz_matches', q: 'SELECT COUNT(*) FROM quiz_matches WHERE couple_id = \$1' },
    { name: 'linked_matches', q: 'SELECT COUNT(*) FROM linked_matches WHERE couple_id = \$1' },
    { name: 'word_search_matches', q: 'SELECT COUNT(*) FROM word_search_matches WHERE couple_id = \$1' },
    { name: 'love_point_awards', q: 'SELECT COUNT(*) FROM love_point_awards WHERE couple_id = \$1' },
    { name: 'quiz_progression', q: 'SELECT COUNT(*) FROM quiz_progression WHERE couple_id = \$1' },
    { name: 'branch_progression', q: 'SELECT COUNT(*) FROM branch_progression WHERE couple_id = \$1' },
  ];

  console.log('\nSupabase Verification:\n');
  for (const check of checks) {
    const result = await query(check.q, [COUPLE_ID]);
    const count = result.rows[0].count;
    const status = count === '0' ? '✓' : '✗';
    console.log(\`  \${status} \${check.name}: \${count} rows\`);
  }

  // Check LP
  const lp = await query('SELECT total_lp FROM couples WHERE id = \$1', [COUPLE_ID]);
  const lpValue = lp.rows[0]?.total_lp ?? 'N/A';
  const lpStatus = lpValue === 0 ? '✓' : '✗';
  console.log(\`  \${lpStatus} couples.total_lp: \${lpValue}\`);

  console.log('');
  process.exit(0);
}

verify();
"
```

**Expected output (all zeros):**
```
Supabase Verification:

  ✓ daily_quests: 0 rows
  ✓ quiz_matches: 0 rows
  ✓ linked_matches: 0 rows
  ✓ word_search_matches: 0 rows
  ✓ love_point_awards: 0 rows
  ✓ quiz_progression: 0 rows
  ✓ branch_progression: 0 rows
  ✓ couples.total_lp: 0
```

### 2. Verify in the App

After launching fresh apps:

| Check | Expected Result |
|-------|-----------------|
| LP counter (top of home screen) | `0` |
| Daily quest badges | `Begin together` (italic) |
| Side quest badges | `Begin together` (italic) |
| Activities → Game history | Empty / no completed games |
| Debug menu (double-tap greeting) | Quests tab shows empty or fresh quests |

---

## Dev Test Users

| User | Device | User ID |
|------|--------|---------|
| TestiY | Android Emulator | `e2ecabb7-43ee-422c-b49c-f0636d57e6d2` |
| Jokke | Chrome | `634e2af3-1625-4532-89c0-2d0900a2690a` |
| **Couple ID** | - | `11111111-1111-1111-1111-111111111111` |

---

## After Reset: Launch Fresh Apps

```bash
# Kill any existing Flutter processes
pkill -9 -f "flutter"

# Launch Android (TestiY)
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind &

# Wait for quest generation, then launch Chrome (Jokke)
sleep 3
flutter run -d chrome --dart-define=BRAND=togetherRemind &
```

Or use the slash command:
```
/runtogether
```

---

## Troubleshooting

### "Connection refused" when running Supabase script

The script connects to the production Supabase via the API. Make sure:
1. You have internet connection
2. The `.env` file in `/api` has correct `DATABASE_URL` or `SUPABASE_URL`

### Chrome still shows old data

Chrome aggressively caches IndexedDB. Try:
1. Hard refresh: `Cmd+Shift+R`
2. Clear site data in DevTools
3. Use Incognito mode
4. Kill Chrome entirely: `pkill -9 -f "chrome"`

### Android app won't uninstall

```bash
# Check if emulator is running
~/Library/Android/sdk/platform-tools/adb devices

# Force uninstall
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

# If that fails, try the other bundle ID
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind2
```

---

## Script Locations

| Script | Purpose |
|--------|---------|
| `scripts/reset_all_progress.sh` | Master script - runs everything |
| `api/scripts/reset_couple_progress.ts` | Supabase only |

---

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Main technical guide
- [Testing Procedure](../CLAUDE.md#complete-clean-testing-procedure) - Full clean testing steps
- [runtogether command](../.claude/commands/runtogether.md) - Quick launch guide
