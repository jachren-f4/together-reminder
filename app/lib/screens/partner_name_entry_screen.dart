import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/screens/onboarding/anniversary_screen.dart';
import 'package:togetherremind/services/phantom_partner_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/utils/logger.dart';

/// Partner name entry screen for single-phone mode.
///
/// Shown after authentication for new users. Creates a phantom partner
/// via the API and navigates to AnniversaryScreen on success.
///
/// Follows mockup: mockups/us20variants/single-mode/partner-name-entry.html
class PartnerNameEntryScreen extends StatefulWidget {
  const PartnerNameEntryScreen({super.key});

  @override
  State<PartnerNameEntryScreen> createState() => _PartnerNameEntryScreenState();
}

class _PartnerNameEntryScreenState extends State<PartnerNameEntryScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _showSuccess = false;
  String? _errorMessage;

  // Animation for floating icon
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await PhantomPartnerService().createPhantomPartner(name);

      if (!mounted) return;

      setState(() {
        _showSuccess = true;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to create phantom partner', error: e, service: 'partnerNameEntry');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  void _handleNext() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AnniversaryScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD1C1), Color(0xFFFFF5F0)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _buildFormContent(),
              if (_showSuccess) _buildSuccessOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      children: [
        // Nav row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text(
                  '\u2190 Back',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5A5A5A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Step 3 of 6',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF707070),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Floating heart icon
                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  "What's your partner's name?",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A3A3A),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                // Subtitle
                SizedBox(
                  width: 280,
                  child: Text(
                    "You'll play together on this phone. No download needed!",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: const Color(0xFF5A5A5A),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // Text field
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3A3A3A),
                  ),
                  decoration: InputDecoration(
                    hintText: "Partner's name",
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF707070),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF5E62),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: const Color(0xFFFF5E62),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Continue button
                GestureDetector(
                  onTap: _nameController.text.trim().isNotEmpty && !_isLoading
                      ? _handleContinue
                      : null,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _nameController.text.trim().isNotEmpty && !_isLoading
                        ? 1.0
                        : 0.5,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Continue',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Badge chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'One phone, two players, zero friction',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5A5A5A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessOverlay() {
    final userName = StorageService().getUser()?.name ?? 'You';
    final partnerName = _nameController.text.trim();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _showSuccess ? 1.0 : 0.0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD1C1), Color(0xFFFFF5F0)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Confetti (simple implementation)
              _ConfettiEffect(show: _showSuccess),

              // Avatars row
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User avatar
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 24,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'Y',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userName,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3A3A3A),
                          ),
                        ),
                      ],
                    ),

                    // Heart between
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(scale: value, child: child);
                        },
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Partner avatar
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF6C9CE9), Color(0xFF45B7D1)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 24,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          partnerName,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3A3A3A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Success text
              Text(
                "Perfect! Let's get started",
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3A3A),
                ),
              ),

              const SizedBox(height: 32),

              // Next button
              GestureDetector(
                onTap: _handleNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    'Next \u2192',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple confetti effect widget
class _ConfettiEffect extends StatelessWidget {
  final bool show;
  const _ConfettiEffect({required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    // Confetti is decorative - rendered as colored dots scattered around
    // In a real implementation, use a confetti package. Keeping simple for now.
    return const SizedBox.shrink();
  }
}
