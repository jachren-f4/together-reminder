#!/bin/bash
# Test: You-or-Me Turn-Based Flow
# Order: Determined dynamically by API (first_player_id || user2_id)

print_test "You-or-Me - Turn-Based Flow"
echo "---"

# Step 1: Jokke (Chrome) creates You-or-Me match
print_info "Jokke (Chrome) creates You-or-Me match..."
RESPONSE=$(api_call POST "/api/sync/you-or-me-match" "$JOKKE_ID" "{
  \"localDate\": \"$TODAY\"
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "Jokke creates You-or-Me match"
assert_json_field "$BODY" ".success" "true" "Match created successfully"

MATCH_ID=$(get_json_field "$BODY" ".match.id")
TOTAL_QUESTIONS=$(get_json_field "$BODY" ".quiz.totalQuestions // .quiz.questions | length")
JOKKE_IS_MY_TURN=$(get_json_field "$BODY" ".gameState.isMyTurn")

# Default to 10 if not specified
if [[ "$TOTAL_QUESTIONS" == "null" || -z "$TOTAL_QUESTIONS" ]]; then
  TOTAL_QUESTIONS=10
fi

print_info "Match ID: $MATCH_ID, Questions: $TOTAL_QUESTIONS"
print_info "Jokke goes first: $JOKKE_IS_MY_TURN"

# Determine who plays first based on API response
if [[ "$JOKKE_IS_MY_TURN" == "true" ]]; then
  FIRST_PLAYER_ID="$JOKKE_ID"
  FIRST_PLAYER_NAME="Jokke"
  SECOND_PLAYER_ID="$TESTIY_ID"
  SECOND_PLAYER_NAME="TestiY"
else
  FIRST_PLAYER_ID="$TESTIY_ID"
  FIRST_PLAYER_NAME="TestiY"
  SECOND_PLAYER_ID="$JOKKE_ID"
  SECOND_PLAYER_NAME="Jokke"
fi

print_info "Turn order: $FIRST_PLAYER_NAME goes FIRST, $SECOND_PLAYER_NAME goes SECOND"

# Step 2: First player answers all questions
print_info "$FIRST_PLAYER_NAME answers all $TOTAL_QUESTIONS questions..."
FIRST_FAILED=0

for i in $(seq 0 $((TOTAL_QUESTIONS - 1))); do
  # Alternate between "you" and "me"
  if [[ $((i % 2)) -eq 0 ]]; then
    ANSWER="you"
  else
    ANSWER="me"
  fi

  RESPONSE=$(api_call POST "/api/sync/you-or-me-match/submit" "$FIRST_PLAYER_ID" "{
    \"matchId\": \"$MATCH_ID\",
    \"questionIndex\": $i,
    \"answer\": \"$ANSWER\"
  }")

  parse_response "$RESPONSE"

  if [[ "$HTTP_CODE" != "200" ]]; then
    print_debug "$FIRST_PLAYER_NAME answer Q$i failed (HTTP $HTTP_CODE): $BODY"
    ((FIRST_FAILED++))
  fi
done

if [[ $FIRST_FAILED -eq 0 ]]; then
  print_pass "$FIRST_PLAYER_NAME completed all $TOTAL_QUESTIONS questions"
else
  print_fail "$FIRST_PLAYER_NAME failed $FIRST_FAILED questions"
fi

# Step 3: Second player fetches the match
print_info "$SECOND_PLAYER_NAME fetches the You-or-Me match..."
RESPONSE=$(api_call POST "/api/sync/you-or-me-match" "$SECOND_PLAYER_ID" "{
  \"localDate\": \"$TODAY\"
}")

parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "$SECOND_PLAYER_NAME fetches You-or-Me match"

SECOND_MATCH_ID=$(get_json_field "$BODY" ".match.id")
assert_equal "$MATCH_ID" "$SECOND_MATCH_ID" "$SECOND_PLAYER_NAME gets same match"

# Step 4: Second player answers all questions
print_info "$SECOND_PLAYER_NAME answers all $TOTAL_QUESTIONS questions..."
SECOND_FAILED=0

for i in $(seq 0 $((TOTAL_QUESTIONS - 1))); do
  # Second player answers opposite (will create disagreement on some)
  if [[ $((i % 2)) -eq 0 ]]; then
    ANSWER="me"  # Opposite of first player's "you"
  else
    ANSWER="you"  # Opposite of first player's "me"
  fi

  RESPONSE=$(api_call POST "/api/sync/you-or-me-match/submit" "$SECOND_PLAYER_ID" "{
    \"matchId\": \"$MATCH_ID\",
    \"questionIndex\": $i,
    \"answer\": \"$ANSWER\"
  }")

  parse_response "$RESPONSE"

  if [[ "$HTTP_CODE" != "200" ]]; then
    print_debug "$SECOND_PLAYER_NAME answer Q$i failed (HTTP $HTTP_CODE): $BODY"
    ((SECOND_FAILED++))
  fi
done

if [[ $SECOND_FAILED -eq 0 ]]; then
  print_pass "$SECOND_PLAYER_NAME completed all $TOTAL_QUESTIONS questions"
else
  print_fail "$SECOND_PLAYER_NAME failed $SECOND_FAILED questions"
fi

# Check final response for completion
assert_status 200 "$HTTP_CODE" "$SECOND_PLAYER_NAME final answer succeeded"
assert_json_field "$BODY" ".isCompleted" "true" "Match should be completed"
assert_json_exists "$BODY" ".lpEarned" "LP awarded on completion"

PLAYER1_SCORE=$(get_json_field "$BODY" ".match.player1Score // .player1Score")
PLAYER2_SCORE=$(get_json_field "$BODY" ".match.player2Score // .player2Score")
LP_EARNED=$(get_json_field "$BODY" ".lpEarned")

print_info "Final scores: Player1=$PLAYER1_SCORE, Player2=$PLAYER2_SCORE"
print_info "LP Earned: $LP_EARNED"

# Store LP earned for verification later
YOM_LP_EARNED=$LP_EARNED

echo ""
