import 'package:hive/hive.dart';

part 'steps_data.g.dart';

/// Represents a single day's step data for the Steps Together feature.
/// Stores both user and partner steps, sync timestamps, and claim status.
@HiveType(typeId: 27)
class StepsDay extends HiveObject {
  /// Date key in format "2024-11-27"
  @HiveField(0)
  String dateKey;

  /// Current user's step count for this day
  @HiveField(1)
  int userSteps;

  /// Partner's step count for this day
  @HiveField(2)
  int partnerSteps;

  /// When the user's steps were last synced
  @HiveField(3)
  DateTime lastSync;

  /// When the partner's steps were last synced (null if not yet synced)
  @HiveField(4)
  DateTime? partnerLastSync;

  /// Whether the reward for this day has been claimed
  @HiveField(5, defaultValue: false)
  bool claimed;

  /// The LP earned for this day (calculated when both have synced)
  @HiveField(6, defaultValue: 0)
  int earnedLP;

  /// Timestamp when the reward expires (48 hours after day ends)
  @HiveField(7)
  DateTime? claimExpiresAt;

  StepsDay({
    required this.dateKey,
    this.userSteps = 0,
    this.partnerSteps = 0,
    required this.lastSync,
    this.partnerLastSync,
    this.claimed = false,
    this.earnedLP = 0,
    this.claimExpiresAt,
  });

  /// Combined steps from both partners
  int get combinedSteps => userSteps + partnerSteps;

  /// Progress toward the 20K goal (0.0 to 1.0+)
  double get progress => combinedSteps / 20000;

  /// Whether this day's reward can be claimed
  bool get canClaim {
    if (claimed) return false;
    if (claimExpiresAt == null) return false;
    if (DateTime.now().isAfter(claimExpiresAt!)) return false;
    // Both must have synced
    if (partnerLastSync == null) return false;
    // Must have at least 10K combined steps to earn LP
    if (combinedSteps < 10000) return false;
    return true;
  }

  /// Whether this day's reward has expired
  bool get isExpired {
    if (claimExpiresAt == null) return false;
    return DateTime.now().isAfter(claimExpiresAt!);
  }

  /// Calculate LP earned based on combined steps
  static int calculateLP(int combinedSteps) {
    if (combinedSteps < 10000) return 0;
    if (combinedSteps >= 20000) return 30;

    // +3 LP per 2000 steps above 10000
    int extraSteps = combinedSteps - 10000;
    int extraTiers = extraSteps ~/ 2000;
    return 15 + (extraTiers * 3);
  }

  /// Get the tier name for display
  static String getTierName(int combinedSteps) {
    if (combinedSteps >= 20000) return "20K";
    if (combinedSteps >= 18000) return "18K";
    if (combinedSteps >= 16000) return "16K";
    if (combinedSteps >= 14000) return "14K";
    if (combinedSteps >= 12000) return "12K";
    if (combinedSteps >= 10000) return "10K";
    return "Below 10K";
  }

  @override
  String toString() {
    return 'StepsDay(dateKey: $dateKey, userSteps: $userSteps, partnerSteps: $partnerSteps, '
        'combined: $combinedSteps, claimed: $claimed, earnedLP: $earnedLP)';
  }
}

/// Tracks the HealthKit connection status for the Steps Together feature.
@HiveType(typeId: 28)
class StepsConnection extends HiveObject {
  /// Whether the current user has connected Apple Health
  @HiveField(0, defaultValue: false)
  bool isConnected;

  /// When the user connected Apple Health
  @HiveField(1)
  DateTime? connectedAt;

  /// Whether the partner has connected Apple Health
  @HiveField(2, defaultValue: false)
  bool partnerConnected;

  /// When the partner connected Apple Health
  @HiveField(3)
  DateTime? partnerConnectedAt;

  /// Whether HealthKit permission was denied (to avoid re-prompting)
  @HiveField(4, defaultValue: false)
  bool permissionDenied;

  StepsConnection({
    this.isConnected = false,
    this.connectedAt,
    this.partnerConnected = false,
    this.partnerConnectedAt,
    this.permissionDenied = false,
  });

  /// Whether both partners are connected
  bool get bothConnected => isConnected && partnerConnected;

  /// Whether either partner is connected
  bool get eitherConnected => isConnected || partnerConnected;

  @override
  String toString() {
    return 'StepsConnection(isConnected: $isConnected, partnerConnected: $partnerConnected, '
        'bothConnected: $bothConnected)';
  }
}
