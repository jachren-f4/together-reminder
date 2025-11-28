import 'package:firebase_database/firebase_database.dart';
import '../models/daily_quest.dart';
import '../models/quiz_progression_state.dart';
import '../services/storage_service.dart';
import '../services/quest_utilities.dart';
import '../services/api_client.dart';
import '../utils/logger.dart';
import '../config/dev_config.dart';

/// Service for synchronizing daily quests via Firebase RTDB
///
/// Uses "first user creates, second user loads" pattern to ensure
/// both partners get identical daily quests.
///
/// Database structure:
/// /daily_quests/{coupleId}/{dateKey}/
///   - quests: List of quest objects
///   - generatedBy: userId who generated
///   - generatedAt: timestamp
///   - progression: current quiz progression state
class QuestSyncService {
  final StorageService _storage;
  final DatabaseReference _database;
  final ApiClient _apiClient = ApiClient(); // Supabase API Client

  QuestSyncService({
    required StorageService storage,
  })  : _storage = storage,
        _database = FirebaseDatabase.instance.ref();

  /// Sync today's quests from Firebase or generate if first user
  ///
  /// Returns true if sync was successful
  ///
  /// PHASE 4: When useSuperbaseForDailyQuests is TRUE, uses Supabase-only path
  Future<bool> syncTodayQuests({
    required String currentUserId,
    required String partnerUserId,
  }) async {
    // PHASE 4: Supabase-only path (flag-gated)
    if (DevConfig.useSuperbaseForDailyQuests) {
      return _syncTodayQuestsSupabase(currentUserId, partnerUserId);
    }

    // OLD PATH: Firebase (default)
    try {
      final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
      final dateKey = QuestUtilities.getTodayDateKey();

      Logger.debug('🔄 Quest Sync Check:', service: 'quest');
      Logger.debug('   Couple ID: $coupleId', service: 'quest');
      Logger.debug('   Date Key: $dateKey', service: 'quest');
      Logger.debug('   Firebase Path: /daily_quests/$coupleId/$dateKey', service: 'quest');

      // Determine device priority to prevent race condition
      // Device with alphabetically first user ID is device 0 (generates)
      // Device with alphabetically second user ID is device 1 (loads)
      final sortedIds = [currentUserId, partnerUserId]..sort();
      final isSecondDevice = currentUserId == sortedIds[1];

      if (isSecondDevice) {
        // Second device waits 3 seconds to allow first device to generate and sync
        Logger.debug('   ⏱️  Second device detected - waiting 3 seconds for first device to generate quests...', service: 'quest');
        await Future.delayed(const Duration(seconds: 3));
      }

      // ALWAYS check Firebase first (with retry for second device)
      Logger.debug('   📡 Checking Firebase for existing quests...', service: 'quest');
      final questsRef = _database.child('daily_quests/$coupleId/$dateKey');

      DataSnapshot snapshot = await questsRef.get();

      // If second device and Firebase is still empty, retry once after 2 more seconds
      if (isSecondDevice && (!snapshot.exists || snapshot.value == null)) {
        Logger.debug('   ⏱️  Firebase still empty - retrying in 2 seconds...', service: 'quest');
        await Future.delayed(const Duration(seconds: 2));
        snapshot = await questsRef.get();
      }

      if (snapshot.exists && snapshot.value != null) {
        // Firebase has quests - validate local quests match
        final data = snapshot.value as Map<dynamic, dynamic>;
        final questsData = data['quests'] as List<dynamic>;

        // Get Firebase quest IDs
        final firebaseQuestIds = questsData.map((q) => (q as Map)['id'] as String).toSet();

        // Check if local quests exist
        final localQuests = _storage.getTodayQuests();

        if (localQuests.isNotEmpty) {
          // Get local quest IDs
          final localQuestIds = localQuests.map((q) => q.id).toSet();

          // Check if quest IDs match
          if (firebaseQuestIds.difference(localQuestIds).isEmpty &&
              localQuestIds.difference(firebaseQuestIds).isEmpty) {
            // Quest IDs match - just sync completion status
            Logger.debug('   ✅ Local quests match Firebase - syncing completion only', service: 'quest');
            await _syncCompletionStatus(coupleId, dateKey, currentUserId);
            return true;
          } else {
            // Quest IDs don't match - replace local with Firebase
            Logger.debug('   ⚠️  Local quest IDs don\'t match Firebase!', service: 'quest');
            Logger.debug('   Firebase IDs: $firebaseQuestIds', service: 'quest');
            Logger.debug('   Local IDs: $localQuestIds', service: 'quest');
            Logger.debug('   🔄 Replacing local quests with Firebase quests...', service: 'quest');

            // Clear local quests
            for (final quest in localQuests) {
              await quest.delete();
            }
          }
        }

        // Load quests from Firebase (either no local quests or mismatched IDs)
        Logger.debug('   ✅ Loading quests from Firebase...', service: 'quest');
        await _loadQuestsFromFirebase(snapshot, dateKey);
        return true;
      } else {
        // No Firebase quests yet
        final localQuests = _storage.getTodayQuests();
        if (localQuests.isNotEmpty) {
          // Local quests exist but not in Firebase - SAVE THEM to Firebase
          Logger.debug('   📤 Local quests exist but not in Firebase - uploading to Firebase...', service: 'quest');

          // Save quests to Firebase so partner can load them
          await saveQuestsToFirebase(
            quests: localQuests,
            currentUserId: currentUserId,
            partnerUserId: partnerUserId,
          );

          Logger.debug('   ✅ Local quests synced to Firebase', service: 'quest');
          return true;
        } else {
          // No quests anywhere - need to generate
          Logger.debug('   ⚠️  No quests in Firebase or locally - will generate new ones', service: 'quest');
          return false; // Indicates quests need to be generated
        }
      }
    } catch (e) {
      Logger.error('Error syncing quests', error: e, service: 'quest');
      return false;
    }
  }

