import 'package:flutter/material.dart';
import '../services/unlock_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/animations/animations.dart';

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
    HapticService().trigger(HapticType.light);

    // Mark LP intro as shown on server
    await UnlockService().markLpIntroShown();

    // Fade out
    await _fadeController.reverse();

    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

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

                const Spacer(flex: 3),

                // Got It button
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 800),
                    child: EditorialButton(
                      label: 'Got It!',
                      onPressed: _dismiss,
                    ),
                  ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
