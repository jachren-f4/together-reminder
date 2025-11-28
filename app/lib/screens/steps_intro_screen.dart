import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/steps_feature_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/poke_service.dart';
import 'steps_counter_screen.dart';

/// Intro screen for Steps Together feature.
///
/// Three variants based on connection status:
/// - Neither connected: Both avatars gray, explain feature
/// - Partner connected: Partner has checkmark, social proof
/// - Waiting for partner: User connected, partner waiting
class StepsIntroScreen extends StatefulWidget {
  const StepsIntroScreen({super.key});

  @override
  State<StepsIntroScreen> createState() => _StepsIntroScreenState();
}

class _StepsIntroScreenState extends State<StepsIntroScreen> {
  final StepsFeatureService _stepsService = StepsFeatureService();
  final StorageService _storage = StorageService();
  bool _isConnecting = false;
  bool _isSendingReminder = false;

  @override
  Widget build(BuildContext context) {
    final state = _stepsService.getCurrentState();
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    return Scaffold(
      backgroundColor: BrandLoader().colors.surface,
      appBar: AppBar(
        backgroundColor: BrandLoader().colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: BrandLoader().colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Steps Together',
          style: AppTheme.headlineFont.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: BrandLoader().colors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Footprints illustration
              _buildFootprintsIllustration(state),
              const SizedBox(height: 32),

              // Avatar circles with status
              _buildAvatarSection(state, partnerName),
              const SizedBox(height: 24),

              // Equals row with LP bubble
              _buildRewardRow(),
              const SizedBox(height: 32),

              // Title and description
              _buildTitleSection(state, partnerName),
              const SizedBox(height: 32),

              // How it works / Reward tiers section
              if (state == StepsFeatureState.waitingForPartner)
                _buildRewardTiersSection()
              else
                _buildHowItWorksSection(),
              const SizedBox(height: 32),

              // Action buttons
              _buildActionButtons(state, partnerName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFootprintsIllustration(StepsFeatureState state) {
    // Footprints with varying opacity based on connection state
    final bool userConnected = state == StepsFeatureState.waitingForPartner;
    final bool partnerConnected = state == StepsFeatureState.partnerConnected;
    final bool bothConnected = state == StepsFeatureState.tracking;

    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left footprint (user)
          Transform.rotate(
            angle: -0.3,
            child: Opacity(
              opacity: userConnected || bothConnected ? 1.0 : 0.3,
              child: const Text('👣', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(width: 20),
          // Right footprint (partner)
          Transform.rotate(
            angle: 0.3,
            child: Opacity(
              opacity: partnerConnected || bothConnected ? 1.0 : 0.3,
              child: const Text('👣', style: TextStyle(fontSize: 40)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(StepsFeatureState state, String partnerName) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    final bool userConnected = state == StepsFeatureState.waitingForPartner ||
        state == StepsFeatureState.tracking;
    final bool partnerConnected = state == StepsFeatureState.partnerConnected ||
        state == StepsFeatureState.tracking;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // User avatar
        _buildAvatar(
          name: 'You',
          initial: _getInitial(user?.name, 'Y'),
          isConnected: userConnected,
          statusText: userConnected ? 'Connected!' : 'Not connected',
        ),
        const SizedBox(width: 16),
        // Plus sign
        Text(
          '+',
          style: AppTheme.headlineFont.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: BrandLoader().colors.textTertiary,
          ),
        ),
        const SizedBox(width: 16),
        // Partner avatar
        _buildAvatar(
          name: partnerName,
          initial: _getInitial(partner?.name, 'P'),
          isConnected: partnerConnected,
          statusText: partnerConnected
              ? 'Ready!'
              : (state == StepsFeatureState.waitingForPartner
                  ? 'Waiting...'
                  : 'Not connected'),
          showHourglass: state == StepsFeatureState.waitingForPartner,
        ),
      ],
    );
  }

  Widget _buildAvatar({
    required String name,
    required String initial,
    required bool isConnected,
    required String statusText,
    bool showHourglass = false,
  }) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isConnected
                    ? BrandLoader().colors.textPrimary
                    : const Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: showHourglass
                    ? const Text('⏳', style: TextStyle(fontSize: 24))
                    : Text(
                        initial,
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isConnected
                              ? Colors.white
                              : BrandLoader().colors.textTertiary,
                        ),
                      ),
              ),
            ),
            if (isConnected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: BrandLoader().colors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: AppTheme.headlineFont.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: BrandLoader().colors.textPrimary,
          ),
        ),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 12,
            color: isConnected
                ? BrandLoader().colors.success
                : BrandLoader().colors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 2,
          color: BrandLoader().colors.borderLight,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: BrandLoader().colors.textPrimary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Up to +30 LP',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 40,
          height: 2,
          color: BrandLoader().colors.borderLight,
        ),
      ],
    );
  }

  Widget _buildTitleSection(StepsFeatureState state, String partnerName) {
    String title;
    String description;

    switch (state) {
      case StepsFeatureState.neitherConnected:
        title = 'Steps Together';
        description =
            'Connect Apple Health to combine your daily steps with $partnerName\'s and earn Love Points together!';
        break;
      case StepsFeatureState.partnerConnected:
        title = 'Steps Together';
        description =
            '$partnerName is already connected! Join them to start earning Love Points for your combined steps.';
        break;
      case StepsFeatureState.waitingForPartner:
        title = 'Almost There!';
        description =
            'You\'re connected! Once $partnerName connects too, you\'ll start earning Love Points together.';
        break;
      default:
        title = 'Steps Together';
        description = 'Walk together, earn together.';
    }

    return Column(
      children: [
        Text(
          title,
          style: AppTheme.headlineFont.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: BrandLoader().colors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            fontSize: 16,
            color: BrandLoader().colors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHowItWorksSection() {
    final steps = [
      {
        'number': '1',
        'text': 'Connect Apple Health to share your step count',
      },
      {
        'number': '2',
        'text': 'Walk throughout the day - steps sync automatically',
      },
      {
        'number': '3',
        'text': 'Open the app tomorrow to claim your combined reward',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BrandLoader().colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: BrandLoader().colors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          step['number']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step['text']!,
                        style: TextStyle(
                          fontSize: 14,
                          color: BrandLoader().colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRewardTiersSection() {
    final tiers = [
      {'steps': '10,000', 'lp': '+15 LP'},
      {'steps': '12,000', 'lp': '+18 LP'},
      {'steps': '14,000', 'lp': '+21 LP'},
      {'steps': '16,000', 'lp': '+24 LP'},
      {'steps': '18,000', 'lp': '+27 LP'},
      {'steps': '20,000+', 'lp': '+30 LP'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reward Tiers',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BrandLoader().colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...tiers.map((tier) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tier['steps']} combined steps',
                      style: TextStyle(
                        fontSize: 14,
                        color: BrandLoader().colors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BrandLoader().colors.textPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tier['lp']!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          Text(
            'Your steps are being tracked in the meantime!',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: BrandLoader().colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(StepsFeatureState state, String partnerName) {
    if (state == StepsFeatureState.waitingForPartner) {
      return Column(
        children: [
          // Primary: Remind partner
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSendingReminder ? null : _sendReminder,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandLoader().colors.textPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSendingReminder
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Remind $partnerName',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Secondary: Done
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: BrandLoader().colors.textSecondary,
              ),
              child: Text(
                'Done',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: BrandLoader().colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Primary: Connect Apple Health
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isConnecting ? null : _connectHealthKit,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandLoader().colors.textPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Connect Apple Health',
                        style: AppTheme.headlineFont.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary: Maybe later
        SizedBox(
          width: double.infinity,
          height: 56,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: BrandLoader().colors.textSecondary,
            ),
            child: Text(
              'Maybe later',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BrandLoader().colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _connectHealthKit() async {
    setState(() => _isConnecting = true);
    HapticService().tap();
    SoundService().tap();

    try {
      final granted = await _stepsService.connectHealthKit();

      if (granted && mounted) {
        HapticService().trigger(HapticType.success);

        // Navigate to counter screen on success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StepsCounterScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please allow access to Health data in Settings'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _sendReminder() async {
    if (_isSendingReminder) return;

    setState(() => _isSendingReminder = true);
    HapticService().tap();
    SoundService().tap();

    try {
      // Use poke service with steps emoji
      final success = await PokeService.sendPoke(emoji: '👟');

      if (mounted) {
        if (success) {
          HapticService().trigger(HapticType.success);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reminder sent! 👟'),
              backgroundColor: BrandLoader().colors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Rate limited
          final remaining = PokeService.getRemainingSeconds();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait $remaining seconds before sending again'),
              backgroundColor: BrandLoader().colors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reminder: $e'),
            backgroundColor: BrandLoader().colors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingReminder = false);
      }
    }
  }

  /// Get initial from name, with fallback
  String _getInitial(String? name, String fallback) {
    if (name != null && name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return fallback;
  }
}
