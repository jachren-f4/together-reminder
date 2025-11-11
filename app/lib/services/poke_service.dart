import 'package:cloud_functions/cloud_functions.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/models/partner.dart';
import 'package:togetherremind/models/user.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/love_point_service.dart';
import 'package:uuid/uuid.dart';

class PokeService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final StorageService _storage = StorageService();
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
        print('⏳ Rate limited. Wait $remaining seconds');
        return false;
      }

      // Get partner and user info
      final partner = _storage.getPartner();
      final user = _storage.getUser();

      if (partner == null) {
        print('❌ No partner found, cannot send poke');
        return false;
      }

      if (user == null) {
        print('❌ No user found, cannot send poke');
        return false;
      }

      final pokeId = const Uuid().v4();
      final now = DateTime.now();

      print('💫 Sending poke to partner...');
      print('   Partner token: ${partner.pushToken}');
      print('   Sender: ${user.name ?? 'You'}');
      print('   Emoji: $emoji');

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

      // Call Cloud Function
      final callable = _functions.httpsCallable('sendPoke');
      final result = await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your Partner',
        'pokeId': pokeId,
        'emoji': emoji,
      });

      print('✅ Cloud Function response: ${result.data}');

      // Update rate limit timestamp
      _lastPokeTime = now;

      // Check if this is a mutual poke and award LP
      if (isMutualPoke(poke)) {
        await LovePointService.awardPoints(
          amount: 5,
          reason: 'mutual_poke',
          relatedId: pokeId,
        );
        print('🎉 Mutual poke! Awarded 5 LP');
      }

      return true;
    } catch (e) {
      print('❌ Error sending poke: $e');
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
      print('💾 Saved received poke from $fromName');
    } catch (e) {
      print('❌ Error handling received poke: $e');
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
      } else {
        // Award LP for poke back
        await LovePointService.awardPoints(
          amount: 3,
          reason: 'poke_back',
          relatedId: originalPokeId,
        );
        print('💕 Poke back! Awarded 3 LP');
      }

      return success;
    } catch (e) {
      print('❌ Error sending poke back: $e');
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
}
