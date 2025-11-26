import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:togetherremind/theme/app_theme.dart';

enum PokeAnimationType {
  send,
  receive,
  mutual,
}

class PokeAnimationService {
  /// Show poke animation overlay
  static Future<void> showPokeAnimation(
    BuildContext context, {
    required PokeAnimationType type,
    String? partnerName,
  }) async {
    // Haptic feedback based on type
    if (type == PokeAnimationType.send) {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.lightImpact();
    } else if (type == PokeAnimationType.receive) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    } else {
      // Mutual - triple pulse
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    }

    if (!context.mounted) return;

    // Show animation overlay
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _PokeAnimationOverlay(
          type: type,
          partnerName: partnerName,
        );
      },
    );
  }
}

class _PokeAnimationOverlay extends StatefulWidget {
  final PokeAnimationType type;
  final String? partnerName;

  const _PokeAnimationOverlay({
    required this.type,
    this.partnerName,
  });

  @override
  State<_PokeAnimationOverlay> createState() => _PokeAnimationOverlayState();
}

class _PokeAnimationOverlayState extends State<_PokeAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getDuration(),
    );

    // Auto-dismiss after animation completes
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration _getDuration() {
    switch (widget.type) {
      case PokeAnimationType.send:
        return const Duration(milliseconds: 800);
      case PokeAnimationType.receive:
        return const Duration(milliseconds: 1200);
      case PokeAnimationType.mutual:
        return const Duration(milliseconds: 1500);
    }
  }

  String _getAnimationPath() {
    switch (widget.type) {
      case PokeAnimationType.send:
        return 'assets/animations/poke_send.json';
      case PokeAnimationType.receive:
        return 'assets/animations/poke_receive.json';
      case PokeAnimationType.mutual:
        return 'assets/animations/poke_mutual.json';
    }
  }

  String _getEmoji() {
    switch (widget.type) {
      case PokeAnimationType.send:
        return '💫';
      case PokeAnimationType.receive:
        return '❤️';
      case PokeAnimationType.mutual:
        return '🎉';
    }
  }

  String _getMessage() {
    switch (widget.type) {
      case PokeAnimationType.send:
        return 'Poke sent!';
      case PokeAnimationType.receive:
        return widget.partnerName != null
            ? '${widget.partnerName} poked you!'
            : 'You\'ve been poked!';
      case PokeAnimationType.mutual:
        return 'You poked each other! 💕';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.backgroundStart, AppTheme.backgroundEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie animation
              SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  _getAnimationPath(),
                  controller: _controller,
                  onLoaded: (composition) {
                    _controller.duration = composition.duration;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Emoji
              Text(
                _getEmoji(),
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                _getMessage(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlack,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