  /// Save generated quests to Firebase AND Supabase (Dual-Write)
  ///
  /// PHASE 4: When useSuperbaseForDailyQuests is TRUE, uses Supabase-only path
  Future<void> saveQuestsToFirebase({
    required List<DailyQuest> quests,
    required String currentUserId,
    required String partnerUserId,
    QuizProgressionState? progressionState,
  }) async {
    // PHASE 4: Supabase-only path (flag-gated)
    if (DevConfig.useSuperbaseForDailyQuests) {
      return _saveQuestsToSupabaseOnly(quests);
    }

    // OLD PATH: Firebase + dual-write (default)
    try {
      final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
      final dateKey = QuestUtilities.getTodayDateKey();

      final questsRef = _database.child('daily_quests/$coupleId/$dateKey');

      // Convert quests to JSON
      final questsData = quests.map((q) => {
        'id': q.id,
        'questType': q.questType,
        'contentId': q.contentId,
        'sortOrder': q.sortOrder,
        'isSideQuest': q.isSideQuest,
        'formatType': q.formatType,
        'quizName': q.quizName,
      }).toList();

      // 1. Save to Firebase (Primary)
      await questsRef.set({
        'quests': questsData,
        'generatedBy': currentUserId,
        'generatedAt': ServerValue.timestamp,
        'dateKey': dateKey,
        'progression': progressionState != null ? {
          'currentTrack': progressionState.currentTrack,
          'currentPosition': progressionState.currentPosition,
          'totalCompleted': progressionState.totalQuizzesCompleted,
        } : null,
      });

      Logger.debug('Saved ${quests.length} quests to Firebase for $dateKey', service: 'quest');

      // 2. Save to Supabase (Secondary - Dual Write)
      // We do this asynchronously and don't block if it fails
      _saveQuestsToSupabase(quests, dateKey).catchError((e) {
        Logger.error('Supabase dual-write failed (saveQuests)', error: e, service: 'quest');
      });

    } catch (e) {
      Logger.error('Error saving quests to Firebase', error: e, service: 'quest');
      rethrow;
    }
  }

