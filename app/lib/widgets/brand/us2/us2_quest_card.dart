import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/models/daily_quest.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/couple_preferences_service.dart';
import 'package:togetherremind/services/haptic_service.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/widgets/quest_guidance_overlay.dart';

/// Therapeutic branch names that get the "Deeper" badge
const List<String> _therapeuticBranches = ['connection', 'attachment', 'growth'];

/// Returns true if the branch is a therapeutic branch
bool _isTherapeuticBranch(String? branch) {
  if (branch == null) return false;
  return _therapeuticBranches.contains(branch.toLowerCase());
}

/// Us 2.0 quest card with full status handling
///
/// States supported:
/// - Fresh: "Begin together" or "[Name] goes first" for turn-based
/// - Your turn: Partner completed, pulsing indicator
/// - Urgent: Partner is waiting (turn-based games)
/// - Waiting: You completed, animated dots
/// - Results ready: Both completed, glowing animation
/// - Completed: Green checkmark
/// - Locked: Grayscale with lock icon
class Us2QuestCard extends StatefulWidget {
  final DailyQuest? quest;
  final String title;
  final String description;
  final String emoji;
  final String buttonLabel;
  final VoidCallback onTap;
  final bool isSmall;
  final double? width;
  final String? imagePath;
  final String? currentUserId;
  final bool isLocked;
  final String? unlockCriteria;
  final bool showGuidance;
  final String? guidanceText;

  const Us2QuestCard({
    super.key,
    this.quest,
    required this.title,
    required this.description,
    required this.emoji,
    required this.buttonLabel,
    required this.onTap,
    this.isSmall = false,
    this.width,
    this.imagePath,
    this.currentUserId,
    this.isLocked = false,
    this.unlockCriteria,
    this.showGuidance = false,
    this.guidanceText,
  });

  @override
  State<Us2QuestCard> createState() => _Us2QuestCardState();
}

