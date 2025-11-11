import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configure notification categories for Done/Snooze actions
    if #available(iOS 10.0, *) {
      let doneAction = UNNotificationAction(
        identifier: "DONE_ACTION",
        title: "Done",
        options: []
      )

      let snoozeAction = UNNotificationAction(
        identifier: "SNOOZE_ACTION",
        title: "Snooze",
        options: []
      )

      let reminderCategory = UNNotificationCategory(
        identifier: "REMINDER_CATEGORY",
        actions: [doneAction, snoozeAction],
        intentIdentifiers: [],
        options: []
      )

      // Poke actions
      let pokeBackAction = UNNotificationAction(
        identifier: "POKE_BACK_ACTION",
        title: "❤️ Send Back",
        options: []
      )

      let acknowledgeAction = UNNotificationAction(
        identifier: "ACKNOWLEDGE_ACTION",
        title: "🙂 Smile",
        options: []
      )

      let pokeCategory = UNNotificationCategory(
        identifier: "POKE_CATEGORY",
        actions: [pokeBackAction, acknowledgeAction],
        intentIdentifiers: [],
        options: []
      )

      UNUserNotificationCenter.current().setNotificationCategories([reminderCategory, pokeCategory])
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
