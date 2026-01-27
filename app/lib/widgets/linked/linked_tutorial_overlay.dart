import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/brand/us2_theme.dart';

/// Tutorial overlay for the Linked game (shown on first play)
///
/// 3-step tutorial explaining:
/// 1. Read the clues (gray cells with arrows)
/// 2. Drag letters from rack to grid
/// 3. Take turns with partner
class LinkedTutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final GlobalKey clueKey;
  final GlobalKey rackKey;
  final GlobalKey submitKey;

  const LinkedTutorialOverlay({
    super.key,
    required this.onComplete,
    required this.onSkip,
    required this.clueKey,
    required this.rackKey,
    required this.submitKey,
  });

  @override
  State<LinkedTutorialOverlay> createState() => _LinkedTutorialOverlayState();
}

class _LinkedTutorialOverlayState extends State<LinkedTutorialOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _tutorialSteps = [
    _TutorialStep(
      title: 'Read the Clues',
      description:
          'Gray cells contain clues. They can be emojis, text, or both! Arrows show which direction the answer goes.',
      spotlightType: _SpotlightType.clue,
    ),
    _TutorialStep(
      title: 'Drag Your Letters',
      description:
          'Your letter rack is at the bottom. Drag letters onto empty cells in the grid. Place as many or as few as you\'d like, then tap Submit!',
      spotlightType: _SpotlightType.letterRack,
    ),
    _TutorialStep(
      title: 'Take Turns',
      description:
          'You and your partner take turns placing letters. When you\'re ready, tap Submit Turn and wait for your partner\'s turn!',
      spotlightType: _SpotlightType.submitButton,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(); // Continuous rotation for circular motion

    _pulseAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi, // Full circle in radians
    ).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _tutorialSteps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    widget.onSkip();
  }

  /// Get the position and size of a widget using its GlobalKey
  Rect? _getWidgetRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  @override
  Widget build(BuildContext context) {
    final step = _tutorialSteps[_currentStep];
    final isLastStep = _currentStep == _tutorialSteps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // Block taps
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),

          // Spotlight highlight (salmon rectangle around the element)
          if (step.spotlightType != _SpotlightType.none)
            _buildSpotlightHighlight(step.spotlightType),

          // Tutorial card
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress dots
                    _buildProgressDots(),
                    const SizedBox(height: 16),

                    // Step number badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          '${_currentStep + 1}',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      step.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    Text(
                      step.description,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: const Color(0xFF5A5A5A),
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      children: [
                        if (!isLastStep) ...[
                          // Skip button (not on last step)
                          Expanded(
                            child: GestureDetector(
                              onTap: _skip,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    'Skip',
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF5A5A5A),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Next/Let's Play button
                        Expanded(
                          flex: isLastStep ? 1 : 2,
                          child: GestureDetector(
                            onTap: _nextStep,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  isLastStep ? "Let's Play!" : 'Next \u2192',
                                  style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_tutorialSteps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                  )
                : null,
            color: isCompleted
                ? const Color(0xFF4CAF50)
                : (isActive ? null : const Color(0xFFE0E0E0)),
          ),
        );
      }),
    );
  }

  Widget _buildSpotlightHighlight(_SpotlightType type) {
    // Get the appropriate key based on spotlight type
    final key = switch (type) {
      _SpotlightType.clue => widget.clueKey,
      _SpotlightType.letterRack => widget.rackKey,
      _SpotlightType.submitButton => widget.submitKey,
      _SpotlightType.none => null,
    };

    if (key == null) return const SizedBox.shrink();

    // Use a post-frame callback to get the position after layout
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final rect = _getWidgetRect(key);
        if (rect == null) return const SizedBox.shrink();

        // Add padding around the element
        final padding = 8.0;
        final highlightRect = Rect.fromLTWH(
          rect.left - padding,
          rect.top - padding,
          rect.width + padding * 2,
          rect.height + padding * 2,
        );

        // Calculate circular motion offset (2px radius)
        final circleRadius = 2.0;
        final offsetX = math.cos(_pulseAnimation.value) * circleRadius;
        final offsetY = math.sin(_pulseAnimation.value) * circleRadius;

        return Positioned(
          left: highlightRect.left + offsetX,
          top: highlightRect.top + offsetY,
          child: Container(
              width: highlightRect.width,
              height: highlightRect.height,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _salmonColor,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _salmonColor.withOpacity(0.5),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
          ),
        );
      },
    );
  }

  // Salmon color used for highlights
  static const Color _salmonColor = Color(0xFFFA8072);
}

enum _SpotlightType {
  clue,
  letterRack,
  submitButton,
  none,
}

class _TutorialStep {
  final String title;
  final String description;
  final _SpotlightType spotlightType;

  const _TutorialStep({
    required this.title,
    required this.description,
    required this.spotlightType,
  });
}
