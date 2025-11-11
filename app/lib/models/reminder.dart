import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String type; // 'sent' or 'received'

  @HiveField(2)
  late String from;

  @HiveField(3)
  late String to;

  @HiveField(4)
  late String text;

  @HiveField(5)
  late DateTime timestamp;

  @HiveField(6)
  late DateTime scheduledFor;

  @HiveField(7)
  late String status; // 'pending', 'done', 'snoozed'

  @HiveField(8)
  DateTime? snoozedUntil;

  @HiveField(9)
  late DateTime createdAt;

  @HiveField(10, defaultValue: 'reminder')
  String category; // 'reminder' or 'poke'

  Reminder({
    required this.id,
    required this.type,
    required this.from,
    required this.to,
    required this.text,
    required this.timestamp,
    required this.scheduledFor,
    required this.status,
    this.snoozedUntil,
    required this.createdAt,
    this.category = 'reminder', // default to reminder for backward compatibility
  });

  // Helper methods
  bool get isPoke => category == 'poke';
  bool get isReminder => category == 'reminder';
}
