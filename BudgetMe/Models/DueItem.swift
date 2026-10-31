import SwiftUI
import SwiftData

/// A card payment or bill due in a specific month, for the Due list.
struct DueItem: Identifiable {
    enum Source {
        case card(CreditCard)
        case bill(Bill)
    }

    let source: Source
    let dueDate: Date
    let monthKey: String

    init(card: CreditCard, month: Date) {
        source = .card(card)
        dueDate = month.day(card.dueDay)
        monthKey = month.monthKey
    }

    init(bill: Bill, month: Date) {
        source = .bill(bill)
        dueDate = month.day(bill.dueDay)
        monthKey = month.monthKey
    }

    var id: PersistentIdentifier {
        switch source {
        case .card(let card): card.persistentModelID
        case .bill(let bill): bill.persistentModelID
        }
    }

    var title: String {
        switch source {
        case .card(let card): card.name
        case .bill(let bill): bill.name
        }
    }

    var dueDay: Int {
        switch source {
        case .card(let card): card.dueDay
        case .bill(let bill): bill.dueDay
        }
    }

    var amount: Double? {
        switch source {
        case .card: nil
        case .bill(let bill): bill.amount
        }
    }

    var isPaid: Bool {
        switch source {
        case .card(let card): card.isPaid(monthKey: monthKey)
        case .bill(let bill): bill.isPaid(monthKey: monthKey)
        }
    }

    func setPaid(_ paid: Bool) {
        switch source {
        case .card(let card): card.setPaid(paid, monthKey: monthKey)
        case .bill(let bill): bill.setPaid(paid, monthKey: monthKey)
        }
    }
}

/// Which payday funds a payment: the latest payday on or before the due day.
/// Anything due before the first payday is covered by the previous month's last payday.
struct PaydaySchedule {
    let paydays: [Int]

    init(_ days: [Int]) {
        let unique = Array(Set(days.map { min(max($0, 1), 31) })).sorted()
        paydays = unique.isEmpty ? [1] : unique
    }

    func payday(forDueDay day: Int) -> Int {
        paydays.last(where: { $0 <= day }) ?? paydays[paydays.count - 1]
    }
}

enum SettingsKey {
    static let firstPayday = "firstPayday"
    static let secondPayday = "secondPayday"
    static let remindersEnabled = "remindersEnabled"
    static let reminderDaysBefore = "reminderDaysBefore"
    static let reminderMinuteOfDay = "reminderMinuteOfDay"
    static let remindOnDueDate = "remindOnDueDate"
    static let appearance = "appearance"
    static let includePortalRates = "includePortalRates"
    static let noForeignFeesOnly = "noForeignFeesOnly"
}

extension Int {
    /// 1 → "1st", 22 → "22nd"
    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    var currencyText: String {
        formatted(.currency(code: Locale.current.currency?.identifier ?? "USD").precision(.fractionLength(0...2)))
    }
}
