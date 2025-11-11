import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/poke_service.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/models/partner.dart';
import 'package:togetherremind/widgets/foreground_notification_banner.dart';
import 'package:uuid/uuid.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message: ${message.messageId}');

  // Check if this is a pairing confirmation
  if (message.data['type'] == 'pairing') {
    print('🔗 Background pairing confirmation received');
    final partnerName = message.data['partnerName'] ?? 'Partner';
    final partnerToken = message.data['partnerToken'] ?? '';

    // Save partner data immediately
    await StorageService.init(); // Ensure Hive is initialized
    final storage = StorageService();
    final partner = Partner(
      name: partnerName,
      pushToken: partnerToken,
      pairedAt: DateTime.now(),
      avatarEmoji: '👤',
    );
    await storage.savePartner(partner);
    print('💾 Saved partner from background pairing: $partnerName');
    return;
  }

  // Check if this is a poke
  if (message.data['type'] == 'poke') {
    print('💫 Background poke received');
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

  static Future<void> initialize() async {
    // On web, skip FCM initialization (service workers not supported in debug mode)
    if (kIsWeb) {
      print('🌐 Web platform: Skipping FCM initialization (not supported in browser)');
      print('✅ NotificationService initialized (web mode)');
      return;
    }

    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');
    } else {
      print('⚠️ User declined notification permission');
    }

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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

    print('✅ NotificationService initialized');
  }

  static Future<String?> getToken() async {
    if (kIsWeb) {
      // Web doesn't support FCM tokens - return a fake token for testing
      final webToken = 'web_token_${DateTime.now().millisecondsSinceEpoch}';
      print('🌐 Web platform: Using fake token for testing');
      return webToken;
    }
    final token = await _fcm.getToken();
    print('📱 FCM Token: $token');
    return token;
  }

  static void setAppContext(BuildContext context) {
    _appContext = context;
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message: ${message.notification?.title}');

    // Check if this is a pairing confirmation
    if (message.data['type'] == 'pairing') {
      print('🔗 Received pairing confirmation');
      final partnerName = message.data['partnerName'] ?? 'Partner';
      final partnerToken = message.data['partnerToken'] ?? '';

      if (onPairingComplete != null) {
        onPairingComplete!(partnerName, partnerToken);
      }
      return;
    }

    // Check if this is a poke
    if (message.data['type'] == 'poke') {
      print('💫 Received poke');
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
    print('💾 Saved received reminder: ${reminder.text}');
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
    print('🔔 Notification tapped: ${response.actionId}');

    if (response.actionId == 'done') {
      _storage.updateReminderStatus(response.payload ?? '', 'done');
      print('✅ Marked reminder as done');
    } else if (response.actionId == 'snooze') {
      _storage.updateReminderStatus(
        response.payload ?? '',
        'snoozed',
        snoozedUntil: DateTime.now().add(const Duration(hours: 1)),
      );
      print('⏰ Snoozed reminder for 1 hour');
    } else if (response.actionId == 'poke_back' ||
               response.actionId == 'POKE_BACK_ACTION') {
      // Poke back action
      final pokeId = response.payload ?? '';
      print('❤️ Poke back action for: $pokeId');
      PokeService.sendPokeBack(pokeId);
    } else if (response.actionId == 'acknowledge' ||
               response.actionId == 'ACKNOWLEDGE_ACTION') {
      // Acknowledge action
      final pokeId = response.payload ?? '';
      print('🙂 Acknowledge action for: $pokeId');
      _storage.updateReminderStatus(pokeId, 'acknowledged');
    }
  }

  static Future<void> sendPairingConfirmation({
    required String partnerToken,
    required String myName,
    required String myPushToken,
  }) async {
    try {
      print('🔗 Calling Cloud Function with:');
      print('   partnerToken: $partnerToken');
      print('   myName: $myName');
      print('   myPushToken: $myPushToken');

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendPairingConfirmation');

      final result = await callable.call({
        'partnerToken': partnerToken,
        'myName': myName,
        'myPushToken': myPushToken,
      });

      print('🔗 Sent pairing confirmation to partner, result: $result');
    } catch (e) {
      print('❌ Error sending pairing confirmation: $e');
      rethrow;
    }
  }
}
