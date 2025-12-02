import 'package:flutter/material.dart';
import 'package:togetherremind/screens/name_entry_screen.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/widgets/newspaper/newspaper_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;

  Future<void> _handleGetStarted() async {
    setState(() => _isLoading = true);

    try {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NameEntryScreen(),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
                    NewspaperPrimaryButton(
                      text: 'Begin Your Story',
                      onPressed: _handleGetStarted,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                    NewspaperSignInLink(
                      text: 'Returning reader?',
                      linkText: 'Sign in here',
                      onTap: () {
                        // TODO: Navigate to sign in flow
                      },
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
