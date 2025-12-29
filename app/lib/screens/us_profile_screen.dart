import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/us_profile_service.dart';
import '../services/storage_service.dart';
import '../config/brand/us2_theme.dart';

/// Us Profile Screen
///
/// Displays relationship insights based on quiz answers.
/// Supports two modes:
/// - Day 1 Experience (variant-10): For new couples with 1 quiz
/// - Full Profile (variant-9): For established couples with more data
class UsProfileScreen extends StatefulWidget {
  const UsProfileScreen({super.key});

  @override
  State<UsProfileScreen> createState() => _UsProfileScreenState();
}

class _UsProfileScreenState extends State<UsProfileScreen> {
  final UsProfileService _profileService = UsProfileService();
  final StorageService _storage = StorageService();

  UsProfile? _profile;
  bool _isLoading = true;
  String? _error;

  // Colors from mockup
  static const Color _emmaColor = Color(0xFFFF6B6B);
  static const Color _jamesColor = Color(0xFF5B9BD5);
  static const Color _accentPurple = Color(0xFF9B7ED9);
  static const Color _accentTeal = Color(0xFF5BBFBA);
  static const Color _accentGold = Color(0xFFF4C55B);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _lockedBg = Color(0xFFF0EDE8);

  /// Lowercase the first character of a string (for discoveries text)
  String _lowercaseFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final profile = await _profileService.fetchProfile();

    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = _profile == null;
        _error = profile == null ? 'Failed to load profile' : null;
      });
    }
  }

  Future<void> _refreshProfile() async {
    final profile = await _profileService.recalculateProfile();
    if (mounted && profile != null) {
      setState(() => _profile = profile);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: _isLoading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: Us2Theme.primaryBrandPink,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _error!,
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Us2Theme.textMedium,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Us2Theme.primaryBrandPink,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final profile = _profile!;
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    // Determine display names
    final userName = profile.userRole == 'user1'
        ? (user?.name ?? 'You')
        : (partner?.name ?? 'Partner');
    final partnerName = profile.userRole == 'user1'
        ? (partner?.name ?? 'Partner')
        : (user?.name ?? 'You');

    return RefreshIndicator(
      onRefresh: _refreshProfile,
      color: Us2Theme.primaryBrandPink,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(profile),
            const SizedBox(height: 8),
            _buildInfoLink(),
            const SizedBox(height: 16),

            // Action Stats - always shown
            _buildActionStatsCard(profile, partnerName),
            const SizedBox(height: 20),

            // Day 1 or Full Profile content
            if (profile.isDay1) ...[
              _buildDay1Content(profile, userName, partnerName),
            ] else ...[
              _buildFullProfileContent(profile, userName, partnerName),
            ],

            const SizedBox(height: 20),
            _buildMethodologyHint(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UsProfile profile) {
    final subtitle = profile.isDay1
        ? 'Your journey together starts here'
        : 'Growing together, one action at a time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back button row
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: Us2Theme.textDark,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
        // Centered logo and tagline
        Center(
          child: Text(
            'Us',
            style: GoogleFonts.pacifico(
              fontSize: 32,
              color: Us2Theme.textDark,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            subtitle,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Us2Theme.textMedium,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoLink() {
    return Center(
      child: GestureDetector(
        onTap: () {
          // TODO: Navigate to methodology page
        },
        child: Text(
          'How we create these insights',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: Us2Theme.textLight,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Action Stats Card (variant-9/10)
  // ===========================================================================

  Widget _buildActionStatsCard(UsProfile profile, String partnerName) {
    final isDay1 = profile.isDay1;
    final stats = profile.actionStats;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Your Actions Together',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  color: Us2Theme.textMedium,
                ),
              ),
              const SizedBox(width: 8),
              _buildInfoButton('actions'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildActionStat(
                  stats.insightsActedOn,
                  'Insights\nActed On',
                  isZero: stats.insightsActedOn == 0,
                  goalText: isDay1 ? 'Your first one is below!' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionStat(
                  stats.conversationsHad,
                  'Conversations\nHad',
                  isZero: stats.conversationsHad == 0,
                  goalText: isDay1 ? 'Start with the prompt below' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWeeklyFocusSection(profile, partnerName),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Us2Theme.beige, width: 1),
              ),
            ),
            child: Text(
              isDay1
                  ? 'Your first quiz completed today!'
                  : 'Last updated: Today',
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: Us2Theme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionStat(int value, String label,
      {bool isZero = false, String? goalText}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isZero ? Us2Theme.textLight : Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 10,
              color: Us2Theme.textLight,
              height: 1.3,
            ),
          ),
          if (goalText != null) ...[
            const SizedBox(height: 6),
            Text(
              goalText,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: _accentPurple,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyFocusSection(UsProfile profile, String partnerName) {
    final focus = profile.weeklyFocus;
    final focusText = focus?.text ??
        'When $partnerName seems stressed, try saying "I\'m here when you\'re ready" instead of asking what\'s wrong.';
    final sourceText = focus?.source ?? 'Based on your stress processing difference';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK\'S FOCUS',
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            focusText,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
              ),
            ),
            child: Text(
              sourceText,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Day 1 Experience (variant-10)
  // ===========================================================================

  Widget _buildDay1Content(
      UsProfile profile, String userName, String partnerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First Discovery - Celebratory
        if (profile.discoveries.isNotEmpty) ...[
          _buildSectionTitle('Your First Discovery',
              showNewBadge: true, infoKey: 'discoveries'),
          _buildFirstDiscoveryCard(
              profile.discoveries.first, userName, partnerName),
          const SizedBox(height: 20),
        ],

        // First Conversation Starter
        if (profile.conversationStarters.isNotEmpty) ...[
          _buildSectionTitle('Start a Conversation', infoKey: 'conversation'),
          _buildConversationCard(profile.conversationStarters.first),
          const SizedBox(height: 20),
        ],

        // Locked Sections Grid
        _buildSectionTitle('Coming Soon'),
        _buildLockedGrid(profile),
        const SizedBox(height: 20),

        // What's Coming Roadmap
        _buildWhatsComingCard(profile),
      ],
    );
  }

  Widget _buildFirstDiscoveryCard(
      FramedDiscovery discovery, String userName, String partnerName) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF9E6), Color(0xFFFFF5F0)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _accentGold.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildDiscoveryItemWithAction(discovery, userName, partnerName),
            ],
          ),
        ),
        // Badge
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accentGold, const Color(0xFFF5D76E)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _accentGold.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'You learned something new!',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedGrid(UsProfile profile) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildLockedGridItem(
                icon: '🧭',
                title: 'How You Navigate',
                description: 'See how you each approach life',
                progress: 20,
                remaining: '2 more quizzes',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLockedGridItem(
                icon: '💎',
                title: 'Where You Align',
                description: 'Discover shared values',
                progress: 20,
                remaining: '2 more quizzes',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildLockedSection(
          icon: '👀',
          title: 'Through Each Other\'s Eyes',
          description: 'Play "You or Me" to see how your partner sees you',
          progress: 0,
          actionText: 'Play You or Me',
        ),
      ],
    );
  }

  Widget _buildLockedGridItem({
    required String icon,
    required String title,
    required String description,
    required double progress,
    required String remaining,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lockedBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD0C8BE),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 12,
              color: Us2Theme.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 10,
              color: Us2Theme.textLight,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: const Color(0xFFD0C8BE),
                    valueColor: const AlwaysStoppedAnimation(_accentPurple),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                remaining,
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _accentPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockedSection({
    required String icon,
    required String title,
    required String description,
    required double progress,
    String? actionText,
    String? infoKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _lockedBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD0C8BE),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Text(icon,
              style:
                  TextStyle(fontSize: 28, color: Colors.black.withOpacity(0.5))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  color: Us2Theme.textMedium,
                ),
              ),
              if (infoKey != null) ...[
                const SizedBox(width: 8),
                _buildInfoButton(infoKey),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Us2Theme.textLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: const Color(0xFFD0C8BE),
                    valueColor: const AlwaysStoppedAnimation(_accentPurple),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                actionText ?? '${(100 - progress).toInt()}% to unlock',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _accentPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsComingCard(UsProfile profile) {
    final upcomingItems = profile.upcomingInsights.isNotEmpty
        ? profile.upcomingInsights
        : _getDefaultUpcomingInsights();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Your Profile Will Grow',
            style: GoogleFonts.playfairDisplay(
              fontSize: 15,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 14),
          ...upcomingItems.map((item) => _buildComingItem(item)),
        ],
      ),
    );
  }

  List<UpcomingInsight> _getDefaultUpcomingInsights() {
    return [
      UpcomingInsight(
        id: 'stress',
        title: 'Stress Processing Style',
        unlockCondition: 'After 3 more questions',
        current: 1,
        required: 4,
      ),
      UpcomingInsight(
        id: 'planning',
        title: 'Planning Style',
        unlockCondition: 'After 3 more questions',
        current: 0,
        required: 3,
      ),
      UpcomingInsight(
        id: 'love_languages',
        title: 'Love Languages',
        unlockCondition: 'After 6 love language questions',
        current: 0,
        required: 6,
      ),
    ];
  }

  Widget _buildComingItem(UpcomingInsight item) {
    final icons = {
      'stress': '😤',
      'planning': '📅',
      'love_languages': '💕',
      'financial': '💰',
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Us2Theme.beige, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Us2Theme.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                icons[item.id] ?? '✨',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                ),
                Text(
                  item.unlockCondition,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    color: Us2Theme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item.current}/${item.required}',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _accentPurple,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Full Profile (variant-9)
  // ===========================================================================

  Widget _buildFullProfileContent(
      UsProfile profile, String userName, String partnerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dimensions
        if (profile.progressiveReveal.showDimensions &&
            profile.dimensions.any((d) => d.isUnlocked)) ...[
          _buildDimensionsSection(profile, userName, partnerName),
          const SizedBox(height: 20),
        ],

        // Discoveries with Try This actions
        if (profile.discoveries.isNotEmpty) ...[
          _buildSectionTitle('Recent Discoveries', infoKey: 'discoveries'),
          _buildDiscoveriesCard(profile, userName, partnerName),
          const SizedBox(height: 20),
        ],

        // Values Alignment
        if (profile.values.isNotEmpty) ...[
          _buildValuesSection(profile),
          const SizedBox(height: 20),
        ],

        // Locked Love Languages
        if (!profile.progressiveReveal.showLoveLanguages)
          _buildLockedSection(
            icon: '💕',
            title: 'Love Languages',
            description: 'Discover how you each give and receive love',
            progress: 50,
            actionText: '3 more questions to unlock',
            infoKey: 'love_languages',
          ),

        const SizedBox(height: 20),

        // Partner Perception
        if (profile.partnerPerceptions.isNotEmpty) ...[
          _buildPartnerPerceptionSection(profile, userName, partnerName),
          const SizedBox(height: 20),
        ],

        // Conversation Starters
        if (profile.conversationStarters.isNotEmpty) ...[
          _buildSectionTitle('Start a Conversation', infoKey: 'conversation'),
          _buildConversationStartersCard(profile),
        ],
      ],
    );
  }

  Widget _buildDimensionsSection(
      UsProfile profile, String userName, String partnerName) {
    final unlockedDims = profile.dimensions.where((d) => d.isUnlocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'How You Navigate Together',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textDark,
              ),
            ),
            const SizedBox(width: 8),
            _buildInfoButton('dimensions'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Based on ${profile.stats.questionsExplored} questions',
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _accentTeal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'The 4 dimensions that matter most for daily life',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: Us2Theme.textLight,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ...unlockedDims
                  .take(4)
                  .map((dim) => _buildDimensionRow(dim, userName, partnerName)),
              const SizedBox(height: 14),
              _buildDimensionLegend(userName, partnerName),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionRow(
      FramedDimension dim, String userName, String partnerName) {
    final user1Percent = ((dim.user1Position + 1) / 2 * 100).clamp(5.0, 95.0);
    final user2Percent = ((dim.user2Position + 1) / 2 * 100).clamp(5.0, 95.0);
    final isLowConfidence = dim.dataPoints < 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Opacity(
        opacity: isLowConfidence ? 0.7 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      dim.label,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.textDark,
                      ),
                    ),
                    if (dim.similarity == 'different') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _emmaColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Key',
                          style: GoogleFonts.nunito(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: _emmaColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  isLowConfidence
                      ? '${dim.dataPoints} questions - Early reading'
                      : '${dim.dataPoints} questions',
                  style: GoogleFonts.nunito(
                    fontSize: 9,
                    color: Us2Theme.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dim.user1Label,
                  style: GoogleFonts.nunito(
                    fontSize: 9,
                    color: Us2Theme.textLight,
                  ),
                ),
                Text(
                  dim.user2Label,
                  style: GoogleFonts.nunito(
                    fontSize: 9,
                    color: Us2Theme.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 22,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isLowConfidence
                            ? null
                            : LinearGradient(
                                colors: [
                                  Us2Theme.beige,
                                  Us2Theme.cream,
                                  Us2Theme.beige,
                                ],
                              ),
                        color: isLowConfidence ? Us2Theme.beige : null,
                        borderRadius: BorderRadius.circular(4),
                        border: isLowConfidence
                            ? Border.all(
                                color: const Color(0xFFCCCCCC),
                                style: BorderStyle.solid,
                              )
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment(user1Percent / 50 - 1, 0),
                      child: _buildMarker(
                          userName[0], _emmaColor, isLowConfidence),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment(user2Percent / 50 - 1, 0),
                      child: _buildMarker(
                          partnerName[0], _jamesColor, isLowConfidence),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Us2Theme.cream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: isLowConfidence
                  ? Text(
                      'More questions will refine this',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Us2Theme.textLight,
                      ),
                    )
                  : RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: Us2Theme.textMedium,
                        ),
                        children: [
                          TextSpan(
                            text: userName,
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: _emmaColor),
                          ),
                          TextSpan(text: ' ${_lowercaseFirst(dim.user1Description)} • '),
                          TextSpan(
                            text: partnerName,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _jamesColor),
                          ),
                          TextSpan(text: ' ${_lowercaseFirst(dim.user2Description)}'),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarker(String initial, Color color, bool isLowConfidence) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isLowConfidence
            ? Border.all(color: Colors.white, width: 2, style: BorderStyle.solid)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: isLowConfidence ? 0.6 : 1.0,
        child: Center(
          child: Text(
            initial.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDimensionLegend(String userName, String partnerName) {
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Us2Theme.beige, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(userName, _emmaColor),
          const SizedBox(width: 20),
          _buildLegendItem(partnerName, _jamesColor),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String name, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: Us2Theme.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveriesCard(
      UsProfile profile, String userName, String partnerName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF9E6), Color(0xFFFFF5F0)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _accentGold.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: profile.discoveries
            .take(3)
            .map((d) => _buildDiscoveryItemWithAction(d, userName, partnerName))
            .toList(),
      ),
    );
  }

  Widget _buildDiscoveryItemWithAction(
      FramedDiscovery discovery, String userName, String partnerName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Us2Theme.textDark,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.primaryBrandPink,
                  ),
                ),
                TextSpan(text: ' ${_lowercaseFirst(discovery.user1Answer)} • '),
                TextSpan(
                  text: partnerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.primaryBrandPink,
                  ),
                ),
                TextSpan(text: ' ${_lowercaseFirst(discovery.user2Answer)}'),
              ],
            ),
          ),
          if (discovery.tryThisAction != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _emmaColor.withOpacity(0.15),
                    const Color(0xFFFF9F43).withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: _emmaColor, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRY THIS',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _emmaColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    discovery.tryThisAction!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textDark,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildActionButton('I tried it!', _accentGreen, true),
                      const SizedBox(width: 8),
                      _buildActionButton('Save for later', Us2Theme.beige, false),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, bool isPrimary) {
    return GestureDetector(
      onTap: () {
        // TODO: Track action
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : Us2Theme.textMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildValuesSection(UsProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Where You Align',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textDark,
              ),
            ),
            const SizedBox(width: 8),
            _buildInfoButton('values'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${profile.values.fold(0, (sum, v) => sum + v.questions)} questions',
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _accentGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: profile.values.map((v) => _buildValueRow(v)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildValueRow(ValueAlignment value) {
    final statusColors = {
      'aligned': _accentTeal,
      'exploring': _accentPurple,
      'important': _emmaColor,
    };
    final statusLabels = {
      'aligned': 'Aligned',
      'exploring': 'Exploring',
      'important': 'Explore Together',
    };

    final color = statusColors[value.status] ?? _accentPurple;
    final label = statusLabels[value.status] ?? 'Exploring';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: value.isPriority ? _emmaColor.withOpacity(0.03) : null,
        border: Border(
          bottom: BorderSide(color: Us2Theme.beige, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    value.name,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textDark,
                    ),
                  ),
                  if (value.isPriority) ...[
                    const SizedBox(width: 6),
                    const Text('⭐', style: TextStyle(fontSize: 12)),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.alignment / 100,
              backgroundColor: Us2Theme.beige,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.insight,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Us2Theme.textMedium,
              height: 1.4,
            ),
          ),
          Text(
            value.isPriority
                ? '${value.questions} questions - High impact topic'
                : '${value.questions} questions',
            style: GoogleFonts.nunito(
              fontSize: 9,
              color: Us2Theme.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerPerceptionSection(
      UsProfile profile, String userName, String partnerName) {
    final userPerception = profile.partnerPerceptions.firstWhere(
      (p) => p.userId == profile.userRole,
      orElse: () => FramedPerception(userId: '', traits: [], frame: ''),
    );

    if (userPerception.traits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Through $partnerName\'s Eyes', infoKey: 'perception'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14,
                    color: Us2Theme.textDark,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Based on how '),
                    TextSpan(
                      text: partnerName,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: _jamesColor,
                      ),
                    ),
                    const TextSpan(text: ' answered "You or Me"'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Positive traits $partnerName sees in you',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Us2Theme.textLight,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: userPerception.traits.map((trait) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _jamesColor.withOpacity(0.1),
                          _jamesColor.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: _jamesColor.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      trait,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Us2Theme.textDark,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversationStartersCard(UsProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: profile.conversationStarters
            .take(3)
            .map((s) => _buildConversationItem(s))
            .toList(),
      ),
    );
  }

  Widget _buildConversationCard(ConversationStarter starter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildConversationItem(starter),
    );
  }

  Widget _buildConversationItem(ConversationStarter starter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            starter.triggerType.toUpperCase().replaceAll('_', ' '),
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _accentPurple,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            starter.promptText,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Us2Theme.textDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            starter.contextText,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: Us2Theme.textLight,
              height: 1.4,
            ),
          ),
          if (starter.id != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildConvoButton(
                  'We discussed this',
                  isPrimary: true,
                  onTap: () => _onStarterDiscussed(starter.id!),
                ),
                const SizedBox(width: 8),
                _buildConvoButton(
                  'Later',
                  isPrimary: false,
                  onTap: () => _onStarterDismissed(starter.id!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConvoButton(String text,
      {required bool isPrimary, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                )
              : null,
          color: isPrimary ? null : Us2Theme.beige,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : Us2Theme.textMedium,
          ),
        ),
      ),
    );
  }

  Future<void> _onStarterDiscussed(String starterId) async {
    await _profileService.markStarterDiscussed(starterId);
    await _loadProfile();
  }

  Future<void> _onStarterDismissed(String starterId) async {
    await _profileService.dismissStarter(starterId);
    await _loadProfile();
  }

  // ===========================================================================
  // Info Modal System
  // ===========================================================================

  /// Info content for each section
  static const Map<String, _InfoModalContent> _infoContent = {
    'actions': _InfoModalContent(
      icon: '🎯',
      title: 'Actions Together',
      subtitle: 'Turn insights into real connection',
      description:
          'Knowledge is great, but action is where relationships grow. Track your progress here!',
      items: [
        _InfoItem(
          icon: '💡',
          title: 'Insights Acted On',
          text:
              'Tried a suggestion from your discoveries or conversation starters? Count it!',
        ),
        _InfoItem(
          icon: '💬',
          title: 'Conversations Had',
          text:
              'Had a meaningful talk using our prompts? That\'s connection in action.',
        ),
      ],
      highlightIcon: '📈',
      highlightText: 'Aim for 2+ actions per week to build your connection habit!',
    ),
    'dimensions': _InfoModalContent(
      icon: '📊',
      title: 'Dimensions',
      subtitle: 'Your relationship spectrums',
      description:
          'Dimensions show where each of you naturally land on key relationship spectrums.',
      items: [
        _InfoItem(
          icon: '🎚️',
          title: 'Spectrum positions',
          text:
              'Your dot shows your tendency based on quiz answers. Neither end is better!',
        ),
        _InfoItem(
          icon: '🔄',
          title: 'Complementary pairs',
          text:
              'Being on opposite ends often means you balance each other out.',
        ),
        _InfoItem(
          icon: '📝',
          title: 'More accuracy',
          text: 'Each quiz adds data points, making your readings more precise.',
        ),
      ],
      highlightIcon: '🔓',
      highlightText:
          'New dimensions unlock as you complete more quizzes together.',
    ),
    'discoveries': _InfoModalContent(
      icon: '🔍',
      title: 'Discoveries',
      subtitle: 'Your different perspectives',
      description:
          'Discoveries highlight where you answered differently - these are opportunities, not problems!',
      items: [
        _InfoItem(
          icon: '🌟',
          title: 'Different ≠ Wrong',
          text: 'Your unique perspectives make your relationship richer.',
        ),
        _InfoItem(
          icon: '💭',
          title: 'Try This actions',
          text:
              'Each discovery has a suggested action to help you explore it together.',
        ),
        _InfoItem(
          icon: '❤️',
          title: 'Build empathy',
          text:
              'Understanding why they see it differently deepens your bond.',
        ),
      ],
      highlightIcon: '💡',
      highlightText:
          'Pick one discovery per week to explore. Quality over quantity!',
    ),
    'values': _InfoModalContent(
      icon: '💎',
      title: 'Your Shared Values',
      subtitle: 'What matters most to both of you',
      description:
          'Values show what matters most to both of you. High alignment on core values predicts relationship satisfaction!',
      items: [
        _InfoItem(
          icon: '📊',
          title: 'Alignment %',
          text: 'Shows how often you answered similarly on value questions.',
        ),
        _InfoItem(
          icon: '⭐',
          title: 'Priority values',
          text: 'Marked when they come up frequently in your answers.',
        ),
        _InfoItem(
          icon: '🌱',
          title: 'Growing together',
          text: 'Shared values create a strong foundation.',
        ),
      ],
      highlightIcon: '💝',
      highlightText:
          'Celebrate your shared values - they\'re your relationship superpower!',
    ),
    'perception': _InfoModalContent(
      icon: '👀',
      title: 'Partner Perception',
      subtitle: 'How they see you',
      description:
          'Based on "You or Me" game answers, this shows the positive traits your partner associates with you.',
      items: [
        _InfoItem(
          icon: '🎮',
          title: 'From "You or Me"',
          text:
              'When your partner picks "You" for a positive trait, it appears here.',
        ),
        _InfoItem(
          icon: '💕',
          title: 'What they admire',
          text: 'These are the qualities your partner notices and appreciates.',
        ),
        _InfoItem(
          icon: '🔄',
          title: 'Keeps growing',
          text: 'Play more rounds to discover more about each other!',
        ),
      ],
      highlightIcon: '✨',
      highlightText:
          'Knowing how your partner sees you can boost confidence and connection!',
    ),
    'conversation': _InfoModalContent(
      icon: '💬',
      title: 'Conversation Starters',
      subtitle: 'Meaningful prompts for you',
      description:
          'These prompts are personalized based on your discoveries and dimensions to spark deeper conversations.',
      items: [
        _InfoItem(
          icon: '🎯',
          title: 'Personalized',
          text:
              'Each prompt is based on something specific from your quizzes.',
        ),
        _InfoItem(
          icon: '⏰',
          title: 'Quality time',
          text:
              'Pick a calm moment to discuss - no pressure to solve anything.',
        ),
        _InfoItem(
          icon: '📝',
          title: 'Track it',
          text: 'Mark "We discussed this" to track your connection habit.',
        ),
      ],
      highlightIcon: '💑',
      highlightText:
          'Couples who have one quality conversation per week feel more connected!',
    ),
    'weekly_focus': _InfoModalContent(
      icon: '🎯',
      title: 'Weekly Focus',
      subtitle: 'Your personalized tip',
      description:
          'Each week, we highlight one actionable tip based on your biggest difference or opportunity.',
      items: [
        _InfoItem(
          icon: '📊',
          title: 'Based on data',
          text: 'We analyze your quiz answers to find the most relevant advice.',
        ),
        _InfoItem(
          icon: '🔄',
          title: 'Changes weekly',
          text:
              'New focus each week keeps your relationship growing.',
        ),
        _InfoItem(
          icon: '✅',
          title: 'Small steps',
          text: 'Focus on one thing at a time for lasting change.',
        ),
      ],
      highlightIcon: '💪',
      highlightText:
          'Practicing one insight consistently beats trying everything at once!',
    ),
    'love_languages': _InfoModalContent(
      icon: '💕',
      title: 'Love Languages',
      subtitle: 'How you give & receive love',
      description:
          'Based on Dr. Gary Chapman\'s framework, your love language is how you naturally express and feel love.',
      items: [
        _InfoItem(
          icon: '💬',
          title: 'Words of Affirmation',
          text: 'Verbal compliments and encouragement.',
        ),
        _InfoItem(
          icon: '⏰',
          title: 'Quality Time',
          text: 'Undivided attention and presence.',
        ),
        _InfoItem(
          icon: '🎁',
          title: 'Gifts & Acts',
          text: 'Thoughtful presents or helpful actions.',
        ),
        _InfoItem(
          icon: '🤗',
          title: 'Physical Touch',
          text: 'Hugs, holding hands, physical closeness.',
        ),
      ],
      highlightIcon: '💝',
      highlightText:
          'Speaking your partner\'s language makes your love land more effectively!',
    ),
  };

  void _showInfoModal(String sectionKey) {
    final content = _infoContent[sectionKey];
    if (content == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gradient header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Close button
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Column(
                            children: [
                              Text(
                                content.icon,
                                style: const TextStyle(fontSize: 40),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                content.title,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                content.subtitle,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              content.description,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: Us2Theme.textMedium,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // List items
                            ...content.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.icon,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              color: Us2Theme.textDark,
                                              height: 1.5,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: '${item.title} - ',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                              TextSpan(text: item.text),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            // Highlight box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Us2Theme.cream,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    content.highlightIcon,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      content.highlightText,
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: Us2Theme.textDark,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Footer button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Us2Theme.cream,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Got it!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Us2Theme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoButton(String sectionKey) {
    return GestureDetector(
      onTap: () => _showInfoModal(sectionKey),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '?',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Common Widgets
  // ===========================================================================

  Widget _buildSectionTitle(String title,
      {bool showNewBadge = false, String? infoKey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          if (showNewBadge) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'New!',
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ] else if (infoKey != null) ...[
            const SizedBox(width: 8),
            _buildInfoButton(infoKey),
          ],
        ],
      ),
    );
  }

  Widget _buildMethodologyHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: Us2Theme.textLight,
            height: 1.5,
          ),
          children: [
            const TextSpan(
              text:
                  'These patterns are based on your quiz answers and inspired by relationship research. They\'re meant to spark conversation, not define you. ',
            ),
            TextSpan(
              text: 'Learn more',
              style: TextStyle(
                color: _accentPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class for info modal content
class _InfoModalContent {
  final String icon;
  final String title;
  final String subtitle;
  final String description;
  final List<_InfoItem> items;
  final String highlightIcon;
  final String highlightText;

  const _InfoModalContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.items,
    required this.highlightIcon,
    required this.highlightText,
  });
}

/// Data class for a single info list item
class _InfoItem {
  final String icon;
  final String title;
  final String text;

  const _InfoItem({
    required this.icon,
    required this.title,
    required this.text,
  });
}
