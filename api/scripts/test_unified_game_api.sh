#!/bin/bash
#
# Test: Unified Game API (Option B)
# Tests the new simplified 2-endpoint architecture
#
# Prerequisites:
# - API server running on localhost:3000
# - Test couple exists in database
#

set -e

API_BASE="http://localhost:3000"
USER1_ID="c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"  # TestiY (Android)
USER2_ID="d71425a3-a92f-404e-bfbe-a54c4cb58b6a"  # Jokke (Chrome)
TODAY=$(date +%Y-%m-%d)

echo "=========================================="
echo "Unified Game API Test Suite"
echo "=========================================="
echo "Date: $TODAY"
echo "User 1 (TestiY): $USER1_ID"
echo "User 2 (Jokke):  $USER2_ID"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; exit 1; }
info() { echo -e "${YELLOW}→${NC} $1"; }
section() { echo -e "\n${CYAN}$1${NC}"; echo "$(printf '=%.0s' {1..50})"; }

#------------------------------------------
# Test 0: Reset games for clean state
#------------------------------------------
section "Test 0: Reset games"
info "Resetting quiz_matches for couple..."

RESET_RESULT=$(curl -s -X POST "$API_BASE/api/dev/reset-games" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER1_ID" \
  -d '{"userId": "'$USER1_ID'"}')

if echo "$RESET_RESULT" | grep -q '"success":true'; then
  pass "Games reset successfully"
else
  echo "Response: $RESET_RESULT"
  fail "Failed to reset games"
fi

#------------------------------------------
# Test 1: Game status returns empty
#------------------------------------------
section "Test 1: GET /api/sync/game/status (empty)"
info "Checking game status for User 1..."

STATUS1=$(curl -s "$API_BASE/api/sync/game/status" \
  -H "X-Dev-User-Id: $USER1_ID")

if echo "$STATUS1" | grep -q '"success":true'; then
  GAME_COUNT=$(echo "$STATUS1" | jq '.games | length')
  if [ "$GAME_COUNT" = "0" ]; then
    pass "No games returned (expected after reset)"
  else
    info "Found $GAME_COUNT existing games"
  fi
else
  echo "Response: $STATUS1"
  fail "Failed to get game status"
fi

#------------------------------------------
# Test 2: Start a new classic quiz
#------------------------------------------
section "Test 2: POST /api/sync/game/classic/play (start)"
info "User 1 starting classic quiz..."

START_RESULT=$(curl -s -X POST "$API_BASE/api/sync/game/classic/play" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER1_ID" \
  -d '{"localDate": "'$TODAY'"}')

if echo "$START_RESULT" | grep -q '"success":true'; then
  MATCH_ID=$(echo "$START_RESULT" | jq -r '.match.id')
  QUIZ_ID=$(echo "$START_RESULT" | jq -r '.match.quizId')
  IS_NEW=$(echo "$START_RESULT" | jq -r '.isNew')
  HAS_QUIZ=$(echo "$START_RESULT" | jq -r '.quiz.questions | length')
  pass "Classic quiz started: $MATCH_ID"
  echo "  Quiz ID: $QUIZ_ID"
  echo "  Is new: $IS_NEW"
  echo "  Questions: $HAS_QUIZ"
else
  echo "Response: $START_RESULT"
  fail "Failed to start classic quiz"
fi

#------------------------------------------
# Test 3: Game status shows new quiz
#------------------------------------------
section "Test 3: GET /api/sync/game/status (with game)"
info "Checking game status for User 1..."

STATUS2=$(curl -s "$API_BASE/api/sync/game/status" \
  -H "X-Dev-User-Id: $USER1_ID")

GAME_COUNT=$(echo "$STATUS2" | jq '.games | length')
if [ "$GAME_COUNT" -gt 0 ]; then
  GAME_TYPE=$(echo "$STATUS2" | jq -r '.games[0].type')
  GAME_STATUS=$(echo "$STATUS2" | jq -r '.games[0].status')
  pass "Game appears in status"
  echo "  Type: $GAME_TYPE"
  echo "  Status: $GAME_STATUS"
else
  fail "Game not showing in status"
fi

#------------------------------------------
# Test 4: User 1 submits answers
#------------------------------------------
section "Test 4: POST /api/sync/game/classic/play (submit)"
info "User 1 submitting answers..."

SUBMIT1_RESULT=$(curl -s -X POST "$API_BASE/api/sync/game/classic/play" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER1_ID" \
  -d '{
    "matchId": "'$MATCH_ID'",
    "answers": [0, 1, 2, 1, 0]
  }')

if echo "$SUBMIT1_RESULT" | grep -q '"success":true'; then
  USER_ANSWERED=$(echo "$SUBMIT1_RESULT" | jq -r '.state.userAnswered')
  PARTNER_ANSWERED=$(echo "$SUBMIT1_RESULT" | jq -r '.state.partnerAnswered')
  IS_COMPLETED=$(echo "$SUBMIT1_RESULT" | jq -r '.state.isCompleted')
  pass "User 1 answers submitted"
  echo "  User answered: $USER_ANSWERED"
  echo "  Partner answered: $PARTNER_ANSWERED"
  echo "  Is completed: $IS_COMPLETED"
else
  echo "Response: $SUBMIT1_RESULT"
  fail "Failed to submit User 1 answers"
fi

#------------------------------------------
# Test 5: User 2 sees partner completed via status
#------------------------------------------
section "Test 5: GET /api/sync/game/status (User 2)"
info "User 2 checking game status..."

STATUS3=$(curl -s "$API_BASE/api/sync/game/status" \
  -H "X-Dev-User-Id: $USER2_ID")

USER2_ANSWERED=$(echo "$STATUS3" | jq -r '.games[0].userAnswered')
PARTNER_ANSWERED=$(echo "$STATUS3" | jq -r '.games[0].partnerAnswered')

echo "  User 2 answered: $USER2_ANSWERED"
echo "  Partner (User 1) answered: $PARTNER_ANSWERED"

if [ "$USER2_ANSWERED" = "false" ] && [ "$PARTNER_ANSWERED" = "true" ]; then
  pass "User 2 sees partner has completed (polling works!)"
else
  fail "Expected userAnswered=false, partnerAnswered=true"
fi

#------------------------------------------
# Test 6: User 2 submits (completes the game)
#------------------------------------------
section "Test 6: POST /api/sync/game/classic/play (User 2 submit)"
info "User 2 submitting answers..."

SUBMIT2_RESULT=$(curl -s -X POST "$API_BASE/api/sync/game/classic/play" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER2_ID" \
  -d '{
    "matchId": "'$MATCH_ID'",
    "answers": [0, 1, 2, 0, 1]
  }')

if echo "$SUBMIT2_RESULT" | grep -q '"success":true'; then
  IS_COMPLETED=$(echo "$SUBMIT2_RESULT" | jq -r '.state.isCompleted')
  LP_EARNED=$(echo "$SUBMIT2_RESULT" | jq -r '.result.lpEarned')
  MATCH_PCT=$(echo "$SUBMIT2_RESULT" | jq -r '.result.matchPercentage')
  pass "User 2 answers submitted"
  echo "  Is completed: $IS_COMPLETED"
  echo "  LP earned: $LP_EARNED"
  echo "  Match %: $MATCH_PCT"
else
  echo "Response: $SUBMIT2_RESULT"
  fail "Failed to submit User 2 answers"
fi

#------------------------------------------
# Test 7: Final status shows completion
#------------------------------------------
section "Test 7: GET /api/sync/game/status (final)"
info "Checking final game status..."

STATUS4=$(curl -s "$API_BASE/api/sync/game/status" \
  -H "X-Dev-User-Id: $USER1_ID")

FINAL_STATUS=$(echo "$STATUS4" | jq -r '.games[0].status')
FINAL_LP=$(echo "$STATUS4" | jq -r '.games[0].lpEarned')
TOTAL_LP=$(echo "$STATUS4" | jq -r '.totalLp')

echo "  Game status: $FINAL_STATUS"
echo "  LP earned: $FINAL_LP"
echo "  Total LP: $TOTAL_LP"

if [ "$FINAL_STATUS" = "completed" ]; then
  pass "Game shows as completed"
else
  fail "Game not showing as completed"
fi

if [ "$FINAL_LP" = "30" ]; then
  pass "LP awarded correctly (30)"
else
  fail "LP not awarded correctly (expected 30, got $FINAL_LP)"
fi

#------------------------------------------
# Test 8: Start and submit in one call
#------------------------------------------
section "Test 8: POST /api/sync/game/affirmation/play (start+submit)"
info "User 1 starting AND submitting affirmation quiz in one call..."

COMBO_RESULT=$(curl -s -X POST "$API_BASE/api/sync/game/affirmation/play" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER1_ID" \
  -d '{
    "localDate": "'$TODAY'",
    "answers": [2, 3, 1, 4, 2]
  }')

if echo "$COMBO_RESULT" | grep -q '"success":true'; then
  AFF_MATCH_ID=$(echo "$COMBO_RESULT" | jq -r '.match.id')
  USER_ANSWERED=$(echo "$COMBO_RESULT" | jq -r '.state.userAnswered')
  IS_NEW=$(echo "$COMBO_RESULT" | jq -r '.isNew')
  pass "Affirmation quiz started and submitted in one call"
  echo "  Match ID: $AFF_MATCH_ID"
  echo "  Is new: $IS_NEW"
  echo "  User answered: $USER_ANSWERED"
else
  echo "Response: $COMBO_RESULT"
  fail "Failed to start+submit affirmation quiz"
fi

#------------------------------------------
# Test 9: Filter by game type
#------------------------------------------
section "Test 9: GET /api/sync/game/status?type=classic"
info "Checking status filtered by type..."

FILTERED=$(curl -s "$API_BASE/api/sync/game/status?type=classic" \
  -H "X-Dev-User-Id: $USER1_ID")

FILTERED_COUNT=$(echo "$FILTERED" | jq '.games | length')
FILTERED_TYPE=$(echo "$FILTERED" | jq -r '.games[0].type')

if [ "$FILTERED_TYPE" = "classic" ]; then
  pass "Type filter works"
  echo "  Filtered games count: $FILTERED_COUNT"
else
  fail "Type filter not working"
fi

#------------------------------------------
# Test 10: Invalid game type
#------------------------------------------
section "Test 10: POST /api/sync/game/invalid/play (error)"
info "Testing invalid game type..."

INVALID_RESULT=$(curl -s -X POST "$API_BASE/api/sync/game/invalid/play" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER1_ID" \
  -d '{"localDate": "'$TODAY'"}')

if echo "$INVALID_RESULT" | grep -q '"error"'; then
  pass "Invalid game type rejected"
else
  fail "Invalid game type should be rejected"
fi

#------------------------------------------
# Summary
#------------------------------------------
echo ""
echo "=========================================="
echo -e "${GREEN}All Unified Game API Tests Passed!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Unified play endpoint works for all game types"
echo "  - Start + submit in one call works"
echo "  - Status endpoint returns all games"
echo "  - Type filtering works"
echo "  - LP awards work correctly"
echo "  - Partner completion polling works"
echo ""
echo "New Architecture:"
echo "  POST /api/sync/game/{type}/play  - Smart start/submit"
echo "  GET  /api/sync/game/status       - Unified polling"
echo ""
