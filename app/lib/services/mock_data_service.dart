import 'package:togetherremind/models/partner.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/models/user.dart';
import 'package:togetherremind/models/love_point_transaction.dart';
import 'package:togetherremind/models/quiz_session.dart';
import 'package:togetherremind/models/badge.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/notification_service.dart';
import 'package:togetherremind/config/dev_config.dart';
import 'package:uuid/uuid.dart';

/// Service for injecting mock data in development mode
/// Enables testing without QR pairing flow
class MockDataService {
  static const _uuid = Uuid();
  static final _storage = StorageService();

  /// Automatically inject mock data if enabled and no partner exists
  /// Call this in main() after StorageService.init()
  ///
  /// For dual-emulator mode:
  /// - Detects which emulator (Alice or Bob) based on port
  /// - Creates user with REAL FCM token
  /// - Creates partner placeholder (will be paired via DevPairingService)
  static Future<void> injectMockDataIfNeeded() async {
    final enableMockPairing = await DevConfig.enableMockPairing;
    if (!enableMockPairing) return;

    final isSimulator = await DevConfig.isSimulator;

    if (isSimulator) {
      // DUAL-EMULATOR MODE: Always update to deterministic IDs
      // Check if existing data uses old random IDs
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      final partnerIndex = await DevConfig.partnerIndex;
      final expectedUserId = DevConfig.dualPartnerUserIds[partnerIndex];

      if (user != null && user.id != expectedUserId) {
        print('⚠️  Detected old user ID, replacing with deterministic ID...');
        await _storage.clearAllData();
      } else if (partner != null && !partner.pushToken.contains('dev-user')) {
        print('⚠️  Detected old partner ID, replacing with deterministic ID...');
        await _storage.clearAllData();
      }

      // Create partner-specific data with deterministic IDs
      if (!_storage.hasPartner()) {
        await _injectDualEmulatorData();
      } else {
        // Removed verbose logging
        // print('ℹ️  Deterministic mock data already exists');
      }
    } else {
      // SINGLE-DEVICE MODE: Use old mock data approach
      if (_storage.hasPartner()) {
        // Removed verbose logging
        // print('ℹ️  Mock data already exists, skipping injection');
        return;
      }
      await _injectSingleDeviceMockData();
    }
  }

  /// Inject data for dual-emulator testing
  /// Each emulator gets a unique user (Alice or Bob) with real FCM token
  static Future<void> _injectDualEmulatorData() async {
    // Removed verbose logging
    // print('🧑‍💻 Dual-Emulator Mode: Setting up partner data...');

    final partnerIndex = await DevConfig.partnerIndex;
    final config = DevConfig.dualPartnerConfig[partnerIndex];
    final emulatorId = await DevConfig.emulatorId;

    // Get deterministic user IDs for this user and their partner
    final myUserId = DevConfig.dualPartnerUserIds[partnerIndex];
    final partnerUserId = DevConfig.dualPartnerUserIds[(partnerIndex + 1) % 2];

    // Removed verbose logging
    // print('   Emulator ID: $emulatorId');
    // print('   This partner: ${config['name']} ${config['emoji']}');
    // print('   My user ID: $myUserId');
    // print('   Other partner: ${config['partnerName']} ${config['partnerEmoji']}');
    // print('   Partner user ID: $partnerUserId');

    // Create THIS user with DETERMINISTIC user ID and REAL FCM token
    if (_storage.getUser() == null) {
      await _createMockUserWithRealToken(
        userId: myUserId,
        name: config['name']!,
        emoji: config['emoji']!,
      );
    }

    // Create partner with DETERMINISTIC user ID as pushToken
    // This ensures couple ID generation works correctly
    await _createPartnerPlaceholder(
      name: config['partnerName']!,
      emoji: config['partnerEmoji']!,
      pushToken: partnerUserId,  // Use partner's user ID for couple ID generation
    );

    // Removed verbose logging
    // print('✅ Dual-emulator setup complete!');
    // print('   User: ${config['name']} with deterministic ID and real FCM token');
    // print('   Partner: ${config['partnerName']} with deterministic ID');
    // print('   Couple ID will be consistent across both devices');
  }

