import 'dart:async';
import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../services/quiz_service.dart';
import '../widgets/quest_card.dart';
import '../screens/quiz_question_screen.dart';
import '../screens/quiz_results_screen.dart';

/// Widget displaying daily quests with completion tracking
///
/// Shows 3 daily quests with visual progress tracker and completion banner
class DailyQuestsWidget extends StatefulWidget {
  const DailyQuestsWidget({Key? key}) : super(key: key);

  @override
  State<DailyQuestsWidget> createState() => _DailyQuestsWidgetState();
}

class _DailyQuestsWidgetState extends State<DailyQuestsWidget> {
  final StorageService _storage = StorageService();
  late DailyQuestService _questService;
  late QuestSyncService _questSyncService;
  final QuizService _quizService = QuizService();
  StreamSubscription? _partnerCompletionSubscription;

  @override
  void initState() {
    super.initState();
    _questService = DailyQuestService(
      storage: _storage,
    );
    _questSyncService = QuestSyncService(
      storage: _storage,
    );

    // Listen for partner quest completions
    _listenForPartnerCompletions();

    // Quest generation happens in main.dart on app start
  }

  /// Listen for partner's quest completions in real-time
  void _listenForPartnerCompletions() {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      return; // Can't listen without both users
    }

    _partnerCompletionSubscription = _questSyncService
        .listenForPartnerCompletions(
          currentUserId: user.id,
          partnerUserId: partner.pushToken,
        )
        .listen((partnerCompletions) {
      // partnerCompletions is a map of {questId: true} for completed quests
      if (partnerCompletions.isEmpty) return;

      print('📥 Received partner quest completions: ${partnerCompletions.keys.join(", ")}');

      // Update local storage with partner's completions
      for (final questId in partnerCompletions.keys) {
        final quest = _storage.getDailyQuest(questId);
        print('🔍 Looking for quest: $questId');
        print('🔍 Found quest: ${quest != null ? quest.id : "NULL"}');
        if (quest != null) {
          print('🔍 Partner already completed? ${quest.hasUserCompleted(partner.pushToken)}');
          print('🔍 Partner user ID: ${partner.pushToken}');
          print('🔍 Quest completions: ${quest.userCompletions}');
        }
        if (quest != null && !quest.hasUserCompleted(partner.pushToken)) {
          quest.userCompletions ??= {};
          quest.userCompletions![partner.pushToken] = true;

          // Check if both completed now
          if (quest.areBothUsersCompleted()) {
            quest.status = 'completed';
            quest.completedAt = DateTime.now();

            // Award LP if not already awarded (prevent duplicates)
            if (quest.lpAwarded == null || quest.lpAwarded == 0) {
              quest.lpAwarded = 30;

              print('💰 Auto-awarding 30 LP for completed quest: ${quest.type.name}');

              LovePointService.awardPointsToBothUsers(
                userId1: user.id,
                userId2: partner.pushToken,
                amount: 30,
                reason: 'daily_quest_${quest.type.name}',
                relatedId: quest.id,
              ).then((_) {
                print('✅ LP awarded automatically via partner completion listener');
              }).catchError((error) {
                print('❌ Error awarding LP: $error');
              });
            }
          } else {
            quest.status = 'in_progress';
          }

          _storage.updateDailyQuest(quest);
          print('✅ Updated quest ${quest.type.name} with partner completion');
        }
      }

      // Trigger UI rebuild
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _partnerCompletionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final quests = _questService.getMainDailyQuests();
    final allCompleted = _questService.areAllMainQuestsCompleted();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Daily Quests',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Quests list with progress tracker
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: quests.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    for (int i = 0; i < quests.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i < quests.length - 1 ? 14 : 0),
                        child: _buildQuestItem(quests[i], i, user?.id),
                      ),
                  ],
                ),
        ),

        // Completion banner
        if (allCompleted) _buildCompletionBanner(),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuestItem(DailyQuest quest, int index, String? userId) {
    final isCompleted = quest.isCompleted;
    final userCompleted = userId != null && quest.hasUserCompleted(userId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Completion tracker
        Column(
          children: [
            // Check circle
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.black : Colors.white,
                border: Border.all(
                  color: isCompleted ? Colors.black : const Color(0xFFE0E0E0),
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : const Text(
                        '○',
                        style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            // Track line (only if not last item)
            if (index < 2)
              Container(
                width: 2,
                height: 70,
                margin: const EdgeInsets.symmetric(vertical: 5),
                color: isCompleted ? Colors.black : const Color(0xFFE0E0E0),
              ),
          ],
        ),

        const SizedBox(width: 14),

        // Quest card
        Expanded(
          child: QuestCard(
            quest: quest,
            currentUserId: userId,
            onTap: () => _handleQuestTap(quest),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No Daily Quests Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check back tomorrow for new quests!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text(
              '✅',
              style: TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Way to go! You\'ve completed your Daily Quests',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuestTap(DailyQuest quest) async {
    // Navigate based on quest type
    switch (quest.type) {
      case QuestType.quiz:
        await _handleQuizQuestTap(quest);
        break;

      case QuestType.wordLadder:
        // TODO: Navigate to Word Ladder screen
        break;

      case QuestType.memoryFlip:
        // TODO: Navigate to Memory Flip screen
        break;

      case QuestType.question:
        // TODO: Navigate to Question screen
        break;

      case QuestType.game:
        // TODO: Navigate to Game screen
        break;
    }

    // Refresh state after returning
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleQuizQuestTap(DailyQuest quest) async {
    // Get quiz session - try local storage first, then fetch from Firebase
    final session = await _quizService.getSession(quest.contentId);

    if (session == null) {
      _showError('Quiz session not found');
      return;
    }

    // Check if quest is completed by both users (regardless of session status)
    // This handles cases where quest completion is synced but session status isn't
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final bothCompletedQuest = quest.isCompleted ||
                                (user != null && partner != null &&
                                 quest.hasUserCompleted(user.id) &&
                                 quest.hasUserCompleted(partner.pushToken));

    // Navigate based on completion status
    if (session.isCompleted || bothCompletedQuest) {
      // Navigate to results
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizResultsScreen(session: session),
        ),
      );
    } else {
      // Navigate to quiz
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizQuestionScreen(session: session),
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
