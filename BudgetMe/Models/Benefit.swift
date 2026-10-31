import Foundation
import SwiftData

/// A statement credit or perk that renews on a schedule (Uber Cash, Resy, a hotel credit…).
/// Instead of a single checkbox, it remembers which periods were used, so it
/// resets on its own when a new month, half-year or year starts.
@Model
final class Benefit {
    var name: String = ""
    /// Value of the credit, if known.
    var amount: Double?
    var cadenceRaw: String = Cadence.monthly.rawValue
    /// Period keys ("2026-10", "2026-H2", "2026") in which the credit was used.
    var usedPeriods: [String] = []
    var note: String = ""
    var createdAt: Date = Date()
    var card: CreditCard?

    init(name: String, amount: Double? = nil, cadence: Cadence, note: String = "", card: CreditCard? = nil) {
        self.name = name
        self.amount = amount
        self.cadenceRaw = cadence.rawValue
        self.note = note
        self.card = card
        self.createdAt = Date()
    }

    var cadence: Cadence {
        get { Cadence(rawValue: cadenceRaw) ?? .monthly }
        set { cadenceRaw = newValue.rawValue }
    }

    func isUsed(on date: Date = .now) -> Bool {
        isUsed(periodKey: cadence.periodKey(for: date))
    }

    func setUsed(_ used: Bool, on date: Date = .now) {
        setUsed(used, periodKey: cadence.periodKey(for: date))
    }

    func isUsed(periodKey key: String) -> Bool {
        usedPeriods.contains(key)
    }

    func setUsed(_ used: Bool, periodKey key: String) {
        if used {
            if !usedPeriods.contains(key) { usedPeriods.append(key) }
        } else {
            usedPeriods.removeAll { $0 == key }
        }
    }
}
