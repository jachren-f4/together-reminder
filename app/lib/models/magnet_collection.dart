import 'package:hive/hive.dart';

part 'magnet_collection.g.dart';

/// Magnet Collection state for a couple
///
/// Stores the current magnet progress and LP tracking.
/// Magnets are calculated from total LP (not stored individually).
@HiveType(typeId: 32)
class MagnetCollection extends HiveObject {
  /// Number of magnets unlocked (0-30)
  @HiveField(0)
  int unlockedCount;

  /// Next magnet ID to unlock (1-30, null if all unlocked)
  @HiveField(1)
  int? nextMagnetId;

  /// Current total LP
  @HiveField(2)
  int currentLp;

  /// LP required for next magnet
  @HiveField(3)
  int lpForNextMagnet;

  /// LP progress toward next magnet
  @HiveField(4)
  int lpProgressToNext;

  /// Progress percentage (0-100)
  @HiveField(5)
  int progressPercent;

  /// Total magnets in collection (30)
  @HiveField(6, defaultValue: 30)
  int totalMagnets;

  /// Whether all magnets are unlocked
  @HiveField(7, defaultValue: false)
  bool allUnlocked;

  /// Last sync timestamp
  @HiveField(8)
  DateTime? lastSyncedAt;

  MagnetCollection({
    this.unlockedCount = 0,
    this.nextMagnetId = 1,
    this.currentLp = 0,
    this.lpForNextMagnet = 600,
    this.lpProgressToNext = 0,
    this.progressPercent = 0,
    this.totalMagnets = 30,
    this.allUnlocked = false,
    this.lastSyncedAt,
  });

  factory MagnetCollection.fromJson(Map<String, dynamic> json) {
    return MagnetCollection(
      unlockedCount: json['unlockedCount'] as int? ?? 0,
      nextMagnetId: json['nextMagnetId'] as int?,
      currentLp: json['currentLp'] as int? ?? 0,
      lpForNextMagnet: json['lpForNextMagnet'] as int? ?? 600,
      lpProgressToNext: json['lpProgressToNext'] as int? ?? 0,
      progressPercent: json['progressPercent'] as int? ?? 0,
      totalMagnets: json['totalMagnets'] as int? ?? 30,
      allUnlocked: json['allUnlocked'] as bool? ?? false,
      lastSyncedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unlockedCount': unlockedCount,
      'nextMagnetId': nextMagnetId,
      'currentLp': currentLp,
      'lpForNextMagnet': lpForNextMagnet,
      'lpProgressToNext': lpProgressToNext,
      'progressPercent': progressPercent,
      'totalMagnets': totalMagnets,
      'allUnlocked': allUnlocked,
    };
  }

  /// Magnet configuration - 30 real-world romantic destinations
  /// Format: (name, assetFilename)
  static const List<(String, String)> _magnetConfig = [
    // US Cities (1-7)
    ('Austin', 'austin.jpg'),
    ('Los Angeles', 'los_angeles.jpg'),
    ('San Francisco', 'san_francisco.jpg'),
    ('Chicago', 'chicago.jpg'),
    ('Miami', 'miami.jpg'),
    ('New Orleans', 'new_orleans.jpg'),
    ('New York', 'new_york.jpg'),
    // Northern Europe (8-14)
    ('London', 'london.jpg'),
    ('Paris', 'paris.png'),
    ('Amsterdam', 'amsterdam.jpg'),
    ('Berlin', 'berlin.jpg'),
    ('Copenhagen', 'copenhagen.jpg'),
    ('Stockholm', 'stockholm.jpg'),
    ('Oslo', 'oslo.jpg'),
    // Southern Europe (15-21)
    ('Barcelona', 'barcelona.jpg'),
    ('Naples', 'naples.png'),
    ('Rome', 'rome.jpg'),
    ('Vienna', 'vienna.jpg'),
    ('Prague', 'prague.jpg'),
    ('Lisbon', 'lisbon.jpg'),
    ('Athens', 'athens.jpg'),
    // Nordic & Mediterranean Dreams (22-25)
    ('Helsinki', 'helsinki.jpg'),
    ('Reykjavik', 'reykjavik.jpg'),
    ('Santorini', 'santorini.jpg'),
    ('Dubrovnik', 'dubrovnik.jpg'),
    // Exotic World (26-30)
    ('Tokyo', 'tokyo.jpg'),
    ('Marrakech', 'marrakech.jpg'),
    ('Cape Town', 'cape_town.jpg'),
    ('Buenos Aires', 'buenos_aires.jpg'),
    ('Havana', 'havana.jpg'),
  ];

  /// Get asset path for a magnet image
  static String getMagnetAssetPath(int magnetId) {
    if (magnetId < 1 || magnetId > _magnetConfig.length) {
      return 'assets/brands/us2/images/magnets/placeholder.png';
    }

    final (_, assetFilename) = _magnetConfig[magnetId - 1];
    return 'assets/brands/us2/images/magnets/$assetFilename';
  }

  /// Get destination name for a magnet
  static String getMagnetName(int magnetId) {
    if (magnetId < 1 || magnetId > _magnetConfig.length) {
      return 'Unknown';
    }

    final (name, _) = _magnetConfig[magnetId - 1];
    return name;
  }
}
