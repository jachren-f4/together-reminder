import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/brand_config.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/notification_service.dart';
import '../services/app_bootstrap_service.dart';
import '../utils/logger.dart';
import '../widgets/newspaper/newspaper_widgets.dart';
import 'pairing_screen.dart';
import 'main_screen.dart';

/// OTP Verification screen with newspaper styling
///
/// Users enter the 8-digit code from their email to complete sign in.
class OtpVerificationScreen extends StatefulWidget {
  final String email;

  /// Whether this is a new user signing up (true) or returning user (false)
  final bool isNewUser;

  /// Whether this verification was triggered from Settings (account verification)
  /// When true, just pops back to Settings on success instead of navigating elsewhere
  final bool isFromSettings;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isNewUser = true,  // Default to new user for backwards compatibility
    this.isFromSettings = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  final _otpController = TextEditingController();
  final _authService = AuthService();
  final _focusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 8) {
      setState(() {
        _errorMessage = 'Please enter the 8-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.verifyOTP(widget.email, otp);

      if (!success) {
        setState(() {
          _errorMessage = 'Invalid code. Please check and try again.';
        });
        return;  // BLOCK - don't continue
      }

      if (!mounted) return;

      // If this is from Settings (account verification), just pop back with success
      if (widget.isFromSettings) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      if (widget.isNewUser) {
        // New user - complete signup with stored name
        const secureStorage = FlutterSecureStorage();
        final pendingName = await secureStorage.read(key: 'pending_user_name');

        if (pendingName == null || pendingName.isEmpty) {
          setState(() {
            _errorMessage = 'Name not found. Please restart signup.';
          });
          return;  // BLOCK - don't continue without name
        }

        try {
          final pushToken = await NotificationService.getToken();
          final userProfileService = UserProfileService();

          await userProfileService.completeSignup(
            pushToken: pushToken,
            name: pendingName,
          );
          Logger.success('Signup completed on server', service: 'auth');

          // Clear the pending name after successful signup
          await secureStorage.delete(key: 'pending_user_name');

          // Mark onboarding as completed
          await secureStorage.write(key: 'has_completed_onboarding', value: 'true');
        } catch (e) {
          Logger.error('Failed to complete signup on server', error: e, service: 'auth');
          setState(() {
            _errorMessage = 'Failed to complete signup. Please try again.';
          });
          return;  // BLOCK - don't continue if signup fails
        }

        if (!mounted) return;

        // New user - go to pairing screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PairingScreen()),
          (route) => false,
        );
      } else {
        // Returning user - sync profile and bootstrap before going to home
        try {
          final pushToken = await NotificationService.getToken();
          final userProfileService = UserProfileService();

          // Complete signup syncs the user profile with server (restores couple if exists)
          final result = await userProfileService.completeSignup(
            pushToken: pushToken,
          );
          Logger.success('Profile synced: paired=${result.isPaired}', service: 'auth');

          // Save coupleId if paired
          if (result.isPaired && result.coupleId != null) {
            const secureStorage = FlutterSecureStorage();
            await secureStorage.write(key: 'couple_id', value: result.coupleId!);

            // Bootstrap handles LP sync, quest sync, unlock state, and polling
            await AppBootstrapService.instance.bootstrap();
            Logger.success('Bootstrap completed for returning user', service: 'auth');
          }
        } catch (e) {
          // Log but don't block for returning users - they can still proceed
          Logger.error('Failed to sync profile on server', error: e, service: 'auth');
        }

        if (!mounted) return;

        // Returning user - go to home (with bottom nav)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      Logger.error('Error verifying OTP', error: e);
      setState(() {
        _errorMessage = 'Verification failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.signInWithMagicLink(widget.email);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New code sent! Check your email.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to resend code. Please try again.';
        });
      }
    } catch (e) {
      Logger.error('Error resending OTP', error: e);
      setState(() {
        _errorMessage = 'Failed to resend code.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                subtitle: 'Almost There',
              ),

              // Article header
              NewspaperArticleHeader(
                kicker: 'Confirmation Required',
                headline: 'Check your inbox',
                deck: 'Enter the 8-digit code sent to\n${widget.email}',
              ),

              // OTP content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // OTP boxes display
                      _buildOtpBoxes(),

                      const SizedBox(height: 16),

                      // Hidden text field for input
                      Opacity(
                        opacity: 0,
                        child: SizedBox(
                          height: 1,
                          child: TextField(
                            controller: _otpController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            enabled: !_isLoading,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              setState(() {});
                              if (value.length == 8) {
                                _verifyOtp();
                              }
                            },
                          ),
                        ),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            border: Border(
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

                      // Resend link
                      NewspaperSignInLink(
                        text: "Didn't receive it?",
                        linkText: 'Request new code',
                        onTap: _isLoading ? null : _resendCode,
                      ),
                    ],
                  ),
                ),
              ),

              // Footer with button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFDDDDDD),
                      width: 1,
                    ),
                  ),
                ),
                child: NewspaperPrimaryButton(
                  text: 'Verify Code',
                  onPressed: _verifyOtp,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBoxes() {
    final digits = _otpController.text.split('');

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(8, (index) {
          final digit = index < digits.length ? digits[index] : null;
          final isActive = index == digits.length && _focusNode.hasFocus;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: OtpBox(
                digit: digit,
                isActive: isActive,
              ),
            ),
          );
        }),
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
                    crossAxisAlignment: widget.isNewUser ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      // Large step number (only for returning users / sign-in flow)
                      if (!widget.isNewUser) ...[
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                          ).createShader(bounds),
                          child: Text(
                            '2',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 100,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                        Text(
                          'of 2 steps',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: Us2Theme.textMedium,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Title
                      Text(
                        'Check your inbox',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Us2Theme.textDark,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Enter the 8-digit code sent to',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          color: Us2Theme.textMedium,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        widget.email,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Us2Theme.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // OTP Boxes
                      _buildUs2OtpBoxes(),

                      // Hidden text field for input
                      Opacity(
                        opacity: 0,
                        child: SizedBox(
                          height: 1,
                          child: TextField(
                            controller: _otpController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            enabled: !_isLoading,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              setState(() {});
                              if (value.length == 8) {
                                _verifyOtp();
                              }
                            },
                          ),
                        ),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE53935).withValues(alpha: 0.3),
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

                      // Resend link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive it? ",
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Us2Theme.textMedium,
                            ),
                          ),
                          GestureDetector(
                            onTap: _isLoading ? null : _resendCode,
                            child: Text(
                              'Request new code',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _isLoading
                                    ? Us2Theme.textLight
                                    : Us2Theme.primaryBrandPink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: _buildUs2Button(
                  'Verify Code',
                  _isLoading ? null : _verifyOtp,
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
        ],
      ),
    );
  }

  Widget _buildUs2OtpBoxes() {
    final digits = _otpController.text.split('');

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(8, (index) {
          final digit = index < digits.length ? digits[index] : null;
          final isActive = index == digits.length && _focusNode.hasFocus;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? Us2Theme.primaryBrandPink
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? Us2Theme.glowPink.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: isActive ? 12 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: digit != null
                      ? Text(
                          digit,
                          style: GoogleFonts.nunito(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Us2Theme.textDark,
                          ),
                        )
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Us2Theme.textLight.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
            ),
          );
        }),
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
