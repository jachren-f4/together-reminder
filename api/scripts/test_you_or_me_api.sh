#!/bin/bash

# Test script for You or Me API endpoints
# Tests session creation, incremental answer submission, and completion
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
echo "You or Me API Test Suite"
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

# Test 1: Create You or Me session (Alice)
echo -e "${YELLOW}Test 1: Create You or Me session (Alice)${NC}"
CREATE_BODY=$(cat <<EOF
{
  "date": "$TODAY",
  "questions": [
    {"id": "yom_001", "prompt": "Who's more likely to", "content": "plan a surprise date", "category": "actions"},
    {"id": "yom_002", "prompt": "Who's more", "content": "spontaneous", "category": "personality"},
    {"id": "yom_003", "prompt": "Who would", "content": "win at trivia", "category": "scenarios"},
    {"id": "yom_004", "prompt": "Who's more likely to", "content": "cook dinner", "category": "actions"},
    {"id": "yom_005", "prompt": "Who's more", "content": "patient", "category": "personality"},
    {"id": "yom_006", "prompt": "Who's more likely to", "content": "remember anniversaries", "category": "actions"},
    {"id": "yom_007", "prompt": "Who's more", "content": "adventurous", "category": "personality"},
    {"id": "yom_008", "prompt": "Who would", "content": "plan a road trip", "category": "scenarios"},
    {"id": "yom_009", "prompt": "Who's more likely to", "content": "apologize first", "category": "actions"},
    {"id": "yom_010", "prompt": "Who's more", "content": "romantic", "category": "personality"}
  ],
  "questId": "test-yom-quest-001"
}
EOF
)

CREATE_RESPONSE=$(api_request POST "/api/sync/you-or-me" "$ALICE_ID" "$CREATE_BODY")
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

# Test 2: Bob gets the same session
echo -e "${YELLOW}Test 2: Bob gets the same session${NC}"
BOB_GET=$(api_request GET "/api/sync/you-or-me?date=$TODAY" "$BOB_ID")
echo "Response: $BOB_GET" | head -c 500
echo ""

# Test 3: Alice submits answers one at a time
echo -e "${YELLOW}Test 3: Alice submits answers incrementally${NC}"

for i in {1..5}; do
  ANSWER_BODY=$(cat <<EOF
{
  "sessionId": "$SESSION_ID",
  "answer": {
    "questionId": "yom_00$i",
    "questionPrompt": "Who's more",
    "questionContent": "test content $i",
    "answerValue": true
  }
}
EOF
)
  echo "Submitting answer $i..."
  SUBMIT_RESPONSE=$(api_request POST "/api/sync/you-or-me/submit" "$ALICE_ID" "$ANSWER_BODY")
  USER_COUNT=$(echo "$SUBMIT_RESPONSE" | grep -o '"userAnswerCount":[0-9]*' | cut -d':' -f2)
  echo "  User answer count: $USER_COUNT"
done

echo ""

# Test 4: Poll session to see Alice's progress
echo -e "${YELLOW}Test 4: Poll session (Bob checking Alice's progress)${NC}"
POLL_RESPONSE=$(api_request GET "/api/sync/you-or-me/$SESSION_ID" "$BOB_ID")
echo "Response: $POLL_RESPONSE" | head -c 500
echo ""

# Test 5: Alice submits remaining answers as bulk
echo -e "${YELLOW}Test 5: Alice submits remaining answers (bulk)${NC}"
BULK_BODY=$(cat <<EOF
{
  "sessionId": "$SESSION_ID",
  "answers": [
    {"questionId": "yom_006", "questionPrompt": "Who's more likely to", "questionContent": "remember anniversaries", "answerValue": false},
    {"questionId": "yom_007", "questionPrompt": "Who's more", "questionContent": "adventurous", "answerValue": true},
    {"questionId": "yom_008", "questionPrompt": "Who would", "questionContent": "plan a road trip", "answerValue": true},
    {"questionId": "yom_009", "questionPrompt": "Who's more likely to", "questionContent": "apologize first", "answerValue": false},
    {"questionId": "yom_010", "questionPrompt": "Who's more", "questionContent": "romantic", "answerValue": true}
  ]
}
EOF
)
ALICE_COMPLETE=$(api_request POST "/api/sync/you-or-me/submit" "$ALICE_ID" "$BULK_BODY")
echo "Response: $ALICE_COMPLETE" | head -c 500
echo ""

USER_COMPLETE=$(echo "$ALICE_COMPLETE" | grep -o '"userComplete":true' || echo "")
if [ -n "$USER_COMPLETE" ]; then
  echo -e "${GREEN}✅ Alice completed all 10 questions${NC}"
else
  echo -e "${RED}❌ Alice not complete${NC}"
fi

echo ""

# Test 6: Bob submits all answers at once
echo -e "${YELLOW}Test 6: Bob submits all 10 answers${NC}"
BOB_BULK=$(cat <<EOF
{
  "sessionId": "$SESSION_ID",
  "answers": [
    {"questionId": "yom_001", "questionPrompt": "Who's more likely to", "questionContent": "plan a surprise date", "answerValue": false},
    {"questionId": "yom_002", "questionPrompt": "Who's more", "questionContent": "spontaneous", "answerValue": true},
    {"questionId": "yom_003", "questionPrompt": "Who would", "questionContent": "win at trivia", "answerValue": false},
    {"questionId": "yom_004", "questionPrompt": "Who's more likely to", "questionContent": "cook dinner", "answerValue": true},
    {"questionId": "yom_005", "questionPrompt": "Who's more", "questionContent": "patient", "answerValue": false},
    {"questionId": "yom_006", "questionPrompt": "Who's more likely to", "questionContent": "remember anniversaries", "answerValue": true},
    {"questionId": "yom_007", "questionPrompt": "Who's more", "questionContent": "adventurous", "answerValue": false},
    {"questionId": "yom_008", "questionPrompt": "Who would", "questionContent": "plan a road trip", "answerValue": true},
    {"questionId": "yom_009", "questionPrompt": "Who's more likely to", "questionContent": "apologize first", "answerValue": true},
    {"questionId": "yom_010", "questionPrompt": "Who's more", "questionContent": "romantic", "answerValue": false}
  ]
}
EOF
)
BOB_COMPLETE=$(api_request POST "/api/sync/you-or-me/submit" "$BOB_ID" "$BOB_BULK")
echo "Response: $BOB_COMPLETE" | head -c 500
echo ""

# Check for completion
IS_COMPLETED=$(echo "$BOB_COMPLETE" | grep -o '"isCompleted":true' || echo "")
LP_EARNED=$(echo "$BOB_COMPLETE" | grep -o '"lpEarned":[0-9]*' | cut -d':' -f2)

if [ -n "$IS_COMPLETED" ]; then
  echo -e "${GREEN}✅ You or Me completed!${NC}"
  echo "LP Earned: $LP_EARNED"
else
  echo -e "${RED}❌ You or Me not completed${NC}"
fi

echo ""

# Test 7: Final session state
echo -e "${YELLOW}Test 7: Final session state${NC}"
FINAL_STATE=$(api_request GET "/api/sync/you-or-me/$SESSION_ID" "$ALICE_ID")
echo "$FINAL_STATE" | python3 -m json.tool 2>/dev/null || echo "$FINAL_STATE"

echo ""
echo -e "${GREEN}=========================================="
echo "Test Suite Complete!"
echo "==========================================${NC}"
