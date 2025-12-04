import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import '../services/haptic_service.dart';
import '../services/couple_preferences_service.dart';
import '../config/brand/brand_loader.dart';
import '../theme/app_theme.dart';
import '../animations/animation_config.dart';
import 'animated_checkmark.dart';

/// Therapeutic branch names that get the "Deeper" badge
const List<String> _therapeuticBranches = ['connection', 'attachment', 'growth'];

/// Returns true if the branch is a therapeutic branch
bool _isTherapeuticBranch(String? branch) {
  if (branch == null) return false;
  return _therapeuticBranches.contains(branch.toLowerCase());
}

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
  String? _firstPlayerName; // For "who goes first" display on turn-based games
  bool? _isMyTurn; // For turn-based games: true if it's current user's turn
  bool _hasActiveGame = false; // Whether a game is in progress
  bool _firstPlayerLoaded = false; // Guard to prevent repeated async calls

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

    // Load turn-based game state (Linked, Word Search)
    if (widget.quest.type == QuestType.linked || widget.quest.type == QuestType.wordSearch) {
      _loadTurnBasedGameState();
    }
  }

  void _loadTurnBasedGameState() {
    // Synchronous part: check active game from Hive (fast, local read)
    final storage = StorageService();
    final user = storage.getUser();
    final userId = user?.id;

    if (userId == null) return;

    // Check for active game in local storage
    String? currentTurnUserId;
    bool hasActiveGame = false;

    if (widget.quest.type == QuestType.linked) {
      final activeMatch = storage.getActiveLinkedMatch();
      if (activeMatch != null && activeMatch.status != 'completed') {
        hasActiveGame = true;
        currentTurnUserId = activeMatch.currentTurnUserId;
      }
    } else if (widget.quest.type == QuestType.wordSearch) {
      final activeMatch = storage.getActiveWordSearchMatch();
      if (activeMatch != null && activeMatch.status != 'completed') {
        hasActiveGame = true;
        currentTurnUserId = activeMatch.currentTurnUserId;
      }
    }

    // If game is active, determine whose turn it is (synchronous)
    if (hasActiveGame && currentTurnUserId != null) {
      _hasActiveGame = true;
      _isMyTurn = currentTurnUserId == userId;
      return;
    }

    // No active game - reset turn state and load "who goes first" preference (async, once)
    _hasActiveGame = false;
    _isMyTurn = null;
    if (!_firstPlayerLoaded) {
      _firstPlayerLoaded = true;
      _loadFirstPlayerPreference();
    }
  }

  Future<void> _loadFirstPlayerPreference() async {
    try {
      final storage = StorageService();
      final user = storage.getUser();
      final partner = storage.getPartner();

      final firstPlayerId = await CouplePreferencesService().getFirstPlayerId();

      if (mounted) {
        setState(() {
          if (firstPlayerId == user?.id) {
            _firstPlayerName = user?.name ?? 'You';
          } else if (firstPlayerId == partner?.id) {
            _firstPlayerName = partner?.name ?? 'Partner';
          } else {
            _firstPlayerName = null;
          }
        });
      }
    } catch (e) {
      // Silently fail - will show "Begin together" as fallback
    }
  }

  @override
  void didUpdateWidget(QuestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh turn-based game state when widget rebuilds (e.g., after polling updates)
    if (widget.quest.type == QuestType.linked || widget.quest.type == QuestType.wordSearch) {
      _loadTurnBasedGameState();
    }
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
    // For turn-based games, refresh turn state on every build (Hive read is fast)
    // This ensures we always show current turn status after navigation or polling
    if (widget.quest.type == QuestType.linked || widget.quest.type == QuestType.wordSearch) {
      _loadTurnBasedGameState();
    }

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
            // Includes "Deeper" badge overlay for therapeutic branches
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
                child: Stack(
                  children: [
                    ConstrainedBox(
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
                    // "Deeper" badge for therapeutic branches
                    if (_isTherapeuticBranch(widget.quest.branch))
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          color: BrandLoader().colors.textPrimary,
                          child: Text(
                            'DEEPER',
                            style: TextStyle(
                              color: BrandLoader().colors.textOnPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
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

  /// Check if partner has completed this quest
  /// Uses partner.id (UUID) if available, falls back to pushToken for backward compatibility
  bool _hasPartnerCompleted(dynamic partner) {
    // Prefer partner.id (UUID) - matches how user completions are stored
    if (partner.id != null && partner.id.isNotEmpty) {
      return widget.quest.hasUserCompleted(partner.id);
    }
    // Fallback to pushToken for backward compatibility with old Partner data
    return widget.quest.hasUserCompleted(partner.pushToken);
  }

  /// Get user's initial for badge display (e.g., "J" for Joakim)
  String _getUserInitial(dynamic user) {
    if (user?.name != null && user.name.isNotEmpty) {
      return user.name[0].toUpperCase();
    }
    return '•'; // Fallback dot if no name available
  }

  Widget _buildStatusBadge(dynamic user, dynamic partner, bool userCompleted, bool bothCompleted) {
    // For turn-based games (Linked, Word Search), check turn status FIRST
    // These games have multiple turns before completion, unlike quizzes where each user plays once
    final isTurnBased = widget.quest.type == QuestType.linked || widget.quest.type == QuestType.wordSearch;

    if (isTurnBased && _hasActiveGame) {
      // Game is in progress - show whose turn it is
      if (_isMyTurn == true && partner != null) {
        // It's my turn - show "Partner is waiting" (social nudge)
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
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BrandLoader().colors.textOnPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${partner.name} is waiting',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BrandLoader().colors.textPrimary,
                ),
              ),
            ],
          ),
        );
      } else if (_isMyTurn == false) {
        // It's partner's turn - show "Waiting for Partner"
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
                    _getUserInitial(user),
                    style: AppTheme.headlineFont.copyWith(
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
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        );
      }
      // If _isMyTurn is null, fall through to standard logic
    }

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
    } else if (partner != null && _hasPartnerCompleted(partner)) {
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
              '${partner.name} has completed',
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
                  _getUserInitial(user),
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
      // Fresh quest - show who goes first (turn-based) or "Begin together"
      String statusText;
      if (isTurnBased && _firstPlayerName != null) {
        statusText = '$_firstPlayerName goes first';
      } else {
        statusText = 'Begin together';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: BrandLoader().colors.surface,
          border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
        ),
        child: Text(
          statusText,
          style: AppTheme.headlineFont.copyWith( // Serif font
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: BrandLoader().colors.textPrimary,
          ),
        ),
      );
    }
  }

  String _getQuestTitle() {
    // Priority 1: Use quest's quizName if available
    // This is set from branch manifest at quest creation time
    if (widget.quest.quizName != null && widget.quest.quizName!.isNotEmpty) {
      return widget.quest.quizName!;
    }

    // Priority 2: Fallback to quest type-based titles
    switch (widget.quest.type) {
      case QuestType.question:
        return 'Daily Question';
      case QuestType.quiz:
        if (widget.quest.formatType == 'affirmation') {
          return 'Affirmation Quiz';
        }
        return 'Couple Quiz'; // Fallback for classic quizzes without manifest
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
}