  /// Save quests to Supabase (Dual-Write Implementation)
  Future<void> _saveQuestsToSupabase(List<DailyQuest> quests, String dateKey) async {
    try {
      Logger.debug('🚀 Attempting dual-write to Supabase (saveQuests)...', service: 'quest');
      
      final response = await _apiClient.post('/api/sync/daily-quests', body: {
        'dateKey': dateKey,
        'quests': quests.map((q) => {
          'id': q.id,
          'questType': q.type.name, // Send string name (e.g. 'quiz')
          'contentId': q.contentId,
          'sortOrder': q.sortOrder,
          'isSideQuest': q.isSideQuest,
          'formatType': q.formatType,
          'quizName': q.quizName,
        }).toList(),
      });

      if (response.success) {
        Logger.debug('✅ Supabase dual-write successful!', service: 'quest');
      } else {
        Logger.error('Supabase dual-write failed: ${response.error}', service: 'quest');
      }
    } catch (e) {
      Logger.error('Supabase dual-write exception', error: e, service: 'quest');
    }
  }

  /// Load quests from Firebase snapshot
  Future<void> _loadQuestsFromFirebase(
    DataSnapshot snapshot,
    String dateKey,
  ) async {
    try {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final questsData = data['quests'] as List<dynamic>;

      // Load completion data from Firebase
      final completionsData = data['completions'] as Map<dynamic, dynamic>?;

      for (final questData in questsData) {
        final questMap = questData as Map<dynamic, dynamic>;
        final questId = questMap['id'] as String;

        final now = DateTime.now();
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        // Get completions for this quest from Firebase
        Map<String, bool>? userCompletions;
        if (completionsData != null && completionsData.containsKey(questId)) {
          final questCompletions = completionsData[questId] as Map<dynamic, dynamic>;
          userCompletions = {};
          questCompletions.forEach((userId, completed) {
            if (completed == true) {
              userCompletions![userId.toString()] = true;
            }
          });
        }

        // Determine status based on completions
        String status = 'pending';
        if (userCompletions != null && userCompletions.isNotEmpty) {
          // Check if both users completed (assuming 2 users)
          if (userCompletions.length >= 2) {
            status = 'completed';
          } else {
            status = 'in_progress';
          }
        }

        // Create DailyQuest from Firebase data, preserving the original ID
        final quest = DailyQuest(
          id: questId, // CRITICAL: Use ID from Firebase!
          dateKey: dateKey,
          questType: questMap['questType'] as int,
          contentId: questMap['contentId'] as String,
          createdAt: now,
          expiresAt: endOfDay,
          status: status,
          sortOrder: questMap['sortOrder'] as int,
          isSideQuest: questMap['isSideQuest'] as bool? ?? false,
          formatType: questMap['formatType'] as String? ?? 'classic',
          quizName: questMap['quizName'] as String?,
          userCompletions: userCompletions,
        );

        // Save locally
        await _storage.saveDailyQuest(quest);
      }

      Logger.debug('Loaded ${questsData.length} quests from Firebase with preserved IDs and completions', service: 'quest');
    } catch (e) {
      Logger.error('Error loading quests from Firebase', error: e, service: 'quest');
      rethrow;
    }
  }

  /// Sync completion status with Firebase
  Future<void> _syncCompletionStatus(
    String coupleId,
    String dateKey,
    String userId,
  ) async {
    try {
      final completionsRef = _database.child('daily_quests/$coupleId/$dateKey/completions');
      final quests = _storage.getDailyQuestsForDate(dateKey);

      // Update completion status for each quest
      for (final quest in quests) {
        if (quest.hasUserCompleted(userId)) {
          await completionsRef.child('${quest.id}/$userId').set(true);
        }
      }
    } catch (e) {
      Logger.error('Error syncing completion status', error: e, service: 'quest');
    }
  }

  /// Listen for partner quest completions
  ///
  /// Returns a stream of quest IDs that the partner completed
  Stream<Map<String, dynamic>> listenForPartnerCompletions({
    required String currentUserId,
    required String partnerUserId,
  }) {
    final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
    final dateKey = QuestUtilities.getTodayDateKey();

    final completionsRef = _database.child('daily_quests/$coupleId/$dateKey/completions');

    return completionsRef.onValue.map((event) {
      if (event.snapshot.value == null) return <String, dynamic>{};

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final completions = <String, dynamic>{};

      // Filter for partner's completions
      data.forEach((questId, users) {
        if (users is Map && users[partnerUserId] == true) {
          completions[questId.toString()] = true;
        }
      });

      return completions;
    });
  }

