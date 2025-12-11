import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';
import 'particle_burst_widget.dart';
import 'flash_overlay_widget.dart';
import 'expanding_rings_widget.dart';
import 'confetti_widget.dart';

/// Mixin that provides dramatic screen entrance effects.
/// Use this on screen states to get automatic entry animations and
/// access to particle burst, flash, and ring controllers.
mixin DramaticScreenMixin<T extends StatefulWidget> on State<T> {
  // Controllers for animation effects
  late ParticleBurstController particleController;
  late FlashController flashController;
  late ExpandingRingsController ringsController;
  late ConfettiController confettiController;

  // Track if entry animation has played
  bool _hasPlayedEntryAnimation = false;
  bool get hasPlayedEntryAnimation => _hasPlayedEntryAnimation;

  // Override these to customize behavior
  bool get enableEntryAnimation => true;
  bool get enableParticles => true;
  bool get enableFlash => true;
  bool get enableRings => true;
  bool get enableConfetti => false; // Off by default

  // Timing for entry sequence
  Duration get entryFlashDelay => const Duration(milliseconds: 100);
  Duration get entryRingsDelay => const Duration(milliseconds: 100);
  Duration get entryParticlesDelay => const Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    particleController = ParticleBurstController();
    flashController = FlashController();
    ringsController = ExpandingRingsController();
    confettiController = ConfettiController();

    if (enableEntryAnimation) {
      _playEntryAnimation();
    }
  }

  @override
  void dispose() {
    particleController.dispose();
    flashController.dispose();
    ringsController.dispose();
    confettiController.dispose();
    super.dispose();
  }

  /// Play the dramatic entry animation sequence
  void _playEntryAnimation() {
    if (_hasPlayedEntryAnimation) return;
    _hasPlayedEntryAnimation = true;

    // Flash
    if (enableFlash) {
      Future.delayed(entryFlashDelay, () {
        if (mounted) flashController.flash();
      });
    }

    // Rings
    if (enableRings) {
      Future.delayed(entryRingsDelay, () {
        if (mounted) ringsController.expand();
      });
    }
  }

  /// Trigger a particle burst at a tap location
  void triggerParticles(TapDownDetails details) {
    if (!enableParticles) return;
    particleController.burst(details.localPosition);
  }

  /// Trigger a particle burst at a specific offset
  void triggerParticlesAt(Offset position) {
    if (!enableParticles) return;
    particleController.burst(position);
  }

  /// Trigger flash effect
  void triggerFlash() {
    if (!enableFlash) return;
    flashController.flash();
  }

  /// Trigger expanding rings from center
  void triggerRings() {
    if (!enableRings) return;
    ringsController.expand();
  }

  /// Trigger expanding rings from a specific point
  void triggerRingsFrom(Offset center) {
    if (!enableRings) return;
    ringsController.expandFrom(center);
  }

  /// Trigger confetti
  void triggerConfetti() {
    if (!enableConfetti) return;
    confettiController.trigger();
  }

  /// Trigger all dramatic effects at once (for major celebrations)
  void triggerAllEffects([Offset? particleOrigin]) {
    triggerFlash();
    triggerRings();
    if (particleOrigin != null) {
      triggerParticlesAt(particleOrigin);
    }
    if (enableConfetti) {
      triggerConfetti();
    }
  }

  /// Wrap content with dramatic effect overlays.
  /// Call this in your build method around your main content.
  Widget wrapWithDramaticEffects(Widget child) {
    Widget result = child;

    // Particle overlay
    if (enableParticles) {
      result = ParticleBurstOverlay(
        controller: particleController,
        child: result,
      );
    }

    // Flash overlay
    if (enableFlash) {
      result = FlashOverlay(
        controller: flashController,
        child: result,
      );
    }

    // Rings overlay
    if (enableRings) {
      result = ExpandingRingsOverlay(
        controller: ringsController,
        child: result,
      );
    }

    // Confetti overlay
    if (enableConfetti) {
      result = ConfettiOverlay(
        controller: confettiController,
        child: result,
      );
    }

    return result;
  }
}

/// A complete dramatic screen wrapper that includes all effects.
/// Use this to wrap your entire screen scaffold.
class DramaticScreenWrapper extends StatefulWidget {
  final Widget child;
  final bool enableFlash;
  final bool enableRings;
  final bool enableParticles;
  final bool enableConfetti;
  final bool playEntryAnimation;
  final Duration entryDelay;
  final ParticleBurstController? particleController;
  final FlashController? flashController;
  final ExpandingRingsController? ringsController;
  final ConfettiController? confettiController;

  const DramaticScreenWrapper({
    super.key,
    required this.child,
    this.enableFlash = true,
    this.enableRings = true,
    this.enableParticles = true,
    this.enableConfetti = false,
    this.playEntryAnimation = true,
    this.entryDelay = const Duration(milliseconds: 100),
    this.particleController,
    this.flashController,
    this.ringsController,
    this.confettiController,
  });

  @override
  State<DramaticScreenWrapper> createState() => _DramaticScreenWrapperState();
}

class _DramaticScreenWrapperState extends State<DramaticScreenWrapper> {
  late ParticleBurstController _particleController;
  late FlashController _flashController;
  late ExpandingRingsController _ringsController;
  late ConfettiController _confettiController;
  bool _hasPlayedEntry = false;

  @override
  void initState() {
    super.initState();
    _particleController =
        widget.particleController ?? ParticleBurstController();
    _flashController = widget.flashController ?? FlashController();
    _ringsController = widget.ringsController ?? ExpandingRingsController();
    _confettiController = widget.confettiController ?? ConfettiController();

    if (widget.playEntryAnimation) {
      _playEntry();
    }
  }

  void _playEntry() {
    if (_hasPlayedEntry) return;
    _hasPlayedEntry = true;

    Future.delayed(widget.entryDelay, () {
      if (!mounted) return;
      if (widget.enableFlash) _flashController.flash();
      if (widget.enableRings) _ringsController.expand();
    });
  }

  @override
  void dispose() {
    if (widget.particleController == null) _particleController.dispose();
    if (widget.flashController == null) _flashController.dispose();
    if (widget.ringsController == null) _ringsController.dispose();
    if (widget.confettiController == null) _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    Widget result = widget.child;

    if (widget.enableParticles) {
      result = ParticleBurstOverlay(
        controller: _particleController,
        child: result,
      );
    }

    if (widget.enableFlash) {
      result = FlashOverlay(
        controller: _flashController,
        child: result,
      );
    }

    if (widget.enableRings) {
      result = ExpandingRingsOverlay(
        controller: _ringsController,
        child: result,
      );
    }

    if (widget.enableConfetti) {
      result = ConfettiOverlay(
        controller: _confettiController,
        child: result,
      );
    }

    return result;
  }
}
