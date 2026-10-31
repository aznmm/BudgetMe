import Foundation

/// Works out which payment reminders to send and when.
/// Kept apart from UserNotifications so the date math stays easy to follow and check.
enum ReminderPlan {
    struct Payment {
        let id: String
        let name: String
        let dueDay: Int
        let paidPeriods: [String]
        /// This payment's own notice, or nil to use the default from Settings.
        let daysBefore: Int?
    }

    struct Options {
        var daysBefore = 2
        /// Minutes after midnight: 540 is 9:00 AM.
        var minuteOfDay = 540
        /// Also send a reminder on the due date itself.
        var alsoOnDueDate = false
    }

    struct Reminder {
        let id: String
        let title: String
        let body: String
        let fireDate: Date
    }

    static let maxDaysBefore = 30
    /// iOS keeps at most 64 pending notifications per app, so only the soonest are scheduled.
    static let maxPending = 64

    /// Reminders for unpaid payments due this month and the next two, soonest first.
    /// Three months covers the longest notice for anything due next month.
    static func reminders(for payments: [Payment], options: Options, now: Date = .now, calendar: Calendar = .current) -> [Reminder] {
        let minute = min(max(options.minuteOfDay, 0), 24 * 60 - 1)
        var reminders: [Reminder] = []

        for offset in 0..<3 {
            let month = now.startOfMonth.addingMonths(offset)
            for payment in payments where !payment.paidPeriods.contains(month.monthKey) {
                let due = month.day(payment.dueDay)
                let notice = min(max(payment.daysBefore ?? options.daysBefore, 0), maxDaysBefore)
                let leads = options.alsoOnDueDate && notice > 0 ? [notice, 0] : [notice]

                for lead in leads {
                    guard let day = calendar.date(byAdding: .day, value: -lead, to: due),
                          let fireDate = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day),
                          fireDate > now
                    else { continue }

                    reminders.append(Reminder(
                        id: "due-\(payment.id)-\(month.monthKey)-\(lead)",
                        title: "\(payment.name) is due \(dueText(due, daysAway: lead))",
                        body: "Payment due \(due.formatted(.dateTime.weekday(.wide).month(.wide).day())).",
                        fireDate: fireDate
                    ))
                }
            }
        }

        return Array(reminders.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    /// "today", "tomorrow", "Friday", "on November 15"
    static func dueText(_ due: Date, daysAway: Int) -> String {
        switch daysAway {
        case 0: "today"
        case 1: "tomorrow"
        case 2..<7: due.formatted(.dateTime.weekday(.wide))
        default: "on \(due.formatted(.dateTime.month(.wide).day()))"
        }
    }

    /// "On the due date", "1 day before", "5 days before"
    static func noticeText(_ days: Int) -> String {
        switch days {
        case 0: "On the due date"
        case 1: "1 day before"
        default: "\(days) days before"
        }
    }
}
