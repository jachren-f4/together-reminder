import 'package:hive/hive.dart';

part 'love_point_transaction.g.dart';

@HiveType(typeId: 3)
class LovePointTransaction extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late int amount; // Can be positive or negative

  @HiveField(2)
  late String reason; // 'reminder_sent', 'reminder_done', 'mutual_poke', etc.

  @HiveField(3)
  late DateTime timestamp;

  @HiveField(4)
  String? relatedId; // reminderId or pokeId for reference

  @HiveField(5, defaultValue: 1)
  int multiplier; // For weekly challenge 2x, default 1x

  LovePointTransaction({
    required this.id,
    required this.amount,
    required this.reason,
    required this.timestamp,
    this.relatedId,
    this.multiplier = 1,
  });

  // Helper to get display text
  String get displayReason {
    switch (reason) {
      case 'reminder_sent':
        return 'Sent reminder';
      case 'reminder_done':
        return 'Completed reminder';
      case 'mutual_poke':
        return 'Mutual poke';
      case 'poke_back':
        return 'Poke back';
      case 'quiz_completed':
        return 'Couple quiz';
      case 'weekly_challenge_bonus':
        return 'Weekly challenge';
      case 'memory_flip_match':
        return 'Memory match';
      case 'memory_flip_completed':
        return 'Puzzle complete';
      default:
        return reason;
    }
  }
}
