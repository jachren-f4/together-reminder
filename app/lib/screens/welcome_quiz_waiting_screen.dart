import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../services/welcome_quiz_service.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';
import '../widgets/animations/animations.dart';
import '../widgets/editorial/editorial.dart';
import 'welcome_quiz_results_screen.dart';

/// Waiting screen shown when user completes Welcome Quiz before partner.
///
/// IMPORTANT: Does NOT show LP badges - LP hasn't been introduced yet at this point.
/// Shows preview of upcoming features without "+30 LP" rewards.
class WelcomeQuizWaitingScreen extends StatefulWidget {
  const WelcomeQuizWaitingScreen({super.key});

  @override
  State<WelcomeQuizWaitingScreen> createState() =>
      _WelcomeQuizWaitingScreenState();
}

class _WelcomeQuizWaitingScreenState extends State<WelcomeQuizWaitingScreen>
    with DramaticScreenMixin {
  final WelcomeQuizService _service = WelcomeQuizService();
  Timer? _pollTimer;
  bool _isPolling = false;

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  bool get enableConfetti => false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPartnerCompletion();
    });
    // Also check immediately
    _checkPartnerCompletion();
  }

  Future<void> _checkPartnerCompletion() async {
    if (_isPolling) return;

    _isPolling = true;
    Logger.debug('📡 Polling for partner completion...', service: 'welcome_quiz');
    try {
      final data = await _service.getQuizData();
      Logger.debug('📡 Poll response: data=${data != null}, status=${data?.status}, bothCompleted=${data?.status.bothCompleted}, hasResults=${data?.results != null}', service: 'welcome_quiz');

      if (!mounted) return;

      if (data != null && data.status.bothCompleted && data.results != null) {
        // Partner completed - navigate to results
        _pollTimer?.cancel();

        triggerFlash();
        triggerConfetti();

        await Future.delayed(const Duration(milliseconds: 300));

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WelcomeQuizResultsScreen(
              results: data.results!,
            ),
          ),
        );
      }
    } catch (e) {
      Logger.warn('Error checking partner completion: $e',
          service: 'welcome_quiz');
    } finally {
      _isPolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Screen();

    final partner = StorageService().getPartner();
    final partnerName = partner?.name ?? 'your partner';

    return wrapWithDramaticEffects(
      Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Animated hourglass
                  BounceInWidget(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: EditorialStyles.fullBorder,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _PulsingEmoji(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  BounceInWidget(
                    delay: const Duration(milliseconds: 400),
                    child: Text(
                      'Waiting for $partnerName',
                      style: EditorialStyles.headline.copyWith(
                        fontSize: 28,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  BounceInWidget(
                    delay: const Duration(milliseconds: 600),
                    child: Text(
                      "You've completed your part! $partnerName needs to finish the Welcome Quiz to unlock your first activities together.",
                      style: EditorialStyles.bodyText.copyWith(
                        height: 1.5,
                        color: EditorialStyles.ink.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Progress checklist
                  BounceInWidget(
                    delay: const Duration(milliseconds: 800),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: EditorialStyles.fullBorder,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildChecklistItem(
                            'You completed',
                            isComplete: true,
                          ),
                          const SizedBox(height: 12),
                          _buildChecklistItem(
                            '$partnerName in progress...',
                            isComplete: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Coming up next preview - NO LP shown!
                  BounceInWidget(
                    delay: const Duration(milliseconds: 1000),
                    child: Column(
                      children: [
                        Text(
                          'COMING UP NEXT',
                          style: EditorialStyles.labelUppercase.copyWith(
                            letterSpacing: 2,
                            color: EditorialStyles.ink.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeaturePreview(
                          'Classic Quiz',
                          'Test how well you know each other',
                        ),
                        const SizedBox(height: 8),
                        _buildFeaturePreview(
                          'Affirmation Quiz',
                          'Celebrate your relationship',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Nudge tip
                  BounceInWidget(
                    delay: const Duration(milliseconds: 1200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: EditorialStyles.ink.withOpacity(0.05),
                        border: EditorialStyles.fullBorder,
                      ),
                      child: Row(
                        children: [
                          ColorFiltered(
                            colorFilter: const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                            child: const Text(
                              '💡',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Send a gentle reminder to complete the quiz',
                              style: EditorialStyles.bodyText.copyWith(
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String text, {required bool isComplete}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete ? EditorialStyles.ink : Colors.transparent,
            border: Border.all(
              color: EditorialStyles.ink,
              width: 2,
            ),
          ),
          child: isComplete
              ? Icon(
                  Icons.check,
                  size: 14,
                  color: EditorialStyles.paper,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: EditorialStyles.bodyText.copyWith(
              color: isComplete
                  ? EditorialStyles.ink
                  : EditorialStyles.ink.withOpacity(0.5),
            ),
          ),
        ),
        if (!isComplete) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                EditorialStyles.ink.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeaturePreview(String title, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: EditorialStyles.ink.withOpacity(0.2),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: EditorialStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: EditorialStyles.bodyText.copyWith(
                    fontSize: 14,
                    color: EditorialStyles.ink.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          // Note: NO LP badge here - LP not introduced yet
        ],
      ),
    );
  }

  // ===========================================
  // Us 2.0 Implementation
  // ===========================================

  Widget _buildUs2Screen() {
    final partner = StorageService().getPartner();
    final partnerName = partner?.name ?? 'your partner';

    return wrapWithDramaticEffects(
      Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: Us2Theme.backgroundGradient,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Animated hourglass emoji
                  _buildUs2EmojiCircle(),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Waiting for $partnerName',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    "You've completed your part! $partnerName needs to finish the Welcome Quiz to unlock your first activities together.",
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      color: Us2Theme.textMedium,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Progress checklist
                  _buildUs2Checklist(partnerName),

                  const SizedBox(height: 32),

                  // Coming up next
                  _buildUs2ComingUpNext(),

                  const SizedBox(height: 32),

                  // Tip box
                  _buildUs2TipBox(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUs2EmojiCircle() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Us2Theme.glowPink.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: _Us2PulsingEmoji(),
      ),
    );
  }

  Widget _buildUs2Checklist(String partnerName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildUs2ChecklistItem('You completed', isComplete: true),
          const SizedBox(height: 12),
          _buildUs2ChecklistItem('$partnerName in progress...', isComplete: false),
        ],
      ),
    );
  }

  Widget _buildUs2ChecklistItem(String text, {required bool isComplete}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isComplete ? Us2Theme.accentGradient : null,
            border: isComplete
                ? null
                : Border.all(color: Us2Theme.primaryBrandPink, width: 2),
          ),
          child: isComplete
              ? const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: isComplete ? Us2Theme.textDark : Us2Theme.textLight,
            ),
          ),
        ),
        if (!isComplete) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Us2Theme.primaryBrandPink.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUs2ComingUpNext() {
    return Column(
      children: [
        Text(
          'COMING UP NEXT',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Us2Theme.textLight,
          ),
        ),
        const SizedBox(height: 16),
        _buildUs2FeaturePreview('Classic Quiz', 'Test how well you know each other'),
        const SizedBox(height: 8),
        _buildUs2FeaturePreview('Affirmation Quiz', 'Celebrate your relationship'),
      ],
    );
  }

  Widget _buildUs2FeaturePreview(String title, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Us2Theme.primaryBrandPink,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Us2Theme.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2TipBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Send a gentle reminder to complete the quiz',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Us2Theme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple pulsing animation widget for the hourglass emoji (Liia style)
class _PulsingEmoji extends StatefulWidget {
  @override
  State<_PulsingEmoji> createState() => _PulsingEmojiState();
}

class _PulsingEmojiState extends State<_PulsingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: const Text(
          '⏳',
          style: TextStyle(fontSize: 48),
        ),
      ),
    );
  }
}

/// Pulsing animation widget for the hourglass emoji (Us 2.0 style - with color)
class _Us2PulsingEmoji extends StatefulWidget {
  const _Us2PulsingEmoji();

  @override
  State<_Us2PulsingEmoji> createState() => _Us2PulsingEmojiState();
}

class _Us2PulsingEmojiState extends State<_Us2PulsingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: const Text(
        '⏳',
        style: TextStyle(fontSize: 48),
      ),
    );
  }
}
