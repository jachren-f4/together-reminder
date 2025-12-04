import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:togetherremind/screens/auth_screen.dart';
import 'package:togetherremind/screens/name_entry_screen.dart';
import 'package:togetherremind/services/auth_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/widgets/newspaper/newspaper_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  /// Check if Apple Sign-In is available (iOS only for now)
  /// TODO: Set to true once Apple Developer Portal and Supabase are configured
  bool get _isAppleSignInAvailable {
    return false; // Disabled until portal configuration is complete
    // if (kIsWeb) return false;
    // return Platform.isIOS;
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithApple();

      if (!mounted) return;

      if (result['success'] == true) {
        // Navigate to name entry screen (which will check if name is already set)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const NameEntryScreen(),
          ),
        );
      } else if (result['cancelled'] != true) {
        // Show error only if not cancelled by user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleEmailSignIn() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
    );
  }

  /// Build the Apple Sign-In button using the official Apple style
  Widget _buildAppleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: SignInWithAppleButton(
        onPressed: _isLoading ? () {} : _handleAppleSignIn,
        style: SignInWithAppleButtonStyle.black,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        text: 'Continue with Apple',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NewspaperColors.surface,
      body: SafeArea(
          child: Column(
            children: [
              // Masthead
              const NewspaperMasthead(
                date: 'Est. 2024',
                title: 'TogetherRemind',
                subtitle: "The Couples' Daily Companion",
              ),

              // Edition bar
              const NewspaperEditionBar(
                left: 'First Edition',
                right: 'Your Love Story Begins',
              ),

              // Hero section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hero emoji with animation and grayscale
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: const GrayscaleEmoji(
                              emoji: '💕',
                              size: 100,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),

                      // Headline
                      Text(
                        'Send Caring Reminders\nTo Your Partner',
                        textAlign: TextAlign.center,
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                          color: NewspaperColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Subhead
                      Text(
                        'Build stronger connections through\ndaily moments of thoughtfulness',
                        textAlign: TextAlign.center,
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF555555),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // CTA section
              Container(
                padding: const EdgeInsets.fromLTRB(30, 24, 30, 40),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFDDDDDD),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Apple Sign-In button (iOS only) or Email button (other platforms)
                    if (_isAppleSignInAvailable)
                      _buildAppleSignInButton()
                    else
                      NewspaperPrimaryButton(
                        text: 'Continue with Email',
                        onPressed: _handleEmailSignIn,
                        isLoading: _isLoading,
                      ),
                    const SizedBox(height: 16),

                    // "Don't have Apple ID?" link (iOS only)
                    if (_isAppleSignInAvailable)
                      NewspaperSignInLink(
                        text: "No Apple ID?",
                        linkText: 'Use email instead',
                        onTap: _handleEmailSignIn,
                      ),

                    // Spacing between the two links
                    if (_isAppleSignInAvailable)
                      const SizedBox(height: 8),

                    // "Returning reader?" link
                    NewspaperSignInLink(
                      text: 'Returning reader?',
                      linkText: 'Sign in here',
                      onTap: _handleEmailSignIn,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }
}
