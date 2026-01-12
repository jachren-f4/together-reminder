import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/animation_constants.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/models/magnet_collection.dart';
import 'package:togetherremind/services/haptic_service.dart';

/// Connection bar showing magnet collection progress
///
/// Features:
/// - Gradient background (pink to orange)
/// - Progress bar with heart indicator
/// - Animated sparkles around heart
/// - Current magnet and next magnet at endpoints
/// - Animated LP counter and progress bar on LP gain
class Us2ConnectionBar extends StatefulWidget {
  final MagnetCollection? collection;
  final VoidCallback? onTap;

  const Us2ConnectionBar({
    super.key,
    this.collection,
    this.onTap,
  });

  // Width reserved for magnet endpoint icons
  static const double _magnetEndpointWidth = 36.0;

  /// Format number with comma separators (e.g., 2460 -> "2,460")
  static String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    final String str = number.toString();
    final int len = str.length;
    if (len <= 3) return str;
    return '${str.substring(0, len - 3)},${str.substring(len - 3)}';
  }

  /// Get cumulative LP required to unlock a specific magnet
  /// Magnet 1: 600, Magnet 2: 1200, Magnet 3: 1800, Magnet 4: 2500, etc.
  /// Public so MagnetCollectionScreen can use it too.
  static int getCumulativeLpForMagnet(int magnetNumber) {
    int cumulative = 0;
    for (int i = 1; i <= magnetNumber; i++) {
      final tier = (i - 1) ~/ 3;
      cumulative += 600 + (tier * 100);
    }
    return cumulative;
  }

  /// Get emoji for magnet based on destination (fallback when no image)
  static String getMagnetEmoji(int magnetId) {
    const emojis = [
      // US Cities (1-7)
      '🎸', // 1: Austin
      '🎬', // 2: Los Angeles
      '🌉', // 3: San Francisco
      '🏙️', // 4: Chicago
      '🌴', // 5: Miami
      '🎷', // 6: New Orleans
      '🗽', // 7: New York
      // Northern Europe (8-14)
      '🎡', // 8: London
      '🗼', // 9: Paris
      '🚲', // 10: Amsterdam
      '🐻', // 11: Berlin
      '🧜', // 12: Copenhagen
      '👑', // 13: Stockholm
      '⛷️', // 14: Oslo
      // Southern Europe (15-21)
      '🏛️', // 15: Barcelona
      '🍕', // 16: Naples
      '🏟️', // 17: Rome
      '🎼', // 18: Vienna
      '🏰', // 19: Prague
      '🚃', // 20: Lisbon
      '🏛️', // 21: Athens
      // Nordic & Mediterranean Dreams (22-25)
      '🦌', // 22: Helsinki
      '🌋', // 23: Reykjavik
      '🔵', // 24: Santorini
      '🏰', // 25: Dubrovnik
      // Exotic World (26-30)
      '🗼', // 26: Tokyo
      '🕌', // 27: Marrakech
      '🦁', // 28: Cape Town
      '💃', // 29: Buenos Aires
      '🚗', // 30: Havana
    ];
    if (magnetId < 1 || magnetId > emojis.length) return '🧲';
    return emojis[magnetId - 1];
  }

  @override
  State<Us2ConnectionBar> createState() => Us2ConnectionBarState();
}

