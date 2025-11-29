# Daily Quest Test Suite

Curl-based API test suite for testing daily quest flows without requiring device builds.

---

## Overview

This test suite simulates two users (Jokke & TestiY) completing daily quests via curl commands. It tests the full daily quest flow including Classic Quiz, Affirmation Quiz, and You-or-Me games.

**Test Results from 2025-11-29:** 18 passed, 21 failed (see findings in `TEST_SUITE_FINDINGS_2025-11-29.md`)

---

## Quick Start

```bash
# 1. Start API server (in one terminal)
cd /Users/joakimachren/Desktop/togetherremind/api
npm run dev

# 2. Run full test suite (in another terminal)
cd /Users/joakimachren/Desktop/togetherremind/api/scripts
./test_daily_quest_flow.sh

# Run specific test only
./test_daily_quest_flow.sh --test=classic
./test_daily_quest_flow.sh --test=affirmation
./test_daily_quest_flow.sh --test=you_or_me
./test_daily_quest_flow.sh --test=verify_lp

# Verbose mode (show full responses)
./test_daily_quest_flow.sh --verbose

# Test against production API
API_URL=https://togetherremind-api.vercel.app ./test_daily_quest_flow.sh
```

---

## Prerequisites

1. **jq** installed for JSON parsing: `brew install jq`
2. **API server running** with dev auth enabled (`AUTH_DEV_BYPASS_ENABLED=true`)
3. **Test users exist** in Supabase (Jokke & TestiY couple)

---

## Test Users

| User | ID | Device | Role |
|------|-----|--------|------|
| Jokke | `d71425a3-a92f-404e-bfbe-a54c4cb58b6a` | Chrome | Goes FIRST |
| TestiY | `c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28` | Android | Goes SECOND |

**Couple ID:** `11111111-1111-1111-1111-111111111111`

---

## File Structure

```
api/scripts/
├── test_daily_quest_flow.sh      # Main test orchestrator
├── lib/
│   ├── test_helpers.sh           # Assertions, colors, API wrapper
│   └── user_config.sh            # User IDs, API URL, couple ID
└── tests/
    ├── 01_reset_data.sh          # Reset test data (needs endpoint)
    ├── 02_classic_quiz.sh        # Classic quiz flow test
    ├── 03_affirmation_quiz.sh    # Affirmation quiz flow test
    ├── 04_you_or_me.sh           # You-or-Me turn-based test
    └── 05_verify_lp.sh           # LP verification test
```

---

## Test Execution Flow

**Order:** Jokke (Chrome/Web) always goes FIRST, TestiY (Android) goes SECOND

```
1. Reset Data
   └── Delete quiz_matches, you_or_me_matches for couple

2. Classic Quiz Test
   ├── Jokke (Chrome) creates/gets quiz match
   ├── Jokke (Chrome) submits his answers
   ├── TestiY (Android) fetches same match
   ├── TestiY (Android) submits predictions
   └── Verify: bothAnswered=true, matchPercentage, lpEarned=30

3. Affirmation Quiz Test
   ├── Jokke (Chrome) creates affirmation match
   ├── Jokke (Chrome) submits ratings
   ├── TestiY (Android) fetches match
   ├── TestiY (Android) submits ratings
   └── Verify: completed, LP awarded

4. You-or-Me Test
   ├── Jokke (Chrome) creates match
   ├── Jokke (Chrome) answers all 10 questions
   ├── TestiY (Android) answers all 10 questions
   └── Verify: completed, scores calculated, LP=30

5. LP Verification
   ├── Fetch Jokke LP total
   ├── Fetch TestiY LP total
   └── Verify: totals match (shared pool)
```

---

## Expected Output

