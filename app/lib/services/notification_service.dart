import 'dart:async';
import 'dart:io' show Platform;
import '../utils/logger.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/poke_service.dart';
import 'package:togetherremind/services/user_profile_service.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/models/partner.dart';
import 'package:togetherremind/widgets/foreground_notification_banner.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Removed verbose logging
  // print('📨 Background message: ${message.messageId}');

  // Check if this is a pairing confirmation
  if (message.data['type'] == 'pairing') {
    // Removed verbose logging
    // print('🔗 Background pairing confirmation received');
    final partnerName = message.data['partnerName'] ?? 'Partner';
    final partnerToken = message.data['partnerToken'] ?? '';
    final partnerId = message.data['partnerId'] ?? '';

    // Save partner data immediately
    await StorageService.init(); // Ensure Hive is initialized
    final storage = StorageService();
    final partner = Partner(
      name: partnerName,
      pushToken: partnerToken,
      pairedAt: DateTime.now(),
      avatarEmoji: '👤',
      id: partnerId,
    );
    await storage.savePartner(partner);
    // Removed verbose logging
    // print('💾 Saved partner from background pairing: $partnerName');
    return;
  }

  // Check if this is a poke
  if (message.data['type'] == 'poke') {
    // Removed verbose logging
    // print('💫 Background poke received');
    await PokeService.handleReceivedPoke(
      pokeId: message.data['pokeId'] ?? '',
      fromName: message.data['fromName'] ?? 'Partner',
      emoji: message.data['emoji'] ?? '💫',
    );
    return;
  }

  // Regular reminder
  await NotificationService._saveReceivedReminder(message);
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final StorageService _storage = StorageService();

  // Callback for pairing completion
  static Function(String partnerName, String partnerToken)? onPairingComplete;

  // BuildContext for showing foreground notifications
  static BuildContext? _appContext;

  // Track if permission has been requested
  static bool _permissionRequested = false;

  static Future<void> initialize() async {
    // On web, skip FCM initialization (service workers not supported in debug mode)
    if (kIsWeb) {
      // Removed verbose logging
      // print('🌐 Web platform: Skipping FCM initialization (not supported in browser)');
      // Logger.success('NotificationService initialized (web mode)', service: 'notification');
      return;
    }

    // DON'T request permissions here - defer until after LP intro
    // Permission will be requested via requestPermission() from LpIntroOverlay

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // DON'T request permissions during init - defer until after first quiz
    // Permission will be requested via requestPermission() after classic quiz completion
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      'reminder_channel',
      'Reminders',
      description: 'Reminders from your partner',
      importance: Importance.max,
    );

    const AndroidNotificationChannel pokeChannel = AndroidNotificationChannel(
      'poke_channel',
      'Pokes',
      description: 'Instant pokes from your partner',
      importance: Importance.max,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(reminderChannel);
    await androidPlugin?.createNotificationChannel(pokeChannel);

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Setup background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Listen for token refresh and sync to server
    _fcm.onTokenRefresh.listen(_onTokenRefresh);

    // Removed verbose logging
    // Logger.success('NotificationService initialized', service: 'notification');
  }

  /// Handle FCM token refresh - sync to server
  static Future<void> _onTokenRefresh(String token) async {
    Logger.info('FCM token refreshed, syncing to server', service: 'notification');
    try {
      final userProfileService = UserProfileService();
      final platform = _getPlatform();
      await userProfileService.syncPushToken(token, platform);
      Logger.success('Push token synced to server', service: 'notification');
    } catch (e) {
      Logger.warn('Failed to sync refreshed push token: $e', service: 'notification');
    }
  }

  /// Get platform string for push token sync
  static String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// Sync current push token to server (call on app start if authenticated)
  ///
  /// This handles both cases:
  /// 1. User already has permission - sync immediately
  /// 2. User doesn't have permission yet - skip (will sync after LP intro grants permission)
  static Future<void> syncTokenToServer() async {
    if (kIsWeb) return;

    try {
      // First check if we already have permission (without showing dialog)
      final settings = await _fcm.getNotificationSettings();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        // Permission not granted yet - skip silently
        // Token will be synced when user grants permission via LP intro
        Logger.debug('Push token sync skipped - permission not granted yet', service: 'notification');
        return;
      }

      // Permission granted - get and sync token
      // Retry a few times since APNs token might not be ready immediately
      String? token;
      for (int attempt = 0; attempt < 3; attempt++) {
        token = await getToken();
        if (token != null) break;

        // Wait a bit for APNs token to arrive
        await Future.delayed(const Duration(milliseconds: 500));
        Logger.debug('Push token retry ${attempt + 1}/3', service: 'notification');
      }

      if (token == null) {
        Logger.warn('Push token sync failed - token is null after retries', service: 'notification');
        return;
      }

      // Sync token to server with retry logic for network failures
      final userProfileService = UserProfileService();
      final platform = _getPlatform();

      for (int apiAttempt = 0; apiAttempt < 3; apiAttempt++) {
        try {
          await userProfileService.syncPushToken(token, platform);
          Logger.success('Push token synced to server', service: 'notification');
          return; // Success - exit
        } catch (e) {
          if (apiAttempt < 2) {
            Logger.debug('Push token API retry ${apiAttempt + 1}/3: $e', service: 'notification');
            await Future.delayed(const Duration(seconds: 1));
          } else {
            Logger.warn('Push token sync failed after 3 attempts: $e', service: 'notification');
          }
        }
      }
    } catch (e) {
      Logger.warn('Failed to sync push token on startup: $e', service: 'notification');
    }
  }

  /// Check if notifications are authorized (without requesting permission)
  /// Returns true if authorized, false if denied/notDetermined
  static Future<bool> isAuthorized() async {
    if (kIsWeb) return true; // Web doesn't need permission

    try {
      final settings = await _fcm.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      Logger.warn('Failed to check notification authorization: $e', service: 'notification');
      return false;
    }
  }

  /// Request notification permission - called from LP intro overlay after user sees value
  /// This is deferred from initialize() to provide better UX (no gray overlay on first launch)
  static Future<bool> requestPermission() async {
    // Skip on web
    if (kIsWeb) return true;

    // Don't request again if already requested
    if (_permissionRequested) return true;

    _permissionRequested = true;

    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          Logger.warn('FCM permission request timed out (network issue)', service: 'notification');
          throw TimeoutException('FCM permission request timed out');
        },
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        Logger.success('User granted notification permission', service: 'notification');
        // Sync token to server now that we have permission
        await syncTokenToServer();
        return true;
      } else {
        Logger.warn('User declined notification permission', service: 'notification');
        return false;
      }
    } catch (e) {
      Logger.warn('Failed to request FCM permissions: $e', service: 'notification');
      return false;
    }
  }

  static Future<String?> getToken() async {
    if (kIsWeb) {
      // Web doesn't support FCM tokens - return a fake token for testing
      final webToken = 'web_token_${DateTime.now().millisecondsSinceEpoch}';
      // Removed verbose logging
      // print('🌐 Web platform: Using fake token for testing');
      return webToken;
    }
    try {
      final token = await _fcm.getToken();
      // Removed verbose logging
      // print('📱 FCM Token: $token');
      return token;
    } catch (e) {
      Logger.warn('Failed to get FCM token: $e', service: 'notification');
      return null;
    }
  }

  static void setAppContext(BuildContext context) {
    _appContext = context;
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Removed verbose logging
    // print('📨 Foreground message: ${message.notification?.title}');

    // Check if this is a pairing confirmation
    if (message.data['type'] == 'pairing') {
      // Removed verbose logging
      // print('🔗 Received pairing confirmation');
      final partnerName = message.data['partnerName'] ?? 'Partner';
      final partnerToken = message.data['partnerToken'] ?? '';

      if (onPairingComplete != null) {
        onPairingComplete!(partnerName, partnerToken);
      }
      return;
    }

    // Check if this is a poke
    if (message.data['type'] == 'poke') {
      // Removed verbose logging
      // print('💫 Received poke');
      await PokeService.handleReceivedPoke(
        pokeId: message.data['pokeId'] ?? '',
        fromName: message.data['fromName'] ?? 'Partner',
        emoji: message.data['emoji'] ?? '💫',
      );

      // Show in-app banner for foreground notification
      if (_appContext != null && _appContext!.mounted) {
        ForegroundNotificationBanner.show(
          _appContext!,
          title: message.notification?.title ?? 'Poke',
          message: message.notification?.body ?? 'Tap to respond',
          emoji: message.data['emoji'] ?? '💫',
        );
      }
      return;
    }

    // Regular reminder message
    await _saveReceivedReminder(message);

    // Show in-app banner for foreground notification
    if (_appContext != null && _appContext!.mounted) {
      ForegroundNotificationBanner.show(
        _appContext!,
        title: message.notification?.title ?? 'Reminder',
        message: message.notification?.body ?? '',
        emoji: '📝',
      );
    }
  }

  static Future<void> _saveReceivedReminder(RemoteMessage message) async {
    const uuid = Uuid();
    final reminder = Reminder(
      id: message.data['reminderId'] ?? uuid.v4(),
      type: 'received',
      from: message.data['fromName'] ?? 'Partner',
      to: 'You',
      text: message.data['text'] ?? message.notification?.body ?? '',
      timestamp: DateTime.now(),
      scheduledFor: DateTime.now(),
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _storage.saveReminder(reminder);
    // Removed verbose logging
    // print('💾 Saved received reminder: ${reminder.text}');
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final isPoke = message.data['type'] == 'poke';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isPoke ? 'poke_channel' : 'reminder_channel',
      isPoke ? 'Pokes' : 'Reminders',
      importance: Importance.max,
      priority: Priority.high,
      actions: isPoke
          ? <AndroidNotificationAction>[
              AndroidNotificationAction('poke_back', '❤️ Send Back'),
              AndroidNotificationAction('acknowledge', '🙂 Smile'),
            ]
          : <AndroidNotificationAction>[
              AndroidNotificationAction('done', 'Done'),
              AndroidNotificationAction('snooze', 'Snooze'),
            ],
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: isPoke ? 'POKE_CATEGORY' : 'REMINDER_CATEGORY',
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? (isPoke ? 'Poke' : 'Reminder'),
      message.notification?.body ?? '',
      details,
      payload: isPoke ? message.data['pokeId'] : message.data['reminderId'],
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Removed verbose logging
    // print('🔔 Notification tapped: ${response.actionId}');

    if (response.actionId == 'done') {
      _storage.updateReminderStatus(response.payload ?? '', 'done');
      Logger.success('Marked reminder as done', service: 'notification');
    } else if (response.actionId == 'snooze') {
      _storage.updateReminderStatus(
        response.payload ?? '',
        'snoozed',
        snoozedUntil: DateTime.now().add(const Duration(hours: 1)),
      );
      Logger.info('Snoozed reminder for 1 hour', service: 'notification');
    } else if (response.actionId == 'poke_back' ||
               response.actionId == 'POKE_BACK_ACTION') {
      // Poke back action
      final pokeId = response.payload ?? '';
      Logger.info('Poke back action for: $pokeId', service: 'notification');
      PokeService.sendPokeBack(pokeId);
    } else if (response.actionId == 'acknowledge' ||
               response.actionId == 'ACKNOWLEDGE_ACTION') {
      // Acknowledge action
      final pokeId = response.payload ?? '';
      Logger.info('Acknowledge action for: $pokeId', service: 'notification');
      _storage.updateReminderStatus(pokeId, 'acknowledged');
    }
  }

  static Future<void> sendPairingConfirmation({
    required String partnerToken,
    required String myName,
    required String myPushToken,
  }) async {
    try {
      // Removed verbose logging
      // print('🔗 Calling Cloud Function with:');
      // print('   partnerToken: $partnerToken');
      // print('   myName: $myName');
      // print('   myPushToken: $myPushToken');

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendPairingConfirmation');

      final result = await callable.call({
        'partnerToken': partnerToken,
        'myName': myName,
        'myPushToken': myPushToken,
      });

      // Removed verbose logging
      // print('🔗 Sent pairing confirmation to partner, result: $result');
    } catch (e) {
      Logger.error('Error sending pairing confirmation', error: e, service: 'notification');
      rethrow;
    }
  }
}
