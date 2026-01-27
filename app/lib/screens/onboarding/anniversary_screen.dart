import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/pairing_screen.dart';

/// Screen 07: Anniversary Date
///
/// Optional anniversary date collection with contextual encouragement
/// based on relationship length. Skip button available.
///
/// Mockup: mockups/new-onboarding-flow/07-anniversary.html
class AnniversaryScreen extends StatefulWidget {
  /// When true, runs in preview mode for debug browser
  final bool previewMode;

  const AnniversaryScreen({
    super.key,
    this.previewMode = false,
  });

  @override
  State<AnniversaryScreen> createState() => _AnniversaryScreenState();
}

class _AnniversaryScreenState extends State<AnniversaryScreen> {
  DateTime? _anniversaryDate;
  bool _isDateSelected = false;

  Future<void> _selectDate() async {
    // Default to 1 year ago
    final initialDate = DateTime.now().subtract(const Duration(days: 365));
    // Max date: today, Min date: 100 years ago
    final firstDate = DateTime.now().subtract(const Duration(days: 365 * 100));
    final lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _anniversaryDate ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Us2Theme.gradientAccentStart,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Us2Theme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _anniversaryDate = picked;
        _isDateSelected = true;
      });
    }
  }

  /// Get dynamic encouragement message based on relationship length
  Map<String, String> _getEncouragement() {
    if (_anniversaryDate == null) {
      return {'title': '', 'message': ''};
    }

    final years = DateTime.now().difference(_anniversaryDate!).inDays / 365.25;

    if (years < 1) {
      return {
        'title': 'We love to see it!',
        'message':
            'Building good habits early in your relationship is amazing. You are starting on the right path!',
      };
    } else if (years < 5) {
      return {
        'title': 'Worth celebrating!',
        'message':
            "That's worth celebrating! We'll make sure you never miss an anniversary.",
      };
    } else if (years < 10) {
      return {
        'title': 'Relationship goals!',
        'message':
            'Half a decade of love! Your commitment to growing together is inspiring.',
      };
    } else {
      return {
        'title': 'A decade of love!',
        'message':
            'What an incredible journey! We are honored to be part of your continued growth together.',
      };
    }
  }

  Future<void> _handleContinue() async {
    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }

    // Save anniversary date to FlutterSecureStorage (will be synced after pairing)
    if (_anniversaryDate != null) {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'pending_anniversary_date', value: _anniversaryDate!.toIso8601String());
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const PairingScreen(),
        ),
      );
    }
  }

  void _handleSkip() {
    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PairingScreen(),
      ),
    );
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Us2Theme.bgGradientStart, Us2Theme.bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header
                  _buildHeader(),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Hearts illustration
                          _buildHeartsIllustration(),
                          const SizedBox(height: 32),

                          // Title
                          _buildTitle(),
                          const SizedBox(height: 12),

                          // Subtitle
                          _buildSubtitle(),
                          const SizedBox(height: 32),

                          // Date field
                          _buildDateField(),

                          // Encouragement card
                          if (_isDateSelected) ...[
                            const SizedBox(height: 24),
                            _buildEncouragementCard(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  _buildFooter(),
                ],
              ),

              // Preview mode banner
              if (widget.previewMode) _buildPreviewBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _handleBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.gradientAccentStart.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Us2Theme.textDark,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: _handleSkip,
            child: Text(
              'Skip',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textMedium,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartsIllustration() {
    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // First heart (smaller, rotated left)
          Transform.rotate(
            angle: -0.26, // -15 degrees
            child: _buildGradientHeart(60),
          ),
          // Second heart (larger, rotated right, overlapping)
          Transform.translate(
            offset: const Offset(-20, 0),
            child: Transform.rotate(
              angle: 0.175, // 10 degrees
              child: _buildGradientHeart(70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeart(double size) {
    return Stack(
      children: [
        // Shadow layer (slightly offset, blurred)
        Positioned(
          top: 4,
          child: Icon(
            Icons.favorite,
            size: size,
            color: Us2Theme.gradientAccentStart.withOpacity(0.3),
          ),
        ),
        // Gradient heart on top
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
          ).createShader(bounds),
          child: Icon(
            Icons.favorite,
            size: size,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      'When did you become a couple?',
      textAlign: TextAlign.center,
      style: GoogleFonts.playfairDisplay(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: Us2Theme.textDark,
        height: 1.3,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'We will remind you to celebrate your anniversary every year!',
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(
        fontSize: 15,
        color: Us2Theme.textMedium,
        height: 1.6,
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ANNIVERSARY DATE',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Us2Theme.textMedium,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'OPTIONAL',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Us2Theme.textLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 50, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Text(
                  _anniversaryDate != null
                      ? DateFormat('MMMM d, y').format(_anniversaryDate!)
                      : 'Select your anniversary',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    color: _anniversaryDate != null
                        ? Us2Theme.textDark
                        : Us2Theme.textLight,
                  ),
                ),
                // Validation checkmark
                if (_isDateSelected)
                  Positioned(
                    right: -34,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEncouragementCard() {
    final encouragement = _getEncouragement();

    return AnimatedOpacity(
      opacity: _isDateSelected ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Us2Theme.cream, Colors.white],
          ),
          borderRadius: BorderRadius.circular(16),
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
                    gradient: const LinearGradient(
                      colors: [
                        Us2Theme.gradientAccentStart,
                        Us2Theme.gradientAccentEnd,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  encouragement['title']!,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              encouragement['message']!,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Us2Theme.textMedium,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: GestureDetector(
        onTap: _handleContinue,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Us2Theme.gradientAccentStart,
                Us2Theme.gradientAccentEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Us2Theme.gradientAccentStart.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            'Continue',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBanner() {
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'PREVIEW MODE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