  /// Inject old-style mock data for single device testing
  static Future<void> _injectSingleDeviceMockData() async {
    // Removed verbose logging
    // print('🧑‍💻 Dev Mode: Injecting mock data...');

    // Create mock user if needed
    if (_storage.getUser() == null) {
      await _createMockUser();
    }

    // Inject mock partner
    await _injectMockPartner();

    // Inject mock reminders
    await _injectMockReminders();

    // Inject mock LP transactions
    await _injectMockTransactions();

    // Inject mock quiz data
    await _injectMockQuizData();

    // Removed verbose logging
    // print('✅ Mock data injected successfully');
    // print('   Partner: ${DevConfig.mockPartnerName} ${DevConfig.mockPartnerEmoji}');
    // print('   Reminders: 10 (3 received pending, 2 received done, 1 snoozed, 3 sent, 1 sent done)');
    // print('   Love Points: 1280 LP (Beach Villa tier)');
    // print('   Transactions: 8 recent LP activities');
    // print('   Quiz History: 3 completed quizzes');
    // print('   Badges: 1 Perfect Sync badge');
  }

  /// Create a mock user with fake push token and LP data
  static Future<void> _createMockUser() async {
    final user = User(
      id: _uuid.v4(),
      pushToken: 'mock_user_token_${_uuid.v4().substring(0, 8)}',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      name: DevConfig.mockUserName,
      lovePoints: 1280, // Beach Villa tier (1000-2500)
      arenaTier: 2,
      floor: 1000,
      lastActivityDate: DateTime.now(),
    );

    await _storage.saveUser(user);
    // Removed verbose logging
    // print('   Created mock user: ${user.name} (1280 LP, Beach Villa)');
  }

  /// Inject mock partner with fake push token
  static Future<void> _injectMockPartner() async {
    final partner = Partner(
      name: DevConfig.mockPartnerName,
      pushToken: 'mock_partner_token_${_uuid.v4().substring(0, 8)}',
      pairedAt: DateTime.now().subtract(const Duration(days: 30)),
      avatarEmoji: DevConfig.mockPartnerEmoji,
    );

    await _storage.savePartner(partner);
  }

  /// Inject 10 varied mock reminders for realistic testing
  static Future<void> _injectMockReminders() async {
    final now = DateTime.now();
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) return;

