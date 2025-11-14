import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';

/// Card displaying a single daily quest
///
/// Shows quest type, title, and completion status with participant avatars
class QuestCard extends StatelessWidget {
  final DailyQuest quest;
  final VoidCallback onTap;
  final String? currentUserId;

  const QuestCard({
    Key? key,
    required this.quest,
    required this.onTap,
    this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();

    // Determine quest status for current user
    final userCompleted = currentUserId != null && quest.hasUserCompleted(currentUserId!);
    final bothCompleted = quest.isCompleted;
    final isExpired = quest.isExpired;

    // Get quest title from content
    final title = _getQuestTitle();

    return GestureDetector(
      onTap: isExpired ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: bothCompleted ? Colors.black : const Color(0xFFF0F0F0),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quest type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getQuestTypeName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quest title
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),

            // Bottom right: Participant status or "Your Turn" badge
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildStatusIndicator(user, partner, userCompleted, bothCompleted),
            ),

            // Bottom left: "Your Turn" badge if needed
            if (!userCompleted && !isExpired)
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Your Turn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Expired indicator
            if (isExpired)
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Expired',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    dynamic user,
    dynamic partner,
    bool userCompleted,
    bool bothCompleted,
  ) {
    // Check if partner completed (even if user hasn't)
    final partnerCompleted = partner != null && quest.hasUserCompleted(partner.pushToken);

    if (bothCompleted && user != null && partner != null) {
      // Show dual avatars (both completed)
      return SizedBox(
        width: 52,
        height: 32,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: _buildAvatar(user.name ?? 'U', Colors.black),
            ),
            Positioned(
              right: 0,
              child: _buildAvatar(partner.name ?? 'P', Colors.black),
            ),
          ],
        ),
      );
    } else if (userCompleted && partnerCompleted && user != null && partner != null) {
      // Both completed but quest not marked complete yet (edge case)
      return SizedBox(
        width: 52,
        height: 32,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: _buildAvatar(user.name ?? 'U', Colors.black),
            ),
            Positioned(
              right: 0,
              child: _buildAvatar(partner.name ?? 'P', Colors.black),
            ),
          ],
        ),
      );
    } else if (userCompleted && user != null) {
      // Show single avatar (user completed, partner hasn't)
      return _buildAvatar(user.name ?? 'U', Colors.black);
    } else if (partnerCompleted && partner != null) {
      // Show single avatar (partner completed, user hasn't)
      return _buildAvatar(partner.name ?? 'P', Colors.grey.shade400);
    } else {
      // No avatar (neither completed)
      return const SizedBox.shrink();
    }
  }

  Widget _buildAvatar(String name, Color bgColor) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _getQuestTypeName() {
    switch (quest.type) {
      case QuestType.question:
        return 'QUESTION';
      case QuestType.quiz:
        return 'QUIZ';
      case QuestType.game:
        return 'GAME';
      case QuestType.wordLadder:
        return 'WORD LADDER';
      case QuestType.memoryFlip:
        return 'MEMORY FLIP';
    }
  }

  String _getQuestTitle() {
    switch (quest.type) {
      case QuestType.question:
        return 'Daily Question';
      case QuestType.quiz:
        // Use sort order to generate distinct titles
        return _getQuizTitle(quest.sortOrder);
      case QuestType.game:
        return 'Fun Game';
      case QuestType.wordLadder:
        return 'Word Ladder Challenge';
      case QuestType.memoryFlip:
        return 'Memory Match Game';
    }
  }

  String _getQuizTitle(int sortOrder) {
    // Generate titles based on position in daily quest lineup
    // These will cycle through as progression advances
    const titles = [
      'Getting to Know You',
      'Deeper Connection',
      'Understanding Each Other',
    ];

    if (sortOrder >= 0 && sortOrder < titles.length) {
      return titles[sortOrder];
    }

    return 'Relationship Quiz #${sortOrder + 1}';
  }
}
