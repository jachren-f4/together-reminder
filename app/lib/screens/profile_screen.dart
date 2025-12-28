import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../services/love_point_service.dart';
import '../services/couple_stats_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/number_formatter.dart';
import '../widgets/brand/brand_widget_factory.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storage = StorageService();
  final CoupleStatsService _coupleStatsService = CoupleStatsService();
  final AuthService _authService = AuthService();

  CoupleStats? _coupleStats;
  bool _isLoadingStats = true;

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  void initState() {
    super.initState();
    _loadCoupleStats();
  }

  Future<void> _loadCoupleStats() async {
    final stats = await _coupleStatsService.fetchStats();
    if (mounted) {
      setState(() {
        _coupleStats = stats;
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final stats = LovePointService.getStats();

    if (_isUs2) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Us2Theme.bgGradientStart, Us2Theme.bgGradientEnd],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildUs2Header(user, partner),
                  _buildUs2HeroStats(stats),
                  _buildUs2CurrentArena(stats),
                  _buildUs2ProgressSection(stats),
                  const SizedBox(height: 20),
                  _buildUs2TogetherForSection(),
                  const SizedBox(height: 20),
                  _buildUs2YourActivitySection(),
                  const SizedBox(height: 32),
                  _buildUs2AccountSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
              const SizedBox(height: 16),
              _buildTogetherForSection(),
              const SizedBox(height: 16),
              _buildYourActivitySection(),
              const SizedBox(height: 32),
              _buildAccountSection(),
              const SizedBox(height: 32),
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

  /// Section 5: Together For (Anniversary timer)
  Widget _buildTogetherForSection() {
    final anniversaryDate = _coupleStats?.anniversaryDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: anniversaryDate == null
          ? _buildSetAnniversaryPrompt()
          : _buildAnniversaryDisplay(anniversaryDate),
    );
  }

  /// Prompt to set anniversary date (State A)
  Widget _buildSetAnniversaryPrompt() {
    return InkWell(
      onTap: _showSetAnniversaryModal,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.favorite_outline,
              color: AppTheme.primaryWhite.withOpacity(0.7),
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Together for',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set up your anniversary date',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 14,
                      color: AppTheme.primaryWhite.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline,
              color: AppTheme.primaryWhite.withOpacity(0.7),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Display anniversary duration (State B)
  Widget _buildAnniversaryDisplay(DateTime anniversaryDate) {
    final duration = RelationshipDuration.fromAnniversary(anniversaryDate);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header row with title and edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Together for',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryWhite,
                ),
              ),
              IconButton(
                onPressed: _showEditAnniversaryModal,
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppTheme.primaryWhite.withOpacity(0.7),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Duration boxes
          Row(
            children: [
              Expanded(
                child: _buildDurationBox(
                  value: duration.years.toString(),
                  label: 'Years',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDurationBox(
                  value: duration.months.toString(),
                  label: 'Months',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDurationBox(
                  value: duration.days.toString(),
                  label: 'Days',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Single duration box (Years/Months/Days)
  Widget _buildDurationBox({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodyFont.copyWith(
              fontSize: 14,
              color: AppTheme.primaryWhite.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 6: Your Activity Stats
  Widget _buildYourActivitySection() {
    if (_isLoadingStats) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlack,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryWhite,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_coupleStats == null) {
      return const SizedBox.shrink();
    }

    final currentUser = _coupleStats!.currentUserStats;
    final partner = _coupleStats!.partnerStats;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Your Activity',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryWhite,
            ),
          ),
          const SizedBox(height: 20),
          // Column headers with icons
          Row(
            children: [
              const SizedBox(width: 40), // Space for avatar
              Expanded(child: _buildActivityHeader(Icons.check_circle_outline, 'Activities\ncompleted')),
              Expanded(child: _buildActivityHeader(Icons.local_fire_department_outlined, 'Current streak\ndays')),
              Expanded(child: _buildActivityHeader(Icons.emoji_events_outlined, 'Couple games\nwon')),
            ],
          ),
          const SizedBox(height: 12),
          // User row
          _buildActivityRow(
            initial: currentUser.initial,
            isCurrentUser: true,
            activitiesCompleted: currentUser.activitiesCompleted,
            streakDays: currentUser.currentStreakDays,
            gamesWon: currentUser.coupleGamesWon,
          ),
          const SizedBox(height: 8),
          // Partner row
          _buildActivityRow(
            initial: partner.initial,
            isCurrentUser: false,
            activitiesCompleted: partner.activitiesCompleted,
            streakDays: partner.currentStreakDays,
            gamesWon: partner.coupleGamesWon,
          ),
        ],
      ),
    );
  }

  /// Column header with grayscale icon
  Widget _buildActivityHeader(IconData icon, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryWhite.withOpacity(0.5),
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 11,
            color: AppTheme.primaryWhite.withOpacity(0.7),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  /// Single activity row for a user
  Widget _buildActivityRow({
    required String initial,
    required bool isCurrentUser,
    required int activitiesCompleted,
    required int streakDays,
    required int gamesWon,
  }) {
    // Colors: current user gets light pill, partner gets slightly darker shade
    final pillColor = isCurrentUser
        ? AppTheme.primaryWhite.withOpacity(0.9)
        : AppTheme.primaryWhite.withOpacity(0.5);
    final textColor = isCurrentUser
        ? AppTheme.primaryBlack
        : AppTheme.primaryBlack;

    return Row(
      children: [
        // Avatar circle
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: pillColor,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: pillColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Stats
        Expanded(
          child: _buildStatPill(
            value: activitiesCompleted.toString(),
            color: pillColor,
            textColor: textColor,
          ),
        ),
        Expanded(
          child: _buildStatPill(
            value: streakDays > 0 ? streakDays.toString() : '-',
            color: pillColor,
            textColor: textColor,
          ),
        ),
        Expanded(
          child: _buildStatPill(
            value: gamesWon.toString(),
            color: pillColor,
            textColor: textColor,
          ),
        ),
      ],
    );
  }

  /// Single stat pill
  Widget _buildStatPill({
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          value,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  /// Section 7: Account Section (Sign Out)
  Widget _buildAccountSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Account',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlack,
              ),
            ),
          ),
          InkWell(
            onTap: _showLogoutConfirmation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red[300]!, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: Colors.red[600],
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sign Out',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[600],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.red[400],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign Out',
          style: AppTheme.headlineFont.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out? This will clear all local data and you\'ll need to sign in again.',
          style: AppTheme.bodyFont.copyWith(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.bodyFont.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            child: Text(
              'Sign Out',
              style: AppTheme.bodyFont.copyWith(
                color: Colors.red[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Perform the actual logout
  Future<void> _performLogout() async {
    try {
      // Clear auth tokens (Supabase session)
      await _authService.signOut();

      // Clear all Hive local data (user, partner, quests, sessions, etc.)
      await _storage.clearAllData();

      // Navigate to onboarding and clear navigation stack
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Show error if something goes wrong
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show modal to set anniversary date
  void _showSetAnniversaryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnniversaryDatePicker(
        initialDate: null,
        onDateSelected: (date) async {
          Navigator.pop(context);
          final success = await _coupleStatsService.setAnniversaryDate(date);
          if (success && mounted) {
            _loadCoupleStats();
          }
        },
      ),
    );
  }

  /// Show modal to edit/delete anniversary date
  void _showEditAnniversaryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                'Anniversary',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const SizedBox(height: 24),
              // Edit option
              ListTile(
                leading: Icon(Icons.edit_outlined, color: AppTheme.primaryBlack),
                title: Text(
                  'Edit your anniversary',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 16,
                    color: AppTheme.primaryBlack,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDatePicker();
                },
              ),
              // Delete option
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red[600]),
                title: Text(
                  'Delete your anniversary',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 16,
                    color: Colors.red[600],
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await _coupleStatsService.deleteAnniversaryDate();
                  if (success && mounted) {
                    _loadCoupleStats();
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Show date picker to edit anniversary
  void _showEditDatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnniversaryDatePicker(
        initialDate: _coupleStats?.anniversaryDate,
        onDateSelected: (date) async {
          Navigator.pop(context);
          final success = await _coupleStatsService.setAnniversaryDate(date);
          if (success && mounted) {
            _loadCoupleStats();
          }
        },
      ),
    );
  }

  // ==================== Us 2.0 Sections ====================

  /// Us2 Header with gradient title
  Widget _buildUs2Header(user, partner) {
    String subtitle;
    if (user != null && partner != null) {
      final combined = '${user.name} & ${partner.name}';
      subtitle = combined.length > 30 ? '${combined.substring(0, 27)}...' : combined;
    } else {
      subtitle = 'Your Progress';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
            ).createShader(bounds),
            child: Text(
              'Progress',
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Us2Theme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Us2 Hero Stats Card
  Widget _buildUs2HeroStats(Map<String, dynamic> stats) {
    final lovePoints = stats['total'] ?? 0;
    final dayStreak = stats['streak'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                  ).createShader(bounds),
                  child: Text(
                    NumberFormatter.format(lovePoints),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'LOVE POINTS',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Us2Theme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 2,
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: Us2Theme.accentGradient,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                  ).createShader(bounds),
                  child: Text(
                    NumberFormatter.format(dayStreak),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DAY STREAK',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Us2Theme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Us2 Current Arena Card
  Widget _buildUs2CurrentArena(Map<String, dynamic> stats) {
    final arena = stats['currentArena'] ?? {'emoji': '🏆', 'name': 'Current Arena'};
    final tier = stats['tier'] ?? 1;
    final emoji = arena['emoji'] ?? '🏆';
    final arenaName = arena['name'] ?? 'Current Arena';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: Us2Theme.accentGradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'TIER $tier OF 5',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  arenaName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Us2 Progress Section
  Widget _buildUs2ProgressSection(Map<String, dynamic> stats) {
    final nextArena = stats['nextArena'];

    if (nextArena == null) {
      return _buildUs2MaxTierCard();
    }

    final progress = stats['progressToNext'] ?? 0.0;
    final currentLP = stats['total'] ?? 0;
    final nextArenaMin = nextArena['min'] ?? 0;
    final remaining = nextArenaMin - currentLP;
    final nextArenaEmoji = nextArena['emoji'] ?? '🏆';
    final nextArenaName = nextArena['name'] ?? 'Next Arena';
    final cappedProgress = progress.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next: $nextArenaName',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                ),
              ),
              Text(
                remaining < 10 ? '< 10 LP remaining' : '${NumberFormatter.format(remaining)} LP remaining',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Us2Theme.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Us2Theme.beige,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: cappedProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: Us2Theme.accentGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(nextArenaEmoji, style: const TextStyle(fontSize: 32)),
            ],
          ),
        ],
      ),
    );
  }

  /// Us2 Max Tier Card
  Widget _buildUs2MaxTierCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('👑', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Max Tier Reached!',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Us2 Together For Section
  Widget _buildUs2TogetherForSection() {
    final anniversaryDate = _coupleStats?.anniversaryDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: Us2Theme.accentGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.glowPink,
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: anniversaryDate == null
          ? _buildUs2SetAnniversaryPrompt()
          : _buildUs2AnniversaryDisplay(anniversaryDate),
    );
  }

  /// Us2 Prompt to set anniversary
  Widget _buildUs2SetAnniversaryPrompt() {
    return InkWell(
      onTap: _showSetAnniversaryModal,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.favorite_outline,
              color: Colors.white.withOpacity(0.8),
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Together for',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set up your anniversary date',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline,
              color: Colors.white.withOpacity(0.8),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Us2 Anniversary Display
  Widget _buildUs2AnniversaryDisplay(DateTime anniversaryDate) {
    final duration = RelationshipDuration.fromAnniversary(anniversaryDate);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Together for',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: _showEditAnniversaryModal,
                child: Text(
                  '✏️',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildUs2DurationBox(duration.years.toString(), 'Years')),
              const SizedBox(width: 12),
              Expanded(child: _buildUs2DurationBox(duration.months.toString(), 'Months')),
              const SizedBox(width: 12),
              Expanded(child: _buildUs2DurationBox(duration.days.toString(), 'Days')),
            ],
          ),
        ],
      ),
    );
  }

  /// Us2 Duration Box
  Widget _buildUs2DurationBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Us2 Your Activity Section
  Widget _buildUs2YourActivitySection() {
    if (_isLoadingStats) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_coupleStats == null) {
      return const SizedBox.shrink();
    }

    final currentUser = _coupleStats!.currentUserStats;
    final partner = _coupleStats!.partnerStats;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Activity',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 20),
          // Headers
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(child: _buildUs2ActivityHeader('✓', 'Activities\ncompleted')),
              Expanded(child: _buildUs2ActivityHeader('🔥', 'Current streak\ndays')),
              Expanded(child: _buildUs2ActivityHeader('🏆', 'Couple games\nwon')),
            ],
          ),
          const SizedBox(height: 16),
          // User row
          _buildUs2ActivityRow(
            initial: currentUser.initial,
            isCurrentUser: true,
            values: [
              currentUser.activitiesCompleted.toString(),
              currentUser.currentStreakDays > 0 ? currentUser.currentStreakDays.toString() : '-',
              currentUser.coupleGamesWon.toString(),
            ],
          ),
          const SizedBox(height: 12),
          // Partner row
          _buildUs2ActivityRow(
            initial: partner.initial,
            isCurrentUser: false,
            values: [
              partner.activitiesCompleted.toString(),
              partner.currentStreakDays > 0 ? partner.currentStreakDays.toString() : '-',
              partner.coupleGamesWon.toString(),
            ],
          ),
        ],
      ),
    );
  }

  /// Us2 Activity Header
  Widget _buildUs2ActivityHeader(String icon, String label) {
    return Column(
      children: [
        Text(icon, style: TextStyle(fontSize: 20, color: Colors.grey.withOpacity(0.5))),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 10,
            color: Us2Theme.textLight,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  /// Us2 Activity Row
  Widget _buildUs2ActivityRow({
    required String initial,
    required bool isCurrentUser,
    required List<String> values,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            gradient: isCurrentUser ? Us2Theme.accentGradient : null,
            color: isCurrentUser ? null : Us2Theme.beige,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isCurrentUser ? Colors.white : Us2Theme.textDark,
              ),
            ),
          ),
        ),
        ...values.map((value) => Expanded(
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: isCurrentUser ? Us2Theme.accentGradient : null,
                color: isCurrentUser ? null : Us2Theme.beige,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isCurrentUser ? Colors.white : Us2Theme.textDark,
                ),
              ),
            ),
          ),
        )),
      ],
    );
  }

  /// Us2 Account Section
  Widget _buildUs2AccountSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Account',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textDark,
              ),
            ),
          ),
          GestureDetector(
            onTap: _showLogoutConfirmation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFF6B6B), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('🚪', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
                  Text(
                    '›',
                    style: TextStyle(
                      fontSize: 18,
                      color: const Color(0xFFFFB3B3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet date picker for anniversary
class _AnniversaryDatePicker extends StatefulWidget {
  final DateTime? initialDate;
  final Function(DateTime) onDateSelected;

  const _AnniversaryDatePicker({
    this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<_AnniversaryDatePicker> createState() => _AnniversaryDatePickerState();
}

class _AnniversaryDatePickerState extends State<_AnniversaryDatePicker> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              widget.initialDate == null
                  ? 'When did you start dating?'
                  : 'Edit your anniversary',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will be used to calculate how long you\'ve been together',
              textAlign: TextAlign.center,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // Date picker
            SizedBox(
              height: 200,
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                onDateChanged: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            // Save button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onDateSelected(_selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlack,
                    foregroundColor: AppTheme.primaryWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
