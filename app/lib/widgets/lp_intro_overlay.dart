import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/unlock_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/notification_service.dart';
import '../services/quest_initialization_service.dart';
import '../services/storage_service.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/animations/animations.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';

/// LP Introduction overlay shown on home screen after completing Welcome Quiz.
///
/// Shows animated LP meter filling from 0 to 30 LP.
/// This is the first time users learn about Love Points.
class LpIntroOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final int lpAwarded;

  const LpIntroOverlay({
    super.key,
    required this.onDismiss,
    this.lpAwarded = 30,
  });

  @override
  State<LpIntroOverlay> createState() => _LpIntroOverlayState();
}

class _LpIntroOverlayState extends State<LpIntroOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _meterController;
  late Animation<double> _meterAnimation;

  bool _showContent = false;
  bool _isProcessing = false;
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  void initState() {
    super.initState();

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // LP meter fill animation
    _meterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _meterAnimation = CurvedAnimation(
      parent: _meterController,
      curve: Curves.easeOutCubic,
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _showContent = true);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _meterController.forward();
            HapticService().trigger(HapticType.success);
            SoundService().play(SoundId.success);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _meterController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    // Prevent double-tap
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    HapticService().trigger(HapticType.light);

    // Mark LP intro as shown on server
    await UnlockService().markLpIntroShown();

    // Request notification permission now that user has seen the value
    // This shows the system permission dialog (gray overlay is expected here)
    await NotificationService.requestPermission();

    // Ensure daily quests are initialized before revealing home screen
    // This prevents the "No Daily Quests Yet" flash when overlay dismisses
    await _ensureQuestsReady();

    // Fade out
    await _fadeController.reverse();

    if (mounted) {
      widget.onDismiss();
    }
  }

  /// Wait for daily quests to be available in local storage
  /// Either from sync or generation - prevents empty state flash
  Future<void> _ensureQuestsReady() async {
    final storage = StorageService();

    // Check if quests already exist (fast path)
    if (storage.getTodayQuests().isNotEmpty) {
      return;
    }

    // Trigger quest initialization (may already be in progress from HomeScreen)
    final initService = QuestInitializationService();
    await initService.ensureQuestsInitialized();

    // Poll for quests to appear in Hive (max 3 seconds)
    // This handles race condition where quests are being saved by another async task
    for (int i = 0; i < 15; i++) {
      if (storage.getTodayQuests().isNotEmpty) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Overlay(context);
    return _buildLiiaOverlay(context);
  }

  Widget _buildLiiaOverlay(BuildContext context) {
    // Wrap with opaque background that's always visible (prevents home screen flash)
    // Only the content fades in, not the background
    return Material(
      color: Colors.white, // Opaque white background - NO animation
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // Sparkle icon
                  if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 0),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: EditorialStyles.fullBorder,
                      ),
                      child: Center(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0, 0, 0, 1, 0,
                          ]),
                          child: const Text(
                            '✨',
                            style: TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                // Title
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'Love Points',
                      style: EditorialStyles.headline.copyWith(
                        fontSize: 32,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Explanation
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'You just earned your first Love Points! Complete activities together to earn more and track your journey.',
                        textAlign: TextAlign.center,
                        style: EditorialStyles.bodyText.copyWith(
                          height: 1.5,
                          color: EditorialStyles.ink.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // Animated LP meter
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 600),
                    child: AnimatedBuilder(
                      animation: _meterAnimation,
                      builder: (context, child) {
                        final progress = _meterAnimation.value;
                        final currentLp = (widget.lpAwarded * progress).round();

                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: EditorialStyles.fullBorder,
                          ),
                          child: Column(
                            children: [
                              // LP count with +30 badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$currentLp',
                                    style: EditorialStyles.headline.copyWith(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'LP',
                                    style: EditorialStyles.headlineSmall.copyWith(
                                      fontSize: 24,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Progress bar
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  border: EditorialStyles.fullBorder,
                                ),
                                child: Stack(
                                  children: [
                                    FractionallySizedBox(
                                      widthFactor: progress * 0.03, // 30 out of ~1000
                                      child: Container(
                                        color: EditorialStyles.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // +30 LP badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: EditorialStyles.ink,
                                ),
                                child: Text(
                                  '+${widget.lpAwarded} LP',
                                  style: EditorialStyles.labelUppercase.copyWith(
                                    color: EditorialStyles.paper,
                                    letterSpacing: 2,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 40),

                // Got It button
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 800),
                    child: EditorialButton(
                      label: 'Got It!',
                      onPressed: _dismiss,
                      isLoading: _isProcessing,
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ), // Column
            ), // ConstrainedBox
          ), // SingleChildScrollView
        ), // SafeArea
      ), // FadeTransition
    ); // Material
  }

  Widget _buildUs2Overlay(BuildContext context) {
    return Material(
      // Fully opaque gradient - prevents main screen flash
      color: const Color(0xFFFF6B6B),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SizedBox.expand(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF6B6B), // Fully opaque gradient start
                  Color(0xFFFF9F43), // Fully opaque gradient end
                ],
              ),
            ),
            child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),

                  // Diamond icon with glow - smaller
                  if (_showContent)
                    BounceInWidget(
                      delay: const Duration(milliseconds: 0),
                      child: _buildUs2DiamondIcon(),
                    ),

                  const SizedBox(height: 20),

                  // Title with text shadow for readability
                  if (_showContent)
                    BounceInWidget(
                      delay: const Duration(milliseconds: 200),
                      child: Text(
                        'Love Points',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Subtitle with better contrast
                  if (_showContent)
                    BounceInWidget(
                      delay: const Duration(milliseconds: 300),
                      child: Text(
                        'Complete quests together to earn points\nand strengthen your connection',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // LP Meter
                  if (_showContent)
                    BounceInWidget(
                      delay: const Duration(milliseconds: 500),
                      child: AnimatedBuilder(
                        animation: _meterAnimation,
                        builder: (context, child) {
                          final progress = _meterAnimation.value;
                          return _buildUs2LpMeter(progress);
                        },
                      ),
                    ),

                  const Spacer(flex: 2),

                  // Continue button
                  if (_showContent)
                    BounceInWidget(
                      delay: const Duration(milliseconds: 700),
                      child: GestureDetector(
                        onTap: _isProcessing ? null : _dismiss,
                        child: AnimatedOpacity(
                          opacity: _isProcessing ? 0.7 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 280),
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isProcessing
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Us2Theme.gradientAccentStart,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      "Let's Go!",
                                      style: GoogleFonts.nunito(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Us2Theme.gradientAccentStart,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildUs2DiamondIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect - smaller
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Diamond emoji with animation - smaller
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 1.08),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: const Text(
                '💎',
                style: TextStyle(fontSize: 64),
              ),
            );
          },
          onEnd: () {
            // Restart animation for pulsing effect
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildUs2LpMeter(double progress) {
    final currentLp = (widget.lpAwarded * progress).round();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Big LP number with +30 badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+$currentLp',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  ' LP',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress track
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress * 0.2, // 30 out of 150 = 20%
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Footer
          Text(
            '${widget.lpAwarded} / 150 to next tier',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2InfoCards() {
    final items = [
      {'icon': '✨', 'text': 'Complete daily quests to earn LP'},
      {'icon': '🎯', 'text': 'Reach milestones to unlock rewards'},
      {'icon': '💕', 'text': 'Build your connection score together'},
    ];

    return Column(
      children: items.map((item) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                item['icon']!,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['text']!,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
