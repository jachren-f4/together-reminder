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

  Partner({
    required this.name,
    required this.pushToken,
    required this.pairedAt,
    this.avatarEmoji,
  });
}
