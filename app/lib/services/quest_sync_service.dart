import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_quest.dart';
import '../models/quiz_progression_state.dart';
import '../services/storage_service.dart';
import '../services/quest_utilities.dart';
import '../utils/logger.dart';

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

  QuestSyncService({
    required StorageService storage,
  })  : _storage = storage,
        _database = FirebaseDatabase.instance.ref();

  /// Sync today's quests from Firebase or generate if first user
  ///
  /// Returns true if sync was successful
  Future<bool> syncTodayQuests({
    required String currentUserId,
    required String partnerUserId,
  }) async {
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
        if (_storage.getTodayQuests().isNotEmpty) {
          // Local quests exist but not in Firebase - sync them
          Logger.debug('   ✅ Local quests exist but not in Firebase - syncing completion', service: 'quest');
          await _syncCompletionStatus(coupleId, dateKey, currentUserId);
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

  /// Save generated quests to Firebase
  Future<void> saveQuestsToFirebase({
    required List<DailyQuest> quests,
    required String currentUserId,
    required String partnerUserId,
    QuizProgressionState? progressionState,
  }) async {
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

      // Save to Firebase
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
    } catch (e) {
      Logger.error('Error saving quests to Firebase', error: e, service: 'quest');
      rethrow;
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

  /// Mark quest as completed for current user in Firebase
  Future<void> markQuestCompleted({
    required String questId,
    required String currentUserId,
    required String partnerUserId,
  }) async {
    try {
      final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
      final dateKey = QuestUtilities.getTodayDateKey();

      final completionRef = _database.child('daily_quests/$coupleId/$dateKey/completions/$questId/$currentUserId');
      await completionRef.set(true);

      Logger.debug('Marked quest $questId as completed for $currentUserId in Firebase', service: 'quest');
    } catch (e) {
      Logger.error('Error marking quest completed in Firebase', error: e, service: 'quest');
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
}