class _Us2QuestCardState extends State<Us2QuestCard>
    with TickerProviderStateMixin {
  bool _isPressed = false;
  String? _firstPlayerName;
  bool? _isMyTurn;
  bool _hasActiveGame = false;
  bool _firstPlayerLoaded = false;

  @override
  void initState() {
    super.initState();
    if (_isTurnBased) {
      _loadTurnBasedGameState();
    }
  }

  bool get _isTurnBased =>
      widget.quest?.type == QuestType.linked ||
      widget.quest?.type == QuestType.wordSearch;

  void _loadTurnBasedGameState() {
    final storage = StorageService();
    final user = storage.getUser();
    final userId = user?.id;

    if (userId == null) return;

    String? currentTurnUserId;
    bool hasActiveGame = false;

    if (widget.quest?.type == QuestType.linked) {
      final activeMatch = storage.getActiveLinkedMatch();
      if (activeMatch != null && activeMatch.status != 'completed') {
        hasActiveGame = true;
        currentTurnUserId = activeMatch.currentTurnUserId;
      }
    } else if (widget.quest?.type == QuestType.wordSearch) {
      final activeMatch = storage.getActiveWordSearchMatch();
      if (activeMatch != null && activeMatch.status != 'completed') {
        hasActiveGame = true;
        currentTurnUserId = activeMatch.currentTurnUserId;
      }
    }

    if (hasActiveGame && currentTurnUserId != null) {
      _hasActiveGame = true;
      _isMyTurn = currentTurnUserId == userId;
      return;
    }

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
  void didUpdateWidget(Us2QuestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isTurnBased) {
      _loadTurnBasedGameState();
    }
  }

  void _handleTap() {
    if (widget.isLocked) {
      HapticService().trigger(HapticType.light);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.unlockCriteria ?? 'Complete other activities to unlock'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    SoundService().tap();
    widget.onTap();
  }

  bool _hasPartnerCompleted(dynamic partner) {
    if (widget.quest == null) return false;
    if (partner?.id != null && partner.id.isNotEmpty) {
      return widget.quest!.hasUserCompleted(partner.id);
    }
    return widget.quest!.hasUserCompleted(partner?.pushToken ?? '');
  }

  String _getUserInitial(dynamic user) {
    if (user?.name != null && user.name.isNotEmpty) {
      return user.name[0].toUpperCase();
    }
    return '•';
  }

  @override
  Widget build(BuildContext context) {
    // Refresh turn state on every build for turn-based games
    if (_isTurnBased) {
      _loadTurnBasedGameState();
    }

    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();

    final userCompleted = widget.currentUserId != null &&
        widget.quest?.hasUserCompleted(widget.currentUserId!) == true;
    final bothCompleted = widget.quest?.isCompleted ?? false;

    final cardWidth = widget.width ?? (widget.isSmall ? 250.0 : 320.0);
    final imageHeight = widget.isSmall ? 130.0 : 180.0;
    final emojiSize = widget.isSmall ? 50.0 : 60.0;

    // Grayscale matrix for locked state
    const grayscaleMatrix = <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ];

    Widget cardContent = Container(
      width: cardWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image section (fixed height)
          Stack(
            children: [
              Container(
                height: imageHeight,
                decoration: BoxDecoration(
                  gradient: widget.isLocked
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE0E0E0), Color(0xFFCCCCCC)],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFDDD2), Color(0xFFFFCABA)],
                        ),
                ),
                child: widget.imagePath != null
                    ? Image.asset(
                        widget.imagePath!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: imageHeight,
                        alignment: Alignment.topCenter,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(widget.emoji, style: TextStyle(fontSize: emojiSize)),
                          );
                        },
                      )
                    : Center(
                        child: Text(widget.emoji, style: TextStyle(fontSize: emojiSize)),
                      ),
              ),
              // Deeper badge
              if (_isTherapeuticBranch(widget.quest?.branch))
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEEPER',
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              // Lock overlay
              if (widget.isLocked)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🔒', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Content section (expands to fill remaining space)
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                widget.isSmall ? 14 : 20,
                widget.isSmall ? 12 : 18,
                widget.isSmall ? 14 : 20,
                widget.isSmall ? 14 : 22,
              ),
              decoration: BoxDecoration(
                gradient: widget.isLocked
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFA0A0A0), Color(0xFF909090)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF7B6B), Color(0xFFFF6B5B)],
                      ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: widget.isSmall ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    widget.description,
                    style: GoogleFonts.nunito(
                      fontSize: widget.isSmall ? 12 : 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.3,
                    ),
                  ),
                  // Spacer pushes divider and button to bottom
                  const Spacer(),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.25),
                  ),
                  SizedBox(height: widget.isSmall ? 12 : 16),
                  // Status badge or button
                  _buildStatusWidget(user, partner, userCompleted, bothCompleted),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Apply grayscale filter when locked
    if (widget.isLocked) {
      cardContent = ColorFiltered(
        colorFilter: const ColorFilter.matrix(grayscaleMatrix),
        child: cardContent,
      );
    }

    return QuestGuidanceOverlay(
      showGuidance: widget.showGuidance,
      ribbonText: widget.guidanceText ?? 'Start Here',
      child: GestureDetector(
        onTapDown: (_) {
          if (!widget.isLocked) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (!widget.isLocked) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (!widget.isLocked) setState(() => _isPressed = false);
        },
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _isPressed ? 2 : 0, 0),
          child: cardContent,
        ),
      ),
    );
  }

  Widget _buildStatusWidget(dynamic user, dynamic partner, bool userCompleted, bool bothCompleted) {
    // For locked quests
    if (widget.isLocked) {
      return _Us2StatusBadge(
        style: _StatusStyle.locked,
        text: widget.unlockCriteria ?? 'Complete a quiz to unlock',
        icon: '🔒',
      );
    }

    // No quest provided - show simple button (card handles tap)
    if (widget.quest == null) {
      return _Us2QuestButton(
        label: widget.buttonLabel,
        isSmall: widget.isSmall,
      );
    }

    // Turn-based games (Linked, Word Search) - check turn status FIRST
    if (_isTurnBased && _hasActiveGame) {
      if (_isMyTurn == true && partner != null) {
        // It's my turn - partner is waiting (urgent)
        return _Us2StatusBadge(
          style: _StatusStyle.urgent,
          text: '${partner.name} is waiting',
          userInitial: partner.name[0].toUpperCase(),
          showInitialOnGradient: true,
        );
      } else if (_isMyTurn == false) {
        // Partner's turn - waiting with animated dots
        return _Us2StatusBadge(
          style: _StatusStyle.waiting,
          text: "${partner?.name ?? 'Partner'}'s turn",
          userInitial: _getUserInitial(user),
          showAnimatedDots: true,
        );
      }
    }

    // Check for pending results
    String? contentType;
    if (widget.quest!.type == QuestType.quiz) {
      contentType = widget.quest!.formatType == 'affirmation' ? 'affirmation_quiz' : 'classic_quiz';
    } else if (widget.quest!.type == QuestType.youOrMe) {
      contentType = 'you_or_me';
    } else if (widget.quest!.type == QuestType.linked) {
      contentType = 'linked';
    } else if (widget.quest!.type == QuestType.wordSearch) {
      contentType = 'word_search';
    }

    if (contentType != null && bothCompleted && StorageService().hasPendingResults(contentType)) {
      return _Us2StatusBadge(
        style: _StatusStyle.resultsReady,
        text: 'Results are ready!',
      );
    }

    // Both completed
    if (bothCompleted) {
      return _Us2StatusBadge(
        style: _StatusStyle.completed,
        text: 'Completed',
      );
    }

    // Partner completed, your turn
    if (partner != null && _hasPartnerCompleted(partner)) {
      return _Us2StatusBadge(
        style: _StatusStyle.yourTurn,
        text: '${partner.name} has finished',
        userInitial: partner.name[0].toUpperCase(),
        showPulseDot: true,
      );
    }

    // User completed, waiting for partner
    if (userCompleted) {
      return _Us2StatusBadge(
        style: _StatusStyle.waiting,
        text: 'Waiting for ${partner?.name ?? "partner"}',
        userInitial: _getUserInitial(user),
        showAnimatedDots: true,
      );
    }

    // Fresh quest
    if (_isTurnBased && _firstPlayerName != null) {
      return _Us2StatusBadge(
        style: _StatusStyle.firstPlayer,
        text: '$_firstPlayerName goes first',
        userInitial: _firstPlayerName![0].toUpperCase(),
      );
    }

    return _Us2StatusBadge(
      style: _StatusStyle.fresh,
      text: 'Begin together',
      icon: '✨',
    );
  }
}

