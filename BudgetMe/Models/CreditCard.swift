import Foundation
import SwiftData

/// A credit card: when it's due, what it earns, and which credits it carries.
///
/// CloudKit sync rules: every stored property has a default value, relationships
/// are optional, and nothing is marked unique.
@Model
final class CreditCard {
    var name: String = ""
    var issuer: String = ""
    var lastFour: String = ""
    var themeRaw: String = CardTheme.graphite.rawValue
    /// Day of the month the payment is due (1–31, clamped to the month's length).
    var dueDay: Int = 1
    /// Month keys ("2026-10") in which this card's payment was marked paid.
    var paidPeriods: [String] = []
    /// Earning rates, stored as JSON so the schema stays simple for CloudKit.
    var rewardRatesData: Data = Data()
    /// Free-form perks such as "Rental car coverage".
    var perks: [String] = []
    var notes: String = ""
    /// Days of notice for this card's payment reminder, or nil to use the default from Settings.
    var reminderDaysBefore: Int? = nil
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Benefit.card)
    var benefits: [Benefit]? = []

    init(
        name: String,
        issuer: String = "",
        lastFour: String = "",
        theme: CardTheme = .graphite,
        dueDay: Int,
        rewardRates: [RewardRate] = [],
        perks: [String] = [],
        sortOrder: Int = 0
    ) {
        self.name = name
        self.issuer = issuer
        self.lastFour = lastFour
        self.themeRaw = theme.rawValue
        self.dueDay = dueDay
        self.perks = perks
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.rewardRates = rewardRates
    }

    var theme: CardTheme {
        get { CardTheme(rawValue: themeRaw) ?? .graphite }
        set { themeRaw = newValue.rawValue }
    }

    var rewardRates: [RewardRate] {
        get { (try? JSONDecoder().decode([RewardRate].self, from: rewardRatesData)) ?? [] }
        set { rewardRatesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var sortedBenefits: [Benefit] {
        (benefits ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
