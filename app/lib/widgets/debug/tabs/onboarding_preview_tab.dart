import 'package:flutter/material.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/onboarding/value_carousel_screen.dart';
import 'package:togetherremind/screens/onboarding/name_birthday_screen.dart';
import 'package:togetherremind/screens/onboarding/anniversary_screen.dart';
import 'package:togetherremind/screens/onboarding/notification_permission_screen.dart';
import 'package:togetherremind/screens/onboarding/value_proposition_screen.dart';

/// Debug tab for previewing new onboarding screens.
///
/// Each screen runs in preview mode where:
/// - Navigation goes back to browser instead of real flow
/// - Data is NOT saved to storage
/// - Permission requests are simulated
class OnboardingPreviewTab extends StatelessWidget {
  const OnboardingPreviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap any screen to preview. Screens run in preview mode (no data saved, no real navigation).',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Screen tiles
        _ScreenTile(
          number: '01',
          title: 'Value Carousel',
          subtitle: 'Video background + 3 swipeable slides',
          onTap: () => _openScreen(
            context,
            const ValueCarouselScreen(previewMode: true),
          ),
        ),
        _ScreenTile(
          number: '04',
          title: 'Name + Birthday',
          subtitle: 'Personal info collection',
          onTap: () => _openScreen(
            context,
            const NameBirthdayScreen(previewMode: true),
          ),
        ),
        _ScreenTile(
          number: '07',
          title: 'Anniversary Date',
          subtitle: 'Relationship context + encouragement',
          onTap: () => _openScreen(
            context,
            const AnniversaryScreen(previewMode: true),
          ),
        ),
        _ScreenTile(
          number: '09',
          title: 'Push Notifications',
          subtitle: 'Permission request with preview',
          onTap: () => _openScreen(
            context,
            const NotificationPermissionScreen(previewMode: true),
          ),
        ),
        _ScreenTile(
          number: '14',
          title: 'Value Proposition',
          subtitle: 'Benefits cards grid',
          onTap: () => _openScreen(
            context,
            const ValuePropositionScreen(previewMode: true),
          ),
        ),
      ],
    );
  }

  void _openScreen(BuildContext context, Widget screen) {
    // Close the debug menu dialog first
    Navigator.pop(context);
    // Then navigate to the screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _ScreenTile extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ScreenTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Number badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Us2Theme.gradientAccentStart,
                      Us2Theme.gradientAccentEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
