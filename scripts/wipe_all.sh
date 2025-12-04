#!/bin/bash

# =============================================================================
# WIPE ALL ACCOUNTS & DATA - Nuclear option for complete reset
# =============================================================================
#
# This script wipes EVERYTHING except John & Jane dummy accounts:
#   1. Deletes all users and their couples from Supabase
#   2. Clears all game progress, quests, LP, etc.
#   3. Clears Android app data (uninstalls)
#   4. Clears Chrome IndexedDB
#
# Protected accounts (NOT deleted):
#   - john@test.local
#   - jane@test.local
#   - Their couple (11111111-1111-1111-1111-111111111111)
#
# Usage:
#   ./scripts/wipe_all.sh
#
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         WIPE ALL ACCOUNTS & DATA                           ║"
echo "║         (except John & Jane dummy accounts)                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

cd "$ROOT_DIR/api"

# Source environment variables
if [ -f .env.local ]; then
    export $(grep -v '^#' .env.local | xargs)
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1/3: Wipe All Accounts from Supabase"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
npx tsx scripts/wipe_all_accounts.ts

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2/3: Clear Android Hive (Uninstall App)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ADB=~/Library/Android/sdk/platform-tools/adb

if $ADB devices | grep -q "emulator"; then
    echo "📱 Android emulator detected. Uninstalling app..."
    $ADB uninstall com.togetherremind.togetherremind 2>/dev/null && echo "   ✓ App uninstalled" || echo "   - App not installed"
else
    echo "⚠️  No Android emulator running. Skipping uninstall."
    echo "   To clear manually: adb uninstall com.togetherremind.togetherremind"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3/3: Clear Chrome Hive (IndexedDB)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clear localhost IndexedDB data from Chrome's profile
CHROME_PROFILE="$HOME/Library/Application Support/Google/Chrome/Default"
INDEXEDDB_PATH="$CHROME_PROFILE/IndexedDB"

if [ -d "$INDEXEDDB_PATH" ]; then
    echo "🌐 Clearing Chrome IndexedDB for localhost..."

    # Find and remove localhost IndexedDB directories
    LOCALHOST_DBS=$(find "$INDEXEDDB_PATH" -maxdepth 1 -type d -name "*localhost*" -o -name "*127.0.0.1*" 2>/dev/null)

    if [ -n "$LOCALHOST_DBS" ]; then
        # Kill Chrome first to release file locks
        if pgrep -x "Google Chrome" > /dev/null; then
            echo "   Closing Chrome to release file locks..."
            pkill -9 "Google Chrome" 2>/dev/null
            sleep 1
        fi

        # Remove the IndexedDB directories
        echo "$LOCALHOST_DBS" | while read -r db_path; do
            if [ -n "$db_path" ] && [ -d "$db_path" ]; then
                rm -rf "$db_path" && echo "   ✓ Removed: $(basename "$db_path")"
            fi
        done
        echo "   ✓ Chrome IndexedDB cleared"
    else
        echo "   - No localhost IndexedDB data found"
    fi
else
    echo "   ⚠️  Chrome profile not found at expected location"
    echo "   Manual clear: DevTools → Application → Storage → Clear site data"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    WIPE COMPLETE                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ All accounts wiped (except John & Jane)"
echo "✅ All progress cleared"
echo "✅ Android: App uninstalled"
echo "✅ Chrome:  IndexedDB cleared"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "REMAINING IN DATABASE:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   Users:"
echo "   - john@test.local"
echo "   - jane@test.local"
echo ""
echo "   Couple:"
echo "   - 11111111-1111-1111-1111-111111111111"
echo ""
echo "For iOS physical devices, uninstall the app manually."
echo ""
