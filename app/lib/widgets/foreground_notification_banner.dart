import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:togetherremind/theme/app_theme.dart';

class ForegroundNotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final String emoji;
  final VoidCallback? onTap;
  final Duration displayDuration;

  const ForegroundNotificationBanner({
    super.key,
    required this.title,
    required this.message,
    required this.emoji,
    this.onTap,
    this.displayDuration = const Duration(seconds: 4),
  });

  @override
  State<ForegroundNotificationBanner> createState() =>
      _ForegroundNotificationBannerState();

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required String emoji,
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => ForegroundNotificationBanner(
        title: title,
        message: message,
        emoji: emoji,
        onTap: onTap,
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove after duration
    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry.remove();
    });

    // Trigger haptic feedback
    HapticFeedback.mediumImpact();
  }
}

class _ForegroundNotificationBannerState
    extends State<ForegroundNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto-dismiss with animation
    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          // Will be removed by parent
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    _controller.reverse();
                    widget.onTap?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Emoji
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.borderLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              widget.emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: AppTheme.bodyFont.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                style: AppTheme.bodyFont.copyWith(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
