import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../utils/logger.dart';
import 'storage_service.dart';
import 'steps_health_service.dart';
import 'api_client.dart';

/// Service for synchronizing step data between partners via Firebase RTDB.
///
/// Database structure:
/// /steps_data/{coupleId}/
///   ├── connection/
///   │   ├── user1_connected: true
///   │   ├── user1_connected_at: timestamp
///   │   ├── user2_connected: false
///   │   └── user2_connected_at: null
///   └── days/{dateKey}/
///       ├── user1_steps: 8200
///       ├── user1_last_sync: timestamp
///       ├── user2_steps: 6000
///       ├── user2_last_sync: timestamp
///       └── claimed_by: null | userId
class StepsSyncService {
  static final StepsSyncService _instance = StepsSyncService._internal();
  factory StepsSyncService() => _instance;
  StepsSyncService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final StorageService _storage = StorageService();
  final StepsHealthService _healthService = StepsHealthService();
  final ApiClient _apiClient = ApiClient();

  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  StreamSubscription<DatabaseEvent>? _stepsSubscription;
  StreamSubscription<DatabaseEvent>? _yesterdaySubscription;

  String? _currentCoupleId;
  String? _currentUserId;

  /// Initialize sync service with couple and user IDs
  void initialize({
    required String coupleId,
    required String userId,
  }) {
    _currentCoupleId = coupleId;
    _currentUserId = userId;
    Logger.debug('StepsSyncService initialized for couple: $coupleId, user: $userId', service: 'steps');
  }

  /// Start listening for partner's connection status and step updates
  void startListening() {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot start listening - StepsSyncService not initialized', service: 'steps');
      return;
    }

