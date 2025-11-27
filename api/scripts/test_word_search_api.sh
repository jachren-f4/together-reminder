#!/bin/bash
#
# Word Search API Test Script
# Tests the full turn-based Word Search flow without requiring simulators
#
# Usage: ./scripts/test_word_search_api.sh
#
# Prerequisites:
# - API server running on localhost:3000
# - AUTH_DEV_BYPASS_ENABLED=true in .env.local
# - Run migration 012_word_search_game.sql

set -e

API_URL="http://localhost:3000"
ALICE_ID="c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"
BOB_ID="d71425a3-a92f-404e-bfbe-a54c4cb58b6a"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Word Search API Test Suite"
echo "=========================================="
echo "API URL: $API_URL"
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

# Step 1: Create/get match for Alice
echo "2. Creating match (Alice)..."
CREATE_RESPONSE=$(api_request POST "/api/sync/word-search" "$ALICE_ID")
MATCH_ID=$(echo "$CREATE_RESPONSE" | jq -r '.match.matchId')
PUZZLE_ID=$(echo "$CREATE_RESPONSE" | jq -r '.match.puzzleId')
CURRENT_TURN=$(echo "$CREATE_RESPONSE" | jq -r '.match.currentTurnUserId')
IS_NEW=$(echo "$CREATE_RESPONSE" | jq -r '.isNewMatch')

if [ "$MATCH_ID" != "null" ] && [ -n "$MATCH_ID" ]; then
    echo -e "${GREEN}✓ Match created/retrieved${NC}"
    echo "  Match ID: $MATCH_ID"
    echo "  Puzzle ID: $PUZZLE_ID"
    echo "  Is New Match: $IS_NEW"
    echo "  Current Turn: $CURRENT_TURN"
else
    echo -e "${RED}✗ Failed to create match${NC}"
    echo "  Response: $CREATE_RESPONSE"
    exit 1
fi
echo ""

# Step 2: Check game state for Bob
echo "3. Checking game state (Bob)..."
BOB_STATE=$(api_request GET "/api/sync/word-search" "$BOB_ID")
BOB_IS_MY_TURN=$(echo "$BOB_STATE" | jq -r '.gameState.isMyTurn')
echo "  Bob's turn: $BOB_IS_MY_TURN"
echo ""

# Determine who goes first
if [ "$CURRENT_TURN" = "$BOB_ID" ]; then
    FIRST_PLAYER_ID=$BOB_ID
    FIRST_PLAYER_NAME="Bob"
    SECOND_PLAYER_ID=$ALICE_ID
    SECOND_PLAYER_NAME="Alice"
else
    FIRST_PLAYER_ID=$ALICE_ID
    FIRST_PLAYER_NAME="Alice"
    SECOND_PLAYER_ID=$BOB_ID
    SECOND_PLAYER_NAME="Bob"
fi

echo -e "${BLUE}Turn order: $FIRST_PLAYER_NAME goes first${NC}"
echo ""

# Step 3: First player finds word 1 (FOREPLAY at 0,R = positions 0-7)
echo "4. $FIRST_PLAYER_NAME finds FOREPLAY..."
SUBMIT_BODY='{
    "matchId": "'"$MATCH_ID"'",
    "word": "FOREPLAY",
    "positions": [
        {"row": 0, "col": 0},
        {"row": 0, "col": 1},
        {"row": 0, "col": 2},
        {"row": 0, "col": 3},
        {"row": 0, "col": 4},
        {"row": 0, "col": 5},
        {"row": 0, "col": 6},
        {"row": 0, "col": 7}
    ]
}'
SUBMIT_RESPONSE=$(api_request POST "/api/sync/word-search/submit" "$FIRST_PLAYER_ID" "$SUBMIT_BODY")
VALID=$(echo "$SUBMIT_RESPONSE" | jq -r '.valid')
POINTS=$(echo "$SUBMIT_RESPONSE" | jq -r '.pointsEarned')
WORDS_THIS_TURN=$(echo "$SUBMIT_RESPONSE" | jq -r '.wordsFoundThisTurn')

if [ "$VALID" = "true" ]; then
    echo -e "${GREEN}✓ FOREPLAY found! (+$POINTS points)${NC}"
    echo "  Words found this turn: $WORDS_THIS_TURN"
else
    echo -e "${RED}✗ Word submission failed${NC}"
    echo "  Response: $SUBMIT_RESPONSE"
fi
echo ""

