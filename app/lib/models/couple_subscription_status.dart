/// Models for the couple-level subscription system.
///
/// These models are used by SubscriptionService to track
/// subscription status at the couple level (one subscription, two accounts).

/// Status of the couple's subscription from the server.
class CoupleSubscriptionStatus {
  /// Subscription status: 'none', 'trial', 'active', 'cancelled', 'expired', 'refunded'
  final String status;

  /// Whether the subscription is currently active (includes trial)
  final bool isActive;

  /// Whether the current user is the one who subscribed
  final bool subscribedByMe;

  /// Name of the user who subscribed (if any)
  final String? subscriberName;

  /// User ID of the subscriber (if any)
  final String? subscriberId;

  /// When the current billing period ends
  final DateTime? expiresAt;

  /// RevenueCat product ID
  final String? productId;

  /// Whether the current user can manage the subscription
  final bool canManage;

  CoupleSubscriptionStatus({
    required this.status,
    required this.isActive,
    required this.subscribedByMe,
    this.subscriberName,
    this.subscriberId,
    this.expiresAt,
    this.productId,
    required this.canManage,
  });

  factory CoupleSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return CoupleSubscriptionStatus(
      status: json['status'] as String? ?? 'none',
      isActive: json['isActive'] as bool? ?? false,
      subscribedByMe: json['subscribedByMe'] as bool? ?? false,
      subscriberName: json['subscriberName'] as String?,
      subscriberId: json['subscriberId'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      productId: json['productId'] as String?,
      canManage: json['canManage'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'isActive': isActive,
      'subscribedByMe': subscribedByMe,
      'subscriberName': subscriberName,
      'subscriberId': subscriberId,
      'expiresAt': expiresAt?.toIso8601String(),
      'productId': productId,
      'canManage': canManage,
    };
  }

  /// Creates a "not subscribed" status
  factory CoupleSubscriptionStatus.none() {
    return CoupleSubscriptionStatus(
      status: 'none',
      isActive: false,
      subscribedByMe: false,
      canManage: false,
    );
  }
}

/// Result of attempting to activate a subscription for the couple.
class ActivationResult {
  /// Status: 'activated' or 'already_subscribed'
  final String status;

  /// Name of partner who already subscribed (if already_subscribed)
  final String? subscriberName;

  /// Message to display
  final String? message;

  ActivationResult({
    required this.status,
    this.subscriberName,
    this.message,
  });

  factory ActivationResult.fromJson(Map<String, dynamic> json) {
    return ActivationResult(
      status: json['status'] as String? ?? 'activated',
      subscriberName: json['subscriberName'] as String?,
      message: json['message'] as String?,
    );
  }

  bool get isAlreadySubscribed => status == 'already_subscribed';
  bool get wasActivated => status == 'activated';
}

/// Result of a purchase attempt.
class PurchaseResult {
  final bool success;
  final bool isAlreadySubscribed;
  final String? subscriberName;
  final String? error;

  PurchaseResult._({
    required this.success,
    required this.isAlreadySubscribed,
    this.subscriberName,
    this.error,
  });

  /// Successful purchase
  factory PurchaseResult.success() {
    return PurchaseResult._(
      success: true,
      isAlreadySubscribed: false,
    );
  }

  /// Partner already subscribed
  factory PurchaseResult.alreadySubscribed(String? subscriberName) {
    return PurchaseResult._(
      success: true,
      isAlreadySubscribed: true,
      subscriberName: subscriberName,
    );
  }

  /// User cancelled
  factory PurchaseResult.cancelled() {
    return PurchaseResult._(
      success: false,
      isAlreadySubscribed: false,
    );
  }

  /// Purchase failed with error
  factory PurchaseResult.failed(String error) {
    return PurchaseResult._(
      success: false,
      isAlreadySubscribed: false,
      error: error,
    );
  }
}

/// Result of a restore purchases attempt.
class RestoreResult {
  final bool isCoupleActive;
  final bool isRevenueCatRestored;
  final String? subscriberName;

  RestoreResult._({
    required this.isCoupleActive,
    required this.isRevenueCatRestored,
    this.subscriberName,
  });

  /// Partner has active subscription - couple is subscribed
  factory RestoreResult.coupleActive(String? subscriberName) {
    return RestoreResult._(
      isCoupleActive: true,
      isRevenueCatRestored: false,
      subscriberName: subscriberName,
    );
  }

  /// Own RevenueCat subscription was restored
  factory RestoreResult.revenueCatRestored() {
    return RestoreResult._(
      isCoupleActive: false,
      isRevenueCatRestored: true,
    );
  }

  /// No subscription found
  factory RestoreResult.nothingToRestore() {
    return RestoreResult._(
      isCoupleActive: false,
      isRevenueCatRestored: false,
    );
  }

  bool get hasSubscription => isCoupleActive || isRevenueCatRestored;
}

/// Result of presenting the RevenueCat Paywall UI.
class PaywallPresentResult {
  final PaywallPresentStatus status;
  final String? error;

  PaywallPresentResult._({
    required this.status,
    this.error,
  });

  /// User successfully purchased
  factory PaywallPresentResult.purchased() {
    return PaywallPresentResult._(status: PaywallPresentStatus.purchased);
  }

  /// User restored a previous purchase
  factory PaywallPresentResult.restored() {
    return PaywallPresentResult._(status: PaywallPresentStatus.restored);
  }

  /// User cancelled without purchasing
  factory PaywallPresentResult.cancelled() {
    return PaywallPresentResult._(status: PaywallPresentStatus.cancelled);
  }

  /// An error occurred
  factory PaywallPresentResult.error(String error) {
    return PaywallPresentResult._(
      status: PaywallPresentStatus.error,
      error: error,
    );
  }

  /// Paywall not available (web platform or not configured)
  factory PaywallPresentResult.notAvailable() {
    return PaywallPresentResult._(status: PaywallPresentStatus.notAvailable);
  }

  /// Whether the user purchased or restored successfully
  bool get didPurchaseOrRestore =>
      status == PaywallPresentStatus.purchased ||
      status == PaywallPresentStatus.restored;

  /// Whether the paywall was shown
  bool get wasPresented =>
      status != PaywallPresentStatus.notAvailable &&
      status != PaywallPresentStatus.error;
}

/// Status of the paywall presentation.
enum PaywallPresentStatus {
  purchased,
  restored,
  cancelled,
  error,
  notAvailable,
}

/// Result of presenting the Customer Center.
class CustomerCenterResult {
  final CustomerCenterStatus status;
  final String? error;

  CustomerCenterResult._({
    required this.status,
    this.error,
  });

  /// Customer Center was dismissed normally
  factory CustomerCenterResult.dismissed() {
    return CustomerCenterResult._(status: CustomerCenterStatus.dismissed);
  }

  /// An error occurred
  factory CustomerCenterResult.error(String error) {
    return CustomerCenterResult._(
      status: CustomerCenterStatus.error,
      error: error,
    );
  }

  /// Customer Center not available (web platform or not configured)
  factory CustomerCenterResult.notAvailable() {
    return CustomerCenterResult._(status: CustomerCenterStatus.notAvailable);
  }

  bool get wasPresented =>
      status != CustomerCenterStatus.notAvailable &&
      status != CustomerCenterStatus.error;
}

/// Status of the Customer Center presentation.
enum CustomerCenterStatus {
  dismissed,
  error,
  notAvailable,
}
