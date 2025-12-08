import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';
import '../widgets/newspaper/newspaper_widgets.dart';

/// OTP Verification screen with newspaper styling
///
/// Users enter the 8-digit code from their email to complete sign in.
class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
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

      if (success) {
        // Complete signup on server - creates user profile and restores couple if exists
        try {
          final pushToken = await NotificationService.getToken();
          final userProfileService = UserProfileService();

          // Get pending name from name entry screen (if any)
          const secureStorage = FlutterSecureStorage();
          final pendingName = await secureStorage.read(key: 'pending_user_name');

          await userProfileService.completeSignup(
            pushToken: pushToken,
            name: pendingName,
          );
          Logger.success('Signup completed on server', service: 'auth');

          // Clear the pending name after successful signup
          if (pendingName != null) {
            await secureStorage.delete(key: 'pending_user_name');
          }
        } catch (e) {
          // Log but don't fail - user can still proceed
          Logger.error('Failed to complete signup on server', error: e, service: 'auth');
        }

        if (mounted) {
          // Clear entire navigation stack and return to root
          // This lets AuthWrapper re-evaluate auth state and show correct screen
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid code. Please check and try again.';
        });
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
    return Scaffold(
      body: Container(
        color: NewspaperColors.surface,
        child: SafeArea(
          child: Column(
            children: [
              // Masthead
              const NewspaperMasthead(
                date: 'Verification',
                title: 'TogetherRemind',
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
}
