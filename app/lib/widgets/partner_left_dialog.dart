import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/us2_theme.dart';
import '../services/user_notification_service.dart';

/// Dialog shown when a user's partner has deleted their account
///
/// Shows a message explaining what happened and directs them to re-pair.
class PartnerLeftDialog extends StatelessWidget {
  final UserNotification notification;
  final VoidCallback onDismiss;

  const PartnerLeftDialog({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  /// Show the partner left dialog
  static Future<void> show(BuildContext context, UserNotification notification) async {
    final notificationService = UserNotificationService();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PartnerLeftDialog(
        notification: notification,
        onDismiss: () async {
          // Dismiss the notification on the server
          await notificationService.dismissNotification(notification.id);
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Sad emoji
          const Text(
            '💔',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            notification.message,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle
          Text(
            'You can pair with someone new to continue your journey together.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: Us2Theme.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // OK Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: Us2Theme.primaryBrandPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'OK',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
