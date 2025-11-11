import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String pushToken;

  @HiveField(2)
  late DateTime createdAt;

  @HiveField(3)
  String? name;

  // Love Points & Gamification fields
  @HiveField(4, defaultValue: 0)
  int lovePoints;

  @HiveField(5, defaultValue: 1)
  int arenaTier; // 1-5 (Cabin to Castle)

  @HiveField(6, defaultValue: 0)
  int floor; // Floor protection threshold

  @HiveField(7)
  DateTime? lastActivityDate;

  User({
    required this.id,
    required this.pushToken,
    required this.createdAt,
    this.name,
    this.lovePoints = 0,
    this.arenaTier = 1,
    this.floor = 0,
    this.lastActivityDate,
  });
}
