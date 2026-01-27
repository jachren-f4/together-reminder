import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/welcome_quiz_intro_screen.dart';
import 'package:togetherremind/services/storage_service.dart';

/// Screen 09: Push Notifications Permission
///
/// Permission request screen with example notification mockup.
/// Shows what notifications will look like to encourage opt-in.
///
/// Mockup: mockups/new-onboarding-flow/09-notifications.html
class NotificationPermissionScreen extends StatefulWidget {
  /// When true, runs in preview mode for debug browser
  final bool previewMode;

  const NotificationPermissionScreen({
    super.key,
    this.previewMode = false,
  });

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen> {
  bool _isRequesting = false;

  /// Get partner's name or fallback to "Your partner"
  String get _partnerDisplayName {
    final partner = StorageService().getPartner();
    if (partner?.name != null && partner!.name!.isNotEmpty) {
      return partner.name!;
    }
    return 'Your partner';
  }

  Future<void> _handleEnableNotifications() async {
    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isRequesting = true);

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }

    if (mounted) {
      setState(() => _isRequesting = false);
      _navigateToNext();
    }
  }

  void _handleMaybeLater() {
    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }
    _navigateToNext();
  }

  void _handleSkip() {
    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }
    _navigateToNext();
  }

  void _navigateToNext() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WelcomeQuizIntroScreen(),
      ),
    );
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
                  // Header with skip
                  _buildHeader(),

                  // Content
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Notification mockup
                            _buildNotificationMockup(),
                            const SizedBox(height: 40),

                            // Title
                            _buildTitle(),
                            const SizedBox(height: 12),

                            // Subtitle
                            _buildSubtitle(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _handleSkip,
            child: Text(
              'Skip',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textMedium,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationMockup() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status bar
          _buildMockStatusBar(),
          const SizedBox(height: 12),

          // Notification banner
          _buildNotificationBanner(),
        ],
      ),
    );
  }

  Widget _buildMockStatusBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '9:41',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Row(
          children: [
            // WiFi icon
            const Icon(Icons.wifi, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            // Battery icon
            const Icon(Icons.battery_full, color: Colors.white, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Us2Theme.gradientAccentStart,
                  Us2Theme.gradientAccentEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),

          // Notification content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'US 2.0',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'now',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: Us2Theme.textLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$_partnerDisplayName finished today\'s quiz!',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.textDark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'See how you matched',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Us2Theme.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Never miss a moment together',
      textAlign: TextAlign.center,
      style: GoogleFonts.playfairDisplay(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: Us2Theme.textDark,
        height: 1.3,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Get notified when your partner finishes an activity so you can see your results together.',
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          fontSize: 15,
          color: Us2Theme.textMedium,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enable notifications button (primary)
          GestureDetector(
            onTap: _isRequesting ? null : _handleEnableNotifications,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Us2Theme.gradientAccentStart,
                    Us2Theme.gradientAccentEnd,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.gradientAccentStart.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _isRequesting
                  ? const SizedBox(
                      height: 19,
                      child: Center(
                        child: SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    )
                  : Text(
                      'Enable notifications',
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
          const SizedBox(height: 12),

          // Maybe later button (secondary)
          GestureDetector(
            onTap: _handleMaybeLater,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Maybe later',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textMedium,
                ),
              ),
            ),
          ),
        ],
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
