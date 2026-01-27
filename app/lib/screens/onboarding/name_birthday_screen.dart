import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/auth_screen.dart';

/// Screen 04: Name + Birthday
///
/// Collects user's first name (required) and birthday (optional).
/// Data is stored in SharedPreferences pre-auth and synced after authentication.
///
/// Mockup: mockups/new-onboarding-flow/04-name-birthday.html
class NameBirthdayScreen extends StatefulWidget {
  /// When true, runs in preview mode for debug browser
  final bool previewMode;

  const NameBirthdayScreen({
    super.key,
    this.previewMode = false,
  });

  @override
  State<NameBirthdayScreen> createState() => _NameBirthdayScreenState();
}

class _NameBirthdayScreenState extends State<NameBirthdayScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  DateTime? _birthday;
  bool _isBirthdaySelected = false;

  bool get _isFormValid => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Auto-focus name input on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    // Default to 25 years ago
    final initialDate = DateTime.now().subtract(const Duration(days: 365 * 25));
    // Min age: 13 years, Max age: 120 years
    final firstDate = DateTime.now().subtract(const Duration(days: 365 * 120));
    final lastDate = DateTime.now().subtract(const Duration(days: 365 * 13));

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Us2Theme.gradientAccentStart,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Us2Theme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _birthday = picked;
        _isBirthdaySelected = true;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (!_isFormValid) return;

    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }

    // Store data in FlutterSecureStorage (pre-auth)
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'pending_user_name', value: _nameController.text.trim());
    if (_birthday != null) {
      await secureStorage.write(key: 'pending_user_birthday', value: _birthday!.toIso8601String());
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AuthScreen(isNewUser: true),
        ),
      );
    }
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Us2Theme.bgGradientStart, Us2Theme.bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header with back button
                  _buildHeader(),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Step indicator
                          _buildStepIndicator(),
                          const SizedBox(height: 24),

                          // Title
                          _buildTitle(),
                          const SizedBox(height: 32),

                          // Name field
                          _buildNameField(),
                          const SizedBox(height: 24),

                          // Birthday field
                          _buildBirthdayField(),
                        ],
                      ),
                    ),
                  ),

                  // Footer with continue button
                  _buildFooter(),
                ],
              ),

              // Preview mode banner
              if (widget.previewMode) _buildPreviewBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.gradientAccentStart.withOpacity(0.15),
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

  Widget _buildStepIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Text(
          'OF 3 STEPS',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Us2Theme.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      'Tell us about yourself',
      style: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Us2Theme.textDark,
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          textCapitalization: TextCapitalization.words,
          keyboardType: TextInputType.name,
          onChanged: (_) => setState(() {}),
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
            border: OutlineInputBorder(
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'YOUR BIRTHDAY',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Us2Theme.textMedium,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'OPTIONAL',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Us2Theme.textLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _selectBirthday,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 50, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Text(
                  _birthday != null
                      ? DateFormat('MMMM d, y').format(_birthday!)
                      : 'Select your birthday',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    color: _birthday != null
                        ? Us2Theme.textDark
                        : Us2Theme.textLight,
                  ),
                ),
                // Validation checkmark
                if (_isBirthdaySelected)
                  Positioned(
                    right: -34,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We will send you a special surprise on your birthday!',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: Us2Theme.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: GestureDetector(
        onTap: _isFormValid ? _handleContinue : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: _isFormValid
                ? const LinearGradient(
                    colors: [
                      Us2Theme.gradientAccentStart,
                      Us2Theme.gradientAccentEnd,
                    ],
                  )
                : null,
            color: _isFormValid ? null : Us2Theme.textLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isFormValid
                ? [
                    BoxShadow(
                      color: Us2Theme.gradientAccentStart.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            'Continue',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBanner() {
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'PREVIEW MODE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
