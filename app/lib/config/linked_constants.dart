/// Linked game configuration constants.
///
/// These constants define Linked game behavior that needs to be
/// consistent between Flutter client and API server.
///
/// IMPORTANT: Keep in sync with api/lib/linked/config.ts
class LinkedConstants {
  /// Number of letters in the rack (5, 6, or 7)
  static const int rackSize = 5;

  /// Number of hints at the start of the game
  static const int startingHints = 2;

  LinkedConstants._();
}
