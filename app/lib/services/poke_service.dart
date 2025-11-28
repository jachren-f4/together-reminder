import 'package:cloud_functions/cloud_functions.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/models/partner.dart';
import 'package:togetherremind/models/user.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/general_activity_streak_service.dart';
import 'package:togetherremind/services/api_client.dart';
import 'package:togetherremind/services/dev_data_service.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

class PokeService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final StorageService _storage = StorageService();
  static final ApiClient _apiClient = ApiClient();
  static DateTime? _lastPokeTime;
  static const int _rateLimitSeconds = 30;

  /// Check if rate limit allows sending a poke
  static bool canSendPoke() {
    if (_lastPokeTime == null) return true;

    final now = DateTime.now();
    final difference = now.difference(_lastPokeTime!);
    return difference.inSeconds >= _rateLimitSeconds;
  }

  /// Get remaining seconds until next poke is allowed
  static int getRemainingSeconds() {
    if (_lastPokeTime == null) return 0;

    final now = DateTime.now();
    final difference = now.difference(_lastPokeTime!);
    final remaining = _rateLimitSeconds - difference.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Send a poke to partner
  static Future<bool> sendPoke({String emoji = '💫'}) async {
    try {
      // Check rate limit
      if (!canSendPoke()) {
        final remaining = getRemainingSeconds();
        Logger.warn('Rate limited. Wait $remaining seconds', service: 'poke');
        return false;
      }

      // Get partner and user info
      final partner = _storage.getPartner();
      final user = _storage.getUser();

      if (partner == null) {
        Logger.error('No partner found, cannot send poke', service: 'poke');
        return false;
      }

      if (user == null) {
        Logger.error('No user found, cannot send poke', service: 'poke');
        return false;
      }

      // Refresh partner's FCM token from Supabase before sending
      // This ensures we have the latest token (solves startup race condition)
      await DevDataService().refreshPartnerPushToken();

      // Re-fetch partner to get updated token
      final updatedPartner = _storage.getPartner();
      final partnerToken = updatedPartner?.pushToken ?? partner.pushToken;

      final pokeId = const Uuid().v4();
      final now = DateTime.now();

      // Removed verbose logging
      // print('💫 Sending poke to partner...');
      // print('   Partner token: ${partner.pushToken}');
      // print('   Sender: ${user.name ?? 'You'}');
      // print('   Emoji: $emoji');

      // Create poke record (as Reminder with category='poke')
      final poke = Reminder(
        id: pokeId,
        type: 'sent',
        from: user.name ?? 'You',
        to: partner.name,
        text: '$emoji Poke',
        timestamp: now,
        scheduledFor: now,
        status: 'sent',
        createdAt: now,
        category: 'poke',
      );

      // Save locally
      await _storage.saveReminder(poke);

      // Sync to Supabase (Dual-Write)
      await _syncPokeToSupabase(poke);

      // Call Cloud Function
      final callable = _functions.httpsCallable('sendPoke');
      final result = await callable.call({
        'partnerToken': partnerToken,
        'senderName': user.name ?? 'Your Partner',
        'pokeId': pokeId,
        'emoji': emoji,
      });

      // Removed verbose logging
      // Logger.success('Cloud Function response: ${result.data}', service: 'poke');

      // Update rate limit timestamp
      _lastPokeTime = now;

      // LP awarding removed from pokes

      // Record activity for streak tracking
      await GeneralActivityStreakService().recordActivity();

      return true;
    } catch (e) {
      Logger.error('Error sending poke', error: e, service: 'poke');
      return false;
    }
  }

  /// Handle received poke notification
  static Future<void> handleReceivedPoke({
    required String pokeId,
    required String fromName,
    required String emoji,
  }) async {
    try {
      final now = DateTime.now();
      final user = _storage.getUser();

      final poke = Reminder(
        id: pokeId,
        type: 'received',
        from: fromName,
        to: user?.name ?? 'You',
        text: '$emoji Poke',
        timestamp: now,
        scheduledFor: now,
        status: 'received',
        createdAt: now,
        category: 'poke',
      );

      await _storage.saveReminder(poke);

      // Sync to Supabase (Dual-Write)
      await _syncPokeToSupabase(poke);

      // Removed verbose logging
      // print('💾 Saved received poke from $fromName');
    } catch (e) {
      Logger.error('Error handling received poke', error: e, service: 'poke');
    }
  }

  /// Send a poke back (response to received poke)
  static Future<bool> sendPokeBack(String originalPokeId) async {
    try {
      // Mark original poke as responded
      final originalPoke = _storage.remindersBox.get(originalPokeId);
      if (originalPoke != null) {
        originalPoke.status = 'responded_heart';
        await originalPoke.save();
      }

      // Send new poke (bypass rate limit for immediate response)
      final previousLastPokeTime = _lastPokeTime;
      _lastPokeTime = null; // Temporarily clear rate limit

      final success = await sendPoke(emoji: '❤️');

      if (!success) {
        _lastPokeTime = previousLastPokeTime; // Restore if failed
      }
      // LP awarding removed from poke back

      return success;
    } catch (e) {
      Logger.error('Error sending poke back', error: e, service: 'poke');
      return false;
    }
  }

  /// Check if a poke is mutual (both sent within short time window)
  static bool isMutualPoke(Reminder poke) {
    if (!poke.isPoke) return false;

    // Get all pokes from the last 2 minutes
    final now = DateTime.now();
    final twoMinutesAgo = now.subtract(const Duration(minutes: 2));

    final recentPokes = _storage.getAllReminders()
        .where((r) => r.isPoke && r.timestamp.isAfter(twoMinutesAgo))
        .toList();

    // Check if there's a sent and received poke within this window
    final hasSent = recentPokes.any((r) => r.type == 'sent');
    final hasReceived = recentPokes.any((r) => r.type == 'received');

    return hasSent && hasReceived;
  }

  /// Get poke statistics
  static Map<String, int> getPokeStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = now.subtract(const Duration(days: 7));

    final allPokes = _storage.getAllReminders()
        .where((r) => r.isPoke)
        .toList();

    final todayPokes = allPokes
        .where((r) => r.timestamp.isAfter(today))
        .length;

    final weekPokes = allPokes
        .where((r) => r.timestamp.isAfter(weekAgo))
        .length;

    final mutualPokes = allPokes
        .where((r) => isMutualPoke(r))
        .length ~/ 2; // Divide by 2 since mutual pokes are counted twice

    return {
      'today': todayPokes,
      'week': weekPokes,
      'mutual': mutualPokes,
    };
  }

  /// Sync poke to Supabase (Dual-Write Implementation)
  static Future<void> _syncPokeToSupabase(Reminder poke) async {
    try {
      Logger.debug('🚀 Attempting dual-write to Supabase (poke)...', service: 'poke');

      final response = await _apiClient.post('/api/sync/reminders', body: {
        'id': poke.id,
        'type': poke.type,
        'fromName': poke.from,
        'toName': poke.to,
        'text': poke.text,
        'category': poke.category,
        'emoji': poke.text.contains('💫') ? '💫' : null,
        'scheduledFor': poke.scheduledFor.toIso8601String(),
        'status': poke.status,
        'createdAt': poke.createdAt.toIso8601String(),
        'sentAt': poke.status == 'sent' ? poke.timestamp.toIso8601String() : null,
      });

      if (response.success) {
        Logger.debug('✅ Supabase dual-write successful!', service: 'poke');
      }
    } catch (e) {
      Logger.error('Supabase dual-write exception', error: e, service: 'poke');
    }
  }
}