    _startConnectionListener();
    _startStepsListener();
    _startYesterdayListener();
  }

  /// Stop all listeners
  void stopListening() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _stepsSubscription?.cancel();
    _stepsSubscription = null;
    _yesterdaySubscription?.cancel();
    _yesterdaySubscription = null;
    Logger.debug('StepsSyncService listeners stopped', service: 'steps');
  }

  /// Start listening for connection status changes
  void _startConnectionListener() {
    final connectionRef = _database.child('steps_data/$_currentCoupleId/connection');

    _connectionSubscription = connectionRef.onValue.listen((event) {
      if (event.snapshot.value == null) return;

      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _handleConnectionUpdate(data);
      } catch (e, stackTrace) {
        Logger.error('Error handling connection update', error: e, stackTrace: stackTrace, service: 'steps');
      }
    });

    Logger.debug('Started connection listener for $_currentCoupleId', service: 'steps');
  }

  /// Handle connection status update from Firebase
  void _handleConnectionUpdate(Map<dynamic, dynamic> data) {
    // Find partner's connection status (the one that's not current user)
    bool partnerConnected = false;
    DateTime? partnerConnectedAt;

    data.forEach((key, value) {
      if (key.toString().endsWith('_connected') && !key.toString().startsWith(_currentUserId!)) {
        // This is partner's connection field
        final userId = key.toString().replaceAll('_connected', '');
        partnerConnected = value == true;

        // Get connected_at timestamp
        final connectedAtKey = '${userId}_connected_at';
        if (data.containsKey(connectedAtKey) && data[connectedAtKey] != null) {
          partnerConnectedAt = DateTime.fromMillisecondsSinceEpoch(data[connectedAtKey] as int);
        }
      }
    });

    // Update local storage
    _healthService.updatePartnerConnection(
      connected: partnerConnected,
      connectedAt: partnerConnectedAt,
    );

    Logger.debug('Partner connection status updated: $partnerConnected', service: 'steps');
  }

  /// Start listening for partner's step updates
  void _startStepsListener() {
    final today = StepsHealthService.todayDateKey;
    final stepsRef = _database.child('steps_data/$_currentCoupleId/days/$today');

    _stepsSubscription = stepsRef.onValue.listen((event) {
      if (event.snapshot.value == null) return;

      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _handleStepsUpdate(data, today);
      } catch (e, stackTrace) {
        Logger.error('Error handling steps update', error: e, stackTrace: stackTrace, service: 'steps');
      }
    });

    Logger.debug('Started steps listener for $_currentCoupleId/$today', service: 'steps');
  }

  /// Start listening for yesterday's claim status (prevents double-claiming)
  void _startYesterdayListener() {
    final yesterday = StepsHealthService.yesterdayDateKey;
    final yesterdayRef = _database.child('steps_data/$_currentCoupleId/days/$yesterday');

    _yesterdaySubscription = yesterdayRef.onValue.listen((event) {
      if (event.snapshot.value == null) return;

      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _handleStepsUpdate(data, yesterday);
      } catch (e, stackTrace) {
        Logger.error('Error handling yesterday update', error: e, stackTrace: stackTrace, service: 'steps');
      }
    });

    Logger.debug('Started yesterday listener for $_currentCoupleId/$yesterday', service: 'steps');
  }

  /// Handle step data update from Firebase
  void _handleStepsUpdate(Map<dynamic, dynamic> data, String dateKey) {
    // Find partner's steps (the one that's not current user)
    data.forEach((key, value) {
      if (key.toString().endsWith('_steps') && !key.toString().startsWith(_currentUserId!)) {
        // This is partner's steps field
        final userId = key.toString().replaceAll('_steps', '');
        final steps = value as int? ?? 0;

        // Get last sync timestamp
        final lastSyncKey = '${userId}_last_sync';
        DateTime syncTime = DateTime.now();
        if (data.containsKey(lastSyncKey) && data[lastSyncKey] != null) {
          syncTime = DateTime.fromMillisecondsSinceEpoch(data[lastSyncKey] as int);
        }

        // Update local storage
        _healthService.updatePartnerSteps(
          dateKey: dateKey,
          steps: steps,
          syncTime: syncTime,
        );

        Logger.debug('Partner steps updated: $steps for $dateKey', service: 'steps');
      }
    });

    // Check for claim status (prevents double-claiming)
    if (data.containsKey('claimed_by') && data['claimed_by'] != null) {
      _healthService.markAsClaimedFromSync(dateKey);
      Logger.debug('Steps reward for $dateKey already claimed by ${data['claimed_by']}', service: 'steps');
    }
  }

  /// Sync user's connection status to Firebase
  Future<void> syncConnectionStatus() async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot sync connection - not initialized', service: 'steps');
      return;
    }

    final connection = _storage.getStepsConnection();
    if (connection == null) return;

    try {
      final connectionRef = _database.child('steps_data/$_currentCoupleId/connection');

      await connectionRef.update({
        '${_currentUserId}_connected': connection.isConnected,
        '${_currentUserId}_connected_at': connection.connectedAt?.millisecondsSinceEpoch,
      });

      Logger.debug('Synced connection status to Firebase: ${connection.isConnected}', service: 'steps');

      // Dual-write to Supabase (fire-and-forget)
      _syncConnectionToSupabase(connection.isConnected, connection.connectedAt);
    } catch (e, stackTrace) {
      Logger.error('Error syncing connection status', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Sync user's steps to Firebase
  Future<void> syncStepsToFirebase() async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot sync steps - not initialized', service: 'steps');
      return;
    }

    // Get today's local step data
    final today = _storage.getTodaySteps();
    if (today == null) {
      Logger.debug('No local steps to sync', service: 'steps');
      return;
    }

    try {
      final stepsRef = _database.child('steps_data/$_currentCoupleId/days/${today.dateKey}');

      await stepsRef.update({
        '${_currentUserId}_steps': today.userSteps,
        '${_currentUserId}_last_sync': ServerValue.timestamp,
      });

      Logger.debug('Synced ${today.userSteps} steps to Firebase for ${today.dateKey}', service: 'steps');

      // Dual-write to Supabase (fire-and-forget)
      _syncStepsToSupabase(today.dateKey, today.userSteps);
    } catch (e, stackTrace) {
      Logger.error('Error syncing steps to Firebase', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Sync yesterday's steps to Firebase (for claim eligibility)
  Future<void> syncYesterdayToFirebase() async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot sync yesterday - not initialized', service: 'steps');
      return;
    }

    // Get yesterday's local step data
    final yesterday = _storage.getYesterdaySteps();
    if (yesterday == null) {
      Logger.debug('No yesterday steps to sync', service: 'steps');
      return;
    }

    try {
      final stepsRef = _database.child('steps_data/$_currentCoupleId/days/${yesterday.dateKey}');

      await stepsRef.update({
        '${_currentUserId}_steps': yesterday.userSteps,
        '${_currentUserId}_last_sync': ServerValue.timestamp,
      });

      Logger.debug('Synced ${yesterday.userSteps} steps to Firebase for ${yesterday.dateKey}', service: 'steps');

      // Dual-write to Supabase (fire-and-forget)
      _syncStepsToSupabase(yesterday.dateKey, yesterday.userSteps);
    } catch (e, stackTrace) {
      Logger.error('Error syncing yesterday to Firebase', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Full sync: read from HealthKit and push to Firebase
  Future<void> performFullSync() async {
    if (!StepsHealthService.isSupported) {
      Logger.debug('Steps sync skipped - not iOS', service: 'steps');
      return;
    }

    // 1. Sync from HealthKit to local storage
    await _healthService.syncTodaySteps();
    await _healthService.syncYesterdaySteps();

    // 2. Sync from local storage to Firebase
    await syncStepsToFirebase();
    await syncYesterdayToFirebase();
    await syncConnectionStatus();

    Logger.info('Full steps sync completed', service: 'steps');
  }

  /// Mark a day's reward as claimed in Firebase
  Future<void> markClaimedInFirebase(String dateKey) async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot mark claimed - not initialized', service: 'steps');
      return;
    }

    try {
      final stepsRef = _database.child('steps_data/$_currentCoupleId/days/$dateKey');

      await stepsRef.update({
        'claimed_by': _currentUserId,
        'claimed_at': ServerValue.timestamp,
      });

      Logger.debug('Marked $dateKey as claimed in Firebase', service: 'steps');

      // Dual-write to Supabase (fire-and-forget)
      final yesterday = _storage.getYesterdaySteps();
      if (yesterday != null && yesterday.dateKey == dateKey) {
        _syncClaimToSupabase(dateKey, yesterday.combinedSteps, yesterday.earnedLP);
      }
    } catch (e, stackTrace) {
      Logger.error('Error marking claimed in Firebase', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Load partner's data from Firebase (initial load on app start)
  Future<void> loadPartnerDataFromFirebase() async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot load partner data - not initialized', service: 'steps');
      return;
    }

    try {
      // Load connection status
      final connectionRef = _database.child('steps_data/$_currentCoupleId/connection');
      final connectionSnapshot = await connectionRef.get();

      if (connectionSnapshot.exists && connectionSnapshot.value != null) {
        final data = connectionSnapshot.value as Map<dynamic, dynamic>;
        _handleConnectionUpdate(data);
      }

      // Load today's steps
      final today = StepsHealthService.todayDateKey;
      final todayRef = _database.child('steps_data/$_currentCoupleId/days/$today');
      final todaySnapshot = await todayRef.get();

      if (todaySnapshot.exists && todaySnapshot.value != null) {
        final data = todaySnapshot.value as Map<dynamic, dynamic>;
        _handleStepsUpdate(data, today);
      }

      // Load yesterday's steps
      final yesterday = StepsHealthService.yesterdayDateKey;
      final yesterdayRef = _database.child('steps_data/$_currentCoupleId/days/$yesterday');
      final yesterdaySnapshot = await yesterdayRef.get();

      if (yesterdaySnapshot.exists && yesterdaySnapshot.value != null) {
        final data = yesterdaySnapshot.value as Map<dynamic, dynamic>;
        _handleStepsUpdate(data, yesterday);
      }

      Logger.info('Loaded partner data from Firebase', service: 'steps');
    } catch (e, stackTrace) {
      Logger.error('Error loading partner data', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Generate couple ID from two user IDs (consistent ordering)
  static String generateCoupleId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Clean up old step data from Firebase (older than 7 days)
  Future<void> cleanupOldData() async {
    if (_currentCoupleId == null) return;

    try {
      final daysRef = _database.child('steps_data/$_currentCoupleId/days');
      final snapshot = await daysRef.get();

      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now();

      for (final dateKey in data.keys) {
        try {
          final dateParts = (dateKey as String).split('-');
          final stepDate = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );

          if (now.difference(stepDate).inDays > 7) {
            await daysRef.child(dateKey).remove();
            Logger.debug('Cleaned up old steps data for $dateKey', service: 'steps');
          }
        } catch (e) {
          Logger.error('Error parsing date key $dateKey', error: e, service: 'steps');
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Error cleaning up old data', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Dispose of resources
  void dispose() {
    stopListening();
    _currentCoupleId = null;
    _currentUserId = null;
  }

  // ===========================================================================
  // SUPABASE DUAL-WRITE METHODS
  // ===========================================================================
  // These methods sync data to Supabase alongside Firebase for eventual migration.
  // All methods are fire-and-forget (don't await, don't block main flow).

  /// Sync connection status to Supabase (dual-write)
  void _syncConnectionToSupabase(bool isConnected, DateTime? connectedAt) {
    _apiClient.post('/api/sync/steps', body: {
      'operation': 'connection',
      'isConnected': isConnected,
      'connectedAt': connectedAt?.toIso8601String(),
    }).then((response) {
      if (response.success) {
        Logger.debug('✅ Steps connection synced to Supabase', service: 'steps');
      }
    }).catchError((e) {
      Logger.warn('⚠️ Failed to sync steps connection to Supabase: $e', service: 'steps');
    });
  }

  /// Sync daily steps to Supabase (dual-write)
  void _syncStepsToSupabase(String dateKey, int steps) {
    _apiClient.post('/api/sync/steps', body: {
      'operation': 'steps',
      'dateKey': dateKey,
      'steps': steps,
      'lastSyncAt': DateTime.now().toIso8601String(),
    }).then((response) {
      if (response.success) {
        Logger.debug('✅ Steps synced to Supabase: $steps for $dateKey', service: 'steps');
      }
    }).catchError((e) {
      Logger.warn('⚠️ Failed to sync steps to Supabase: $e', service: 'steps');
    });
  }

  /// Sync claim to Supabase (dual-write)
  void _syncClaimToSupabase(String dateKey, int combinedSteps, int lpEarned) {
    _apiClient.post('/api/sync/steps', body: {
      'operation': 'claim',
      'dateKey': dateKey,
      'combinedSteps': combinedSteps,
      'lpEarned': lpEarned,
    }).then((response) {
      if (response.success) {
        final data = response.data;
        if (data != null && data['alreadyClaimed'] == true) {
          Logger.debug('ℹ️ Steps claim already recorded in Supabase', service: 'steps');
        } else {
          Logger.debug('✅ Steps claim synced to Supabase: +$lpEarned LP', service: 'steps');
        }
      }
    }).catchError((e) {
      Logger.warn('⚠️ Failed to sync steps claim to Supabase: $e', service: 'steps');
    });
  }
}