    final reminders = [
      // === RECEIVED REMINDERS (from partner) ===

      // 1. Received - Pending (2 hours from now)
      Reminder(
        id: _uuid.v4(),
        type: 'received',
        from: partner.name,
        to: user.name ?? 'You',
        text: 'Don\'t forget to buy milk! 🥛',
        timestamp: now,
        scheduledFor: now.add(const Duration(hours: 2)),
        status: 'pending',
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),

      // 2. Received - Pending (tonight at 8 PM)
      Reminder(
        id: _uuid.v4(),
        type: 'received',
        from: partner.name,
        to: user.name ?? 'You',
        text: 'Call mom tonight 📞',
        timestamp: now,
        scheduledFor: DateTime(now.year, now.month, now.day, 20, 0),
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),

      // 3. Received - Pending (tomorrow 9 AM)
      Reminder(
        id: _uuid.v4(),
        type: 'received',
        from: partner.name,
        to: user.name ?? 'You',
        text: 'Pick up dry cleaning 👔',
        timestamp: now,
        scheduledFor: DateTime(now.year, now.month, now.day + 1, 9, 0),
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 12)),
      ),

      // 4. Received - Done (yesterday)
      Reminder(
        id: _uuid.v4(),
        type: 'received',
        from: partner.name,
        to: user.name ?? 'You',
        text: 'Love you! 💕',
        timestamp: now.subtract(const Duration(days: 1)),
        scheduledFor: now.subtract(const Duration(days: 1)),
        status: 'done',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),

      // 5. Received - Done (2 days ago)
      Reminder(
        id: _uuid.v4(),
        type: 'received',
        from: partner.name,
        to: user.name ?? 'You',
        text: 'Take out trash 🗑️',
        timestamp: now.subtract(const Duration(days: 2)),
        scheduledFor: now.subtract(const Duration(days: 2)),
        status: 'done',
        createdAt: now.subtract(const Duration(days: 2, hours: 1)),
      ),

      // 6. Received - Snoozed (snoozed until tomorrow)
      Reminder(
        id: _uuid.v4(),
        type: 'received',
        from: partner.name,
        to: user.name ?? 'You',
        text: 'Water the plants 🌱',
        timestamp: now.subtract(const Duration(hours: 6)),
        scheduledFor: now.subtract(const Duration(hours: 6)),
        status: 'snoozed',
        snoozedUntil: DateTime(now.year, now.month, now.day + 1, 10, 0),
        createdAt: now.subtract(const Duration(hours: 8)),
      ),

      // === SENT REMINDERS (to partner) ===

      // 7. Sent - Pending (1 hour from now)
      Reminder(
        id: _uuid.v4(),
        type: 'sent',
        from: user.name ?? 'You',
        to: partner.name,
        text: 'Buy coffee beans ☕',
        timestamp: now,
        scheduledFor: now.add(const Duration(hours: 1)),
        status: 'pending',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),

      // 8. Sent - Pending (tonight at 7 PM)
      Reminder(
        id: _uuid.v4(),
        type: 'sent',
        from: user.name ?? 'You',
        to: partner.name,
        text: 'Book dentist appointment 🦷',
        timestamp: now,
        scheduledFor: DateTime(now.year, now.month, now.day, 19, 0),
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),

      // 9. Sent - Pending (tomorrow afternoon)
      Reminder(
        id: _uuid.v4(),
        type: 'sent',
        from: user.name ?? 'You',
        to: partner.name,
        text: 'Workout together? 💪',
        timestamp: now,
        scheduledFor: DateTime(now.year, now.month, now.day + 1, 15, 0),
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 18)),
      ),

      // 10. Sent - Done (3 hours ago)
      Reminder(
        id: _uuid.v4(),
        type: 'sent',
        from: user.name ?? 'You',
        to: partner.name,
        text: 'I\'m home! 🏠',
        timestamp: now.subtract(const Duration(hours: 3)),
        scheduledFor: now.subtract(const Duration(hours: 3)),
        status: 'done',
        createdAt: now.subtract(const Duration(hours: 3, minutes: 5)),
      ),
    ];

    // Save all reminders
    for (final reminder in reminders) {
      await _storage.saveReminder(reminder);
    }
  }

  /// Inject mock LP transactions for realistic profile testing
  static Future<void> _injectMockTransactions() async {
    final now = DateTime.now();

    final transactions = [
      LovePointTransaction(
        id: _uuid.v4(),
        amount: 10,
        reason: 'reminder_done',
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
      LovePointTransaction(
        id: _uuid.v4(),
        amount: 8,
        reason: 'reminder_sent',
        timestamp: now.subtract(const Duration(hours: 5)),
      ),
      LovePointTransaction(
        id: _uuid.v4(),
        amount: 5,
        reason: 'mutual_poke',
        timestamp: now.subtract(const Duration(hours: 8)),
      ),
      LovePointTransaction(
        id: _uuid.v4(),
        amount: 10,
        reason: 'reminder_done',
        timestamp: now.subtract(const Duration(days: 1)),
      ),
      LovePointTransaction(
        id: _uuid.v4(),
        amount: 3,
        reason: 'poke_back',
        timestamp: now.subtract(const Duration(days: 1, hours: 5)),
      ),
      LovePointTransaction(
        id: _uuid.v4(),
        amount: 8,
        reason: 'reminder_sent',
        timestamp: now.subtract(const Duration(days: 2)),
      ),
      LovePointTransaction(
        id: _uuid.v4(),
        amount: 10,
        reason: 'reminder_done',
        timestamp: now.subtract(const Duration(days: 2, hours: 12)),
      ),
      LovePointTransaction(
        id: _uuid.v4(),
        amount: 5,
        reason: 'mutual_poke',
        timestamp: now.subtract(const Duration(days: 3)),
      ),
    ];

    // Save all transactions
    for (final transaction in transactions) {
      await _storage.saveTransaction(transaction);
    }
  }

  /// Inject mock quiz sessions and badges for realistic testing
  static Future<void> _injectMockQuizData() async {
    final now = DateTime.now();
    final user = _storage.getUser();

    if (user == null) return;

    // Create mock quiz sessions
    final sessions = [
      // 1. Completed quiz - Perfect Match (100%)
      QuizSession(
        id: _uuid.v4(),
        questionIds: ['q1', 'q2', 'q3', 'q4', 'q5'], // Mock question IDs
        createdAt: now.subtract(const Duration(days: 2)),
        expiresAt: now.subtract(const Duration(days: 2)).add(const Duration(hours: 3)),
        status: 'completed',
        initiatedBy: user.id,
        answers: {
          user.id: [0, 1, 2, 0, 1], // User's answers
          'partner_id': [0, 1, 2, 0, 1], // Partner's matching answers
        },
        matchPercentage: 100,
        lpEarned: 50,
        completedAt: now.subtract(const Duration(days: 2, hours: -1)),
      ),

      // 2. Completed quiz - Great Match (80%)
      QuizSession(
        id: _uuid.v4(),
        questionIds: ['q6', 'q7', 'q8', 'q9', 'q10'],
        createdAt: now.subtract(const Duration(days: 5)),
        expiresAt: now.subtract(const Duration(days: 5)).add(const Duration(hours: 3)),
        status: 'completed',
        initiatedBy: user.id,
        answers: {
          user.id: [1, 2, 0, 3, 1],
          'partner_id': [1, 2, 0, 2, 1], // 4 matches
        },
        matchPercentage: 80,
        lpEarned: 30,
        completedAt: now.subtract(const Duration(days: 5, hours: -2)),
      ),

      // 3. Completed quiz - Good Match (60%)
      QuizSession(
        id: _uuid.v4(),
        questionIds: ['q11', 'q12', 'q13', 'q14', 'q15'],
        createdAt: now.subtract(const Duration(days: 8)),
        expiresAt: now.subtract(const Duration(days: 8)).add(const Duration(hours: 3)),
        status: 'completed',
        initiatedBy: user.id,
        answers: {
          user.id: [2, 1, 3, 0, 2],
          'partner_id': [2, 1, 1, 0, 1], // 3 matches
        },
        matchPercentage: 60,
        lpEarned: 20,
        completedAt: now.subtract(const Duration(days: 8, hours: -1)),
      ),
    ];

    // Save all quiz sessions
    for (final session in sessions) {
      await _storage.saveQuizSession(session);
    }

    // Create Perfect Sync badge
    final badge = Badge(
      id: _uuid.v4(),
      name: 'Perfect Sync',
      emoji: '🎯',
      description: '100% match on a couple quiz',
      earnedAt: now.subtract(const Duration(days: 2, hours: -1)),
      category: 'quiz',
    );

    await _storage.saveBadge(badge);

    // Removed verbose logging
    // print('   Created 3 mock quiz sessions and 1 badge');
  }

  /// Create a mock user with REAL FCM token (for dual-emulator testing)
  static Future<void> _createMockUserWithRealToken({
    required String userId,
    required String name,
    required String emoji,
  }) async {
    // Get REAL FCM token from Firebase (uses NotificationService which handles web)
    final fcmToken = await NotificationService.getToken();
    // Removed verbose logging
    // if (fcmToken == null) {
    //   print('⚠️ Warning: Could not get FCM token, using placeholder');
    // }

    final user = User(
      id: userId,  // Use deterministic user ID from DevConfig
      pushToken: fcmToken ?? 'placeholder_token_${_uuid.v4().substring(0, 8)}',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      name: name,
      lovePoints: 0, // Start fresh for dual-emulator testing
      arenaTier: 0,
      floor: 0,
      lastActivityDate: DateTime.now(),
    );

    await _storage.saveUser(user);
    // Removed verbose logging
    // print('   Created user: $name $emoji (ID: ${userId.substring(0, 30)}...)');
    // print('   FCM token: ${fcmToken?.substring(0, 20)}...');
  }

  /// Create partner placeholder
  /// Uses partner's deterministic user ID for couple ID generation
  /// DevPairingService will update with real FCM token for notifications
  static Future<void> _createPartnerPlaceholder({
    required String name,
    required String emoji,
    required String pushToken,
  }) async {
    final partner = Partner(
      name: name,
      pushToken: pushToken,  // Use partner's deterministic user ID
      pairedAt: DateTime.now(),
      avatarEmoji: emoji,
    );

    await _storage.savePartner(partner);
    // Removed verbose logging
    // print('   Created partner: $name $emoji');
    // print('   Partner token (user ID): ${pushToken.substring(0, 30)}...');
  }

  /// Clear all mock data (useful for dev menu in Phase 2)
  static Future<void> clearMockData() async {
    await _storage.clearAllData();
    print('🗑️  Mock data cleared');
  }
}
