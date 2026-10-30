import Foundation
import SwiftData

/// A recurring monthly payment that isn't a credit card (an investment transfer, rent, a phone bill).
@Model
final class Bill {
    var name: String = ""
    var amount: Double?
    var dueDay: Int = 1
    var symbol: String = "dollarsign.circle.fill"
    /// Month keys ("2026-10") in which this bill was marked paid.
    var paidPeriods: [String] = []
    var createdAt: Date = Date()

    init(name: String, amount: Double? = nil, dueDay: Int, symbol: String = "dollarsign.circle.fill") {
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.symbol = symbol
        self.createdAt = Date()
    }

    func isPaid(monthKey: String) -> Bool {
        paidPeriods.contains(monthKey)
    }

    func setPaid(_ paid: Bool, monthKey: String) {
        if paid {
            if !paidPeriods.contains(monthKey) { paidPeriods.append(monthKey) }
        } else {
            paidPeriods.removeAll { $0 == monthKey }
        }
    }
}
