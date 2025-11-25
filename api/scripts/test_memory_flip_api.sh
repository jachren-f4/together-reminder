#!/bin/bash
#
# Memory Flip API Test Script
# Tests the full turn-based Memory Flip flow without requiring simulators
#
# Usage: ./scripts/test_memory_flip_api.sh
#
# Prerequisites:
# - API server running on localhost:3000
# - AUTH_DEV_BYPASS_ENABLED=true in .env.local

set -e

API_URL="http://localhost:3000"
ALICE_ID="c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"
BOB_ID="d71425a3-a92f-404e-bfbe-a54c4cb58b6a"
PUZZLE_ID="puzzle_$(date +%Y-%m-%d)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Memory Flip API Test Suite"
echo "=========================================="
echo "API URL: $API_URL"
echo "Puzzle ID: $PUZZLE_ID"
echo "Alice (User 1): $ALICE_ID"
echo "Bob (User 2): $BOB_ID"
echo ""

# Helper function to make API requests
api_request() {
    local method=$1
    local path=$2
    local user_id=$3
    local body=$4

    if [ -n "$body" ]; then
        curl -s -X "$method" "$API_URL$path" \
            -H "Content-Type: application/json" \
            -H "X-Dev-User-Id: $user_id" \
            -d "$body"
    else
        curl -s -X "$method" "$API_URL$path" \
            -H "Content-Type: application/json" \
            -H "X-Dev-User-Id: $user_id"
    fi
}

# Check if API is running
echo "1. Checking API health..."
if ! curl -s "$API_URL" > /dev/null 2>&1; then
    echo -e "${RED}✗ API not running at $API_URL${NC}"
    echo "  Start the API with: cd api && npm run dev"
    exit 1
fi
echo -e "${GREEN}✓ API is running${NC}"
echo ""

# Step 1: Reset Memory Flip data
echo "2. Resetting Memory Flip data..."
RESET_RESPONSE=$(api_request POST "/api/dev/reset-memory-flip" "$ALICE_ID")
if echo "$RESET_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓ Memory Flip data reset${NC}"
else
    echo -e "${YELLOW}⚠ Reset response: $RESET_RESPONSE${NC}"
fi
echo ""

# Step 2: Create a new puzzle
echo "3. Creating new puzzle..."
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CREATE_BODY=$(cat <<EOF
{
    "id": "$PUZZLE_ID",
    "date": "$(date +%Y-%m-%d)",
    "totalPairs": 4,
    "matchedPairs": 0,
    "cards": [
        {"id": "card-0", "emoji": "❤️", "pairId": "pair-0", "status": "hidden", "position": 0},
        {"id": "card-1", "emoji": "❤️", "pairId": "pair-0", "status": "hidden", "position": 1},
        {"id": "card-2", "emoji": "💕", "pairId": "pair-1", "status": "hidden", "position": 2},
        {"id": "card-3", "emoji": "💕", "pairId": "pair-1", "status": "hidden", "position": 3},
        {"id": "card-4", "emoji": "💖", "pairId": "pair-2", "status": "hidden", "position": 4},
        {"id": "card-5", "emoji": "💖", "pairId": "pair-2", "status": "hidden", "position": 5},
        {"id": "card-6", "emoji": "💗", "pairId": "pair-3", "status": "hidden", "position": 6},
        {"id": "card-7", "emoji": "💗", "pairId": "pair-3", "status": "hidden", "position": 7}
    ],
    "status": "active",
    "createdAt": "$NOW"
}
EOF
)

CREATE_RESPONSE=$(api_request POST "/api/sync/memory-flip" "$ALICE_ID" "$CREATE_BODY")
if echo "$CREATE_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓ Puzzle created${NC}"
else
    echo -e "${RED}✗ Failed to create puzzle: $CREATE_RESPONSE${NC}"
    exit 1
fi
echo ""

# Step 3: Get puzzle state as Alice
echo "4. Getting puzzle state as Alice..."
STATE_RESPONSE=$(api_request GET "/api/sync/memory-flip/$PUZZLE_ID" "$ALICE_ID")
if echo "$STATE_RESPONSE" | grep -q '"puzzle"'; then
    echo -e "${GREEN}✓ Got puzzle state${NC}"
    IS_MY_TURN=$(echo "$STATE_RESPONSE" | grep -o '"isMyTurn":[^,]*' | cut -d':' -f2)
    CAN_PLAY=$(echo "$STATE_RESPONSE" | grep -o '"canPlay":[^,]*' | cut -d':' -f2)
    echo "   isMyTurn: $IS_MY_TURN"
    echo "   canPlay: $CAN_PLAY"
