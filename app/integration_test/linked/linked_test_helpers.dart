/// Reusable test utilities for Linked game integration tests
///
/// Provides helpers for:
/// - Resetting test data via API
/// - Making API calls as test users
/// - Simulating partner actions
/// - Verifying LP awards
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'test_config.dart';

/// API client for test operations
class LinkedTestApi {
  final String baseUrl;
  final String userId;

  LinkedTestApi({
    required this.userId,
    this.baseUrl = LinkedTestConfig.apiBaseUrl,
  });

  /// Make authenticated API request
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      'X-Dev-User-Id': userId,
    };

    http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : '{}',
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['error'] ?? 'API request failed',
        code: error['code'],
      );
    }
  }

  /// Get or create a Linked match
  Future<Map<String, dynamic>> getOrCreateMatch() async {
    final now = DateTime.now();
    final localDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return request('POST', '/api/sync/linked', body: {'localDate': localDate});
  }

  /// Poll match state by ID
  Future<Map<String, dynamic>> pollMatch(String matchId) async {
    return request('GET', '/api/sync/linked/$matchId');
  }

  /// Submit placements for a turn
  Future<Map<String, dynamic>> submitTurn(
    String matchId,
    List<Map<String, dynamic>> placements,
  ) async {
    return request('POST', '/api/sync/linked/submit', body: {
      'matchId': matchId,
      'placements': placements,
    });
  }

  /// Get couple's current LP
  Future<int> getCoupleLP() async {
    final response = await request('GET', '/api/sync/love-points');
    return response['totalLP'] as int? ?? 0;
  }
}

/// Exception for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  @override
  String toString() => 'ApiException($statusCode): $message [code: $code]';

  bool get isNotYourTurn => code == 'NOT_YOUR_TURN';
  bool get isGameNotActive => code == 'GAME_NOT_ACTIVE';
  bool get isCooldownActive => code == 'COOLDOWN_ACTIVE';
}

/// Helper to reset all test data
class LinkedTestDataReset {
  /// Reset all progress for the test couple via direct API call
  ///
  /// This calls a test-only endpoint that clears:
  /// - Linked matches and moves
  /// - Love points
  /// - Branch progression
  static Future<void> resetTestData() async {
    final api = LinkedTestApi(userId: LinkedTestConfig.testUserId);

    try {
      // Call the reset endpoint (assumes it exists for testing)
      await api.request('POST', '/api/dev/reset-couple-progress', body: {
        'coupleId': LinkedTestConfig.coupleId,
      });
    } catch (e) {
      // If endpoint doesn't exist, we can't reset via API
      // Tests should handle this gracefully
      print('Warning: Could not reset test data via API: $e');
    }
  }

  /// Alternative: Reset by completing and starting fresh match
  /// Use this if the reset endpoint isn't available
  static Future<void> resetByStartingFresh() async {
    // Simply start a new match - the API handles match rotation
    final api = LinkedTestApi(userId: LinkedTestConfig.testUserId);
    try {
      await api.getOrCreateMatch();
    } catch (e) {
      // Cooldown might be active - that's ok for some tests
      print('Warning: Could not start fresh match: $e');
    }
  }
}

/// Simulate partner actions from the partner's perspective
class PartnerSimulator {
  final LinkedTestApi _partnerApi;

  PartnerSimulator()
      : _partnerApi = LinkedTestApi(userId: LinkedTestConfig.partnerUserId);

  /// Get current match state as partner
  Future<Map<String, dynamic>> getMatchState(String matchId) async {
    return _partnerApi.pollMatch(matchId);
  }

  /// Submit partner's turn
  Future<Map<String, dynamic>> submitTurn(
    String matchId,
    List<Map<String, dynamic>> placements,
  ) async {
    return _partnerApi.submitTurn(matchId, placements);
  }

  /// Wait for it to be partner's turn, then submit placements
  Future<Map<String, dynamic>> waitAndSubmit(
    String matchId,
    List<Map<String, dynamic>> placements, {
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 100),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final state = await getMatchState(matchId);
        final gameState = state['gameState'] as Map<String, dynamic>?;

        if (gameState?['isMyTurn'] == true) {
          return submitTurn(matchId, placements);
        }
      } catch (e) {
        // Ignore errors during polling
      }

      await Future.delayed(pollInterval);
    }

    throw TimeoutException('Partner never got their turn');
  }
}

/// Timeout exception for test operations
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

/// Assertions for Linked game tests
class LinkedTestAssertions {
  /// Assert that LP increased by expected amount
  static Future<void> assertLPIncreased({
    required int lpBefore,
    required int expectedIncrease,
  }) async {
    final api = LinkedTestApi(userId: LinkedTestConfig.testUserId);
    final lpAfter = await api.getCoupleLP();

    if (lpAfter != lpBefore + expectedIncrease) {
      throw AssertionError(
        'Expected LP to increase by $expectedIncrease '
        '(from $lpBefore to ${lpBefore + expectedIncrease}), '
        'but got $lpAfter (increase of ${lpAfter - lpBefore})',
      );
    }
  }

  /// Assert that points match expected value
  static void assertPointsEarned({
    required Map<String, dynamic> result,
    required int expectedPoints,
  }) {
    final actualPoints = result['pointsEarned'] as int? ?? 0;
    if (actualPoints != expectedPoints) {
      throw AssertionError(
        'Expected $expectedPoints points, but got $actualPoints',
      );
    }
  }

  /// Assert that game is complete
  static void assertGameComplete(Map<String, dynamic> result) {
    final isComplete = result['gameComplete'] as bool? ?? false;
    if (!isComplete) {
      throw AssertionError('Expected game to be complete');
    }
  }

  /// Assert that game is NOT complete
  static void assertGameNotComplete(Map<String, dynamic> result) {
    final isComplete = result['gameComplete'] as bool? ?? false;
    if (isComplete) {
      throw AssertionError('Expected game to NOT be complete');
    }
  }

  /// Assert correct placements count
  static void assertCorrectPlacements({
    required Map<String, dynamic> result,
    required int expectedCorrect,
  }) {
    final results = result['results'] as List<dynamic>? ?? [];
    final correctCount = results.where((r) => r['correct'] == true).length;

    if (correctCount != expectedCorrect) {
      throw AssertionError(
        'Expected $expectedCorrect correct placements, but got $correctCount',
      );
    }
  }

  /// Assert winner ID matches expected
  static void assertWinner({
    required Map<String, dynamic> result,
    required String? expectedWinnerId,
  }) {
    final winnerId = result['winnerId'] as String?;
    if (winnerId != expectedWinnerId) {
      throw AssertionError(
        'Expected winner to be $expectedWinnerId, but got $winnerId',
      );
    }
  }
}
