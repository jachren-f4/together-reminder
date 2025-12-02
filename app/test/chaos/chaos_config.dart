/// Chaos testing configuration for Linked game
///
/// Provides configurable fault injection for testing edge cases:
/// - Random delays
/// - Simulated errors
/// - Response reordering
/// - Race condition triggers
library;

import 'dart:math';

/// Configuration for chaos testing parameters
class ChaosConfig {
  /// Minimum artificial delay to add to API calls
  final Duration minDelay;

  /// Maximum artificial delay to add to API calls
  final Duration maxDelay;

  /// Probability (0.0 - 1.0) that a request will fail
  final double errorRate;

  /// Whether to enable race condition simulation
  final bool enableRaceConditions;

  /// Whether to reorder responses (deliver out-of-sequence)
  final bool enableResponseReordering;

  /// Whether to simulate network timeouts
  final bool enableTimeouts;

  /// Probability of timeout when enabled
  final double timeoutRate;

  /// Whether chaos is enabled at all
  final bool enabled;

  const ChaosConfig({
    this.minDelay = Duration.zero,
    this.maxDelay = Duration.zero,
    this.errorRate = 0.0,
    this.enableRaceConditions = false,
    this.enableResponseReordering = false,
    this.enableTimeouts = false,
    this.timeoutRate = 0.0,
    this.enabled = false,
  });

  /// No chaos - normal operation
  static const disabled = ChaosConfig();

  /// Light chaos for basic testing
  static const light = ChaosConfig(
    enabled: true,
    minDelay: Duration(milliseconds: 50),
    maxDelay: Duration(milliseconds: 200),
    errorRate: 0.05, // 5% error rate
  );

  /// Medium chaos for stress testing
  static const medium = ChaosConfig(
    enabled: true,
    minDelay: Duration(milliseconds: 100),
    maxDelay: Duration(milliseconds: 500),
    errorRate: 0.10, // 10% error rate
    enableRaceConditions: true,
  );

  /// Heavy chaos for resilience testing
  static const heavy = ChaosConfig(
    enabled: true,
    minDelay: Duration(milliseconds: 200),
    maxDelay: Duration(milliseconds: 1000),
    errorRate: 0.20, // 20% error rate
    enableRaceConditions: true,
    enableResponseReordering: true,
    enableTimeouts: true,
    timeoutRate: 0.10, // 10% timeout rate
  );

  /// Get a random delay within the configured range
  Duration getRandomDelay() {
    if (!enabled || maxDelay == Duration.zero) {
      return Duration.zero;
    }

    final random = Random();
    final minMs = minDelay.inMilliseconds;
    final maxMs = maxDelay.inMilliseconds;
    final delayMs = minMs + random.nextInt(maxMs - minMs + 1);
    return Duration(milliseconds: delayMs);
  }

  /// Determine if this request should fail
  bool shouldFail() {
    if (!enabled || errorRate == 0.0) {
      return false;
    }
    return Random().nextDouble() < errorRate;
  }

  /// Determine if this request should timeout
  bool shouldTimeout() {
    if (!enabled || !enableTimeouts || timeoutRate == 0.0) {
      return false;
    }
    return Random().nextDouble() < timeoutRate;
  }
}

/// Chaos error types that can be injected
enum ChaosErrorType {
  networkError,
  timeout,
  serverError,
  invalidResponse,
  connectionReset,
}

/// Exception thrown by chaos injection
class ChaosException implements Exception {
  final ChaosErrorType type;
  final String message;

  const ChaosException(this.type, this.message);

  @override
  String toString() => 'ChaosException($type): $message';
}

/// Response wrapper that can be delayed or reordered
class ChaosResponse<T> {
  final T data;
  final int sequenceNumber;
  final DateTime requestTime;
  final Duration artificialDelay;

  ChaosResponse({
    required this.data,
    required this.sequenceNumber,
    required this.requestTime,
    required this.artificialDelay,
  });

  bool get isStale => DateTime.now().difference(requestTime) > const Duration(seconds: 5);
}

/// Response reordering queue for simulating out-of-order delivery
class ResponseReorderQueue<T> {
  final List<ChaosResponse<T>> _pending = [];
  int _nextSequence = 0;

  /// Add a response to the queue
  void add(T data, Duration delay) {
    _pending.add(ChaosResponse(
      data: data,
      sequenceNumber: _nextSequence++,
      requestTime: DateTime.now(),
      artificialDelay: delay,
    ));
  }

  /// Get responses in potentially reordered sequence
  List<T> getReorderedResponses() {
    if (_pending.isEmpty) return [];

    // Shuffle to simulate network reordering
    _pending.shuffle();

    final results = _pending.map((r) => r.data).toList();
    _pending.clear();
    return results;
  }

  /// Get responses in correct order
  List<T> getOrderedResponses() {
    if (_pending.isEmpty) return [];

    _pending.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    final results = _pending.map((r) => r.data).toList();
    _pending.clear();
    return results;
  }
}