class Us2ConnectionBarState extends State<Us2ConnectionBar>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _counterController;
  late AnimationController _celebrationPulseController;

  // Animation values
  late Animation<double> _progressAnimation;
  late Animation<int> _counterAnimation;
  late Animation<double> _celebrationPulseAnimation;

  // Track values for animation
  int _displayedLp = 0;
  double _displayedProgress = 0.0;
  int _previousLp = 0;
  double _previousProgress = 0.0;
  bool _isAnimating = false;

  // Particle celebration animation - rendered inside this widget so they scroll with the bar
  List<_ParticleState>? _particles;
  List<AnimationController>? _particleControllers;

  @override
  void initState() {
    super.initState();

    // Initialize with current values
    _displayedLp = widget.collection?.currentLp ?? 0;
    _previousLp = _displayedLp;
    _displayedProgress = _calculateProgress();
    _previousProgress = _displayedProgress;

    // Progress bar animation controller
    _progressController = AnimationController(
      duration: AnimationConstants.lpCountUp,
      vsync: this,
    );

    // Counter animation controller
    _counterController = AnimationController(
      duration: AnimationConstants.lpCountUp,
      vsync: this,
    );

    // Celebration pulse controller (quick pulse when animation completes)
    _celebrationPulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _celebrationPulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _celebrationPulseController,
        curve: Curves.easeOutBack,
      ),
    );

    // Initialize animations with current values
    _progressAnimation = Tween<double>(
      begin: _displayedProgress,
      end: _displayedProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    _counterAnimation = IntTween(
      begin: _displayedLp,
      end: _displayedLp,
    ).animate(CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _progressController.dispose();
    _counterController.dispose();
    _celebrationPulseController.dispose();
    _disposeParticles();
    super.dispose();
  }

  void _disposeParticles() {
    if (_particleControllers != null) {
      for (final controller in _particleControllers!) {
        controller.dispose();
      }
      _particleControllers = null;
      _particles = null;
    }
  }

  /// Trigger particle celebration animation.
  /// Particles fly from bottom of bar up to the LP counter.
  /// Call this BEFORE animateLPGain for best visual effect.
  void triggerParticleCelebration() {
    _disposeParticles();

    final random = Random();
    const particleCount = 25;

    // Create particles with randomized properties
    _particles = List.generate(particleCount, (index) {
      // Start: spread across bottom of the bar
      final startX = 50.0 + random.nextDouble() * 250.0;
      final startY = 120.0 + random.nextDouble() * 40.0; // Below the bar

      // End: converge on LP counter (top right area)
      final endX = 280.0 + (random.nextDouble() - 0.5) * 40.0;
      final endY = 10.0 + (random.nextDouble() - 0.5) * 20.0;

      return _ParticleState(
        startX: startX,
        startY: startY,
        endX: endX,
        endY: endY,
        size: 10.0 + random.nextDouble() * 8.0,
        arcHeight: 20.0 + random.nextDouble() * 40.0,
      );
    });

    // Create animation controllers
    _particleControllers = List.generate(particleCount, (index) {
      return AnimationController(
        duration: AnimationConstants.lpParticleFlight,
        vsync: this,
      );
    });

    // Start staggered animations
    _startParticleAnimations();

    setState(() {});
  }

  void _startParticleAnimations() async {
    if (_particleControllers == null) return;

    for (var i = 0; i < _particleControllers!.length; i++) {
      if (i > 0) {
        await Future.delayed(AnimationConstants.lpParticleStagger);
      }
      if (mounted && _particleControllers != null) {
        _particleControllers![i].forward();
      }
    }

    // Clean up after animation completes
    await Future.delayed(AnimationConstants.lpParticleFlight);
    if (mounted) {
      setState(() {
        _disposeParticles();
      });
    }
  }

  @override
  void didUpdateWidget(Us2ConnectionBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update values without animation when collection changes externally
    // (animation is triggered explicitly via animateLPGain)
    if (!_isAnimating) {
      final newLp = widget.collection?.currentLp ?? 0;
      final newProgress = _calculateProgress();

      if (newLp != _displayedLp || newProgress != _displayedProgress) {
        setState(() {
          _displayedLp = newLp;
          _previousLp = newLp;
          _displayedProgress = newProgress;
          _previousProgress = newProgress;
        });
      }
    }
  }

  /// Trigger animated LP gain from previousLP to current collection LP.
  /// Call this after particles arrive at the meter.
  void animateLPGain(int previousLP) {
    final newLp = widget.collection?.currentLp ?? 0;
    final newProgress = _calculateProgress();

    if (newLp <= previousLP) return; // No gain to animate

    setState(() {
      _isAnimating = true;
      _previousLp = previousLP;
      _previousProgress = _calculateProgressForLP(previousLP);
    });

    // Setup progress animation
    _progressAnimation = Tween<double>(
      begin: _previousProgress,
      end: newProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    // Setup counter animation
    _counterAnimation = IntTween(
      begin: previousLP,
      end: newLp,
    ).animate(CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    ));

    // Reset and start animations
    _progressController.reset();
    _counterController.reset();
    _progressController.forward();
    _counterController.forward();

    // Listen for completion
    _counterController.addStatusListener(_onAnimationComplete);
  }

  void _onAnimationComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _counterController.removeStatusListener(_onAnimationComplete);

      // Celebration pulse and haptic
      _celebrationPulseController.forward(from: 0.0).then((_) {
        _celebrationPulseController.reverse();
      });
      HapticService().trigger(HapticType.success);

      setState(() {
        _isAnimating = false;
        _displayedLp = widget.collection?.currentLp ?? 0;
        _displayedProgress = _calculateProgress();
        _previousLp = _displayedLp;
        _previousProgress = _displayedProgress;
      });
    }
  }

  double _calculateProgress() {
    return _calculateProgressForLP(widget.collection?.currentLp ?? 0);
  }

  double _calculateProgressForLP(int lp) {
    final unlockedCount = widget.collection?.unlockedCount ?? 0;
    final nextMagnetId = widget.collection?.nextMagnetId ?? 1;
    final allUnlocked = widget.collection?.allUnlocked ?? false;

    if (allUnlocked) return 1.0;

    final prevThreshold = unlockedCount > 0
        ? Us2ConnectionBar.getCumulativeLpForMagnet(unlockedCount)
        : 0;
    final nextThreshold = Us2ConnectionBar.getCumulativeLpForMagnet(nextMagnetId);
    final lpInCurrentTier = lp - prevThreshold;
    final lpNeededForTier = nextThreshold - prevThreshold;

    return lpNeededForTier > 0
        ? (lpInCurrentTier / lpNeededForTier).clamp(0.0, 1.0)
        : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = widget.collection?.unlockedCount ?? 0;
    final nextMagnetId = widget.collection?.nextMagnetId ?? 1;
    final allUnlocked = widget.collection?.allUnlocked ?? false;
    final currentMagnetId = unlockedCount > 0 ? unlockedCount : 0;
    final effectiveNextMagnetId = nextMagnetId;

    // Wrap in Stack to overlay particles
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main bar content
        GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              gradient: Us2Theme.connectionBarGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Us2Theme.connectionBarBorderRadius),
                topRight: Radius.circular(Us2Theme.connectionBarBorderRadius),
              ),
            ),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OUR JOURNEY',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
                // Total LP with animation
                AnimatedBuilder(
                  animation: Listenable.merge([_counterAnimation, _celebrationPulseAnimation]),
                  builder: (context, child) {
                    final displayValue = _isAnimating
                        ? _counterAnimation.value
                        : _displayedLp;

                    return Transform.scale(
                      scale: _celebrationPulseAnimation.value,
                      child: Text(
                        allUnlocked
                            ? 'Complete!'
                            : '${Us2ConnectionBar._formatNumber(displayValue)} LP',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar with magnet endpoints
            SizedBox(
              height: 50,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final hasLeftMagnet = currentMagnetId > 0;

                  final trackLeft = hasLeftMagnet
                      ? Us2ConnectionBar._magnetEndpointWidth + 16
                      : 16.0;
                  final trackRight = Us2ConnectionBar._magnetEndpointWidth + 16;
                  final trackWidth = totalWidth - trackLeft - trackRight;

                  return AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      final progress = _isAnimating
                          ? _progressAnimation.value
                          : _displayedProgress;
                      final heartPosition = trackLeft + (trackWidth * progress);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Left endpoint (current/last magnet)
                          if (hasLeftMagnet)
                            Positioned(
                              left: 0,
                              top: 0,
                              child: _MagnetEndpoint(magnetId: currentMagnetId),
                            ),
                          // Right endpoint (next magnet)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: _MagnetEndpoint(magnetId: effectiveNextMagnetId),
                          ),
                          // Track background
                          Positioned(
                            left: trackLeft,
                            right: trackRight,
                            top: 13,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          // Progress fill - animated width
                          Positioned(
                            left: trackLeft,
                            top: 13,
                            child: Container(
                              height: 10,
                              width: trackWidth * progress,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFE066),
                                    Color(0xFFFFB347),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFE066).withValues(alpha: 0.6),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Heart indicator - animated position
                          Positioned(
                            left: heartPosition - 22,
                            top: -4,
                            child: _Us2ProgressHeart(
                              celebrationAnimation: _celebrationPulseAnimation,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
          ),
        ),
        // Particle overlay - rendered above the bar content
        if (_particles != null && _particleControllers != null)
          ..._buildParticles(),
      ],
    );
  }

  /// Build particle widgets for the celebration animation
  List<Widget> _buildParticles() {
    if (_particles == null || _particleControllers == null) return [];

    return List.generate(_particles!.length, (index) {
      final particle = _particles![index];
      final controller = _particleControllers![index];

      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          if (controller.value == 0) return const SizedBox.shrink();

          final progress = Curves.easeInQuad.transform(controller.value);

          // Calculate position along curved arc path
          final x = particle.startX + (particle.endX - particle.startX) * progress;
          final linearY = particle.startY + (particle.endY - particle.startY) * progress;
          final arcOffset = -particle.arcHeight * 4 * progress * (1 - progress);
          final y = linearY + arcOffset;

          // Scale: start at 1.0, shrink slightly as approaching destination
          final scale = 1.0 - (progress * 0.2);

          // Fade out quickly in last 15% of journey
          final opacity = progress < 0.85 ? 1.0 : (1.0 - (progress - 0.85) / 0.15);

          return Positioned(
            left: x - (particle.size * scale / 2),
            top: y - (particle.size * scale / 2),
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: _buildSparkle(particle.size),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildSparkle(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Glow behind the star
          Center(
            child: Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700),
                    blurRadius: size * 1.5,
                    spreadRadius: size * 0.3,
                  ),
                ],
              ),
            ),
          ),
          // Star icon
          Center(
            child: Icon(
              Icons.star,
              size: size,
              color: const Color(0xFFFFD700),
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Particle state for celebration animation
class _ParticleState {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double size;
  final double arcHeight;

  _ParticleState({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.arcHeight,
  });
}

/// Magnet endpoint - square rounded image (no label per mockup spec)
class _MagnetEndpoint extends StatelessWidget {
  final int magnetId;

  const _MagnetEndpoint({
    required this.magnetId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _buildMagnetImage(magnetId),
      ),
    );
  }

  Widget _buildMagnetImage(int magnetId) {
    final assetPath = MagnetCollection.getMagnetAssetPath(magnetId);

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFFF6B6B),
          child: Center(
            child: Text(
              Us2ConnectionBar.getMagnetEmoji(magnetId),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        );
      },
    );
  }
}

/// Animated heart with sparkles
class _Us2ProgressHeart extends StatefulWidget {
  final Animation<double>? celebrationAnimation;

  const _Us2ProgressHeart({
    this.celebrationAnimation,
  });

  @override
  State<_Us2ProgressHeart> createState() => _Us2ProgressHeartState();
}

class _Us2ProgressHeartState extends State<_Us2ProgressHeart>
    with TickerProviderStateMixin {
  late List<AnimationController> _sparkleControllers;
  late List<Animation<double>> _sparkleAnimations;

  @override
  void initState() {
    super.initState();

    // Create 3 staggered sparkle animations
    _sparkleControllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: Us2Theme.sparkleAnimationDuration),
        vsync: this,
      )..repeat();
    });

    _sparkleAnimations = _sparkleControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;
      // Stagger the animations
      Future.delayed(Duration(milliseconds: index * 500), () {
        if (mounted) controller.forward();
      });
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _sparkleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget heart = SizedBox(
      width: Us2Theme.progressHeartSize,
      height: Us2Theme.progressHeartSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Heart circle
          Container(
            width: Us2Theme.progressHeartSize,
            height: Us2Theme.progressHeartSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Us2Theme.gradientAccentStart,
                  Us2Theme.gradientAccentEnd,
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Us2Theme.glowPink.withValues(alpha: 0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('💗', style: TextStyle(fontSize: 20)),
            ),
          ),
          // Sparkles
          _buildSparkle(0, -8, -8),
          _buildSparkle(1, 30, -5),
          _buildSparkle(2, 35, 25),
        ],
      ),
    );

    // Wrap with celebration animation if provided
    if (widget.celebrationAnimation != null) {
      return AnimatedBuilder(
        animation: widget.celebrationAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.celebrationAnimation!.value,
            child: heart,
          );
        },
      );
    }

    return heart;
  }

  Widget _buildSparkle(int index, double left, double top) {
    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _sparkleAnimations[index],
        builder: (context, child) {
          return Opacity(
            opacity: _sparkleAnimations[index].value,
            child: Transform.scale(
              scale: 0.8 + (_sparkleAnimations[index].value * 0.4),
              child: const Text('✨', style: TextStyle(fontSize: 14)),
            ),
          );
        },
      ),
    );
  }
}
