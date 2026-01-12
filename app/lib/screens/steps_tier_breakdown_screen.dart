import 'package:flutter/material.dart';
import '../config/brand/us2_theme.dart';
import '../services/steps_feature_service.dart';

/// Screen showing the full tier ladder and how LP rewards work.
class StepsTierBreakdownScreen extends StatelessWidget {
  final int currentCombinedSteps;

  const StepsTierBreakdownScreen({
    super.key,
    required this.currentCombinedSteps,
  });

  static const List<Map<String, dynamic>> _tiers = [
    {'threshold': 20000, 'lp': 30, 'label': '20K', 'emoji': ''},
    {'threshold': 18000, 'lp': 27, 'label': '18K', 'emoji': ''},
    {'threshold': 16000, 'lp': 24, 'label': '16K', 'emoji': ''},
    {'threshold': 14000, 'lp': 21, 'label': '14K', 'emoji': ''},
    {'threshold': 12000, 'lp': 18, 'label': '12K', 'emoji': ''},
    {'threshold': 10000, 'lp': 15, 'label': '10K', 'emoji': ''},
  ];

  int _getCurrentTierIndex() {
    for (int i = 0; i < _tiers.length; i++) {
      if (currentCombinedSteps >= _tiers[i]['threshold']) {
        return i;
      }
    }
    return -1; // Below all tiers
  }

  @override
  Widget build(BuildContext context) {
    final currentTierIndex = _getCurrentTierIndex();
    final projectedLP = StepsFeatureService().getProjectedLP();

    return Scaffold(
      backgroundColor: Us2Theme.bgGradientEnd,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Us2Theme.textDark, size: 20),
            ),
          ),
        ),
        title: const Text(
          'Tier System',
          style: TextStyle(
            fontFamily: Us2Theme.fontHeading,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Us2Theme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Intro card
                _buildIntroCard(),
                const SizedBox(height: 16),

                // Current status
                _buildCurrentStatusCard(projectedLP),
                const SizedBox(height: 24),

                // Tier ladder
                _buildTierLadder(currentTierIndex),
                const SizedBox(height: 24),

                // FAQ section
                _buildFAQCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Us2Theme.accentGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            '',
            style: TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            'Walk Together, Earn Together',
            style: TextStyle(
              fontFamily: Us2Theme.fontHeading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The more steps you take as a couple, the more Love Points you earn. Hit higher tiers for bigger rewards!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard(int projectedLP) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Status Today',
                  style: TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 12,
                    color: Us2Theme.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(currentCombinedSteps),
                  style: const TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.textDark,
                  ),
                ),
                const Text(
                  'combined steps',
                  style: TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 14,
                    color: Us2Theme.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB347), Color(0xFFFFD89B)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '+$projectedLP',
                  style: const TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'LP',
                  style: TextStyle(
                    fontFamily: Us2Theme.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierLadder(int currentTierIndex) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tier Ladder',
            style: TextStyle(
              fontFamily: Us2Theme.fontHeading,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_tiers.length, (index) {
            final tier = _tiers[index];
            final isAchieved = index >= currentTierIndex && currentTierIndex >= 0;
            final isCurrent = index == currentTierIndex;
            final isNext = index == currentTierIndex - 1;

            return _buildTierRow(
              label: tier['label'],
              lp: tier['lp'],
              isAchieved: isAchieved,
              isCurrent: isCurrent,
              isNext: isNext,
              stepsNeeded: isNext ? tier['threshold'] - currentCombinedSteps : null,
            );
          }),

          // Below threshold message
          if (currentTierIndex < 0)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Walk ${_formatNumber(10000 - currentCombinedSteps)} more steps together to start earning LP!',
                      style: const TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 13,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTierRow({
    required String label,
    required int lp,
    required bool isAchieved,
    required bool isCurrent,
    required bool isNext,
    int? stepsNeeded,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFFFFF0EB)
            : isAchieved
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: Us2Theme.gradientAccentStart, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? Us2Theme.gradientAccentStart
                  : isAchieved
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE0E0E0),
            ),
            child: Icon(
              isCurrent
                  ? Icons.star
                  : isAchieved
                      ? Icons.check
                      : Icons.lock_outline,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Tier info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: Us2Theme.fontHeading,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isAchieved || isCurrent
                            ? Us2Theme.textDark
                            : Us2Theme.textLight,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Us2Theme.gradientAccentStart,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isNext && stepsNeeded != null)
                  Text(
                    '${_formatNumber(stepsNeeded)} more steps',
                    style: const TextStyle(
                      fontFamily: Us2Theme.fontBody,
                      fontSize: 12,
                      color: Us2Theme.textLight,
                    ),
                  ),
              ],
            ),
          ),

          // LP reward
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent
                  ? Us2Theme.gradientAccentStart
                  : isAchieved
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$lp LP',
              style: TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isCurrent || isAchieved ? Colors.white : Us2Theme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'How It Works',
                style: TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFAQItem(
            question: 'When do I get my LP?',
            answer: 'LP is auto-claimed when you open the app the next day. Your steps from today become claimable tomorrow.',
          ),
          _buildFAQItem(
            question: 'What if my partner walks more than me?',
            answer: 'No problem! Your steps are combined together. It doesn\'t matter who walks more - you\'re a team!',
          ),
          _buildFAQItem(
            question: 'Do I need to claim manually?',
            answer: 'Nope! LP is automatically claimed when you open the app. Just make sure to open the app daily.',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(
              fontFamily: Us2Theme.fontBody,
              fontSize: 13,
              color: Us2Theme.textMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return number.toString();
  }
}
