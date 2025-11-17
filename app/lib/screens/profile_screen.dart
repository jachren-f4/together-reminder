import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/love_point_service.dart';
import '../theme/app_theme.dart';
import '../utils/number_formatter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final stats = LovePointService.getStats();

    return Scaffold(
      backgroundColor: AppTheme.primaryWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(user, partner),
              _buildHeroStats(stats),
              _buildCurrentArena(stats),
              _buildProgressSection(stats),
            ],
          ),
        ),
      ),
    );
  }

  /// Section 1: Header (Black background)
  Widget _buildHeader(user, partner) {
    // Format subtitle: "Joakim & Taija"
    String subtitle;
    if (user != null && partner != null) {
      final combined = '${user.name} & ${partner.name}';
      // Truncate if too long
      subtitle = combined.length > 30
          ? '${combined.substring(0, 27)}...'
          : combined;
    } else {
      subtitle = 'Your Progress';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      color: AppTheme.primaryBlack,
      child: Column(
        children: [
          Text(
            'PROGRESS',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w400,
              letterSpacing: 2,
              color: AppTheme.primaryWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTheme.bodyFont.copyWith(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppTheme.primaryWhite.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 2: Hero Stats (Gradient background with LP and Streak)
  Widget _buildHeroStats(Map<String, dynamic> stats) {
    final lovePoints = stats['total'] ?? 0;
    final dayStreak = stats['streak'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFAFAFA),
            Color(0xFFF0F0F0),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryBlack, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left: Love Points
          Expanded(
            child: Column(
              children: [
                Text(
                  NumberFormatter.format(lovePoints),
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'LOVE POINTS',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    letterSpacing: 1,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),

          // Center: Divider
          Container(
            width: 2,
            height: 60,
            color: AppTheme.primaryBlack,
          ),

          // Right: Day Streak
          Expanded(
            child: Column(
              children: [
                Text(
                  NumberFormatter.format(dayStreak),
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DAY STREAK',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 12,
                    letterSpacing: 1,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section 3: Current Arena
  Widget _buildCurrentArena(Map<String, dynamic> stats) {
    final arena = stats['currentArena'] ?? {
      'emoji': '🏆',
      'name': 'Current Arena',
    };
    final tier = stats['tier'] ?? 1;
    final emoji = arena['emoji'] ?? '🏆';
    final arenaName = arena['name'] ?? 'Current Arena';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Arena Emoji
          Text(
            emoji,
            style: TextStyle(fontSize: 72),
          ),
          const SizedBox(width: 20),

          // Right: Arena Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tier Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlack,
                  ),
                  child: Text(
                    'TIER $tier OF 5',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: AppTheme.primaryWhite,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Arena Name
                Text(
                  arenaName,
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlack,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section 4: Progress to Next Arena (or Max Tier)
  Widget _buildProgressSection(Map<String, dynamic> stats) {
    final nextArena = stats['nextArena'];

    if (nextArena == null) {
      // Max tier reached
      return _buildMaxTierCard();
    }

    final progress = stats['progressToNext'] ?? 0.0;
    final currentLP = stats['total'] ?? 0;
    final nextArenaMin = nextArena['min'] ?? 0;
    final remaining = nextArenaMin - currentLP;
    final nextArenaEmoji = nextArena['emoji'] ?? '🏆';
    final nextArenaName = nextArena['name'] ?? 'Next Arena';

    // Cap progress at 100% (defensive coding)
    final cappedProgress = progress.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: AppTheme.primaryWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next: $nextArenaName',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlack,
                ),
              ),
              Text(
                remaining < 10
                    ? '< 10 LP remaining'
                    : '${NumberFormatter.format(remaining)} LP remaining',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Visual Row
          Row(
            children: [
              // Progress Bar
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(0xFFE0E0E0),
                    border: Border.all(
                      color: AppTheme.primaryBlack,
                      width: 2,
                    ),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: cappedProgress,
                    child: Container(
                      color: AppTheme.primaryBlack,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Next Arena Emoji
              Text(
                nextArenaEmoji,
                style: TextStyle(fontSize: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Max Tier Card (shown when at tier 5)
  Widget _buildMaxTierCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: AppTheme.primaryWhite,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '👑',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            'Max Tier Reached!',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlack,
            ),
          ),
        ],
      ),
    );
  }
}
