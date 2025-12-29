import 'package:flutter/material.dart';
import 'package:togetherremind/models/daily_quest.dart';
import 'us2_quest_card.dart';

/// Horizontal scrolling carousel of quest cards
///
/// Based on us2-home-v2.html mockup:
/// - Daily quests: 82% width, max 320px
/// - Side quests: 65% width, max 250px
/// - Snap scrolling enabled
class Us2QuestCarousel extends StatelessWidget {
  final List<Us2QuestData> quests;
  final bool isSmall;

  const Us2QuestCarousel({
    super.key,
    required this.quests,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 82% for daily quests, 65% for side quests
    final cardWidthFraction = isSmall ? 0.65 : 0.82;
    final maxCardWidth = isSmall ? 250.0 : 320.0;
    final cardWidth = (screenWidth * cardWidthFraction).clamp(0.0, maxCardWidth);

    return SizedBox(
      height: isSmall ? 330 : 380,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 15, right: 15, bottom: 25),
        physics: const BouncingScrollPhysics(),
        itemCount: quests.length,
        itemBuilder: (context, index) {
          final questData = quests[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < quests.length - 1 ? 16 : 0,
            ),
            child: Us2QuestCard(
              quest: questData.quest,
              title: questData.title,
              description: questData.description,
              emoji: questData.emoji,
              buttonLabel: questData.buttonLabel,
              onTap: questData.onTap,
              isSmall: isSmall,
              width: cardWidth,
              imagePath: questData.imagePath,
              currentUserId: questData.currentUserId,
              isLocked: questData.isLocked,
              unlockCriteria: questData.unlockCriteria,
            ),
          );
        },
      ),
    );
  }
}

/// Data model for quest card display
class Us2QuestData {
  final DailyQuest? quest;
  final String title;
  final String description;
  final String emoji;
  final String buttonLabel;
  final VoidCallback onTap;
  final String? imagePath;
  final String? currentUserId;
  final bool isLocked;
  final String? unlockCriteria;

  const Us2QuestData({
    this.quest,
    required this.title,
    required this.description,
    required this.emoji,
    required this.buttonLabel,
    required this.onTap,
    this.imagePath,
    this.currentUserId,
    this.isLocked = false,
    this.unlockCriteria,
  });
}
