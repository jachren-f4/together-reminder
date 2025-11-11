import 'package:hive/hive.dart';

part 'badge.g.dart';

@HiveType(typeId: 6)
class Badge extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name; // 'Perfect Sync', 'Active Duo', etc.

  @HiveField(2)
  late String emoji;

  @HiveField(3)
  late String description;

  @HiveField(4)
  late DateTime earnedAt;

  @HiveField(5)
  late String category; // 'quiz', 'health', 'poke', 'challenge'

  Badge({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.earnedAt,
    required this.category,
  });
}
