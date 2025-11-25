#!/bin/bash

echo "🧪 Testing Memory Flip Turn-Based API"
echo "======================================"

# Configuration
API_BASE="http://localhost:3000/api"
PUZZLE_ID="puzzle_$(date +%Y-%m-%d)"
USER_ID="c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"

# Test 1: Create a puzzle
echo -e "\n📋 Test 1: Creating puzzle..."
curl -X POST "$API_BASE/sync/memory-flip" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER_ID" \
  -d '{
    "id": "'$PUZZLE_ID'",
    "date": "'$(date +%Y-%m-%d)'",
    "totalPairs": 4,
    "matchedPairs": 0,
    "cards": [
      {"id": "card-0", "emoji": "🍎", "pairId": "pair-0", "status": "hidden"},
      {"id": "card-1", "emoji": "🍎", "pairId": "pair-0", "status": "hidden"},
      {"id": "card-2", "emoji": "🍌", "pairId": "pair-1", "status": "hidden"},
      {"id": "card-3", "emoji": "🍌", "pairId": "pair-1", "status": "hidden"},
      {"id": "card-4", "emoji": "🍇", "pairId": "pair-2", "status": "hidden"},
      {"id": "card-5", "emoji": "🍇", "pairId": "pair-2", "status": "hidden"},
      {"id": "card-6", "emoji": "🍊", "pairId": "pair-3", "status": "hidden"},
      {"id": "card-7", "emoji": "🍊", "pairId": "pair-3", "status": "hidden"}
    ],
    "status": "active",
    "createdAt": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'"
  }' | jq '.'

# Test 2: Get puzzle state
echo -e "\n📋 Test 2: Getting puzzle state..."
curl -X GET "$API_BASE/sync/memory-flip/$PUZZLE_ID" \
  -H "X-Dev-User-Id: $USER_ID" | jq '.'

# Test 3: Submit a move (no match)
echo -e "\n📋 Test 3: Submitting move (no match expected)..."
curl -X POST "$API_BASE/sync/memory-flip/move" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER_ID" \
  -d '{
    "puzzleId": "'$PUZZLE_ID'",
    "card1Id": "card-0",
    "card2Id": "card-2"
  }' | jq '.'

# Test 4: Submit a move (match)
echo -e "\n📋 Test 4: Submitting move (match expected)..."
curl -X POST "$API_BASE/sync/memory-flip/move" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $USER_ID" \
  -d '{
    "puzzleId": "'$PUZZLE_ID'",
    "card1Id": "card-0",
    "card2Id": "card-1"
  }' | jq '.'

echo -e "\n✅ Tests completed!"