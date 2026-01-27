import 'api_client.dart';
import '../utils/logger.dart';

/// Represents a user notification from the server
class UserNotification {
  final String id;
  final String type;
  final String message;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Check if this is a "partner left" notification
  bool get isPartnerLeft => type == 'partner_left';
}

/// Service for checking and dismissing user notifications
///
/// Used to show one-time messages like "Your partner has left Us 2.0"
class UserNotificationService {
  static final UserNotificationService _instance = UserNotificationService._internal();
  factory UserNotificationService() => _instance;
  UserNotificationService._internal();

  final _api = ApiClient();

  /// Fetch unread notifications for the current user
  Future<List<UserNotification>> getNotifications() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/api/user/notifications',
        parser: (json) => json,
      );

      if (!response.success || response.data == null) {
        Logger.debug('Failed to fetch notifications: ${response.error}', service: 'notification');
        return [];
      }

      final notifications = (response.data!['notifications'] as List<dynamic>?)
          ?.map((n) => UserNotification.fromJson(n as Map<String, dynamic>))
          .toList() ?? [];

      Logger.debug('Fetched ${notifications.length} notifications', service: 'notification');
      return notifications;
    } catch (e) {
      Logger.error('Error fetching notifications', error: e, service: 'notification');
      return [];
    }
  }

  /// Check for a specific notification type
  Future<UserNotification?> checkForNotification(String type) async {
    final notifications = await getNotifications();
    try {
      return notifications.firstWhere((n) => n.type == type);
    } catch (_) {
      return null;
    }
  }

  /// Check if partner left notification exists
  Future<UserNotification?> checkForPartnerLeft() async {
    return checkForNotification('partner_left');
  }

  /// Dismiss a notification by ID
  Future<bool> dismissNotification(String notificationId) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/api/user/notifications/dismiss',
        body: {'notificationId': notificationId},
        parser: (json) => json,
      );

      if (response.success) {
        Logger.debug('Dismissed notification: $notificationId', service: 'notification');
        return true;
      } else {
        Logger.debug('Failed to dismiss notification: ${response.error}', service: 'notification');
        return false;
      }
    } catch (e) {
      Logger.error('Error dismissing notification', error: e, service: 'notification');
      return false;
    }
  }
}
