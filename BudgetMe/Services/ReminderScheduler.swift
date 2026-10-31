import Foundation
import UserNotifications

/// Schedules local "payment due" reminders for unpaid cards and bills.
enum ReminderScheduler {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ payments: [ReminderPlan.Payment], enabled: Bool, options: ReminderPlan.Options, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }

        let calendar = Calendar.current
        for reminder in ReminderPlan.reminders(for: payments, options: options, now: now, calendar: calendar) {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
