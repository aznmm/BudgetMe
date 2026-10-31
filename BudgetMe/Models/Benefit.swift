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
        // A one-time credit stays used, whichever year it was used in.
        if cadence == .once { return usedPeriods.contains { $0.hasPrefix("once") } }
        return isUsed(periodKey: cadence.periodKey(for: date))
    }

    func setUsed(_ used: Bool, on date: Date = .now) {
        if cadence == .once && !used {
            usedPeriods.removeAll { $0.hasPrefix("once") }
            return
        }
        setUsed(used, periodKey: cadence.periodKey(for: date))
    }

    /// How many periods of `year` this credit was used in. A one-time credit counts in the year it was used.
    func timesUsed(inYear year: Int) -> Int {
        cadence.periods(inYear: year).filter { isUsed(periodKey: $0.key) }.count
    }

    func isUsed(periodKey key: String) -> Bool {
        usedPeriods.contains(key) || (key == legacyOnceKey && usedPeriods.contains("once"))
    }

    func setUsed(_ used: Bool, periodKey key: String) {
        if used {
            if !isUsed(periodKey: key) { usedPeriods.append(key) }
        } else {
            usedPeriods.removeAll { $0 == key || (key == legacyOnceKey && $0 == "once") }
        }
    }

    /// Earlier versions saved a one-time use as plain "once"; it counts toward the year the credit was added.
    private var legacyOnceKey: String {
        Cadence.once.periodKey(for: createdAt)
    }
}
