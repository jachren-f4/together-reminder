import 'package:hive/hive.dart';

part 'memory_flip.g.dart';

@HiveType(typeId: 10)
class MemoryPuzzle extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late DateTime createdAt;

  @HiveField(2)
  late DateTime expiresAt;

  @HiveField(3)
  late List<MemoryCard> cards;

  @HiveField(4)
  late String status; // 'active' or 'completed'

  @HiveField(5)
  late int totalPairs;

  @HiveField(6)
  late int matchedPairs;

  @HiveField(7)
  DateTime? completedAt;

  @HiveField(8)
  late String completionQuote;

  MemoryPuzzle({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    required this.cards,
    required this.status,
    required this.totalPairs,
    this.matchedPairs = 0,
    this.completedAt,
    required this.completionQuote,
  });

  // Helper methods
  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
  double get progressPercentage => totalPairs > 0 ? (matchedPairs / totalPairs) : 0.0;
}

@HiveType(typeId: 11)
class MemoryCard extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String puzzleId;

  @HiveField(2)
  late int position;

  @HiveField(3)
  late String emoji;

  @HiveField(4)
  late String pairId;

  @HiveField(5)
  late String status; // 'hidden' or 'matched'

  @HiveField(6)
  String? matchedBy;

  @HiveField(7)
  DateTime? matchedAt;

  @HiveField(8)
  late String revealQuote;

  MemoryCard({
    required this.id,
    required this.puzzleId,
    required this.position,
    required this.emoji,
    required this.pairId,
    this.status = 'hidden',
    this.matchedBy,
    this.matchedAt,
    required this.revealQuote,
  });

  // Helper methods
  bool get isHidden => status == 'hidden';
  bool get isMatched => status == 'matched';
}

@HiveType(typeId: 12)
class MemoryFlipAllowance extends HiveObject {
  @HiveField(0)
  late String userId;

  @HiveField(1)
  late int flipsRemaining;

  @HiveField(2)
  late DateTime resetsAt;

  @HiveField(3)
  late int totalFlipsToday;

  @HiveField(4)
  late DateTime lastFlipAt;

  MemoryFlipAllowance({
    required this.userId,
    required this.flipsRemaining,
    required this.resetsAt,
    this.totalFlipsToday = 0,
    required this.lastFlipAt,
  });

  // Helper methods
  bool get canFlip => flipsRemaining >= 2; // Need 2 flips for one turn
  bool get needsReset => DateTime.now().isAfter(resetsAt);
}
