import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/brand/brand_loader.dart';
import '../models/quiz_session.dart';
import '../models/branch_progression_state.dart';
import '../services/branch_manifest_service.dart';
import '../widgets/editorial/editorial.dart';
import 'quiz_question_screen.dart';

/// Intro screen for affirmation-style quizzes
/// Editorial newspaper aesthetic with scale preview
class AffirmationIntroScreen extends StatefulWidget {
  final QuizSession session;
  final String? branch; // Branch for manifest video lookup

  const AffirmationIntroScreen({
    super.key,
    required this.session,
    this.branch,
  });

  @override
  State<AffirmationIntroScreen> createState() => _AffirmationIntroScreenState();
}

class _AffirmationIntroScreenState extends State<AffirmationIntroScreen>
    with TickerProviderStateMixin {
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

  String _getDescription(String category) {
    switch (category) {
      case 'trust':
        return 'Rate how strongly you agree with statements about trust and emotional safety in your relationship.';
      case 'emotional_support':
        return 'Rate how strongly you agree with statements about emotional support and understanding.';
      case 'commitment':
        return 'Rate how strongly you agree with statements about commitment and dedication.';
      case 'intimacy':
        return 'Rate how strongly you agree with statements about emotional and physical closeness.';
      case 'relationship_satisfaction':
        return 'Rate how strongly you agree with statements about overall relationship satisfaction.';
      case 'shared_values':
        return 'Rate how strongly you agree with statements about shared values and goals.';
      default:
        return 'Rate how strongly you agree with statements about your relationship\'s emotional foundation.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Header (fixed at top)
            _buildHeader(context),

            // Scrollable content (includes hero)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image with video (scrolls with content)
                    _buildHeroImage(),

                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge (animated)
                          _animatedContent(
                            _badgeAnimation,
                            const EditorialBadge(
                              label: 'Affirmation',
                              isInverted: true,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title (animated)
                          _animatedContent(
                            _titleAnimation,
                            Text(
                              widget.session.quizName ?? 'Affirmation Quiz',
                              style: EditorialStyles.headline,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description (animated)
                          _animatedContent(
                            _descAnimation,
                            Text(
                              _getDescription(widget.session.category ?? 'trust'),
                              style: EditorialStyles.bodyTextItalic,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Stats card (animated)
                          _animatedContent(
                            _statsAnimation,
                            EditorialStatsCard(
                              rows: [
                                ('Statements', '${widget.session.questionIds.length}'),
                                ('Time', '~3 minutes'),
                                ('Reward', '+30 LP'),
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
            _animatedContent(_footerAnimation, _buildFooter(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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

  Widget _buildFooter(BuildContext context) {
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
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => QuizQuestionScreen(session: widget.session),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Complete to earn +30 Love Points',
            style: EditorialStyles.bodySmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
