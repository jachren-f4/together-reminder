import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/steps_feature_service.dart';
import '../../services/haptic_service.dart';
import '../../services/sound_service.dart';
import '../../config/brand/brand_loader.dart';
import '../../theme/app_theme.dart';
import '../../animations/animation_config.dart';

/// Steps Together quest card for the side quests carousel.
///
/// Three visual states based on mockups:
/// - Not Connected: Grayed sneaker, "Connect HealthKit" prompt
/// - Progress: Dual progress bars, today's step count
/// - Claim Ready: Dark/inverted theme, yesterday's reward
class StepsQuestCard extends StatefulWidget {
  final VoidCallback onTap;
  final bool showShadow;

  const StepsQuestCard({
    super.key,
    required this.onTap,
    this.showShadow = false,
  });

  @override
  State<StepsQuestCard> createState() => _StepsQuestCardState();
}

class _StepsQuestCardState extends State<StepsQuestCard>
    with SingleTickerProviderStateMixin {
  final StepsFeatureService _stepsService = StepsFeatureService();
  final StorageService _storage = StorageService();

  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: AnimationConfig.fast,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: AnimationConfig.buttonPress,
    ));
    _shadowAnimation = Tween<double>(
      begin: 4.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: AnimationConfig.buttonPress,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
    HapticService().tap();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _handleTap() {
    SoundService().tap();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // Only show on iOS
    if (!Platform.isIOS) {
      return const SizedBox.shrink();
    }

    final state = _stepsService.getCurrentState();

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _isPressed ? 0.9 : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: BrandLoader().colors.surface, // Always white - individual sections handle their own background
                  border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
                  borderRadius: BorderRadius.circular(0),
                  boxShadow: widget.showShadow
                      ? [
                          BoxShadow(
                            color: BrandLoader().colors.textPrimary.withOpacity(0.15),
                            blurRadius: 0,
                            offset: Offset(_shadowAnimation.value, _shadowAnimation.value),
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            ),
          );
        },
        child: _buildCardContent(state),
      ),
    );
  }

  Widget _buildCardContent(StepsFeatureState state) {
    switch (state) {
      case StepsFeatureState.notSupported:
        return const SizedBox.shrink();

      case StepsFeatureState.neitherConnected:
      case StepsFeatureState.partnerConnected:
        return _buildNotConnectedCard();

      case StepsFeatureState.waitingForPartner:
      case StepsFeatureState.tracking:
        return _buildProgressCard();

      case StepsFeatureState.claimReady:
        return _buildClaimReadyCard();
    }
  }

  /// Not connected state - grayed sneaker emoji, connect prompt (matches mockup 01)
  /// Wrapped with BONUS ribbon overlay until user connects HealthKit
  Widget _buildNotConnectedCard() {
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image section - sneaker emoji centered
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: BrandLoader().colors.textPrimary,
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Grayed sneaker emoji - grayscale filter + reduced opacity
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 0.4, 0,
                ]),
                child: const Text(
                  '👟',
                  style: TextStyle(fontSize: 64),
                ),
              ),
              const SizedBox(height: 12),
              // "Connect HealthKit" - black, 14px, semi-bold
              Text(
                'Connect HealthKit',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BrandLoader().colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              // "Earn up to +30 LP daily" - gray, 12px
              Text(
                'Earn up to +30 LP daily',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),

        // Content section - white background
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "Steps Together" - title
                        Text(
                          'Steps Together',
                          style: AppTheme.headlineFont.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // "Walk together, earn together" - gray italic
                        Text(
                          'Walk together, earn together',
                          style: AppTheme.headlineFont.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF666666),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Grayed "+30" badge - gray border, light bg, gray text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      border: Border.all(color: const Color(0xFF999999), width: 1),
                    ),
                    child: Text(
                      '+30',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer with "CONNECT" badge - black border, white bg
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
                    ),
                    child: Text(
                      'CONNECT',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: BrandLoader().colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // Wrap with BONUS ribbon overlay
    return Stack(
      clipBehavior: Clip.none,
      children: [
        cardContent,
        // BONUS ribbon at top-left
        const Positioned(
          top: 12,
          left: 0,
          child: _BonusRibbon(),
        ),
      ],
    );
  }

  /// Progress state - big step count with single progress bar (matches mockup)
  Widget _buildProgressCard() {
    final today = _stepsService.getTodayData();
    final partner = _storage.getPartner();
    final connection = _stepsService.getConnectionStatus();

    final userSteps = today?.userSteps ?? 0;
    final partnerSteps = today?.partnerSteps ?? 0;
    // Check if partner data is still loading (connected but no sync yet for today)
    final isPartnerLoading = connection.partnerConnected && today?.partnerLastSync == null;
    final combinedSteps = userSteps + partnerSteps;
    final projectedLP = _stepsService.getProjectedLP();

    // Progress as percentage of 20K goal
    final progress = (combinedSteps / 20000).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image section with big step count and progress bar
        Container(
          height: 170,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5F5F5), Color(0xFFE8E8E8)],
            ),
            border: Border(
              bottom: BorderSide(
                color: BrandLoader().colors.textPrimary,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Big step count - show loading if partner data not yet synced
                if (isPartnerLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatNumberWithCommas(userSteps),
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BrandLoader().colors.textTertiary,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _formatNumberWithCommas(combinedSteps),
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                    ),
                  ),
                const SizedBox(height: 4),
                // Goal text
                Text(
                  isPartnerLoading ? 'waiting for partner...' : 'of 20,000 today',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 12),
                // Single progress bar
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0E0E0),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      color: BrandLoader().colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Steps Together',
                          style: AppTheme.headlineFont.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You + ${partner?.name ?? 'Partner'} combined',
                          style: AppTheme.headlineFont.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF666666),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Reward badge (black with projected LP)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BrandLoader().colors.textPrimary,
                      border: Border.all(
                        color: BrandLoader().colors.textPrimary,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '+${projectedLP > 0 ? projectedLP : _calculateProjectedLP(combinedSteps)}',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer with View Details badge
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.surface,
                    border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
                  ),
                  child: Text(
                    'VIEW DETAILS',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: BrandLoader().colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Calculate projected LP based on combined steps
  int _calculateProjectedLP(int combinedSteps) {
    if (combinedSteps >= 20000) return 30;
    if (combinedSteps >= 15000) return 21;
    if (combinedSteps >= 10000) return 15;
    return 0;
  }

  /// Claim ready state - dark theme with "Yesterday" label, steps, date, reward (matches mockup)
  Widget _buildClaimReadyCard() {
    final yesterday = _stepsService.getYesterdayData();
    final earnedLP = yesterday?.earnedLP ?? 0;
    final combinedSteps = yesterday?.combinedSteps ?? 0;

    // Calculate yesterday's date for display
    final yesterdayDate = DateTime.now().subtract(const Duration(days: 1));
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December'];
    final dateString = '${monthNames[yesterdayDate.month - 1]} ${yesterdayDate.day}';

    // Calculate hours left to claim (expiry at end of today, roughly)
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final hoursLeft = endOfDay.difference(now).inHours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image section - dark with "Yesterday", steps, date, reward
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: BrandLoader().colors.textPrimary,
            border: Border(
              bottom: BorderSide(
                color: BrandLoader().colors.textPrimary,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // "Yesterday" label
                Text(
                  'Yesterday',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Colors.white.withOpacity(0.7),
                  ).copyWith(fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 8),
                // Big step count
                Text(
                  _formatNumberWithCommas(combinedSteps),
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Date
                Text(
                  dateString,
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                // Reward badge with border
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    '+$earnedLP LP',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Content - white theme (unlike image section)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Steps Together',
                          style: AppTheme.headlineFont.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reward ready to claim',
                          style: AppTheme.headlineFont.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF666666),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Reward badge (black)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: BrandLoader().colors.textPrimary,
                      border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
                    ),
                    child: Text(
                      '+$earnedLP',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer with Claim badge AND expiry time
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Claim Now badge (black background)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: BrandLoader().colors.textPrimary,
                        border: Border.all(color: BrandLoader().colors.textPrimary, width: 1),
                      ),
                      child: Text(
                        'CLAIM NOW',
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Expiry time
                    Text(
                      '${hoursLeft}h left',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 11,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K'.replaceAll('.0K', 'K');
    }
    return number.toString();
  }

  /// Format number with commas (e.g., 12450 -> "12,450")
  String _formatNumberWithCommas(int number) {
    final str = number.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
    }
    return result.toString();
  }
}

/// "BONUS" ribbon for the not-connected state
/// Shows at top-left of the Steps card until user connects HealthKit
class _BonusRibbon extends StatelessWidget {
  const _BonusRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: const Text(
        'BONUS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
