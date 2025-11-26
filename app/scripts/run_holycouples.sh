#!/bin/bash
# Run Holy Couples flavor in debug mode

# Default to Chrome if no device specified
if [ -n "$1" ]; then
    DEVICE_FLAG="-d $1"
else
    DEVICE_FLAG=""
fi

echo "🙏 Starting Holy Couples..."
echo ""

cd "$(dirname "$0")/.." || exit 1

flutter run \
    --flavor holycouples \
    --dart-define=BRAND=holyCouples \
    $DEVICE_FLAG

# Usage examples:
# ./scripts/run_holycouples.sh              # Default device
# ./scripts/run_holycouples.sh chrome       # Web
# ./scripts/run_holycouples.sh emulator-5554  # Android
