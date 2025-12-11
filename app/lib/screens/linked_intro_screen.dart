import 'package:flutter/material.dart';
import '../config/animation_constants.dart';
import '../widgets/animations/animations.dart';
import '../widgets/editorial/editorial.dart';
import '../services/linked_service.dart';
import '../services/storage_service.dart';
import 'linked_game_screen.dart';

/// Introduction screen for Linked crossword game.
/// Shows game preview with animated crossword grid before starting.
class LinkedIntroScreen extends StatefulWidget {
  const LinkedIntroScreen({super.key});

  @override
  State<LinkedIntroScreen> createState() => _LinkedIntroScreenState();
}

class _LinkedIntroScreenState extends State<LinkedIntroScreen>
    with DramaticScreenMixin {
  final LinkedService _service = LinkedService();
  bool _isLoading = false;
  bool _isMyTurn = true;

  @override
  bool get enableConfetti => false;

  @override
  void initState() {
    super.initState();
    _checkTurnStatus();
  }

  Future<void> _checkTurnStatus() async {
    try {
      final state = await _service.getOrCreateMatch();
      if (!mounted) return;

      setState(() {
        _isMyTurn = state.isMyTurn;
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
        MaterialPageRoute(builder: (context) => const LinkedGameScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = StorageService().getUser();
    final partner = StorageService().getPartner();
    final userName = user?.name;
    final partnerName = partner?.name;

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
                        'Linked',
                        style: EditorialStyles.headline,
                      ),
                    ],
                  ),
                ),
              ),

              // Hero section with crossword preview
              Expanded(
                child: SingleChildScrollView(
                  child: BounceInWidget(
                    delay: AnimationConstants.heroRevealDelay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Crossword grid preview
                          _buildCrosswordPreview(),

                          const SizedBox(height: 20),

                          // Turn indicator
                          BounceInWidget(
                            delay: const Duration(milliseconds: 1800),
                            child: _buildTurnIndicator(userName, partnerName),
                          ),

                          const SizedBox(height: 16),

                          // Description
                          BounceInWidget(
                            delay: const Duration(milliseconds: 1000),
                            child: Text(
                              'Take turns solving crossword clues.\nConnect your words and see how in sync your minds are.',
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LP reward preview
                    BounceInWidget(
                      delay: AnimationConstants.rewardBoxDelay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
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
                              delay: const Duration(milliseconds: 2000),
                              child: Text(
                                '♥',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+30 LP on completion',
                              style: EditorialStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Start button
                    ButtonRiseWidget(
                      delay: const Duration(milliseconds: 1600),
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

  Widget _buildCrosswordPreview() {
    // 5x3 grid preview with LOVE, EAR, and CARE themed words
    // Layout: LOVE horizontal, EAR vertical from E, CARE horizontal with R intersecting EAR's R
    final grid = [
      ['L', 'O', 'V', 'E', ''],
      ['', '', '', 'A', ''],
      ['', 'C', 'A', 'R', 'E'],
    ];

    // Cell indices:
    // Row 0: 0(L), 1(O), 2(V), 3(E), 4('')
    // Row 1: 5(''), 6(''), 7(''), 8(A), 9('')
    // Row 2: 10(''), 11(C), 12(A), 13(R), 14(E)
    // EAR's R at index 13 intersects with CARE's R at index 13

    // Grayscale - all filled cells use the same ink color
    final filledCells = <int>{
      0, 1, 2, 3,     // LOVE
      8,              // A from EAR
      11, 12, 13, 14, // CARE (13 is shared R with EAR)
    };

    int cellIndex = 0;

    return Column(
      children: grid.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((letter) {
            final index = cellIndex++;
            final isEmpty = letter.isEmpty;
            final isFilled = filledCells.contains(index);

            if (isEmpty) {
              return const SizedBox(width: 43, height: 43);
            }

            return CellPopWidget(
              cellIndex: index,
              baseDelay: const Duration(milliseconds: 800),
              animate: true,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: isFilled ? EditorialStyles.ink : EditorialStyles.paper,
                  border: EditorialStyles.fullBorder,
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isFilled ? EditorialStyles.paper : EditorialStyles.ink,
                  ),
                ),
              ),
            );
          }).toList(),
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
          label: !_isMyTurn ? 'Their Turn' : 'Waiting',
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
