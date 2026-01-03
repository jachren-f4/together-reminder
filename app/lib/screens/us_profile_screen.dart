import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Friction/repair colors
  static const Color _frictionBg = Color(0xFFFFF0ED);
  static const Color _frictionBorder = Color(0xFFFFD4CC);

  // Track which dimension repair sections are expanded
  final Set<String> _expandedRepairDimensions = {};

  // Discovery filter state
  String _selectedDiscoveryFilter = 'All';
  static const List<String> _discoveryFilters = [
    'All',
    'Lifestyle',
    'Values',
    'Communication',
    'Future',
    'Family',
    'Daily Life',
  ];

  // Repair script data for each dimension
  static const Map<String, Map<String, dynamic>> _repairScripts = {
    'stress_processing': {
      'recognition': 'One of you wants to talk through stress while the other needs quiet time to process first.',
      'leftScript': 'I need some quiet time to process, but I promise we\'ll talk about this. Can we reconnect in an hour?',
      'rightScript': 'I know you need space right now. I\'m here when you\'re ready. No pressure.',
      'tip': 'Create a signal (like a specific phrase) that means "I need processing time" without having to explain in the moment.',
    },
    'conflict_approach': {
      'recognition': 'One of you wants to talk about a disagreement right away while the other needs time to calm down first.',
      'leftScript': 'I need some time to collect my thoughts so I can be fully present. I\'ll come find you in 20 minutes.',
      'rightScript': 'I want to work this out together. Would 20 minutes be enough time for you to feel ready to talk?',
      'tip': 'Agree on a "pause phrase" in advance that either can use to request time without it feeling like rejection.',
    },
    'social_energy': {
      'recognition': 'One of you is energized by social events while the other feels drained and needs recovery time.',
      'leftScript': 'I loved the party, but I\'m going to need some quiet time tomorrow to recharge. Can we plan a low-key day?',
      'rightScript': 'I know that party was a lot for you. Thanks for coming with me. Let\'s have a relaxed evening at home.',
      'tip': 'Set expectations before events: agree on arrival/departure times so both partners feel heard.',
    },
    'planning_style': {
      'recognition': 'One of you prefers spontaneity while the other feels more comfortable with plans and structure.',
      'leftScript': 'I\'m feeling a bit anxious without a plan. Could we at least decide on a rough outline?',
      'rightScript': 'I\'d love to leave some room for spontaneity. What if we plan the mornings but keep afternoons flexible?',
      'tip': 'Try "planned spontaneity" - schedule blocks of unstructured time so both styles are honored.',
    },
    'support_style': {
      'recognition': 'One of you offers solutions when stressed while the other just wants to be heard and validated.',
      'leftScript': 'Right now I just need to vent. Can you listen without trying to fix it? Solutions can come later.',
      'rightScript': 'That sounds really hard. I\'m here for you. Do you want me to just listen, or would suggestions help?',
      'tip': 'Use a simple check-in: "Are you venting or problem-solving?" to clarify what kind of support is needed.',
    },
    'space_needs': {
      'recognition': 'One of you craves togetherness while the other needs more alone time to feel balanced.',
      'leftScript': 'I love spending time with you. I also need some solo time to recharge - it\'s not about us.',
      'rightScript': 'I miss you when we\'re apart. Can we schedule some quality time together this week?',
      'tip': 'Create a shared calendar that includes both "us time" and "me time" so needs are visible and respected.',
    },
  };

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

      // Mark profile as viewed when successfully loaded
      if (profile != null) {
        _profileService.markProfileViewed();
      }
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
                fontSize: 11,
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
              fontSize: 11,
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
          const SizedBox(height: 20),
        ],

        // Growth Milestone Timeline
        _buildGrowthMilestoneSection(profile),
      ],
    );
  }

  /// Build the growth milestone timeline section
  Widget _buildGrowthMilestoneSection(UsProfile profile) {
    // Calculate milestones based on profile data
    final milestones = _calculateMilestones(profile);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _emmaColor.withOpacity(0.08),
            const Color(0xFFFF9F43).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('📈', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Your Journey So Far',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Us2Theme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Milestone items
          ...milestones.map((m) => _buildMilestoneItem(
                m['text'] as String,
                m['date'] as String,
                m['completed'] as bool,
              )),
        ],
      ),
    );
  }

  /// Calculate milestones based on profile stats
  List<Map<String, dynamic>> _calculateMilestones(UsProfile profile) {
    final milestones = <Map<String, dynamic>>[];
    final unlockedDims =
        profile.dimensions.where((d) => d.isUnlocked).length;
    final totalQuizzes = profile.stats.questionsExplored;

    // First quiz milestone (always completed if they have a profile)
    milestones.add({
      'text': 'First quiz completed together',
      'date': 'Day 1',
      'completed': true,
    });

    // Dimension unlock milestones
    if (unlockedDims >= 2) {
      milestones.add({
        'text': 'Unlocked 2 dimensions',
        'date': 'Week 1',
        'completed': true,
      });
    }

    if (unlockedDims >= 4) {
      milestones.add({
        'text': 'Unlocked 4 dimensions',
        'date': 'Week 2',
        'completed': true,
      });
    }

    // Discovery milestone
    if (profile.discoveries.length >= 5) {
      milestones.add({
        'text': '5 discoveries found',
        'date': 'Week 2',
        'completed': true,
      });
    }

    // Quiz count milestones
    if (totalQuizzes >= 10) {
      milestones.add({
        'text': '10 questions explored',
        'date': 'Week 1',
        'completed': true,
      });
    }

    if (totalQuizzes >= 25) {
      milestones.add({
        'text': '25 questions explored',
        'date': 'Week 3',
        'completed': true,
      });
    }

    // Pending milestones (not yet achieved)
    if (unlockedDims < 6) {
      milestones.add({
        'text': 'All 6 dimensions unlocked',
        'date': 'Soon',
        'completed': false,
      });
    }

    if (totalQuizzes < 50) {
      milestones.add({
        'text': '50 questions milestone',
        'date': 'Keep going!',
        'completed': false,
      });
    }

    return milestones;
  }

  /// Build a single milestone item
  Widget _buildMilestoneItem(String text, String date, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Milestone dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: completed ? _accentGreen : Colors.transparent,
              shape: BoxShape.circle,
              border: completed
                  ? null
                  : Border.all(
                      color: Us2Theme.textLight,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Milestone text
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: completed ? Us2Theme.textDark : Us2Theme.textLight,
                fontWeight: completed ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          // Date
          Text(
            date,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: Us2Theme.textLight,
            ),
          ),
        ],
      ),
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
                  fontSize: 11,
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
                    if (dim.similarity != 'aligned') ...[
                      const SizedBox(width: 6),
                      _buildSimilarityBadge(dim.similarity),
                    ],
                  ],
                ),
                Text(
                  isLowConfidence
                      ? '${dim.dataPoints} questions - Early reading'
                      : '${dim.dataPoints} questions',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
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
                    fontSize: 11,
                    color: Us2Theme.textLight,
                  ),
                ),
                Text(
                  dim.user2Label,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
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
            // Repair script section (only for 'different' dimensions with enough data)
            if (dim.similarity == 'different' &&
                !isLowConfidence &&
                _repairScripts.containsKey(dim.id))
              _buildRepairSection(dim, userName, partnerName),
          ],
        ),
      ),
    );
  }

  /// Build the expandable repair script section for a dimension
  Widget _buildRepairSection(
      FramedDimension dim, String userName, String partnerName) {
    final isExpanded = _expandedRepairDimensions.contains(dim.id);
    final scripts = _repairScripts[dim.id]!;

    // Determine which partner is on which pole based on their positions
    final user1IsLeft = dim.user1Position < dim.user2Position;
    final leftPartner = user1IsLeft ? userName : partnerName;
    final rightPartner = user1IsLeft ? partnerName : userName;
    final leftColor = user1IsLeft ? _emmaColor : _jamesColor;
    final rightColor = user1IsLeft ? _jamesColor : _emmaColor;

    return Column(
      children: [
        const SizedBox(height: 10),
        // Friction trigger button
        GestureDetector(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedRepairDimensions.remove(dim.id);
              } else {
                _expandedRepairDimensions.add(dim.id);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isExpanded ? _frictionBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _frictionBorder,
                style: BorderStyle.solid,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Text('🔧', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'When this causes friction...',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textMedium,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '▾',
                    style: TextStyle(
                      fontSize: 12,
                      color: Us2Theme.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Expandable repair content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _frictionBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _frictionBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recognition section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You might notice tension when...',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Us2Theme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        scripts['recognition'] as String,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Us2Theme.textDark,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Scripts section header
                Row(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Words that can help:',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.textMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Left pole partner script
                _buildScriptCard(
                  'For $leftPartner:',
                  scripts['leftScript'] as String,
                  leftColor,
                ),
                const SizedBox(height: 8),
                // Right pole partner script
                _buildScriptCard(
                  'For $rightPartner:',
                  scripts['rightScript'] as String,
                  rightColor,
                ),
                const SizedBox(height: 12),
                // De-escalation tip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF4E6C8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pro Tip',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB8860B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scripts['tip'] as String,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: Us2Theme.textDark,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  /// Build a script card for a partner
  Widget _buildScriptCard(String label, String script, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"$script"',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Us2Theme.textDark,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Build similarity badge with colors matching mockup
  Widget _buildSimilarityBadge(String similarity) {
    // Colors from mockup CSS
    Color bgColor;
    Color textColor;
    String label;

    switch (similarity) {
      case 'different':
        bgColor = const Color(0xFFFFEBEE); // Light red
        textColor = const Color(0xFFE53935); // Dark red
        label = 'Different';
        break;
      case 'similar':
        bgColor = const Color(0xFFE8F5E9); // Light green
        textColor = const Color(0xFF43A047); // Dark green
        label = 'Similar';
        break;
      case 'complementary':
        bgColor = const Color(0xFFE3F2FD); // Light blue
        textColor = const Color(0xFF1976D2); // Dark blue
        label = 'Complementary';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
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
    // Filter discoveries based on selected category
    final filteredDiscoveries = _selectedDiscoveryFilter == 'All'
        ? profile.discoveries
        : profile.discoveries
            .where((d) =>
                d.category?.toLowerCase() ==
                _selectedDiscoveryFilter.toLowerCase().replaceAll(' ', '_'))
            .toList();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter tabs
          _buildDiscoveryFilterTabs(profile.discoveries),
          const SizedBox(height: 14),
          // Filtered discoveries list
          if (filteredDiscoveries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No discoveries in this category yet',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Us2Theme.textLight,
                  ),
                ),
              ),
            )
          else
            ...filteredDiscoveries
                .take(5)
                .map((d) =>
                    _buildDiscoveryItemWithAction(d, userName, partnerName)),
        ],
      ),
    );
  }

  /// Build the horizontal scrollable filter tabs for discoveries
  Widget _buildDiscoveryFilterTabs(List<FramedDiscovery> discoveries) {
    // Get available categories from actual discoveries
    final availableCategories = <String>{'All'};
    for (final d in discoveries) {
      if (d.category != null && d.category!.isNotEmpty) {
        // Convert snake_case to Title Case
        final formatted = d.category!
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
        availableCategories.add(formatted);
      }
    }

    // Filter the predefined list to only show categories with discoveries
    final filtersToShow = _discoveryFilters
        .where((f) => availableCategories.contains(f))
        .toList();

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filtersToShow.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filtersToShow[index];
          final isSelected = _selectedDiscoveryFilter == filter;
          final count = filter == 'All'
              ? discoveries.length
              : discoveries
                  .where((d) =>
                      d.category?.toLowerCase() ==
                      filter.toLowerCase().replaceAll(' ', '_'))
                  .length;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDiscoveryFilter = filter;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [_emmaColor, Color(0xFFFF9F43)],
                      )
                    : null,
                color: isSelected ? null : Us2Theme.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Us2Theme.beige,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Us2Theme.textMedium,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.25)
                          : Us2Theme.beige,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count.toString(),
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Us2Theme.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Get timing info based on discovery category
  Map<String, dynamic> _getTimingInfo(String? category) {
    // High-stakes categories need dedicated time
    const dedicatedCategories = ['values', 'future', 'family', 'money'];
    // Medium-stakes need a relaxed moment
    const relaxedCategories = ['communication', 'emotional', 'conflict', 'intimacy'];
    // Quick categories for light topics
    const quickCategories = ['lifestyle', 'entertainment', 'social', 'daily_life'];

    final cat = category?.toLowerCase() ?? '';

    if (dedicatedCategories.contains(cat)) {
      return {
        'type': 'dedicated',
        'icon': '📅',
        'label': '20-30 min',
        'hint': 'Plan a relaxed time for this',
        'bgColor': const Color(0xFFFCE4EC),
        'textColor': const Color(0xFFC2185B),
      };
    } else if (relaxedCategories.contains(cat)) {
      return {
        'type': 'relaxed',
        'icon': '🌙',
        'label': 'Quiet moment',
        'hint': 'Best for a calm evening',
        'bgColor': const Color(0xFFF3E5F5),
        'textColor': const Color(0xFF7B1FA2),
      };
    } else if (quickCategories.contains(cat)) {
      return {
        'type': 'quick',
        'icon': '⚡',
        'label': 'Anytime',
        'hint': '2-3 minutes is enough',
        'bgColor': const Color(0xFFE8F5E9),
        'textColor': const Color(0xFF388E3C),
      };
    } else {
      // Default to relaxed for unknown categories
      return {
        'type': 'relaxed',
        'icon': '🌙',
        'label': 'Relaxed moment',
        'hint': 'Find a calm moment',
        'bgColor': const Color(0xFFF3E5F5),
        'textColor': const Color(0xFF7B1FA2),
      };
    }
  }

  // High-stakes discovery colors
  static const Color _highStakesBg = Color(0xFFFFF8F5);
  static const Color _highStakesBorder = Color(0xFFFFB8A8);

  Widget _buildDiscoveryItemWithAction(
      FramedDiscovery discovery, String userName, String partnerName) {
    final timing = _getTimingInfo(discovery.category);
    final isHighStakes = timing['type'] == 'dedicated';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighStakes ? _highStakesBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isHighStakes
            ? Border.all(color: _highStakesBorder, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // High-stakes "Big Topic" badge
          if (isHighStakes) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withOpacity(0.2),
                    const Color(0xFFFF9F43).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    'Big Topic',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _emmaColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Timing badge row
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: timing['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timing['icon'] as String,
                          style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        timing['label'] as String,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: timing['textColor'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timing['hint'] as String,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: Us2Theme.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                ],
              ),
            ),
          ],
          // High-stakes guidance section
          if (isHighStakes) ...[
            const SizedBox(height: 14),
            _buildHighStakesGuidance(),
          ],
        ],
      ),
    );
  }

  /// Build the high-stakes guidance section with acknowledgment and steps
  Widget _buildHighStakesGuidance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Acknowledgment section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Us2Theme.beige),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'This is a significant topic',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Us2Theme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'This touches on big life questions. There\'s no quick answer, and that\'s okay.',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: Us2Theme.textMedium,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Suggested approach steps
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🗺️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'Suggested approach',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Us2Theme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildGuidanceStep(1, 'Find a relaxed time (not during stress)'),
              _buildGuidanceStep(2, 'Start with curiosity, not conclusions'),
              _buildGuidanceStep(3, 'Share feelings without pressure to decide'),
              _buildGuidanceStep(4, 'It\'s okay to revisit this multiple times'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Reassurance quote
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF4E6C8)),
          ),
          child: Text(
            '"Many happy couples navigate this over time. You don\'t need to solve it today."',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Us2Theme.textMedium,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        // Professional help prompt
        _buildProfessionalHelpPrompt(),
      ],
    );
  }

  /// Build the subtle professional help prompt for high-stakes discoveries
  Widget _buildProfessionalHelpPrompt() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FFF5), // help-bg
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)), // help-border
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Some couples find it helpful to explore big life questions with a professional. This isn\'t about having problems — it\'s about having support for important conversations.',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Us2Theme.textDark,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    // Could link to resources in the future
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Resources coming soon!',
                          style: GoogleFonts.nunito(fontSize: 14),
                        ),
                        backgroundColor: const Color(0xFF4CAF50),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Learn more about couples coaching',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4CAF50), // help-accent
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single guidance step
  Widget _buildGuidanceStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _emmaColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _emmaColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: Us2Theme.textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
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
                  fontSize: 11,
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
                    fontSize: 11,
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
              fontSize: 11,
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
              // Growth Edge section (if available)
              if (profile.growthEdges.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildGrowthEdgeSection(profile.growthEdges.first, partnerName),
              ],
              // Framing note
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _emmaColor.withOpacity(0.08),
                      const Color(0xFFFF9F43).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'These perceptions often reveal strengths you don\'t recognize in yourself.',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Us2Theme.textMedium,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Growth Edge colors
  static const Color _growthBg = Color(0xFFF0F7FF);
  static const Color _growthBorder = Color(0xFFB8D4F0);
  static const Color _growthAccent = Color(0xFF4A90C2);

  /// Build the Growth Edge section showing perception gaps
  Widget _buildGrowthEdgeSection(GrowthEdge edge, String partnerName) {
    return Container(
      decoration: BoxDecoration(
        color: _growthBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _growthBorder),
      ),
      child: Column(
        children: [
          // Gradient top bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_growthAccent, const Color(0xFF7BC4D4)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text('🔍', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'A Different Perspective',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _growthAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Comparison highlight
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'YOU SAID',
                                  style: GoogleFonts.nunito(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Us2Theme.textLight,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Us2Theme.cream,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '"${edge.selfView}"',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Us2Theme.textDark,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '↔️',
                              style: TextStyle(
                                fontSize: 16,
                                color: _growthAccent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${partnerName.toUpperCase()} SEES',
                                  style: GoogleFonts.nunito(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Us2Theme.textLight,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Us2Theme.cream,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '"${edge.partnerView}"',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Us2Theme.textDark,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        edge.insight,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Us2Theme.textMedium,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Curiosity prompt
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💭', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Try asking $partnerName:',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _growthAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '"${edge.askQuestion}"',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Us2Theme.textDark,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              fontSize: 11,
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
                  fontSize: 11,
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
