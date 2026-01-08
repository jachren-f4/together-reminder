import 'package:flutter/material.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/models/daily_quest.dart';
import 'package:togetherremind/models/magnet_collection.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'us2_logo.dart';
import 'us2_day_label.dart';
import 'us2_avatar_section.dart';
import 'us2_connection_bar.dart';
import 'us2_section_header.dart';
import 'us2_quest_carousel.dart';

/// Callback type for calculating quest guidance state
typedef GuidanceCallback = ({bool showGuidance, String? guidanceText}) Function(DailyQuest quest);

/// Toggle: Set to true to make side quest cards the same size as daily quest cards
/// Set to false for smaller side quest cards (original design)
const bool kSideQuestsSameAsDailyQuests = true;

/// Us 2.0 brand home screen content
///
/// This widget replaces the default Liia home content when running
/// with --dart-define=BRAND=us2
class Us2HomeContent extends StatelessWidget {
  final String userName;
  final String partnerName;
  final int dayNumber;
  final MagnetCollection? magnetCollection;
  final VoidCallback? onCollectionTap;
  final List<DailyQuest> dailyQuests;
  final List<DailyQuest> sideQuests;
  final Function(DailyQuest) onQuestTap;
  final VoidCallback? onDebugTap;
  final GuidanceCallback? getDailyQuestGuidance;
  final GuidanceCallback? getSideQuestGuidance;

  Us2HomeContent({
    super.key,
    required this.userName,
    required this.partnerName,
    required this.dayNumber,
    this.magnetCollection,
    this.onCollectionTap,
    required this.dailyQuests,
    required this.sideQuests,
    required this.onQuestTap,
    this.onDebugTap,
    this.getDailyQuestGuidance,
    this.getSideQuestGuidance,
  });

