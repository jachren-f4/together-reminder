import 'dart:io';
import 'package:flutter/material.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
// import '../config/animation_constants.dart';  // Disabled with Card3DEntrance
import 'quest_card.dart';
import 'steps/steps_quest_card.dart';
// import 'animations/dramatic_entrance_widgets.dart';  // Disabled - animation causing flicker bugs

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
/// Callback to determine if a quest is locked and what criteria is needed to unlock
typedef QuestLockCallback = ({bool isLocked, String? unlockCriteria}) Function(DailyQuest quest);

/// Callback to determine if a quest should show onboarding guidance
typedef QuestGuidanceCallback = ({bool showGuidance, String? guidanceText}) Function(DailyQuest quest);

class QuestCarousel extends StatefulWidget {
  final List<DailyQuest> quests;
  final String? currentUserId;
  final Function(DailyQuest) onQuestTap;
  final double cardWidthPercent; // Default: 0.6 (60%)
  final bool showProgressBar; // Default: true
  final QuestLockCallback? isLockedBuilder; // Optional: determines locked state per quest
  final QuestGuidanceCallback? guidanceBuilder; // Optional: determines guidance state per quest

  const QuestCarousel({
    super.key,
    required this.quests,
    this.currentUserId,
    required this.onQuestTap,
    this.cardWidthPercent = 0.6,
    this.showProgressBar = true,
    this.isLockedBuilder,
    this.guidanceBuilder,
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
          height: 380, // Accommodate image (200px max) + content (~180px) with margin
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(), // iOS-style bounce for better overscroll
            itemCount: widget.quests.length,
            padEnds: false, // Remove padding at start/end for better left alignment
            itemBuilder: (context, index) {
              final quest = widget.quests[index];
              final isActive = index == _activeCardIndex;

              // Add RepaintBoundary for performance (Phase 2 optimization)
              // Card3DEntrance animation DISABLED - was causing flicker/re-render bugs
              // TODO: Re-enable once animation tracking is fixed
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4), // Small gap between cards
                  child: _buildQuestCard(quest, isActive),
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

  /// Build appropriate card widget based on quest type
  Widget _buildQuestCard(DailyQuest quest, bool isActive) {
    // Check if quest is locked
    final lockState = widget.isLockedBuilder?.call(quest);
    final isLocked = lockState?.isLocked ?? false;
    final unlockCriteria = lockState?.unlockCriteria;

    // Check if quest should show guidance
    final guidanceState = widget.guidanceBuilder?.call(quest);
    final showGuidance = guidanceState?.showGuidance ?? false;
    final guidanceText = guidanceState?.guidanceText;

    // Use specialized StepsQuestCard for steps quests (iOS only)
    if (quest.type == QuestType.steps && Platform.isIOS) {
      return StepsQuestCard(
        onTap: () => widget.onQuestTap(quest),
        showShadow: isActive,
      );
    }

    // Default: use generic QuestCard
    // Key includes completion count to force rebuild when quest status changes
    // (Hive returns same object instances, so without Key Flutter reuses State)
    // For turn-based games (Linked, Word Search), also include currentTurnUserId
    // so the card rebuilds when the turn changes
    final completionCount = quest.userCompletions?.length ?? 0;
    String keyExtra = '';
    if (quest.type == QuestType.linked) {
      final match = StorageService().getActiveLinkedMatch();
      keyExtra = '_${match?.currentTurnUserId ?? 'none'}';
    } else if (quest.type == QuestType.wordSearch) {
      final match = StorageService().getActiveWordSearchMatch();
      keyExtra = '_${match?.currentTurnUserId ?? 'none'}';
    }
    return QuestCard(
      key: ValueKey('${quest.id}_$completionCount${keyExtra}_$isLocked'),
      quest: quest,
      currentUserId: widget.currentUserId,
      onTap: () => widget.onQuestTap(quest),
      showShadow: isActive,
      isLocked: isLocked,
      unlockCriteria: unlockCriteria,
      showGuidance: showGuidance,
      guidanceText: guidanceText,
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }
}
