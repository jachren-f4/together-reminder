import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/love_point_service.dart';
import '../services/couple_stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/number_formatter.dart';

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
