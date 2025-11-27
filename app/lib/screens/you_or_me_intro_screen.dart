import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/you_or_me.dart';
import '../models/branch_progression_state.dart';
import '../services/storage_service.dart';
import '../services/branch_manifest_service.dart';
import '../widgets/editorial/editorial.dart';
import '../config/brand/brand_loader.dart';
import 'you_or_me_game_screen.dart';

/// Intro screen for You or Me game
/// Editorial newspaper aesthetic with example card and instructions
class YouOrMeIntroScreen extends StatefulWidget {
  final YouOrMeSession session;
  final String? branch; // Branch for manifest video lookup

  const YouOrMeIntroScreen({
    super.key,
    required this.session,
    this.branch,
  });

  @override
  State<YouOrMeIntroScreen> createState() => _YouOrMeIntroScreenState();
}

class _YouOrMeIntroScreenState extends State<YouOrMeIntroScreen>
    with TickerProviderStateMixin {
  int? _exampleSelected; // 0 = You, 1 = Partner

  // Video player state
  VideoPlayerController? _videoController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showIcon = false;
  bool _videoError = false;

  // Content stagger animations
  late AnimationController _contentController;
  late Animation<double> _badgeAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _descAnimation;
  late Animation<double> _statsAnimation;
  late Animation<double> _exampleAnimation;
  late Animation<double> _stepsAnimation;
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

    // Content stagger animation controller (1400ms total for all elements)
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    // Staggered intervals for each content element
    _badgeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );
    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.07, 0.32, curve: Curves.easeOut),
      ),
    );
    _descAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.14, 0.39, curve: Curves.easeOut),
      ),
    );
    _statsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.21, 0.46, curve: Curves.easeOut),
      ),
    );
    _exampleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.28, 0.53, curve: Curves.easeOut),
      ),
    );
    _stepsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
      ),
    );
    _footerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.42, 0.67, curve: Curves.easeOut),
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
          activityType: BranchableActivityType.youOrMe,
          branch: widget.branch!,
        );
      }

      // Fallback to default video if no manifest video
      if (videoPath == null || videoPath.isEmpty) {
        final brandId = BrandLoader().config.brandId;
        videoPath = 'assets/brands/$brandId/videos/getting-comfortable.mp4';
      }

      _videoController = VideoPlayerController.asset(videoPath);

      await _videoController!.initialize();

      _videoController!.addListener(_onVideoProgress);
      _videoController!.play();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // If video fails to load, show the icon immediately
      if (mounted) {
        setState(() {
          _videoError = true;
          _showIcon = true;
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

    // When video is about to end (or has ended), fade to icon
    if (duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 100) {
      if (!_showIcon) {
        _showIcon = true;
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

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final partner = storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

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
                    // Hero image area (scrolls with content)
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
                              label: 'You or Me',
                              isInverted: true,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title (animated)
                          _animatedContent(
                            _titleAnimation,
                            Text(
                              'Who Does It Best?',
                              style: EditorialStyles.headline,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description (animated)
                          _animatedContent(
                            _descAnimation,
                            Text(
                              'For each trait or behavior, decide who it describes better—you or $partnerName. See how well you know each other!',
                              style: EditorialStyles.bodyTextItalic,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Stats card (animated)
                          _animatedContent(
                            _statsAnimation,
                            EditorialStatsCard(
                              rows: [
                                ('Questions', '${widget.session.questions.length}'),
                                ('Time', '~3 minutes'),
                                ('Reward', '+30 LP'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Example section (animated)
                          _animatedContent(
                            _exampleAnimation,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EXAMPLE',
                                  style: EditorialStyles.labelUppercase,
                                ),
                                const SizedBox(height: 16),
                                _buildExampleCard(partnerName),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Instructions (animated)
                          _animatedContent(
                            _stepsAnimation,
                            Column(
                              children: [
                                _buildStep(1, 'Read each question and choose who it fits better'),
                                _buildStep(2, '$partnerName answers the same questions separately'),
                                _buildStep(3, 'Compare answers and see how well you match!'),
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

            // Icon layer (fades in after video) - grayscale
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
                        '🤝',
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

  Widget _buildExampleCard(String partnerName) {
    return Container(
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
        boxShadow: [
          BoxShadow(
            color: EditorialStyles.ink.withValues(alpha: 0.08),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHO IS MORE LIKELY TO...',
                  style: EditorialStyles.labelUppercaseSmall.copyWith(
                    color: EditorialStyles.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '"Fall asleep during a movie"',
                  style: EditorialStyles.bodyTextItalic.copyWith(
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: EditorialStyles.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildExampleButton(
                    label: 'You',
                    isSelected: _exampleSelected == 0,
                    onTap: () => setState(() => _exampleSelected = 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildExampleButton(
                    label: partnerName,
                    isSelected: _exampleSelected == 1,
                    onTap: () => setState(() => _exampleSelected = 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? EditorialStyles.ink : EditorialStyles.paper,
          border: EditorialStyles.fullBorder,
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: EditorialStyles.labelUppercase.copyWith(
              color: isSelected ? EditorialStyles.paper : EditorialStyles.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialStepNumber(number: number),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: EditorialStyles.bodySmall,
              ),
            ),
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
            label: 'Start Game',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => YouOrMeGameScreen(session: widget.session),
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
