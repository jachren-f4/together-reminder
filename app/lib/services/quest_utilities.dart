/// Shared utility functions for quest-related services
///
/// This class provides common utilities used by quest generation,
/// synchronization, and management services. All methods are static
/// and stateless to avoid circular dependencies.
class QuestUtilities {
  QuestUtilities._(); // Private constructor to prevent instantiation

  /// Get today's date key in YYYY-MM-DD format
  ///
  /// Used for organizing quests by date in Firebase RTDB and local storage.
  /// Example: "2025-01-14"
  static String getTodayDateKey() {
    final today = DateTime.now();
    return getDateKey(today);
  }

  /// Get date key for a specific date in YYYY-MM-DD format
  ///
  /// Used for organizing quests by date in Firebase RTDB and local storage.
  /// Example: "2025-01-14"
  static String getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Generate a consistent couple ID from two user IDs
  ///
  /// Always sorts user IDs alphabetically to ensure both users
  /// generate the same couple ID regardless of call order.
  ///
  /// Example:
  /// ```dart
  /// generateCoupleId("alice", "bob") == "alice_bob"
  /// generateCoupleId("bob", "alice") == "alice_bob" // Same result
  /// ```
  static String generateCoupleId(String userId1, String userId2) {
    final userIds = [userId1, userId2]..sort();
    return '${userIds[0]}_${userIds[1]}';
  }
}
