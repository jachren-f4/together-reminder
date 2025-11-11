import '../models/arena.dart';
import 'storage_service.dart';

/// Service for managing arena progression and Love Points
class ArenaService {
  final StorageService _storage = StorageService();

  /// Get the current arena based on user's Love Points
  Arena getCurrentArena() {
    final lovePoints = getLovePoints();
    return Arena.getCurrentArena(lovePoints);
  }

  /// Get the next arena to unlock, or null if at max tier
  Arena? getNextArena() {
    final lovePoints = getLovePoints();
    return Arena.getNextArena(lovePoints);
  }

  /// Get progress percentage in current arena (0.0 to 1.0)
  double getCurrentProgress() {
    final lovePoints = getLovePoints();
    final currentArena = getCurrentArena();
    return currentArena.getProgress(lovePoints);
  }

  /// Get Love Points remaining until next arena
  int getLovePointsUntilNext() {
    final lovePoints = getLovePoints();
    final nextArena = getNextArena();
    if (nextArena == null) return 0; // Already at max tier
    return nextArena.minLP - lovePoints;
  }

  /// Get current Love Points
  int getLovePoints() {
    final user = _storage.getUser();
    if (user == null) return 0;
    return user.lovePoints;
  }

  /// Award Love Points for completing an activity
  Future<bool> awardLovePoints(int points, String reason) async {
    final user = _storage.getUser();
    if (user == null) return false;

    final oldLP = user.lovePoints;
    user.lovePoints += points;

    // Update floor protection if reaching new arena
    final newArena = getCurrentArena();
    if (user.lovePoints >= newArena.minLP && newArena.minLP > user.floor) {
      user.floor = newArena.minLP;
    }

    await user.save(); // Save to Hive

    print('🏆 Awarded $points LP for: $reason (Total: ${user.lovePoints})');

    // Check if unlocked new arena
    return didUnlockNewArena(oldLP, user.lovePoints);
  }

  /// Check if user just unlocked a new arena
  bool didUnlockNewArena(int oldLP, int newLP) {
    final oldArena = Arena.getCurrentArena(oldLP);
    final newArena = Arena.getCurrentArena(newLP);
    return oldArena.type != newArena.type;
  }

  /// Get formatted progress string for current arena
  String getProgressString() {
    final lovePoints = getLovePoints();
    final currentArena = getCurrentArena();
    return currentArena.getProgressString(lovePoints);
  }
}
