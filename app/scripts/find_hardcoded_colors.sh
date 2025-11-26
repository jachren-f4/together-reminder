#!/bin/bash
# Find all hardcoded color references in Dart files
#
# This script identifies files that need color migration:
# 1. Colors.* references (Flutter's built-in colors)
# 2. Color(0x...) hardcoded hex values
# 3. Color.fromRGBO/fromARGB calls
#
# Usage: ./scripts/find_hardcoded_colors.sh [--save]
# With --save: outputs to docs/COLOR_MIGRATION_AUDIT.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$APP_DIR")"

cd "$APP_DIR"

SAVE_TO_FILE=false
if [[ "$1" == "--save" ]]; then
  SAVE_TO_FILE=true
fi

generate_report() {
  echo "# Color Migration Audit"
  echo ""
  echo "Generated: $(date)"
  echo ""
  echo "---"
  echo ""

  # Count totals first
  COLORS_TOTAL=$(grep -r "Colors\." lib/ --include="*.dart" 2>/dev/null | wc -l | tr -d ' ')
  HEX_TOTAL=$(grep -r "Color(0x" lib/ --include="*.dart" 2>/dev/null | wc -l | tr -d ' ')
  RGBA_TOTAL=$(grep -rE "Color\.from(RGBO|ARGB)" lib/ --include="*.dart" 2>/dev/null | wc -l | tr -d ' ')

  echo "## Summary"
  echo ""
  echo "| Type | Count |"
  echo "|------|-------|"
  echo "| \`Colors.*\` references | $COLORS_TOTAL |"
  echo "| \`Color(0x...)\` hex values | $HEX_TOTAL |"
  echo "| \`Color.fromRGBO/ARGB\` calls | $RGBA_TOTAL |"
  echo "| **Total** | $((COLORS_TOTAL + HEX_TOTAL + RGBA_TOTAL)) |"
  echo ""
  echo "---"
  echo ""

  echo "## Files with \`Colors.*\` References (by count)"
  echo ""
  echo "| File | Count |"
  echo "|------|-------|"

  # Group by file and count, sorted by count descending
  grep -r "Colors\." lib/ --include="*.dart" -c 2>/dev/null | \
    grep -v ":0$" | \
    sort -t: -k2 -nr | \
    while IFS=: read -r file count; do
      # Make path relative
      rel_path="${file#lib/}"
      echo "| \`$rel_path\` | $count |"
    done

  echo ""
  echo "---"
  echo ""

  echo "## Files with \`Color(0x...)\` References (by count)"
  echo ""
  echo "| File | Count |"
  echo "|------|-------|"

  grep -r "Color(0x" lib/ --include="*.dart" -c 2>/dev/null | \
    grep -v ":0$" | \
    sort -t: -k2 -nr | \
    while IFS=: read -r file count; do
      rel_path="${file#lib/}"
      echo "| \`$rel_path\` | $count |"
    done

  echo ""
  echo "---"
  echo ""

  echo "## High Priority Files (>10 references)"
  echo ""
  echo "These files should be migrated first:"
  echo ""

  grep -r "Colors\." lib/ --include="*.dart" -c 2>/dev/null | \
    grep -v ":0$" | \
    sort -t: -k2 -nr | \
    while IFS=: read -r file count; do
      if [ "$count" -gt 10 ]; then
        rel_path="${file#lib/}"
        echo "- [ ] \`$rel_path\` ($count refs)"
      fi
    done

  echo ""
  echo "---"
  echo ""

  echo "## Exclusions (Debug/Test files)"
  echo ""
  echo "These files can be migrated later or left as-is:"
  echo ""

  grep -r "Colors\." lib/widgets/debug/ --include="*.dart" -c 2>/dev/null | \
    grep -v ":0$" | \
    while IFS=: read -r file count; do
      rel_path="${file#lib/}"
      echo "- \`$rel_path\` ($count refs)"
    done

  echo ""
  echo "---"
  echo ""

  echo "## Migration Guide"
  echo ""
  echo "Replace hardcoded colors with semantic colors from BrandLoader:"
  echo ""
  echo "\`\`\`dart"
  echo "// Before"
  echo "color: Colors.black"
  echo "color: Color(0xFF1A1A1A)"
  echo ""
  echo "// After"
  echo "color: BrandLoader().colors.textPrimary"
  echo "color: AppTheme.textPrimary"
  echo "\`\`\`"
  echo ""
  echo "### Color Mapping Reference"
  echo ""
  echo "| Old | New |"
  echo "|-----|-----|"
  echo "| \`Colors.black\` | \`BrandLoader().colors.textPrimary\` |"
  echo "| \`Colors.white\` | \`BrandLoader().colors.surface\` or \`.textOnPrimary\` |"
  echo "| \`Colors.grey\` | \`BrandLoader().colors.textSecondary\` |"
  echo "| \`Colors.red\` | \`BrandLoader().colors.error\` |"
  echo "| \`Colors.green\` | \`BrandLoader().colors.success\` |"
  echo "| \`Colors.orange\` | \`BrandLoader().colors.warning\` |"
  echo "| \`Colors.blue\` | \`BrandLoader().colors.info\` |"
  echo "| \`Colors.transparent\` | Keep as-is (universal) |"
}

if $SAVE_TO_FILE; then
  OUTPUT_FILE="$PROJECT_DIR/docs/COLOR_MIGRATION_AUDIT.md"
  generate_report > "$OUTPUT_FILE"
  echo "Report saved to: $OUTPUT_FILE"
  echo ""
  echo "Summary:"
  head -20 "$OUTPUT_FILE"
else
  generate_report
fi
