import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/brand/us2_theme.dart';

/// Test screen with 5 different fade gradient approaches
/// Access via Debug Menu > Actions tab
class FadeGradientTestScreen extends StatefulWidget {
  const FadeGradientTestScreen({super.key});

  @override
  State<FadeGradientTestScreen> createState() => _FadeGradientTestScreenState();
}

class _FadeGradientTestScreenState extends State<FadeGradientTestScreen> {
  int _selectedApproach = 0;

  @override
  Widget build(BuildContext context) {
    // APPROACH 0 (★ In scroll full): Everything scrolls, extends into safe area
    if (_selectedApproach == 0) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
          child: SafeArea(
            bottom: false, // Allow content to extend into bottom safe area
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildApproachSelector(),
                  _buildFakeContent(),
                  // Button inside scroll
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildButtonOnly(),
                  ),
                  // Extra padding to push content above home indicator when scrolled to bottom
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // APPROACH 1 (Stack+Gradient): Stack layout with very tall gradient
    if (_selectedApproach == 1) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
          child: SafeArea(
            child: Stack(
              children: [
                // Full-screen scrollable content
                Column(
                  children: [
                    _buildHeader(),
                    _buildApproachSelector(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildFakeContent(),
                            const SizedBox(height: 120), // Space for overlaid footer
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Very tall gradient from bottom of screen
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 200, // Very tall gradient
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                          colors: [
                            Colors.transparent,
                            Us2Theme.bgGradientEnd.withOpacity(0.2),
                            Us2Theme.bgGradientEnd.withOpacity(0.5),
                            Us2Theme.bgGradientEnd.withOpacity(0.8),
                            Us2Theme.bgGradientEnd,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Footer overlaid at bottom (on top of gradient)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildButtonOnly(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // APPROACH 7: Use Stack layout instead of Column (no gradient)
    if (_selectedApproach == 7) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
          child: SafeArea(
            child: Stack(
              children: [
                // Full-screen scrollable content
                Column(
                  children: [
                    _buildHeader(),
                    _buildApproachSelector(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildFakeContent(),
                            const SizedBox(height: 120), // Space for overlaid footer
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Footer overlaid at bottom (not in Column flow)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildButtonOnly(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Default: Column-based layout
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Approach selector
              _buildApproachSelector(),

              // Content area with selected approach
              Expanded(
                child: _buildContentWithApproach(_selectedApproach),
              ),

              // Fixed footer button
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.close, size: 20, color: Us2Theme.textDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Fade Gradient Test',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproachSelector() {
    final approaches = [
      '★ In scroll (full)',
      'Stack+Gradient',
      '1: Simple (60px)',
      '2: Tall (100px)',
      '3: Multi-stop (80px)',
      '4: Very tall (150px)',
      '5: No gradient',
      '6: Stack layout',
      '7: Zero padding',
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: approaches.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedApproach == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedApproach = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Us2Theme.primaryBrandPink : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Us2Theme.primaryBrandPink : Colors.grey.shade300,
                  ),
                ),
                child: Center(
                  child: Text(
                    approaches[index],
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Us2Theme.textDark,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContentWithApproach(int approach) {
    // All Column-based approaches: scrollable content, footer handled separately
    return SingleChildScrollView(
      child: _buildFakeContent(),
    );
  }

  // Fake content to scroll
  Widget _buildFakeContent() {
    return Column(
      children: [
        // Score summary
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildScoreStat('4', 'ALIGNED'),
                  const SizedBox(width: 40),
                  _buildScoreStat('1', 'DIFFERENT'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Mostly aligned, with some interesting differences to discuss.',
                style: GoogleFonts.nunito(fontSize: 14, color: Us2Theme.textMedium),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Fake question cards
        ...List.generate(5, (i) => _buildFakeQuestionCard(i + 1)),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildScoreStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Us2Theme.textDark,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Us2Theme.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildFakeQuestionCard(int number) {
    final isAligned = number != 3;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAligned
            ? const Color(0xFFE8F5E9)  // Light green
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAligned ? const Color(0xFF4CAF50) : Colors.grey.shade300,
          width: isAligned ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isAligned ? const Color(0xFF4CAF50) : Us2Theme.primaryBrandPink,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sample question text for item $number that might be quite long',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAligned ? const Color(0xFF4CAF50) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAligned ? 'ALIGNED' : 'DIFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isAligned ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('TAITSU', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Us2Theme.textMedium)),
              const SizedBox(width: 12),
              Text('Agree', style: GoogleFonts.nunito(fontSize: 13, color: Us2Theme.textDark)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('JOKKE', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Us2Theme.textMedium)),
              const SizedBox(width: 12),
              Text(isAligned ? 'Agree' : 'Disagree', style: GoogleFonts.nunito(fontSize: 13, color: Us2Theme.textDark)),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildFooter() {
    // Use the selected approach for the footer gradient
    return _buildFooterWithApproach(_selectedApproach);
  }

  Widget _buildFooterWithApproach(int approach) {
    switch (approach) {
      case 0:
        return const SizedBox.shrink(); // ★ In scroll (full) handled in build()
      case 1:
        return const SizedBox.shrink(); // Stack+Gradient handled in build()
      case 2:
        return _footer1SimpleGradient();
      case 3:
        return _footer2TallGradient();
      case 4:
        return _footer3MultiStop();
      case 5:
        return _footer4VeryTallGradient();
      case 6:
        return _footer5NoGradient();
      case 7:
        return const SizedBox.shrink(); // Stack layout handled in build()
      case 8:
        return _footer7ZeroPadding();
      default:
        return _footer1SimpleGradient();
    }
  }

  // ============================================
  // APPROACH 1: Simple gradient (60px above button)
  // ============================================
  Widget _footer1SimpleGradient() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient extending upward - covers entire footer + above
        Positioned(
          left: 0,
          right: 0,
          top: -60,
          child: IgnorePointer(
            child: Container(
              height: 60 + 150, // gradient height + footer height estimate
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3],
                  colors: [
                    Colors.transparent,
                    Us2Theme.bgGradientEnd,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Button content (no background)
        _buildFooterContentNoBg(),
      ],
    );
  }

  // ============================================
  // APPROACH 2: Taller gradient (100px above button)
  // ============================================
  Widget _footer2TallGradient() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -100,
          child: IgnorePointer(
            child: Container(
              height: 100 + 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4],
                  colors: [
                    Colors.transparent,
                    Us2Theme.bgGradientEnd,
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildFooterContentNoBg(),
      ],
    );
  }

  // ============================================
  // APPROACH 3: Multi-stop gradient (80px, smoother)
  // ============================================
  Widget _footer3MultiStop() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -80,
          child: IgnorePointer(
            child: Container(
              height: 80 + 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.15, 0.35, 0.5],
                  colors: [
                    Colors.transparent,
                    Us2Theme.bgGradientEnd.withOpacity(0.3),
                    Us2Theme.bgGradientEnd.withOpacity(0.7),
                    Us2Theme.bgGradientEnd,
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildFooterContentNoBg(),
      ],
    );
  }

  // ============================================
  // APPROACH 4: Very tall gradient (150px above)
  // ============================================
  Widget _footer4VeryTallGradient() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -150,
          child: IgnorePointer(
            child: Container(
              height: 150 + 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.15, 0.35, 0.55, 0.7],
                  colors: [
                    Colors.transparent,
                    Us2Theme.bgGradientEnd.withOpacity(0.15),
                    Us2Theme.bgGradientEnd.withOpacity(0.4),
                    Us2Theme.bgGradientEnd.withOpacity(0.75),
                    Us2Theme.bgGradientEnd,
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildFooterContentNoBg(),
      ],
    );
  }

  // ============================================
  // APPROACH 5: No gradient (baseline)
  // ============================================
  Widget _footer5NoGradient() {
    return _buildFooterContentNoBg();
  }

  // ============================================
  // APPROACH 6: Stack layout - footer overlays content
  // This tests if the Column layout itself creates the box
  // (Handled in build method, this won't be called)
  // ============================================
  Widget _footer6StackLayout() {
    return const SizedBox.shrink();
  }

  // ============================================
  // APPROACH 7: Zero padding, just the raw button
  // ============================================
  Widget _footer7ZeroPadding() {
    return _buildButtonOnly();
  }

  // Just the button, no padding, no container
  Widget _buildButtonOnly() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: Us2Theme.accentGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                'Return Home',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: Text(
            'Back to Main Screen',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Us2Theme.primaryBrandPink,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Footer content WITHOUT any background - just the button
  Widget _buildFooterContentNoBg() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Return Home button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: Us2Theme.accentGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.glowPink.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Return Home',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Quick navigation back to main screen
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Text(
              'Back to Main Screen',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Us2Theme.primaryBrandPink,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