  /// Build the hero section with overlapping logo, avatars, and connection bar
  /// This uses a Stack to achieve the visual overlap from the HTML mockup
  Widget _buildHeroSection() {
    // Heights based on mockup layout
    const logoSectionHeight = 100.0; // Logo + day label
    const avatarHeight = 235.0;
    const connectionBarHeight = 115.0; // Header + spacing + track + padding
    const avatarOverlap = 80.0; // How much avatars overlap into header

    return SizedBox(
      height: logoSectionHeight + avatarHeight + connectionBarHeight - avatarOverlap - 25,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatars - positioned to overlap with logo area (rendered first, behind logo)
          Positioned(
            top: logoSectionHeight - avatarOverlap,
            left: 0,
            right: 0,
            child: Us2AvatarSection(
              userName: userName,
              partnerName: partnerName,
            ),
          ),
          // Connection bar - positioned after avatars
          Positioned(
            top: logoSectionHeight - avatarOverlap + avatarHeight - 10,
            left: 0,
            right: 0,
            child: Us2ConnectionBar(
              collection: magnetCollection,
              onTap: onCollectionTap,
            ),
          ),
          // Logo and day label at top - LAST in Stack so it receives touch events
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Us2Logo(onDoubleTap: onDebugTap),
                const SizedBox(height: 4),
                Us2DayLabel(dayNumber: dayNumber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: Us2Theme.backgroundGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Hero section with overlapping elements
              _buildHeroSection(),
              // Daily Quests section
              const Us2SectionHeader(title: 'Daily Quests'),
              Us2QuestCarousel(
                quests: _mapQuestsToData(dailyQuests, getDailyQuestGuidance),
              ),
              // Side Quests section
              const Us2SectionHeader(title: 'Side Quests'),
              Us2QuestCarousel(
                quests: _mapQuestsToData(sideQuests, getSideQuestGuidance),
                isSmall: !kSideQuestsSameAsDailyQuests,
              ),
              const SizedBox(height: 60), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  List<Us2QuestData> _mapQuestsToData(List<DailyQuest> quests, GuidanceCallback? getGuidance) {
    final userId = StorageService().getUser()?.id;

    return quests.map((quest) {
      final guidance = getGuidance?.call(quest);
      return Us2QuestData(
        quest: quest,
        title: _getQuestTitle(quest),
        description: _getQuestDescription(quest),
        emoji: _getQuestEmoji(quest),
        buttonLabel: _getButtonLabel(quest),
        onTap: () => onQuestTap(quest),
        imagePath: _getQuestImagePath(quest),
        currentUserId: userId,
        showGuidance: guidance?.showGuidance ?? false,
        guidanceText: guidance?.guidanceText,
      );
    }).toList();
  }

  String? _getQuestImagePath(DailyQuest quest) {
    const basePath = 'assets/brands/us2/images/quests';

    // Check formatType for quiz variants
    if (quest.type == QuestType.quiz && quest.formatType == 'affirmation') {
      return '$basePath/affirmation-default.png';
    }

    switch (quest.type) {
      case QuestType.question:
        return '$basePath/daily-question.png';
      case QuestType.quiz:
        return '$basePath/classic-quiz-default.png';
      case QuestType.game:
        return null; // Use emoji fallback
      case QuestType.youOrMe:
        return '$basePath/you-or-me.png';
      case QuestType.linked:
        return '$basePath/linked.png';
      case QuestType.wordSearch:
        return '$basePath/word-search.png';
      case QuestType.steps:
        return null; // Use emoji fallback
    }
  }

  String _getQuestTitle(DailyQuest quest) {
    // Check formatType for quiz variants
    if (quest.type == QuestType.quiz && quest.formatType == 'affirmation') {
      return 'Affirmation Quiz';
    }

    switch (quest.type) {
      case QuestType.question:
        return 'Daily Question';
      case QuestType.quiz:
        return quest.quizName ?? 'Lighthearted Quiz';
      case QuestType.game:
        return 'Game';
      case QuestType.youOrMe:
        return quest.quizName ?? 'You or Me';
      case QuestType.linked:
        return 'Linked';
      case QuestType.wordSearch:
        return 'Word Search';
      case QuestType.steps:
        return 'Steps Together';
    }
  }

  String _getQuestDescription(DailyQuest quest) {
    // Use quest's description if available
    if (quest.description != null && quest.description!.isNotEmpty) {
      return quest.description!;
    }

    // Check formatType for quiz variants
    if (quest.type == QuestType.quiz && quest.formatType == 'affirmation') {
      return 'Rate your feelings together';
    }

    switch (quest.type) {
      case QuestType.question:
        return 'Answer together';
      case QuestType.quiz:
        return 'Answer five questions together';
      case QuestType.game:
        return 'Play together';
      case QuestType.youOrMe:
        return 'Who does what in your relationship?';
      case QuestType.linked:
        return 'Crossword puzzle together';
      case QuestType.wordSearch:
        return 'Find hidden words';
      case QuestType.steps:
        return 'Walk together, earn points';
    }
  }

  String _getQuestEmoji(DailyQuest quest) {
    // Check formatType for quiz variants
    if (quest.type == QuestType.quiz && quest.formatType == 'affirmation') {
      return '💑';
    }

    switch (quest.type) {
      case QuestType.question:
        return '❓';
      case QuestType.quiz:
        return '👫🏾';
      case QuestType.game:
        return '🎮';
      case QuestType.youOrMe:
        return '🤔';
      case QuestType.linked:
        return '🔗';
      case QuestType.wordSearch:
        return '🔍';
      case QuestType.steps:
        return '👟';
    }
  }

  String _getButtonLabel(DailyQuest quest) {
    final userId = StorageService().getUser()?.id;

    if (quest.areBothUsersCompleted()) {
      return 'Completed ✓';
    }
    if (userId != null && quest.hasUserCompleted(userId)) {
      return 'Waiting for partner...';
    }
    return 'Start Quest';
  }
}