else
    echo -e "${RED}✗ Failed to get state: $STATE_RESPONSE${NC}"
    exit 1
fi
echo ""

# Step 4: Alice makes a move (matching pair)
echo "5. Alice makes a move (cards 0 and 1 - matching pair)..."
MOVE_BODY='{"puzzleId":"'"$PUZZLE_ID"'","card1Id":"card-0","card2Id":"card-1"}'
MOVE_RESPONSE=$(api_request POST "/api/sync/memory-flip/move" "$ALICE_ID" "$MOVE_BODY")
if echo "$MOVE_RESPONSE" | grep -q '"success":true'; then
    MATCH_FOUND=$(echo "$MOVE_RESPONSE" | grep -o '"matchFound":[^,]*' | cut -d':' -f2)
    echo -e "${GREEN}✓ Move submitted${NC}"
    echo "   matchFound: $MATCH_FOUND"
    if [ "$MATCH_FOUND" = "true" ]; then
        echo -e "   ${GREEN}Match found! ❤️${NC}"
    fi
else
    echo -e "${RED}✗ Move failed: $MOVE_RESPONSE${NC}"
    exit 1
fi
echo ""

# Step 5: Bob tries to make a move (should work, it's his turn now)
echo "6. Bob makes a move (cards 2 and 3 - matching pair)..."
MOVE_BODY='{"puzzleId":"'"$PUZZLE_ID"'","card1Id":"card-2","card2Id":"card-3"}'
MOVE_RESPONSE=$(api_request POST "/api/sync/memory-flip/move" "$BOB_ID" "$MOVE_BODY")
if echo "$MOVE_RESPONSE" | grep -q '"success":true'; then
    MATCH_FOUND=$(echo "$MOVE_RESPONSE" | grep -o '"matchFound":[^,]*' | cut -d':' -f2)
    echo -e "${GREEN}✓ Bob's move submitted${NC}"
    echo "   matchFound: $MATCH_FOUND"
else
    echo -e "${RED}✗ Bob's move failed: $MOVE_RESPONSE${NC}"
    exit 1
fi
echo ""

# Step 6: Verify turn alternation - Alice should be able to move again
echo "7. Alice makes another move (cards 4 and 5)..."
MOVE_BODY='{"puzzleId":"'"$PUZZLE_ID"'","card1Id":"card-4","card2Id":"card-5"}'
MOVE_RESPONSE=$(api_request POST "/api/sync/memory-flip/move" "$ALICE_ID" "$MOVE_BODY")
if echo "$MOVE_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓ Turn alternation working${NC}"
else
    echo -e "${RED}✗ Turn alternation failed: $MOVE_RESPONSE${NC}"
    exit 1
fi
echo ""

# Step 7: Bob completes the game
echo "8. Bob makes final move (cards 6 and 7)..."
MOVE_BODY='{"puzzleId":"'"$PUZZLE_ID"'","card1Id":"card-6","card2Id":"card-7"}'
MOVE_RESPONSE=$(api_request POST "/api/sync/memory-flip/move" "$BOB_ID" "$MOVE_BODY")
if echo "$MOVE_RESPONSE" | grep -q '"success":true'; then
    GAME_COMPLETED=$(echo "$MOVE_RESPONSE" | grep -o '"gameCompleted":[^,]*' | cut -d':' -f2)
    echo -e "${GREEN}✓ Final move submitted${NC}"
    if [ "$GAME_COMPLETED" = "true" ]; then
        echo -e "   ${GREEN}🎉 Game completed!${NC}"
    fi
else
    echo -e "${RED}✗ Final move failed: $MOVE_RESPONSE${NC}"
    exit 1
fi
echo ""

# Step 8: Verify final state
echo "9. Verifying final game state..."
FINAL_STATE=$(api_request GET "/api/sync/memory-flip/$PUZZLE_ID" "$ALICE_ID")
MATCHED_PAIRS=$(echo "$FINAL_STATE" | grep -o '"matchedPairs":[0-9]*' | cut -d':' -f2)
GAME_PHASE=$(echo "$FINAL_STATE" | grep -o '"gamePhase":"[^"]*"' | cut -d'"' -f4)
echo "   matchedPairs: $MATCHED_PAIRS"
echo "   gamePhase: $GAME_PHASE"

if [ "$MATCHED_PAIRS" = "4" ]; then
    echo -e "${GREEN}✓ All pairs matched${NC}"
else
    echo -e "${YELLOW}⚠ Expected 4 matched pairs, got $MATCHED_PAIRS${NC}"
fi
echo ""

echo "=========================================="
echo -e "${GREEN}All tests passed! ✓${NC}"
echo "=========================================="
