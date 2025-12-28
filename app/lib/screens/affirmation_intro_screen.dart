import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/brand/brand_loader.dart';
import '../models/branch_progression_state.dart';
import '../services/branch_manifest_service.dart';
import '../services/quiz_match_service.dart';
import '../services/love_point_service.dart';
import '../services/storage_service.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/brand/brand_widget_factory.dart';
import '../widgets/brand/us2/us2_intro_screen.dart';
import 'quiz_match_game_screen.dart';

/// Therapeutic branch names that get the "Deeper" badge
const List<String> _therapeuticBranches = ['connection', 'attachment', 'growth'];

/// Returns true if the branch is a therapeutic branch
bool _isTherapeuticBranch(String? branch) {
  if (branch == null) return false;
  return _therapeuticBranches.contains(branch.toLowerCase());
}

/// Intro screen for Affirmation Quiz (server-centric architecture)
///
/// Editorial newspaper aesthetic with animated content.
/// Does NOT require a pre-loaded session - the game screen fetches
/// from the API when user taps "Begin".
class AffirmationIntroScreen extends StatefulWidget {
  final String? branch; // Branch for manifest video lookup
  final String? questId; // Optional: Daily quest ID for updating local status

  const AffirmationIntroScreen({super.key, this.branch, this.questId});

  @override
  State<AffirmationIntroScreen> createState() => _AffirmationIntroScreenState();
}

