#!/bin/bash

# Test script for Quiz API endpoints
# Tests Classic and Affirmation quiz flows
#
# Prerequisites:
# - API server running: cd api && npm run dev
# - AUTH_DEV_BYPASS_ENABLED=true in .env.local

set -e

# Configuration
API_BASE="${API_BASE:-http://localhost:3000}"
ALICE_ID="c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"  # Android dev user
BOB_ID="d71425a3-a92f-404e-bfbe-a54c4cb58b6a"    # Web dev user
TODAY=$(date +%Y-%m-%d)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Quiz API Test Suite"
echo "=========================================="
echo "API Base: $API_BASE"
echo "Date: $TODAY"
echo "Alice ID: $ALICE_ID"
echo "Bob ID: $BOB_ID"
echo ""

# Helper function to make API requests
api_request() {
  local method=$1
  local endpoint=$2
  local user_id=$3
  local body=$4

  if [ -n "$body" ]; then
    curl -s -X "$method" "${API_BASE}${endpoint}" \
      -H "Content-Type: application/json" \
      -H "X-Dev-User-Id: $user_id" \
      -d "$body"
  else
    curl -s -X "$method" "${API_BASE}${endpoint}" \
      -H "Content-Type: application/json" \
      -H "X-Dev-User-Id: $user_id"
  fi
}

# Test 1: Health check
echo -e "${YELLOW}Test 1: Health check${NC}"
HEALTH=$(curl -s "${API_BASE}/api/health" 2>/dev/null || echo '{"error":"no health endpoint"}')
echo "Response: $HEALTH"
echo ""

# Test 2: Create Classic Quiz (Alice)
echo -e "${YELLOW}Test 2: Create Classic Quiz (Alice)${NC}"
CLASSIC_BODY=$(cat <<EOF
{
  "date": "$TODAY",
  "formatType": "classic",
  "questions": [
    {"id": "q1", "text": "What is Alice's favorite color?", "choices": ["Red", "Blue", "Green", "Yellow"], "correctIndex": 1},
    {"id": "q2", "text": "What is Alice's dream vacation?", "choices": ["Beach", "Mountains", "City", "Forest"], "correctIndex": 0},
    {"id": "q3", "text": "What is Alice's favorite food?", "choices": ["Pizza", "Sushi", "Tacos", "Pasta"], "correctIndex": 2},
    {"id": "q4", "text": "What is Alice's favorite movie genre?", "choices": ["Comedy", "Drama", "Action", "Horror"], "correctIndex": 0},
    {"id": "q5", "text": "What is Alice's favorite season?", "choices": ["Spring", "Summer", "Fall", "Winter"], "correctIndex": 3}
  ],
  "quizName": "Test Classic Quiz",
  "dailyQuestId": "test-quest-001"
}
EOF
)

CREATE_RESPONSE=$(api_request POST "/api/sync/quiz" "$ALICE_ID" "$CLASSIC_BODY")
echo "Response: $CREATE_RESPONSE" | head -c 500
echo ""

# Extract session ID
SESSION_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Session ID: $SESSION_ID"
echo ""

if [ -z "$SESSION_ID" ]; then
  echo -e "${RED}Failed to create session${NC}"
  exit 1
fi

# Test 3: Bob gets the same session
echo -e "${YELLOW}Test 3: Bob gets the same session${NC}"
BOB_GET=$(api_request GET "/api/sync/quiz?date=$TODAY&formatType=classic" "$BOB_ID")
echo "Response: $BOB_GET" | head -c 500
echo ""

# Test 4: Alice submits answers
echo -e "${YELLOW}Test 4: Alice submits answers (subject)${NC}"
ALICE_ANSWERS=$(cat <<EOF
{
  "sessionId": "$SESSION_ID",
  "answers": [1, 0, 2, 0, 3]
}
EOF
)

ALICE_SUBMIT=$(api_request POST "/api/sync/quiz/submit" "$ALICE_ID" "$ALICE_ANSWERS")
echo "Response: $ALICE_SUBMIT" | head -c 500
echo ""

# Test 5: Poll session (should show Alice answered)
echo -e "${YELLOW}Test 5: Poll session state${NC}"
POLL_RESPONSE=$(api_request GET "/api/sync/quiz/$SESSION_ID" "$BOB_ID")
echo "Response: $POLL_RESPONSE" | head -c 500
echo ""

