import 'package:flutter/material.dart';
import 'package:togetherremind/config/journal_fonts.dart';
import 'package:togetherremind/models/journal_entry.dart';
import 'package:togetherremind/models/weekly_insights.dart';
import 'package:togetherremind/services/journal_service.dart';
import 'package:togetherremind/widgets/journal/journal_polaroid.dart';
import 'package:togetherremind/widgets/journal/journal_detail_sheet.dart';
import 'package:togetherremind/widgets/journal/week_loading_overlay.dart';
import 'package:togetherremind/screens/journal_loading_screen.dart';

/// Journal screen showing completed quests in a scrapbook/polaroid style.
///
/// Features:
/// - Week-based navigation (Monday-Sunday)
/// - Day groups with polaroid cards
/// - Weekly insights card
/// - First-time loading animation (JournalLoadingScreen)
/// - Week loading overlay (WeekLoadingOverlay)
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _journalService = JournalService();
  final _scrollController = ScrollController();

  // Current week being displayed
  late DateTime _currentWeekStart;

  // Loading states
  bool _isLoadingWeek = false;
  bool _showFirstTimeScreen = false;

  // Data
  List<JournalEntry> _entries = [];
  WeeklyInsights? _insights;

  // Scroll offset for paper lines
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = JournalService.getMondayOfWeek(DateTime.now());
    _showFirstTimeScreen = _journalService.isFirstTimeOpening;

    // Track scroll for paper lines effect
    _scrollController.addListener(_onScroll);

    // Don't load data yet if showing first-time screen
    // The first-time screen callback will trigger the load
    if (!_showFirstTimeScreen) {
      _loadWeek(_currentWeekStart);
    }
  }

  /// Load entries for a week (shows WeekLoadingOverlay)
  Future<void> _loadWeek(DateTime weekStart) async {
    setState(() {
      _currentWeekStart = weekStart;
      _isLoadingWeek = true;
    });

    try {
      final entries = await _journalService.getEntriesForWeek(weekStart);
      final insights = await _journalService.getWeeklyInsights(weekStart);

      if (mounted) {
        setState(() {
          _entries = entries;
          _insights = insights;
          _isLoadingWeek = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeek = false);
      debugPrint('Error loading journal week: $e');
    }
  }

  void _goToPreviousWeek() {
    if (!_journalService.canNavigateToPreviousWeek(_currentWeekStart)) return;
    final previousWeek = _currentWeekStart.subtract(const Duration(days: 7));
    _loadWeek(previousWeek);
  }

  void _goToNextWeek() {
    if (!_journalService.canNavigateToNextWeek(_currentWeekStart)) return;
    final nextWeek = _currentWeekStart.add(const Duration(days: 7));
    _loadWeek(nextWeek);
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // First-time opening: show intro animation screen
    if (_showFirstTimeScreen) {
      return JournalLoadingScreen(
        onComplete: () async {
          await _journalService.markAsOpened();
          if (mounted) {
            setState(() => _showFirstTimeScreen = false);
            _loadWeek(_currentWeekStart);
          }
        },
      );
    }

    // Normal view with optional week loading overlay
    return Scaffold(
      body: Stack(
        children: [
          _buildPaperBackground(),
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildHeader(),
                _buildWeekNavigation(),
                if (_entries.isEmpty && !_isLoadingWeek)
                  _buildEmptyState()
                else ...[
                  if (_insights != null && _insights!.hasActivity)
                    _buildWeeklyInsights(),
                  _buildTapHint(),
                  ..._buildDaySections(),
                ],
                const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
              ],
            ),
          ),
          // Week loading overlay
          WeekLoadingOverlay(
            targetWeekLabel: JournalService.formatWeekRange(_currentWeekStart),
            visible: _isLoadingWeek,
          ),
        ],
      ),
    );
  }

  /// Paper texture background with gradient and lines
  Widget _buildPaperBackground() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0), // cream
      ),
      child: Stack(
        children: [
          // Radial gradient at top
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  const Color(0xFFFFD1C1).withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Paper lines (scroll with content)
          CustomPaint(
            painter: _PaperLinesPainter(scrollOffset: _scrollOffset),
            size: Size.infinite,
          ),
        ],
      ),
    );
  }

  /// Header: "Our Journal"
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Center(
          child: Text(
            'Our Journal',
            style: JournalFonts.header,
          ),
        ),
      ),
    );
  }

  /// Week navigation with tape decoration
  Widget _buildWeekNavigation() {
    final canGoPrev = _journalService.canNavigateToPreviousWeek(_currentWeekStart);
    final canGoNext = _journalService.canNavigateToNextWeek(_currentWeekStart);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Tape background (slightly rotated)
            Transform.rotate(
              angle: -0.017, // -1 degree
              child: Container(
                width: 220,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDC96).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Navigation row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNavButton(
                  Icons.chevron_left,
                  _goToPreviousWeek,
                  !canGoPrev,
                ),
                const SizedBox(width: 16),
                Text(
                  JournalService.formatWeekRange(_currentWeekStart),
                  style: JournalFonts.weekDates,
                ),
                const SizedBox(width: 16),
                _buildNavButton(
                  Icons.chevron_right,
                  _goToNextWeek,
                  !canGoNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.transparent
              : Colors.white.withOpacity(0.8),
          shape: BoxShape.circle,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(
          icon,
          size: 24,
          color: disabled
              ? const Color(0xFFCCCCCC)
              : const Color(0xFF2D2D2D),
        ),
      ),
    );
  }

  /// Weekly insights card
  Widget _buildWeeklyInsights() {
    if (_insights == null) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with heart icon
            Row(
              children: [
                const Text('💕', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'This Week\'s Story',
                  style: JournalFonts.insightsHeader,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Insights rows
            _buildInsightRow(
              icon: '🎯',
              headline: 'Learning About Each Other',
              detail: 'You explored ${_insights!.totalQuestions} questions together, '
                  'with ${_insights!.alignedAnswers} aligned perspectives',
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              icon: '📅',
              headline: '${_insights!.daysConnected} Days Connected',
              detail: 'You checked in together on ${_insights!.daysConnected} '
                  'out of ${_insights!.possibleDays} days this week',
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              icon: '🎮',
              headline: '${_insights!.totalQuestsCompleted} Activities Completed',
              detail: '${_insights!.dailyQuestsCompleted} Quizzes, '
                  '${_insights!.sideQuestsCompleted} Games, '
                  '${_insights!.stepsTogetherCompleted} Steps Together',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow({
    required String icon,
    required String headline,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, style: JournalFonts.insightHeadline),
              const SizedBox(height: 2),
              Text(detail, style: JournalFonts.insightDetail),
            ],
          ),
        ),
      ],
    );
  }

  /// Tap hint text
  Widget _buildTapHint() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          'Tap a memory to see more details',
          style: JournalFonts.insightDetail.copyWith(
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Build day sections with polaroid cards
  List<Widget> _buildDaySections() {
    final groupedEntries = _journalService.groupEntriesByDay(_entries);

    if (groupedEntries.isEmpty) {
      return [];
    }

    final sections = <Widget>[];
    for (final entry in groupedEntries.entries) {
      final date = entry.key;
      final dayEntries = entry.value;

      // Day label
      sections.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              _formatDayLabel(date),
              style: JournalFonts.dayLabel,
            ),
          ),
        ),
      );

      // Polaroid cards for this day - 2 per row with wrap
      sections.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: dayEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final journalEntry = entry.value;
                return JournalPolaroid(
                  entry: journalEntry,
                  index: index,
                  onTap: () => _showEntryDetails(journalEntry),
                );
              }).toList(),
            ),
          ),
        ),
      );
    }

    return sections;
  }

  /// Show entry details in a bottom sheet
  void _showEntryDetails(JournalEntry entry) {
    JournalDetailSheet.show(context, entry);
  }

  /// Empty state when no entries exist for the week
  Widget _buildEmptyState() {
    final isCurrentWeek = JournalService.isSameDay(
      _currentWeekStart,
      JournalService.getMondayOfWeek(DateTime.now()),
    );

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '📖',
                style: TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 20),
              Text(
                isCurrentWeek
                    ? 'Your story starts here'
                    : 'No memories this week',
                style: JournalFonts.emptyStateHeader,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isCurrentWeek
                    ? 'Complete quests together and they\'ll appear here as cherished memories'
                    : 'Navigate to a different week to see your memories',
                style: JournalFonts.emptyStateDescription,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      // Format as "Monday, Dec 23"
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
    }
  }
}

/// Custom painter for paper texture lines
class _PaperLinesPainter extends CustomPainter {
  final double scrollOffset;

  _PaperLinesPainter({this.scrollOffset = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2D2D2D).withOpacity(0.06)
      ..strokeWidth = 1;

    const lineSpacing = 28.0;
    // Offset lines based on scroll position (modulo keeps pattern repeating)
    final offset = scrollOffset % lineSpacing;
    double y = lineSpacing - offset;

    while (y < size.height) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
      y += lineSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperLinesPainter oldDelegate) =>
      oldDelegate.scrollOffset != scrollOffset;
}
