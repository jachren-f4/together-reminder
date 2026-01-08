import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../services/love_point_service.dart';
import '../services/couple_stats_service.dart';
import '../services/us_profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/number_formatter.dart';
import '../widgets/brand/brand_widget_factory.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../widgets/brand/us2/us2_tier_emoji.dart';
import '../widgets/brand/us2/us2_connection_bar.dart';
import '../models/magnet_collection.dart';
import '../services/magnet_service.dart';
import '../screens/magnet_collection_screen.dart';
import 'us_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storage = StorageService();
  final CoupleStatsService _coupleStatsService = CoupleStatsService();

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
                  _buildUs2ProfileLink(),
                  _buildUs2HeroStats(stats),
                  _buildUs2MagnetCollectionSection(),
                  const SizedBox(height: 20),
                  _buildUs2TogetherForSection(),
                  const SizedBox(height: 20),
                  _buildUs2YourActivitySection(),
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

  /// Us2 Profile Link Card - Navigate to Us Profile
  Widget _buildUs2ProfileLink() {
    final stats = UsProfileService().getCachedQuickStats();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const UsProfileScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              // Slide up from bottom with fade
              const begin = Offset(0.0, 0.15);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;
              var slideTween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var fadeTween = Tween(begin: 0.0, end: 1.0)
                  .chain(CurveTween(curve: curve));

              return SlideTransition(
                position: animation.drive(slideTween),
                child: FadeTransition(
                  opacity: animation.drive(fadeTween),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Us2Theme.gradientAccentStart.withOpacity(0.15),
              Us2Theme.gradientAccentEnd.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Us2Theme.primaryBrandPink.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Us2Theme.primaryBrandPink.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Us icon with glow and optional "New" badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: Us2Theme.accentGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Us2Theme.primaryBrandPink.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Us',
                          style: TextStyle(
                            fontFamily: 'Pacifico',
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // "New" badge when there's new content
                    if (stats?.hasNewContent == true)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B6B).withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'New',
                            style: GoogleFonts.nunito(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Us Profile',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Us2Theme.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your relationship insights & discoveries',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Us2Theme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Us2Theme.beige,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Us2Theme.primaryBrandPink,
                  ),
                ),
              ],
            ),
            // Stats preview row (only show if we have data)
            if (stats != null && stats.hasData) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildProfileStatItem(
                      '${stats.discoveryCount}',
                      'Discoveries',
                      const Color(0xFFFF6B6B),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: Us2Theme.beige,
                    ),
                    _buildProfileStatItem(
                      '${stats.dimensionCount}/6',
                      'Dimensions',
                      const Color(0xFF9B7ED9),
                    ),
                    if (stats.valueAlignmentPercent != null) ...[
                      Container(
                        width: 1,
                        height: 24,
                        color: Us2Theme.beige,
                      ),
                      _buildProfileStatItem(
                        '${stats.valueAlignmentPercent}%',
                        'Aligned',
                        const Color(0xFF4CAF50),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // Onboarding prompt for new users
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFE082),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Play quizzes together to unlock relationship insights!',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Us2Theme.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a single stat item for the profile card preview
  Widget _buildProfileStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            color: Us2Theme.textLight,
          ),
        ),
      ],
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

  /// Us2 Magnet Collection Section - matches mockup/magnet-collection/collection-view.html
  /// Profile Screen Section: Shows 6 magnets + "Collecting..." card
  Widget _buildUs2MagnetCollectionSection() {
    final collection = MagnetService().getCachedCollection();
    final unlockedCount = collection?.unlockedCount ?? 0;
    final nextMagnetId = collection?.nextMagnetId ?? 1;
    final nextMagnetName = MagnetCollection.getMagnetName(nextMagnetId);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Us2Theme.beige, width: 2),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.primaryBrandPink.withOpacity(0.1),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: "My Collection" + "View All →"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Collection',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: Us2Theme.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MagnetCollectionScreen()),
                ),
                child: Text(
                  'View All →',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.primaryBrandPink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row of 6 magnets (48x48px)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final magnetId = index + 1;
              final isUnlocked = magnetId <= unlockedCount;
              final isNext = magnetId == nextMagnetId;
              return _buildProfileMagnet(magnetId, isUnlocked, isNext);
            }),
          ),
          const SizedBox(height: 16),
          // "Collecting..." card
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MagnetCollectionScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Us2Theme.gradientAccentStart.withOpacity(0.1),
                    Us2Theme.gradientAccentEnd.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Us2Theme.beige, width: 2),
              ),
              child: Row(
                children: [
                  // Next magnet image (40x40)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        MagnetCollection.getMagnetAssetPath(nextMagnetId),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFFFD1C1),
                          child: Center(
                            child: Text(
                              Us2ConnectionBar.getMagnetEmoji(nextMagnetId),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COLLECTING...',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: Us2Theme.textLight,
                          ),
                        ),
                        Text(
                          nextMagnetName,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Us2Theme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Text(
                    '→',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.primaryBrandPink,
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

  /// Single profile magnet (48x48px) for the collection row
  Widget _buildProfileMagnet(int magnetId, bool isUnlocked, bool isNext) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isNext
            ? Border.all(color: Us2Theme.goldBorder, width: 2)
            : isUnlocked
                ? null
                : Border.all(
                    color: Us2Theme.goldMid,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: Us2Theme.goldBorder.withOpacity(0.3),
                  blurRadius: 12,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isUnlocked ? 8 : 6),
        child: isUnlocked
            ? Image.asset(
                MagnetCollection.getMagnetAssetPath(magnetId),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFFFD1C1),
                  child: Center(
                    child: Text(
                      Us2ConnectionBar.getMagnetEmoji(magnetId),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              )
            : ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: Opacity(
                  opacity: 0.4,
                  child: Image.asset(
                    MagnetCollection.getMagnetAssetPath(magnetId),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Us2Theme.beige,
                      child: Center(
                        child: Text(
                          Us2ConnectionBar.getMagnetEmoji(magnetId),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
