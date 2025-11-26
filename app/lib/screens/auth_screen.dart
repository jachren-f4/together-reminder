import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';
import 'otp_verification_screen.dart';

/// Authentication screen for sign up / sign in
///
/// Users enter their email and receive a magic link or OTP code.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final success = await _authService.signInWithMagicLink(email);

      if (success) {
        if (mounted) {
          // Navigate to OTP verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(email: email),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to send magic link. Please try again.';
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // Logo/Title
              Icon(
                Icons.favorite,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              Text(
                'TogetherRemind',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'Stay connected with your partner',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: BrandLoader().colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Email form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter your email to get started',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      enabled: !_isLoading,
                      validator: _validateEmail,
                      onFieldSubmitted: (_) => _sendMagicLink(),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: BrandLoader().colors.surface,
                      ),
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

                    // Submit button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendMagicLink,
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
                              'Continue with Email',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BrandLoader().colors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: BrandLoader().colors.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We\'ll send you a magic link to sign in. No password needed!',
                        style: TextStyle(color: BrandLoader().colors.info),
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