  /// Mark quest as completed for current user in Firebase AND Supabase (Dual-Write)
  Future<void> markQuestCompleted({
    required String questId,
    required String currentUserId,
    required String partnerUserId,
  }) async {
    try {
      final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
      final dateKey = QuestUtilities.getTodayDateKey();

      // 1. Firebase Write (Primary)
      final completionRef = _database.child('daily_quests/$coupleId/$dateKey/completions/$questId/$currentUserId');
      await completionRef.set(true);

      Logger.debug('Marked quest $questId as completed for $currentUserId in Firebase', service: 'quest');

      // 2. Supabase Write (Secondary - Dual Write)
      _markQuestCompletedInSupabase(questId, currentUserId).catchError((e) {
        Logger.error('Supabase dual-write failed (markCompleted)', error: e, service: 'quest');
      });

    } catch (e) {
      Logger.error('Error marking quest completed in Firebase', error: e, service: 'quest');
    }
  }

  /// Mark quest completed in Supabase (Dual-Write Implementation)
  Future<void> _markQuestCompletedInSupabase(String questId, String userId) async {
    try {
      Logger.debug('🚀 Attempting dual-write to Supabase (markCompleted)...', service: 'quest');

      final response = await _apiClient.post('/api/sync/daily-quests/completion', body: {
        'quest_id': questId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (response.success) {
        Logger.debug('✅ Supabase dual-write successful!', service: 'quest');
      } else {
        Logger.error('Supabase dual-write failed: ${response.error}', service: 'quest');
      }
    } catch (e) {
      Logger.error('Supabase dual-write exception', error: e, service: 'quest');
    }
  }

  /// Load quiz progression state from Firebase
  Future<QuizProgressionState?> loadProgressionState({
    required String currentUserId,
    required String partnerUserId,
  }) async {
    try {
      final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
      final progressionRef = _database.child('quiz_progression/$coupleId');

      final snapshot = await progressionRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Convert Firebase data to QuizProgressionState
        final state = QuizProgressionState(
          coupleId: coupleId,
          currentTrack: data['currentTrack'] as int,
          currentPosition: data['currentPosition'] as int,
          completedQuizzes: Map<String, bool>.from(data['completedQuizzes'] as Map? ?? {}),
          createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int),
          lastCompletedAt: data['lastCompletedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['lastCompletedAt'] as int)
              : null,
          totalQuizzesCompleted: data['totalQuizzesCompleted'] as int? ?? 0,
          hasCompletedAllTracks: data['hasCompletedAllTracks'] as bool? ?? false,
        );

        // Save locally
        await _storage.saveQuizProgressionState(state);

        return state;
      }

      return null;
    } catch (e) {
      Logger.error('Error loading progression state', error: e, service: 'quest');
      return null;
    }
  }

  /// Save quiz progression state to Firebase
  Future<void> saveProgressionState(
    QuizProgressionState state,
  ) async {
    try {
      final progressionRef = _database.child('quiz_progression/${state.coupleId}');

      await progressionRef.set({
        'currentTrack': state.currentTrack,
        'currentPosition': state.currentPosition,
        'completedQuizzes': state.completedQuizzes,
        'createdAt': state.createdAt.millisecondsSinceEpoch,
        'lastCompletedAt': state.lastCompletedAt?.millisecondsSinceEpoch,
        'totalQuizzesCompleted': state.totalQuizzesCompleted,
        'hasCompletedAllTracks': state.hasCompletedAllTracks,
      });

      Logger.debug('Saved progression state to Firebase', service: 'quest');
    } catch (e) {
      Logger.error('Error saving progression state', error: e, service: 'quest');
      rethrow;
    }
  }

  /// Clean up old quest data from Firebase (older than 7 days)
  Future<void> cleanupOldQuests({
    required String currentUserId,
    required String partnerUserId,
  }) async {
    try {
      final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
      final questsRef = _database.child('daily_quests/$coupleId');

      final snapshot = await questsRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now();

      for (final dateKey in data.keys) {
        try {
          final dateParts = (dateKey as String).split('-');
          final questDate = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );

          if (now.difference(questDate).inDays > 7) {
            await questsRef.child(dateKey).remove();
            Logger.debug('Cleaned up old quests for $dateKey', service: 'quest');
          }
        } catch (e) {
          Logger.error('Error parsing date key $dateKey', error: e, service: 'quest');
        }
      }
    } catch (e) {
      Logger.error('Error cleaning up old quests', error: e, service: 'quest');
    }
  }