class _AffirmationIntroScreenState extends State<AffirmationIntroScreen>
    with TickerProviderStateMixin {
  final StorageService _storage = StorageService();

  // Partner status for banner
  bool _partnerCompleted = false;
  String? _partnerName;

  // Quiz metadata from API/Quest
  String? _quizTitle;
  String? _quizDescription;

  // LP status for reward display
  LpContentStatus? _lpStatus;

  // Video player state
  VideoPlayerController? _videoController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showHeart = false;
  bool _videoError = false;

  // Content stagger animations
  late AnimationController _contentController;
  late Animation<double> _badgeAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _descAnimation;
  late Animation<double> _statsAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _footerAnimation;
  bool _contentAnimationStarted = false;

  @override
  void initState() {
    super.initState();

    // Load quiz metadata from DailyQuest immediately (already synced)
    _loadQuizMetadataFromQuest();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Content stagger animation controller (1200ms total for all elements)
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Staggered intervals for each content element
    _badgeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.1, 0.4, curve: Curves.easeOut),
      ),
    );
    _descAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _statsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );
    _footerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );

    _initializeVideo();
    _checkPartnerStatus();
    _checkLpStatus();

    // Start content animation immediately (don't wait for video)
    // Video is a visual enhancement, not a blocker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContentAnimation();
    });
  }

  /// Load quiz metadata directly from DailyQuest (already synced from home screen)
  void _loadQuizMetadataFromQuest() {
    if (widget.questId == null) return;

    final quest = _storage.getDailyQuest(widget.questId!);

    if (quest != null) {
      _quizTitle = quest.quizName;
      _quizDescription = quest.description;
      _partnerName = _storage.getPartner()?.name;
    }
  }

  /// Check if partner has already completed this quiz
  Future<void> _checkPartnerStatus() async {
    // Skip if quest is already completed - both already answered
    // This avoids calling getOrCreateMatch which would create a new match
    if (widget.questId != null) {
      final quest = _storage.getDailyQuest(widget.questId!);
      if (quest != null && quest.isCompleted) {
        return;
      }
    }

    try {
      final service = QuizMatchService();
      final gameState = await service.getOrCreateMatch('affirmation');

      // Update DailyQuest with quiz metadata if available
      if (widget.questId != null && gameState.quiz != null) {
        final quest = _storage.getDailyQuest(widget.questId!);
        if (quest != null &&
            (quest.quizName == null || quest.quizName == 'Affirmation Quiz')) {
          // Update quest with quiz title and description
          quest.quizName = gameState.quiz!.title;
          quest.description = gameState.quiz!.description;
          await _storage.saveDailyQuest(quest);
        }
      }

      if (mounted) {
        setState(() {
          // Only show partner status if match is active (not completed)
          // and partner has actually answered
          _partnerCompleted = !gameState.isCompleted && gameState.hasPartnerAnswered;
          _partnerName = _storage.getPartner()?.name;
          // Store quiz metadata for display
          _quizTitle ??= gameState.quiz?.title;
          _quizDescription ??= gameState.quiz?.description;
        });
      }
    } catch (e) {
      // Silently fail - banner is optional enhancement
    }
  }

  /// Check LP status for this content type
  Future<void> _checkLpStatus() async {
    final status = await LovePointService.checkLpStatus('affirmation_quiz');
    if (mounted) {
      setState(() {
        _lpStatus = status;
      });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      // Get video path from manifest if branch is provided
      String? videoPath;
      if (widget.branch != null) {
        videoPath = await BranchManifestService().getVideoPath(
          activityType: BranchableActivityType.affirmation,
          branch: widget.branch!,
        );
      }

      // Fallback to default video if no manifest video
      if (videoPath == null || videoPath.isEmpty) {
        final brandId = BrandLoader().config.brandId;
        videoPath = 'assets/brands/$brandId/videos/affirmation.mp4';
      }

      _videoController = VideoPlayerController.asset(videoPath);

      await _videoController!.initialize();

      _videoController!.addListener(_onVideoProgress);
      _videoController!.play();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // If video fails to load, show the heart banner immediately
      if (mounted) {
        setState(() {
          _videoError = true;
          _showHeart = true;
        });
        // Start content animation immediately
        _startContentAnimation();
      }
    }
  }

  void _startContentAnimation() {
    if (_contentAnimationStarted) return;
    _contentAnimationStarted = true;
    _contentController.forward();
  }

  /// Wraps a widget with staggered fade + slide up animation
  Widget _animatedContent(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }

  void _onVideoProgress() {
    if (_videoController == null) return;

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;

    // When video is about to end (or has ended), fade to heart
    if (duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 100) {
      if (!_showHeart) {
        _showHeart = true;
        _fadeController.forward();
        // Start content stagger animation when video ends
        _startContentAnimation();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    _fadeController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _startQuiz() {
    // Navigate to server-centric game screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizMatchGameScreen(
          quizType: 'affirmation',
          questId: widget.questId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partnerName = _storage.getPartner()?.name ?? 'your partner';

    // Us 2.0 brand uses simplified intro screen
    if (BrandWidgetFactory.isUs2) {
      return _buildUs2Intro(partnerName);
    }

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Header (fixed at top)
            _buildHeader(),

            // Partner status banner (shows if partner already completed)
            _buildPartnerStatusBanner(),

            // Scrollable content (includes hero)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image area (scrolls with content)
                    _buildHeroImage(),

                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge(s) (animated)
                          _animatedContent(
                            _badgeAnimation,
                            Row(
                              children: [
                                const EditorialBadge(
                                  label: 'Affirmation',
                                  isInverted: true,
                                ),
                                if (_isTherapeuticBranch(widget.branch)) ...[
                                  const SizedBox(width: 8),
                                  Container(
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
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quiz Info Card (animated) - shows today's theme
                          _animatedContent(
                            _titleAnimation,
                            _buildQuizInfoCard(),
                          ),
                          const SizedBox(height: 16),

                          // Generic instruction (animated)
                          _animatedContent(
                            _descAnimation,
                            Text(
                              'Rate how strongly you agree with statements about yourself. Then compare with $partnerName to discover where you align!',
                              style: EditorialStyles.bodySmall.copyWith(
                                color: EditorialStyles.inkMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Stats card (animated)
                          _animatedContent(
                            _statsAnimation,
                            EditorialStatsCard(
                              rows: [
                                ('Statements', '5'),
                                ('Time', '~3 minutes'),
                                ('Reward', _lpStatus?.alreadyGrantedToday == true
                                    ? 'Earned today'
                                    : '+30 LP'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Rating scale section (animated)
                          _animatedContent(
                            _scaleAnimation,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RATING SCALE',
                                  style: EditorialStyles.labelUppercase,
                                ),
                                const SizedBox(height: 16),
                                _buildScalePreview(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer (fixed at bottom, animated)
            _animatedContent(_footerAnimation, _buildFooter()),
          ],
        ),
      ),
    );
  }

  /// Build Us 2.0 styled intro screen using reusable component
  Widget _buildUs2Intro(String partnerName) {
    final alreadyEarned = _lpStatus?.alreadyGrantedToday == true;

    // Build badges list
    final badges = <String>['AFFIRMATION'];
    if (_isTherapeuticBranch(widget.branch)) {
      badges.add('DEEPER');
    }

    // Build stats with highlight for reward
    final stats = <(String, String, bool)>[
      ('Statements', '5', false),
      ('Time', '~3 minutes', false),
      ('Reward', alreadyEarned ? 'Earned today' : '+30 LP', !alreadyEarned),
    ];

    return Us2IntroScreen.withQuizCard(
      buttonLabel: 'Begin',
      onStart: _startQuiz,
      onBack: () => Navigator.of(context).pop(),
      heroEmoji: '💑',
      badges: badges,
      quizTitle: _quizTitle ?? 'Affirmation Quiz',
      quizDescription: _quizDescription,
      stats: stats,
      instructionText: 'Rate how strongly you agree with statements about yourself. Then compare with $partnerName to discover where you align!',
    );
  }

  /// Build the Quiz Info Card showing today's theme (Liia style)
  Widget _buildQuizInfoCard() {
    final hasQuizData = _quizTitle != null && _quizTitle!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border(
          left: BorderSide(
            color: BrandLoader().colors.primary,
            width: 4,
          ),
          top: EditorialStyles.border,
          right: EditorialStyles.border,
          bottom: EditorialStyles.border,
        ),
        boxShadow: [
          BoxShadow(
            color: EditorialStyles.ink.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Today's Theme" label
          Text(
            "TODAY'S THEME",
            style: EditorialStyles.labelUppercaseSmall.copyWith(
              color: BrandLoader().colors.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          // Quiz title
          Text(
            hasQuizData ? _quizTitle! : 'Affirmation Quiz',
            style: EditorialStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          // Quiz description (if available)
          if (hasQuizData && _quizDescription != null && _quizDescription!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _quizDescription!,
              style: EditorialStyles.bodyTextItalic.copyWith(
                fontSize: 14,
                color: EditorialStyles.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border(bottom: EditorialStyles.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: EditorialStyles.paper,
                border: EditorialStyles.fullBorder,
              ),
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: EditorialStyles.ink,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'DAILY QUEST',
            style: EditorialStyles.labelUppercase,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EditorialStyles.inkLight,
            EditorialStyles.paper,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: EditorialStyles.border),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video layer (shows first, then fades out)
            if (_videoController != null &&
                _videoController!.value.isInitialized &&
                !_videoError)
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: 1.0 - _fadeAnimation.value,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  );
                },
              ),

            // Heart layer (fades in after video) - grayscale
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                // Show immediately if video failed or not loaded
                final showImmediately = _videoError ||
                    _videoController == null ||
                    !_videoController!.value.isInitialized;

                return Opacity(
                  opacity: showImmediately ? 1.0 : _fadeAnimation.value,
                  child: Center(
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Text(
                        '❤️',
                        style: TextStyle(
                          fontSize: 64,
                          color: EditorialStyles.ink.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScalePreview() {
    const labels = [
      'Strongly\nDisagree',
      'Disagree',
      'Neutral',
      'Agree',
      'Strongly\nAgree',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You\'ll rate each statement on a 5-point scale from strongly disagree to strongly agree.',
            style: EditorialStyles.bodyTextItalic.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final isSelected = index == 4; // Show "Strongly Agree" as selected
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected ? EditorialStyles.ink : EditorialStyles.paper,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: EditorialStyles.ink,
                          width: EditorialStyles.borderWidth,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: EditorialStyles.counterText.copyWith(
                            color: isSelected ? EditorialStyles.paper : EditorialStyles.ink,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: EditorialStyles.labelUppercaseSmall.fontFamily,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: EditorialStyles.inkMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerStatusBanner() {
    if (!_partnerCompleted || _partnerName == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border(bottom: EditorialStyles.border),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: EditorialStyles.ink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_partnerName has answered',
                  style: EditorialStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  "It's your turn!",
                  style: EditorialStyles.bodySmall.copyWith(
                    color: EditorialStyles.inkMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final alreadyEarned = _lpStatus?.alreadyGrantedToday == true;
    final resetTime = _lpStatus?.resetTimeFormatted ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border(top: EditorialStyles.border),
      ),
      child: Column(
        children: [
          EditorialPrimaryButton(
            label: 'Begin',
            onPressed: _startQuiz,
          ),
          const SizedBox(height: 12),
          Text(
            alreadyEarned
                ? 'LP already earned today · Resets in $resetTime'
                : 'Complete to earn +30 Love Points',
            style: EditorialStyles.bodySmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
