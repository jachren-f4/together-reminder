/// Navigation guard to prevent double-tap issues when opening screens.
///
/// Usage:
/// ```dart
/// onTap: () => NavigationGuard.navigate(context, () {
///   Navigator.push(context, MaterialPageRoute(builder: (_) => MyScreen()));
/// }),
/// ```
class NavigationGuard {
  static bool _isNavigating = false;
  static const _cooldownDuration = Duration(milliseconds: 500);

  /// Execute a navigation action with double-tap protection.
  /// Returns true if navigation was allowed, false if blocked.
  static bool navigate(dynamic context, void Function() action) {
    if (_isNavigating) {
      return false;
    }

    _isNavigating = true;

    // Execute the navigation action
    action();

    // Reset after cooldown
    Future.delayed(_cooldownDuration, () {
      _isNavigating = false;
    });

    return true;
  }

  /// Async version for navigation actions that need awaiting.
  static Future<bool> navigateAsync(dynamic context, Future<void> Function() action) async {
    if (_isNavigating) {
      return false;
    }

    _isNavigating = true;

    try {
      await action();
    } finally {
      // Reset after cooldown
      Future.delayed(_cooldownDuration, () {
        _isNavigating = false;
      });
    }

    return true;
  }

  /// Reset the navigation guard (useful for testing or error recovery)
  static void reset() {
    _isNavigating = false;
  }
}
