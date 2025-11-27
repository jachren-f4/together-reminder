import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../config/brand/brand_loader.dart';
import '../theme/app_theme.dart';

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
      child: Opacity(
        opacity: isExpired ? 0.5 : 1.0, // Gray out expired quests
        child: Container(
          decoration: BoxDecoration(
            color: BrandLoader().colors.surface,
            border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
            borderRadius: BorderRadius.circular(0), // Sharp corners like mockup
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: BrandLoader().colors.textPrimary.withOpacity(0.15),
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
                // Note: Only cacheWidth specified to maintain aspect ratio
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
                          color: BrandLoader().colors.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Image not found',
                          style: TextStyle(
                            fontSize: 12,
                            color: BrandLoader().colors.textSecondary,
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
                              style: AppTheme.headlineFont.copyWith( // Serif font
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getQuestDescription(),
                              style: AppTheme.headlineFont.copyWith( // Serif font
                                fontSize: 12,
                                color: const Color(0xFF666666),
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
                          color: BrandLoader().colors.textPrimary,
                          border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
                        ),
                        child: Text(
                          '+${quest.lpAwarded ?? 30}',
                          style: AppTheme.headlineFont.copyWith( // Serif font
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: BrandLoader().colors.textOnPrimary,
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
    final questImages = BrandLoader().assets.questImagesPath;
    switch (quest.type) {
      case QuestType.quiz:
        // Fallback for quizzes without imagePath
        if (quest.formatType == 'affirmation') {
          return '$questImages/affirmation-default.png';
        }
        return '$questImages/classic-quiz-default.png';
      case QuestType.wordLadder:
        return '$questImages/word-ladder.png';
      case QuestType.memoryFlip:
        return '$questImages/memory-flip.png';
      case QuestType.youOrMe:
        return '$questImages/you-or-me.png';
      case QuestType.question:
        return '$questImages/daily-question.png';
      case QuestType.linked:
        return '$questImages/linked.png';
      case QuestType.wordSearch:
        return '$questImages/word-search.png';
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
      case QuestType.wordSearch:
        return 'Find twelve hidden words';
      default:
        return '';
    }
  }

  Widget _buildStatusBadge(dynamic user, dynamic partner, bool userCompleted, bool bothCompleted) {
    if (bothCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: BrandLoader().colors.textPrimary,
          border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
        ),
        child: Text(
          '✓ COMPLETED',
          style: AppTheme.headlineFont.copyWith( // Serif font
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: BrandLoader().colors.textOnPrimary,
          ),
        ),
      );
    } else if (partner != null && quest.hasUserCompleted(partner.pushToken)) {
      // Partner completed, user hasn't
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: BrandLoader().colors.textPrimary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  partner.name[0].toUpperCase(),
                  style: AppTheme.headlineFont.copyWith( // Serif font
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BrandLoader().colors.textOnPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${partner.name} completed',
              style: AppTheme.headlineFont.copyWith( // Serif font
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    } else if (quest.type == QuestType.memoryFlip && !quest.isCompleted) {
      // Memory Flip: Show "OUT OF FLIPS" if user exhausted daily flip allowance
      if (userCompleted) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: BrandLoader().colors.surface,
            border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
          ),
          child: Text(
            'OUT OF FLIPS',
            style: AppTheme.headlineFont.copyWith( // Serif font
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: BrandLoader().colors.textPrimary,
          ),
          ),
        );
      }
      // Otherwise show YOUR TURN (flips available)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: BrandLoader().colors.surface,
          border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
        ),
        child: Text(
          'YOUR TURN',
          style: AppTheme.headlineFont.copyWith( // Serif font
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: BrandLoader().colors.textPrimary,
          ),
        ),
      );
    } else if (userCompleted) {
      // User completed, waiting for partner (applies to You or Me, Word Ladder, etc.)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: BrandLoader().colors.textPrimary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user?.name[0].toUpperCase() ?? 'Y',
                  style: AppTheme.headlineFont.copyWith( // Serif font
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BrandLoader().colors.textOnPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Waiting for ${partner?.name ?? "partner"}',
              style: AppTheme.headlineFont.copyWith( // Serif font
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    } else {
      // User's turn (for turn-based games like Word Ladder)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: BrandLoader().colors.surface,
          border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
        ),
        child: Text(
          'YOUR TURN',
          style: AppTheme.headlineFont.copyWith( // Serif font
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: BrandLoader().colors.textPrimary,
          ),
        ),
      );
    }
  }

  String _getQuestTitle() {
    // Option 1: Use quest's quizName if available (for affirmation quizzes and custom titles)
    // This allows side quests and placeholders to have custom titles
    if (quest.quizName != null && quest.quizName!.isNotEmpty) {
      return quest.quizName!;
    }

    // Option 2: Fallback to quest type-based titles
    switch (quest.type) {
      case QuestType.question:
        return 'Daily Question';
      case QuestType.quiz:
        // Check quest formatType first (always available from Firebase)
        if (quest.formatType == 'affirmation') {
          return 'Affirmation Quiz'; // Fallback if quizName wasn't set
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
      case QuestType.linked:
        return 'Linked Puzzle';
      case QuestType.wordSearch:
        return 'Word Search';
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
