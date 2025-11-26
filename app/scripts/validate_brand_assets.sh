#!/bin/bash
# Validate brand assets for all configured brands
#
# Usage: ./scripts/validate_brand_assets.sh [brand_id]
# If no brand_id specified, validates all brands

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
ASSETS_DIR="$APP_DIR/assets/brands"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Required directories per brand
REQUIRED_DIRS=(
  "data"
  "animations"
  "images/quests"
  "words"
)

# Required JSON files in data/
REQUIRED_DATA_FILES=(
  "quiz_questions.json"
  "affirmation_quizzes.json"
  "you_or_me_questions.json"
)

# Required animation files
REQUIRED_ANIMATION_FILES=(
  "poke_send.json"
  "poke_receive.json"
  "poke_mutual.json"
)

# Required word files
REQUIRED_WORD_FILES=(
  "english_words.json"
)

# Track validation results
ERRORS=0
WARNINGS=0

log_error() {
  echo -e "${RED}ERROR:${NC} $1"
  ((ERRORS++))
}

log_warning() {
  echo -e "${YELLOW}WARNING:${NC} $1"
  ((WARNINGS++))
}

log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

validate_json() {
  local file=$1
  if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
    log_error "Invalid JSON: $file"
    return 1
  fi
  return 0
}

validate_brand() {
  local brand_id=$1
  local brand_dir="$ASSETS_DIR/$brand_id"

  echo ""
  echo "========================================"
  echo "Validating brand: $brand_id"
  echo "========================================"

  # Check brand directory exists
  if [ ! -d "$brand_dir" ]; then
    log_error "Brand directory not found: $brand_dir"
    return 1
  fi

  # Check required directories
  echo ""
  echo "Checking directories..."
  for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$brand_dir/$dir" ]; then
      log_success "$dir/"
    else
      log_error "Missing directory: $dir/"
    fi
  done

  # Check required data files
  echo ""
  echo "Checking data files..."
  for file in "${REQUIRED_DATA_FILES[@]}"; do
    local filepath="$brand_dir/data/$file"
    if [ -f "$filepath" ]; then
      if validate_json "$filepath"; then
        log_success "data/$file"
      fi
    else
      log_error "Missing file: data/$file"
    fi
  done

  # Check animation files
  echo ""
  echo "Checking animation files..."
  for file in "${REQUIRED_ANIMATION_FILES[@]}"; do
    local filepath="$brand_dir/animations/$file"
    if [ -f "$filepath" ]; then
      if validate_json "$filepath"; then
        log_success "animations/$file"
      fi
    else
      log_error "Missing file: animations/$file"
    fi
  done

  # Check word files
  echo ""
  echo "Checking word files..."
  for file in "${REQUIRED_WORD_FILES[@]}"; do
    local filepath="$brand_dir/words/$file"
    if [ -f "$filepath" ]; then
      if validate_json "$filepath"; then
        log_success "words/$file"
      fi
    else
      log_error "Missing file: words/$file"
    fi
  done

  # Check quest images exist (at least one)
  echo ""
  echo "Checking quest images..."
  local quest_images=$(find "$brand_dir/images/quests" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$quest_images" -gt 0 ]; then
    log_success "Found $quest_images quest image(s)"
  else
    log_warning "No quest images found in images/quests/"
  fi

  # Validate quiz_questions.json structure (array of questions)
  echo ""
  echo "Validating quiz content..."
  local quiz_file="$brand_dir/data/quiz_questions.json"
  if [ -f "$quiz_file" ]; then
    local question_count=$(python3 -c "import json; data=json.load(open('$quiz_file')); print(len(data) if isinstance(data, list) else len(data.get('questions', [])))" 2>/dev/null || echo "0")
    if [ "$question_count" -gt 0 ]; then
      log_success "quiz_questions.json has $question_count questions"
    else
      log_warning "quiz_questions.json has no questions"
    fi
  fi

  # Validate affirmation_quizzes.json structure
  local affirmation_file="$brand_dir/data/affirmation_quizzes.json"
  if [ -f "$affirmation_file" ]; then
    local quiz_count=$(python3 -c "import json; data=json.load(open('$affirmation_file')); print(len(data) if isinstance(data, list) else len(data.get('quizzes', [])))" 2>/dev/null || echo "0")
    if [ "$quiz_count" -gt 0 ]; then
      log_success "affirmation_quizzes.json has $quiz_count quizzes"
    else
      log_warning "affirmation_quizzes.json has no quizzes"
    fi
  fi

  # Validate you_or_me_questions.json structure
  local yom_file="$brand_dir/data/you_or_me_questions.json"
  if [ -f "$yom_file" ]; then
    local yom_count=$(python3 -c "import json; data=json.load(open('$yom_file')); print(len(data) if isinstance(data, list) else len(data.get('questions', [])))" 2>/dev/null || echo "0")
    if [ "$yom_count" -gt 0 ]; then
      log_success "you_or_me_questions.json has $yom_count questions"
    else
      log_warning "you_or_me_questions.json has no questions"
    fi
  fi
}

# Main
echo "Brand Asset Validator"
echo "====================="
echo "Assets directory: $ASSETS_DIR"

if [ -n "$1" ]; then
  # Validate specific brand
  validate_brand "$1"
else
  # Validate all brands
  for brand_dir in "$ASSETS_DIR"/*/; do
    if [ -d "$brand_dir" ]; then
      brand_id=$(basename "$brand_dir")
      validate_brand "$brand_id"
    fi
  done
fi

# Summary
echo ""
echo "========================================"
echo "Validation Summary"
echo "========================================"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}All validations passed!${NC}"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}Passed with $WARNINGS warning(s)${NC}"
  exit 0
else
  echo -e "${RED}Failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
  exit 1
fi
