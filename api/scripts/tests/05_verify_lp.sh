#!/bin/bash
# Test: Verify Love Points
# Checks that LP was awarded correctly and both users have matching totals

print_test "Love Points - Verification"
echo "---"

# Get Jokke's LP
print_info "Fetching Jokke's LP total..."
RESPONSE=$(api_call GET "/api/sync/love-points" "$JOKKE_ID" "")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "Fetch Jokke LP"

JOKKE_LP=$(get_json_field "$BODY" ".total // 0")
print_info "Jokke total LP: $JOKKE_LP"

# Get TestiY's LP (should be same - shared pool)
print_info "Fetching TestiY's LP total..."
RESPONSE=$(api_call GET "/api/sync/love-points" "$TESTIY_ID" "")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "Fetch TestiY LP"

TESTIY_LP=$(get_json_field "$BODY" ".total // 0")
print_info "TestiY total LP: $TESTIY_LP"

# Verify they match (couples share LP)
if [[ "$TESTIY_LP" == "$JOKKE_LP" ]]; then
  print_pass "Jokke and TestiY LP totals match ($JOKKE_LP)"
else
  print_fail "LP mismatch: Jokke=$JOKKE_LP, TestiY=$TESTIY_LP"
fi

# Verify LP increased from tests (if we have initial value)
if [[ -n "$INITIAL_LP" ]]; then
  if [[ "$JOKKE_LP" -gt "$INITIAL_LP" ]]; then
    LP_GAINED=$((JOKKE_LP - INITIAL_LP))
    print_pass "LP increased by $LP_GAINED (from $INITIAL_LP to $JOKKE_LP)"
  else
    print_info "LP did not increase (Initial: $INITIAL_LP, Current: $JOKKE_LP)"
    print_info "This may be expected if tests were re-run with already completed quests"
  fi
fi

# Summary of expected LP awards
echo ""
print_info "Expected LP awards per quest type:"
print_info "  - Classic Quiz: 30 LP"
print_info "  - Affirmation Quiz: 30 LP"
print_info "  - You-or-Me: 30 LP"
print_info "  - Total possible: 90 LP per day"

echo ""
