import 'package:flutter/material.dart';
import '../config/brand/us2_theme.dart';

/// A contextual popup asking users to enable push notifications.
/// Shown after completing a classic quiz if notifications aren't authorized.
///
/// Returns `true` if user tapped "Turn On Notifications", `false` if "Not Now".
class NotificationPermissionPopup extends StatelessWidget {
  const NotificationPermissionPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        decoration: BoxDecoration(
          color: Us2Theme.cream,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Us2Theme.beige),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bell icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: Us2Theme.accentGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.gradientAccentStart.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),

            // Title
            Text(
              "Don't Miss a Moment",
              style: TextStyle(
                fontFamily: Us2Theme.fontHeading,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Us2Theme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Body text
            Text(
              "We'll let you know when your partner finishes their quiz so you can see your results together.",
              style: TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 16,
                color: Us2Theme.textMedium,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Primary button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: Us2Theme.accentGradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Us2Theme.gradientAccentStart.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Turn On Notifications',
                    style: TextStyle(
                      fontFamily: Us2Theme.fontBody,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary button
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Not Now',
                style: TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
