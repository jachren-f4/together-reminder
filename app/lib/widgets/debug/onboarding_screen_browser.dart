import 'package:flutter/material.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/onboarding/value_carousel_screen.dart';
import 'package:togetherremind/screens/onboarding/name_birthday_screen.dart';
import 'package:togetherremind/screens/onboarding/anniversary_screen.dart';
import 'package:togetherremind/screens/onboarding/notification_permission_screen.dart';
import 'package:togetherremind/screens/onboarding/value_proposition_screen.dart';

/// Debug browser for testing new onboarding screens individually.
///
/// Access: Double-tap the top-left corner (greeting area) on the home screen.
/// Each screen runs in preview mode where:
/// - Navigation goes back to browser instead of real flow
/// - Data is NOT saved to storage
/// - Permission requests are simulated (just show UI)
class OnboardingScreenBrowser extends StatelessWidget {
  const OnboardingScreenBrowser({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Onboarding Screen Browser',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Us2Theme.gradientAccentStart,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Us2Theme.bgGradientStart, Us2Theme.bgGradientEnd],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Debug mode header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DEBUG MODE - Tap any screen to preview.\nScreens run in preview mode (no data saved).',
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
            const SizedBox(height: 24),

            // Section: New Screens
            _buildSectionHeader('New Onboarding Screens'),
            const SizedBox(height: 12),

            _ScreenTile(
              number: '01',
              title: 'Value Carousel',
              subtitle: 'Video background + 3 swipeable slides',
              isNew: true,
              onTap: () => _navigateToScreen(
                context,
                const ValueCarouselScreen(previewMode: true),
              ),
            ),

            _ScreenTile(
              number: '04',
              title: 'Name + Birthday',
              subtitle: 'Personal info collection',
              isNew: true,
              onTap: () => _navigateToScreen(
                context,
                const NameBirthdayScreen(previewMode: true),
              ),
            ),

            _ScreenTile(
              number: '07',
              title: 'Anniversary Date',
              subtitle: 'Relationship context + encouragement',
              isNew: true,
              onTap: () => _navigateToScreen(
                context,
                const AnniversaryScreen(previewMode: true),
              ),
            ),

            _ScreenTile(
              number: '09',
              title: 'Push Notifications',
              subtitle: 'Permission request with preview',
              isNew: true,
              onTap: () => _navigateToScreen(
                context,
                const NotificationPermissionScreen(previewMode: true),
              ),
            ),

            _ScreenTile(
              number: '14',
              title: 'Value Proposition',
              subtitle: 'Benefits cards grid',
              isNew: true,
              onTap: () => _navigateToScreen(
                context,
                const ValuePropositionScreen(previewMode: true),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),

            // Section: Flow Preview
            _buildSectionHeader('Flow Preview'),
            const SizedBox(height: 12),

            _ScreenTile(
              number: '',
              title: 'Complete Flow',
              subtitle: 'Run through all new screens in sequence',
              isNew: false,
              isFlow: true,
              onTap: () => _navigateToScreen(
                context,
                const ValueCarouselScreen(previewMode: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: Us2Theme.textMedium,
      ),
    );
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

/// Individual screen tile in the browser list
class _ScreenTile extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final bool isNew;
  final bool isFlow;
  final VoidCallback onTap;

  const _ScreenTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.isNew,
    this.isFlow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Number badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isFlow
                      ? const LinearGradient(
                          colors: [Color(0xFF6B8AFF), Color(0xFF43C6FF)],
                        )
                      : Us2Theme.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isFlow
                      ? const Icon(Icons.play_arrow, color: Colors.white, size: 24)
                      : Text(
                          number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Us2Theme.textDark,
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Us2Theme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Us2Theme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
