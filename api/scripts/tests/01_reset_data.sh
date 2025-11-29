#!/bin/bash
# Test: Reset Data
# Clears all test data from Supabase before running tests

print_test "Reset Test Data"
echo "---"

# Record initial LP before reset (for comparison)
print_info "Recording initial LP totals..."
RESPONSE=$(api_call GET "/api/sync/love-points" "$JOKKE_ID" "")
parse_response "$RESPONSE"
INITIAL_LP=$(get_json_field "$BODY" ".total // 0")
print_info "Initial LP total: $INITIAL_LP"

# Reset all games for the couple via the dev reset endpoint
print_info "Calling reset endpoint..."
RESPONSE=$(api_call POST "/api/dev/reset-games" "$JOKKE_ID" "{
  \"coupleId\": \"$COUPLE_ID\"
}")

parse_response "$RESPONSE"

if [[ "$HTTP_CODE" == "200" ]]; then
  print_pass "Reset endpoint succeeded (HTTP $HTTP_CODE)"

  # Show what was deleted
  QUIZ_COUNT=$(get_json_field "$BODY" ".deleted.quizMatches // 0")
  YOM_COUNT=$(get_json_field "$BODY" ".deleted.youOrMeSessions // 0")

  print_info "Deleted: $QUIZ_COUNT quiz matches, $YOM_COUNT you-or-me sessions"
else
  # If reset endpoint doesn't exist, that's okay - tests will still work
  print_info "Reset endpoint returned HTTP $HTTP_CODE (may not exist yet)"
  print_info "Continuing with tests - new sessions will be created"
fi

echo ""
