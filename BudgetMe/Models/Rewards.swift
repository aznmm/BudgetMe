import Foundation

/// Spending categories used to find the best card for a purchase.
enum SpendCategory: String, CaseIterable, Identifiable, Codable {
    case dining
    case groceries
    case gas
    case travel
    case hotels
    case airfare
    case carRental
    case drugstore
    case streaming
    case everythingElse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dining: "Dining"
        case .groceries: "Groceries"
        case .gas: "Gas"
        case .travel: "Travel"
        case .hotels: "Hotels"
        case .airfare: "Flights"
        case .carRental: "Car Rental"
        case .drugstore: "Drugstore"
        case .streaming: "Streaming"
        case .everythingElse: "Everything Else"
        }
    }

    var symbol: String {
        switch self {
        case .dining: "fork.knife"
        case .groceries: "cart.fill"
        case .gas: "fuelpump.fill"
        case .travel: "suitcase.rolling.fill"
        case .hotels: "bed.double.fill"
        case .airfare: "airplane"
        case .carRental: "car.fill"
        case .drugstore: "cross.case.fill"
        case .streaming: "play.tv.fill"
        case .everythingElse: "bag.fill"
        }
    }

    /// Hotels, flights and car rentals also earn a card's general travel rate.
    private var isTravelKind: Bool {
        self == .hotels || self == .airfare || self == .carRental
    }

    /// Whether a rate earned on `rateCategory` applies to a purchase in this category.
    func isCovered(by rateCategory: SpendCategory) -> Bool {
        rateCategory == self || (isTravelKind && rateCategory == .travel)
    }
}

/// One earning rate on a card, e.g. 4× on dining or 5× on travel booked through the issuer.
struct RewardRate: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var category: SpendCategory
    var multiplier: Double
    var note: String = ""

    var label: String {
        note.isEmpty ? category.title : note
    }
}

extension Double {
    /// "4×", "1.5×"
    var multiplierText: String {
        formatted(.number.precision(.fractionLength(0...1))) + "×"
    }
}

/// What a card earns on a given category.
struct Earning {
    let multiplier: Double
    /// Every rate that applies, best first ("5× Via Chase Travel", "2× All other travel").
    let details: [RewardRate]
    let isBaseRate: Bool
}

extension CreditCard {
    /// The best rate this card earns on `category`, falling back to its everything-else rate.
    func earning(for category: SpendCategory) -> Earning? {
        let rates = rewardRates
        let matches = rates
            .filter { category.isCovered(by: $0.category) }
            .sorted { $0.multiplier > $1.multiplier }
        if let best = matches.first {
            return Earning(multiplier: best.multiplier, details: matches, isBaseRate: category == .everythingElse)
        }
        if let base = rates.first(where: { $0.category == .everythingElse }) {
            return Earning(multiplier: base.multiplier, details: [base], isBaseRate: true)
        }
        return nil
    }
}
