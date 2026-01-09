import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/steps_feature_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/poke_service.dart';
import '../services/notification_service.dart';
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

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  Widget build(BuildContext context) {
    final state = _stepsService.getCurrentState();
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    return Scaffold(
      backgroundColor: _isUs2 ? Us2Theme.bgGradientEnd : BrandLoader().colors.surface,
      extendBodyBehindAppBar: _isUs2,
      appBar: AppBar(
        backgroundColor: _isUs2 ? Colors.transparent : BrandLoader().colors.surface,
        elevation: 0,
        leading: _isUs2
            ? Padding(
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
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Us2Theme.textDark, size: 20),
                  ),
                ),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: BrandLoader().colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Steps Together',
          style: _isUs2
              ? const TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                )
              : AppTheme.headlineFont.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: BrandLoader().colors.textPrimary,
                ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: _isUs2
            ? const BoxDecoration(gradient: Us2Theme.backgroundGradient)
            : null,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Footprints illustration (skip for Us 2.0)
                if (!_isUs2) ...[
                  _buildFootprintsIllustration(state),
                  const SizedBox(height: 32),
                ],

                // Avatar circles with status (skip for Us 2.0)
                if (!_isUs2) ...[
                  _buildAvatarSection(state, partnerName),
                  const SizedBox(height: 24),
                ],

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
                    ? (_isUs2 ? null : BrandLoader().colors.textPrimary)
                    : const Color(0xFFE0E0E0),
                gradient: isConnected && _isUs2 ? Us2Theme.accentGradient : null,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: showHourglass
                    ? const Text('⏳', style: TextStyle(fontSize: 24))
                    : Text(
                        initial,
                        style: _isUs2
                            ? TextStyle(
                                fontFamily: Us2Theme.fontHeading,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: isConnected
                                    ? Colors.white
                                    : Us2Theme.textLight,
                              )
                            : AppTheme.headlineFont.copyWith(
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
                    color: _isUs2 ? const Color(0xFF4CAF50) : BrandLoader().colors.success,
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
          style: _isUs2
              ? const TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                )
              : AppTheme.headlineFont.copyWith(
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
                ? (_isUs2 ? const Color(0xFF4CAF50) : BrandLoader().colors.success)
                : (_isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary),
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
          color: _isUs2 ? Us2Theme.beige : BrandLoader().colors.borderLight,
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isUs2 ? null : BrandLoader().colors.textPrimary,
            gradient: _isUs2 ? Us2Theme.accentGradient : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Up to +30 LP',
            style: _isUs2
                ? const TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )
                : AppTheme.headlineFont.copyWith(
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
          color: _isUs2 ? Us2Theme.beige : BrandLoader().colors.borderLight,
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
          style: _isUs2
              ? const TextStyle(
                  fontFamily: Us2Theme.fontHeading,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Us2Theme.textDark,
                )
              : AppTheme.headlineFont.copyWith(
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
            fontFamily: _isUs2 ? Us2Theme.fontBody : null,
            fontSize: 16,
            color: _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
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
        color: _isUs2 ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isUs2
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: _isUs2
                ? const TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.textDark,
                  )
                : AppTheme.headlineFont.copyWith(
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
                        color: _isUs2 ? null : BrandLoader().colors.textPrimary,
                        gradient: _isUs2 ? Us2Theme.accentGradient : null,
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
                          fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                          fontSize: 14,
                          color: _isUs2
                              ? Us2Theme.textMedium
                              : BrandLoader().colors.textSecondary,
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
        color: _isUs2 ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isUs2
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reward Tiers',
            style: _isUs2
                ? const TextStyle(
                    fontFamily: Us2Theme.fontHeading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.textDark,
                  )
                : AppTheme.headlineFont.copyWith(
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
                        fontFamily: _isUs2 ? Us2Theme.fontBody : null,
                        fontSize: 14,
                        color: _isUs2
                            ? Us2Theme.textMedium
                            : BrandLoader().colors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isUs2 ? null : BrandLoader().colors.textPrimary,
                        gradient: _isUs2 ? Us2Theme.accentGradient : null,
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
              fontFamily: _isUs2 ? Us2Theme.fontBody : null,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: _isUs2 ? Us2Theme.textLight : BrandLoader().colors.textTertiary,
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
          _isUs2
              ? _buildUs2PrimaryButton(
                  onPressed: _isSendingReminder ? null : _sendReminder,
                  isLoading: _isSendingReminder,
                  label: 'Remind $partnerName',
                )
              : SizedBox(
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
                foregroundColor:
                    _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
              ),
              child: Text(
                'Done',
                style: _isUs2
                    ? const TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Us2Theme.textMedium,
                      )
                    : AppTheme.headlineFont.copyWith(
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
        _isUs2
            ? _buildUs2PrimaryButton(
                onPressed: _isConnecting ? null : _connectHealthKit,
                isLoading: _isConnecting,
                label: 'Connect Apple Health',
                icon: Icons.favorite,
              )
            : SizedBox(
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
              foregroundColor:
                  _isUs2 ? Us2Theme.textMedium : BrandLoader().colors.textSecondary,
            ),
            child: Text(
              'Maybe later',
              style: _isUs2
                  ? const TextStyle(
                      fontFamily: Us2Theme.fontBody,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textMedium,
                    )
                  : AppTheme.headlineFont.copyWith(
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

  /// Us 2.0 styled primary button with gradient and glow
  Widget _buildUs2PrimaryButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String label,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: onPressed != null ? Us2Theme.accentGradient : null,
          color: onPressed == null ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: Us2Theme.glowPink,
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
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
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
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
      // Check if user has granted push notification permission
      // If not, this is a great moment to ask (contextually relevant)
      final isAuthorized = await NotificationService.isAuthorized();
      if (!isAuthorized) {
        // Request permission - user is about to send a reminder, so they understand the value
        await NotificationService.requestPermission();
        // Continue regardless of result - we still try to send the poke
      }

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
