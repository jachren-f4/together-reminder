#!/bin/bash
# Test Helper Library for Daily Quest Testing
# Contains colors, assertions, and API wrapper functions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Print functions
print_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
print_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
print_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
print_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
print_debug() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${CYAN}[DEBUG]${NC} $1"
  fi
}

# API call wrapper
# Usage: api_call METHOD ENDPOINT USER_ID [DATA]
# Returns: HTTP_CODE|BODY
api_call() {
  local METHOD=$1
  local ENDPOINT=$2
  local USER_ID=$3
  local DATA=$4

  local CURL_ARGS=(-s -w "\n%{http_code}")
  CURL_ARGS+=(-X "$METHOD")
  CURL_ARGS+=(-H "Content-Type: application/json")
  CURL_ARGS+=(-H "X-Dev-User-Id: $USER_ID")

  if [[ -n "$DATA" ]]; then
    CURL_ARGS+=(-d "$DATA")
  fi

  print_debug "curl ${CURL_ARGS[*]} $API_URL$ENDPOINT"
  if [[ -n "$DATA" && "$VERBOSE" == "true" ]]; then
    print_debug "Request body: $DATA"
  fi

  local RESPONSE=$(curl "${CURL_ARGS[@]}" "$API_URL$ENDPOINT")
  local HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  local BODY=$(echo "$RESPONSE" | sed '$d')

  print_debug "Response HTTP $HTTP_CODE"
  if [[ "$VERBOSE" == "true" ]]; then
    print_debug "Response body: $BODY"
  fi

  echo "$HTTP_CODE|$BODY"
}

# Assertions

# Assert HTTP status code
assert_status() {
  local EXPECTED=$1
  local ACTUAL=$2
  local MESSAGE=$3

  if [[ "$ACTUAL" == "$EXPECTED" ]]; then
    print_pass "$MESSAGE (HTTP $ACTUAL)"
    return 0
  else
    print_fail "$MESSAGE (Expected HTTP $EXPECTED, got $ACTUAL)"
    return 1
  fi
}

# Assert JSON field equals value
assert_json_field() {
  local JSON=$1
  local FIELD=$2
  local EXPECTED=$3
  local MESSAGE=$4

  local ACTUAL=$(echo "$JSON" | jq -r "$FIELD" 2>/dev/null)

  if [[ "$ACTUAL" == "$EXPECTED" ]]; then
    print_pass "$MESSAGE ($FIELD = $EXPECTED)"
    return 0
  else
    print_fail "$MESSAGE (Expected $FIELD = $EXPECTED, got $ACTUAL)"
    return 1
  fi
}

# Assert JSON field exists and is not null
assert_json_exists() {
  local JSON=$1
  local FIELD=$2
  local MESSAGE=$3

  local VALUE=$(echo "$JSON" | jq -r "$FIELD" 2>/dev/null)

  if [[ "$VALUE" != "null" && -n "$VALUE" ]]; then
    print_pass "$MESSAGE ($FIELD exists)"
    return 0
  else
    print_fail "$MESSAGE ($FIELD is null or missing)"
    return 1
  fi
}

# Assert JSON field is greater than value
assert_json_gt() {
  local JSON=$1
  local FIELD=$2
  local EXPECTED=$3
  local MESSAGE=$4

  local ACTUAL=$(echo "$JSON" | jq -r "$FIELD" 2>/dev/null)

  if [[ "$ACTUAL" =~ ^[0-9]+$ ]] && [[ "$ACTUAL" -gt "$EXPECTED" ]]; then
    print_pass "$MESSAGE ($FIELD = $ACTUAL > $EXPECTED)"
    return 0
  else
    print_fail "$MESSAGE (Expected $FIELD > $EXPECTED, got $ACTUAL)"
    return 1
  fi
}

# Assert two values are equal
assert_equal() {
  local EXPECTED=$1
  local ACTUAL=$2
  local MESSAGE=$3

  if [[ "$EXPECTED" == "$ACTUAL" ]]; then
    print_pass "$MESSAGE ($ACTUAL)"
    return 0
  else
    print_fail "$MESSAGE (Expected $EXPECTED, got $ACTUAL)"
    return 1
  fi
}

# Print summary and exit with appropriate code
print_summary() {
  echo ""
  echo -e "Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
  fi
}

# Extract JSON field value
get_json_field() {
  local JSON=$1
  local FIELD=$2
  echo "$JSON" | jq -r "$FIELD" 2>/dev/null
}

# Parse response into HTTP_CODE and BODY
parse_response() {
  local RESPONSE=$1
  HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
  BODY=$(echo "$RESPONSE" | cut -d'|' -f2-)
}