  // ============================================================================
  // PHASE 4: SUPABASE-ONLY METHODS (Flag-gated)
  // ============================================================================

  /// Sync today's quests from Supabase (Supabase-only path)
  /// Used when DevConfig.useSuperbaseForDailyQuests is TRUE
  Future<bool> _syncTodayQuestsSupabase(
    String currentUserId,
    String partnerUserId,
  ) async {
    try {
      final dateKey = QuestUtilities.getTodayDateKey();

      Logger.debug('🔄 Quest Sync Check (Supabase):', service: 'quest');
      Logger.debug('   Date Key: $dateKey', service: 'quest');

      // Determine device priority (same as Firebase)
      final sortedIds = [currentUserId, partnerUserId]..sort();
      final isSecondDevice = currentUserId == sortedIds[1];

      if (isSecondDevice) {
        Logger.debug('   ⏱️  Second device detected - waiting 3 seconds...', service: 'quest');
        await Future.delayed(const Duration(seconds: 3));
      }

      // Try to fetch from Supabase
      Logger.debug('   📡 Checking Supabase for existing quests...', service: 'quest');
      final response = await _apiClient.get('/api/sync/daily-quests?date=$dateKey');

      if (response.success && response.data != null) {
        final questsData = response.data['quests'] as List?;

        if (questsData != null && questsData.isNotEmpty) {
          // Quests exist in Supabase - validate local quests match
          final firebaseQuestIds = questsData.map((q) => q['id'] as String).toSet();
          final localQuests = _storage.getTodayQuests();

          if (localQuests.isNotEmpty) {
            final localQuestIds = localQuests.map((q) => q.id).toSet();

            if (firebaseQuestIds.difference(localQuestIds).isEmpty &&
                localQuestIds.difference(firebaseQuestIds).isEmpty) {
              // Quest IDs match - already synced
              Logger.debug('   ✅ Local quests match Supabase', service: 'quest');
              return true;
            } else {
              // Quest IDs don't match - replace with Supabase
              Logger.debug('   ⚠️  Local quest IDs don\'t match Supabase!', service: 'quest');
              Logger.debug('   Supabase IDs: $firebaseQuestIds', service: 'quest');
              Logger.debug('   Local IDs: $localQuestIds', service: 'quest');
              Logger.debug('   🔄 Replacing local quests with Supabase quests...', service: 'quest');

              // Clear local quests
              for (final quest in localQuests) {
                await quest.delete();
              }
            }
          }

          // Load quests from Supabase
          Logger.debug('   ✅ Loading quests from Supabase...', service: 'quest');
          await _loadQuestsFromSupabase(questsData, dateKey);
          return true;
        }
      }

      // If second device and still no quests, retry once
      if (isSecondDevice) {
        Logger.debug('   ⏱️  Supabase still empty - retrying in 2 seconds...', service: 'quest');
        await Future.delayed(const Duration(seconds: 2));

        final retryResponse = await _apiClient.get('/api/sync/daily-quests?date=$dateKey');
        if (retryResponse.success && retryResponse.data != null) {
          final questsData = retryResponse.data['quests'] as List?;
          if (questsData != null && questsData.isNotEmpty) {
            await _loadQuestsFromSupabase(questsData, dateKey);
            return true;
          }
        }
      }

      // No quests in Supabase yet
      if (_storage.getTodayQuests().isNotEmpty) {
        // Local quests exist but not in Supabase - already generated locally
        Logger.debug('   ✅ Local quests exist but not in Supabase', service: 'quest');
        return true;
      } else {
        // No quests anywhere - need to generate
        Logger.debug('   ⚠️  No quests in Supabase or locally - will generate new ones', service: 'quest');
        return false;
      }
    } catch (e) {
      Logger.error('Error syncing quests from Supabase', error: e, service: 'quest');
      return false;
    }
  }

