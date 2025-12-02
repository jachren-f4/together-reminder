/// Test configuration for Linked game integration tests
///
/// Provides test user IDs, couple ID, and configurable parameters for tests.
library;

/// Test configuration constants
class LinkedTestConfig {
  // Test users (from DevConfig - matches real database)
  static const String testUserId = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28'; // TestiY (user1_id)
  static const String partnerUserId = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a'; // Jokke (user2_id)

  // Dev test couple ID (must exist in database)
  static const String coupleId = '11111111-1111-1111-1111-111111111111';

  // API configuration
  static const String apiBaseUrl = 'http://localhost:3000';

  // Test timing configuration
  /// Use 100ms poll interval for tests (not 10s production value)
  static const Duration pollInterval = Duration(milliseconds: 100);

  /// Timeout for API calls during tests
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Timeout for waiting for partner actions (simulated)
  static const Duration partnerActionTimeout = Duration(seconds: 5);

  // Scoring constants (must match api/lib/lp/config.ts)
  static const int pointsPerLetter = 10;
  static const int lpRewardOnCompletion = 30;
}

/// State machine states for tracking game flow
enum LinkedGameTestState {
  home,          // User on home screen
  loading,       // Fetching match from server
  myTurn,        // User can place letters
  submitting,    // API call in progress
  animating,     // Showing results animation
  partnerTurn,   // Waiting for partner
  completing,    // Syncing LP
  completed,     // On completion screen
  error,         // Error occurred
}

/// Helper class to track state transitions during tests
class StateTransitionTracker {
  final List<LinkedGameTestState> _transitions = [];

  void recordTransition(LinkedGameTestState state) {
    _transitions.add(state);
  }

  List<LinkedGameTestState> get transitions => List.unmodifiable(_transitions);

  LinkedGameTestState? get currentState => _transitions.isNotEmpty ? _transitions.last : null;

  bool hasVisitedState(LinkedGameTestState state) => _transitions.contains(state);

  void clear() => _transitions.clear();

  @override
  String toString() => _transitions.map((s) => s.name).join(' -> ');
}
