import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/brand/us2_theme.dart';
import '../services/subscription_service.dart';
import '../utils/logger.dart';
import 'already_subscribed_screen.dart';

/// Shows the RevenueCat Paywall UI and returns whether purchase/restore succeeded.
///
/// This is a convenience function to present the RevenueCat Paywall UI from anywhere
/// in the app without needing to navigate to a screen.
///
/// Returns true if user has premium access after the paywall was dismissed.
Future<bool> showRevenueCatPaywall(BuildContext context) async {
  final subscriptionService = SubscriptionService();
  final result = await subscriptionService.presentPaywall();
  return result.didPurchaseOrRestore || subscriptionService.isPremium;
}

/// Paywall screen shown after pairing or when subscription lapses
///
/// This is a "hard paywall" - users must subscribe to access the app.
///
/// Two modes:
/// - New user (default): Shows free trial offer after pairing
/// - Lapsed user: Shows "Welcome Back" resubscribe flow
///
/// Two UI options:
/// - Custom paywall (default): Our custom-designed paywall
/// - RevenueCat paywall: RevenueCat's built-in paywall UI (set useRevenueCatPaywall: true)
class PaywallScreen extends StatefulWidget {
  /// Called when user successfully subscribes or skips (if allowed).
  /// Receives BuildContext to ensure navigation uses a mounted context.
  final void Function(BuildContext context) onContinue;

  /// Whether to allow skipping the paywall (for testing/dev)
  final bool allowSkip;

  /// Whether this is a lapsed user (subscription ended)
  /// Changes messaging from "Start Free Trial" to "Welcome Back"
  final bool isLapsedUser;

  /// Whether to use RevenueCat's built-in paywall UI instead of custom
  /// Set to true to use RevenueCat's paywall designer
  final bool useRevenueCatPaywall;