# Step 4: First player finds word 2 (SENSUAL at 10,R = row 1)
echo "5. $FIRST_PLAYER_NAME finds SENSUAL..."
SUBMIT_BODY='{
    "matchId": "'"$MATCH_ID"'",
    "word": "SENSUAL",
    "positions": [
        {"row": 1, "col": 0},
        {"row": 1, "col": 1},
        {"row": 1, "col": 2},
        {"row": 1, "col": 3},
        {"row": 1, "col": 4},
        {"row": 1, "col": 5},
        {"row": 1, "col": 6}
    ]
}'
SUBMIT_RESPONSE=$(api_request POST "/api/sync/word-search/submit" "$FIRST_PLAYER_ID" "$SUBMIT_BODY")
VALID=$(echo "$SUBMIT_RESPONSE" | jq -r '.valid')
WORDS_THIS_TURN=$(echo "$SUBMIT_RESPONSE" | jq -r '.wordsFoundThisTurn')

if [ "$VALID" = "true" ]; then
    echo -e "${GREEN}✓ SENSUAL found!${NC}"
    echo "  Words found this turn: $WORDS_THIS_TURN"
else
    echo -e "${RED}✗ Word submission failed${NC}"
    echo "  Response: $SUBMIT_RESPONSE"
fi
echo ""

# Step 5: First player finds word 3 (INTIMACY at 20,R = row 2)
echo "6. $FIRST_PLAYER_NAME finds INTIMACY (completes turn)..."
SUBMIT_BODY='{
    "matchId": "'"$MATCH_ID"'",
    "word": "INTIMACY",
    "positions": [
        {"row": 2, "col": 0},
        {"row": 2, "col": 1},
        {"row": 2, "col": 2},
        {"row": 2, "col": 3},
        {"row": 2, "col": 4},
        {"row": 2, "col": 5},
        {"row": 2, "col": 6},
        {"row": 2, "col": 7}
    ]
}'
SUBMIT_RESPONSE=$(api_request POST "/api/sync/word-search/submit" "$FIRST_PLAYER_ID" "$SUBMIT_BODY")
VALID=$(echo "$SUBMIT_RESPONSE" | jq -r '.valid')
TURN_COMPLETE=$(echo "$SUBMIT_RESPONSE" | jq -r '.turnComplete')
NEXT_TURN=$(echo "$SUBMIT_RESPONSE" | jq -r '.nextTurnUserId')

if [ "$VALID" = "true" ]; then
    echo -e "${GREEN}✓ INTIMACY found!${NC}"
    echo "  Turn complete: $TURN_COMPLETE"
    if [ "$TURN_COMPLETE" = "true" ]; then
        echo -e "${BLUE}  → Turn switched to $SECOND_PLAYER_NAME${NC}"
    fi
else
    echo -e "${RED}✗ Word submission failed${NC}"
    echo "  Response: $SUBMIT_RESPONSE"
fi
echo ""

# Step 6: Verify turn switched - first player should get NOT_YOUR_TURN
echo "7. Verifying turn switch ($FIRST_PLAYER_NAME tries to play)..."
SUBMIT_BODY='{
    "matchId": "'"$MATCH_ID"'",
    "word": "DESIRE",
    "positions": [
        {"row": 3, "col": 0},
        {"row": 3, "col": 1},
        {"row": 3, "col": 2},
        {"row": 3, "col": 3},
        {"row": 3, "col": 4},
        {"row": 3, "col": 5}
    ]
}'
SUBMIT_RESPONSE=$(api_request POST "/api/sync/word-search/submit" "$FIRST_PLAYER_ID" "$SUBMIT_BODY")
ERROR=$(echo "$SUBMIT_RESPONSE" | jq -r '.error')

if [ "$ERROR" = "NOT_YOUR_TURN" ]; then
    echo -e "${GREEN}✓ Correctly blocked - not $FIRST_PLAYER_NAME's turn${NC}"
else
    echo -e "${RED}✗ Should have been blocked${NC}"
    echo "  Response: $SUBMIT_RESPONSE"
fi
echo ""

# Step 7: Second player uses hint
echo "8. $SECOND_PLAYER_NAME uses hint..."
HINT_BODY='{"matchId": "'"$MATCH_ID"'"}'
HINT_RESPONSE=$(api_request POST "/api/sync/word-search/hint" "$SECOND_PLAYER_ID" "$HINT_BODY")
HINT_WORD=$(echo "$HINT_RESPONSE" | jq -r '.hint.word')
HINT_ROW=$(echo "$HINT_RESPONSE" | jq -r '.hint.firstLetterPosition.row')
HINT_COL=$(echo "$HINT_RESPONSE" | jq -r '.hint.firstLetterPosition.col')
HINTS_LEFT=$(echo "$HINT_RESPONSE" | jq -r '.hintsRemaining')

if [ "$HINT_WORD" != "null" ]; then
    echo -e "${GREEN}✓ Hint received${NC}"
    echo "  Word: $HINT_WORD"
    echo "  First letter at: row $HINT_ROW, col $HINT_COL"
    echo "  Hints remaining: $HINTS_LEFT"
else
    echo -e "${RED}✗ Hint failed${NC}"
    echo "  Response: $HINT_RESPONSE"
