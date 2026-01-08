import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/dev_config.dart';
import '../config/revenuecat_config.dart';
import '../utils/logger.dart';

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
  CustomerInfo? _customerInfo;

  // Stream for subscription status changes (legacy - use addListener instead)
  final _premiumStatusController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  // Hive box key for caching premium status
  static const String _premiumCacheKey = 'subscription_is_premium';

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
      return;
    }

    // Check if configured
    if (!RevenueCatConfig.isConfigured) {
      Logger.warn('RevenueCat not configured - subscription features disabled', service: 'subscription');
      _isInitialized = true;
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
      Logger.info('SubscriptionService initialized successfully', service: 'subscription');
      Logger.debug('Premium status: $isPremium', service: 'subscription');
    } catch (e) {
      Logger.error('Failed to initialize SubscriptionService', error: e, service: 'subscription');
      _isInitialized = true; // Mark as initialized to prevent repeated attempts
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
  /// For most up-to-date status, call [refreshPremiumStatus] first.
  bool get isPremium {
    // Dev bypass: Skip subscription check in debug mode
    if (kDebugMode && DevConfig.skipSubscriptionCheckInDev) {
      return true;
    }

    // On web, always return false (no IAP support)
    if (kIsWeb) return false;

    // If not configured, return false
    if (!RevenueCatConfig.isConfigured) return false;

    // Check cached customer info first
    if (_customerInfo != null) {
      return _customerInfo!.entitlements.active.containsKey(RevenueCatConfig.premiumEntitlement);
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

  /// Get available offerings for the paywall
  ///
  /// Returns null if offerings couldn't be fetched.
  Future<Offerings?> getOfferings() async {
    if (kIsWeb || !RevenueCatConfig.isConfigured) return null;

    try {
      final offerings = await Purchases.getOfferings();
      Logger.debug('Fetched offerings: ${offerings.current?.identifier}', service: 'subscription');
      return offerings;
    } catch (e) {
      Logger.error('Failed to fetch offerings', error: e, service: 'subscription');
      return null;
    }
  }

  /// Purchase a package
  ///
  /// Returns true if purchase was successful.
  /// Throws [PurchasesError] on failure (user cancelled, payment failed, etc.)
  Future<bool> purchasePackage(Package package) async {
    if (kIsWeb || !RevenueCatConfig.isConfigured) return false;

    try {
      Logger.debug('Purchasing package: ${package.identifier}', service: 'subscription');
      _customerInfo = await Purchases.purchasePackage(package);
      _updatePremiumCache();
      notifyListeners();

      final success = isPremium;
      Logger.info('Purchase ${success ? 'successful' : 'completed but not premium'}', service: 'subscription');
      return success;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        Logger.debug('Purchase cancelled by user', service: 'subscription');
        return false;
      }

      Logger.error('Purchase failed: ${errorCode.name}', error: e, service: 'subscription');
      rethrow;
    }
  }

  /// Restore previous purchases
  ///
  /// Call this when user taps "Restore Purchases" button.
  /// Returns true if any purchases were restored.
  Future<bool> restorePurchases() async {
    if (kIsWeb || !RevenueCatConfig.isConfigured) return false;

    try {
      Logger.debug('Restoring purchases', service: 'subscription');
      _customerInfo = await Purchases.restorePurchases();
      _updatePremiumCache();
      notifyListeners();

      final restored = isPremium;
      Logger.info('Restore ${restored ? 'successful - premium active' : 'completed - no premium found'}', service: 'subscription');
      return restored;
    } catch (e) {
      Logger.error('Restore purchases failed', error: e, service: 'subscription');
      rethrow;
    }
  }

  /// Get the current customer info (for debugging/display)
  CustomerInfo? get customerInfo => _customerInfo;

  /// Check if subscription service is ready
  bool get isInitialized => _isInitialized;

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    Logger.debug('Customer info updated', service: 'subscription');
    _customerInfo = customerInfo;
    _updatePremiumCache();
    _premiumStatusController.add(isPremium);
    notifyListeners(); // Notify ChangeNotifier listeners
  }

  void _updatePremiumCache() {
    final premium = _customerInfo?.entitlements.active.containsKey(RevenueCatConfig.premiumEntitlement) ?? false;

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

  /// Dispose resources
  void dispose() {
    _premiumStatusController.close();
  }
}
