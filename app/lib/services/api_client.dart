import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// API Client for making authenticated requests to Next.js backend
/// 
/// Features:
/// - Automatic JWT token inclusion
/// - Automatic 401 handling with token refresh
/// - Retry logic for failed requests
/// - Rate limit handling (429)
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _authService = AuthService();
  
  // API base URL (configure based on environment)
  String _baseUrl = 'https://your-api.vercel.app';
  
  // Debug flag to simulate network errors
  bool simulateNetworkError = false;
  
  void configure({required String baseUrl}) {
    _baseUrl = baseUrl;
    debugPrint('✅ ApiClient configured: $_baseUrl');
  }

  /// GET request with authentication
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return _makeRequest(
      method: 'GET',
      endpoint: endpoint,
      queryParams: queryParams,
      parser: parser,
    );
  }

  /// POST request with authentication
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return _makeRequest(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      parser: parser,
    );
  }

  /// PUT request with authentication
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return _makeRequest(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      parser: parser,
    );
  }

  /// DELETE request with authentication
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return _makeRequest(
      method: 'DELETE',
      endpoint: endpoint,
      parser: parser,
    );
  }

  // Private request method with retry logic
  Future<ApiResponse<T>> _makeRequest<T>({
    required String method,
    required String endpoint,
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? parser,
    int retryCount = 0,
  }) async {
    if (simulateNetworkError) {
      await Future.delayed(const Duration(milliseconds: 500));
      return ApiResponse.error('Simulated network error');
    }

    try {
      // Build URL
      final uri = _buildUri(endpoint, queryParams);
      
      // Get auth headers
      final headers = await _authService.getAuthHeaders();
      
      // Make request
      http.Response response;
      
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
      
      // Handle response
      return _handleResponse<T>(
        response: response,
        method: method,
        endpoint: endpoint,
        queryParams: queryParams,
        body: body,
        parser: parser,
        retryCount: retryCount,
      );
    } on SocketException {
      return ApiResponse.error('No internet connection');
    } on HttpException {
      return ApiResponse.error('HTTP error occurred');
    } catch (e) {
      debugPrint('❌ API request error: $e');
      return ApiResponse.error('Request failed: $e');
    }
  }

  Future<ApiResponse<T>> _handleResponse<T>({
    required http.Response response,
    required String method,
    required String endpoint,
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? parser,
    required int retryCount,
  }) async {
    final statusCode = response.statusCode;
    
    // Success (200-299)
    if (statusCode >= 200 && statusCode < 300) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (parser != null) {
          final parsed = parser(data);
          return ApiResponse.success(parsed);
        }
        
        return ApiResponse.success(data as T);
      } catch (e) {
        debugPrint('❌ Error parsing response: $e');
        return ApiResponse.error('Failed to parse response');
      }
    }
    
    // Unauthorized (401) - Token expired or invalid
    if (statusCode == 401 && retryCount < 2) {
      debugPrint('🔐 401 Unauthorized - attempting token refresh');
      
      final refreshed = await _authService.handleUnauthorized();
      
      if (refreshed) {
        // Retry the request with new token
        return _makeRequest(
          method: method,
          endpoint: endpoint,
          queryParams: queryParams,
          body: body,
          parser: parser,
          retryCount: retryCount + 1,
        );
      }
      
      return ApiResponse.error('Authentication failed - please sign in again');
    }
    
    // Rate Limited (429)
    if (statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      final message = retryAfter != null
          ? 'Rate limit exceeded - retry after $retryAfter seconds'
          : 'Rate limit exceeded - please try again later';
      
      debugPrint('⚠️ $message');
      return ApiResponse.error(message);
    }
    
    // Server Error (500+)
    if (statusCode >= 500) {
      debugPrint('❌ Server error: $statusCode');
      debugPrint('❌ Response body: ${response.body}');

      // Try to get detailed error from response
      try {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['error'] as String? ?? 'Server error';
        debugPrint('❌ Server error message: $errorMessage');
        return ApiResponse.error(errorMessage);
      } catch (e) {
        return ApiResponse.error('Server error - please try again later');
      }
    }
    
    // Client Error (400-499)
    try {
      final errorData = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMessage = errorData['error'] as String? ?? 
                          errorData['message'] as String? ??
                          'Request failed';
      
      debugPrint('❌ API error: $errorMessage');
      return ApiResponse.error(errorMessage);
    } catch (e) {
      return ApiResponse.error('Request failed with status: $statusCode');
    }
  }

  Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    var url = '$_baseUrl$endpoint';
    
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url = '$url?$queryString';
    }
    
    return Uri.parse(url);
  }
}

/// API Response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  
  ApiResponse._({
    required this.success,
    this.data,
    this.error,
  });
  
  factory ApiResponse.success(T data) {
    return ApiResponse._(
      success: true,
      data: data,
    );
  }
  
  factory ApiResponse.error(String error) {
    return ApiResponse._(
      success: false,
      error: error,
    );
  }
}
