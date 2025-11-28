import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import '../services/haptic_service.dart';
import '../config/brand/brand_loader.dart';
import '../theme/app_theme.dart';
import '../animations/animation_config.dart';
import 'animated_checkmark.dart';

/// Card displaying a single daily quest with image, title, description, and status
///
/// New carousel design with:
/// - Image at top (170px height)
/// - Title + description + reward badge
/// - Status badges (Your Turn / Partner completed / Completed)
/// - Press animation with scale, shadow lift, and haptic feedback
class QuestCard extends StatefulWidget {
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
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  bool _isPressed = false;

  bool get _isExpired => widget.quest.isExpired;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AnimationConfig.fast,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: AnimationConfig.buttonPress,
    ));
    _shadowAnimation = Tween<double>(
      begin: 4.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: AnimationConfig.buttonPress,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (_isExpired) return;
    setState(() => _isPressed = true);
    _pressController.forward();
    HapticService().tap();
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isExpired) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _handleTapCancel() {
    if (_isExpired) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _handleTap() {
    if (_isExpired) return;
    SoundService().tap();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();

    // Determine quest status for current user
    final userCompleted = widget.currentUserId != null && widget.quest.hasUserCompleted(widget.currentUserId!);
    final bothCompleted = widget.quest.isCompleted;
    final isExpired = _isExpired;

    // Get image path based on quest type
    final imagePath = _getQuestImage();

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: isExpired ? 0.5 : (_isPressed ? 0.9 : 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: BrandLoader().colors.surface,
                  border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
                  borderRadius: BorderRadius.circular(0), // Sharp corners like mockup
                  boxShadow: widget.showShadow
                      ? [
                          BoxShadow(
                            color: BrandLoader().colors.textPrimary.withOpacity(0.15),
                            blurRadius: 0,
                            offset: Offset(_shadowAnimation.value, _shadowAnimation.value),
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image (top, full-width) with bottom border and white background
            // Dynamic height based on image aspect ratio (no cropping)
            if (imagePath != null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: BrandLoader().colors.textPrimary,
                      width: 1,
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200, // Cap height for very tall images
                  ),
                  child: Image.asset(
                    imagePath,
                    width: double.infinity,
                    fit: BoxFit.fitWidth, // Scale to card width, height follows aspect ratio
                    alignment: Alignment.topCenter, // Start from top, don't center vertically
                    // Note: No cacheWidth - use full resolution for crisp display on high-DPI screens
                    errorBuilder: (context, error, stackTrace) {
                      // Show fallback placeholder when image fails to load
                      return Container(
                        height: 120,
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
                ),
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
                          '+${widget.quest.lpAwarded ?? 30}',
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
    );
  }

  String? _getQuestImage() {
    // Option 1: Use quest's imagePath if available (from quiz JSON)
    // This is the preferred method - imagePath is denormalized from quiz definition
    if (widget.quest.imagePath != null && widget.quest.imagePath!.isNotEmpty) {
      return widget.quest.imagePath;
    }

    // Option 2: Fallback to quest type-based images (backward compatibility)
    // Used for old quests without imagePath
    final questImages = BrandLoader().assets.questImagesPath;
    switch (widget.quest.type) {
      case QuestType.quiz:
        // Fallback for quizzes without imagePath
        if (widget.quest.formatType == 'affirmation') {
          return '$questImages/affirmation-default.png';
        }
        return '$questImages/classic-quiz-default.png';
      case QuestType.youOrMe:
        return '$questImages/you-or-me.png';
      case QuestType.question:
        return '$questImages/daily-question.png';
      case QuestType.linked:
        return '$questImages/linked.png';
      case QuestType.wordSearch:
        return '$questImages/word-search.png';
      case QuestType.steps:
        // Steps Together uses a special card widget, but fallback to emoji
        return null;
      default:
        return null;
    }
  }

  String _getQuestDescription() {
    // Option 1: Use quest's description if available (from quiz JSON)
    // This is the preferred method - description is denormalized from quiz definition
    if (widget.quest.description != null && widget.quest.description!.isNotEmpty) {
      return widget.quest.description!;
    }

    // Option 2: Fallback to quest type-based descriptions (backward compatibility)
    switch (widget.quest.type) {
      case QuestType.quiz:
        if (widget.quest.formatType == 'affirmation') {
          return 'Rate your feelings together';
        }
        return 'Answer ten questions together';
      case QuestType.youOrMe:
        return 'Guess who said what';
      case QuestType.question:
        return 'Share your thoughts';
      case QuestType.wordSearch:
        return 'Find twelve hidden words';
      case QuestType.steps:
        return 'Walk together, earn together';
      default:
        return '';
    }
  }

  Widget _buildStatusBadge(dynamic user, dynamic partner, bool userCompleted, bool bothCompleted) {
    if (bothCompleted) {
      // Animated completion badge with draw-in checkmark
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.0),
        duration: AnimationConfig.normal,
        curve: AnimationConfig.scaleIn,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: BrandLoader().colors.textPrimary,
                border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCheckmark(
                    size: 12,
                    color: BrandLoader().colors.textOnPrimary,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'COMPLETED',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: BrandLoader().colors.textOnPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (partner != null && widget.quest.hasUserCompleted(partner.pushToken)) {
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
    } else if (userCompleted) {
      // User completed, waiting for partner
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
      // User's turn
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
    if (widget.quest.quizName != null && widget.quest.quizName!.isNotEmpty) {
      return widget.quest.quizName!;
    }

    // Option 2: Fallback to quest type-based titles
    switch (widget.quest.type) {
      case QuestType.question:
        return 'Daily Question';
      case QuestType.quiz:
        // Check quest formatType first (always available from Firebase)
        if (widget.quest.formatType == 'affirmation') {
          return 'Affirmation Quiz'; // Fallback if quizName wasn't set
        }
        // Use sort order to generate distinct titles for classic quizzes
        return _getQuizTitle(widget.quest.sortOrder);
      case QuestType.game:
        return 'Fun Game';
      case QuestType.youOrMe:
        return 'You or Me?';
      case QuestType.linked:
        return 'Crossword Puzzle';
      case QuestType.wordSearch:
        return 'Word Search';
      case QuestType.steps:
        return 'Steps Together';
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
