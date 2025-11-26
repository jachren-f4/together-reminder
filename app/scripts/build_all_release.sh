#!/bin/bash
# Build all flavor release builds
#
# Usage: ./scripts/build_all_release.sh [android|ios|all]
# Default: Builds for all platforms

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"

cd "$APP_DIR"

PLATFORM="${1:-all}"

# Brand configurations
# Format: brandId:flavorName:dartDefine
BRANDS=(
  "togetherremind:togetherremind:togetherRemind"
  "holycouples:holycouples:holyCouples"
  # Add more brands here as they're implemented:
  # "spicycouples:spicycouples:spicyCouples"
)

build_android() {
  local flavor=$1
  local dart_define=$2
  echo "Building Android APK for $flavor..."
  flutter build apk \
    --release \
    --flavor "$flavor" \
    --dart-define="BRAND=$dart_define"
  echo "APK: build/app/outputs/flutter-apk/app-$flavor-release.apk"
}

build_appbundle() {
  local flavor=$1
  local dart_define=$2
  echo "Building Android App Bundle for $flavor..."
  flutter build appbundle \
    --release \
    --flavor "$flavor" \
    --dart-define="BRAND=$dart_define"
  echo "AAB: build/app/outputs/bundle/${flavor}Release/app-$flavor-release.aab"
}

build_ios() {
  local flavor=$1
  local dart_define=$2
  echo "Building iOS for $flavor..."
  flutter build ios \
    --release \
    --flavor "$flavor" \
    --dart-define="BRAND=$dart_define"
  echo "iOS app: build/ios/iphoneos/Runner.app"
}

echo "========================================"
echo "Building release versions for all brands"
echo "========================================"
echo ""

for brand_config in "${BRANDS[@]}"; do
  IFS=':' read -r brand_id flavor dart_define <<< "$brand_config"

  echo "----------------------------------------"
  echo "Brand: $brand_id"
  echo "Flavor: $flavor"
  echo "Dart Define: $dart_define"
  echo "----------------------------------------"

  case "$PLATFORM" in
    android)
      build_android "$flavor" "$dart_define"
      build_appbundle "$flavor" "$dart_define"
      ;;
    ios)
      build_ios "$flavor" "$dart_define"
      ;;
    all)
      build_android "$flavor" "$dart_define"
      build_appbundle "$flavor" "$dart_define"
      build_ios "$flavor" "$dart_define"
      ;;
    *)
      echo "Unknown platform: $PLATFORM"
      echo "Usage: ./scripts/build_all_release.sh [android|ios|all]"
      exit 1
      ;;
  esac

  echo ""
done

echo "========================================"
echo "Build complete!"
echo "========================================"
