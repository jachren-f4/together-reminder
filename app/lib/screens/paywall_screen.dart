import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/brand/us2_theme.dart';
import '../config/revenuecat_config.dart';
import '../services/subscription_service.dart';
import '../utils/logger.dart';
import 'already_subscribed_screen.dart';

/// Legal page URLs (GitHub Pages)
const String _privacyPolicyUrl = 'https://jachren-f4.github.io/together-reminder/privacy.html';
const String _termsOfUseUrl = 'https://jachren-f4.github.io/together-reminder/terms.html';

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

  /// Debug overlay state
  bool _showDebugOverlay = false;

  /// Release debug overlay (works in release builds, for TestFlight debugging)
  bool _showReleaseDebugOverlay = false;
  int _releaseDebugTapCount = 0;
  DateTime? _releaseDebugLastTap;
  String _lastRestoreDebugInfo = '';

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

  /// Handle triple-tap on subtitle for release debug overlay
  void _handleReleaseDebugTap() {
    final now = DateTime.now();

    // Reset if more than 500ms since last tap
    if (_releaseDebugLastTap != null && now.difference(_releaseDebugLastTap!).inMilliseconds > 500) {
      _releaseDebugTapCount = 0;
    }

    _releaseDebugLastTap = now;
    _releaseDebugTapCount++;

    if (_releaseDebugTapCount >= 3) {
      _releaseDebugTapCount = 0;
      HapticFeedback.mediumImpact();
      setState(() => _showReleaseDebugOverlay = true);
    }
  }

  /// Generate debug info for release builds
  String _generateReleaseDebugInfo() {
    final debugInfo = _subscriptionService.getDebugInfo();
    final customerInfo = _subscriptionService.customerInfo;
    final coupleStatus = _subscriptionService.coupleStatus;

    final buffer = StringBuffer();
    buffer.writeln('=== PAYWALL DEBUG (Release) ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Build: 71 (Unicode fuzzy match fix)');
    buffer.writeln('');
    buffer.writeln('--- SDK STATUS ---');
    buffer.writeln('Platform: ${debugInfo['platform']}');
    buffer.writeln('isConfigured: ${debugInfo['isConfigured']}');
    buffer.writeln('SDK Initialized: ${debugInfo['isInitialized']}');
    buffer.writeln('Init Success: ${debugInfo['isInitializedSuccessfully']}');
    buffer.writeln('Init Error: ${debugInfo['initializationError'] ?? 'none'}');
    buffer.writeln('');
    buffer.writeln('--- COUPLE STATUS ---');
    buffer.writeln('Status: ${coupleStatus?.status ?? 'null'}');
    buffer.writeln('isActive: ${coupleStatus?.isActive ?? 'null'}');
    buffer.writeln('subscribedByMe: ${coupleStatus?.subscribedByMe ?? 'null'}');
    buffer.writeln('subscriberName: ${coupleStatus?.subscriberName ?? 'null'}');
    buffer.writeln('expiresAt: ${coupleStatus?.expiresAt?.toIso8601String() ?? 'null'}');
    buffer.writeln('');
    buffer.writeln('--- REVENUECAT CUSTOMER ---');
    buffer.writeln('hasCustomerInfo: ${customerInfo != null}');
    if (customerInfo != null) {
      buffer.writeln('originalAppUserId: ${customerInfo.originalAppUserId}');
      buffer.writeln('activeEntitlements: ${customerInfo.entitlements.active.keys.toList()}');
      buffer.writeln('allEntitlements: ${customerInfo.entitlements.all.keys.toList()}');

      // Check for exact match first
      final exactMatch = customerInfo.entitlements.active['Us 2.0 Pro'];
      if (exactMatch != null) {
        buffer.writeln('');
        buffer.writeln('--- Us 2.0 Pro ENTITLEMENT (EXACT MATCH) ---');
        buffer.writeln('isActive: ${exactMatch.isActive}');
        buffer.writeln('productId: ${exactMatch.productIdentifier}');
        buffer.writeln('expirationDate: ${exactMatch.expirationDate}');
        buffer.writeln('willRenew: ${exactMatch.willRenew}');
      } else {
        // Try fuzzy matching
        buffer.writeln('EXACT MATCH for "Us 2.0 Pro": NOT FOUND');
        buffer.writeln('Trying FUZZY MATCH...');

        String? fuzzyKey;
        for (final key in customerInfo.entitlements.active.keys) {
          if (RevenueCatConfig.isPremiumEntitlement(key)) {
            fuzzyKey = key;
            break;
          }
        }

        if (fuzzyKey != null) {
          final fuzzyMatch = customerInfo.entitlements.active[fuzzyKey]!;
          buffer.writeln('');
          buffer.writeln('--- ENTITLEMENT (FUZZY MATCH) ---');
          buffer.writeln('MATCHED KEY: "$fuzzyKey"');
          buffer.writeln('KEY BYTES: ${fuzzyKey.codeUnits}');
          buffer.writeln('isActive: ${fuzzyMatch.isActive}');
          buffer.writeln('productId: ${fuzzyMatch.productIdentifier}');
          buffer.writeln('expirationDate: ${fuzzyMatch.expirationDate}');
          buffer.writeln('willRenew: ${fuzzyMatch.willRenew}');
        } else {
          buffer.writeln('FUZZY MATCH: NOT FOUND');
          // Show key bytes to help debug Unicode issues
          for (final key in customerInfo.entitlements.active.keys) {
            buffer.writeln('Key "$key" bytes: ${key.codeUnits}');
          }
        }
      }
    }
    buffer.writeln('');
    buffer.writeln('--- isPremium CHECK ---');
    buffer.writeln('isPremium: ${debugInfo['isPremium']}');
    buffer.writeln('devBypassActive: ${debugInfo['isDevBypassActive']}');
    buffer.writeln('');
    buffer.writeln('--- LAST RESTORE ATTEMPT ---');
    buffer.writeln(_lastRestoreDebugInfo.isEmpty ? 'No restore attempted yet' : _lastRestoreDebugInfo);
    buffer.writeln('');
    buffer.writeln('==============================');

    return buffer.toString();
  }

  /// Build the release debug overlay (works in TestFlight)
  Widget _buildReleaseDebugOverlay() {
    if (!_showReleaseDebugOverlay) return const SizedBox.shrink();

    final debugText = _generateReleaseDebugInfo();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close and copy buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🔧 DEBUG (TestFlight)',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  // Copy button
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: debugText));
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debug info copied!'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Close button
                  GestureDetector(
                    onTap: () => setState(() => _showReleaseDebugOverlay = false),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          // Debug text (scrollable)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Text(
                debugText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          Navigator.push(
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

      // Debug logging
      Logger.debug('Offerings loaded: ${offerings != null ? "yes" : "null"}', service: 'paywall');
      Logger.debug('Current offering: ${offerings?.current?.identifier ?? "none"}', service: 'paywall');
      Logger.debug('Packages count: ${offerings?.current?.availablePackages.length ?? 0}', service: 'paywall');
      if (_subscriptionService.lastOfferingsError != null) {
        Logger.debug('Offerings error: ${_subscriptionService.lastOfferingsError}', service: 'paywall');
      }

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
          _errorMessage = 'Unable to load subscription options: $e';
        });
      }
    }
  }

  Future<void> _startTrial() async {
    Logger.debug('_startTrial called', service: 'paywall');
    Logger.debug('offerings: ${_offerings != null ? "present" : "null"}', service: 'paywall');
    Logger.debug('current: ${_offerings?.current?.identifier ?? "null"}', service: 'paywall');
    Logger.debug('packages: ${_offerings?.current?.availablePackages.length ?? 0}', service: 'paywall');

    final package = _offerings?.current?.availablePackages.firstOrNull;
    Logger.debug('selected package: ${package?.identifier ?? "null"}', service: 'paywall');

    if (package == null) {
      Logger.warn('No package available for purchase', service: 'paywall');
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
        Navigator.push(
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
        Navigator.push(
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

    // Capture state BEFORE restore for debugging
    final beforeInfo = StringBuffer();
    beforeInfo.writeln('BEFORE restore:');
    beforeInfo.writeln('  coupleStatus: ${_subscriptionService.coupleStatus?.status}');
    beforeInfo.writeln('  customerInfo: ${_subscriptionService.customerInfo != null}');
    if (_subscriptionService.customerInfo != null) {
      beforeInfo.writeln('  originalAppUserId: ${_subscriptionService.customerInfo!.originalAppUserId}');
      beforeInfo.writeln('  activeEntitlements: ${_subscriptionService.customerInfo!.entitlements.active.keys.toList()}');
    }

    try {
      final result = await _subscriptionService.restorePurchases();

      // Capture state AFTER restore for debugging
      final afterInfo = StringBuffer();
      afterInfo.writeln('AFTER restore:');
      afterInfo.writeln('  result.isCoupleActive: ${result.isCoupleActive}');
      afterInfo.writeln('  result.isRevenueCatRestored: ${result.isRevenueCatRestored}');
      afterInfo.writeln('  coupleStatus: ${_subscriptionService.coupleStatus?.status}');
      afterInfo.writeln('  customerInfo: ${_subscriptionService.customerInfo != null}');
      if (_subscriptionService.customerInfo != null) {
        afterInfo.writeln('  originalAppUserId: ${_subscriptionService.customerInfo!.originalAppUserId}');
        afterInfo.writeln('  activeEntitlements: ${_subscriptionService.customerInfo!.entitlements.active.keys.toList()}');
        final premium = _subscriptionService.customerInfo!.entitlements.active['Us 2.0 Pro'];
        afterInfo.writeln('  Us 2.0 Pro found: ${premium != null}');
        if (premium != null) {
          afterInfo.writeln('  Us 2.0 Pro isActive: ${premium.isActive}');
        }
      }
      afterInfo.writeln('  isPremium: ${_subscriptionService.isPremium}');

      // Store for debug overlay
      _lastRestoreDebugInfo = '$beforeInfo\n$afterInfo';

      if (!mounted) return;

      if (result.isCoupleActive) {
        // Partner subscribed - show success screen
        _pollTimer?.cancel();
        Navigator.push(
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
      _lastRestoreDebugInfo = '$beforeInfo\nEXCEPTION: $e';
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
          // DEBUG: Collapsible debug overlay (only in debug builds)
          if (kDebugMode) _buildDebugOverlay(),

          // RELEASE DEBUG: Hidden overlay triggered by triple-tap on subtitle
          _buildReleaseDebugOverlay(),

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
        // Logo - triple-tap for release debug overlay
        GestureDetector(
          onTap: _handleReleaseDebugTap,
          child: Text(
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDisabled
                ? [Colors.grey.shade300, Colors.grey.shade400]
                : [const Color(0xFFFF6B6B), const Color(0xFFFF9F43)], // Coral gradient
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
                    color: Colors.white, // White on gradient
                  ),
                )
              : Text(
                  widget.isLapsedUser ? 'Continue Your Journey' : 'Start Free Trial',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white, // White text for better contrast on gradient
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
            _buildLegalLink('Terms of Use', () => _openUrl(_termsOfUseUrl)),
            const SizedBox(width: 20),
            _buildLegalLink('Privacy Policy', () => _openUrl(_privacyPolicyUrl)),
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
          decoration: TextDecoration.underline,
          decorationColor: Us2Theme.textLight.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Open a URL in the system browser
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Logger.warn('Could not launch URL: $url', service: 'paywall');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      }
    } catch (e) {
      Logger.error('Error opening URL: $url', error: e, service: 'paywall');
    }
  }

  // ==========================================================================
  // DEBUG OVERLAY (Remove before production release)
  // ==========================================================================

  String _getDebugInfo() {
    final packages = _offerings?.current?.availablePackages ?? [];
    final packageInfo = packages.map((p) =>
      '  - ${p.identifier}: ${p.storeProduct.identifier} (${p.storeProduct.priceString})'
    ).join('\n');

    final allOfferings = _offerings?.all.keys.toList() ?? [];
    final debugInfo = _subscriptionService.getDebugInfo();

    return '''
=== PAYWALL DEBUG INFO ===
Timestamp: ${DateTime.now().toIso8601String()}

--- SDK STATUS ---
Platform: ${debugInfo['platform']}
API Key: ${debugInfo['apiKeyPrefix']}
Entitlement: ${debugInfo['entitlementId']}
isConfigured: ${debugInfo['isConfigured']}
SDK Initialized: ${debugInfo['isInitialized']}
Init Success: ${debugInfo['isInitializedSuccessfully']}
Init Error: ${debugInfo['initializationError'] ?? 'none'}

--- OFFERINGS ---
Offerings Object: ${_offerings != null ? "LOADED" : "NULL"}
All Offerings: $allOfferings
Current Offering: ${_offerings?.current?.identifier ?? "NULL"}
Packages Count: ${packages.length}
${packageInfo.isNotEmpty ? 'Packages:\n$packageInfo' : 'Packages: NONE'}

--- ERRORS ---
Last Offerings Error: ${_subscriptionService.lastOfferingsError ?? 'none'}
Screen Error: ${_errorMessage ?? 'none'}

--- STATE ---
hasCustomerInfo: ${debugInfo['hasCustomerInfo']}
isPremium: ${debugInfo['isPremium']}
devBypassActive: ${debugInfo['isDevBypassActive']}
isLoading: $_isLoading
isPurchasing: $_isPurchasing
isRestoring: $_isRestoring
Button Enabled: ${!_isPurchasing && !_isRestoring && _offerings != null}
==============================
''';
  }

  Widget _buildDebugOverlay() {
    return Column(
      children: [
        // Toggle button - small floating button
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () => setState(() => _showDebugOverlay = !_showDebugOverlay),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _showDebugOverlay
                    ? Colors.red.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showDebugOverlay ? Icons.close : Icons.bug_report,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showDebugOverlay ? 'Close' : 'Debug',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Debug panel (expanded)
        if (_showDebugOverlay) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with copy button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DEBUG INFO',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _getDebugInfo()));
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Debug info copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),

                // Debug info
                _debugRow('Configured', RevenueCatConfig.isConfigured ? 'YES ✓' : 'NO ✗', RevenueCatConfig.isConfigured),
                _debugRow('SDK Init', _subscriptionService.isInitialized ? 'YES ✓' : 'NO ✗', _subscriptionService.isInitialized),
                _debugRow('Init OK', _subscriptionService.isInitializedSuccessfully ? 'YES ✓' : 'NO ✗', _subscriptionService.isInitializedSuccessfully),
                if (_subscriptionService.initializationError != null)
                  _debugRow('Init Err', _subscriptionService.initializationError!, false),
                _debugRow('Offerings', _offerings != null ? 'LOADED ✓' : 'NULL ✗', _offerings != null),
                _debugRow('Current', _offerings?.current?.identifier ?? 'NULL', _offerings?.current != null),
                _debugRow('Packages', '${_offerings?.current?.availablePackages.length ?? 0}', (_offerings?.current?.availablePackages.length ?? 0) > 0),
                if (_subscriptionService.lastOfferingsError != null)
                  _debugRow('Offer Err', _subscriptionService.lastOfferingsError!, false),
                _debugRow('Button', !_isPurchasing && !_isRestoring && _offerings != null ? 'ENABLED ✓' : 'DISABLED ✗', !_isPurchasing && !_isRestoring && _offerings != null),
                if (_errorMessage != null)
                  _debugRow('Scr Err', _errorMessage!, false),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _debugRow(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isOk ? Colors.greenAccent : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
