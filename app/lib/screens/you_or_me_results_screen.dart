import 'package:flutter/material.dart';
import '../models/you_or_me.dart';
import '../services/you_or_me_service.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/love_point_service.dart';
import '../models/daily_quest.dart';
import '../utils/logger.dart';
import '../config/brand/brand_loader.dart';

/// Results screen for You or Me game
/// Shows agreement statistics and individual answers
class YouOrMeResultsScreen extends StatefulWidget {
  final YouOrMeSession session;

  const YouOrMeResultsScreen({
    super.key,
    required this.session,
  });

  @override
  State<YouOrMeResultsScreen> createState() => _YouOrMeResultsScreenState();
}

class _YouOrMeResultsScreenState extends State<YouOrMeResultsScreen> {
  final YouOrMeService _service = YouOrMeService();
  final StorageService _storage = StorageService();
  Map<String, dynamic>? _results;
  bool _isLoadingPartnerSession = false;

  @override
  void initState() {
    super.initState();
    _loadSessionAndCalculateResults();

    // Check and complete associated daily quest
    _checkQuestCompletion();
  }

  Future<void> _loadSessionAndCalculateResults() async {
    setState(() {
      _isLoadingPartnerSession = true;
    });

    try {
      // Single-session architecture: Both users' answers are in the same session
      // Check if both users have answered
      if (!widget.session.areBothUsersAnswered()) {
        // Refresh session from Firebase to get latest data (e.g., partner's answers)
        Logger.debug('Not all users answered, refreshing session from Firebase', service: 'you_or_me');
        final refreshedSession = await _service.getSession(
          widget.session.id,
          forceRefresh: true,
        );

        if (refreshedSession != null && refreshedSession.areBothUsersAnswered()) {
          // Both answered now, calculate results
          setState(() {
            _results = _service.calculateResults(refreshedSession);
            _isLoadingPartnerSession = false;
          });
        } else {
          // Still waiting for partner
          Logger.debug('Still waiting for partner to complete', service: 'you_or_me');
          setState(() {
            _results = null;
            _isLoadingPartnerSession = false;
          });
        }
      } else {
        // Both users have answered, calculate results directly
        Logger.debug('Both users answered, calculating results', service: 'you_or_me');
        setState(() {
          _results = _service.calculateResults(widget.session);
          _isLoadingPartnerSession = false;
        });
      }
    } catch (e) {
      Logger.error('Error loading session results', error: e, service: 'you_or_me');
      setState(() {
        _results = null;
        _isLoadingPartnerSession = false;
      });
    }
  }

