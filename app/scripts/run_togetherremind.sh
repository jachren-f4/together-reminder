#!/bin/bash
# Run TogetherRemind flavor in debug mode
#
# Usage: ./scripts/run_togetherremind.sh [android|ios|chrome]
# Default: Runs on the first available device

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"

cd "$APP_DIR"

PLATFORM="${1:-}"
DEVICE_FLAG=""

case "$PLATFORM" in
  android)
    DEVICE_FLAG="-d emulator-5554"
    echo "Running on Android emulator..."
    ;;
  ios)
    DEVICE_FLAG="-d $(flutter devices | grep -i 'iphone\|ipad' | head -1 | awk '{print $NF}' | tr -d '()')"
    echo "Running on iOS device..."
    ;;
  chrome)
    DEVICE_FLAG="-d chrome"
    echo "Running on Chrome..."
    ;;
  "")
    echo "Running on first available device..."
    ;;
  *)
    echo "Unknown platform: $PLATFORM"
    echo "Usage: ./scripts/run_togetherremind.sh [android|ios|chrome]"
    exit 1
    ;;
esac

echo "Building and running TogetherRemind..."
flutter run \
  --flavor togetherremind \
  --dart-define=BRAND=togetherRemind \
  $DEVICE_FLAG
