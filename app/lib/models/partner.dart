import 'package:hive/hive.dart';

part 'partner.g.dart';

@HiveType(typeId: 1)
class Partner extends HiveObject {
  @HiveField(0)
  late String name;

  @HiveField(1)
  late String pushToken;

  @HiveField(2)
  late DateTime pairedAt;

  @HiveField(3)
  String? avatarEmoji;

  /// Partner's user ID (UUID) - used for userCompletions tracking
  /// Added to fix mismatch where userCompletions used UUID for current user
  /// but pushToken for partner, causing "YOUR TURN" display bug
  @HiveField(4, defaultValue: '')
  String id;

  Partner({
    required this.name,
    required this.pushToken,
    required this.pairedAt,
    this.avatarEmoji,
    this.id = '',
  });
}