  /// Load quests from Supabase API response
  Future<void> _loadQuestsFromSupabase(
    List<dynamic> questsData,
    String dateKey,
  ) async {
    try {
      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      for (final questData in questsData) {
        final questMap = questData as Map<String, dynamic>;
        final questId = questMap['id'] as String;

        // Parse metadata
        final metadata = questMap['metadata'] as Map<String, dynamic>?;
        final formatType = metadata?['formatType'] as String? ?? 'classic';
        final quizName = metadata?['quizName'] as String?;

        // Parse quest type from string
        final questTypeStr = questMap['quest_type'] as String;
        final questType = _parseQuestType(questTypeStr);

        // Create DailyQuest from Supabase data
        final quest = DailyQuest(
          id: questId,
          dateKey: dateKey,
          questType: questType,
          contentId: questMap['content_id'] as String,
          createdAt: now,
          expiresAt: endOfDay,
          status: 'pending',
          sortOrder: questMap['sort_order'] as int,
          isSideQuest: questMap['is_side_quest'] as bool? ?? false,
          formatType: formatType,
          quizName: quizName,
          userCompletions: null,
        );

        // Save locally
        await _storage.saveDailyQuest(quest);
      }

      Logger.success('Loaded ${questsData.length} quests from Supabase', service: 'quest');
    } catch (e) {
      Logger.error('Error loading quests from Supabase', error: e, service: 'quest');
      rethrow;
    }
  }

  /// Parse quest type string to int (for DailyQuest model)
  int _parseQuestType(String questTypeStr) {
    // Map quest type strings to their int values
    // These match the QuestType enum values
    switch (questTypeStr.toLowerCase()) {
      case 'quiz':
        return 1; // QuestType.quiz
      case 'you_or_me':
        return 3; // QuestType.youOrMe
      case 'linked':
        return 4; // QuestType.linked
      case 'word_search':
        return 5; // QuestType.wordSearch
      case 'steps':
        return 6; // QuestType.steps
      default:
        Logger.warn('Unknown quest type: $questTypeStr, defaulting to quiz', service: 'quest');
        return 1; // Default to quiz
    }
  }

  /// Save quests to Supabase (Supabase-only path)
  /// Used when DevConfig.useSuperbaseForDailyQuests is TRUE
  Future<void> _saveQuestsToSupabaseOnly(
    List<DailyQuest> quests,
  ) async {
    try {
      final dateKey = QuestUtilities.getTodayDateKey();

      Logger.debug('🚀 Saving quests to Supabase (Supabase-only)...', service: 'quest');

      final response = await _apiClient.post('/api/sync/daily-quests', body: {
        'dateKey': dateKey,
        'quests': quests.map((q) => {
          'id': q.id,
          'questType': _getQuestTypeString(q.type),
          'contentId': q.contentId,
          'sortOrder': q.sortOrder,
          'isSideQuest': q.isSideQuest,
          'formatType': q.formatType,
          'quizName': q.quizName,
        }).toList(),
      });

      if (response.success) {
        Logger.success('Saved ${quests.length} quests to Supabase', service: 'quest');
      } else {
        Logger.error('Failed to save quests to Supabase: ${response.error}', service: 'quest');
        throw Exception('Failed to save quests to Supabase');
      }
    } catch (e) {
      Logger.error('Error saving quests to Supabase', error: e, service: 'quest');
      rethrow;
    }
  }

  /// Get quest type string from QuestType enum
  String _getQuestTypeString(QuestType type) {
    return type.name; // Returns 'quiz', 'memoryFlip', etc.
  }
}
