import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../config/dev_config.dart';
import '../config/revenuecat_config.dart';
import '../models/couple_subscription_status.dart';
import '../utils/logger.dart';
import 'api_client.dart';

/// Subscription service for managing in-app purchases via RevenueCat
///
/// Responsibilities:
/// - Initialize RevenueCat SDK
/// - Track premium subscription status
/// - Handle purchases and restores
/// - Sync user identity with RevenueCat
///
/// Usage:
/// ```dart
/// // Check if user has premium
/// if (SubscriptionService().isPremium) { ... }
///
/// // Get offerings for paywall
/// final offerings = await SubscriptionService().getOfferings();
///
/// // Purchase a package
/// await SubscriptionService().purchasePackage(package);
/// ```
class SubscriptionService with ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // State
  bool _isInitialized = false;
  String? _initializationError;  // Stores error if initialization failed
  CustomerInfo? _customerInfo;

  // Couple-level subscription status (one subscription, two accounts)
  CoupleSubscriptionStatus? _coupleSubscriptionStatus;

  // Dev bypass flag (set via triple-tap on paywall for testing)
  bool _devBypass = false;

  // Stream for subscription status changes (legacy - use addListener instead)
  final _premiumStatusController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  // Hive box keys
  static const String _premiumCacheKey = 'subscription_is_premium';
  static const String _coupleStatusCacheKey = 'couple_subscription_status';
  static const String _coupleStatusCacheTimeKey = 'couple_subscription_status_time';
  static const String _pendingActivationKey = 'pending_subscription_activation';

  /// Get the current couple subscription status
  CoupleSubscriptionStatus? get coupleStatus => _coupleSubscriptionStatus;

  /// Set dev bypass flag (triple-tap on paywall for testing)
  ///
  /// When true, [isPremium] returns true regardless of subscription state.
  /// Use this for testing the app without subscribing in TestFlight builds.
  void setDevBypass(bool enabled) {
    _devBypass = enabled;
    notifyListeners();
  }

  /// Check if dev bypass is active
  bool get isDevBypassActive => _devBypass;

  /// Initialize RevenueCat SDK
  ///
  /// Should be called early in app startup, after Firebase but before auth.
  /// Safe to call multiple times - will no-op if already initialized.
  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.debug('SubscriptionService already initialized', service: 'subscription');
      return;
    }

    // Skip on web - RevenueCat doesn't support web
    if (kIsWeb) {
      Logger.info('SubscriptionService: Skipping on web platform', service: 'subscription');
      _isInitialized = true;
      _initializationError = null;
      return;
    }

    // Check if configured
    if (!RevenueCatConfig.isConfigured) {
      Logger.warn('RevenueCat not configured - subscription features disabled', service: 'subscription');
      _isInitialized = true;
      _initializationError = 'API key not configured';
      return;
    }

    try {
      // Get appropriate API key for platform
      final apiKey = Platform.isIOS
          ? RevenueCatConfig.iosApiKey
          : RevenueCatConfig.androidApiKey;

      // Configure RevenueCat
      final configuration = PurchasesConfiguration(apiKey);

      // Enable debug logs in debug mode
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      await Purchases.configure(configuration);

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

      // Get initial customer info
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumCache();

      _isInitialized = true;
      _initializationError = null;
      Logger.info('SubscriptionService initialized successfully', service: 'subscription');
      Logger.debug('Premium status: $isPremium', service: 'subscription');
    } catch (e) {
      Logger.error('Failed to initialize SubscriptionService', error: e, service: 'subscription');
      _isInitialized = true; // Mark as initialized to prevent repeated attempts
      _initializationError = e.toString();
    }
  }

  /// Log in user to RevenueCat (sync identity)
  ///
  /// Call this after successful Supabase authentication.
  /// This associates the user's purchases with their account.
  Future<void> logIn(String userId) async {
    if (kIsWeb || !RevenueCatConfig.isConfigured) return;

    try {
      Logger.debug('Logging in to RevenueCat with userId: $userId', service: 'subscription');
      final result = await Purchases.logIn(userId);
      _customerInfo = result.customerInfo;
      _updatePremiumCache();
      notifyListeners();
      Logger.info('RevenueCat login successful', service: 'subscription');
    } catch (e) {
      Logger.error('RevenueCat login failed', error: e, service: 'subscription');
    }
  }

  /// Log out user from RevenueCat
  ///
  /// Call this when user signs out of the app.
  /// Creates an anonymous user for the device.
  Future<void> logOut() async {
    if (kIsWeb || !RevenueCatConfig.isConfigured) return;

    try {
      Logger.debug('Logging out from RevenueCat', service: 'subscription');
      _customerInfo = await Purchases.logOut();
      _updatePremiumCache();
      notifyListeners();
      Logger.info('RevenueCat logout successful', service: 'subscription');
    } catch (e) {
      Logger.error('RevenueCat logout failed', error: e, service: 'subscription');
    }
  }

  /// Check if user has premium entitlement
  ///
  /// Uses cached value for fast synchronous access.
  /// Checks both couple-level subscription and RevenueCat entitlement.
  /// For most up-to-date status, call [refreshPremiumStatus] first.
  bool get isPremium {
    // Dev bypass via triple-tap on paywall (works in release builds)
    if (_devBypass) {
      return true;
    }

    // Dev bypass: Skip subscription check in debug mode
    if (kDebugMode && DevConfig.skipSubscriptionCheckInDev) {
      return true;
    }

    // Check couple-level subscription first (partner may have subscribed)
    // This works on all platforms including web
    if (_coupleSubscriptionStatus?.isActive == true) {
      return true;
    }

    // If server explicitly says expired, trust that over RevenueCat
    // This prevents showing premium when a different Apple ID on the device
    // has an active subscription that doesn't belong to this couple
    if (_coupleSubscriptionStatus?.status == 'expired') {
      return false;
    }

    // Check cached couple status (for offline partner access)
    final cachedCoupleStatus = _getCachedCoupleStatus();
    if (cachedCoupleStatus?.isActive == true) {
      // Verify not expired
      if (cachedCoupleStatus!.expiresAt == null ||
          cachedCoupleStatus.expiresAt!.isAfter(DateTime.now())) {
        return true;
      }
    }

    // If cached status is expired, trust that
    if (cachedCoupleStatus?.status == 'expired') {
      return false;
    }

    // On web, no RevenueCat support - rely on couple subscription only
    if (kIsWeb) return false;

    // If not configured, return false
    if (!RevenueCatConfig.isConfigured) return false;

    // Check RevenueCat for users who haven't checked server yet (new purchase/restore)
    if (_customerInfo != null) {
      return _hasRevenueCatPremium();
    }

    // Fall back to Hive cache for offline access
    return _getCachedPremiumStatus();
  }

  /// Refresh premium status from RevenueCat
  ///
  /// Call this on app resume or when you need the latest status.
  Future<bool> refreshPremiumStatus() async {
    if (kIsWeb || !RevenueCatConfig.isConfigured) return false;

    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumCache();
      notifyListeners();
      return isPremium;
    } catch (e) {
      Logger.error('Failed to refresh premium status', error: e, service: 'subscription');
      return isPremium; // Return cached value on error
    }
  }

  // Last error from getOfferings (for debugging)
  String? _lastOfferingsError;

  /// Get last offerings fetch error (for debugging)
  String? get lastOfferingsError => _lastOfferingsError;

  /// Get available offerings for the paywall
  ///
  /// Returns null if offerings couldn't be fetched.
  Future<Offerings?> getOfferings() async {
    _lastOfferingsError = null;

    if (kIsWeb) {
      _lastOfferingsError = 'Web platform not supported';
      return null;
    }

    if (!RevenueCatConfig.isConfigured) {
      _lastOfferingsError = 'RevenueCat not configured';
      return null;
    }

    if (_initializationError != null) {
      _lastOfferingsError = 'SDK init failed: $_initializationError';
      return null;
    }

    try {
      final offerings = await Purchases.getOfferings();
      Logger.debug('Fetched offerings: ${offerings.current?.identifier}', service: 'subscription');

      // Additional debug info
      if (offerings.current == null) {
        _lastOfferingsError = 'No current offering set in RevenueCat dashboard';
      } else if (offerings.current!.availablePackages.isEmpty) {
        _lastOfferingsError = 'Current offering has no packages';
      }

      return offerings;
    } catch (e) {
      Logger.error('Failed to fetch offerings', error: e, service: 'subscription');
      _lastOfferingsError = e.toString();
      return null;
    }
  }

  /// Get detailed debug info about the SDK state
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'initializationError': _initializationError,
      'isInitializedSuccessfully': isInitializedSuccessfully,
      'isConfigured': RevenueCatConfig.isConfigured,
      'apiKeyPrefix': RevenueCatConfig.iosApiKey.length > 10
          ? '${RevenueCatConfig.iosApiKey.substring(0, 10)}...'
          : RevenueCatConfig.iosApiKey,
      'entitlementId': RevenueCatConfig.premiumEntitlement,
      'lastOfferingsError': _lastOfferingsError,
      'hasCustomerInfo': _customerInfo != null,
      'isPremium': isPremium,
      'isDevBypassActive': _devBypass,
      'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'iOS' : 'Android'),
    };
  }

  /// Purchase a package
  ///
  /// Returns PurchaseResult indicating success, cancellation, or if partner already subscribed.
  /// Throws [PurchasesError] on failure (payment failed, etc.)
  Future<PurchaseResult> purchasePackage(Package package) async {
    if (kIsWeb || !RevenueCatConfig.isConfigured) {
      return PurchaseResult.failed('Not available on this platform');
    }

    try {
      Logger.debug('Purchasing package: ${package.identifier}', service: 'subscription');
      _customerInfo = await Purchases.purchasePackage(package);
      _updatePremiumCache();

      // CRITICAL: Clear couple status (in-memory AND cache) after successful purchase.
      // This allows isPremium to check RevenueCat directly even if server
      // still says "expired" (activation may have failed).
      // The status will be refreshed when we call checkCoupleSubscription() later.
      _clearCoupleStatus();

      // Check if purchase gave us premium entitlement (using fuzzy match for Unicode variations)
      final hasEntitlement = _hasRevenueCatPremium();

      if (hasEntitlement) {
        // Activate subscription for the couple (with retry)
        final activationResult = await _activateForCoupleWithRetry(
          package.storeProduct.identifier,
        );

        if (activationResult != null && activationResult.isAlreadySubscribed) {
          // Partner subscribed at the same time - our purchase went through but
          // they got there first. Show the already subscribed screen.
          Logger.info('Partner already subscribed during purchase', service: 'subscription');
          return PurchaseResult.alreadySubscribed(activationResult.subscriberName);
        }

        Logger.info('Purchase successful, couple activated', service: 'subscription');
        notifyListeners();
        return PurchaseResult.success();
      }

      Logger.warn('Purchase completed but no entitlement', service: 'subscription');
      notifyListeners();
      return PurchaseResult.failed('Purchase completed but subscription not active');
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        Logger.debug('Purchase cancelled by user', service: 'subscription');
        return PurchaseResult.cancelled();
      }

      Logger.error('Purchase failed: ${errorCode.name}', error: e, service: 'subscription');
      return PurchaseResult.failed('Purchase failed: ${errorCode.name}');
    }
  }

  /// Restore previous purchases
  ///
  /// Checks couple-level subscription first (partner may have subscribed),
  /// then falls back to RevenueCat restore.
  ///
  /// Returns RestoreResult indicating what was found.
  Future<RestoreResult> restorePurchases() async {
    // First: Check if partner already subscribed (couple-level)
    try {
      final status = await checkCoupleSubscription();
      if (status != null && status.isActive) {
        _coupleSubscriptionStatus = status;
        _updateCoupleStatusCache(status);
        notifyListeners();
        Logger.info('Restore: Partner subscription found', service: 'subscription');
        return RestoreResult.coupleActive(status.subscriberName);
      }
    } catch (e) {
      Logger.debug('Couple status check failed during restore: $e', service: 'subscription');
    }

    // Second: Try RevenueCat restore (for the original subscriber)
    if (!kIsWeb && RevenueCatConfig.isConfigured) {
      try {
        Logger.debug('Restoring purchases via RevenueCat', service: 'subscription');
        _customerInfo = await Purchases.restorePurchases();
        _updatePremiumCache();

        // CRITICAL: Clear couple status (in-memory AND cache) after successful restore.
        // This allows isPremium to check RevenueCat directly even if server
        // still says "expired" (previous status check may have been stale).
        _clearCoupleStatus();

        // Use fuzzy matching for Unicode variations in entitlement name
        final entitlement = _getPremiumEntitlement();

        if (entitlement != null) {
          // Subscriber restored - also activate for couple
          await _activateForCoupleWithRetry(
            entitlement.productIdentifier ?? 'restored',
          );

          notifyListeners();
          Logger.info('Restore: RevenueCat subscription restored', service: 'subscription');
          return RestoreResult.revenueCatRestored();
        }
      } catch (e) {
        Logger.error('RevenueCat restore failed', error: e, service: 'subscription');
      }
    }

    Logger.info('Restore: No subscription found', service: 'subscription');
    return RestoreResult.nothingToRestore();
  }

  /// Get the current customer info (for debugging/display)
  CustomerInfo? get customerInfo => _customerInfo;

  /// Check if subscription service is ready
  bool get isInitialized => _isInitialized;

  /// Get initialization error (null if successful)
  String? get initializationError => _initializationError;

  /// Check if initialization actually succeeded (no error)
  bool get isInitializedSuccessfully => _isInitialized && _initializationError == null;

  // ============================================================================
  // REVENUECAT PAYWALL UI
  // ============================================================================

  /// Present the RevenueCat Paywall UI
  ///
  /// Returns PaywallResult indicating what happened:
  /// - purchased: User successfully purchased
  /// - restored: User restored a previous purchase
  /// - cancelled: User dismissed without purchasing
  /// - error: An error occurred
  ///
  /// If purchase/restore succeeded, also activates subscription for couple.
  Future<PaywallPresentResult> presentPaywall() async {
    if (kIsWeb) {
      Logger.warn('RevenueCat Paywall not available on web', service: 'subscription');
      return PaywallPresentResult.notAvailable();
    }

    if (!RevenueCatConfig.isConfigured) {
      Logger.warn('RevenueCat not configured', service: 'subscription');
      return PaywallPresentResult.notAvailable();
    }

    try {
      Logger.debug('Presenting RevenueCat Paywall', service: 'subscription');

      final result = await RevenueCatUI.presentPaywall();

      Logger.debug('Paywall result: $result', service: 'subscription');

      // Refresh customer info after paywall interaction
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumCache();

      // Check if user now has premium
      if (isPremium) {
        // Activate for couple with the product they purchased
        // Use fuzzy matching for Unicode variations in entitlement name
        final entitlement = _getPremiumEntitlement();
        final productId = entitlement?.productIdentifier;

        if (productId != null) {
          await _activateForCoupleWithRetry(productId);
        }

        notifyListeners();
        return PaywallPresentResult.purchased();
      }

      // Map the result
      switch (result) {
        case PaywallResult.purchased:
          return PaywallPresentResult.purchased();
        case PaywallResult.restored:
          return PaywallPresentResult.restored();
        case PaywallResult.cancelled:
          return PaywallPresentResult.cancelled();
        case PaywallResult.error:
          return PaywallPresentResult.error('Paywall error occurred');
        default:
          return PaywallPresentResult.cancelled();
      }
    } catch (e) {
      Logger.error('Failed to present paywall', error: e, service: 'subscription');
      return PaywallPresentResult.error(e.toString());
    }
  }

  /// Present the RevenueCat Paywall UI if user doesn't have premium
  ///
  /// Convenience method that only shows paywall if needed.
  /// Returns true if user has (or now has) premium access.
  Future<bool> presentPaywallIfNeeded() async {
    if (isPremium) {
      Logger.debug('User already has premium, skipping paywall', service: 'subscription');
      return true;
    }

    final result = await presentPaywall();
    return result.didPurchaseOrRestore;
  }

  // ============================================================================
  // CUSTOMER CENTER
  // ============================================================================

  /// Present the RevenueCat Customer Center
  ///
  /// The Customer Center allows users to:
  /// - View their subscription details
  /// - Manage their subscription (upgrade/downgrade/cancel)
  /// - Restore purchases
  /// - Contact support
  ///
  /// Returns CustomerCenterResult indicating what happened.
  Future<CustomerCenterResult> presentCustomerCenter() async {
    if (kIsWeb) {
      Logger.warn('Customer Center not available on web', service: 'subscription');
      return CustomerCenterResult.notAvailable();
    }

    if (!RevenueCatConfig.isConfigured) {
      Logger.warn('RevenueCat not configured', service: 'subscription');
      return CustomerCenterResult.notAvailable();
    }

    try {
      Logger.debug('Presenting Customer Center', service: 'subscription');

      await RevenueCatUI.presentCustomerCenter();

      // Refresh customer info after customer center interaction
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumCache();
      notifyListeners();

      Logger.debug('Customer Center dismissed', service: 'subscription');
      return CustomerCenterResult.dismissed();
    } catch (e) {
      Logger.error('Failed to present Customer Center', error: e, service: 'subscription');
      return CustomerCenterResult.error(e.toString());
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Get the premium entitlement from customer info using fuzzy matching.
  ///
  /// RevenueCat sometimes returns entitlement names with different Unicode
  /// characters (e.g., U+2024 ONE DOT LEADER instead of U+002E FULL STOP).
  /// This method finds the entitlement regardless of such variations.
  EntitlementInfo? _getPremiumEntitlement() {
    if (_customerInfo == null) return null;

    // First try exact match
    final exactMatch = _customerInfo!.entitlements.active[RevenueCatConfig.premiumEntitlement];
    if (exactMatch != null) return exactMatch;

    // Fall back to fuzzy matching
    for (final entry in _customerInfo!.entitlements.active.entries) {
      if (RevenueCatConfig.isPremiumEntitlement(entry.key)) {
        Logger.debug(
          'Found entitlement via fuzzy match: "${entry.key}" (expected: "${RevenueCatConfig.premiumEntitlement}")',
          service: 'subscription',
        );
        return entry.value;
      }
    }

    return null;
  }

  /// Check if customer has premium entitlement (using fuzzy matching).
  bool _hasRevenueCatPremium() {
    return _getPremiumEntitlement() != null;
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    Logger.debug('Customer info updated', service: 'subscription');
    _customerInfo = customerInfo;
    _updatePremiumCache();
    _premiumStatusController.add(isPremium);
    notifyListeners(); // Notify ChangeNotifier listeners
  }

  void _updatePremiumCache() {
    // Use fuzzy matching for Unicode variations in entitlement name
    final premium = _hasRevenueCatPremium();

    // Cache in Hive for offline access
    try {
      final box = Hive.box('app_metadata');
      box.put(_premiumCacheKey, premium);
    } catch (e) {
      Logger.debug('Failed to cache premium status: $e', service: 'subscription');
    }
  }

  bool _getCachedPremiumStatus() {
    try {
      final box = Hive.box('app_metadata');
      return box.get(_premiumCacheKey, defaultValue: false) as bool;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // COUPLE-LEVEL SUBSCRIPTION (One subscription, two accounts)
  // ============================================================================

  /// Check couple-level subscription status from server.
  ///
  /// Returns null on error (network failure, not paired, etc.)
  Future<CoupleSubscriptionStatus?> checkCoupleSubscription() async {
    try {
      final response = await ApiClient().get('/api/subscription/status');

      if (!response.success || response.data == null) {
        Logger.debug('Couple subscription check failed: ${response.error}', service: 'subscription');
        return null;
      }

      final status = CoupleSubscriptionStatus.fromJson(
        response.data as Map<String, dynamic>,
      );

      _coupleSubscriptionStatus = status;
      _updateCoupleStatusCache(status);
      notifyListeners();

      return status;
    } catch (e) {
      Logger.error('Error checking couple subscription', error: e, service: 'subscription');
      return null;
    }
  }

  /// Activate subscription for couple after RevenueCat purchase.
  ///
  /// Returns ActivationResult indicating if activation succeeded or partner already subscribed.
  Future<ActivationResult?> activateForCouple({
    required String productId,
    DateTime? expiresAt,
  }) async {
    try {
      final response = await ApiClient().post(
        '/api/subscription/activate',
        body: {
          'productId': productId,
          if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        },
      );

      if (!response.success || response.data == null) {
        Logger.error('Couple activation failed: ${response.error}', service: 'subscription');
        return null;
      }

      final result = ActivationResult.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Refresh couple status after activation
      if (result.wasActivated) {
        await checkCoupleSubscription();
      }

      return result;
    } catch (e) {
      Logger.error('Error activating couple subscription', error: e, service: 'subscription');
      return null;
    }
  }

  /// Set the couple subscription status (used by bootstrap).
  void setCoupleStatus(CoupleSubscriptionStatus? status) {
    _coupleSubscriptionStatus = status;
    if (status != null) {
      _updateCoupleStatusCache(status);
    }
    notifyListeners();
  }

  /// Retry pending activation from a previous failed attempt.
  ///
  /// Call this on app startup to handle cases where purchase succeeded
  /// but server activation failed.
  Future<void> retryPendingActivation() async {
    final pending = _getPendingActivation();
    if (pending == null) return;

    // Only retry if we have a valid RevenueCat entitlement (use fuzzy matching)
    if (!kIsWeb && RevenueCatConfig.isConfigured && _customerInfo != null) {
      final hasEntitlement = _hasRevenueCatPremium();

      if (hasEntitlement) {
        Logger.info('Retrying pending activation for: $pending', service: 'subscription');
        try {
          final expiresAt = _getExpirationDate();
          await activateForCouple(productId: pending, expiresAt: expiresAt);
          _clearPendingActivation();
          Logger.info('Pending activation retry successful', service: 'subscription');
        } catch (e) {
          Logger.error('Pending activation retry failed', error: e, service: 'subscription');
        }
      }
    }
  }

  /// Check if current user has RevenueCat entitlement.
  ///
  /// Used to determine if user can transfer subscription to new couple on re-pair.
  /// Uses fuzzy matching for Unicode variations in entitlement name.
  bool get hasRevenueCatEntitlement {
    if (kIsWeb || !RevenueCatConfig.isConfigured || _customerInfo == null) {
      return false;
    }
    return _hasRevenueCatPremium();
  }

  /// Get current product ID from RevenueCat entitlement.
  /// Uses fuzzy matching for Unicode variations in entitlement name.
  String? get currentProductId {
    final entitlement = _getPremiumEntitlement();
    return entitlement?.productIdentifier;
  }

  /// Get current expiration date from RevenueCat entitlement.
  /// Uses fuzzy matching for Unicode variations in entitlement name.
  DateTime? get currentExpiresAt {
    return _getExpirationDate();
  }

  // ============================================================================
  // PRIVATE HELPERS - COUPLE SUBSCRIPTION
  // ============================================================================

  /// Activate for couple with retry logic.
  Future<ActivationResult?> _activateForCoupleWithRetry(String productId) async {
    const maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final expiresAt = _getExpirationDate();
        final result = await activateForCouple(
          productId: productId,
          expiresAt: expiresAt,
        );

        if (result != null) {
          _clearPendingActivation();
          return result;
        }
      } catch (e) {
        Logger.error('Activate attempt $attempt failed', error: e, service: 'subscription');
      }

      if (attempt < maxRetries) {
        // Exponential backoff
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    // All retries failed - save for retry on next app open
    _savePendingActivation(productId);
    Logger.warn('Activation failed after $maxRetries attempts, saved for retry', service: 'subscription');

    // Return null to indicate failure - webhook will also activate
    return null;
  }

  /// Get expiration date from RevenueCat customer info.
  /// Uses fuzzy matching for Unicode variations in entitlement name.
  DateTime? _getExpirationDate() {
    final entitlement = _getPremiumEntitlement();
    if (entitlement?.expirationDate == null) return null;

    return DateTime.parse(entitlement!.expirationDate!);
  }

  /// Cache couple subscription status for offline access.
  void _updateCoupleStatusCache(CoupleSubscriptionStatus status) {
    try {
      final box = Hive.box('app_metadata');
      box.put(_coupleStatusCacheKey, jsonEncode(status.toJson()));
      box.put(_coupleStatusCacheTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      Logger.debug('Failed to cache couple status: $e', service: 'subscription');
    }
  }

  /// Clear both in-memory and cached couple status.
  /// Used after a successful purchase/restore to allow isPremium
  /// to check RevenueCat directly without being blocked by stale server status.
  void _clearCoupleStatus() {
    _coupleSubscriptionStatus = null;
    try {
      final box = Hive.box('app_metadata');
      box.delete(_coupleStatusCacheKey);
      box.delete(_coupleStatusCacheTimeKey);
      Logger.debug('Cleared couple status cache', service: 'subscription');
    } catch (e) {
      Logger.debug('Failed to clear couple status cache: $e', service: 'subscription');
    }
  }

  /// Get cached couple subscription status (for offline partner access).
  ///
  /// Returns null if cache is too old (>7 days) or doesn't exist.
  CoupleSubscriptionStatus? _getCachedCoupleStatus() {
    try {
      final box = Hive.box('app_metadata');
      final jsonString = box.get(_coupleStatusCacheKey) as String?;
      final cacheTime = box.get(_coupleStatusCacheTimeKey) as String?;

      if (jsonString == null) return null;

      // Check if cache is still valid (within 7 days for offline grace period)
      if (cacheTime != null) {
        final cached = DateTime.parse(cacheTime);
        if (DateTime.now().difference(cached).inDays > 7) {
          Logger.debug('Couple status cache expired', service: 'subscription');
          return null;
        }
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return CoupleSubscriptionStatus.fromJson(json);
    } catch (e) {
      Logger.debug('Failed to read couple status cache: $e', service: 'subscription');
      return null;
    }
  }

  /// Save pending activation for retry on app restart.
  void _savePendingActivation(String productId) {
    try {
      final box = Hive.box('app_metadata');
      box.put(_pendingActivationKey, productId);
    } catch (e) {
      Logger.debug('Failed to save pending activation: $e', service: 'subscription');
    }
  }

  /// Get pending activation product ID.
  String? _getPendingActivation() {
    try {
      final box = Hive.box('app_metadata');
      return box.get(_pendingActivationKey) as String?;
    } catch (e) {
      return null;
    }
  }

  /// Clear pending activation.
  void _clearPendingActivation() {
    try {
      final box = Hive.box('app_metadata');
      box.delete(_pendingActivationKey);
    } catch (e) {
      Logger.debug('Failed to clear pending activation: $e', service: 'subscription');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _premiumStatusController.close();
    super.dispose();
  }
}
