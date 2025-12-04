import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/dev_config.dart';
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

  // Debug log for dev mode
  final List<String> _debugLogs = [];
  bool _showDebugOverlay = false;

  void _addLog(String message) {
    setState(() {
      _debugLogs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
      // Keep only last 20 logs
      if (_debugLogs.length > 20) {
        _debugLogs.removeAt(0);
      }
    });
  }

  void _copyLogs() {
    final logsText = _debugLogs.join('\n');
    Clipboard.setData(ClipboardData(text: logsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Debug Logs',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                    onPressed: _copyLogs,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy to clipboard',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => setState(() => _showDebugOverlay = false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                _debugLogs.isEmpty ? 'No logs yet' : _debugLogs.join('\n'),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _copyLogs,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Copy All Logs'),
            ),
          ),
        ],
      ),
    );
  }

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
        // Always show debug overlay in dev mode
        setState(() {
          _showDebugOverlay = true;
          _debugLogs.clear(); // Clear old logs
        });

        _addLog('Dev mode enabled, calling devSignInWithEmail...');
        _addLog('Email: $email');

        final result = await _authService.devSignInWithEmailWithLogs(email);
        final success = result['success'] as bool;
        final logs = result['logs'] as List<String>;

        // Add all logs from auth service
        for (final log in logs) {
          _addLog(log);
        }

        if (success) {
          _addLog('SUCCESS! Navigating to / in 3 seconds...');
          _addLog('(Double-tap header to copy logs before leaving)');
          // Wait 3 seconds so user can see the logs before navigating
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            // Go directly to root - AuthWrapper will handle navigation
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        } else {
          _addLog('FAILED - check logs above');
          _addLog('Staying on screen so you can copy logs');
          setState(() {
            _errorMessage = 'Dev sign-in failed. See debug logs above.';
            _isLoading = false;
          });
          return; // Don't proceed to finally block's isLoading = false
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
      body: Stack(
        children: [
          Container(
            color: NewspaperColors.surface,
            child: SafeArea(
              child: Column(
                children: [
                  // Masthead - double-tap title to toggle debug overlay
                  GestureDetector(
                    onDoubleTap: () {
                      if (DevConfig.skipOtpVerificationInDev) {
                        setState(() => _showDebugOverlay = !_showDebugOverlay);
                      }
                    },
                    child: const NewspaperMasthead(
                      date: 'Verification',
                      title: 'TogetherRemind',
                      subtitle: 'Step 2 of 3',
                    ),
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

                          // Dev mode: Show Logs button
                          if (DevConfig.skipOtpVerificationInDev && _debugLogs.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () => setState(() => _showDebugOverlay = !_showDebugOverlay),
                              icon: Icon(
                                _showDebugOverlay ? Icons.visibility_off : Icons.visibility,
                                size: 16,
                              ),
                              label: Text(_showDebugOverlay ? 'Hide Logs' : 'Show Logs (${_debugLogs.length})'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                              ),
                            ),
                          ],
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
          // Debug overlay - double-tap masthead to toggle
          if (_showDebugOverlay)
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: _buildDebugOverlay(),
            ),
        ],
      ),
    );
  }
}
