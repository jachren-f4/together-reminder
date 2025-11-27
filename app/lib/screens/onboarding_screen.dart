import 'package:flutter/material.dart';
import 'package:togetherremind/screens/pairing_screen.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/auth_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import 'package:togetherremind/models/user.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isLoading = false;

  /// Handle Get Started button press
  /// Checks if user is returning (has existing name) and skips name dialog if so
  Future<void> _handleGetStarted() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final existingName = await authService.getDisplayName();

      if (existingName != null && mounted) {
        // Returning user - skip name dialog, go directly to pairing
        debugPrint('👋 Welcome back, $existingName!');
        await _saveNameAndNavigate(existingName);
      } else if (mounted) {
        // New user - show name dialog
        _showNameDialog(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Save name to storage and navigate to pairing screen
  Future<void> _saveNameAndNavigate(String name) async {
    final storageService = StorageService();
    var user = storageService.getUser();

    if (user == null) {
      const uuid = Uuid();
      final userId = uuid.v4();
      final pushToken = 'simulator_token_$userId';

      user = User(
        id: userId,
        pushToken: pushToken,
        createdAt: DateTime.now(),
        name: name,
      );
    } else {
      user.name = name;
    }

    await storageService.saveUser(user);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const PairingScreen(),
        ),
      );
    }
  }

  void _showNameDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Text('👋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'What\'s your name?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderLight, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderLight, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryBlack, width: 2),
            ),
          ),
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              await _saveName(context, value.trim());
            }
          },
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await _saveName(context, nameController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlack,
                foregroundColor: AppTheme.primaryWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveName(BuildContext context, String name) async {
    final authService = AuthService();

    // Sync name to Supabase user metadata so other users can see it
    if (authService.isAuthenticated) {
      await authService.updateDisplayName(name);
    }

    if (context.mounted) {
      Navigator.of(context).pop(); // Close dialog
      await _saveNameAndNavigate(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Hero emoji with animation
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: value,
                              child: const Text(
                                '💕',
                                style: TextStyle(fontSize: 100),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // App name
                        Text(
                          'TogetherRemind',
                          style: AppTheme.headlineFont.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tagline
                        Text(
                          'Send caring reminders\nto your partner',
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 18,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),

                // Get Started button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleGetStarted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlack,
                      foregroundColor: AppTheme.primaryWhite,
                      elevation: 0,
                      shadowColor: AppTheme.primaryBlack.withAlpha((0.15 * 255).round()),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryWhite,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('💕', style: TextStyle(fontSize: 20)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
