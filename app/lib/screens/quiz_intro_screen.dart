import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/branch_manifest_service.dart';
import '../models/quiz_session.dart';
import '../models/branch_progression_state.dart';
import '../widgets/editorial/editorial.dart';
import '../config/brand/brand_loader.dart';
import 'quiz_question_screen.dart';
import 'quiz_waiting_screen.dart';

class QuizIntroScreen extends StatefulWidget {
  final QuizSession? session;
  final String? branch; // Branch for manifest video lookup

  const QuizIntroScreen({super.key, this.session, this.branch});

  @override
  State<QuizIntroScreen> createState() => _QuizIntroScreenState();
}

class _QuizIntroScreenState extends State<QuizIntroScreen>
    with TickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();
  bool _isLoading = false;
  String? _error;

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
    _stepsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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
    _checkActiveSession();

    // Start content animation immediately (don't wait for video)
    // Video is a visual enhancement, not a blocker
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContentAnimation();
    });
  }

  Future<void> _initializeVideo() async {
    try {
      // Get video path from manifest if branch is provided
      String? videoPath;
      if (widget.branch != null) {
        videoPath = await BranchManifestService().getVideoPath(
          activityType: BranchableActivityType.classicQuiz,
          branch: widget.branch!,
        );
      }

      // Fallback to default video if no manifest video
      if (videoPath == null || videoPath.isEmpty) {
        final brandId = BrandLoader().config.brandId;
        videoPath = 'assets/brands/$brandId/videos/feel-good-foundations.mp4';
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

  void _checkActiveSession() {
    // If session is passed explicitly (from quest card), show the intro screen
    // Only auto-redirect if user has already answered (go to waiting)
    // Don't auto-redirect to questions - let user see the intro first

    if (widget.session != null) {
      // Session passed from navigation - check if user already answered
      final user = _storage.getUser();
      if (user != null && widget.session!.hasUserAnswered(user.id)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => QuizWaitingScreen(session: widget.session!),
            ),
          );
        });
      }
      // Otherwise, show the intro screen (don't redirect)
      return;
    }

    // No session passed - check for active session (legacy path from activities)
    final activeSession = _quizService.getActiveSession();
    if (activeSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final user = _storage.getUser();
        if (user != null && activeSession.hasUserAnswered(user.id)) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => QuizWaitingScreen(session: activeSession),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => QuizQuestionScreen(session: activeSession),
            ),
          );
        }
      });
    }
  }

  Future<void> _startQuiz() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = widget.session ?? await _quizService.startQuizSession();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuizQuestionScreen(session: session),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedSessions = _quizService.getCompletedSessions();
    final partnerName = _storage.getPartner()?.name ?? 'your partner';

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Header (fixed at top)
            _buildHeader(),

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
                              label: 'Classic Quiz',
                              isInverted: true,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title (animated)
                          _animatedContent(
                            _titleAnimation,
                            Text(
                              widget.session?.category ?? 'Couple Quiz',
                              style: EditorialStyles.headline,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description (animated)
                          _animatedContent(
                            _descAnimation,
                            Text(
                              'Answer questions about yourself, then $partnerName will try to predict your answers. See how well you know each other!',
                              style: EditorialStyles.bodyTextItalic,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Stats card (animated)
                          _animatedContent(
                            _statsAnimation,
                            EditorialStatsCard(
                              rows: [
                                ('Questions', '${widget.session?.questionIds.length ?? 5}'),
                                ('Time', '~3 minutes'),
                                ('Reward', '+30 LP'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // How it works (animated)
                          _animatedContent(
                            _stepsAnimation,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HOW IT WORKS',
                                  style: EditorialStyles.labelUppercase,
                                ),
                                const SizedBox(height: 16),
                                _buildStep(1, 'Answer each question about yourself'),
                                _buildStep(2, '$partnerName answers the same questions about you'),
                                _buildStep(3, 'Compare answers and discover insights'),
                              ],
                            ),
                          ),

                          // Previous stats (if any)
                          if (completedSessions.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildPreviousStats(completedSessions),
                          ],

                          // Error message
                          if (_error != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: BrandLoader().colors.error.withValues(alpha: 0.1),
                                border: Border.all(color: BrandLoader().colors.error),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(color: BrandLoader().colors.error),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
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
                        '🧩',
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

  Widget _buildPreviousStats(List<QuizSession> completedSessions) {
    final avgMatch = _quizService.getAverageMatchPercentage();

    return EditorialCard(
      hasShadow: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'YOUR STATS',
            style: EditorialStyles.labelUppercase,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('${completedSessions.length}', 'Completed'),
              Container(
                width: 1,
                height: 40,
                color: EditorialStyles.inkLight,
              ),
              _buildStatColumn('${avgMatch.round()}%', 'Avg Match'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: EditorialStyles.scoreMedium),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: EditorialStyles.labelUppercaseSmall,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: Border(top: EditorialStyles.border),
      ),
      child: Column(
        children: [
          EditorialPrimaryButton(
            label: _isLoading ? 'Starting...' : 'Begin Quiz',
            onPressed: _isLoading ? null : _startQuiz,
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