```
========================================
  Daily Quest Test Suite
========================================

Date:      2025-11-29
API:       http://localhost:3000
Jokke ID:  d71425a3-a92f-404e-bfbe-a54c4cb58b6a (Chrome - goes FIRST)
TestiY ID: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28 (Android - goes SECOND)
Couple:    11111111-1111-1111-1111-111111111111

----------------------------------------

[TEST] Classic Quiz - Full Flow
---
[INFO] Jokke (Chrome) creates/gets classic quiz match...
[PASS] Jokke creates classic quiz match (HTTP 200)
[PASS] Response indicates success (.success = true)
[INFO] Match ID: abc123...
[INFO] Jokke (Chrome) submits his answers...
[PASS] Jokke submits answers (HTTP 200)
...

[TEST] Love Points - Verification
---
[INFO] Fetching Jokke's LP total...
[PASS] Fetch Jokke LP (HTTP 200)
[INFO] Jokke total LP: 1160
[INFO] Fetching TestiY's LP total...
[PASS] Fetch TestiY LP (HTTP 200)
[INFO] TestiY total LP: 1160
[PASS] Jokke and TestiY LP totals match (1160)

========================================
Results: 24 passed, 0 failed
========================================
```

---

## API Endpoints Tested

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/sync/quiz-match` | POST | Create/get quiz match for date |
| `/api/sync/quiz-match/submit` | POST | Submit quiz answers |
| `/api/sync/you-or-me-match` | POST | Create/get You-or-Me match |
| `/api/sync/you-or-me-match/submit` | POST | Submit You-or-Me answer |
| `/api/sync/love-points` | GET | Fetch LP total |
| `/api/dev/reset-games` | POST | Reset test data (TODO) |

---

## Dev Auth Bypass

All API calls use the `X-Dev-User-Id` header to bypass authentication:

```bash
curl -X POST "$API_URL/api/sync/quiz-match" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: $JOKKE_ID" \
  -d '{"localDate": "2025-11-29"}'
```

This requires `AUTH_DEV_BYPASS_ENABLED=true` in the API's `.env.local`.

---

## Helper Functions

### `api_call`

Wrapper for curl that handles headers and response parsing:

```bash
RESPONSE=$(api_call POST "/api/sync/quiz-match" "$JOKKE_ID" '{"localDate": "2025-11-29"}')
parse_response "$RESPONSE"
# Now $HTTP_CODE and $BODY are available
```

### Assertions

```bash
assert_status 200 "$HTTP_CODE" "Description"
assert_json_field "$BODY" ".success" "true" "Description"
assert_json_exists "$BODY" ".matchId" "Description"
assert_equal "$EXPECTED" "$ACTUAL" "Description"
```

---

## Known Issues

See `docs/TEST_SUITE_FINDINGS_2025-11-29.md` for detailed findings:

1. **LP Mismatch** - Jokke: 240, TestiY: 1160 (historical data corruption)
2. **Quiz Submit 400s** - Already-completed matches rejected (expected)
3. **Missing Reset Endpoint** - `/api/dev/reset-games` needed

---

## LP Rewards

| Quest Type | LP Award |
|------------|----------|
| Classic Quiz | 30 LP |
| Affirmation Quiz | 30 LP |
| You-or-Me | 30 LP |
| **Total per day** | **90 LP** |

---

## Benefits

1. **Fast iteration** - No app builds needed, tests run in seconds
2. **CI/CD ready** - Can run in GitHub Actions
3. **Reproducible** - Same test data every time
4. **Comprehensive** - Tests all quest types and edge cases
5. **Debuggable** - Clear output shows exactly what failed

---

## Extending the Suite

### Adding a New Test

1. Create `api/scripts/tests/XX_new_test.sh`
2. Use `print_test`, `print_info`, `print_pass`, `print_fail`
3. Use `api_call` for HTTP requests
4. Use `assert_*` functions for validations
5. Add to `test_daily_quest_flow.sh` if needed

### Example Test Template

```bash
#!/bin/bash
# Test: Description of what this tests

print_test "Test Name"
echo "---"

# Step 1
print_info "Doing something..."
RESPONSE=$(api_call POST "/api/sync/endpoint" "$JOKKE_ID" '{"key": "value"}')
parse_response "$RESPONSE"

assert_status 200 "$HTTP_CODE" "Request succeeded"
assert_json_field "$BODY" ".success" "true" "Response indicates success"

echo ""
```

---

**Last Updated:** 2025-11-29
