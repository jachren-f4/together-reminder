import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:togetherremind/screens/auth_screen.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/auth_service.dart';
import 'package:togetherremind/services/user_profile_service.dart';
import 'package:togetherremind/widgets/newspaper/newspaper_widgets.dart';

/// Full-screen name entry (Step 1 of 3) in newspaper style
class NameEntryScreen extends StatefulWidget {
  const NameEntryScreen({super.key});

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final _nameController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Check if user already has a name (returning user)
  Future<void> _checkExistingName() async {
    final authService = AuthService();
    final existingName = await authService.getDisplayName();

    if (existingName != null && existingName.isNotEmpty && mounted) {
      _nameController.text = existingName;
    }
  }

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final storageService = StorageService();

      if (authService.isAuthenticated) {
        // User is already authenticated (returning user with no name)
        // Update name via API and local storage
        final userProfileService = UserProfileService();
        await userProfileService.updateName(name);

        // Mark onboarding as completed
        await _secureStorage.write(key: 'has_completed_onboarding', value: 'true');

        if (mounted) {
          // Go back to root - AuthWrapper will show appropriate screen
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        // New user - store name temporarily until auth completes
        // Name will be passed to completeSignup() after OTP verification
        await _secureStorage.write(key: 'pending_user_name', value: name);

        // Also update local user if exists (for display purposes during auth)
        var user = storageService.getUser();
        if (user != null) {
          user.name = name;
          await storageService.saveUser(user);
        }

        // Mark onboarding as completed so user won't see it again
        await _secureStorage.write(key: 'has_completed_onboarding', value: 'true');

        if (mounted) {
          // Navigate to AuthScreen for login
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AuthScreen(),
            ),
          );
        }
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
                date: 'Registration',
                title: 'TogetherRemind',
                subtitle: 'Step 1 of 3',
              ),

              // Article header
              const NewspaperArticleHeader(
                kicker: 'Getting Started',
                headline: 'What shall we call you?',
                deck: 'Your name will appear to your partner when you send reminders',
              ),

              // Form content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NewspaperTextField(
                        controller: _nameController,
                        label: 'Your Name',
                        placeholder: 'Enter your first name',
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                        onSubmitted: (_) => _handleContinue(),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer with button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFDDDDDD),
                      width: 1,
                    ),
                  ),
                ),
                child: NewspaperPrimaryButton(
                  text: 'Continue',
                  onPressed: _handleContinue,
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
