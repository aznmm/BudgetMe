import Foundation

/// The pattern printed on a card face. Drawn designs use the card's finish for color; `photo` shows your own picture.
enum CardDesign: String, CaseIterable, Identifiable, Codable {
    case classic
    case metal
    case waves
    case geometric
    case lines
    case glow
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .metal: "Metal"
        case .waves: "Waves"
        case .geometric: "Circles"
        case .lines: "Engraved"
        case .glow: "Glow"
        case .photo: "Photo"
        }
    }

    /// Every design you can pick without a photo.
    static let drawn: [CardDesign] = [.metal, .waves, .geometric, .lines, .glow, .classic]

    /// A design that suits a finish, for cards where you haven't picked one.
    static func suggested(for theme: CardTheme) -> CardDesign {
        switch theme {
        case .graphite, .midnight, .gold, .platinum: .metal
        case .sapphire, .ocean: .waves
        case .teal, .violet: .geometric
        case .emerald, .burgundy: .lines
        case .rose, .sunset: .glow
        }
    }
}

extension CreditCard {
    /// The design you picked, or one that suits the card's finish. A photo design needs a photo.
    var design: CardDesign {
        get {
            let picked = designRaw.flatMap(CardDesign.init(rawValue:))
            if picked == .photo && cardImageData == nil { return CardDesign.suggested(for: theme) }
            return picked ?? CardDesign.suggested(for: theme)
        }
        set { designRaw = newValue.rawValue }
    }
}
