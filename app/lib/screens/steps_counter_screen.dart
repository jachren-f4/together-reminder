import 'dart:async';
import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../painters/combined_ring_painter.dart';
import '../services/storage_service.dart';
import '../services/steps_feature_service.dart';
import '../services/steps_debug_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../models/steps_data.dart';
import '../widgets/steps_milestone_overlay.dart';
import 'steps_claim_screen.dart';
import 'steps_tier_breakdown_screen.dart';
import 'steps_week_history_screen.dart';

/// Main step tracking view with combined ring progress visualization.
///
/// Features:
/// - Combined progress ring (user + partner)
/// - Tier progress bar with "See all tiers" navigation
/// - Claim countdown card
/// - Week preview with streak
/// - Team messages
/// - Milestone celebrations
class StepsCounterScreen extends StatefulWidget {
  const StepsCounterScreen({super.key});

  @override
  State<StepsCounterScreen> createState() => _StepsCounterScreenState();
}

class _StepsCounterScreenState extends State<StepsCounterScreen>
    with TickerProviderStateMixin {
  final StepsFeatureService _stepsService = StepsFeatureService();
  final StorageService _storage = StorageService();
  final StepsDebugService _debugService = StepsDebugService();

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  late AnimationController _ringAnimationController;
  late Animation<double> _userRingAnimation;
  late Animation<double> _partnerRingAnimation;

  Timer? _syncTimer;
  bool _isRefreshing = false;
  int? _lastCelebratedTier;

  // Tier thresholds and LP rewards
  static const List<int> _tierThresholds = [10000, 12000, 14000, 16000, 18000, 20000];
  static const List<int> _tierLP = [15, 18, 21, 24, 27, 30];

  @override
  void initState() {
    super.initState();

    _ringAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _initializeAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ringAnimationController.forward();
    });

    _startSyncTimer();
  }

  void _initializeAnimations() {
    final today = _stepsService.getTodayData();
    final userSteps = today?.userSteps ?? 0;
    final partnerSteps = today?.partnerSteps ?? 0;
    const goal = 20000.0;

    _userRingAnimation = Tween<double>(
      begin: 0.0,
      end: (userSteps / goal).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _ringAnimationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    _partnerRingAnimation = Tween<double>(
      begin: 0.0,
      end: (partnerSteps / goal).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _ringAnimationController,
      curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
    ));
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // Store previous tier for milestone detection
      final previousData = _stepsService.getTodayData();
      final previousTier = _getCurrentTier(previousData?.combinedSteps ?? 0);

      await _stepsService.syncSteps();

      // Check for tier change
      final newData = _stepsService.getTodayData();
      final newTier = _getCurrentTier(newData?.combinedSteps ?? 0);

      if (newTier > previousTier && previousTier >= 10000 && _lastCelebratedTier != newTier) {
        _lastCelebratedTier = newTier;
        _showMilestoneCelebration(previousTier, newTier, newData!);
      }

      // Update animations
      final userSteps = newData?.userSteps ?? 0;
      final partnerSteps = newData?.partnerSteps ?? 0;
      const goal = 20000.0;

      _userRingAnimation = Tween<double>(
        begin: _userRingAnimation.value,
        end: (userSteps / goal).clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _ringAnimationController,
        curve: Curves.easeOutCubic,
      ));

      _partnerRingAnimation = Tween<double>(
        begin: _partnerRingAnimation.value,
        end: (partnerSteps / goal).clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _ringAnimationController,
        curve: Curves.easeOutCubic,
      ));

      _ringAnimationController.forward(from: 0.0);

      HapticService().tap();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  int _getCurrentTier(int combinedSteps) {
    for (int i = _tierThresholds.length - 1; i >= 0; i--) {
      if (combinedSteps >= _tierThresholds[i]) {
        return _tierThresholds[i];
      }
    }
    return 0;
  }

  int _getTierLP(int tier) {
    final index = _tierThresholds.indexOf(tier);
    return index >= 0 ? _tierLP[index] : 0;
  }

  void _showMilestoneCelebration(int previousTier, int newTier, StepsDay stepsDay) {
    final partner = _storage.getPartner();
    showStepsMilestoneOverlay(
      context: context,
      previousTier: previousTier,
      newTier: newTier,
      combinedSteps: stepsDay.combinedSteps,
      userSteps: stepsDay.userSteps,
      partnerSteps: stepsDay.partnerSteps,
      partnerName: partner?.name ?? 'Partner',
      previousLP: _getTierLP(previousTier),
      newLP: _getTierLP(newTier),
    );
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
    final isAboveThreshold = combinedSteps >= 10000;

    return Scaffold(
      backgroundColor: _isUs2 ? Us2Theme.bgGradientEnd : BrandLoader().colors.surface,
      extendBodyBehindAppBar: _isUs2,
      appBar: _buildAppBar(),
      body: Container(
        decoration: _isUs2
            ? const BoxDecoration(gradient: Us2Theme.backgroundGradient)
            : null,
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: Us2Theme.gradientAccentStart,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Debug indicator
                  if (_debugService.useMockData)
                    _buildDebugIndicator(),

                  // Yesterday claim section
                  if (hasClaimable)
                    _buildYesterdayClaimSection(yesterday!),

                  if (hasClaimable) const SizedBox(height: 16),

                  // Today's progress card
                  _buildTodayProgressCard(today, connection, partner?.name ?? 'Partner'),

                  const SizedBox(height: 16),

                  // Tier progress card (only if above threshold)
                  if (isAboveThreshold)
                    _buildTierProgressCard(combinedSteps),

                  if (isAboveThreshold) const SizedBox(height: 16),

                  // Claim info card (if above threshold)
                  if (isAboveThreshold)
                    _buildClaimInfoCard(today),

                  if (isAboveThreshold) const SizedBox(height: 16),

                  // Below threshold encouragement
                  if (!isAboveThreshold)
                    _buildBelowThresholdCard(combinedSteps),

                  if (!isAboveThreshold) const SizedBox(height: 16),

                  // Week preview card
                  _buildWeekPreviewCard(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
                        color: Colors.black.withValues(alpha: 0.1),
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
        _isUs2 ? 'Steps' : 'Steps Together',
        style: _isUs2
            ? const TextStyle(
                fontFamily: Us2Theme.fontHeading,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textDark,
              )
            : TextStyle(
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
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(Icons.refresh, color: Us2Theme.textDark, size: 18),
                          ),
                          // Green sync dot
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.refresh, color: BrandLoader().colors.textPrimary),
                  onPressed: _refreshData,
                ),
      ],
    );
  }

  Widget _buildDebugIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bug_report, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Text(
            'MOCK DATA ACTIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYesterdayClaimSection(StepsDay yesterday) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Us2Theme.accentGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Yesterday',
                style: TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Claim Now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.gradientAccentStart,
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
                    style: const TextStyle(
                      fontFamily: Us2Theme.fontHeading,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'combined steps',
                    style: TextStyle(
                      fontFamily: Us2Theme.fontBody,
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Text(
                '+${yesterday.earnedLP} LP',
                style: const TextStyle(
                  fontFamily: Us2Theme.fontHeading,
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
                foregroundColor: Us2Theme.gradientAccentStart,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Claim +${yesterday.earnedLP} Love Points',
                style: const TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayProgressCard(
      StepsDay? today, StepsConnection connection, String partnerName) {
    final userSteps = today?.userSteps ?? 0;
    final partnerSteps = today?.partnerSteps ?? 0;
    final combinedSteps = userSteps + partnerSteps;
    final isPartnerLoading = connection.partnerConnected && today?.partnerLastSync == null;
    final projectedLP = _stepsService.getProjectedLP();
    final progressPercent = ((combinedSteps / 20000) * 100).round();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with LIVE badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Progress',
                style: TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Combined ring
          SizedBox(
            width: 220,
            height: 220,
            child: AnimatedBuilder(
              animation: _ringAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: CombinedRingPainter(
                    userProgress: _userRingAnimation.value,
                    partnerProgress: _partnerRingAnimation.value,
                    userColorStart: Us2Theme.gradientAccentStart,
                    userColorEnd: Us2Theme.gradientAccentEnd,
                    partnerColorStart: const Color(0xFF4ECDC4),
                    partnerColorEnd: const Color(0xFF45B7AA),
                    backgroundColor: const Color(0xFFF0F0F0),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatNumber(combinedSteps),
                          style: const TextStyle(
                            fontFamily: Us2Theme.fontHeading,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Us2Theme.textDark,
                          ),
                        ),
                        const Text(
                          'of 20,000 goal',
                          style: TextStyle(
                            fontFamily: Us2Theme.fontBody,
                            fontSize: 14,
                            color: Us2Theme.textLight,
                          ),
                        ),
                        if (projectedLP > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFB347), Color(0xFFFFD89B)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+$projectedLP LP tomorrow',
                              style: const TextStyle(
                                fontFamily: Us2Theme.fontBody,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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

          // Partner breakdown with teal color
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                'You',
                userSteps,
                Us2Theme.gradientAccentStart,
                isGradient: true,
              ),
              const SizedBox(width: 40),
              _buildLegendItem(
                partnerName,
                partnerSteps,
                const Color(0xFF4ECDC4),
                isLoading: isPartnerLoading,
                isTeal: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sync status
          _buildSyncStatus(today, connection),

          // Team message
          const SizedBox(height: 16),
          _buildTeamMessage(progressPercent),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int steps, Color color,
      {bool isLoading = false, bool isGradient = false, bool isTeal = false}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            gradient: isGradient
                ? Us2Theme.accentGradient
                : isTeal
                    ? const LinearGradient(
                        colors: [Color(0xFF4ECDC4), Color(0xFF45B7AA)],
                      )
                    : null,
            color: (!isGradient && !isTeal) ? color : null,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 12,
                color: Us2Theme.textLight,
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Us2Theme.textLight,
                ),
              )
            else
              Text(
                _formatNumber(steps),
                style: const TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.access_time, size: 12, color: Us2Theme.textLight),
        const SizedBox(width: 4),
        Text(
          lastSync != null
              ? 'Synced ${_formatTimeSince(lastSync)}${partnerSync != null ? ' · Partner ${_formatTimeSince(partnerSync)}' : ''}'
              : 'Not synced yet',
          style: const TextStyle(
            fontFamily: Us2Theme.fontBody,
            fontSize: 12,
            color: Us2Theme.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMessage(int progressPercent) {
    String message;
    if (progressPercent >= 100) {
      message = _isUs2 ? 'Goal crushed! Amazing work!' : 'Goal crushed! Amazing teamwork!';
    } else if (progressPercent >= 75) {
      message = 'Almost there! Push for the goal!';
    } else if (progressPercent >= 50) {
      message = _isUs2 ? 'Great progress! You\'re halfway there!' : 'Great teamwork! You\'re halfway there!';
    } else {
      message = _isUs2 ? 'Keep walking! Every step counts.' : 'Keep walking together!';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Us2Theme.gradientAccentStart.withValues(alpha: 0.1),
            Us2Theme.gradientAccentEnd.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: Us2Theme.fontBody,
          fontSize: 14,
          color: Us2Theme.textDark,
        ),
      ),
    );
  }

  Widget _buildTierProgressCard(int combinedSteps) {
    final currentTierIndex = _tierThresholds.indexWhere((t) => combinedSteps < t);
    final nextTierIndex = currentTierIndex >= 0 ? currentTierIndex : _tierThresholds.length;
    final progressPercent = combinedSteps / 20000;

    int? nextTier;
    int? stepsToNext;
    int? lpBonus;

    if (nextTierIndex < _tierThresholds.length) {
      nextTier = _tierThresholds[nextTierIndex];
      stepsToNext = nextTier - combinedSteps;
      final currentLP = _stepsService.getProjectedLP();
      lpBonus = _tierLP[nextTierIndex] - currentLP;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tier Progress',
                style: TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StepsTierBreakdownScreen(
                      currentCombinedSteps: combinedSteps,
                    ),
                  ),
                ),
                child: const Text(
                  'See all tiers →',
                  style: TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.gradientAccentStart,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                // Background track
                Container(
                  height: 8,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Progress fill (left to right)
                Container(
                  height: 8,
                  width: constraints.maxWidth * progressPercent.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: Us2Theme.accentGradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tier markers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_tierThresholds.length, (index) {
              final tier = _tierThresholds[index];
              final isAchieved = combinedSteps >= tier;
              final isCurrent = index == (nextTierIndex - 1).clamp(0, _tierThresholds.length - 1);

              return Column(
                children: [
                  if (isCurrent)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        gradient: Us2Theme.accentGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  Text(
                    '${tier ~/ 1000}K',
                    style: TextStyle(
                      fontFamily: Us2Theme.fontBody,
                      fontSize: 10,
                      fontWeight: isAchieved ? FontWeight.w700 : FontWeight.w400,
                      color: isAchieved ? Us2Theme.gradientAccentStart : Us2Theme.textLight,
                    ),
                  ),
                ],
              );
            }),
          ),

          if (nextTier != null && stepsToNext != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Next tier in',
                        style: TextStyle(
                          fontFamily: Us2Theme.fontBody,
                          fontSize: 12,
                          color: Us2Theme.textMedium,
                        ),
                      ),
                      Text(
                        '${_formatNumber(stepsToNext)} more steps',
                        style: const TextStyle(
                          fontFamily: Us2Theme.fontHeading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Us2Theme.textDark,
                        ),
                      ),
                    ],
                  ),
                  if (lpBonus != null && lpBonus > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB347), Color(0xFFFFD89B)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+$lpBonus LP',
                        style: const TextStyle(
                          fontFamily: Us2Theme.fontBody,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClaimInfoCard(StepsDay? today) {
    final projectedLP = _stepsService.getProjectedLP();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final hoursUntil = midnight.difference(now).inHours;
    final minutesUntil = midnight.difference(now).inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Us2Theme.accentGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tomorrow\'s Claim',
                style: TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'in ${hoursUntil}h ${minutesUntil}m',
                  style: const TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Based on today\'s progress,\nyou\'ll receive',
                style: TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                '+$projectedLP LP',
                style: const TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                'LP is auto-claimed when you open the app tomorrow',
                style: TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBelowThresholdCard(int combinedSteps) {
    final stepsNeeded = 10000 - combinedSteps;
    final progress = combinedSteps / 10000;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            _isUs2 ? 'Keep walking!' : 'Keep walking together!',
            style: const TextStyle(
              fontFamily: Us2Theme.fontHeading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Walk ${_formatNumber(stepsNeeded)} more steps to start earning LP',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 14,
              color: Us2Theme.textMedium,
            ),
          ),
          const SizedBox(height: 16),

          // Progress to 10K
          LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                // Background track
                Container(
                  height: 8,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Progress fill (left to right)
                Container(
                  height: 8,
                  width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: Us2Theme.accentGradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatNumber(combinedSteps),
                style: const TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.gradientAccentStart,
                ),
              ),
              const Text(
                '10,000 (15 LP)',
                style: TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 12,
                  color: Us2Theme.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      'Tips to reach your goal',
                      style: TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Us2Theme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTipRow(_isUs2 ? 'Take a walk after dinner' : 'Take a walk together after dinner'),
                _buildTipRow('Park further away when shopping'),
                _buildTipRow('Take the stairs instead of elevator'),
                if (_isUs2) _buildTipRow('Go for a morning walk'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(String tip) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 12,
                color: Us2Theme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekPreviewCard() {
    final now = DateTime.now();
    final weekData = <_WeekDayData>[];
    int streak = 0;

    // Build week data
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final stepsDay = _storage.getStepsDay(dateKey);
      final isToday = i == 0;

      weekData.add(_WeekDayData(
        dayName: _getShortDayName(date.weekday),
        steps: stepsDay?.combinedSteps ?? 0,
        isToday: isToday,
        isSuccess: (stepsDay?.combinedSteps ?? 0) >= 10000,
        isMax: (stepsDay?.combinedSteps ?? 0) >= 20000,
      ));
    }

    // Calculate streak from the end
    for (int i = weekData.length - 1; i >= 0; i--) {
      if (weekData[i].isSuccess) {
        streak++;
      } else if (!weekData[i].isToday) {
        break;
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StepsWeekHistoryScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                ),
                Row(
                  children: [
                    const Text('', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      _isUs2 ? '$streak day streak' : '$streak day streak of 10K+ together',
                      style: const TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.gradientAccentStart,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekData.map((day) => _buildWeekDayCircle(day)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDayCircle(_WeekDayData day) {
    Color bgColor;
    Color textColor;
    String content;

    if (day.isToday) {
      bgColor = Us2Theme.gradientAccentStart;
      textColor = Colors.white;
      content = day.steps >= 10000 ? '${day.steps ~/ 1000}K' : '';
    } else if (day.isMax) {
      bgColor = const Color(0xFFFFB347);
      textColor = Colors.white;
      content = '';
    } else if (day.isSuccess) {
      bgColor = const Color(0xFF4CAF50);
      textColor = Colors.white;
      content = '';
    } else if (day.steps > 0) {
      bgColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFFF9800);
      content = '';
    } else {
      bgColor = const Color(0xFFF5F5F5);
      textColor = const Color(0xFFCCCCCC);
      content = '-';
    }

    return Column(
      children: [
        Text(
          day.dayName,
          style: const TextStyle(
            fontFamily: Us2Theme.fontBody,
            fontSize: 10,
            color: Us2Theme.textLight,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: day.isToday ? null : bgColor,
            gradient: day.isToday ? Us2Theme.accentGradient : null,
            shape: BoxShape.circle,
            boxShadow: day.isToday
                ? [
                    BoxShadow(
                      color: Us2Theme.gradientAccentStart.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              content,
              style: TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
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

  String _getShortDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }
}

class _WeekDayData {
  final String dayName;
  final int steps;
  final bool isToday;
  final bool isSuccess;
  final bool isMax;

  _WeekDayData({
    required this.dayName,
    required this.steps,
    required this.isToday,
    required this.isSuccess,
    required this.isMax,
  });
}
