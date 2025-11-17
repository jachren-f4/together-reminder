import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import 'quest_card.dart';

/// Reusable horizontal carousel widget with scroll tracking and active card detection
///
/// Features:
/// - Horizontal scrolling with snap-to-center (PageView)
/// - Active card detection based on page index
/// - Progress bar that updates with scroll
/// - Configurable card width (default 60%)
/// - Peek effect for adjacent cards
/// - Performance optimizations (RepaintBoundary)
/// - Scroll position restoration
class QuestCarousel extends StatefulWidget {
  final List<DailyQuest> quests;
  final String? currentUserId;
  final Function(DailyQuest) onQuestTap;
  final double cardWidthPercent; // Default: 0.6 (60%)
  final bool showProgressBar; // Default: true

  const QuestCarousel({
    super.key,
    required this.quests,
    this.currentUserId,
    required this.onQuestTap,
    this.cardWidthPercent = 0.6,
    this.showProgressBar = true,
  });

  @override
  State<QuestCarousel> createState() => _QuestCarouselState();
}

class _QuestCarouselState extends State<QuestCarousel> {
  late PageController _pageController;
  int _activeCardIndex = 0;
  int? _savedPageIndex; // Save page index instead of pixel offset
  double _scrollProgress = 0.0; // Track scroll position (0.0 to 1.0) for progress bar

  @override
  void initState() {
    super.initState();
    // PageView provides built-in snap-to-center (simpler than ListView manual calculations)
    _pageController = PageController(
      viewportFraction: widget.cardWidthPercent, // 60% width with peek effect
      initialPage: _savedPageIndex ?? 0,
    );
    _pageController.addListener(_onPageScroll);

    // Calculate active card after scroll restoration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _updateActiveCardFromPage();
      }
    });
  }

  @override
  void deactivate() {
    // Save page index before navigation (simpler than pixel offset)
    if (_pageController.hasClients && _pageController.page != null) {
      _savedPageIndex = _pageController.page!.round();
    }
    super.deactivate();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;

    // Calculate scroll progress (0.0 to 1.0) for smooth progress bar animation
    // Similar to HTML: scrollLeft / maxScroll
    final position = _pageController.position;
    final offset = position.pixels;
    final minScrollExtent = position.minScrollExtent;
    final maxScrollExtent = position.maxScrollExtent;

    if (maxScrollExtent > minScrollExtent) {
      final newProgress = ((offset - minScrollExtent) / (maxScrollExtent - minScrollExtent)).clamp(0.0, 1.0);
      if ((newProgress - _scrollProgress).abs() > 0.001) { // Only update if changed significantly
        setState(() {
          _scrollProgress = newProgress;
        });
      }
    }

    // Also update active card index for visual effects
    if (_pageController.page != null) {
      _updateActiveCardFromPage();
    }
  }

  void _updateActiveCardFromPage() {
    if (!_pageController.hasClients || _pageController.page == null) return;

    final page = _pageController.page!;
    final newActiveIndex = page.round().clamp(0, widget.quests.length - 1);

    if (newActiveIndex != _activeCardIndex) {
      setState(() {
        _activeCardIndex = newActiveIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // PageView with snap-to-center (replaces ListView for simpler implementation)
        SizedBox(
          height: 350, // Increased to accommodate image (170px) + content + padding
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(), // iOS-style bounce for better overscroll
            itemCount: widget.quests.length,
            padEnds: false, // Remove padding at start/end for better left alignment
            itemBuilder: (context, index) {
              final quest = widget.quests[index];
              final isActive = index == _activeCardIndex;

              // Add RepaintBoundary for performance (Phase 2 optimization)
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4), // Small gap between cards
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    opacity: 1.0, // All cards same visibility
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      scale: 1.0, // All cards same size
                      child: QuestCard(
                        quest: quest,
                        currentUserId: widget.currentUserId,
                        onTap: () => widget.onQuestTap(quest),
                        showShadow: isActive,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Progress bar (updates smoothly with scroll position, like HTML mockup)
        if (widget.showProgressBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 20), // Full width, no side margins
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.centerLeft, // Align fill to left edge
              child: FractionallySizedBox(
                widthFactor: _scrollProgress, // Use actual scroll position instead of page index
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }
}
