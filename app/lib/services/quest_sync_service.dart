import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_quest.dart';
import '../models/quiz_progression_state.dart';
import '../services/storage_service.dart';
import '../services/quest_utilities.dart';

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

      debugPrint('🔄 Quest Sync Check:');
      debugPrint('   Couple ID: $coupleId');
      debugPrint('   Date Key: $dateKey');
      debugPrint('   Firebase Path: /daily_quests/$coupleId/$dateKey');

      // ALWAYS check Firebase first
      debugPrint('   📡 Checking Firebase for existing quests...');
      final questsRef = _database.child('daily_quests/$coupleId/$dateKey');
      final snapshot = await questsRef.get();

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
            debugPrint('   ✅ Local quests match Firebase - syncing completion only');
            await _syncCompletionStatus(coupleId, dateKey, currentUserId);
            return true;
          } else {
            // Quest IDs don't match - replace local with Firebase
            debugPrint('   ⚠️  Local quest IDs don\'t match Firebase!');
            debugPrint('   Firebase IDs: $firebaseQuestIds');
            debugPrint('   Local IDs: $localQuestIds');
            debugPrint('   🔄 Replacing local quests with Firebase quests...');

            // Clear local quests
            for (final quest in localQuests) {
              await quest.delete();
            }
          }
        }

        // Load quests from Firebase (either no local quests or mismatched IDs)
        debugPrint('   ✅ Loading quests from Firebase...');
        await _loadQuestsFromFirebase(snapshot, dateKey);
        return true;
      } else {
        // No Firebase quests yet
        if (_storage.getTodayQuests().isNotEmpty) {
          // Local quests exist but not in Firebase - sync them
          debugPrint('   ✅ Local quests exist but not in Firebase - syncing completion');
          await _syncCompletionStatus(coupleId, dateKey, currentUserId);
          return true;
        } else {
          // No quests anywhere - need to generate
          debugPrint('   ⚠️  No quests in Firebase or locally - will generate new ones');
          return false; // Indicates quests need to be generated
        }
      }
    } catch (e) {
      debugPrint('Error syncing quests: $e');
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

      debugPrint('Saved ${quests.length} quests to Firebase for $dateKey');
    } catch (e) {
      debugPrint('Error saving quests to Firebase: $e');
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

      debugPrint('Loaded ${questsData.length} quests from Firebase with preserved IDs and completions');
    } catch (e) {
      debugPrint('Error loading quests from Firebase: $e');
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
      debugPrint('Error syncing completion status: $e');
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

      debugPrint('Marked quest $questId as completed for $currentUserId in Firebase');
    } catch (e) {
      debugPrint('Error marking quest completed in Firebase: $e');
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
      debugPrint('Error loading progression state: $e');
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

      debugPrint('Saved progression state to Firebase');
    } catch (e) {
      debugPrint('Error saving progression state: $e');
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
            debugPrint('Cleaned up old quests for $dateKey');
          }
        } catch (e) {
          debugPrint('Error parsing date key $dateKey: $e');
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old quests: $e');
    }
  }
}
