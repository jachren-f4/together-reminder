#!/bin/bash

# Resize all quest images to 170px height (maintaining aspect ratio)
# Usage: ./scripts/resize_quest_images.sh

QUEST_DIR="assets/brands/togetherremind/images/quests"
TARGET_HEIGHT=170

echo "Resizing quest images to ${TARGET_HEIGHT}px height..."
echo "Directory: $QUEST_DIR"
echo ""

cd "$(dirname "$0")/.." || exit 1

for img in "$QUEST_DIR"/*.png; do
    if [ -f "$img" ]; then
        filename=$(basename "$img")

        # Get current dimensions
        dimensions=$(identify -format "%wx%h" "$img")

        # Resize to 170px height, width auto-calculated
        convert "$img" -resize "x${TARGET_HEIGHT}" "$img"

        # Get new dimensions
        new_dimensions=$(identify -format "%wx%h" "$img")

        echo "✓ $filename: $dimensions → $new_dimensions"
    fi
done

echo ""
echo "Done! All images resized to ${TARGET_HEIGHT}px height."
