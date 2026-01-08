import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:togetherremind/config/journal_fonts.dart';
import 'package:togetherremind/config/animation_constants.dart';

/// First-time loading screen for the Journal feature.
///
/// Shows an animated intro that transforms from "Your Journal" to "Our Journal",
/// emphasizing the shared nature of the couple's memories.
///
/// Animation sequence (~3s):
/// 1. Background gradient fades in
/// 2. Polaroids stack in from below
/// 3. Paper texture appears
/// 4. Title morphs from "Your" to "Our"
/// 5. Subtitle reveals
/// 6. Auto-navigates to Journal once title morph completes
class JournalLoadingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const JournalLoadingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<JournalLoadingScreen> createState() => _JournalLoadingScreenState();
}

class _JournalLoadingScreenState extends State<JournalLoadingScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _polaroidController;
  late AnimationController _titleController;
  late AnimationController _subtitleController;

  // Animations
  late Animation<double> _backgroundOpacity;
  late Animation<double> _polaroid1Slide;
  late Animation<double> _polaroid2Slide;
  late Animation<double> _polaroid3Slide;
  late Animation<double> _titleMorph;
  late Animation<double> _subtitleReveal;

  @override
  void initState() {
    super.initState();

    // Check for reduced motion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AnimationConstants.shouldReduceMotion(context)) {
        // Skip animations, go directly to completion
        widget.onComplete();
        return;
      }
      _startAnimations();
    });

    _initAnimations();
  }

  void _initAnimations() {
    // Background fade in (0-0.5s)
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _backgroundOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeOut),
    );

    // Polaroid stack in (0.2-1.0s, staggered)
    _polaroidController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _polaroid1Slide = Tween<double>(begin: 200, end: 0).animate(
      CurvedAnimation(
        parent: _polaroidController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _polaroid2Slide = Tween<double>(begin: 200, end: 0).animate(
      CurvedAnimation(
        parent: _polaroidController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _polaroid3Slide = Tween<double>(begin: 200, end: 0).animate(
      CurvedAnimation(
        parent: _polaroidController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack),
      ),
    );

    // Title morph (1.5-2.0s)
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleMorph = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeInOut),
    );

    // Subtitle reveal (2.2-2.8s)
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _subtitleReveal = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOut),
    );
  }

  void _startAnimations() async {
    // Start background
    _backgroundController.forward();

    // Start polaroids after 200ms
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _polaroidController.forward();

    // Start title morph after polaroids settle (~1s)
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _titleController.forward();

    // Start subtitle as title morphs
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _subtitleController.forward();

    // Wait for title morph to complete (800ms total), then brief pause
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _polaroidController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _backgroundController,
          _polaroidController,
          _titleController,
          _subtitleController,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              _buildBackground(),
              _buildPaperTexture(),
              _buildPolaroidStack(),
              _buildContent(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Opacity(
      opacity: _backgroundOpacity.value,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFD1C1),
              Color(0xFFFFF5F0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaperTexture() {
    return Opacity(
      opacity: _backgroundOpacity.value * 0.5,
      child: CustomPaint(
        painter: _PaperLinesPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildPolaroidStack() {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Polaroid 1 (bottom-left, -12deg rotation)
            Transform.translate(
              offset: Offset(-30, _polaroid1Slide.value + 20),
              child: Transform.rotate(
                angle: -12 * math.pi / 180,
                child: _buildMiniPolaroid('📝', const Color(0xFFFFEBEE)),
              ),
            ),
            // Polaroid 2 (bottom-right, 8deg rotation)
            Transform.translate(
              offset: Offset(30, _polaroid2Slide.value + 15),
              child: Transform.rotate(
                angle: 8 * math.pi / 180,
                child: _buildMiniPolaroid('💕', const Color(0xFFFCE4EC)),
              ),
            ),
            // Polaroid 3 (top, -3deg rotation)
            Transform.translate(
              offset: Offset(0, _polaroid3Slide.value - 10),
              child: Transform.rotate(
                angle: -3 * math.pi / 180,
                child: _buildMiniPolaroid('🔗', const Color(0xFFE3F2FD)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPolaroid(String emoji, Color bgColor) {
    return Container(
      width: 80,
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(31),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Title with morph animation
              _buildTitleMorph(),
              const SizedBox(height: 16),
              // Subtitle
              Opacity(
                opacity: _subtitleReveal.value,
                child: Text(
                  'Memories written together...',
                  style: JournalFonts.loadingSubtitle,
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleMorph() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // "Your Journal" (fades out)
        Opacity(
          opacity: (1 - _titleMorph.value).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 1 - (_titleMorph.value * 0.1),
            child: Text(
              'Your Journal',
              style: JournalFonts.loadingTitleSerif,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // "Our Journal" (fades in)
        Opacity(
          opacity: _titleMorph.value,
          child: Transform.scale(
            scale: 0.9 + (_titleMorph.value * 0.1),
            child: Text(
              'Our Journal',
              style: JournalFonts.loadingTitleHandwritten,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for paper texture lines
class _PaperLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2D2D2D).withAlpha(15)
      ..strokeWidth = 1;

    const lineSpacing = 28.0;
    double y = lineSpacing;

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
