import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/brand_config.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/auth_screen.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/auth_service.dart';
import 'package:togetherremind/widgets/newspaper/newspaper_widgets.dart';

/// Full-screen name entry (Step 1 of 3) in newspaper style
///
/// Only shown for new users. Returning users go directly to AuthScreen.
class NameEntryScreen extends StatefulWidget {
  /// Whether this is a new user signing up (true) or existing user (false)
  final bool isNewUser;

  const NameEntryScreen({
    super.key,
    this.isNewUser = true,  // Default to new user for backwards compatibility
  });

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

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
      final storageService = StorageService();

      // Store name temporarily until auth completes
      // Name will be passed to completeSignup() after OTP verification (or dev sign-in)
      await _secureStorage.write(key: 'pending_user_name', value: name);

      // Also update local user if exists (for display purposes during auth)
      var user = storageService.getUser();
      if (user != null) {
        user.name = name;
        await storageService.saveUser(user);
      }

      if (mounted) {
        // Navigate to AuthScreen, passing isNewUser forward
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AuthScreen(isNewUser: widget.isNewUser),
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
    if (_isUs2) return _buildUs2Screen();

    return Scaffold(
      body: Container(
        color: NewspaperColors.surface,
        child: SafeArea(
          child: Column(
            children: [
              // Masthead
              const NewspaperMasthead(
                date: 'Registration',
                title: 'Liia',
                subtitle: 'Step 1 of 3',
              ),

              // Article header
              const NewspaperArticleHeader(
                kicker: 'Getting Started',
                headline: 'What shall we call you?',
                deck: 'Your name will appear to your partner when you send reminders',
              ),

              // Form content - scrollable when keyboard opens
              Expanded(
                child: SingleChildScrollView(
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
                      // Add spacing to ensure content doesn't get covered by button
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // Footer with button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
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
                      // Large step number
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                        ).createShader(bounds),
                        child: Text(
                          '1',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 100,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),

                      // Step label
                      Text(
                        'of 3 steps',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Us2Theme.textMedium,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'What shall we call you?',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Us2Theme.textDark,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Your name will appear to your partner when you connect.',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          color: Us2Theme.textMedium,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Input label
                      Text(
                        'YOUR NAME',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Us2Theme.textMedium,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Text input
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                        enabled: !_isLoading,
                        onSubmitted: (_) => _handleContinue(),
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          color: Us2Theme.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your first name',
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
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: _buildUs2Button(
                  'Continue',
                  _isLoading ? null : _handleContinue,
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
