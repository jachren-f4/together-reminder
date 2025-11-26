import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/brand/brand_loader.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// OTP Verification screen
///
/// Users enter the 6-digit code from their email to complete sign in.
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
    // Auto-focus the OTP field
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
        if (mounted) {
          // Pop back to root and let the app rebuild with authenticated state
          Navigator.of(context).popUntil((route) => route.isFirst);
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
      appBar: AppBar(
        title: const Text('Verify Email'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Email icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Check your email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'We sent a verification code to',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: BrandLoader().colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              Text(
                widget.email,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // OTP input
              TextField(
                controller: _otpController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 8,
                enabled: !_isLoading,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '00000000',
                  hintStyle: TextStyle(
                    color: BrandLoader().colors.textTertiary,
                    fontSize: 24,
                    letterSpacing: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: BrandLoader().colors.surface,
                ),
                onChanged: (value) {
                  // Auto-submit when 8 digits entered
                  if (value.length == 8) {
                    _verifyOtp();
                  }
                },
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BrandLoader().colors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: BrandLoader().colors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: BrandLoader().colors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Verify button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Verify Code',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 24),

              // Resend code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(color: BrandLoader().colors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _resendCode,
                    child: const Text('Resend'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Help text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BrandLoader().colors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: BrandLoader().colors.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Can\'t find the email?',
                          style: TextStyle(
                            color: BrandLoader().colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Check your spam/junk folder\n• Make sure you entered the correct email\n• Wait a few minutes and try again',
                      style: TextStyle(
                        color: BrandLoader().colors.textSecondary,
                        fontSize: 13,
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
}
