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

/// A Best Card category: a built-in one, or one you named, like "Amazon".
enum CategoryChoice: Hashable, Identifiable {
    case builtIn(SpendCategory)
    case custom(String)

    var id: String {
        switch self {
        case .builtIn(let category): "builtin-\(category.rawValue)"
        case .custom(let name): "custom-\(name.lowercased())"
        }
    }

    var title: String {
        switch self {
        case .builtIn(let category): category.title
        case .custom(let name): name
        }
    }

    /// For use mid-sentence: "dining", but "Amazon" keeps its capital.
    var inlineTitle: String {
        switch self {
        case .builtIn(let category): category.title.lowercased()
        case .custom(let name): name
        }
    }

    var symbol: String {
        switch self {
        case .builtIn(let category): category.symbol
        case .custom: "tag.fill"
        }
    }

    /// Every custom category name used by these rates, once each, alphabetically.
    static func customNames(in rates: [RewardRate]) -> [String] {
        var names: [String] = []
        for name in rates.compactMap(\.customCategory) where !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            names.append(name)
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
    /// Spending this rate applies to before it drops, e.g. $25,000 a year. Nil for no amount.
    var capAmount: Double? = nil
    /// How often the cap resets, or nil when the rate has no cap.
    var capPeriod: Cadence? = nil
    /// The quarter ("2026-Q4") a rotating category earns in, or nil when it always earns.
    var rotatingQuarter: String? = nil
    /// A category you named, like "Amazon". When set, the rate earns only there and `category` is ignored.
    var customCategory: String? = nil

    var choice: CategoryChoice {
        customCategory.map { CategoryChoice.custom($0) } ?? .builtIn(category)
    }

    var label: String {
        note.isEmpty ? choice.title : note
    }

    var symbol: String { choice.symbol }

    /// The card's base rate on everything else.
    var isEverydayRate: Bool {
        customCategory == nil && category == .everythingElse
    }

    /// Whether a purchase in `choice` earns this rate. Custom rates never count toward built-in categories.
    func applies(to choice: CategoryChoice) -> Bool {
        switch choice {
        case .builtIn(let spend):
            return customCategory == nil && spend.isCovered(by: category)
        case .custom(let name):
            return customCategory?.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// False for a rotating category whose quarter is over.
    func isActive(on date: Date = .now) -> Bool {
        rotatingQuarter == nil || rotatingQuarter == Cadence.quarterly.periodKey(for: date)
    }

    /// "Up to $25,000 a year"
    var capText: String? {
        guard let capPeriod else { return nil }
        guard let capAmount, capAmount > 0 else { return "Spending cap, resets \(capPeriod.resetText)" }
        return "Up to \(capAmount.currencyText) \(capPeriod.perPeriodText)"
    }

    /// "Q3 2026" for a rotating category's quarter.
    var rotatingLabel: String? {
        guard let rotatingQuarter else { return nil }
        let parts = rotatingQuarter.split(separator: "-")
        return parts.count == 2 ? "\(parts[1]) \(parts[0])" : rotatingQuarter
    }

    /// "Portal · This quarter only · Up to $25,000 a year", or nil when no options are set.
    var optionsSummary: String? {
        var parts: [String] = []
        if viaPortal { parts.append("Portal") }
        if rotatingQuarter != nil { parts.append(isActive() ? "This quarter only" : "Rotating, out of date") }
        if let capText { parts.append(capText) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, multiplier, note, viaPortal, capAmount, capPeriod, rotatingQuarter, customCategory
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
        capAmount = try container.decodeIfPresent(Double.self, forKey: .capAmount)
        capPeriod = try container.decodeIfPresent(Cadence.self, forKey: .capPeriod)
        rotatingQuarter = try container.decodeIfPresent(String.self, forKey: .rotatingQuarter)
        customCategory = try container.decodeIfPresent(String.self, forKey: .customCategory)
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

    /// "8%", "2.4%"
    var percentText: String {
        formatted(.number.precision(.fractionLength(0...1))) + "%"
    }
}

/// What a card earns on a given category.
struct Earning {
    let multiplier: Double
    /// Every rate that applies, best first ("5× Via Chase Travel", "2× All other travel").
    let details: [RewardRate]
    let isBaseRate: Bool
    /// The card has no everyday rate saved, so 1× is assumed.
    var isAssumed = false
    /// This quarter's rotating category, when it adds to the rate.
    var rotatingBonus: RewardRate? = nil
    /// How much the rotating category adds: its rate minus the card's everyday rate.
    var rotatingExtra: Double = 0
}

/// The payment network, which decides where a card is accepted.
enum CardNetwork: String, CaseIterable, Identifiable, Codable {
    case visa
    case mastercard
    case amex
    case discover

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visa: "Visa"
        case .mastercard: "Mastercard"
        case .amex: "Amex"
        case .discover: "Discover"
        }
    }

    /// Visa and Mastercard are taken almost everywhere, including Costco and most places abroad.
    var isWidelyAccepted: Bool {
        self == .visa || self == .mastercard
    }
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

    /// The card's network: what you set, or an estimate from its name. Nil when unknown.
    var effectiveNetwork: CardNetwork? {
        guard let networkRaw else { return CreditCard.estimatedNetwork(name: name, issuer: issuer) }
        return CardNetwork(rawValue: networkRaw)
    }

    /// Amex and Discover issue their own; Chase's Sapphire, Freedom and Marriott cards are Visa, except Freedom Flex.
    static func estimatedNetwork(name: String, issuer: String) -> CardNetwork? {
        let text = "\(name) \(issuer)".lowercased()
        if text.contains("amex") || text.contains("american express") { return .amex }
        if text.contains("discover") { return .discover }
        if text.contains("mastercard") || text.contains("flex") { return .mastercard }
        if ["visa", "sapphire", "freedom", "marriott", "bonvoy"].contains(where: { text.contains($0) }) { return .visa }
        return nil
    }

    /// Point value as a rough cash-back rate: 4× at 2¢ a point is about 8% back.
    func percentBack(for earning: Earning) -> Double {
        earning.multiplier * effectivePointValue
    }

    /// Whether you've marked this rate's spending cap as reached for the current period.
    func isCapReached(_ rate: RewardRate, on date: Date = .now) -> Bool {
        guard let key = capKey(for: rate, on: date) else { return false }
        return capsReached.contains(key)
    }

    func setCapReached(_ reached: Bool, for rate: RewardRate, on date: Date = .now) {
        guard let key = capKey(for: rate, on: date) else { return }
        if reached {
            if !capsReached.contains(key) { capsReached.append(key) }
        } else {
            capsReached.removeAll { $0 == key }
        }
    }

    /// Keyed by period like credits, so a reached cap resets on its own.
    private func capKey(for rate: RewardRate, on date: Date) -> String? {
        guard let period = rate.capPeriod else { return nil }
        return "\(rate.id.uuidString)|\(period.periodKey(for: date))"
    }

    private static let assumedBaseRateID = UUID()

    /// The best rate this card earns on `category`, falling back to its everything-else rate.
    /// With `includePortal` off, rates that need a travel portal booking are left out. Rates whose
    /// cap is reached or whose rotating quarter is over are skipped too.
    func earning(for choice: CategoryChoice, includePortal: Bool = true, on date: Date = .now) -> Earning? {
        let rates = rewardRates.filter { rate in
            (includePortal || !rate.viaPortal) && rate.isActive(on: date) && !isCapReached(rate, on: date)
        }
        let regular = rates.filter { $0.rotatingQuarter == nil }
        let matches = regular
            .filter { $0.applies(to: choice) }
            .sorted { $0.multiplier > $1.multiplier }
        let everyday = regular.first(where: \.isEverydayRate)

        var earning: Earning
        if let best = matches.first {
            earning = Earning(multiplier: best.multiplier, details: matches, isBaseRate: choice == .builtIn(.everythingElse))
        } else if let everyday {
            earning = Earning(multiplier: everyday.multiplier, details: [everyday], isBaseRate: true)
        } else if !rewardRates.isEmpty {
            // Nearly every card earns at least 1× on everything, so assume that rather than leave the card out.
            let assumed = RewardRate(id: CreditCard.assumedBaseRateID, category: .everythingElse, multiplier: 1, note: "Everyday rate (assumed 1×)")
            earning = Earning(multiplier: 1, details: [assumed], isBaseRate: true, isAssumed: true)
        } else {
            return nil
        }

        // A rotating category adds on top of what the purchase already earns. Its rate already includes the
        // everyday rate (Chase's 5% is 1% plus 4% extra), so only the extra is added: 3× dining becomes 7×.
        let everydayMultiplier = everyday?.multiplier ?? 1
        let bonus = rates
            .filter { $0.rotatingQuarter != nil && $0.applies(to: choice) }
            .max { $0.multiplier < $1.multiplier }
        if let bonus, bonus.multiplier > everydayMultiplier {
            let extra = bonus.multiplier - everydayMultiplier
            earning = Earning(
                multiplier: earning.multiplier + extra,
                details: earning.details,
                isBaseRate: false,
                isAssumed: earning.isAssumed,
                rotatingBonus: bonus,
                rotatingExtra: extra
            )
        }
        return earning
    }
}

// MARK: - Rotating categories

extension CreditCard {
    /// Whether the card has rotating 5× categories: what you set, or an estimate from its name.
    var effectiveHasRotatingCategories: Bool {
        hasRotatingCategories ?? CreditCard.estimatedHasRotatingCategories(name: name, issuer: issuer)
    }

    /// Chase Freedom Flex and Discover it have quarterly 5× categories.
    static func estimatedHasRotatingCategories(name: String, issuer: String) -> Bool {
        let text = "\(name) \(issuer)".lowercased()
        return text.contains("flex") || text.contains("discover")
    }

    /// This quarter's rotating category rates.
    func rotatingRates(on date: Date = .now) -> [RewardRate] {
        let quarter = Cadence.quarterly.periodKey(for: date)
        return rewardRates.filter { $0.rotatingQuarter == quarter }
    }

    /// True when the card has rotating categories but none are set for this quarter.
    func needsRotatingCategories(on date: Date = .now) -> Bool {
        effectiveHasRotatingCategories && rotatingRates(on: date).isEmpty
    }

    func isRotatingActivated(on date: Date = .now) -> Bool {
        rotatingActivated.contains(Cadence.quarterly.periodKey(for: date))
    }

    func setRotatingActivated(_ activated: Bool, on date: Date = .now) {
        let quarter = Cadence.quarterly.periodKey(for: date)
        if activated {
            if !rotatingActivated.contains(quarter) { rotatingActivated.append(quarter) }
        } else {
            rotatingActivated.removeAll { $0 == quarter }
        }
    }

    /// Replaces the rotating categories with `choices` for this quarter. Earlier quarters' picks are cleared out.
    func setRotatingCategories(_ choices: [CategoryChoice], multiplier: Double, cap: Double?, on date: Date = .now) {
        let quarter = Cadence.quarterly.periodKey(for: date)
        let quarterLabel = Cadence.quarterly.periodLabel(for: date)
        var rates = rewardRates.filter { $0.rotatingQuarter == nil }
        for choice in choices {
            var rate = RewardRate(category: .everythingElse, multiplier: multiplier, note: "\(choice.title), rotating \(quarterLabel)")
            switch choice {
            case .builtIn(let category): rate.category = category
            case .custom(let name): rate.customCategory = name
            }
            rate.rotatingQuarter = quarter
            if let cap {
                rate.capAmount = cap
                rate.capPeriod = .quarterly
            }
            rates.append(rate)
        }
        rewardRates = rates
    }
}
