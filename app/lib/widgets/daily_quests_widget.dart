import 'dart:async';
import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/api_client.dart';
import '../services/love_point_service.dart';
import '../theme/app_theme.dart';
import '../config/brand/brand_loader.dart';
import '../utils/logger.dart';
import '../widgets/quest_carousel.dart';
import '../screens/quiz_intro_screen.dart';
import '../screens/affirmation_intro_screen.dart';
import '../screens/quiz_match_game_screen.dart';
import '../screens/you_or_me_match_intro_screen.dart';
import '../screens/you_or_me_match_game_screen.dart';

/// Global RouteObserver for tracking navigation events
/// This should be added to MaterialApp's navigatorObservers
final RouteObserver<ModalRoute<void>> questRouteObserver = RouteObserver<ModalRoute<void>>();

/// Widget displaying daily quests with completion tracking
///
/// Shows 3 daily quests with visual progress tracker and completion banner.
/// Uses Supabase polling (instead of Firebase RTDB) for partner completion sync.
class DailyQuestsWidget extends StatefulWidget {
  const DailyQuestsWidget({Key? key}) : super(key: key);

  @override
  State<DailyQuestsWidget> createState() => _DailyQuestsWidgetState();
}

class _DailyQuestsWidgetState extends State<DailyQuestsWidget> with RouteAware {
  final StorageService _storage = StorageService();
  final ApiClient _apiClient = ApiClient();
  late DailyQuestService _questService;
  Timer? _pollingTimer;

  // Polling interval for partner quest status (5 seconds during dev, increase for production)
  static const Duration _pollingInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _questService = DailyQuestService(
      storage: _storage,
    );

    // Start polling for partner quest completions via Supabase
    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events to detect when we return from a quest screen
    final route = ModalRoute.of(context);
    if (route != null) {
      questRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Called when a route has been popped off, and this route is now visible
    // This happens when returning from quiz/waiting/results screens
    if (mounted) {
      setState(() {
        // Force refresh from Hive - quest status should now be updated
      });
      Logger.debug('Route popped - refreshing quest cards', service: 'quest');
    }
  }

