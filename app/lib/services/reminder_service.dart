import 'package:cloud_functions/cloud_functions.dart';
import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/models/partner.dart';
import 'package:togetherremind/models/user.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/love_point_service.dart';

class ReminderService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final StorageService _storage = StorageService();

  static Future<bool> sendReminder(Reminder reminder) async {
    try {
      // Get partner and user info
      final partner = _storage.getPartner();
      final user = _storage.getUser();

      if (partner == null) {
        print('❌ No partner found, cannot send reminder');
        return false;
      }

      if (user == null) {
        print('❌ No user found, cannot send reminder');
        return false;
      }

      print('📤 Sending reminder to partner...');
      print('   Partner token: ${partner.pushToken}');
      print('   Sender: ${user.name ?? 'You'}');
      print('   Text: ${reminder.text}');

      // Call Cloud Function
      final callable = _functions.httpsCallable('sendReminder');
      final result = await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your Partner',
        'reminderText': reminder.text,
        'reminderId': reminder.id,
        'scheduledFor': reminder.scheduledFor.toIso8601String(),
      });

      print('✅ Cloud Function response: ${result.data}');

      // Award LP for sending reminder
      await LovePointService.awardPoints(
        amount: 8,
        reason: 'reminder_sent',
        relatedId: reminder.id,
      );

      return true;
    } catch (e) {
      print('❌ Error sending reminder: $e');
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

  /// Mark a reminder as done and award LP
  static Future<void> markReminderAsDone(String reminderId) async {
    await _storage.updateReminderStatus(reminderId, 'done');

    // Award LP for completing a reminder
    await LovePointService.awardPoints(
      amount: 10,
      reason: 'reminder_done',
      relatedId: reminderId,
    );

    print('✅ Reminder marked as done, awarded 10 LP');
  }
}
