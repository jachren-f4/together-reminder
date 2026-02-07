import 'package:hive/hive.dart';
import '../utils/logger.dart';

/// Play mode determines how a couple plays games together.
enum PlayMode {
  /// Both players share one phone, passing it between turns.
  singlePhone,

  /// Each player uses their own device (default for real partners).
  separatePhones,
}

/// Service for managing single-phone vs. separate-phone play mode.
///
/// Architecture:
/// - Hive-backed singleton (like CouplePreferencesService)
/// - When partner is phantom → always singlePhone
/// - When partner is real → user can choose in Settings (default: separatePhones)
///
/// Hive keys stored in 'app_metadata' box:
/// - 'phantom_user_id' — phantom partner's Supabase user ID (null if real partner)
/// - 'phantom_partner_name' — display name for phantom partner
/// - 'play_mode' — 'singlePhone' or 'separatePhones'
class PlayModeService {
  static final PlayModeService _instance = PlayModeService._internal();
  factory PlayModeService() => _instance;
  PlayModeService._internal();

  static const String _boxName = 'app_metadata';
  static const String _phantomUserIdKey = 'phantom_user_id';
  static const String _phantomPartnerNameKey = 'phantom_partner_name';
  static const String _playModeKey = 'play_mode';

  Box get _box => Hive.box(_boxName);

  // ---------------------------------------------------------------------------
  // Phantom partner state
  // ---------------------------------------------------------------------------

  /// Whether the current partner is a phantom user (single-phone only).
  bool get isPhantomPartner {
    final id = _box.get(_phantomUserIdKey) as String?;
    return id != null && id.isNotEmpty;
  }

  /// The phantom partner's Supabase user ID, or null if real partner.
  String? get phantomUserId {
    return _box.get(_phantomUserIdKey) as String?;
  }

  /// Display name for the phantom partner.
  String get partnerName {
    return _box.get(_phantomPartnerNameKey) as String? ?? 'Partner';
  }

  /// Store phantom partner state after create-with-phantom API call.
  Future<void> setPhantomPartner(String userId, String name) async {
    await _box.put(_phantomUserIdKey, userId);
    await _box.put(_phantomPartnerNameKey, name);
    // Phantom partners always use single-phone mode
    await _box.put(_playModeKey, 'singlePhone');
    Logger.info('Set phantom partner: $name ($userId)', service: 'playMode');
  }

  /// Clear phantom partner state (e.g. after real partner pairs via invite code).
  Future<void> clearPhantomPartner() async {
    await _box.delete(_phantomUserIdKey);
    await _box.delete(_phantomPartnerNameKey);
    // Default back to separate phones after real pairing
    await _box.put(_playModeKey, 'separatePhones');
    Logger.info('Cleared phantom partner state', service: 'playMode');
  }

  // ---------------------------------------------------------------------------
  // Play mode
  // ---------------------------------------------------------------------------

  /// Current play mode.
  PlayMode get playMode {
    if (isPhantomPartner) return PlayMode.singlePhone;
    final stored = _box.get(_playModeKey) as String?;
    return stored == 'singlePhone' ? PlayMode.singlePhone : PlayMode.separatePhones;
  }

  /// Whether the couple is using single-phone mode (either phantom or by choice).
  bool get isSinglePhone => playMode == PlayMode.singlePhone;

  /// Set play mode (only meaningful when partner is real).
  Future<void> setPlayMode(PlayMode mode) async {
    await _box.put(_playModeKey, mode == PlayMode.singlePhone ? 'singlePhone' : 'separatePhones');
    Logger.info('Set play mode: ${mode.name}', service: 'playMode');
  }

  // ---------------------------------------------------------------------------
  // onBehalfOf helper
  // ---------------------------------------------------------------------------

  /// Add `onBehalfOf` field to a request body if in single-phone mode
  /// and the phantom partner should be the effective user.
  ///
  /// Usage in game submission services:
  /// ```dart
  /// final body = {'sessionId': id, 'answers': answers};
  /// PlayModeService().addOnBehalfOfIfNeeded(body);
  /// final response = await apiClient.post('/api/sync/quiz/submit', body: body);
  /// ```
  void addOnBehalfOfIfNeeded(Map<String, dynamic> body) {
    if (isPhantomPartner) {
      body['onBehalfOf'] = phantomUserId;
    }
  }

  // ---------------------------------------------------------------------------
  // Debug / Reset
  // ---------------------------------------------------------------------------

  /// Clear all play mode state (for debug/testing).
  Future<void> clearAll() async {
    await _box.delete(_phantomUserIdKey);
    await _box.delete(_phantomPartnerNameKey);
    await _box.delete(_playModeKey);
    Logger.info('Cleared all play mode state', service: 'playMode');
  }
}