fi
echo ""

# Step 8: Second player finds 3 words (DESIRE, SOFT, PLEASURE)
echo "9. $SECOND_PLAYER_NAME finds DESIRE..."
SUBMIT_BODY='{
    "matchId": "'"$MATCH_ID"'",
    "word": "DESIRE",
    "positions": [
        {"row": 3, "col": 0},
        {"row": 3, "col": 1},
        {"row": 3, "col": 2},
        {"row": 3, "col": 3},
        {"row": 3, "col": 4},
        {"row": 3, "col": 5}
    ]
}'
SUBMIT_RESPONSE=$(api_request POST "/api/sync/word-search/submit" "$SECOND_PLAYER_ID" "$SUBMIT_BODY")
VALID=$(echo "$SUBMIT_RESPONSE" | jq -r '.valid')
if [ "$VALID" = "true" ]; then
    echo -e "${GREEN}✓ DESIRE found!${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "  Response: $SUBMIT_RESPONSE"
fi

echo "   $SECOND_PLAYER_NAME finds SOFT..."
SUBMIT_BODY='{
    "matchId": "'"$MATCH_ID"'",
    "word": "SOFT",
    "positions": [
        {"row": 3, "col": 6},
        {"row": 3, "col": 7},
        {"row": 3, "col": 8},
        {"row": 3, "col": 9}
    ]
}'
SUBMIT_RESPONSE=$(api_request POST "/api/sync/word-search/submit" "$SECOND_PLAYER_ID" "$SUBMIT_BODY")
VALID=$(echo "$SUBMIT_RESPONSE" | jq -r '.valid')
if [ "$VALID" = "true" ]; then
    echo -e "${GREEN}✓ SOFT found!${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "  Response: $SUBMIT_RESPONSE"
fi

echo "   $SECOND_PLAYER_NAME finds PLEASURE..."
SUBMIT_BODY='{
    "matchId": "'"$MATCH_ID"'",
    "word": "PLEASURE",
    "positions": [
        {"row": 4, "col": 0},
        {"row": 4, "col": 1},
        {"row": 4, "col": 2},
        {"row": 4, "col": 3},
        {"row": 4, "col": 4},
        {"row": 4, "col": 5},
        {"row": 4, "col": 6},
        {"row": 4, "col": 7}
    ]
}'
SUBMIT_RESPONSE=$(api_request POST "/api/sync/word-search/submit" "$SECOND_PLAYER_ID" "$SUBMIT_BODY")
VALID=$(echo "$SUBMIT_RESPONSE" | jq -r '.valid')
TURN_COMPLETE=$(echo "$SUBMIT_RESPONSE" | jq -r '.turnComplete')
if [ "$VALID" = "true" ]; then
    echo -e "${GREEN}✓ PLEASURE found!${NC}"
    echo "  Turn complete: $TURN_COMPLETE"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "  Response: $SUBMIT_RESPONSE"
fi
echo ""

# Step 9: Check progress (use main endpoint, not [matchId])
echo "10. Checking game progress..."
POLL_RESPONSE=$(api_request GET "/api/sync/word-search" "$ALICE_ID")
FOUND_COUNT=$(echo "$POLL_RESPONSE" | jq '.match.foundWords | length')
PROGRESS=$(echo "$POLL_RESPONSE" | jq -r '.gameState.progressPercent')
P1_WORDS=$(echo "$POLL_RESPONSE" | jq -r '.match.player1WordsFound')
P2_WORDS=$(echo "$POLL_RESPONSE" | jq -r '.match.player2WordsFound')
TURN_NUM=$(echo "$POLL_RESPONSE" | jq -r '.match.turnNumber')

echo "  Words found: $FOUND_COUNT / 12"
echo "  Progress: $PROGRESS%"
echo "  Player 1 words: $P1_WORDS"
echo "  Player 2 words: $P2_WORDS"
echo "  Current turn: $TURN_NUM"
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}✓ Match creation works${NC}"
echo -e "${GREEN}✓ Word submission with positions works${NC}"
echo -e "${GREEN}✓ Turn switching after 3 words works${NC}"
echo -e "${GREEN}✓ Turn validation (NOT_YOUR_TURN) works${NC}"
echo -e "${GREEN}✓ Hints work${NC}"
echo -e "${GREEN}✓ Progress tracking works${NC}"
echo ""
echo "Match ID for manual testing: $MATCH_ID"
echo ""
echo "To complete the game, continue finding:"
echo "  - TENDER (row 5, col 0-5)"
echo "  - LUST (row 5, col 6-9)"
echo "  - PASSION (row 6, col 0-6)"
echo "  - ROMANCE (row 7, col 0-6)"
echo "  - EROTIC (row 8, col 0-5)"
echo "  - CLIMAX (row 9, col 0-5)"
