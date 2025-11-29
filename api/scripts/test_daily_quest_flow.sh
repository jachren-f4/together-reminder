#!/bin/bash
# Daily Quest Flow Test Suite
# Tests the full daily quest flow for Classic Quiz, Affirmation Quiz, and You-or-Me
#
# Usage:
#   ./test_daily_quest_flow.sh                    # Run all tests
#   ./test_daily_quest_flow.sh --verbose          # Show debug output
#   ./test_daily_quest_flow.sh --test=classic     # Run only classic quiz test
#   ./test_daily_quest_flow.sh --test=affirmation # Run only affirmation test
#   ./test_daily_quest_flow.sh --test=you_or_me   # Run only you-or-me test
#   ./test_daily_quest_flow.sh --test=verify_lp   # Run only LP verification
#
# Environment:
#   API_URL=https://example.com ./test_daily_quest_flow.sh  # Test against specific API

# Don't exit on first error - run all tests
# set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helpers
source "$SCRIPT_DIR/lib/test_helpers.sh"
source "$SCRIPT_DIR/lib/user_config.sh"

# Parse arguments
VERBOSE=false
SPECIFIC_TEST=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --test=*)
      SPECIFIC_TEST="${1#*=}"
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --verbose, -v      Show debug output"
      echo "  --test=NAME        Run only specific test (classic, affirmation, you_or_me, verify_lp)"
      echo "  --help, -h         Show this help"
      echo ""
      echo "Environment:"
      echo "  API_URL            API base URL (default: http://localhost:3000)"
      echo ""
      echo "Examples:"
      echo "  $0                                    # Run all tests"
      echo "  $0 --verbose                          # Run with debug output"
      echo "  $0 --test=classic                     # Run only classic quiz test"
      echo "  API_URL=https://api.example.com $0    # Test against production"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Header
echo ""
echo "========================================"
echo "  Daily Quest Test Suite"
echo "========================================"
echo ""
echo "Date:      $TODAY"
echo "API:       $API_URL"
echo "Jokke ID:  $JOKKE_ID (Chrome - goes FIRST)"
echo "TestiY ID: $TESTIY_ID (Android - goes SECOND)"
echo "Couple:    $COUPLE_ID"
echo ""
echo "----------------------------------------"
echo ""

# Check for jq
if ! command -v jq &> /dev/null; then
  echo -e "${RED}[ERROR]${NC} jq is required but not installed"
  echo "Install with: brew install jq"
  exit 1
fi

# Run tests
run_test() {
  local test_file=$1
  local test_name=$2

  if [[ -n "$SPECIFIC_TEST" && "$test_name" != *"$SPECIFIC_TEST"* ]]; then
    return 0
  fi

  if [[ -f "$SCRIPT_DIR/tests/$test_file" ]]; then
    source "$SCRIPT_DIR/tests/$test_file"
  else
    echo -e "${RED}[ERROR]${NC} Test file not found: $test_file"
  fi
}

# Execute tests in order
run_test "01_reset_data.sh" "reset"
run_test "02_classic_quiz.sh" "classic"
run_test "03_affirmation_quiz.sh" "affirmation"
run_test "04_you_or_me.sh" "you_or_me"
run_test "05_verify_lp.sh" "verify_lp"

# Summary
echo "========================================"
print_summary
echo "========================================"
