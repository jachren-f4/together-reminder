/// Memory Flip API Integration Test
///
/// Tests the MemoryFlipService against the REAL running API.
/// Runs headless with `flutter test` - no simulator needed.
///
/// Prerequisites:
/// - API server running on localhost:3000
/// - AUTH_DEV_BYPASS_ENABLED=true in api/.env.local
///
/// Usage:
///   flutter test test/memory_flip_api_integration_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// Test configuration
const String apiBaseUrl = 'http://localhost:3000';
const String aliceId = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28';
const String bobId = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a';

void main() {
  late String puzzleId;

  setUpAll(() {
    puzzleId = 'puzzle_test_${DateTime.now().millisecondsSinceEpoch}';
  });

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
        return http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      default:
        throw Exception('Unsupported method: $method');
    }
  }

  group('Memory Flip API Integration', () {
    test('API server is running', () async {
      try {
        final response = await http.get(Uri.parse(apiBaseUrl));
        // Any response means server is running (even 404 is fine)
        expect(response.statusCode, isNotNull);
      } catch (e) {
        fail('API server not running at $apiBaseUrl. Start with: cd api && npm run dev');
      }
    });

    // CORS preflight tests - browsers send OPTIONS before POST with custom headers
    test('CORS: POST /api/sync/memory-flip allows X-Dev-User-Id', () async {
      final response = await http.Request('OPTIONS', Uri.parse('$apiBaseUrl/api/sync/memory-flip'))
        ..headers['Access-Control-Request-Method'] = 'POST'
        ..headers['Access-Control-Request-Headers'] = 'x-dev-user-id';
      final streamedResponse = await http.Client().send(response);
      final allowedHeaders = streamedResponse.headers['access-control-allow-headers'] ?? '';
      expect(allowedHeaders.toLowerCase(), contains('x-dev-user-id'),
          reason: 'OPTIONS must allow X-Dev-User-Id for browser CORS');
    });

    test('CORS: POST /api/sync/memory-flip/move allows X-Dev-User-Id', () async {
      final response = await http.Request('OPTIONS', Uri.parse('$apiBaseUrl/api/sync/memory-flip/move'))
        ..headers['Access-Control-Request-Method'] = 'POST'
        ..headers['Access-Control-Request-Headers'] = 'x-dev-user-id';
      final streamedResponse = await http.Client().send(response);
      final allowedHeaders = streamedResponse.headers['access-control-allow-headers'] ?? '';
      expect(allowedHeaders.toLowerCase(), contains('x-dev-user-id'),
          reason: 'OPTIONS must allow X-Dev-User-Id for browser CORS');
    });

    test('CORS: GET /api/sync/memory-flip/:id allows X-Dev-User-Id', () async {
      final response = await http.Request('OPTIONS', Uri.parse('$apiBaseUrl/api/sync/memory-flip/test'))
        ..headers['Access-Control-Request-Method'] = 'GET'
        ..headers['Access-Control-Request-Headers'] = 'x-dev-user-id';
      final streamedResponse = await http.Client().send(response);
      final allowedHeaders = streamedResponse.headers['access-control-allow-headers'] ?? '';
      expect(allowedHeaders.toLowerCase(), contains('x-dev-user-id'),
          reason: 'OPTIONS must allow X-Dev-User-Id for browser CORS');
    });

    test('Reset Memory Flip data', () async {
      final response = await apiRequest(
        'POST',
        '/api/dev/reset-memory-flip',
        userId: aliceId,
      );

      final data = jsonDecode(response.body);
      expect(data['success'], isTrue);
    });

    test('Create puzzle via API', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await apiRequest(
        'POST',
        '/api/sync/memory-flip',
        userId: aliceId,
        body: {
          'id': puzzleId,
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'totalPairs': 4,
          'matchedPairs': 0,
          'cards': [
            {'id': 'card-0', 'emoji': '❤️', 'pairId': 'pair-0', 'status': 'hidden', 'position': 0},
            {'id': 'card-1', 'emoji': '❤️', 'pairId': 'pair-0', 'status': 'hidden', 'position': 1},
            {'id': 'card-2', 'emoji': '💕', 'pairId': 'pair-1', 'status': 'hidden', 'position': 2},
            {'id': 'card-3', 'emoji': '💕', 'pairId': 'pair-1', 'status': 'hidden', 'position': 3},
            {'id': 'card-4', 'emoji': '💖', 'pairId': 'pair-2', 'status': 'hidden', 'position': 4},
            {'id': 'card-5', 'emoji': '💖', 'pairId': 'pair-2', 'status': 'hidden', 'position': 5},
            {'id': 'card-6', 'emoji': '💗', 'pairId': 'pair-3', 'status': 'hidden', 'position': 6},
            {'id': 'card-7', 'emoji': '💗', 'pairId': 'pair-3', 'status': 'hidden', 'position': 7},
          ],
          'status': 'active',
          'createdAt': now,
        },
      );

      expect(response.statusCode, equals(200));
      final data = jsonDecode(response.body);
      expect(data['success'], isTrue);
    });

    test('Get puzzle state', () async {
      final response = await apiRequest(
        'GET',
        '/api/sync/memory-flip/$puzzleId',
        userId: aliceId,
      );

      expect(response.statusCode, equals(200));
      final data = jsonDecode(response.body);
      expect(data['puzzle'], isNotNull);
      expect(data['puzzle']['id'], equals(puzzleId));
      expect(data['puzzle']['totalPairs'], equals(4));
    });

    test('Alice makes a move - matching pair', () async {
      final response = await apiRequest(
        'POST',
        '/api/sync/memory-flip/move',
        userId: aliceId,
        body: {
          'puzzleId': puzzleId,
          'card1Id': 'card-0',
          'card2Id': 'card-1',
        },
      );

      expect(response.statusCode, equals(200));
      final data = jsonDecode(response.body);
      expect(data['success'], isTrue);
      expect(data['matchFound'], isTrue);
    });

    test('Bob makes a move - his turn now', () async {
      final response = await apiRequest(
        'POST',
        '/api/sync/memory-flip/move',
        userId: bobId,
        body: {
          'puzzleId': puzzleId,
          'card1Id': 'card-2',
          'card2Id': 'card-3',
        },
      );

      expect(response.statusCode, equals(200));
      final data = jsonDecode(response.body);
      expect(data['success'], isTrue);
      expect(data['matchFound'], isTrue);
    });

    test('Alice cannot move twice in a row', () async {
      // First, Alice moves
      await apiRequest(
        'POST',
        '/api/sync/memory-flip/move',
        userId: aliceId,
        body: {
          'puzzleId': puzzleId,
          'card1Id': 'card-4',
          'card2Id': 'card-5',
        },
      );

      // Then Alice tries to move again - should fail
      final response = await apiRequest(
        'POST',
        '/api/sync/memory-flip/move',
        userId: aliceId,
        body: {
          'puzzleId': puzzleId,
          'card1Id': 'card-6',
          'card2Id': 'card-7',
        },
      );

      final data = jsonDecode(response.body);
      expect(data['success'], isFalse);
      expect(data['error'], equals('NOT_YOUR_TURN'));
    });

    test('Bob completes the game', () async {
      final response = await apiRequest(
        'POST',
        '/api/sync/memory-flip/move',
        userId: bobId,
        body: {
          'puzzleId': puzzleId,
          'card1Id': 'card-6',
          'card2Id': 'card-7',
        },
      );

      expect(response.statusCode, equals(200));
      final data = jsonDecode(response.body);
      expect(data['success'], isTrue);
      expect(data['gameCompleted'], isTrue);
    });

    test('Final state shows game completed', () async {
      final response = await apiRequest(
        'GET',
        '/api/sync/memory-flip/$puzzleId',
        userId: aliceId,
      );

      final data = jsonDecode(response.body);
      expect(data['puzzle']['matchedPairs'], equals(4));
      expect(data['puzzle']['gamePhase'], equals('completed'));
    });
  });
}