  /// Check if this game session is linked to a daily quest and mark it as completed
  Future<void> _checkQuestCompletion() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) {
        Logger.debug('No user or partner, skipping quest completion check', service: 'you_or_me');
        return;
      }

      // Check if there's a daily quest for this game session
      final questService = DailyQuestService(storage: _storage);
      final todayQuests = questService.getTodayQuests();

      Logger.debug('Checking quest completion - Found ${todayQuests.length} quests today', service: 'you_or_me');
      Logger.debug('Session ID: ${widget.session.id}', service: 'you_or_me');

      // Find quest with matching contentId (single-session architecture)
      final matchingQuest = todayQuests
          .where((q) => q.type == QuestType.youOrMe && q.contentId == widget.session.id)
          .firstOrNull;

      if (matchingQuest == null) {
        Logger.debug('❌ No matching You or Me quest found for session ${widget.session.id}', service: 'you_or_me');
        // Not a daily quest game - just played from Activities screen
        return;
      }

      Logger.debug('✅ Found matching quest: ${matchingQuest.id} for session ${widget.session.id}', service: 'you_or_me');

      // Check if current user has completed all questions
      final userAnswers = widget.session.answers?[user.id];
      if (userAnswers == null || userAnswers.length < widget.session.questions.length) {
        Logger.debug('User has not completed all questions yet (${userAnswers?.length ?? 0}/${widget.session.questions.length})', service: 'you_or_me');
        return; // User hasn't completed the game yet
      }

      Logger.debug('User ${user.id} completed all ${widget.session.questions.length} questions, marking quest complete', service: 'you_or_me');

      // Mark quest as completed for this user
      final bothCompleted = await questService.completeQuestForUser(
        questId: matchingQuest.id,
        userId: user.id,
      );

      Logger.debug('Quest completion result - bothCompleted: $bothCompleted', service: 'you_or_me');

      // Verify quest was updated in storage
      final updatedQuest = _storage.getDailyQuest(matchingQuest.id);
      Logger.debug('Quest after update - ID: ${updatedQuest?.id}, userCompletions: ${updatedQuest?.userCompletions}', service: 'you_or_me');

      // Sync with Firebase
      final syncService = QuestSyncService(storage: _storage);

      await syncService.markQuestCompleted(
        questId: matchingQuest.id,
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );

      Logger.debug('Quest completion synced to Firebase for quest ${matchingQuest.id}', service: 'you_or_me');

      if (bothCompleted) {
        Logger.success('Daily You or Me quest completed by both users! Awarding 30 LP...', service: 'you_or_me');

        // Award Love Points to BOTH users via Firebase (real-time sync)
        await LovePointService.awardPointsToBothUsers(
          userId1: user.id,
          userId2: partner.pushToken,
          amount: 30,
          reason: 'daily_quest_you_or_me',
          relatedId: matchingQuest.id,
        );
      }
    } catch (e) {
      Logger.error('Error checking quest completion', error: e, service: 'you_or_me');
      // Don't block results screen on quest errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (_isLoadingPartnerSession || _results == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAFAFA),
          elevation: 0,
          title: const Text('Results'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final totalQuestions = _results!['totalQuestions'] as int;
    final agreements = _results!['agreements'] as int;
    final disagreements = _results!['disagreements'] as int;
    final agreementPercentage = _results!['agreementPercentage'] as int;
    final comparisons = _results!['comparisons'] as List<Map<String, dynamic>>;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        title: const Text('Results'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: BrandLoader().colors.textPrimary),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'You or Me?',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'See how your perspectives compare!',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BrandLoader().colors.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // Agreement stats
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFD),
                  border: Border.all(color: const Color(0xFFF0F0F0), width: 2),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '$agreementPercentage%',
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Agreement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E6E6E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatChip(
                          '$agreements/$totalQuestions',
                          'Agreed',
                          BrandLoader().colors.success,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          '$disagreements/$totalQuestions',
                          'Different',
                          BrandLoader().colors.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Individual answers header
              Text(
                'Your Answers',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Answer comparisons
              ...comparisons.map((comparison) {
                final question = comparison['question'] as YouOrMeQuestion;
                final userAnswer = comparison['userAnswer'] as String?;
                final partnerAnswer = comparison['partnerAnswer'] as String?;
                final agreed = comparison['agreed'] as bool;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildComparisonCard(
                    question: question,
                    userAnswer: userAnswer,
                    partnerAnswer: partnerAnswer,
                    agreed: agreed,
                    userName: user?.name ?? 'You',
                    partnerName: partner?.name ?? 'Partner',
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Done button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandLoader().colors.primary,
                    foregroundColor: BrandLoader().colors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color.fromRGBO(
                color.red,
                color.green,
                color.blue,
                1.0,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color.fromRGBO(
                color.red,
                color.green,
                color.blue,
                1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required YouOrMeQuestion question,
    required String? userAnswer,
    required String? partnerAnswer,
    required bool agreed,
    required String userName,
    required String partnerName,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFD),
        border: Border.all(
          color: agreed ? BrandLoader().colors.success.withOpacity(0.3) : const Color(0xFFF0F0F0),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (agreed)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: BrandLoader().colors.textOnPrimary,
                    size: 16,
                  ),
                ),
              if (agreed) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6E6E6E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question.content,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Answers
          Row(
            children: [
              Expanded(
                child: _buildAnswerBadge(
                  label: userName,
                  answer: userAnswer,
                  isUser: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnswerBadge(
                  label: partnerName,
                  answer: partnerAnswer,
                  isUser: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerBadge({
    required String label,
    required String? answer,
    required bool isUser,
  }) {
    String answerText;
    switch (answer) {
      case 'me':
        answerText = isUser ? 'Me' : 'You';
        break;
      case 'partner':
        answerText = isUser ? 'Partner' : 'Me';
        break;
      case 'neither':
        answerText = 'Neither';
        break;
      case 'both':
        answerText = 'Both';
        break;
      default:
        answerText = '—';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6E6E6E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            answerText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
