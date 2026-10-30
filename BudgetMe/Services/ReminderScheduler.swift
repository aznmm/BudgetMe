import Foundation
import UserNotifications

/// Schedules local "payment due" reminders for unpaid cards and bills over the next two months.
enum ReminderScheduler {
    struct Payment {
        let id: String
        let name: String
        let dueDay: Int
        let paidPeriods: [String]
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ payments: [Payment], enabled: Bool, daysBefore: Int, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }

        let calendar = Calendar.current
        for offset in 0..<2 {
            let month = now.startOfMonth.addingMonths(offset)
            for payment in payments where !payment.paidPeriods.contains(month.monthKey) {
                let due = month.day(payment.dueDay)
                guard let reminderDay = calendar.date(byAdding: .day, value: -daysBefore, to: due),
                      let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDay),
                      fireDate > now
                else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(payment.name) is due \(daysBefore == 0 ? "today" : due.formatted(.dateTime.weekday(.wide)))"
                content.body = "Payment due \(due.formatted(.dateTime.weekday(.wide).month(.wide).day()))."
                content.sound = .default

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: "due-\(payment.id)-\(month.monthKey)", content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
}
