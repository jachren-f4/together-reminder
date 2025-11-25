# Flutter Testing Guide

**Headless Testing Without Simulators**

This guide documents testing approaches that don't require launching simulators or manual interaction. Tests can be run from the command line and verified automatically.

---

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Types Overview](#test-types-overview)
3. [API Integration Tests](#api-integration-tests)
4. [Shell Script Tests](#shell-script-tests)
5. [Running Tests](#running-tests)
6. [Writing New Tests](#writing-new-tests)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Testing Philosophy

### The Problem

Traditional Flutter integration testing requires:
- Launching Android emulator or iOS simulator
- Waiting for app to build and deploy
- Manual interaction to trigger flows
- Back-and-forth between developer and tester

This is slow, error-prone, and creates friction during development.

### The Solution

Use **headless tests** that:
- Run from command line with `flutter test`
- Make real HTTP calls to running API
- Verify full integration without UI
- Complete in seconds, not minutes

### When to Use Each Approach

| Scenario | Approach | Why |
|----------|----------|-----|
| API endpoint changes | Shell script or Dart test | Fast, no Flutter overhead |
| Service layer changes | Dart unit test | Tests actual service code |
| UI layout/interaction | Manual testing | Requires visual verification |
| End-to-end user flows | Manual testing | Complex state management |

---

## Test Types Overview

### 1. Flutter Unit Tests (Headless)

**Location:** `app/test/`
**Command:** `flutter test`
**Simulator:** Not required

Unit tests run in the Dart VM without any device. They can:
- Test business logic
- Make real HTTP calls to APIs
- Mock dependencies with Mockito

### 2. Shell Script Tests

**Location:** `api/scripts/`
**Command:** `./scripts/test_*.sh`
**Simulator:** Not required

Shell scripts use `curl` to test API endpoints directly. Useful for:
- Quick API verification
- CI/CD pipelines
- Testing without Flutter dependencies

### 3. Widget Tests (Headless)

**Location:** `app/test/`
**Command:** `flutter test`
**Simulator:** Not required

Widget tests verify UI components in isolation without a device.

### 4. Integration Tests (Requires Device)

**Location:** `app/integration_test/`
**Command:** `flutter test integration_test/`
**Simulator:** Required

Full app tests that run on a device. Use sparingly.

---

## API Integration Tests

### Example: Memory Flip API Test

**File:** `app/test/memory_flip_api_integration_test.dart`

This test verifies the complete Memory Flip turn-based flow:

```dart
/// Memory Flip API Integration Test
///
/// Tests the MemoryFlipService against the REAL running API.
/// Runs headless with `flutter test` - no simulator needed.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const String apiBaseUrl = 'http://localhost:3000';
const String aliceId = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28';
const String bobId = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a';

void main() {
  /// Helper to make API requests
  Future<http.Response> apiRequest(
    String method,
    String path, {
    String? userId,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (userId != null) 'X-Dev-User-Id': userId,
    };

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers,
          body: body != null ? jsonEncode(body) : null);
      default:
        throw Exception('Unsupported method: $method');
    }
  }

  group('Memory Flip API Integration', () {
    test('API server is running', () async {
      try {
        await http.get(Uri.parse(apiBaseUrl));
      } catch (e) {
        fail('API not running. Start with: cd api && npm run dev');
      }
    });

    test('Create and play game', () async {
      // Create puzzle
      final createResponse = await apiRequest('POST', '/api/sync/memory-flip',
        userId: aliceId,
        body: { /* puzzle data */ });
      expect(jsonDecode(createResponse.body)['success'], isTrue);

      // Alice makes move
      final moveResponse = await apiRequest('POST', '/api/sync/memory-flip/move',
        userId: aliceId,
        body: {'puzzleId': 'test', 'card1Id': 'card-0', 'card2Id': 'card-1'});
      expect(jsonDecode(moveResponse.body)['success'], isTrue);
    });
  });
}
```

### What This Test Covers

1. **API health check** - Verifies server is running
2. **Reset data** - Clears previous test data
3. **Create puzzle** - Tests POST /api/sync/memory-flip
4. **Get state** - Tests GET /api/sync/memory-flip/:id
5. **Player moves** - Tests POST /api/sync/memory-flip/move
6. **Turn validation** - Verifies players can't move out of turn
7. **Game completion** - Verifies end state

### Running the Test

```bash
# Ensure API is running first
cd api && npm run dev &

# Run the test (from app directory)
cd app
flutter test test/memory_flip_api_integration_test.dart --reporter expanded
```

Expected output:
```
00:00 +0: Memory Flip API Integration API server is running
00:00 +1: Memory Flip API Integration Reset Memory Flip data
00:00 +2: Memory Flip API Integration Create puzzle via API
...
00:02 +9: All tests passed!
```

---

## Shell Script Tests

### Example: Memory Flip Shell Test

**File:** `api/scripts/test_memory_flip_api.sh`

```bash
#!/bin/bash
# Memory Flip API Test Script

API_URL="http://localhost:3000"
ALICE_ID="c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"
BOB_ID="d71425a3-a92f-404e-bfbe-a54c4cb58b6a"

# Helper function
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
            -H "X-Dev-User-Id: $user_id"
    fi
}

# Test: Create puzzle
echo "Creating puzzle..."
RESPONSE=$(api_request POST "/api/sync/memory-flip" "$ALICE_ID" '{"id":"test",...}')
if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✓ Puzzle created"
else
    echo "✗ Failed: $RESPONSE"
    exit 1
fi
```

### Running Shell Tests

```bash
cd api
./scripts/test_memory_flip_api.sh
```

### When to Use Shell vs Dart Tests

| Shell Script | Dart Test |
|--------------|-----------|
| Quick API verification | Testing service layer logic |
| CI/CD pipelines | Type-safe assertions |
| No Flutter dependency | Reusable test utilities |
| Simple pass/fail | Detailed test reports |

---

## Running Tests

### Prerequisites

1. **API server running:**
   ```bash
   cd api && npm run dev
   ```

2. **Dev bypass enabled:**
   ```bash
   # In api/.env.local
   AUTH_DEV_BYPASS_ENABLED=true
   ```

### Commands

```bash
# Run all Flutter tests
cd app && flutter test

# Run specific test file
flutter test test/memory_flip_api_integration_test.dart

# Run with verbose output
flutter test --reporter expanded

# Run shell script tests
cd api && ./scripts/test_memory_flip_api.sh
```

### Test Output Formats

```bash
# Compact (default)
flutter test
# Output: 00:02 +9: All tests passed!

# Expanded (detailed)
flutter test --reporter expanded
# Output: Shows each test name and result

# JSON (for CI)
flutter test --reporter json
```

---

## Writing New Tests

### Template: API Integration Test

```dart
/// [Feature] API Integration Test
///
/// Tests [Feature] against the REAL running API.
/// Runs headless with `flutter test` - no simulator needed.
///
/// Prerequisites:
/// - API server running on localhost:3000
/// - AUTH_DEV_BYPASS_ENABLED=true

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const String apiBaseUrl = 'http://localhost:3000';
const String testUserId = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28';

void main() {
  Future<http.Response> apiRequest(String method, String path, {
    String? userId,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (userId != null) 'X-Dev-User-Id': userId,
    };

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers,
          body: body != null ? jsonEncode(body) : null);
      default:
        throw Exception('Unsupported: $method');
    }
  }

  group('[Feature] API Integration', () {
    test('API server is running', () async {
      try {
        await http.get(Uri.parse(apiBaseUrl));
      } catch (e) {
        fail('API not running at $apiBaseUrl');
      }
    });

    test('Basic operation works', () async {
      final response = await apiRequest('GET', '/api/your-endpoint',
        userId: testUserId);
      expect(response.statusCode, equals(200));
    });
  });
}
```

### Template: Shell Script Test

```bash
#!/bin/bash
# [Feature] API Test Script

set -e  # Exit on error

API_URL="http://localhost:3000"
USER_ID="c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

api_request() {
    curl -s -X "$1" "$API_URL$2" \
        -H "Content-Type: application/json" \
        -H "X-Dev-User-Id: $USER_ID" \
        ${3:+-d "$3"}
}

echo "Testing [Feature]..."

# Test 1
RESPONSE=$(api_request GET "/api/your-endpoint")
if echo "$RESPONSE" | grep -q '"success"'; then
    echo -e "${GREEN}✓ Test passed${NC}"
else
    echo -e "${RED}✗ Test failed: $RESPONSE${NC}"
    exit 1
fi

echo -e "${GREEN}All tests passed!${NC}"
```

---

## Best Practices

### 1. Test Independence

Each test should be independent and not rely on state from previous tests:

```dart
setUp(() async {
  // Reset state before each test
  await apiRequest('POST', '/api/dev/reset-feature', userId: testUserId);
});
```

### 2. Unique Test Data

Use unique IDs to avoid conflicts:

```dart
late String testId;

setUpAll(() {
  testId = 'test_${DateTime.now().millisecondsSinceEpoch}';
});
```

### 3. Clear Error Messages

```dart
test('API server is running', () async {
  try {
    await http.get(Uri.parse(apiBaseUrl));
  } catch (e) {
    fail('API not running at $apiBaseUrl. Start with: cd api && npm run dev');
  }
});
```

### 4. Test Both Success and Failure Cases

```dart
test('Valid request succeeds', () async {
  final response = await apiRequest('POST', '/api/endpoint', body: validData);
  expect(jsonDecode(response.body)['success'], isTrue);
});

test('Invalid request fails gracefully', () async {
  final response = await apiRequest('POST', '/api/endpoint', body: invalidData);
  expect(response.statusCode, equals(400));
});
```

### 5. Document Prerequisites

Always include prerequisites in test file headers:

```dart
/// Prerequisites:
/// - API server running on localhost:3000
/// - AUTH_DEV_BYPASS_ENABLED=true in api/.env.local
/// - Test user exists in database
```

---

## Troubleshooting

### "Connection refused" Error

**Problem:** Test can't connect to API

**Solution:**
```bash
# Check if API is running
curl http://localhost:3000

# Start API if needed
cd api && npm run dev
```

### "Unauthorized" Error

**Problem:** API rejects requests

**Solution:**
```bash
# Ensure dev bypass is enabled in api/.env.local
AUTH_DEV_BYPASS_ENABLED=true
NODE_ENV=development
```

### Tests Pass Individually but Fail Together

**Problem:** State leaking between tests

**Solution:**
```dart
setUp(() async {
  // Reset state before each test
  await apiRequest('POST', '/api/dev/reset-data', userId: testUserId);
});
```

### Flaky Tests

**Problem:** Tests sometimes pass, sometimes fail

**Solution:**
- Add retries for network-dependent tests
- Use unique test data IDs
- Add small delays if needed:
  ```dart
  await Future.delayed(Duration(milliseconds: 100));
  ```

---

## Available Tests

### Memory Flip

| Test | Location | Command |
|------|----------|---------|
| Dart API test | `app/test/memory_flip_api_integration_test.dart` | `flutter test test/memory_flip_api_integration_test.dart` |
| Shell script | `api/scripts/test_memory_flip_api.sh` | `./scripts/test_memory_flip_api.sh` |
| Unit tests | `app/test/memory_flip_service_test.dart` | `flutter test test/memory_flip_service_test.dart` |

---

## Future Improvements

- [ ] Add tests for other features (Quiz, Poke, Reminders)
- [ ] Set up CI/CD pipeline to run tests automatically
- [ ] Add code coverage reporting
- [ ] Create test data fixtures for consistent testing
- [ ] Explore Mockito for mocking external dependencies

---

**Last Updated:** 2025-11-21
