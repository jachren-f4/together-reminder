#!/bin/bash
# Test: Affirmation Quiz Flow
# Order: Jokke (Chrome) creates & rates FIRST, TestiY (Android) rates SECOND

print_test "Affirmation Quiz - Full Flow"
echo "---"

# Step 1: Jokke (Chrome) creates or gets affirmation quiz match
print_info "Jokke (Chrome) creates/gets affirmation quiz match..."
RESPONSE=$(api_call POST "/api/sync/quiz-match" "$JOKKE_ID" "{
  \"localDate\": \"$TODAY\",
  \"quizType\": \"affirmation\"
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "Jokke creates affirmation quiz match"
assert_json_field "$BODY" ".success" "true" "Response indicates success"

MATCH_ID=$(get_json_field "$BODY" ".match.id")
print_info "Match ID: $MATCH_ID"

# Verify match has statements
STATEMENT_COUNT=$(get_json_field "$BODY" ".quiz.questions | length")
print_info "Statements loaded: $STATEMENT_COUNT"

if [[ "$STATEMENT_COUNT" -lt 1 ]]; then
  print_fail "No statements returned in affirmation quiz"
else
  print_pass "Quiz has $STATEMENT_COUNT statements"
fi

# Step 2: Jokke (Chrome) submits his ratings (1-5 scale)
print_info "Jokke (Chrome) submits his ratings..."

# Jokke rates each statement (1-5)
NUM_STATEMENTS=$STATEMENT_COUNT
JOKKE_RATINGS="["
for i in $(seq 0 $((NUM_STATEMENTS - 1))); do
  if [[ $i -gt 0 ]]; then
    JOKKE_RATINGS="$JOKKE_RATINGS,"
  fi
  # Rate 5, 4, 3, 2, 1 repeating
  RATING=$(( 5 - (i % 5) ))
  JOKKE_RATINGS="$JOKKE_RATINGS$RATING"
done
JOKKE_RATINGS="$JOKKE_RATINGS]"

RESPONSE=$(api_call POST "/api/sync/quiz-match/submit" "$JOKKE_ID" "{
  \"matchId\": \"$MATCH_ID\",
  \"answers\": $JOKKE_RATINGS
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "Jokke submits ratings"
assert_json_field "$BODY" ".success" "true" "Submit successful"

BOTH_ANSWERED=$(get_json_field "$BODY" ".bothAnswered")
if [[ "$BOTH_ANSWERED" == "true" ]]; then
  print_info "Both users already answered (may be re-running test)"
else
  print_pass "Both answered is false (waiting for TestiY)"
fi

# Step 3: TestiY (Android) fetches the same match
print_info "TestiY (Android) fetches the affirmation match..."
RESPONSE=$(api_call POST "/api/sync/quiz-match" "$TESTIY_ID" "{
  \"localDate\": \"$TODAY\",
  \"quizType\": \"affirmation\"
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "TestiY fetches affirmation match"

TESTIY_MATCH_ID=$(get_json_field "$BODY" ".match.id")
assert_equal "$MATCH_ID" "$TESTIY_MATCH_ID" "TestiY gets same match as Jokke"

# Step 4: TestiY (Android) submits her ratings
print_info "TestiY (Android) submits ratings..."

# TestiY's ratings - similar to Jokke's but slightly different
TESTIY_RATINGS="["
for i in $(seq 0 $((NUM_STATEMENTS - 1))); do
  if [[ $i -gt 0 ]]; then
    TESTIY_RATINGS="$TESTIY_RATINGS,"
  fi
  # Rate slightly differently (will show some variation)
  if [[ $i -eq 2 ]]; then
    RATING=4  # Different from Jokke's 3
  else
    RATING=$(( 5 - (i % 5) ))  # Same as Jokke
  fi
  TESTIY_RATINGS="$TESTIY_RATINGS$RATING"
done
TESTIY_RATINGS="$TESTIY_RATINGS]"

RESPONSE=$(api_call POST "/api/sync/quiz-match/submit" "$TESTIY_ID" "{
  \"matchId\": \"$MATCH_ID\",
  \"answers\": $TESTIY_RATINGS
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "TestiY submits ratings"
assert_json_field "$BODY" ".success" "true" "Submit successful"
assert_json_field "$BODY" ".bothAnswered" "true" "Both answered should be true"
assert_json_field "$BODY" ".isCompleted" "true" "Quiz should be completed"
assert_json_exists "$BODY" ".lpEarned" "LP earned returned"

LP_EARNED=$(get_json_field "$BODY" ".lpEarned")
print_info "LP Earned: $LP_EARNED"

# Store LP earned for verification later
AFFIRMATION_LP_EARNED=$LP_EARNED

echo ""
