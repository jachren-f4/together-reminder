import 'package:hive/hive.dart';

part 'cooldown_status.g.dart';

/// Activity types that have cooldowns
enum ActivityType {
  classicQuiz,
  affirmationQuiz,
  youOrMe,
  linked,
  wordsearch,
}

/// Cooldown status for a single activity type
@HiveType(typeId: 33)
class CooldownStatus extends HiveObject {
  /// Whether the user can play this activity
  @HiveField(0)
  bool canPlay;

  /// Remaining plays in current batch (0, 1, or 2)
  @HiveField(1)
  int remainingInBatch;

  /// When the cooldown ends (null if not on cooldown)
  @HiveField(2)
  DateTime? cooldownEndsAt;

  /// Remaining milliseconds until cooldown ends
  @HiveField(3)
  int? cooldownRemainingMs;

  CooldownStatus({
    this.canPlay = true,
    this.remainingInBatch = 2,
    this.cooldownEndsAt,
    this.cooldownRemainingMs,
  });

  factory CooldownStatus.fromJson(Map<String, dynamic> json) {
    return CooldownStatus(
      canPlay: json['canPlay'] as bool? ?? true,
      remainingInBatch: json['remainingInBatch'] as int? ?? 2,
      cooldownEndsAt: json['cooldownEndsAt'] != null
          ? DateTime.parse(json['cooldownEndsAt'] as String)
          : null,
      cooldownRemainingMs: json['cooldownRemainingMs'] as int?,
    );
  }

  /// Check if currently on cooldown (recalculates from cooldownEndsAt)
  bool get isOnCooldown {
    if (cooldownEndsAt == null) return false;
    return DateTime.now().isBefore(cooldownEndsAt!);
  }

  /// Get remaining time as Duration
  Duration? get remainingDuration {
    if (cooldownEndsAt == null) return null;
    final remaining = cooldownEndsAt!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Format remaining time as string (e.g., "6h 24m")
  String? get formattedRemaining {
    final duration = remainingDuration;
    if (duration == null) return null;

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Soon';
    }
  }
}

/// Collection of cooldown statuses for all activity types
@HiveType(typeId: 34)
class CooldownCollection extends HiveObject {
  @HiveField(0)
  CooldownStatus classicQuiz;

  @HiveField(1)
  CooldownStatus affirmationQuiz;

  @HiveField(2)
  CooldownStatus youOrMe;

  @HiveField(3)
  CooldownStatus linked;

  @HiveField(4)
  CooldownStatus wordsearch;

  @HiveField(5)
  DateTime? lastSyncedAt;

  CooldownCollection({
    CooldownStatus? classicQuiz,
    CooldownStatus? affirmationQuiz,
    CooldownStatus? youOrMe,
    CooldownStatus? linked,
    CooldownStatus? wordsearch,
    this.lastSyncedAt,
  })  : classicQuiz = classicQuiz ?? CooldownStatus(),
        affirmationQuiz = affirmationQuiz ?? CooldownStatus(),
        youOrMe = youOrMe ?? CooldownStatus(),
        linked = linked ?? CooldownStatus(),
        wordsearch = wordsearch ?? CooldownStatus();

  factory CooldownCollection.fromJson(Map<String, dynamic> json) {
    final cooldowns = json['cooldowns'] as Map<String, dynamic>? ?? {};

    return CooldownCollection(
      classicQuiz: cooldowns['classic_quiz'] != null
          ? CooldownStatus.fromJson(cooldowns['classic_quiz'] as Map<String, dynamic>)
          : CooldownStatus(),
      affirmationQuiz: cooldowns['affirmation_quiz'] != null
          ? CooldownStatus.fromJson(cooldowns['affirmation_quiz'] as Map<String, dynamic>)
          : CooldownStatus(),
      youOrMe: cooldowns['you_or_me'] != null
          ? CooldownStatus.fromJson(cooldowns['you_or_me'] as Map<String, dynamic>)
          : CooldownStatus(),
      linked: cooldowns['linked'] != null
          ? CooldownStatus.fromJson(cooldowns['linked'] as Map<String, dynamic>)
          : CooldownStatus(),
      wordsearch: cooldowns['wordsearch'] != null
          ? CooldownStatus.fromJson(cooldowns['wordsearch'] as Map<String, dynamic>)
          : CooldownStatus(),
      lastSyncedAt: DateTime.now(),
    );
  }

  /// Get cooldown status by activity type
  CooldownStatus getStatus(ActivityType type) {
    switch (type) {
      case ActivityType.classicQuiz:
        return classicQuiz;
      case ActivityType.affirmationQuiz:
        return affirmationQuiz;
      case ActivityType.youOrMe:
        return youOrMe;
      case ActivityType.linked:
        return linked;
      case ActivityType.wordsearch:
        return wordsearch;
    }
  }

  /// Check if any activity is on cooldown
  bool get anyOnCooldown =>
      classicQuiz.isOnCooldown ||
      affirmationQuiz.isOnCooldown ||
      youOrMe.isOnCooldown ||
      linked.isOnCooldown ||
      wordsearch.isOnCooldown;

  /// Check if all activities are on cooldown
  bool get allOnCooldown =>
      classicQuiz.isOnCooldown &&
      affirmationQuiz.isOnCooldown &&
      youOrMe.isOnCooldown &&
      linked.isOnCooldown &&
      wordsearch.isOnCooldown;
}
