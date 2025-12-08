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

  /// Create Partner from API response
  ///
  /// Used when deserializing partner data from server endpoints.
  /// [json] should contain: id, name, email (optional), pushToken (optional), avatarEmoji (optional)
  /// [pairedAt] is the couple creation date, passed separately
  factory Partner.fromJson(Map<String, dynamic> json, DateTime pairedAt) {
    return Partner(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ??
            json['email']?.toString().split('@').first ??
            'Partner',
      pushToken: json['pushToken'] as String? ?? '',
      pairedAt: pairedAt,
      avatarEmoji: json['avatarEmoji'] as String? ?? '💕',
    );
  }

  /// Convert Partner to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pushToken': pushToken,
      'pairedAt': pairedAt.toIso8601String(),
      'avatarEmoji': avatarEmoji,
    };
  }
}
