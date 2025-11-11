/// Model for remote pairing codes
/// Represents a temporary 6-character code for pairing devices remotely
class PairingCode {
  final String code;
  final DateTime expiresAt;

  PairingCode({
    required this.code,
    required this.expiresAt,
  });

  /// Time remaining until expiration
  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  /// Check if code is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get formatted time remaining (e.g., "9:47")
  String get formattedTimeRemaining {
    final remaining = timeRemaining;
    if (remaining.isNegative) return '0:00';

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Convert from JSON
  factory PairingCode.fromJson(Map<String, dynamic> json) {
    return PairingCode(
      code: json['code'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
  }
}