  /// Start polling for partner quest completions
  void _startPolling() {
    // Initial poll
    _pollQuestStatus();

    // Set up periodic polling
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _pollQuestStatus();
    });
  }

  /// Poll Supabase for quest completion status
  Future<void> _pollQuestStatus() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      return;
    }

    try {
      final response = await _apiClient.get('/api/sync/quest-status');

      if (!response.success || response.data == null) {
        return;
      }

      final questsData = response.data['quests'] as List<dynamic>?;
      if (questsData == null || questsData.isEmpty) {
        return;
      }

      bool anyUpdates = false;

      for (final questData in questsData) {
        final questType = questData['questType'] as String?;
        final partnerCompleted = questData['partnerCompleted'] as bool? ?? false;
        final status = questData['status'] as String?;

        if (questType == null) continue;

        // Find local quest by matching formatType to questType
        // API returns: 'classic', 'affirmation', 'you_or_me'
        // Quest formatType: 'classic', 'affirmation', 'youOrMe'
        final localQuests = _storage.getTodayQuests();
        final normalizedQuestType = questType == 'you_or_me' ? 'youOrMe' : questType;
        final matchingQuest = localQuests.where((q) => q.formatType == normalizedQuestType).firstOrNull;

        Logger.debug(
          'Poll: questType=$questType, normalized=$normalizedQuestType, partnerCompleted=$partnerCompleted, '
          'localQuests=${localQuests.map((q) => "${q.type.name}:${q.formatType}").join(", ")}, '
          'matched=${matchingQuest?.type.name}',
          service: 'quest',
        );

        if (matchingQuest != null) {
          // Update partner completion status
          // Use partner.id (UUID) if available, fallback to pushToken for backward compatibility
          final partnerKey = partner.id.isNotEmpty ? partner.id : partner.pushToken;
          if (partnerCompleted && !matchingQuest.hasUserCompleted(partnerKey)) {
            matchingQuest.userCompletions ??= {};
            matchingQuest.userCompletions![partnerKey] = true;

            // Update quest status
            if (status == 'completed' || matchingQuest.areBothUsersCompleted()) {
              matchingQuest.status = 'completed';
              matchingQuest.completedAt = DateTime.now();
            } else {
              matchingQuest.status = 'in_progress';
            }

            _storage.updateDailyQuest(matchingQuest);
            anyUpdates = true;

            Logger.debug('Updated quest ${matchingQuest.type.name} with partner completion', service: 'quest');
          }
        }
      }

      // Trigger UI rebuild if there were updates
      if (anyUpdates && mounted) {
        setState(() {});

        // Also sync LP from server - partner completion may have awarded LP
        await LovePointService.fetchAndSyncFromServer();
      }
    } catch (e) {
      Logger.error('Error polling quest status', error: e, service: 'quest');
    }
  }

  @override
  void dispose() {
    questRouteObserver.unsubscribe(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final quests = _questService.getMainDailyQuests();
    final allCompleted = _questService.areAllMainQuestsCompleted();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: BrandLoader().colors.textPrimary, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Section header (swipe hint commented out)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DAILY QUESTS',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: BrandLoader().colors.textPrimary,
                  ),
                ),
              // Text(
              //   '← SWIPE →', // Match HTML mockup exactly (always LTR, uppercase)
              //   style: AppTheme.headlineFont.copyWith( // Use serif font like HTML mockup
              //     fontSize: 13, // Increased from 11 to match visual size of HTML mockup
              //     color: const Color(0xFF999999),
              //     fontWeight: FontWeight.w600,
              //     letterSpacing: 1,
              //   ),
              // ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Carousel (replaces vertical list)
        if (quests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildEmptyState(),
          )
        else
          QuestCarousel(
            quests: quests,
            currentUserId: user?.id,
            onQuestTap: _handleQuestTap,
          ),

        // Completion banner
        if (allCompleted) _buildCompletionBanner(),

        const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BrandLoader().colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BrandLoader().colors.borderLight,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today, size: 48, color: BrandLoader().colors.textTertiary),
          const SizedBox(height: 12),
          Text(
            'No Daily Quests Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: BrandLoader().colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check back tomorrow for new quests!',
            style: TextStyle(
              fontSize: 14,
              color: BrandLoader().colors.textSecondary,
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
          color: BrandLoader().colors.surface,
          border: Border.all(color: BrandLoader().colors.textPrimary, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BrandLoader().colors.textPrimary.withOpacity(0.06),
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
                  color: BrandLoader().colors.textPrimary,
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

      case QuestType.youOrMe:
        await _handleYouOrMeQuestTap(quest);
        break;

      case QuestType.question:
        // TODO: Navigate to Question screen
        break;

      case QuestType.game:
        // TODO: Navigate to Game screen
        break;

      case QuestType.linked:
        // Linked is handled via Side Quests carousel, not daily quests
        break;

      case QuestType.wordSearch:
        // TODO: Navigate to Word Search screen
        break;

      case QuestType.steps:
        // Steps Together is handled via Side Quests carousel, not daily quests
        break;
    }

    // Refresh state after returning from quest
    // setState() alone is enough - Hive returns the same object instances
    // that were updated by the game screen's _updateLocalQuestStatus()
    // The rebuild will re-read from _questService.getMainDailyQuests()
    // which fetches fresh data from Hive
    if (mounted) {
      setState(() {
        // Force widget rebuild - Hive objects are already updated
      });
    }
  }

  Future<void> _handleQuizQuestTap(DailyQuest quest) async {
    final user = _storage.getUser();
    final userCompleted = user != null && quest.hasUserCompleted(user.id);

    // If user has already completed their part, go directly to game screen
    // (which will show waiting or results screen)
    if (userCompleted) {
      final quizType = quest.formatType == 'affirmation' ? 'affirmation' : 'classic';
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizMatchGameScreen(
            quizType: quizType,
            questId: quest.id,
          ),
        ),
      );
      return;
    }

    // User hasn't completed yet - show intro screen first
    if (quest.formatType == 'affirmation') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AffirmationIntroScreen(
            branch: quest.branch,
            questId: quest.id,
          ),
        ),
      );
    } else {
      // Classic quiz
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizIntroScreen(
            branch: quest.branch,
            questId: quest.id,
          ),
        ),
      );
    }
  }

  Future<void> _handleYouOrMeQuestTap(DailyQuest quest) async {
    final user = _storage.getUser();
    final userCompleted = user != null && quest.hasUserCompleted(user.id);

    // If user has already completed their part, go directly to game screen
    // (which will show waiting or results screen)
    if (userCompleted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => YouOrMeMatchGameScreen(
            questId: quest.id,
          ),
        ),
      );
      return;
    }

    // User hasn't completed yet - show intro screen first
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouOrMeMatchIntroScreen(
          branch: quest.branch,
          questId: quest.id,
        ),
      ),
    );
  }
}
