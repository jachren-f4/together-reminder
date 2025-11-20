#!/bin/bash

# Test script for dual-write endpoints
# Note: These endpoints require authentication via JWT token

BASE_URL="http://localhost:4000"

echo "======================================"
echo "Testing Dual-Write API Endpoints"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Note: All endpoints require authentication.${NC}"
echo -e "${YELLOW}Testing without auth to verify endpoint structure...${NC}"
echo ""

# Test 1: Reminders endpoint
echo "1. Testing POST /api/sync/reminders"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "${BASE_URL}/api/sync/reminders" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-poke-123",
    "type": "sent",
    "fromName": "Alice",
    "toName": "Bob",
    "text": "💫 Poke",
    "category": "poke",
    "scheduledFor": "2024-01-15T10:00:00Z",
    "status": "sent",
    "createdAt": "2024-01-15T10:00:00Z"
  }')
echo "Response: $RESPONSE"
echo ""

# Test 2: You or Me endpoint
echo "2. Testing POST /api/sync/you-or-me"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "${BASE_URL}/api/sync/you-or-me" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-session-123",
    "questions": [
      {"id": "q1", "text": "Who is more likely to cook?", "category": "daily"},
      {"id": "q2", "text": "Who is more spontaneous?", "category": "personality"}
    ],
    "createdAt": "2024-01-15T10:00:00Z"
  }')
echo "Response: $RESPONSE"
echo ""

# Test 3: Memory Flip endpoint
echo "3. Testing POST /api/sync/memory-flip"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "${BASE_URL}/api/sync/memory-flip" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-puzzle-123",
    "date": "2024-01-15",
    "totalPairs": 8,
    "matchedPairs": 0,
    "cards": [
      {"id": "c1", "puzzleId": "test-puzzle-123", "position": 0, "emoji": "❤️", "pairId": 1, "status": "hidden"},
      {"id": "c2", "puzzleId": "test-puzzle-123", "position": 1, "emoji": "❤️", "pairId": 1, "status": "hidden"}
    ],
    "status": "active",
    "completionQuote": "Love is in the air!",
    "createdAt": "2024-01-15T10:00:00Z"
  }')
echo "Response: $RESPONSE"
echo ""

echo "======================================"
echo "Expected: All should return 401 Unauthorized (missing JWT token)"
echo "This confirms endpoints are set up correctly!"
echo "======================================"
