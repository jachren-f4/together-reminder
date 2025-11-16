# Image Processing Workflow

**ImageMagick-based image optimization for TogetherRemind assets**

---

## Overview

This document describes the image processing workflow used to prepare affirmation quiz images for the TogetherRemind app. The workflow uses ImageMagick to resize and crop images for optimal display and file size.

### Two-Stage Processing Pipeline

1. **Stage 1: Resize to Square** - Normalize originals to 1024×1024 PNG
2. **Stage 2: Auto-Crop to Content** - Trim whitespace and optimize dimensions

---

## File Structure

```
assets/raw_images/
├── *.png                    # Original source images (variable sizes)
├── processed/               # Stage 1: Resized to 1024×1024
│   └── *.png               # Square format, centered content
└── cropped/                 # Stage 2: Auto-cropped to content
    └── *.png               # Variable dimensions, optimized file size
```

### Folder Purposes

| Folder | Purpose | Dimensions | File Sizes |
|--------|---------|------------|------------|
| **root** | Original source images from design tool | Variable | 371 KB - 927 KB |
| **processed/** | Normalized square images for consistent aspect ratio | 1024×1024 | 636 KB - 1.3 MB |
| **cropped/** | Final optimized images with whitespace removed | Variable (466×589 to 874×784) | 83 KB - 747 KB |

**Note:** `assets/raw_images/` is gitignored to avoid committing large binary files.

---

## Processing History

### November 14, 2025

**Processing Timeline:**
- **10:40-11:15 AM** - Stage 1: Five images resized to 1024×1024
- **11:13-11:46 AM** - Stage 2: Thirteen images auto-cropped

**Images Processed:**

**Stage 1 (processed/):**
1. Daily Goodness.png (1024×1024, 637 KB)
2. Feel-Good Foundations.png (1024×1024, 735 KB)
3. Getting Comfortable.png (1024×1024, 826 KB)
4. Playful Moments.png (1024×1024, 808 KB)
5. simple_joys.png (1024×1024, 1.3 MB)

**Stage 2 (cropped/):**
1. Connection Basics.png (694×482, 198 KB)
2. Daily Goodness.png (651×721, 308 KB)
3. Easy Check-Ins.png (589×466, 84 KB)
4. Feel-Good Foundations.png (891×693, 436 KB)
5. Getting Comfortable.png (784×874, 508 KB)
6. Growing Familiarity.png (278 KB)
7. Kindness Everyday.png (389 KB)
8. Playful Moments.png (469 KB)
9. Positive Echoes.png (576 KB)
10. Shared Positives.png (176 KB)
11. Staying Curious.png (520 KB)
12. Talking Comfortably.png (159 KB)
13. simple_joys.png (747 KB)

---

## ImageMagick Commands

### Prerequisites

Install ImageMagick (if not already installed):

```bash
# macOS
brew install imagemagick

# Ubuntu/Debian
sudo apt-get install imagemagick

# Verify installation
magick --version
```

### Stage 1: Resize to 1024×1024

Creates square images with centered content:

```bash
cd /Users/joakimachren/Desktop/togetherremind/assets/raw_images
mkdir -p processed

# Single image
magick convert "Original Image.png" \
  -resize 1024x1024 \
  -gravity center \
  -extent 1024x1024 \
  "processed/Original Image.png"

# Batch process all PNG files
for img in *.png; do
  if [ -f "$img" ]; then
    echo "Processing: $img"
    magick convert "$img" \
      -resize 1024x1024 \
      -gravity center \
      -extent 1024x1024 \
      "processed/$img"
  fi
done
```

**Options explained:**
- `-resize 1024x1024` - Resize to fit within 1024×1024 (maintains aspect ratio)
- `-gravity center` - Center the image within the canvas
- `-extent 1024x1024` - Extend canvas to exactly 1024×1024 (adds padding if needed)

### Stage 2: Auto-Crop to Content

Removes whitespace and optimizes dimensions:

```bash
cd /Users/joakimachren/Desktop/togetherremind/assets/raw_images
mkdir -p cropped

# Single image (from processed folder)
magick convert "processed/Original Image.png" \
  -trim \
  +repage \
  "cropped/Original Image.png"

# Batch process from processed/ folder
for img in processed/*.png; do
  if [ -f "$img" ]; then
    echo "Cropping: $(basename "$img")"
    magick convert "$img" \
      -trim \
      +repage \
      "cropped/$(basename "$img")"
  fi
done

# Batch process from root folder (if processed/ doesn't exist)
for img in *.png; do
  if [ -f "$img" ]; then
    echo "Cropping: $img"
    magick convert "$img" \
      -trim \
      +repage \
      "cropped/$img"
  fi
done
```

**Options explained:**
- `-trim` - Remove border pixels that match the corner colors (auto-detects whitespace)
- `+repage` - Reset virtual canvas information (prevents offset issues)

---

## Usage Instructions

### Processing New Images

**Step 1: Add original images**
```bash
# Place new PNG files in assets/raw_images/
cd /Users/joakimachren/Desktop/togetherremind/assets/raw_images
# Copy your new images here
```

**Step 2: Run Stage 1 (resize to square)**
```bash
# Process new images
for img in *.png; do
  if [ -f "$img" ] && [ ! -f "processed/$img" ]; then
    echo "Resizing: $img"
    magick convert "$img" \
      -resize 1024x1024 \
      -gravity center \
      -extent 1024x1024 \
      "processed/$img"
  fi
done
```

**Step 3: Run Stage 2 (auto-crop)**
```bash
# Crop processed images
for img in processed/*.png; do
  filename=$(basename "$img")
  if [ -f "$img" ] && [ ! -f "cropped/$filename" ]; then
    echo "Cropping: $filename"
    magick convert "$img" \
      -trim \
      +repage \
      "cropped/$filename"
  fi
done
```

**Step 4: Verify results**
```bash
# Check file sizes and dimensions
ls -lh cropped/
file cropped/*.png | grep -o '[0-9]* x [0-9]*'
```

### Quick Script (One-Click Processing)

Create a reusable script for future processing:

```bash
#!/bin/bash
# File: /Users/joakimachren/Desktop/togetherremind/assets/raw_images/process_images.sh

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🖼️  Starting image processing workflow..."

# Create output directories
mkdir -p processed cropped

# Stage 1: Resize to 1024x1024
echo ""
echo "📐 Stage 1: Resizing images to 1024×1024..."
count=0
for img in *.png; do
  if [ -f "$img" ] && [ ! -f "processed/$img" ]; then
    echo "  → Processing: $img"
    magick convert "$img" \
      -resize 1024x1024 \
      -gravity center \
      -extent 1024x1024 \
      "processed/$img"
    ((count++))
  fi
done
echo "✅ Resized $count images"

# Stage 2: Auto-crop to content
echo ""
echo "✂️  Stage 2: Auto-cropping to content..."
count=0
for img in processed/*.png; do
  filename=$(basename "$img")
  if [ -f "$img" ] && [ ! -f "cropped/$filename" ]; then
    echo "  → Cropping: $filename"
    magick convert "$img" \
      -trim \
      +repage \
      "cropped/$filename"
    ((count++))
  fi
done
echo "✅ Cropped $count images"

echo ""
echo "🎉 Processing complete!"
echo "📊 Results:"
echo "  - Processed: $(ls -1 processed/*.png 2>/dev/null | wc -l) images"
echo "  - Cropped: $(ls -1 cropped/*.png 2>/dev/null | wc -l) images"
```

**Make it executable:**
```bash
chmod +x /Users/joakimachren/Desktop/togetherremind/assets/raw_images/process_images.sh
```

**Run it:**
```bash
cd /Users/joakimachren/Desktop/togetherremind/assets/raw_images
./process_images.sh
```

---

## Technical Details

### Output Format Specifications

| Property | Value | Rationale |
|----------|-------|-----------|
| **Format** | PNG | Lossless quality, transparency support |
| **Color Mode** | 8-bit/color RGBA | Standard web format, alpha channel for transparency |
| **Processed Size** | 1024×1024 | Square format for consistent UI layout |
| **Cropped Size** | Variable | Optimized to content bounds (typically 466×589 to 874×784) |
| **File Size Range** | 83 KB - 747 KB | Optimized for mobile bandwidth |

### Quality vs File Size

**Original images:**
- Dimensions: Variable (design export sizes)
- File sizes: 371 KB - 927 KB
- Format: PNG with varying compression

**Processed images (1024×1024):**
- Consistent square aspect ratio
- Larger file sizes (636 KB - 1.3 MB) due to padding
- **Use case:** Intermediate format for consistent cropping

**Cropped images (final):**
- Optimized dimensions (whitespace removed)
- Smaller file sizes (83 KB - 747 KB)
- **Use case:** Production assets for app deployment

### ImageMagick Version Compatibility

The commands in this document are compatible with:
- **ImageMagick 7.x** - Modern syntax (`magick convert`)
- **ImageMagick 6.x** - Legacy syntax (use `convert` instead of `magick convert`)

**Check your version:**
```bash
magick --version
# or
convert --version
```

---

## Advanced Options

### Custom Crop with Fuzz Factor

If `-trim` doesn't detect whitespace correctly, add a fuzz factor:

```bash
magick convert "input.png" \
  -fuzz 10% \
  -trim \
  +repage \
  "output.png"
```

**Fuzz explained:** Treats pixels within 10% similarity as matching (helps with anti-aliased edges)

### Resize with Quality Control

For better compression:

```bash
magick convert "input.png" \
  -resize 1024x1024 \
  -gravity center \
  -extent 1024x1024 \
  -quality 90 \
  -strip \
  "output.png"
```

**Additional options:**
- `-quality 90` - PNG compression level (1-100, higher = better quality)
- `-strip` - Remove metadata (EXIF, color profiles) to reduce file size

### Batch Rename with Prefix

Add prefix to processed files:

```bash
for img in *.png; do
  magick convert "$img" \
    -trim +repage \
    "cropped/quiz_${img}"
done
```

---

## Troubleshooting

### Command not found: magick

**Problem:** ImageMagick not installed or not in PATH

**Solution:**
```bash
# macOS
brew install imagemagick

# Verify
which magick
magick --version
```

### Images look pixelated after resize

**Problem:** Upscaling small images to 1024×1024

**Solution:** Use `-filter` option for better interpolation:
```bash
magick convert "input.png" \
  -filter Lanczos \
  -resize 1024x1024 \
  -gravity center \
  -extent 1024x1024 \
  "output.png"
```

### Trim removes too much content

**Problem:** `-trim` is too aggressive

**Solution:** Add border padding after trim:
```bash
magick convert "input.png" \
  -trim +repage \
  -border 20 \
  -bordercolor white \
  "output.png"
```

### File sizes are too large

**Problem:** PNG files exceed bandwidth budget

**Solution:** Optimize with pngquant or convert to WebP:
```bash
# Option 1: Optimize PNG with pngquant
pngquant --quality=65-80 "input.png" --output "output.png"

# Option 2: Convert to WebP (smaller file size)
magick convert "input.png" \
  -quality 85 \
  "output.webp"
```

---

## Git Workflow

### .gitignore Configuration

The `assets/raw_images/` folder is gitignored (line 6 of `.gitignore`):

```gitignore
# Image processing artifacts
assets/raw_images/
```

**Rationale:**
- Original and intermediate images are large (371 KB - 1.3 MB)
- Only final cropped images are committed to `assets/images/` (if used in app)
- Keeps repository size small
- Source images can be stored in design tool or cloud storage

### Committing Final Assets

If cropped images are used in the app:

```bash
# Copy final images to production assets folder
cp assets/raw_images/cropped/*.png assets/images/affirmations/

# Commit only final production assets
git add assets/images/affirmations/
git commit -m "Add optimized affirmation quiz images"
```

---

## Resources

- [ImageMagick Official Documentation](https://imagemagick.org/index.php)
- [ImageMagick Command-Line Options](https://imagemagick.org/script/command-line-options.php)
- [PNG Optimization Best Practices](https://developers.google.com/speed/docs/insights/OptimizeImages)
- [ImageMagick Examples - Resize](https://imagemagick.org/Usage/resize/)
- [ImageMagick Examples - Crop and Trim](https://imagemagick.org/Usage/crop/)

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2025-11-15 | Initial documentation created | Claude Code |
| 2025-11-14 | Image processing performed (13 images cropped) | - |

---

**Last Updated:** 2025-11-15