  const PaywallScreen({
    super.key,
    required this.onContinue,
    this.allowSkip = false,
    this.isLapsedUser = false,
    this.useRevenueCatPaywall = false,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();

  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  Offerings? _offerings;
  String? _errorMessage;

  /// Polls for couple subscription status (partner might subscribe)
  Timer? _pollTimer;

  /// Triple-tap bypass for testing
  int _devTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    if (widget.useRevenueCatPaywall) {
      _presentRevenueCatPaywall();
    } else {
      _loadOfferings();
      _startPolling();
    }
  }

  /// Present RevenueCat's built-in paywall
  Future<void> _presentRevenueCatPaywall() async {
    // Small delay to ensure the screen is mounted
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    // Check if already subscribed
    if (_subscriptionService.isPremium) {
      Logger.debug('User already has premium, skipping paywall', service: 'paywall');
      widget.onContinue(context);
      return;
    }

    // Present RevenueCat paywall
    final result = await _subscriptionService.presentPaywall();

    if (!mounted) return;

    if (result.didPurchaseOrRestore) {
      // Success - continue
      widget.onContinue(context);
    } else if (result.status.name == 'notAvailable') {
      // Fall back to custom paywall
      Logger.warn('RevenueCat paywall not available, using custom', service: 'paywall');
      _loadOfferings();
      _startPolling();
    } else {
      // User cancelled - stay on screen and show custom paywall
      _loadOfferings();
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Handle triple-tap on title for dev bypass
  void _handleDevTap() {
    final now = DateTime.now();

    // Reset if more than 500ms since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds > 500) {
      _devTapCount = 0;
    }

    _lastTapTime = now;
    _devTapCount++;

    if (_devTapCount >= 3) {
      _devTapCount = 0;
      _activateDevBypass();
    }
  }

  /// Activate dev bypass - grants real subscription to the couple via API
  Future<void> _activateDevBypass() async {
    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dev Bypass'),
        content: const Text(
          'Activate test subscription for your couple?\n\n'
          'This will set your couple\'s subscription to active in the database '
          '(expires in 1 year). Both you and your partner will have premium access.\n\n'
          'REMEMBER: Disable this before App Store builds!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isPurchasing = true);

      try {
        // Activate subscription via API (sets it in database)
        final result = await _subscriptionService.activateForCouple(
          productId: 'dev_bypass_test',
          expiresAt: DateTime.now().add(const Duration(days: 365)),
        );

        if (!mounted) return;

        if (result == null) {
          throw Exception('Activation returned null');
        }

        if (result.status == 'activated' || result.status == 'already_subscribed') {
          Logger.info('Dev bypass: subscription activated via API', service: 'paywall');

          // Refresh couple status
          await _subscriptionService.checkCoupleSubscription();

          if (!mounted) return;

          // Show success toast
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.status == 'already_subscribed'
                  ? 'Already subscribed!'
                  : 'Test subscription activated'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Continue to app
          widget.onContinue(context);
        } else {
          throw Exception(result.message ?? 'Activation failed');
        }
      } catch (e) {
        Logger.error('Dev bypass activation failed', error: e, service: 'paywall');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activation failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isPurchasing = false);
      }
    }
  }

  /// Poll every 5 seconds to check if partner subscribed
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final status = await _subscriptionService.checkCoupleSubscription();
        if (status != null && status.isActive && mounted) {
          _pollTimer?.cancel();
          // Partner subscribed! Navigate to AlreadySubscribedScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AlreadySubscribedScreen(
                subscriberName: status.subscriberName ?? 'Your partner',
                onContinue: widget.onContinue,
              ),
            ),
          );
        }
      } catch (e) {
        // Ignore polling errors
        Logger.debug('Paywall poll error: $e', service: 'paywall');
      }
    });
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if already subscribed
      if (_subscriptionService.isPremium) {
        Logger.debug('User already has premium, skipping paywall', service: 'paywall');
        widget.onContinue(context);
        return;
      }

      // Load offerings
      final offerings = await _subscriptionService.getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load offerings', error: e, service: 'paywall');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load subscription options';
        });
      }
    }
  }

  Future<void> _startTrial() async {
    final package = _offerings?.current?.availablePackages.firstOrNull;
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subscription available')),
      );
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      // Check if partner already subscribed before initiating purchase
      final status = await _subscriptionService.checkCoupleSubscription();
      if (status != null && status.isActive && mounted) {
        _pollTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AlreadySubscribedScreen(
              subscriberName: status.subscriberName ?? 'Your partner',
              onContinue: widget.onContinue,
            ),
          ),
        );
        return;
      }

      final result = await _subscriptionService.purchasePackage(package);
      if (!mounted) return;

      if (result.isAlreadySubscribed) {
        // Partner subscribed during our purchase attempt
        _pollTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AlreadySubscribedScreen(
              subscriberName: result.subscriberName ?? 'Your partner',
              onContinue: widget.onContinue,
            ),
          ),
        );
      } else if (result.success) {
        widget.onContinue(context);
      }
    } on PlatformException catch (e) {
      // User cancelled or other error
      Logger.debug('Purchase cancelled or failed: $e', service: 'paywall');
    } catch (e) {
      Logger.error('Purchase error', error: e, service: 'paywall');
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);

    try {
      final result = await _subscriptionService.restorePurchases();
      if (!mounted) return;

      if (result.isCoupleActive) {
        // Partner subscribed - show success screen
        _pollTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AlreadySubscribedScreen(
              subscriberName: result.subscriberName ?? 'Your partner',
              onContinue: widget.onContinue,
            ),
          ),
        );
      } else if (result.isRevenueCatRestored) {
        // Own subscription restored
        widget.onContinue(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subscription found')),
        );
      }
    } catch (e) {
      Logger.error('Restore failed', error: e, service: 'paywall');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to restore purchases')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Us2Theme.primaryBrandPink))
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Hero Section
          _buildHero(),
          const SizedBox(height: 24),

          // Welcome back message (lapsed users only)
          if (widget.isLapsedUser) ...[
            _buildWelcomeBackMessage(),
            const SizedBox(height: 20),
          ],

          // Subscription Card
          _buildSubscriptionCard(),
          const SizedBox(height: 20),

          // CTA Button
          _buildCtaButton(),
          const SizedBox(height: 12),

          // Guarantee text
          Text(
            widget.isLapsedUser
                ? 'Cancel anytime. Your progress is saved.'
                : 'Cancel anytime. No charge until day 8.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Us2Theme.textMedium,
            ),
          ),
          const SizedBox(height: 20),

          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildWelcomeBackMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text.rich(
        TextSpan(
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: Us2Theme.textMedium,
            height: 1.5,
          ),
          children: [
            const TextSpan(
              text: 'Your journey together doesn\'t have to end here.\n',
            ),
            TextSpan(
              text: 'Pick up where you left off.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Us2Theme.primaryBrandPink,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        // Logo
        Text(
          'Us',
          style: GoogleFonts.pacifico(
            fontSize: 42,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 20,
                color: Us2Theme.glowPink.withValues(alpha: 0.8),
              ),
              Shadow(
                blurRadius: 40,
                color: Us2Theme.glowOrange.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        Text(
          '♥',
          style: TextStyle(
            fontSize: 18,
            color: Us2Theme.primaryBrandPink,
          ),
        ),
        const SizedBox(height: 12),

        // Status badge (lapsed users only)
        if (widget.isLapsedUser) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Us2Theme.primaryBrandPink.withValues(alpha: 0.1),
              border: Border.all(
                color: Us2Theme.primaryBrandPink.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Us2Theme.primaryBrandPink,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Subscription Ended',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.primaryBrandPink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Title - different for lapsed users
        // Variant 7: "One Subscription. Two Accounts." messaging
        // Triple-tap for dev bypass (testing)
        GestureDetector(
          onTap: _handleDevTap,
          child: Text(
            widget.isLapsedUser
                ? 'Welcome Back!'
                : 'One Subscription.\nTwo Accounts.',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: widget.isLapsedUser ? 28 : 26,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle - different for lapsed users
        Text(
          widget.isLapsedUser
              ? 'We\'ve missed you'
              : 'You subscribe, your partner gets access too',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: Us2Theme.textMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Us2Theme.cardSalmon, Us2Theme.cardSalmonDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.glowPink.withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Us2Theme.primaryBrandPink.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trial tag (only for new users)
          if (!widget.isLapsedUser) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Us2Theme.cream,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '7-Day Free Trial',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Us2Theme.primaryBrandPink,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Plan name
          Text(
            'Us 2.0 Premium',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            'Full access to everything',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '€9.99',
                style: GoogleFonts.nunito(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/month',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            widget.isLapsedUser ? 'Billed monthly' : 'After your free trial',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 20),

          // Features
          _buildFeature('Daily couples quests'),
          _buildFeature('All game modes unlocked'),
          _buildFeature('Discover new things together'),
          _buildFeature('Fresh content every week'),
        ],
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Us2Theme.primaryBrandPink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButton() {
    final isDisabled = _isPurchasing || _isRestoring || _offerings == null;

    return GestureDetector(
      onTap: isDisabled ? null : _startTrial,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDisabled
                ? [Colors.grey.shade300, Colors.grey.shade400]
                : [Colors.white, Us2Theme.cream],
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: Us2Theme.glowPink.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Us2Theme.primaryBrandPink.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: _isPurchasing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Us2Theme.primaryBrandPink,
                  ),
                )
              : Text(
                  widget.isLapsedUser ? 'Continue Your Journey' : 'Start Free Trial',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.primaryBrandPink,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Restore button
        TextButton(
          onPressed: _isRestoring ? null : _restorePurchases,
          child: _isRestoring
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Already subscribed? Restore',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Us2Theme.textMedium,
                    decoration: TextDecoration.underline,
                    decorationColor: Us2Theme.textMedium.withValues(alpha: 0.3),
                  ),
                ),
        ),
        const SizedBox(height: 12),

        // Legal links
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegalLink('Terms of Service', () {
              // TODO: Open terms URL
            }),
            const SizedBox(width: 20),
            _buildLegalLink('Privacy Policy', () {
              // TODO: Open privacy URL
            }),
          ],
        ),

        // Dev skip button (only in debug)
        if (widget.allowSkip) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => widget.onContinue(context),
            child: Text(
              'Skip (Dev Only)',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Us2Theme.textLight,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLegalLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: Us2Theme.textLight,
        ),
      ),
    );
  }
}
