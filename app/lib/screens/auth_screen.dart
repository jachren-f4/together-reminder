import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/us2_theme.dart';
import '../config/dev_config.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/notification_service.dart';
import '../services/app_bootstrap_service.dart';
import '../utils/logger.dart';
import '../widgets/newspaper/newspaper_widgets.dart';
import 'otp_verification_screen.dart';
import 'pairing_screen.dart';
import 'main_screen.dart';

/// Authentication screen for sign up / sign in with newspaper styling
///
/// Users enter their email and receive a magic link or OTP code.
class AuthScreen extends StatefulWidget {
  /// Whether this is a new user signing up (true) or returning user (false)
  final bool isNewUser;

  const AuthScreen({
    super.key,
    this.isNewUser = true,  // Default to new user for backwards compatibility
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  final _emailController = TextEditingController();
  final _authService = AuthService();
  final _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with random test email when OTP bypass is enabled
    // Works in both debug and release builds for faster testing
    if (DevConfig.skipOtpVerificationInDev) {
      final random = DateTime.now().millisecondsSinceEpoch % 10000;
      _emailController.text = 'test$random@dev.test';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim().toLowerCase();

    // Validate email
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }

    // Skip email format validation in dev mode for faster testing
    if (!DevConfig.skipOtpVerificationInDev) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        setState(() {
          _errorMessage = 'Please enter a valid email';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if OTP bypass is enabled
      if (DevConfig.skipOtpVerificationInDev) {
        await _handleDevModeSignIn(email);
      } else {
        await _handleProductionSignIn(email);
      }
    } catch (e) {
      Logger.error('Error in auth flow', error: e);
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Dev mode: Sign in directly without OTP verification
  Future<void> _handleDevModeSignIn(String email) async {
    final success = await _authService.devSignInWithEmail(email);

    if (!success) {
      setState(() {
        _errorMessage = 'Dev sign-in failed. Please try again.';
      });
      return;
    }

    if (!mounted) return;

    if (widget.isNewUser) {
      // New user in dev mode - complete signup with stored name
      final pendingName = await _secureStorage.read(key: 'pending_user_name');
      if (pendingName != null && pendingName.isNotEmpty) {
        try {
          final pushToken = await NotificationService.getToken();
          final userProfileService = UserProfileService();
          await userProfileService.completeSignup(
            pushToken: pushToken,
            name: pendingName,
          );
          await _secureStorage.delete(key: 'pending_user_name');
          Logger.success('Signup completed on server (dev mode)', service: 'auth');
        } catch (e) {
          Logger.error('Failed to complete signup on server (dev mode)', error: e, service: 'auth');
          // Don't block - user can proceed in dev mode
        }
      }

      // Mark onboarding as completed
      await _secureStorage.write(key: 'has_completed_onboarding', value: 'true');

      if (!mounted) return;

      // New user - go to pairing screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const PairingScreen()),
        (route) => false,
      );
    } else {
      // Returning user in dev mode - restore profile from server first
      try {
        final userProfileService = UserProfileService();
        final result = await userProfileService.getProfile();
        Logger.success('Profile restored: ${result.user.name}, paired: ${result.isPaired}', service: 'auth');

        // Save couple_id if user is paired
        if (result.isPaired && result.coupleId != null) {
          await _secureStorage.write(key: 'couple_id', value: result.coupleId!);

          // Bootstrap handles LP sync, quest sync, unlock state, and polling
          await AppBootstrapService.instance.bootstrap();
          Logger.success('Bootstrap completed for returning user', service: 'auth');
        }
      } catch (e) {
        Logger.error('Failed to restore profile (dev mode)', error: e, service: 'auth');
        // Don't block - user can try to proceed
      }

      if (!mounted) return;

      // Returning user - go to home (with bottom nav)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false,
      );
    }
  }

  /// Production mode: Send OTP and navigate to verification screen
  Future<void> _handleProductionSignIn(String email) async {
    final success = await _authService.signInWithMagicLink(email);

    if (success) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              email: email,
              isNewUser: widget.isNewUser,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = 'Failed to send verification code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Screen();

    return Scaffold(
      body: Container(
        color: NewspaperColors.surface,
        child: SafeArea(
              child: Column(
                children: [
                  // Masthead
                  const NewspaperMasthead(
                    date: 'Verification',
                    title: 'Liia',
                    subtitle: 'Step 2 of 3',
                  ),

                  // Article header
                  const NewspaperArticleHeader(
                    kicker: 'Secure Access',
                    headline: 'Your email address',
                    deck: "We'll send a secure code to verify your identity",
                  ),

                  // Form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NewspaperTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            placeholder: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            onSubmitted: (_) => _sendMagicLink(),
                          ),

                          // Error message
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                border: const Border(
                                  left: BorderSide(
                                    color: Color(0xFFE53935),
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const GrayscaleEmoji(emoji: '⚠️', size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFE53935),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Editor's Note callout
                          const NewspaperCalloutBox(
                            title: "Editor's Note",
                            text: 'No password required. We use a magic code system for enhanced security.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer with button
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: const BoxDecoration(
                      color: NewspaperColors.surface,
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFFDDDDDD),
                          width: 1,
                        ),
                      ),
                    ),
                    child: NewspaperPrimaryButton(
                      text: DevConfig.skipOtpVerificationInDev
                          ? 'Continue (Dev Mode)'
                          : 'Send Verification Code',
                      onPressed: _sendMagicLink,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ============================================
  // Us 2.0 Brand Implementation
  // ============================================

  Widget _buildUs2Screen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: Us2Theme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildUs2Header(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Us2Theme.glowPink.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('📧', style: TextStyle(fontSize: 36)),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Your email address',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Us2Theme.textDark,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        "We'll send a secure code to verify your identity",
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          color: Us2Theme.textMedium,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Input label
                      Text(
                        'EMAIL ADDRESS',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Us2Theme.textMedium,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Email input
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        onSubmitted: (_) => _sendMagicLink(),
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          color: Us2Theme.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'you@example.com',
                          hintStyle: GoogleFonts.nunito(
                            fontSize: 18,
                            color: Us2Theme.textLight,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Us2Theme.primaryBrandPink,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                            border: const Border(
                              left: BorderSide(
                                color: Color(0xFFE53935),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('⚠️', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    color: const Color(0xFFE53935),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: const Border(
                            left: BorderSide(
                              color: Us2Theme.gradientAccentEnd,
                              width: 4,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '✨ No password needed',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Us2Theme.gradientAccentEnd,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'We use a magic code system for enhanced security. Just check your email!',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: Us2Theme.textMedium,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: _buildUs2Button(
                  DevConfig.skipOtpVerificationInDev
                      ? 'Continue (Dev Mode)'
                      : 'Send Verification Code',
                  _isLoading ? null : _sendMagicLink,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.primaryBrandPink.withValues(alpha: 0.15),
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
          const Spacer(),
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step 2 of 3',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textMedium,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // Balance
        ],
      ),
    );
  }

  Widget _buildUs2Button(String label, VoidCallback? onPressed, {bool isLoading = false}) {
    final isDisabled = onPressed == null || isLoading;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisabled
                ? [
                    Us2Theme.gradientAccentStart.withValues(alpha: 0.4),
                    Us2Theme.gradientAccentEnd.withValues(alpha: 0.4),
                  ]
                : [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: Us2Theme.glowPink.withValues(alpha: 0.5),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
