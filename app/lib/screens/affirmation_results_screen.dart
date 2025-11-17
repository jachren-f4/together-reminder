import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../models/daily_quest.dart';
import '../services/quest_utilities.dart';

/// Results screen for affirmation-style quizzes
/// Shows individual score (not match percentage) and answers
class AffirmationResultsScreen extends StatefulWidget {
  final QuizSession session;

  const AffirmationResultsScreen({
    super.key,
    required this.session,
  });

  @override
  State<AffirmationResultsScreen> createState() => _AffirmationResultsScreenState();
}

class _AffirmationResultsScreenState extends State<AffirmationResultsScreen> {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  late List<QuizQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = _quizService.getSessionQuestions(widget.session);

    // Check and complete associated daily quest
    _checkQuestCompletion();
  }

  /// Calculate average score from 1-5 scale answers
  double _calculateAverageScore(List<int> answers) {
    if (answers.isEmpty) return 0;
    final sum = answers.reduce((a, b) => a + b);
    return sum / answers.length;
  }

  /// Convert average (1-5) to percentage (0-100)
  int _averageToPercentage(double average) {
    return ((average / 5.0) * 100).round();
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

      // Find quest with matching contentId (quiz session ID)
      final matchingQuest = todayQuests.where((q) =>
        q.type == QuestType.quiz && q.contentId == widget.session.id
      ).firstOrNull;

      if (matchingQuest == null) {
        // Not a daily quest quiz - just a regular quiz
        return;
      }

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
        Logger.success('Daily affirmation quest completed by both users! Awarding 30 LP...', service: 'quiz');

        // Award Love Points to BOTH users via Firebase (real-time sync)
        await LovePointService.awardPointsToBothUsers(
          userId1: user.id,
          userId2: partner.pushToken,
          amount: 30,
          reason: 'daily_quest_affirmation',
          relatedId: matchingQuest.id,
        );

        // Check if all 3 daily quests are completed
        await _checkDailyQuestsCompletion(questService, user.id, partner.pushToken);
      }
    } catch (e) {
      Logger.error('Error checking quest completion', error: e, service: 'quiz');
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
        Logger.success('All daily quests completed! Advancing progression...', service: 'quiz');

        // Get the couple ID using QuestUtilities
        final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);

        // Get current progression state
        var progressionState = _storage.getQuizProgressionState(coupleId);
        if (progressionState == null) {
          Logger.warn('No progression state found', service: 'quiz');
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

        // Save to Firebase
        final syncService = QuestSyncService(
          storage: _storage,
        );
        await syncService.saveProgressionState(progressionState);
      }
    } catch (e) {
      Logger.error('Error checking daily quests completion', error: e, service: 'quiz');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    final userAnswers = widget.session.answers?[user.id] ?? [];
    final partnerAnswers = widget.session.answers?[partner?.pushToken] ?? [];

    final averageScore = _calculateAverageScore(userAnswers);
    final scorePercentage = _averageToPercentage(averageScore);
    final bothCompleted = userAnswers.isNotEmpty && partnerAnswers.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz title
              Text(
                widget.session.quizName ?? 'Affirmation Quiz',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair Display',
                ),
              ),

              const SizedBox(height: 8),

              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.session.category?.toUpperCase() ?? 'AFFIRMATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Your results section
              Text(
                'Your results',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'This represents how satisfied you are with ${widget.session.category ?? 'this area'} in your relationship at present.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              // Circular progress indicator showing individual score
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: scorePercentage / 100,
                          strokeWidth: 12,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getScoreColor(scorePercentage),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$scorePercentage%',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair Display',
                            ),
                          ),
                          Text(
                            '${averageScore.toStringAsFixed(1)}/5.0',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Partner status
              _buildPartnerStatus(theme, bothCompleted, partner?.name),

              const SizedBox(height: 32),

              // Your answers section
              Text(
                'Your answers',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // List of questions and answers
              ...List.generate(_questions.length, (index) {
                if (index >= userAnswers.length) return const SizedBox.shrink();

                final question = _questions[index];
                final answer = userAnswers[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildAnswerCard(theme, index + 1, question.question, answer),
                );
              }),

              const SizedBox(height: 24),

              // Done button
              FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
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
    );
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildPartnerStatus(ThemeData theme, bool bothCompleted, String? partnerName) {
    if (bothCompleted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${partnerName ?? 'Your partner'} has also completed this quiz',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: theme.colorScheme.onSecondaryContainer,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Awaiting ${partnerName ?? 'partner'}\'s answers',
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAnswerCard(ThemeData theme, int number, String question, int answer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $question',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Heart icons showing the rating
              ...List.generate(5, (index) {
                final value = index + 1;
                final isSelected = value <= answer;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    isSelected ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: isSelected ? Colors.red : Colors.grey[400],
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                '$answer/5',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
