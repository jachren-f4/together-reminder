import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/leaderboard_service.dart';
import '../services/country_service.dart';
import '../theme/app_theme.dart';
import '../config/brand/brand_loader.dart';

class LeaderboardBottomSheet extends StatefulWidget {
  const LeaderboardBottomSheet({super.key});

  /// Show the leaderboard bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LeaderboardBottomSheet(),
    );
  }

  @override
  State<LeaderboardBottomSheet> createState() => _LeaderboardBottomSheetState();
}

enum LeaderboardView { global, country, tier }

class _LeaderboardBottomSheetState extends State<LeaderboardBottomSheet> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  final CountryService _countryService = CountryService();

  LeaderboardView _currentView = LeaderboardView.global;
  bool _isLoading = true;
  bool _isExpanded = false;
  LeaderboardData? _globalData;
  LeaderboardData? _countryData;
  LeaderboardData? _tierData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all three in parallel
      final results = await Future.wait([
        _leaderboardService.getGlobalLeaderboard(),
        _leaderboardService.getCountryLeaderboard(),
        _leaderboardService.getTierLeaderboard(),
      ]);

      if (mounted) {
        setState(() {
          _globalData = results[0];
          _countryData = results[1];
          _tierData = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load leaderboard';
          _isLoading = false;
        });
      }
    }
  }

  LeaderboardData? get _currentData {
    switch (_currentView) {
      case LeaderboardView.global:
        return _globalData;
      case LeaderboardView.country:
        return _countryData;
      case LeaderboardView.tier:
        return _tierData;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryWhite,
            border: Border(
              top: BorderSide(color: AppTheme.primaryBlack, width: 2),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              _buildHeader(),

              // Tab Toggle
              _buildTabToggle(),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _buildLeaderboardContent(scrollController),
              ),

              // Footer
              _buildFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Text(
            'LEADERBOARD',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              letterSpacing: 2,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ranked by Love Points',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabToggle() {
    // Build tier tab label with emoji + name
    String tierLabel = 'MY TIER';
    if (_tierData?.tierEmoji != null && _tierData?.tierName != null) {
      tierLabel = '${_tierData!.tierEmoji} ${_tierData!.tierName!.toUpperCase()}';
    } else if (_tierData?.tierEmoji != null) {
      tierLabel = '${_tierData!.tierEmoji} MY TIER';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.primaryBlack, width: 1),
          bottom: BorderSide(color: AppTheme.primaryBlack, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildTab('GLOBAL', view: LeaderboardView.global),
          Container(width: 1, height: 48, color: AppTheme.primaryBlack),
          _buildTab(
            _countryData?.countryCode != null
                ? '${_countryService.getFlagEmoji(_countryData!.countryCode!)} ${_countryData!.countryName ?? _countryData!.countryCode}'
                : 'MY COUNTRY',
            view: LeaderboardView.country,
          ),
          Container(width: 1, height: 48, color: AppTheme.primaryBlack),
          _buildTab(tierLabel, view: LeaderboardView.tier),
        ],
      ),
    );
  }

  Widget _buildTab(String label, {required LeaderboardView view}) {
    final isActive = _currentView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentView = view);
        },
        child: Container(
          height: 48,
          color: isActive ? AppTheme.primaryBlack : AppTheme.primaryWhite,
          child: Center(
            child: Text(
              label,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isActive ? AppTheme.primaryWhite : AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryBlack,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading rankings...',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😢', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryBlack),
              ),
              child: Text(
                'TRY AGAIN',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardContent(ScrollController scrollController) {
    final data = _currentData;

    if (data == null) {
      return _buildEmptyState();
    }

    // Check for empty country leaderboard
    if (_currentView == LeaderboardView.country && data.entries.isEmpty) {
      if (data.message != null) {
        return _buildNoCountryState(data.message!);
      }
      return _buildFirstInCountryState();
    }

    // Check for empty tier leaderboard
    if (_currentView == LeaderboardView.tier && data.entries.isEmpty) {
      return _buildFirstInTierState();
    }

    // Build section header based on view
    String sectionHeader;
    switch (_currentView) {
      case LeaderboardView.global:
        sectionHeader = 'TOP 5';
        break;
      case LeaderboardView.country:
        sectionHeader = 'TOP 5${data.countryName != null ? ' IN ${data.countryName!.toUpperCase()}' : ''}';
        break;
      case LeaderboardView.tier:
        sectionHeader = 'TOP 5${data.tierName != null ? ' IN ${data.tierName!.toUpperCase()}' : ''}';
        break;
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Top 5 section
        _buildSectionHeader(sectionHeader),
        ...data.top5.map((entry) => _buildLeaderboardRow(entry)),

        // User context (if not in top 5)
        if (!data.isUserInTop(5) && data.getUserContext() != null) ...[
          _buildSectionHeader('YOUR POSITION'),
          ...data.getUserContext()!.map((entry) => _buildLeaderboardRow(entry)),
        ],

        // Motivation (if outside top 50)
        if (data.userRank != null && data.userRank! > 50 && data.lpNeededForRank(50) != null) ...[
          _buildMotivationMessage(data.lpNeededForRank(50)!),
        ],

        // Expand button (if has more entries)
        if (!_isExpanded && data.entries.length > 5 && data.userRank != null && data.userRank! <= 50) ...[
          _buildExpandButton(data),
        ],

        // Expanded entries (6-50)
        if (_isExpanded) ...[
          _buildSectionHeader('FULL TOP ${data.entries.length}'),
          ...data.entries.where((e) => e.rank > 5 && e.rank <= 50).map((entry) => _buildLeaderboardRow(entry)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: BrandLoader().colors.surface,
      child: Text(
        title,
        style: AppTheme.bodyFont.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: AppTheme.textTertiary,
        ),
      ),
    );
  }

  Widget _buildLeaderboardRow(LeaderboardEntry entry) {
    final isHighlighted = entry.isCurrentUser;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: EdgeInsets.only(
          left: isHighlighted ? 16 : 20,
          right: 20,
          top: 12,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: isHighlighted ? BrandLoader().colors.surface : null,
          border: Border(
            left: isHighlighted
                ? BorderSide(color: AppTheme.primaryBlack, width: 4)
                : BorderSide.none,
            bottom: BorderSide(color: BrandLoader().colors.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  _getRankDisplay(entry.rank),
                  style: TextStyle(
                    fontSize: entry.rank <= 3 ? 20 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Initials
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    Text(
                      entry.initials,
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isHighlighted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        color: AppTheme.primaryBlack,
                        child: Text(
                          'YOU',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: AppTheme.primaryWhite,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // LP
            Text(
              '${_formatNumber(entry.totalLp)} LP',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRankDisplay(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k';
    }
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  Widget _buildMotivationMessage(int lpNeeded) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: BrandLoader().colors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          Text(
            'To reach top 50, you need',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+${_formatNumber(lpNeeded)} LP',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandButton(LeaderboardData data) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isExpanded = true);
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryBlack),
        ),
        child: Center(
          child: Text(
            'SHOW FULL TOP ${data.totalCouples > 50 ? 50 : data.totalCouples}',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No rankings yet',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete activities to earn Love Points',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCountryState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌍', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Country Not Set',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstInCountryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            "You're #1!",
            style: AppTheme.headlineFont.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'First couple in your country',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstInTierState() {
    final tierName = _tierData?.tierName ?? 'your tier';
    final tierEmoji = _tierData?.tierEmoji ?? '🏆';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(tierEmoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            "You're #1!",
            style: AppTheme.headlineFont.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'First couple in $tierName',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final data = _currentData;
    final updateTime = data?.updatedAt;

    // Build context-specific footer text
    String? contextText;
    if (data != null) {
      switch (_currentView) {
        case LeaderboardView.global:
          // No extra text for global
          break;
        case LeaderboardView.country:
          if (data.totalCouples > 0) {
            contextText = '${data.totalCouples} couples in ${data.countryName ?? 'your country'}';
          }
          break;
        case LeaderboardView.tier:
          if (data.totalInTier != null && data.totalInTier! > 0) {
            contextText = '${data.totalInTier} couples in ${data.tierName ?? 'your tier'}';
          }
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: BrandLoader().colors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          Text(
            updateTime != null
                ? 'Updated ${_getRelativeTime(updateTime)}'
                : 'Updating...',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 11,
              color: AppTheme.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (contextText != null) ...[
            const SizedBox(height: 4),
            Text(
              contextText,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
  }
}