enum _StatusStyle {
  fresh,
  firstPlayer,
  yourTurn,
  urgent,
  waiting,
  resultsReady,
  completed,
  locked,
}

/// Status badge widget with different styles
class _Us2StatusBadge extends StatefulWidget {
  final _StatusStyle style;
  final String text;
  final String? icon;
  final String? userInitial;
  final bool showPulseDot;
  final bool showAnimatedDots;
  final bool showInitialOnGradient;

  const _Us2StatusBadge({
    required this.style,
    required this.text,
    this.icon,
    this.userInitial,
    this.showPulseDot = false,
    this.showAnimatedDots = false,
    this.showInitialOnGradient = false,
  });

  @override
  State<_Us2StatusBadge> createState() => _Us2StatusBadgeState();
}

class _Us2StatusBadgeState extends State<_Us2StatusBadge>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _dotsController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.showPulseDot) {
      _pulseController.repeat();
    }
    if (widget.showAnimatedDots) {
      _dotsController.repeat();
    }
    if (widget.style == _StatusStyle.resultsReady) {
      _glowController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotsController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildBadge();
  }

  Widget _buildBadge() {
    switch (widget.style) {
      case _StatusStyle.fresh:
        return _buildFreshBadge();
      case _StatusStyle.firstPlayer:
        return _buildFirstPlayerBadge();
      case _StatusStyle.yourTurn:
        return _buildYourTurnBadge();
      case _StatusStyle.urgent:
        return _buildUrgentBadge();
      case _StatusStyle.waiting:
        return _buildWaitingBadge();
      case _StatusStyle.resultsReady:
        return _buildResultsReadyBadge();
      case _StatusStyle.completed:
        return _buildCompletedBadge();
      case _StatusStyle.locked:
        return _buildLockedBadge();
    }
  }

  Widget _buildFreshBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Text(widget.icon!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
          ],
          Text(
            widget.text,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstPlayerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserInitial(isGradient: true),
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourTurnBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserInitial(isSalmonBg: true),
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Us2Theme.cardSalmon,
            ),
          ),
          if (widget.showPulseDot) ...[
            const SizedBox(width: 8),
            _buildPulseDot(),
          ],
        ],
      ),
    );
  }

  Widget _buildUrgentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.glowPink.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserInitial(isWhiteBg: true),
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserInitial(isWhiteBg: true, textSalmon: true),
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (widget.showAnimatedDots) ...[
            const SizedBox(width: 8),
            _buildAnimatedDots(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsReadyBadge() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowValue = 0.3 + 0.2 * (0.5 + 0.5 * (_glowController.value * 2 - 1).abs());
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Us2Theme.gradientAccentStart.withOpacity(glowValue),
                blurRadius: 20 + 10 * _glowController.value,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(
                widget.text,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.cardSalmon,
                ),
              ),
              const SizedBox(width: 8),
              const Text('✨', style: TextStyle(fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.check,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Text(widget.icon!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.text,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInitial({
    bool isGradient = false,
    bool isSalmonBg = false,
    bool isWhiteBg = false,
    bool textSalmon = false,
  }) {
    if (widget.userInitial == null) return const SizedBox.shrink();

    BoxDecoration decoration;
    Color textColor;

    if (isGradient) {
      decoration = const BoxDecoration(
        gradient: LinearGradient(
          colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
        ),
        shape: BoxShape.circle,
      );
      textColor = Colors.white;
    } else if (isSalmonBg) {
      decoration = const BoxDecoration(
        color: Us2Theme.cardSalmon,
        shape: BoxShape.circle,
      );
      textColor = Colors.white;
    } else if (isWhiteBg) {
      decoration = const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      );
      textColor = textSalmon ? Us2Theme.cardSalmon : Us2Theme.gradientAccentStart;
    } else {
      decoration = BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Us2Theme.cardSalmon, width: 2),
      );
      textColor = Us2Theme.cardSalmon;
    }

    return Container(
      width: 22,
      height: 22,
      decoration: decoration,
      child: Center(
        child: Text(
          widget.userInitial!,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPulseDot() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + 0.2 * (0.5 + 0.5 * (_pulseController.value * 2 - 1).abs());
        final opacity = 1.0 - 0.3 * (0.5 + 0.5 * (_pulseController.value * 2 - 1).abs());
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Us2Theme.gradientAccentStart,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _dotsController,
          builder: (context, child) {
            final delay = index * 0.2;
            final progress = (_dotsController.value + delay) % 1.0;
            final bounce = progress < 0.4
                ? -4.0 * (progress / 0.4)
                : (progress < 0.8 ? -4.0 * (1 - (progress - 0.4) / 0.4) : 0.0);
            return Transform.translate(
              offset: Offset(0, bounce),
              child: Container(
                width: 4,
                height: 4,
                margin: EdgeInsets.only(left: index > 0 ? 3 : 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Glowing pill button for quest cards (visual only - card handles tap)
class _Us2QuestButton extends StatelessWidget {
  final String label;
  final bool isSmall;

  const _Us2QuestButton({
    required this.label,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 18 : 24,
        vertical: isSmall ? 12 : 14,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFFFF5E6),
          ],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: Us2Theme.gradientAccentStart,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.glowPink.withOpacity(0.7),
            blurRadius: 25,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: Us2Theme.textDark,
          ),
        ),
      ),
    );
  }
}
