import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/steps_feature_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../models/steps_data.dart';
import 'steps_claim_screen.dart';

/// Main step tracking view with dual-ring progress visualization.
///
/// Shows:
/// - Yesterday section (if claimable reward)
/// - Today section with dual rings
/// - Individual step breakdowns
/// - Sync status
class StepsCounterScreen extends StatefulWidget {
  const StepsCounterScreen({super.key});

  @override
  State<StepsCounterScreen> createState() => _StepsCounterScreenState();
}

class _StepsCounterScreenState extends State<StepsCounterScreen>
    with TickerProviderStateMixin {
  final StepsFeatureService _stepsService = StepsFeatureService();
  final StorageService _storage = StorageService();

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  late AnimationController _ringAnimationController;
  late Animation<double> _userRingAnimation;
  late Animation<double> _partnerRingAnimation;

  Timer? _syncTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    // Initialize ring animations
    _ringAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final userProgress = _stepsService.getUserProgress();
    final partnerProgress = _stepsService.getPartnerProgress();

    _userRingAnimation = Tween<double>(
      begin: 0.0,
      end: userProgress,
    ).animate(CurvedAnimation(
      parent: _ringAnimationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    _partnerRingAnimation = Tween<double>(
      begin: 0.0,
      end: partnerProgress,
    ).animate(CurvedAnimation(
      parent: _ringAnimationController,
      curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
    ));

    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ringAnimationController.forward();
    });

    // Start periodic sync
    _startSyncTimer();
  }

  void _startSyncTimer() {
    // Sync every 60 seconds (app also syncs on launch and resume)
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _stepsService.syncSteps();

      // Update animations with new values
      final userProgress = _stepsService.getUserProgress();
      final partnerProgress = _stepsService.getPartnerProgress();

      _userRingAnimation = Tween<double>(
        begin: _userRingAnimation.value,
        end: userProgress,
      ).animate(CurvedAnimation(
        parent: _ringAnimationController,
        curve: Curves.easeOutCubic,
      ));

      _partnerRingAnimation = Tween<double>(
        begin: _partnerRingAnimation.value,
        end: partnerProgress,
      ).animate(CurvedAnimation(
        parent: _ringAnimationController,
        curve: Curves.easeOutCubic,
      ));

      _ringAnimationController.forward(from: 0.0);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  void dispose() {
    _ringAnimationController.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _stepsService.getTodayData();
    final yesterday = _stepsService.getYesterdayData();
    final connection = _stepsService.getConnectionStatus();
    final partner = _storage.getPartner();
    final hasClaimable = _stepsService.hasClaimableReward();

    final combinedSteps = today?.combinedSteps ?? 0;
    final isPastGoal = combinedSteps >= 20000;

    return Scaffold(
      backgroundColor: _isUs2 ? Us2Theme.bgGradientEnd : BrandLoader().colors.surface,
      extendBodyBehindAppBar: _isUs2,
      appBar: AppBar(
        backgroundColor: _isUs2 ? Colors.transparent : BrandLoader().colors.surface,
        elevation: 0,
        leading: _isUs2
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Us2Theme.textDark, size: 20),
                  ),
                ),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: BrandLoader().colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Steps Together',
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
        ),
        centerTitle: true,
        actions: [
          if (_isRefreshing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _isUs2 ? Us2Theme.gradientAccentStart : null,
                ),
              ),
            )
          else
            _isUs2
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: _refreshData,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.refresh, color: Us2Theme.textDark, size: 18),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.refresh, color: BrandLoader().colors.textPrimary),
                    onPressed: _refreshData,
                  ),
        ],
      ),
      body: Container(
        decoration: _isUs2
            ? const BoxDecoration(gradient: Us2Theme.backgroundGradient)
            : null,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Yesterday section (if claimable) or Max tier banner
              if (hasClaimable)
                _buildYesterdayClaimSection(yesterday!)
              else if (isPastGoal)
                _buildMaxTierBanner(),

              if (hasClaimable || isPastGoal) const SizedBox(height: 24),

              // Today section
              _buildTodaySection(today, connection, partner?.name ?? 'Partner'),

              const SizedBox(height: 24),

              // Tomorrow preview (if not past goal)
              if (!isPastGoal) _buildTomorrowPreview(today),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildYesterdayClaimSection(StepsDay yesterday) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isUs2 ? null : BrandLoader().colors.textPrimary,
        gradient: _isUs2 ? Us2Theme.accentGradient : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Yesterday',
                style: _isUs2
                    ? TextStyle(
                        fontFamily: Us2Theme.fontHeading,
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      )
                    : AppTheme.headlineFont.copyWith(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Claim Now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isUs2 ? Us2Theme.primaryBrandPink : BrandLoader().colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatNumber(yesterday.combinedSteps),
                    style: _isUs2
                        ? const TextStyle(
                            fontFamily: Us2Theme.fontHeading,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )
                        : AppTheme.headlineFont.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                  ),
                  Text(
                    'combined steps',
                    style: TextStyle(
                      fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                      fontSize: 14,
                      color: Colors.white.withOpacity(_isUs2 ? 0.8 : 0.7),
                    ),
                  ),
                ],
              ),
              Text(
                '+${yesterday.earnedLP} LP',
                style: _isUs2
                    ? const TextStyle(
                        fontFamily: Us2Theme.fontHeading,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )
                    : AppTheme.headlineFont.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _navigateToClaim(yesterday),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _isUs2 ? Us2Theme.primaryBrandPink : BrandLoader().colors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Claim +${yesterday.earnedLP} Love Points',
                style: _isUs2
                    ? const TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Us2Theme.primaryBrandPink,
                      )
                    : AppTheme.headlineFont.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BrandLoader().colors.textPrimary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaxTierBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isUs2 ? null : BrandLoader().colors.textPrimary,
        gradient: _isUs2 ? Us2Theme.accentGradient : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Max Tier Reached!',
                    style: TextStyle(
                      fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tomorrow you\'ll earn',
                  style: TextStyle(
                    fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                    fontSize: 14,
                    color: Colors.white.withOpacity(_isUs2 ? 0.8 : 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+30 LP',
            style: _isUs2
                ? const TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )
                : AppTheme.headlineFont.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection(
      StepsDay? today, StepsConnection connection, String partnerName) {
    final userSteps = today?.userSteps ?? 0;
    final partnerSteps = today?.partnerSteps ?? 0;
    // Check if partner data is still loading (connected but no sync yet for today)
    final isPartnerLoading = connection.partnerConnected && today?.partnerLastSync == null;
    final combinedSteps = userSteps + partnerSteps;
    final isPastGoal = combinedSteps >= 20000;
    final projectedLP = _stepsService.getProjectedLP();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isUs2 ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPastGoal ? 'Today · Goal Exceeded!' : 'Today · In Progress',
                style: _isUs2
                    ? const TextStyle(
                        fontFamily: Us2Theme.fontHeading,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Us2Theme.textDark,
                      )
                    : AppTheme.headlineFont.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BrandLoader().colors.textPrimary,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dual ring progress
          SizedBox(
            width: 240,
            height: 240,
            child: AnimatedBuilder(
              animation: _ringAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: DualRingPainter(
                    userProgress: _userRingAnimation.value,
                    partnerProgress: _partnerRingAnimation.value,
                    userColor: _isUs2 ? Us2Theme.gradientAccentStart : BrandLoader().colors.textPrimary,
                    userColorEnd: _isUs2 ? Us2Theme.gradientAccentEnd : null,
                    partnerColor: const Color(0xFF999999),
                    backgroundColor: const Color(0xFFE0E0E0),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatNumber(combinedSteps),
                          style: _isUs2
                              ? const TextStyle(
                                  fontFamily: Us2Theme.fontHeading,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: Us2Theme.textDark,
                                )
                              : AppTheme.headlineFont.copyWith(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: BrandLoader().colors.textPrimary,
                                ),
                        ),
                        if (isPastGoal) ...[
                          Text(
                            '+${_formatNumber(combinedSteps - 20000)} over goal',
                            style: TextStyle(
                              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                              fontSize: 14,
                              color: _isUs2 ? const Color(0xFF4CAF50) : BrandLoader().colors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Goal: 20,000',
                            style: TextStyle(
                              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                              fontSize: 12,
                              color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '/ 20,000',
                            style: TextStyle(
                              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                              fontSize: 16,
                              color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (projectedLP > 0)
                            Text(
                              'Tomorrow: +$projectedLP LP',
                              style: TextStyle(
                                fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                                fontSize: 14,
                                color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                  'You',
                  userSteps,
                  _isUs2 ? Us2Theme.gradientAccentStart : BrandLoader().colors.textPrimary,
                  isLoading: false,
                  isGradient: _isUs2),
              const SizedBox(width: 32),
              _buildLegendItem(partnerName, partnerSteps, const Color(0xFF999999), isLoading: isPartnerLoading),
            ],
          ),
          const SizedBox(height: 20),

          // Sync status
          _buildSyncStatus(today, connection),

          // Overflow indicator (if past goal)
          if (isPastGoal) ...[
            const SizedBox(height: 20),
            _buildOverflowIndicator(combinedSteps),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int steps, Color color,
      {bool isLoading = false, bool isGradient = false}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isGradient ? null : color,
            gradient: isGradient ? Us2Theme.accentGradient : null,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                fontSize: 12,
                color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
                ),
              )
            else
              Text(
                _formatNumber(steps),
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
          ],
        ),
      ],
    );
  }

  Widget _buildSyncStatus(StepsDay? today, StepsConnection connection) {
    final lastSync = today?.lastSync;
    final partnerSync = today?.partnerLastSync;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sync,
              size: 14,
              color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              lastSync != null
                  ? 'Last synced ${_formatTimeSince(lastSync)}'
                  : 'Not synced yet',
              style: TextStyle(
                fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                fontSize: 12,
                color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
              ),
            ),
          ],
        ),
        if (connection.partnerConnected && partnerSync != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Partner synced ${_formatTimeSince(partnerSync)}',
              style: TextStyle(
                fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                fontSize: 12,
                color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverflowIndicator(int combinedSteps) {
    final percentage = ((combinedSteps / 20000) * 100).round();
    final successColor = _isUs2 ? const Color(0xFF4CAF50) : BrandLoader().colors.success;

    return Column(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // Base 100% fill
              Container(
                decoration: BoxDecoration(
                  color: successColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Striped overflow pattern
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CustomPaint(
                    painter: StripedPainter(
                      color: successColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$percentage% of daily goal · Keep going!',
          style: TextStyle(
            fontFamily: _isUs2 ? Us2Theme.fontBody : null,
            fontSize: 12,
            color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTomorrowPreview(StepsDay? today) {
    final projectedLP = _stepsService.getProjectedLP();
    final combinedSteps = today?.combinedSteps ?? 0;

    if (projectedLP == 0) {
      final neededSteps = 10000 - combinedSteps;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _isUs2 ? Us2Theme.beige : BrandLoader().colors.borderLight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.directions_walk,
              color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Walk ${_formatNumber(neededSteps)} more steps together to start earning LP!',
                style: TextStyle(
                  fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                  fontSize: 14,
                  color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _isUs2 ? Us2Theme.beige : BrandLoader().colors.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tomorrow\'s Reward',
                style: TextStyle(
                  fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                  fontSize: 12,
                  color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
                ),
              ),
              Text(
                'Current tier: ${_getTierName(combinedSteps)}',
                style: TextStyle(
                  fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                  fontSize: 14,
                  color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isUs2 ? null : BrandLoader().colors.textPrimary,
              gradient: _isUs2 ? Us2Theme.accentGradient : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$projectedLP LP',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToClaim(StepsDay yesterday) {
    HapticService().tap();
    SoundService().tap();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepsClaimScreen(stepsDay: yesterday),
      ),
    ).then((_) {
      // Refresh after returning from claim
      if (mounted) setState(() {});
    });
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

  String _formatTimeSince(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
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

/// Custom painter for dual-ring progress visualization
class DualRingPainter extends CustomPainter {
  final double userProgress;
  final double partnerProgress;
  final Color userColor;
  final Color? userColorEnd; // For gradient support (Us 2.0)
  final Color partnerColor;
  final Color backgroundColor;

  DualRingPainter({
    required this.userProgress,
    required this.partnerProgress,
    required this.userColor,
    this.userColorEnd,
    required this.partnerColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 10;
    final innerRadius = outerRadius - 30;
    const strokeWidth = 14.0;

    // Background paint
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // User ring paint (outer) - with optional gradient
    final userPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (userColorEnd != null) {
      // Use sweep gradient for Us 2.0
      userPaint.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [userColor, userColorEnd!],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    } else {
      userPaint.color = userColor;
    }

    // Partner ring paint (inner)
    final partnerPaint = Paint()
      ..color = partnerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background rings
    canvas.drawCircle(center, outerRadius, bgPaint);
    canvas.drawCircle(center, innerRadius, bgPaint);

    // Draw progress rings
    const startAngle = -math.pi / 2; // Start from top

    // User ring (outer) - clockwise
    if (userProgress > 0) {
      final userSweep = 2 * math.pi * userProgress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        userSweep,
        false,
        userPaint,
      );
    }

    // Partner ring (inner) - clockwise
    if (partnerProgress > 0) {
      final partnerSweep = 2 * math.pi * partnerProgress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        partnerSweep,
        false,
        partnerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(DualRingPainter oldDelegate) {
    return oldDelegate.userProgress != userProgress ||
        oldDelegate.partnerProgress != partnerProgress ||
        oldDelegate.userColorEnd != userColorEnd;
  }
}

/// Custom painter for striped overflow pattern
class StripedPainter extends CustomPainter {
  final Color color;

  StripedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const spacing = 8.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StripedPainter oldDelegate) => false;
}
