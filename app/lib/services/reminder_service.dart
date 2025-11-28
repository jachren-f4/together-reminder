import 'package:cloud_functions/cloud_functions.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/general_activity_streak_service.dart';
import 'package:togetherremind/services/dev_data_service.dart';
import '../utils/logger.dart';

class ReminderService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final StorageService _storage = StorageService();

  static Future<bool> sendReminder(Reminder reminder) async {
    try {
      // Get partner and user info
      final partner = _storage.getPartner();
      final user = _storage.getUser();

      if (partner == null) {
        Logger.error('No partner found, cannot send reminder', service: 'reminder');
        return false;
      }

      if (user == null) {
        Logger.error('No user found, cannot send reminder', service: 'reminder');
        return false;
      }

      // Refresh partner's FCM token from Supabase before sending
      // This ensures we have the latest token (solves startup race condition)
      await DevDataService().refreshPartnerPushToken();

      // Re-fetch partner to get updated token
      final updatedPartner = _storage.getPartner();
      final partnerToken = updatedPartner?.pushToken ?? partner.pushToken;

      // Call Cloud Function to schedule the reminder
      // scheduledFor is passed as UTC ISO8601 string for consistent timezone handling
      // The Cloud Function will send immediately if delay <= 1 minute,
      // otherwise it creates a Cloud Task to deliver at the scheduled time
      final callable = _functions.httpsCallable('scheduleReminder');
      await callable.call({
        'partnerToken': partnerToken,
        'senderName': user.name ?? 'Your Partner',
        'reminderText': reminder.text,
        'reminderId': reminder.id,
        'scheduledFor': reminder.scheduledFor.toUtc().toIso8601String(),
      });

      // Record activity for streak tracking
      await GeneralActivityStreakService().recordActivity();

      return true;
    } catch (e) {
      Logger.error('Error sending reminder', error: e, service: 'reminder');
      // Save as pending_send for retry later
      reminder.status = 'pending_send';
      await _storage.saveReminder(reminder);
      return false;
    }
  }

  static Future<void> retryPendingReminders() async {
    final reminders = _storage.getAllReminders();
    final pendingReminders = reminders.where((r) => r.status == 'pending_send');

    for (final reminder in pendingReminders) {
      final success = await sendReminder(reminder);
      if (success) {
        reminder.status = 'sent';
        await _storage.saveReminder(reminder);
      }
    }
  }

  /// Mark a reminder as done
  static Future<void> markReminderAsDone(String reminderId) async {
    await _storage.updateReminderStatus(reminderId, 'done');
  }
}
