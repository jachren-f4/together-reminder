import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../exceptions/game_exceptions.dart';
import '../utils/logger.dart';

/// Base class for side quest game services (Linked, Word Search, etc.)
///
/// Provides shared functionality:
/// - API request handling with authentication
/// - Error response parsing with typed exceptions
/// - Date formatting for cooldown checks
/// - Logging with service-specific tags
///
/// Subclasses implement game-specific parsing and caching.
abstract class SideQuestServiceBase {
  final StorageService storage = StorageService();
  final AuthService authService = AuthService();

  /// Service name for logging (e.g., 'linked', 'word_search')
  String get serviceName;

  /// Get API base URL from centralized config
  String get apiBaseUrl => SupabaseConfig.apiUrl;

  /// Make authenticated API request with consistent error handling
  ///
  /// Handles common HTTP errors and converts them to typed exceptions:
  /// - 403 → [NotYourTurnException]
  /// - 404 → [MatchNotFoundException]
  /// - COOLDOWN_ACTIVE code → [CooldownActiveException]
  Future<Map<String, dynamic>> apiRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$apiBaseUrl$path');
    final headers = await authService.getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    http.Response response;

    try {
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
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }

      // Parse error response
      final error = jsonDecode(response.body);
      final errorCode = error['error'] ?? '';
      final errorMessage = error['message'] ?? 'API request failed';

      // Convert HTTP errors to typed exceptions
      switch (response.statusCode) {
        case 403:
          if (errorCode == 'NOT_YOUR_TURN') {
            throw NotYourTurnException(errorMessage);
          }
          throw GameNotActiveException(errorMessage);
        case 404:
          throw MatchNotFoundException(errorMessage);
        default:
          throw Exception(error['error'] ?? 'API request failed');
      }
    } on GameException {
      // Re-throw typed game exceptions without logging
      rethrow;
    } catch (e) {
      Logger.error('API request failed: $method $path',
          error: e, service: serviceName);
      rethrow;
    }
  }

  /// Get local date in YYYY-MM-DD format for cooldown check
  String getLocalDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Check if response indicates cooldown is active
  ///
  /// Call this after getting a successful response to check for soft cooldown errors.
  /// Throws [CooldownActiveException] if cooldown is active, with details about
  /// when the cooldown ends and remaining plays.
  void checkCooldownResponse(Map<String, dynamic> response) {
    if (response['code'] == 'COOLDOWN_ACTIVE') {
      // Parse cooldown details from response
      DateTime? cooldownEndsAt;
      if (response['cooldownEndsAt'] != null) {
        cooldownEndsAt = DateTime.tryParse(response['cooldownEndsAt']);
      }

      final cooldownRemainingMs = response['cooldownRemainingMs'] as int?;
      final remainingInBatch = response['remainingInBatch'] as int? ?? 0;

      throw CooldownActiveException(
        response['message'] ?? 'Next puzzle available in a few hours',
        cooldownEndsAt: cooldownEndsAt,
        cooldownRemainingMs: cooldownRemainingMs,
        remainingInBatch: remainingInBatch,
      );
    }
  }

  /// Get current user ID from auth service
  Future<String?> getCurrentUserId() async {
    return authService.getUserId();
  }
}
