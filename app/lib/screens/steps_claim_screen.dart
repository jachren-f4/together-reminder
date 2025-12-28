import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/steps_feature_service.dart';
import '../services/love_point_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../models/steps_data.dart';

/// Celebration screen for claiming yesterday's step reward.
///
/// Features:
/// - Full-screen confetti animation
/// - Hero section with reward amount
/// - Partner breakdown display
/// - Claim button
class StepsClaimScreen extends StatefulWidget {
  final StepsDay stepsDay;

  const StepsClaimScreen({
    super.key,
    required this.stepsDay,
  });

  @override
  State<StepsClaimScreen> createState() => _StepsClaimScreenState();
}

class _StepsClaimScreenState extends State<StepsClaimScreen>
    with TickerProviderStateMixin {
  final StepsFeatureService _stepsService = StepsFeatureService();
  final StorageService _storage = StorageService();

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  late AnimationController _confettiController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  bool _isClaiming = false;
  bool _hasClaimed = false;

  @override
  void initState() {
    super.initState();

    // Confetti animation (loops)
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Scale animation for reward amount
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    // Start scale animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final earnedLP = widget.stepsDay.earnedLP;
    final tierName = _getTierName(widget.stepsDay.combinedSteps);

    return Scaffold(
      backgroundColor: _isUs2 ? Us2Theme.bgGradientEnd : BrandLoader().colors.surface,
      body: Container(
        decoration: _isUs2
            ? const BoxDecoration(gradient: Us2Theme.backgroundGradient)
            : null,
        child: Stack(
          children: [
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // App bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isUs2 ? 8 : 8,
                      vertical: _isUs2 ? 60 : 8,
                    ),
                    child: Row(
                      children: [
                        _isUs2
                            ? GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back, color: Us2Theme.textDark, size: 24),
                                ),
                              )
                            : IconButton(
                                icon: Icon(Icons.arrow_back,
                                    color: BrandLoader().colors.textPrimary),
                                onPressed: () => Navigator.pop(context),
                              ),
                        Expanded(
                          child: Text(
                            'Claim Reward',
                            style: _isUs2
                                ? const TextStyle(
                                    fontFamily: Us2Theme.fontHeading,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Us2Theme.textDark,
                                  )
                                : AppTheme.headlineFont.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: BrandLoader().colors.textPrimary,
                                  ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                  ),

                  // Hero section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    decoration: BoxDecoration(
                      color: _isUs2 ? null : BrandLoader().colors.textPrimary,
                      gradient: _isUs2 ? Us2Theme.accentGradient : null,
                    ),
                    child: Column(
                      children: [
                        // Animated reward amount
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Text(
                                '+$earnedLP',
                                style: _isUs2
                                    ? const TextStyle(
                                        fontFamily: Us2Theme.fontHeading,
                                        fontSize: 72,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      )
                                    : AppTheme.headlineFont.copyWith(
                                        fontSize: 72,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                              ),
                            );
                          },
                        ),
                        Text(
                          'Love Points',
                          style: _isUs2
                              ? TextStyle(
                                  fontFamily: Us2Theme.fontHeading,
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.8),
                                )
                              : AppTheme.headlineFont.copyWith(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                        ),
                        const SizedBox(height: 16),
                        // Tier badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$tierName Tier Reached',
                            style: TextStyle(
                              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Content section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Date header
                        _buildDateHeader(),
                        const SizedBox(height: 24),

                        // Partner breakdown
                        _buildPartnerBreakdown(user, partner),
                        const SizedBox(height: 24),

                        // Combined total
                        _buildCombinedTotal(),
                        const SizedBox(height: 32),

                        // Claim button
                        _buildClaimButton(earnedLP),
                        const SizedBox(height: 16),

                        // Meta info
                        _buildMetaInfo(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Confetti overlay (on top of everything)
          if (!_hasClaimed)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ConfettiPainter(
                        progress: _confettiController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    // Parse date from dateKey (YYYY-MM-DD)
    final parts = widget.stepsDay.dateKey.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yesterday',
          style: _isUs2
              ? const TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                )
              : AppTheme.headlineFont.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: BrandLoader().colors.textPrimary,
                ),
        ),
        Text(
          '${months[date.month - 1]} ${date.day}, ${date.year}',
          style: TextStyle(
            fontFamily: _isUs2 ? Us2Theme.fontBody : null,
            fontSize: 14,
            color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerBreakdown(dynamic user, dynamic partner) {
    return Row(
      children: [
        Expanded(
          child: _buildPartnerCard(
            name: 'You',
            initial: user?.name[0].toUpperCase() ?? 'Y',
            steps: widget.stepsDay.userSteps,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPartnerCard(
            name: partner?.name ?? 'Partner',
            initial: partner?.name[0].toUpperCase() ?? 'P',
            steps: widget.stepsDay.partnerSteps,
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerCard({
    required String name,
    required String initial,
    required int steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isUs2 ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isUs2
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _isUs2 ? null : BrandLoader().colors.textPrimary,
              gradient: _isUs2 ? Us2Theme.accentGradient : null,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: _isUs2 ? Us2Theme.fontHeading : null,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatNumber(steps),
            style: _isUs2
                ? const TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.textDark,
                  )
                : AppTheme.headlineFont.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: BrandLoader().colors.textPrimary,
                  ),
          ),
          Text(
            name,
            style: TextStyle(
              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
              fontSize: 14,
              color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedTotal() {
    final combinedSteps = widget.stepsDay.combinedSteps;
    final percentage = ((combinedSteps / 20000) * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _isUs2 ? Us2Theme.beige : BrandLoader().colors.borderLight, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Combined Steps',
            style: TextStyle(
              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
              fontSize: 12,
              color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatNumber(combinedSteps),
            style: _isUs2
                ? const TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.textDark,
                  )
                : AppTheme.headlineFont.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: BrandLoader().colors.textPrimary,
                  ),
          ),
          Text(
            'of 20,000 goal ($percentage%)',
            style: TextStyle(
              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
              fontSize: 14,
              color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton(int earnedLP) {
    if (_hasClaimed) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _isUs2 ? const Color(0xFF4CAF50) : BrandLoader().colors.success,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Claimed!',
              style: _isUs2
                  ? const TextStyle(
                      fontFamily: Us2Theme.fontBody,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )
                  : AppTheme.headlineFont.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      );
    }

    if (_isUs2) {
      return GestureDetector(
        onTap: _isClaiming ? null : _claimReward,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: _isClaiming ? null : Us2Theme.accentGradient,
            color: _isClaiming ? Colors.grey.shade300 : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isClaiming
                ? null
                : [
                    BoxShadow(
                      color: Us2Theme.glowPink,
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: _isClaiming
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Claim Reward',
                    style: TextStyle(
                      fontFamily: Us2Theme.fontBody,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isClaiming ? null : _claimReward,
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandLoader().colors.textPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isClaiming
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Claim Reward',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildMetaInfo() {
    final expiresAt = widget.stepsDay.claimExpiresAt;
    String expiryText = '';

    if (expiresAt != null) {
      final diff = expiresAt.difference(DateTime.now());
      if (diff.inHours > 0) {
        expiryText = 'Expires in ${diff.inHours} hours';
      } else if (diff.inMinutes > 0) {
        expiryText = 'Expires in ${diff.inMinutes} minutes';
      } else {
        expiryText = 'Expiring soon';
      }
    }

    final textColor = _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (expiryText.isNotEmpty) ...[
          Text(
            expiryText,
            style: TextStyle(
              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
              fontSize: 12,
              color: textColor,
            ),
          ),
          Text(
            ' | ',
            style: TextStyle(
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
        Text(
          'Both synced',
          style: TextStyle(
            fontFamily: _isUs2 ? Us2Theme.fontBody : null,
            fontSize: 12,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Future<void> _claimReward() async {
    setState(() => _isClaiming = true);
    HapticService().tap();

    try {
      // Claim the reward (LP is awarded server-side by /api/sync/steps)
      await _stepsService.claimReward();

      // Sync LP from server after claim
      await LovePointService.fetchAndSyncFromServer();

      // Success feedback
      HapticService().trigger(HapticType.success);
      SoundService().play(SoundId.confettiBurst);

      setState(() {
        _isClaiming = false;
        _hasClaimed = true;
      });

      // Stop confetti after claim
      _confettiController.stop();

      // Navigate back after short delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isClaiming = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim reward: $e'),
            backgroundColor: BrandLoader().colors.error,
          ),
        );
      }
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return number.toString();
  }

  String _getTierName(int combinedSteps) {
    if (combinedSteps >= 20000) return '20K';
    if (combinedSteps >= 18000) return '18K';
    if (combinedSteps >= 16000) return '16K';
    if (combinedSteps >= 14000) return '14K';
    if (combinedSteps >= 12000) return '12K';
    if (combinedSteps >= 10000) return '10K';
    return 'Below 10K';
  }
}

/// Custom painter for confetti animation
class ConfettiPainter extends CustomPainter {
  final double progress;
  final int particleCount;
  final List<_ConfettiParticle> _particles;

  ConfettiPainter({
    required this.progress,
    this.particleCount = 30,
  }) : _particles = List.generate(
          particleCount,
          (i) => _ConfettiParticle(
            seed: i,
            totalParticles: particleCount,
          ),
        );

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in _particles) {
      particle.draw(canvas, size, progress);
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ConfettiParticle {
  final int seed;
  final double startX;
  final double startDelay;
  final double speed;
  final double size;
  final Color color;
  final double rotation;

  _ConfettiParticle({
    required this.seed,
    required int totalParticles,
  })  : startX = (seed / totalParticles) + (seed * 0.1 % 0.3),
        startDelay = (seed * 0.07) % 0.5,
        speed = 0.3 + (seed * 0.03 % 0.4),
        size = [8.0, 12.0, 16.0][seed % 3],
        color = [
          const Color(0xFF000000),
          const Color(0xFF666666),
          const Color(0xFF999999),
        ][seed % 3],
        rotation = seed * 0.5;

  void draw(Canvas canvas, Size size, double progress) {
    // Adjust progress with delay
    final adjustedProgress = ((progress - startDelay) / (1 - startDelay))
        .clamp(0.0, 1.0);

    if (adjustedProgress <= 0) return;

    // Calculate position
    final x = startX * size.width;
    final y = adjustedProgress * (size.height + 50) - 50;

    // Calculate rotation and scale
    final angle = rotation + (adjustedProgress * math.pi * 4);
    final scale = 1.0 - (adjustedProgress * 0.3);

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.scale(scale);

    final paint = Paint()
      ..color = color.withOpacity(1.0 - adjustedProgress * 0.5)
      ..style = PaintingStyle.fill;

    // Draw rectangular confetti
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: this.size,
        height: this.size * 0.6,
      ),
      paint,
    );

    canvas.restore();
  }
}
