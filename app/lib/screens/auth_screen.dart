import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/dev_config.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/notification_service.dart';
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
      // Check if OTP bypass is enabled
      if (DevConfig.skipOtpVerificationInDev) {
        // Dev mode: Sign in directly without OTP
        final success = await _authService.devSignInWithEmail(email);

        if (success) {
          // Complete signup on server - same as OTP flow
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
            Logger.success('Dev signup completed on server', service: 'auth');

            // Clear the pending name after successful signup
            if (pendingName != null) {
              await secureStorage.delete(key: 'pending_user_name');
            }
          } catch (e) {
            // Log but don't fail - user can still proceed
            Logger.error('Failed to complete dev signup on server', error: e, service: 'auth');
          }

          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        } else {
          setState(() {
            _errorMessage = 'Dev sign-in failed. Please try again.';
            _isLoading = false;
          });
          return;
        }
      } else {
        // Normal mode: Send OTP and navigate to verification screen
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
}
