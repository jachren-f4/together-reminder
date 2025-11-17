import '../models/quiz_expansion.dart';
import 'storage_service.dart';
import '../utils/logger.dart';

/// Service for tracking general activity streaks across all app activities
///
/// Counts as "active day": any quest completion, reminder sent, poke sent, or game played
/// Resets at midnight local time with 2-hour grace period
class GeneralActivityStreakService {
  static const String _streakType = 'general_activity';
  final StorageService _storage = StorageService();

  /// Update streak when any activity is completed
  ///
  /// Call this after:
  /// - Completing any daily quest
  /// - Sending a reminder
  /// - Sending a poke
  /// - Completing Word Ladder game
  /// - Completing Memory Flip game
  /// - Completing Daily Pulse
  Future<void> recordActivity() async {
    final streak = _storage.getStreak(_streakType);
    final now = DateTime.now();

    if (streak != null && _isSameOrConsecutiveDay(streak.lastCompletedDate, now)) {
      // Continue or maintain streak
      if (!_isSameDay(streak.lastCompletedDate, now)) {
        // New day, increment streak
        streak.currentStreak++;
        if (streak.currentStreak > streak.longestStreak) {
          streak.longestStreak = streak.currentStreak;
        }
        Logger.success('Streak increased to ${streak.currentStreak} days! 🔥', service: 'streak');
      } else {
        Logger.debug('Activity recorded, streak maintained at ${streak.currentStreak} days', service: 'streak');
      }

      streak.lastCompletedDate = now;
      streak.totalCompleted++;
      await _storage.updateStreak(streak);
    } else {
      // Reset or create new streak
      final wasReset = streak != null;
      final newStreak = QuizStreak(
        type: _streakType,
        currentStreak: 1,
        longestStreak: streak?.longestStreak ?? 1,
        lastCompletedDate: now,
        totalCompleted: (streak?.totalCompleted ?? 0) + 1,
      );
      await _storage.saveStreak(newStreak);

      if (wasReset) {
        Logger.warn('Streak broken! Reset to 1 day', service: 'streak');
      } else {
        Logger.info('Streak started: 1 day', service: 'streak');
      }
    }
  }

  /// Get current streak count
  ///
  /// Returns 0 if no streak or if streak was broken (last activity was 2+ days ago)
  int getCurrentStreak() {
    final streak = _storage.getStreak(_streakType);
    if (streak == null) return 0;

    // Check if streak is still valid (not broken by missing yesterday)
    if (_isStreakBroken(streak.lastCompletedDate)) {
      Logger.debug('Streak is broken (last activity ${streak.lastCompletedDate})', service: 'streak');
      return 0;
    }

    return streak.currentStreak;
  }

  /// Get longest streak ever achieved
  int getLongestStreak() {
    final streak = _storage.getStreak(_streakType);
    return streak?.longestStreak ?? 0;
  }

  /// Get total number of active days (all time)
  int getTotalActiveDays() {
    final streak = _storage.getStreak(_streakType);
    return streak?.totalCompleted ?? 0;
  }

  /// Check if streak is broken (last activity was 2+ days ago)
  bool _isStreakBroken(DateTime lastDate) {
    final now = DateTime.now();
    final lastNormalized = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final yesterday = DateTime(now.year, now.month, now.day).subtract(Duration(days: 1));

    // Streak is broken if last activity was before yesterday
    return lastNormalized.isBefore(yesterday);
  }

  /// Check if dates are same day or consecutive (with grace period)
  ///
  /// Grace period: Activities between 12:00 AM - 2:00 AM count as previous day
  bool _isSameOrConsecutiveDay(DateTime lastDate, DateTime currentDate) {
    final lastNormalized = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final currentNormalized = DateTime(currentDate.year, currentDate.month, currentDate.day);

    // Same day
    if (lastNormalized == currentNormalized) return true;

    // Yesterday (consecutive)
    final yesterday = currentNormalized.subtract(Duration(days: 1));
    if (lastNormalized == yesterday) return true;

    // Grace period: 12 AM - 2 AM counts as previous day
    if (currentDate.hour < 2) {
      final gracePeriodYesterday = currentNormalized.subtract(Duration(days: 1));
      if (lastNormalized == gracePeriodYesterday) {
        Logger.debug('Grace period applied (${currentDate.hour}:${currentDate.minute} AM)', service: 'streak');
        return true;
      }
    }

    return false;
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Get last activity date (for debugging)
  DateTime? getLastActivityDate() {
    final streak = _storage.getStreak(_streakType);
    return streak?.lastCompletedDate;
  }
}
