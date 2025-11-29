#!/bin/bash
# Test: Classic Quiz Flow
# Order: Jokke (Chrome) creates & answers FIRST, TestiY (Android) predicts SECOND

print_test "Classic Quiz - Full Flow"
echo "---"

# Generate unique quest ID for this test run
CLASSIC_QUEST_ID="quiz:classic:$TODAY"

# Step 1: Jokke (Chrome) creates or gets quiz match
print_info "Jokke (Chrome) creates/gets classic quiz match..."
RESPONSE=$(api_call POST "/api/sync/quiz-match" "$JOKKE_ID" "{
  \"localDate\": \"$TODAY\",
  \"quizType\": \"classic\"
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "Jokke creates classic quiz match"
assert_json_field "$BODY" ".success" "true" "Response indicates success"

MATCH_ID=$(get_json_field "$BODY" ".match.id")
print_info "Match ID: $MATCH_ID"

# Verify match has questions
QUESTION_COUNT=$(get_json_field "$BODY" ".quiz.questions | length")
print_info "Questions loaded: $QUESTION_COUNT"

if [[ "$QUESTION_COUNT" -lt 1 ]]; then
  print_fail "No questions returned in quiz match"
else
  print_pass "Quiz has $QUESTION_COUNT questions"
fi

# Step 2: Jokke (Chrome) submits his answers (he answers about himself)
print_info "Jokke (Chrome) submits his answers..."

# Get number of questions and prepare answers
NUM_QUESTIONS=$(get_json_field "$BODY" ".quiz.questions | length")
JOKKE_ANSWERS="["
for i in $(seq 0 $((NUM_QUESTIONS - 1))); do
  if [[ $i -gt 0 ]]; then
    JOKKE_ANSWERS="$JOKKE_ANSWERS,"
  fi
  # Answer with index (0, 1, 2, 0, 1, ...)
  ANSWER_IDX=$((i % 4))
  JOKKE_ANSWERS="$JOKKE_ANSWERS$ANSWER_IDX"
done
JOKKE_ANSWERS="$JOKKE_ANSWERS]"

RESPONSE=$(api_call POST "/api/sync/quiz-match/submit" "$JOKKE_ID" "{
  \"matchId\": \"$MATCH_ID\",
  \"answers\": $JOKKE_ANSWERS
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "Jokke submits answers"
assert_json_field "$BODY" ".success" "true" "Submit successful"

# Check if both have answered - should be false since TestiY hasn't answered yet
BOTH_ANSWERED=$(get_json_field "$BODY" ".bothAnswered")
if [[ "$BOTH_ANSWERED" == "true" ]]; then
  print_info "Both users already answered (may be re-running test)"
else
  print_pass "Both answered is false (waiting for TestiY)"
fi

# Step 3: TestiY (Android) fetches the same match
print_info "TestiY (Android) fetches the quiz match..."
RESPONSE=$(api_call POST "/api/sync/quiz-match" "$TESTIY_ID" "{
  \"localDate\": \"$TODAY\",
  \"quizType\": \"classic\"
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "TestiY fetches quiz match"

TESTIY_MATCH_ID=$(get_json_field "$BODY" ".match.id")
assert_equal "$MATCH_ID" "$TESTIY_MATCH_ID" "TestiY gets same match as Jokke"

# Step 4: TestiY (Android) submits predictions (guessing Jokke's answers)
print_info "TestiY (Android) submits predictions..."

# TestiY's predictions - slightly different from Jokke's actual answers
TESTIY_ANSWERS="["
for i in $(seq 0 $((NUM_QUESTIONS - 1))); do
  if [[ $i -gt 0 ]]; then
    TESTIY_ANSWERS="$TESTIY_ANSWERS,"
  fi
  # Predict slightly differently (will get ~80% match)
  if [[ $i -eq 3 ]]; then
    ANSWER_IDX=1  # Wrong prediction
  else
    ANSWER_IDX=$((i % 4))  # Same as Jokke
  fi
  TESTIY_ANSWERS="$TESTIY_ANSWERS$ANSWER_IDX"
done
TESTIY_ANSWERS="$TESTIY_ANSWERS]"

RESPONSE=$(api_call POST "/api/sync/quiz-match/submit" "$TESTIY_ID" "{
  \"matchId\": \"$MATCH_ID\",
  \"answers\": $TESTIY_ANSWERS
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "TestiY submits predictions"
assert_json_field "$BODY" ".success" "true" "Submit successful"
assert_json_field "$BODY" ".bothAnswered" "true" "Both answered should be true"
assert_json_field "$BODY" ".isCompleted" "true" "Quiz should be completed"
assert_json_exists "$BODY" ".matchPercentage" "Match percentage calculated"
assert_json_exists "$BODY" ".lpEarned" "LP earned returned"

MATCH_PCT=$(get_json_field "$BODY" ".matchPercentage")
LP_EARNED=$(get_json_field "$BODY" ".lpEarned")
print_info "Match: $MATCH_PCT%, LP Earned: $LP_EARNED"

# Store LP earned for verification later
CLASSIC_LP_EARNED=$LP_EARNED

echo ""
