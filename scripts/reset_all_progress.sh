#!/bin/bash

# =============================================================================
# FULL PROGRESS RESET - Wipes ALL progress for a couple
# =============================================================================
#
# This script completely resets:
#   1. Supabase tables (quests, games, LP, progression)
#   2. Android Hive (uninstalls app)
#   3. Chrome Hive (instructions provided)
#
# Note: Firebase RTDB has been removed - all sync now uses Supabase
#
# Usage:
#   ./scripts/reset_all_progress.sh [coupleId]
#
# If no coupleId provided, uses dev test couple: 11111111-1111-1111-1111-111111111111
#
# =============================================================================

COUPLE_ID="${1:-11111111-1111-1111-1111-111111111111}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           FULL PROGRESS RESET                              ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  Couple: $COUPLE_ID  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Confirm
read -p "⚠️  This will PERMANENTLY DELETE all progress. Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1/3: Reset Supabase"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd "$ROOT_DIR/api"

# Source environment variables
if [ -f .env.local ]; then
    export $(grep -v '^#' .env.local | xargs)
fi

npx tsx scripts/reset_couple_progress.ts "$COUPLE_ID"

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
echo "║                    RESET COMPLETE                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Supabase: Cleared"
echo "✅ Android:  App uninstalled (Hive cleared)"
echo "✅ Chrome:   IndexedDB cleared"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NEXT STEPS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Launch fresh apps:"
echo "   cd $ROOT_DIR/app"
echo "   flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind &"
echo "   sleep 3"
echo "   flutter run -d chrome --dart-define=BRAND=togetherRemind &"
echo ""
echo "Or use: /runtogether"
echo ""
echo "Verify in app:"
echo "   - LP should show 0"
echo "   - Daily quests should show 'Begin together'"
echo "   - No completed games in history"
echo ""
