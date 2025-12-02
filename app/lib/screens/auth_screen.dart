import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';
import '../widgets/newspaper/newspaper_widgets.dart';
import 'otp_verification_screen.dart';

/// Authentication screen for sign up / sign in with newspaper styling
///
/// Users enter their email and receive a magic link or OTP code.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

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

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.signInWithMagicLink(email);

      if (success) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(email: email),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to send verification code. Please try again.';
        });
      }
    } catch (e) {
      Logger.error('Error sending magic link', error: e);
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
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFDDDDDD),
                      width: 1,
                    ),
                  ),
                ),
                child: NewspaperPrimaryButton(
                  text: 'Send Verification Code',
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
}
