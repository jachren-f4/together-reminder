import 'package:flutter/material.dart';
import '../config/animation_constants.dart';
import '../widgets/animations/animations.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/brand/brand_widget_factory.dart';
import '../widgets/brand/us2/us2_intro_screen.dart';
import '../services/word_search_service.dart';
import '../services/love_point_service.dart';
import '../services/storage_service.dart';
import 'word_search_game_screen.dart';

/// Introduction screen for Word Search game.
/// Shows game preview with animated letter grid before starting.
class WordSearchIntroScreen extends StatefulWidget {
  const WordSearchIntroScreen({super.key});

  @override
  State<WordSearchIntroScreen> createState() => _WordSearchIntroScreenState();
}

class _WordSearchIntroScreenState extends State<WordSearchIntroScreen>
    with DramaticScreenMixin {
  final WordSearchService _service = WordSearchService();
  bool _isLoading = false;
  bool _isMyTurn = true;
  int _partnerFoundCount = 0;
  LpContentStatus? _lpStatus;

  @override
  bool get enableConfetti => false;

  @override
  void initState() {
    super.initState();
    _checkTurnStatus();
    _checkLpStatus();
  }

  Future<void> _checkLpStatus() async {
    final status = await LovePointService.checkLpStatus('word_search');
    if (mounted) {
      setState(() {
        _lpStatus = status;
      });
    }
  }

  Future<void> _checkTurnStatus() async {
    try {
      final state = await _service.getOrCreateMatch();
      if (!mounted) return;

      setState(() {
        _isMyTurn = state.isMyTurn;
        // Count partner's found words
        _partnerFoundCount = state.match.player2WordsFound;
      });
    } catch (e) {
      // Silently fail - will show default state
    }
  }

  void _startGame() {
    setState(() => _isLoading = true);
    triggerFlash();
    triggerParticlesAt(Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height * 0.7,
    ));

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WordSearchGameScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = StorageService().getUser();
    final partner = StorageService().getPartner();
    final userName = user?.name;
    final partnerName = partner?.name ?? 'Partner';

    // Us 2.0 brand uses simplified intro screen
    if (BrandWidgetFactory.isUs2) {
      return _buildUs2Intro(userName, partnerName);
    }

    return wrapWithDramaticEffects(
      Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              // Header with 3D drop
              AnimatedHeaderDrop(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: BoxDecoration(
                    border: Border(bottom: EditorialStyles.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: EditorialStyles.fullBorder,
                              ),
                              child: const Icon(Icons.arrow_back, size: 20),
                            ),
                          ),
                          const Spacer(),
                          ShineOverlayWidget(
                            delay: const Duration(milliseconds: 1000),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: EditorialStyles.ink,
                              ),
                              child: Text(
                                'SIDE QUEST',
                                style: EditorialStyles.labelUppercase.copyWith(
                                  color: EditorialStyles.paper,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Word Search',
                        style: EditorialStyles.headline,
                      ),
                    ],
                  ),
                ),
              ),

              // Hero section with word search preview
              Expanded(
                child: SingleChildScrollView(
                  child: BounceInWidget(
                    delay: AnimationConstants.heroRevealDelay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Letter grid preview
                          _buildLetterGridPreview(),

                          const SizedBox(height: 16),

                          // Words list
                          BounceInWidget(
                            delay: const Duration(milliseconds: 1400),
                            child: _buildWordsList(),
                          ),

                          const SizedBox(height: 16),

                          // Turn indicator
                          BounceInWidget(
                            delay: const Duration(milliseconds: 1800),
                            child: _buildTurnIndicator(userName, partnerName),
                          ),

                          const SizedBox(height: 12),

                          // Description
                          BounceInWidget(
                            delay: const Duration(milliseconds: 1000),
                            child: Text(
                              'Race to find hidden words!\nEach word you find earns points for you both.',
                              style: EditorialStyles.bodyText.copyWith(
                                fontStyle: FontStyle.italic,
                                color: EditorialStyles.ink.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  children: [
                    // LP reward preview
                    BounceInWidget(
                      delay: const Duration(milliseconds: 1500),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: EditorialStyles.fullBorder,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              offset: const Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HeartBeatWidget(
                              delay: const Duration(milliseconds: 2200),
                              child: Text(
                                '♥',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _lpStatus?.alreadyGrantedToday == true
                                  ? 'LP earned today · Resets in ${_lpStatus?.resetTimeFormatted ?? ''}'
                                  : '+30 LP on completion',
                              style: EditorialStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Start button
                    ButtonRiseWidget(
                      delay: const Duration(milliseconds: 1700),
                      child: SizedBox(
                        width: double.infinity,
                        child: ShineOverlayWidget(
                          delay: const Duration(milliseconds: 2500),
                          child: EditorialPrimaryButton(
                            label: _isLoading ? 'Loading...' : 'Start Playing',
                            onPressed: _isLoading ? null : _startGame,
                          ),
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
    );
  }

  /// Build Us 2.0 styled intro screen
  Widget _buildUs2Intro(String? userName, String partnerName) {
    final alreadyEarned = _lpStatus?.alreadyGrantedToday == true;

    return Us2IntroScreen(
      title: 'Word Search',
      description: 'Race to find hidden words! Each word you find earns points for you both.',
      emoji: '🔍',
      buttonLabel: _isLoading ? 'Loading...' : 'Start Playing',
      onStart: _isLoading ? () {} : _startGame,
      onBack: () => Navigator.of(context).pop(),
      additionalContent: [
        // Reward badge
        Us2RewardBadge(
          text: alreadyEarned ? 'LP earned today' : '+30 LP',
          icon: Icons.favorite,
        ),
        const SizedBox(height: 12),
        // Turn indicator
        Us2RewardBadge(
          text: _isMyTurn ? "It's your turn!" : "Waiting for $partnerName",
          icon: _isMyTurn ? Icons.play_arrow : Icons.hourglass_empty,
        ),
        if (_partnerFoundCount > 0) ...[
          const SizedBox(height: 12),
          Us2RewardBadge(
            text: '$partnerName found $_partnerFoundCount words',
            icon: Icons.check_circle,
          ),
        ],
      ],
    );
  }

  Widget _buildLetterGridPreview() {
    // 6x5 grid preview - highlight LOVE (row 0, cols 1-4) and KISS (row 4, cols 0-3)
    final grid = [
      ['H', 'L', 'O', 'V', 'E', 'R'],
      ['E', 'K', 'A', 'W', 'N', 'P'],
      ['A', 'I', 'S', 'S', 'T', 'M'],
      ['R', 'S', 'Y', 'H', 'U', 'G'],
      ['K', 'I', 'S', 'S', 'B', 'X'],
    ];

    // Cells that are part of found words
    final highlightedCells = <String>{
      '0-1', '0-2', '0-3', '0-4', // LOVE
      '4-0', '4-1', '4-2', '4-3', // KISS
    };

    return Column(
      children: List.generate(grid.length, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(grid[row].length, (col) {
            final isHighlighted = highlightedCells.contains('$row-$col');
            return WaveInWidget(
              row: row,
              column: col,
              animate: true,
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? EditorialStyles.ink.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  border: Border.all(
                    color: isHighlighted ? EditorialStyles.ink : Colors.grey.shade300,
                    width: isHighlighted ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  grid[row][col],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                    color: isHighlighted ? EditorialStyles.ink : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildWordsList() {
    final words = [
      ('Love', true),
      ('Kiss', true),
      ('Heart', false),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: words.asMap().entries.map((entry) {
        final index = entry.key;
        final word = entry.value.$1;
        final isFound = entry.value.$2;

        return StaggeredSlideIn(
          index: index,
          baseDelay: const Duration(milliseconds: 1400),
          staggerDelay: const Duration(milliseconds: 100),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isFound ? EditorialStyles.ink : EditorialStyles.paper,
              border: EditorialStyles.fullBorder,
            ),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: isFound ? EditorialStyles.paper : EditorialStyles.ink,
                decoration: isFound ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTurnIndicator(String? userName, String? partnerName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPlayerAvatar(
          userName ?? 'You',
          isActive: _isMyTurn,
          label: _isMyTurn ? 'Your Turn' : 'Waiting',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'vs',
            style: EditorialStyles.bodySmall.copyWith(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
        _buildPlayerAvatar(
          partnerName ?? 'Partner',
          isActive: !_isMyTurn,
          label: _partnerFoundCount > 0 ? '$_partnerFoundCount found' : 'Waiting',
        ),
      ],
    );
  }

  Widget _buildPlayerAvatar(String name, {required bool isActive, required String label}) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isActive ? EditorialStyles.ink : EditorialStyles.paper,
            border: EditorialStyles.fullBorder,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isActive ? EditorialStyles.paper : EditorialStyles.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: EditorialStyles.labelUppercase.copyWith(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? EditorialStyles.ink : Colors.grey,
          ),
        ),
      ],
    );
  }
}

