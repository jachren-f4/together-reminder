import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../models/daily_quest.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../services/quest_utilities.dart';

class QuizResultsScreen extends StatefulWidget {
  final QuizSession session;

  const QuizResultsScreen({super.key, required this.session});

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  late ConfettiController _confettiController;
  late List<QuizQuestion> _questions;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _questions = _quizService.getSessionQuestions(widget.session);

    // Show confetti for high matches
    if ((widget.session.matchPercentage ?? 0) >= 80) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confettiController.play();
      });
    }

    // Check and complete associated daily quest
    _checkQuestCompletion();
  }

  /// Check if this quiz session is linked to a daily quest and mark it as completed
  Future<void> _checkQuestCompletion() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      // Check if there's a daily quest for this quiz session
      final questService = DailyQuestService(storage: _storage);
      final todayQuests = questService.getTodayQuests();

      // Removed verbose logging
      // print('🔍 Checking quest completion for session: ${widget.session.id}');
      // print('🔍 Found ${todayQuests.length} today quests');
      // for (final q in todayQuests) {
      //   print('🔍 Quest ${q.id}: type=${q.type}, contentId=${q.contentId}');
      // }

      // Find quest with matching contentId (quiz session ID)
      final matchingQuest = todayQuests.where((q) =>
        q.type == QuestType.quiz && q.contentId == widget.session.id
      ).firstOrNull;

      if (matchingQuest == null) {
        // Removed verbose logging
        // print('❌ No matching quest found for session ${widget.session.id}');
        // Not a daily quest quiz - just a regular quiz
        return;
      }

      // Removed verbose logging
      // print('✅ Found matching quest: ${matchingQuest.id}');

      // Check if current user has completed all questions
      final userAnswers = widget.session.answers?[user.id];
      if (userAnswers == null || userAnswers.length < widget.session.questionIds.length) {
        return; // User hasn't completed the quiz yet
      }

      // Mark quest as completed for this user
      final bothCompleted = await questService.completeQuestForUser(
        questId: matchingQuest.id,
        userId: user.id,
      );

      // Sync with Firebase
      final syncService = QuestSyncService(
        storage: _storage,
      );

      await syncService.markQuestCompleted(
        questId: matchingQuest.id,
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );

      if (bothCompleted) {
        // Removed verbose logging
        // print('✅ Daily quest completed by both users! Awarding 30 LP...');

        // Award Love Points to BOTH users via Firebase (real-time sync)
        await LovePointService.awardPointsToBothUsers(
          userId1: user.id,
          userId2: partner.pushToken,
          amount: 30,
          reason: 'daily_quest_quiz',
          relatedId: matchingQuest.id,
        );

        // Check if all 3 daily quests are completed
        await _checkDailyQuestsCompletion(questService, user.id, partner.pushToken);
      } else {
        // Removed verbose logging
        // print('✅ Quest progress saved - waiting for partner to complete');
      }
    } catch (e) {
      print('❌ Error checking quest completion: $e');
      // Don't block results screen on quest errors
    }
  }

  /// Check if all daily quests are completed and advance progression if so
  Future<void> _checkDailyQuestsCompletion(
    DailyQuestService questService,
    String currentUserId,
    String partnerUserId,
  ) async {
    try {
      // Check if all main daily quests are completed by both users
      if (questService.areAllMainQuestsCompleted()) {
        // Removed verbose logging
        // print('🎯 All daily quests completed! Advancing progression...');

        // Get the couple ID using QuestUtilities
        final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);

        // Get current progression state
        var progressionState = _storage.getQuizProgressionState(coupleId);
        if (progressionState == null) {
          // Removed verbose logging
          // print('⚠️  No progression state found');
          return;
        }

        // Advance progression by 3 positions (for the 3 completed quests)
        for (int i = 0; i < 3; i++) {
          progressionState.currentPosition++;
          if (progressionState.currentPosition >= 4) {
            progressionState.currentTrack++;
            progressionState.currentPosition = 0;
            if (progressionState.currentTrack >= 3) {
              progressionState.hasCompletedAllTracks = true;
              progressionState.currentTrack = 2;
              progressionState.currentPosition = 3;
              break; // Max progression reached
            }
          }
        }

        // Save updated progression
        await _storage.updateQuizProgressionState(progressionState);
        // Removed verbose logging
        // print('📈 Progression advanced to Track ${progressionState.currentTrack}, Position ${progressionState.currentPosition}');

        // Save to Firebase
        final syncService = QuestSyncService(
          storage: _storage,
        );
        await syncService.saveProgressionState(progressionState);
        // Removed verbose logging
        // print('✅ Progression state saved to Firebase');
      }
    } catch (e) {
      print('❌ Error checking daily quests completion: $e');
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // Check if current user is the subject or predictor
  bool get _isSubject {
    final user = _storage.getUser();
    if (user == null) return false;
    return widget.session.isUserSubject(user.id);
  }

  String _getMatchMessage(int percentage) {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Your partner';

    if (_isSubject) {
      // Subject sees how well partner knows them
      if (percentage == 100) return '$partnerName knows you perfectly!';
      if (percentage >= 80) return '$partnerName knows you really well!';
      if (percentage >= 60) return '$partnerName is learning about you!';
      if (percentage >= 40) return '$partnerName learned something new!';
      return '$partnerName discovered new things about you!';
    } else {
      // Predictor sees how well they know partner
      if (percentage == 100) return 'You knew $partnerName perfectly!';
      if (percentage >= 80) return 'You know $partnerName really well!';
      if (percentage >= 60) return 'You\'re learning $partnerName well!';
      if (percentage >= 40) return 'You learned more about $partnerName!';
      return 'You\'re discovering $partnerName!';
    }
  }

  String _getMatchDescription(int percentage) {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'your partner';

    if (_isSubject) {
      // Subject perspective
      if (percentage == 100) {
        return '$partnerName predicted all your answers correctly! You earned a Perfect Sync badge 🏆';
      }
      if (percentage >= 80) {
        return '$partnerName really understands you! Amazing connection!';
      }
      if (percentage >= 60) {
        return 'Here\'s what $partnerName learned about you today.';
      }
      return '$partnerName is getting to know you better with each quiz!';
    } else {
      // Predictor perspective
      if (percentage == 100) {
        return 'You predicted all of $partnerName\'s answers! You earned a Perfect Sync badge 🏆';
      }
      if (percentage >= 80) {
        return 'Your prediction accuracy is incredible! You really know $partnerName!';
      }
      if (percentage >= 60) {
        return 'You\'re building a strong understanding of $partnerName!';
      }
      return 'Keep learning about $partnerName - every quiz brings you closer!';
    }
  }

  Color _getMatchColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchPercentage = widget.session.matchPercentage ?? 0;
    final lpEarned = widget.session.lpEarned ?? 0;
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final answers = widget.session.answers ?? {};
    final userIds = answers.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Pop all quiz screens and return to activities
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Match percentage circle
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _getMatchColor(matchPercentage),
                            _getMatchColor(matchPercentage).withOpacity(0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getMatchColor(matchPercentage).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$matchPercentage%',
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'MATCH',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Match message
                  Text(
                    _getMatchMessage(matchPercentage),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _getMatchDescription(matchPercentage),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // LP earned card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.secondaryContainer,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Text(
                          '+$lpEarned LP Earned!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Show details button
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    icon: Icon(_showDetails ? Icons.expand_less : Icons.expand_more),
                    label: Text(_showDetails ? 'Hide Details' : 'Show Answer Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),

                  // Answer details
                  if (_showDetails && userIds.length >= 2) ...[
                    const SizedBox(height: 24),
                    ..._questions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final question = entry.value;
                      final user1Answer = answers[userIds[0]]?[index] ?? 0;
                      final user2Answer = answers[userIds[1]]?[index] ?? 0;
                      final isMatch = user1Answer == user2Answer;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildAnswerCard(
                          question,
                          index + 1,
                          user1Answer,
                          user2Answer,
                          isMatch,
                          theme,
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),

                  // Next quiz suggestion
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '💡',
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isSubject
                              ? 'Want to test ${partner?.name ?? 'your partner'}? You start the next quiz!'
                              : 'Want ${partner?.name ?? 'your partner'} to quiz you? Ask them to start the next one!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Done button
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(
    QuizQuestion question,
    int questionNumber,
    int user1Answer,
    int user2Answer,
    bool isMatch,
    ThemeData theme,
  ) {
    // Determine which answer belongs to current user vs partner
    final user = _storage.getUser();
    final answers = widget.session.answers ?? {};
    final userIds = answers.keys.toList();

    // Find current user's answer and partner's answer
    final myAnswer = user != null && answers.containsKey(user.id)
        ? answers[user.id]![questionNumber - 1]
        : user1Answer;
    final partnerAnswer = user != null && answers.containsKey(user.id)
        ? answers[userIds.firstWhere((id) => id != user.id)]![questionNumber - 1]
        : user2Answer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMatch
            ? Colors.green.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMatch
              ? Colors.green.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q$questionNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                isMatch ? Icons.check_circle : Icons.cancel,
                color: isMatch ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                isMatch ? 'Match!' : 'Different',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isMatch ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildAnswerRow('You', question.options[myAnswer], theme),
          const SizedBox(height: 8),
          _buildAnswerRow(
            _storage.getPartner()?.name ?? 'Partner',
            question.options[partnerAnswer],
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerRow(String person, String answer, ThemeData theme) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            person,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            answer,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
