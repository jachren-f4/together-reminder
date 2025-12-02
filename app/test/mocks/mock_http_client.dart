/// Mock HTTP Client for testing
///
/// Allows intercepting HTTP requests and returning predefined responses
/// without making actual network calls.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Response builder for mock HTTP client
class MockResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  final Map<String, String> headers;

  MockResponse({
    this.statusCode = 200,
    required this.body,
    this.headers = const {},
  });

  http.Response toResponse() {
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json', ...headers},
    );
  }
}

/// Mock HTTP client that returns predefined responses
class MockHttpOverrides {
  static final Map<String, MockResponse> _responses = {};
  static final List<http.Request> _capturedRequests = [];

  /// Register a mock response for a specific endpoint
  static void when(String method, String urlPattern, MockResponse response) {
    final key = '$method:$urlPattern';
    _responses[key] = response;
  }

  /// Get captured requests (for assertions)
  static List<http.Request> get capturedRequests => List.unmodifiable(_capturedRequests);

  /// Clear all mocks and captured requests
  static void reset() {
    _responses.clear();
    _capturedRequests.clear();
  }

  /// Find a matching response for a request
  static MockResponse? findResponse(String method, String url) {
    // First try exact match
    final exactKey = '$method:$url';
    if (_responses.containsKey(exactKey)) {
      return _responses[exactKey];
    }

    // Then try pattern matching (for endpoints with query params)
    for (final entry in _responses.entries) {
      final key = entry.key;
      final parts = key.split(':');
      if (parts.length == 2 && parts[0] == method) {
        final pattern = parts[1];
        if (url.contains(pattern) || url.startsWith(pattern)) {
          return entry.value;
        }
      }
    }

    return null;
  }

  /// Create a mock HTTP client
  static MockClient createMockClient() {
    return MockClient((request) async {
      _capturedRequests.add(request);

      final response = findResponse(request.method, request.url.toString());
      if (response != null) {
        return response.toResponse();
      }

      // Default 404 for unmatched requests
      return http.Response(
        jsonEncode({'error': 'Mock not found for ${request.method} ${request.url}'}),
        404,
      );
    });
  }
}

/// Test data factories for common response types
class TestDataFactory {
  static Map<String, dynamic> gameStatusResponse({
    int totalLp = 0,
    List<Map<String, dynamic>> games = const [],
  }) {
    return {
      'success': true,
      'totalLp': totalLp,
      'games': games,
      'userId': 'test-user-id',
      'partnerId': 'test-partner-id',
      'date': DateTime.now().toIso8601String().substring(0, 10),
    };
  }

  static Map<String, dynamic> questStatusResponse({
    List<Map<String, dynamic>>? quests,
  }) {
    return {
      'success': true,
      'quests': quests ?? [
        {
          'questType': 'classic',
          'partnerCompleted': false,
          'status': 'active',
        },
      ],
    };
  }

  static Map<String, dynamic> questStatusWithPartnerComplete({
    String questType = 'classic',
    bool partnerCompleted = true,
    String status = 'completed',
  }) {
    return {
      'success': true,
      'quests': [
        {
          'questType': questType,
          'partnerCompleted': partnerCompleted,
          'status': status,
        },
      ],
    };
  }

  static Map<String, dynamic> lovePointsResponse({int totalLp = 30}) {
    return {
      'success': true,
      'total': totalLp,
    };
  }
}
