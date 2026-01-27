import 'package:flutter/material.dart';
import '../../../widgets/unlock_popup.dart';
import '../components/debug_section_card.dart';

/// Debug tab for testing unlock popups
class UnlockPopupTab extends StatelessWidget {
  const UnlockPopupTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Unlock Popups',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap any button below to preview the unlock popup for that feature.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),

          // Quiz features
          DebugSectionCard(
            title: 'Quiz Features',
            child: Column(
              children: [
                _buildPopupButton(
                  context,
                  'Classic Quiz',
                  UnlockFeatureType.classicQuiz,
                  Icons.quiz,
                ),
                const SizedBox(height: 12),
                _buildPopupButton(
                  context,
                  'Affirmation Quiz',
                  UnlockFeatureType.affirmationQuiz,
                  Icons.favorite,
                ),
                const SizedBox(height: 12),
                _buildPopupButton(
                  context,
                  'You or Me',
                  UnlockFeatureType.youOrMe,
                  Icons.people,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Puzzle features
          DebugSectionCard(
            title: 'Puzzle Features',
            child: Column(
              children: [
                _buildPopupButton(
                  context,
                  'Crossword',
                  UnlockFeatureType.crossword,
                  Icons.grid_on,
                ),
                const SizedBox(height: 12),
                _buildPopupButton(
                  context,
                  'Word Search',
                  UnlockFeatureType.wordSearch,
                  Icons.search,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Fitness features
          DebugSectionCard(
            title: 'Fitness Features',
            child: _buildPopupButton(
              context,
              'Steps Together',
              UnlockFeatureType.stepsTogether,
              Icons.directions_walk,
            ),
          ),

          const SizedBox(height: 16),

          // Show all button
          DebugSectionCard(
            title: 'Bulk Testing',
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAllPopupsSequentially(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Show All Popups (Sequential)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPopupButton(
    BuildContext context,
    String label,
    UnlockFeatureType featureType,
    IconData icon,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Get the root navigator context before popping
          final navigatorContext = Navigator.of(context, rootNavigator: true).context;
          // Close debug menu first
          Navigator.of(context).pop();
          // Then show popup using root navigator context
          Future.delayed(const Duration(milliseconds: 100), () {
            if (navigatorContext.mounted) {
              UnlockPopup.show(navigatorContext, featureType: featureType);
            }
          });
        },
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  void _showAllPopupsSequentially(BuildContext context) async {
    final features = UnlockFeatureType.values;

    // Get the root navigator context before popping
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;

    // Close debug menu first
    Navigator.of(context).pop();

    for (var i = 0; i < features.length; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (navigatorContext.mounted) {
        await UnlockPopup.show(navigatorContext, featureType: features[i]);
      }
    }
  }
}
