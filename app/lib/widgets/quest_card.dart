import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';

/// Card displaying a single daily quest with image, title, description, and status
///
/// New carousel design with:
/// - Image at top (170px height)
/// - Title + description + reward badge
/// - Status badges (Your Turn / Partner completed / Completed)
class QuestCard extends StatelessWidget {
  final DailyQuest quest;
  final VoidCallback onTap;
  final String? currentUserId;
  final bool showShadow; // Controlled by carousel for active card

  const QuestCard({
    super.key,
    required this.quest,
    required this.onTap,
    this.currentUserId,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();

    // Determine quest status for current user
    final userCompleted = currentUserId != null && quest.hasUserCompleted(currentUserId!);
    final bothCompleted = quest.isCompleted;
    final isExpired = quest.isExpired;

    // Get image path based on quest type
    final imagePath = _getQuestImage();

    return GestureDetector(
      onTap: isExpired ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(0), // Sharp corners like mockup
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 0,
                    offset: const Offset(4, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image (top, full-width)
            if (imagePath != null)
              Image.asset(
                imagePath,
                height: 170,
                fit: BoxFit.cover,
                // Performance: Cache resized images to reduce memory usage
                cacheWidth: 400, // Reasonable resolution for 60% screen width
                cacheHeight: 340, // 2x the display height (170px * 2)
                errorBuilder: (context, error, stackTrace) {
                  // Show fallback placeholder when image fails to load
                  return Container(
                    height: 170,
                    color: const Color(0xFFF0F0F0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image not found',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Title + Description + Reward
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getQuestTitle(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getQuestDescription(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Reward badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Text(
                          '+${quest.lpAwarded ?? 30}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Footer: Status badges
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                      ),
                    ),
                    child: _buildStatusBadge(user, partner, userCompleted, bothCompleted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getQuestImage() {
    // Option 1: Use quest's imagePath if available (from quiz JSON)
    // This is the preferred method - imagePath is denormalized from quiz definition
    if (quest.imagePath != null && quest.imagePath!.isNotEmpty) {
      return quest.imagePath;
    }

    // Option 2: Fallback to quest type-based images (backward compatibility)
    // Used for:
    // - Old quests without imagePath
    // - Non-quiz quest types (Word Ladder, Memory Flip, You or Me)
    switch (quest.type) {
      case QuestType.quiz:
        // Fallback for quizzes without imagePath
        if (quest.formatType == 'affirmation') {
          return 'assets/images/quests/affirmation-default.png';
        }
        return 'assets/images/quests/classic-quiz-default.png';
      case QuestType.wordLadder:
        return 'assets/images/quests/word-ladder.png';
      case QuestType.memoryFlip:
        return 'assets/images/quests/memory-flip.png';
      case QuestType.youOrMe:
        return 'assets/images/quests/you-or-me.png';
      case QuestType.question:
        return 'assets/images/quests/daily-question.png';
      default:
        return null;
    }
  }

  String _getQuestDescription() {
    // Option 1: Use quest's description if available (from quiz JSON)
    // This is the preferred method - description is denormalized from quiz definition
    if (quest.description != null && quest.description!.isNotEmpty) {
      return quest.description!;
    }

    // Option 2: Fallback to quest type-based descriptions (backward compatibility)
    switch (quest.type) {
      case QuestType.quiz:
        if (quest.formatType == 'affirmation') {
          return 'Rate your feelings together';
        }
        return 'Answer ten questions together';
      case QuestType.wordLadder:
        return 'Collaborate to solve';
      case QuestType.memoryFlip:
        return 'Match all sixteen cards';
      case QuestType.youOrMe:
        return 'Guess who said what';
      case QuestType.question:
        return 'Share your thoughts';
      default:
        return '';
    }
  }

  Widget _buildStatusBadge(dynamic user, dynamic partner, bool userCompleted, bool bothCompleted) {
    if (bothCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: const Text(
          '✓ COMPLETED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
      );
    } else if (partner != null && quest.hasUserCompleted(partner.pushToken)) {
      // Partner completed, user hasn't
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  partner.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${partner.name} completed',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    } else {
      // User's turn
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: const Text(
          'YOUR TURN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.black,
          ),
        ),
      );
    }
  }

  String _getQuestTitle() {
    switch (quest.type) {
      case QuestType.question:
        return 'Daily Question';
      case QuestType.quiz:
        // Check quest formatType first (always available from Firebase)
        if (quest.formatType == 'affirmation') {
          // Use quest.quizName (synced from Firebase) or fallback
          return quest.quizName ?? 'Affirmation Quiz';
        }
        // Use sort order to generate distinct titles for classic quizzes
        return _getQuizTitle(quest.sortOrder);
      case QuestType.game:
        return 'Fun Game';
      case QuestType.wordLadder:
        return 'Word Ladder Challenge';
      case QuestType.memoryFlip:
        return 'Memory Match Game';
      case QuestType.youOrMe:
        return 'You or Me?';
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
