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
    /// Only earned when booking through the card's travel portal (Chase Travel, Amex Travel…).
    var viaPortal: Bool = false

    var label: String {
        note.isEmpty ? category.title : note
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, multiplier, note, viaPortal
    }

    /// Guesses from the details whether a rate saved before the portal switch existed is a portal rate.
    static func looksLikePortal(_ note: String) -> Bool {
        let text = note.lowercased()
        return text.contains("portal") || (text.contains("via ") && text.contains("travel"))
    }
}

extension RewardRate {
    // In an extension so the memberwise initializer is kept.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        category = try container.decode(SpendCategory.self, forKey: .category)
        multiplier = try container.decode(Double.self, forKey: .multiplier)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        viaPortal = try container.decodeIfPresent(Bool.self, forKey: .viaPortal) ?? RewardRate.looksLikePortal(note)
    }
}

extension Double {
    /// "4×", "1.5×"
    var multiplierText: String {
        formatted(.number.precision(.fractionLength(0...1))) + "×"
    }

    /// "2¢", "0.8¢"
    var centsText: String {
        formatted(.number.precision(.fractionLength(0...2))) + "¢"
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
    /// Cents a point is worth: the value you set, or an estimate from the card's name.
    var effectivePointValue: Double {
        pointValue ?? CreditCard.estimatedPointValue(name: name, issuer: issuer)
    }

    /// Rough values: Marriott Bonvoy points are worth less than Amex or Chase points; cash back is 1¢.
    static func estimatedPointValue(name: String, issuer: String) -> Double {
        let text = "\(name) \(issuer)".lowercased()
        if text.contains("marriott") || text.contains("bonvoy") { return 0.8 }
        if ["amex", "american express", "chase", "sapphire", "freedom"].contains(where: { text.contains($0) }) { return 2 }
        return 1
    }

    /// Whether the card skips foreign transaction fees: what you set, or an estimate from its name.
    var effectiveNoForeignFee: Bool {
        noForeignFee ?? CreditCard.estimatedNoForeignFee(name: name, issuer: issuer)
    }

    /// Amex, Sapphire, Marriott and Discover cards generally have no foreign fees; Chase Freedom cards charge 3%.
    /// Anything else is assumed to charge one until you say otherwise.
    static func estimatedNoForeignFee(name: String, issuer: String) -> Bool {
        let text = "\(name) \(issuer)".lowercased()
        if text.contains("freedom") { return false }
        return ["amex", "american express", "sapphire", "marriott", "bonvoy", "discover"].contains(where: { text.contains($0) })
    }

    /// The best rate this card earns on `category`, falling back to its everything-else rate.
    /// With `includePortal` off, rates that need a travel portal booking are left out.
    func earning(for category: SpendCategory, includePortal: Bool = true) -> Earning? {
        let rates = rewardRates.filter { includePortal || !$0.viaPortal }
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