# Test 6: Bob submits answers (predictor)
echo -e "${YELLOW}Test 6: Bob submits answers (predictor)${NC}"
BOB_ANSWERS=$(cat <<EOF
{
  "sessionId": "$SESSION_ID",
  "answers": [1, 0, 2, 1, 3]
}
EOF
)

BOB_SUBMIT=$(api_request POST "/api/sync/quiz/submit" "$BOB_ID" "$BOB_ANSWERS")
echo "Response: $BOB_SUBMIT" | head -c 500
echo ""

# Check for completion
BOTH_ANSWERED=$(echo "$BOB_SUBMIT" | grep -o '"bothAnswered":true' || echo "")
MATCH_PERCENTAGE=$(echo "$BOB_SUBMIT" | grep -o '"matchPercentage":[0-9]*' | cut -d':' -f2)
LP_EARNED=$(echo "$BOB_SUBMIT" | grep -o '"lpEarned":[0-9]*' | cut -d':' -f2)

if [ -n "$BOTH_ANSWERED" ]; then
  echo -e "${GREEN}✅ Quiz completed!${NC}"
  echo "Match Percentage: $MATCH_PERCENTAGE%"
  echo "LP Earned: $LP_EARNED"
else
  echo -e "${RED}❌ Quiz not completed${NC}"
fi

echo ""
echo "=========================================="
echo "Affirmation Quiz Tests"
echo "=========================================="
echo ""

# Test 7: Create Affirmation Quiz (Alice)
echo -e "${YELLOW}Test 7: Create Affirmation Quiz (Alice)${NC}"
AFFIRMATION_BODY=$(cat <<EOF
{
  "date": "$TODAY",
  "formatType": "affirmation",
  "questions": [
    {"id": "a1", "text": "I feel valued in our relationship", "scale": 5},
    {"id": "a2", "text": "We communicate openly", "scale": 5},
    {"id": "a3", "text": "We support each other's goals", "scale": 5}
  ],
  "quizName": "Trust & Communication",
  "category": "trust",
  "dailyQuestId": "test-quest-002"
}
EOF
)

AFF_RESPONSE=$(api_request POST "/api/sync/quiz" "$ALICE_ID" "$AFFIRMATION_BODY")
echo "Response: $AFF_RESPONSE" | head -c 500
echo ""

AFF_SESSION_ID=$(echo "$AFF_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Affirmation Session ID: $AFF_SESSION_ID"
echo ""

if [ -z "$AFF_SESSION_ID" ]; then
  echo -e "${RED}Failed to create affirmation session${NC}"
  exit 1
fi

# Test 8: Both submit affirmation answers
echo -e "${YELLOW}Test 8: Alice submits affirmation answers${NC}"
ALICE_AFF=$(cat <<EOF
{
  "sessionId": "$AFF_SESSION_ID",
  "answers": [4, 5, 4]
}
EOF
)
api_request POST "/api/sync/quiz/submit" "$ALICE_ID" "$ALICE_AFF"
echo ""

echo -e "${YELLOW}Test 9: Bob submits affirmation answers${NC}"
BOB_AFF=$(cat <<EOF
{
  "sessionId": "$AFF_SESSION_ID",
  "answers": [5, 4, 5]
}
EOF
)
AFF_COMPLETE=$(api_request POST "/api/sync/quiz/submit" "$BOB_ID" "$BOB_AFF")
echo "Response: $AFF_COMPLETE" | head -c 500
echo ""

# Final verification
echo ""
echo "=========================================="
echo "Final Verification"
echo "=========================================="
echo ""

# Get final state of classic quiz
echo -e "${YELLOW}Classic Quiz Final State:${NC}"
FINAL_CLASSIC=$(api_request GET "/api/sync/quiz/$SESSION_ID" "$ALICE_ID")
echo "$FINAL_CLASSIC" | python3 -m json.tool 2>/dev/null || echo "$FINAL_CLASSIC"

echo ""
echo -e "${YELLOW}Affirmation Quiz Final State:${NC}"
FINAL_AFF=$(api_request GET "/api/sync/quiz/$AFF_SESSION_ID" "$ALICE_ID")
echo "$FINAL_AFF" | python3 -m json.tool 2>/dev/null || echo "$FINAL_AFF"

echo ""
echo -e "${GREEN}=========================================="
echo "Test Suite Complete!"
echo "==========================================${NC}"
