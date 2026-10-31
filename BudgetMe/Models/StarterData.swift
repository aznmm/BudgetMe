import Foundation
import SwiftData

/// The cards, credits and due dates from Azan's original notes.
/// Loaded once on request from the empty state or Settings, so it never duplicates across synced devices.
enum StarterData {
    static func load(into context: ModelContext, now: Date = .now) {
        func card(_ name: String, _ theme: CardTheme, due: Int, order: Int, rates: [RewardRate] = [], perks: [String] = []) -> CreditCard {
            let card = CreditCard(name: name, theme: theme, dueDay: due, rewardRates: rates, perks: perks, sortOrder: order)
            context.insert(card)
            return card
        }

        func credit(_ name: String, _ cadence: Cadence, amount: Double? = nil, on card: CreditCard, used: Bool = false) {
            let benefit = Benefit(name: name, amount: amount, cadence: cadence)
            context.insert(benefit)
            benefit.card = card
            if used { benefit.setUsed(true, on: now) }
        }

        // Funded by the 1st payday
        _ = card("TD", .emerald, due: 3, order: 0)
        _ = card("Nordstrom", .graphite, due: 4, order: 1)
        let marriott = card("Marriott", .burgundy, due: 8, order: 2, rates: [
            RewardRate(category: .hotels, multiplier: 6, note: "Marriott hotels"),
            RewardRate(category: .dining, multiplier: 3, note: "Restaurants"),
            RewardRate(category: .airfare, multiplier: 3, note: "Airfare"),
            RewardRate(category: .everythingElse, multiplier: 2, note: "All other purchases"),
        ])

        // Funded by the 15th payday
        let amex = card("Amex", .gold, due: 16, order: 3, rates: [
            RewardRate(category: .dining, multiplier: 4, note: "Restaurants worldwide"),
            RewardRate(category: .groceries, multiplier: 4, note: "U.S. supermarkets"),
            RewardRate(category: .hotels, multiplier: 5, note: "Prepaid hotels via Amex Travel", viaPortal: true),
            RewardRate(category: .airfare, multiplier: 3, note: "Airfare"),
            RewardRate(category: .carRental, multiplier: 2, note: "Car rental via Amex Travel", viaPortal: true),
            RewardRate(category: .everythingElse, multiplier: 1, note: "All other purchases"),
        ])
        _ = card("BMO Mastercard", .ocean, due: 18, order: 4)
        _ = card("Chase Freedom", .sapphire, due: 20, order: 5, rates: [
            RewardRate(category: .travel, multiplier: 5, note: "Via Chase Travel", viaPortal: true),
            RewardRate(category: .dining, multiplier: 3, note: "Dining"),
            RewardRate(category: .drugstore, multiplier: 3, note: "Drugstores"),
            RewardRate(category: .everythingElse, multiplier: 1.5, note: "All other purchases"),
        ])
        _ = card("Chase Freedom Flex", .teal, due: 20, order: 6, rates: [
            RewardRate(category: .travel, multiplier: 5, note: "Via Chase Travel", viaPortal: true),
            RewardRate(category: .dining, multiplier: 3, note: "Dining"),
            RewardRate(category: .drugstore, multiplier: 3, note: "Drugstores"),
            RewardRate(category: .everythingElse, multiplier: 1, note: "All other purchases"),
        ])
        _ = card("Discover", .sunset, due: 24, order: 7)
        let sapphire = card("Chase Sapphire", .midnight, due: 27, order: 8, rates: [
            RewardRate(category: .travel, multiplier: 5, note: "Via Chase Travel", viaPortal: true),
            RewardRate(category: .travel, multiplier: 2, note: "All other travel"),
            RewardRate(category: .dining, multiplier: 3, note: "Dining"),
            RewardRate(category: .groceries, multiplier: 3, note: "Online grocery"),
            RewardRate(category: .gas, multiplier: 3, note: "Gas"),
            RewardRate(category: .streaming, multiplier: 3, note: "Streaming services"),
            RewardRate(category: .everythingElse, multiplier: 1, note: "All other purchases"),
        ], perks: ["Rental car coverage"])
        _ = card("Amex Marriott", .platinum, due: 28, order: 9)

        // Credits — checkmarks from the notes are carried over for the current period.
        credit("Uber", .monthly, on: amex)
        credit("Grubhub", .monthly, on: amex)
        credit("Dunkin'", .monthly, on: amex)
        credit("Resy", .semiannual, on: amex, used: true)
        credit("Hotel Collection", .annual, on: amex)

        credit("DoorDash", .monthly, on: sapphire)
        credit("Hotel credit", .annual, amount: 100, on: sapphire)

        credit("Travel credit", .semiannual, amount: 50, on: marriott, used: true)
        credit("50k points redemption", .annual, on: marriott, used: true)

        // Non-card payments
        let invest = Bill(name: "Invest", amount: 200, dueDay: 1, symbol: "chart.line.uptrend.xyaxis")
        context.insert(invest)
        invest.setPaid(true, monthKey: now.monthKey)

        try? context.save()
    }
}
