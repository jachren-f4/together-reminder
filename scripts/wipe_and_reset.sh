#!/bin/bash

# =============================================================================
# WIPE TEST ACCOUNTS & FULL RESET - Complete cleanup for testing
# =============================================================================
#
# This script does everything:
#   1. Wipes test accounts (joakim.achren@fingersoft.net, joachren@gmail.com)
#   2. Resets dev couple progress (11111111-1111-1111-1111-111111111111)
#   3. Clears Android app data (uninstalls)
#   4. Clears Chrome IndexedDB
#
# Usage:
#   ./scripts/wipe_and_reset.sh
#
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DEV_COUPLE_ID="11111111-1111-1111-1111-111111111111"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         WIPE TEST ACCOUNTS & FULL RESET                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

cd "$ROOT_DIR/api"

# Source environment variables
if [ -f .env.local ]; then
    export $(grep -v '^#' .env.local | xargs)
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1/4: Wipe Test Accounts from Supabase"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
npx tsx scripts/wipe_test_accounts.ts

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2/4: Reset Dev Couple Progress"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Couple: $DEV_COUPLE_ID"
npx tsx scripts/reset_couple_progress.ts "$DEV_COUPLE_ID"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3/4: Clear Android Hive (Uninstall App)"
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
echo "STEP 4/4: Clear Chrome Hive (IndexedDB)"
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
echo "║                    RESET COMPLETE                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Test accounts: Wiped (if they existed)"
echo "✅ Dev couple:    Progress reset to zero"
echo "✅ Android:       App uninstalled (Hive cleared)"
echo "✅ Chrome:        IndexedDB cleared"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NEXT STEPS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "For iOS physical devices, uninstall the app manually."
echo ""
echo "Test emails ready for fresh signup:"
echo "   - joakim.achren@fingersoft.net"
echo "   - joachren@gmail.com"
echo ""
