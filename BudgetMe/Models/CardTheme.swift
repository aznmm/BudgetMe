import SwiftUI

/// Finishes for the card tiles, loosely inspired by real card stock.
enum CardTheme: String, CaseIterable, Identifiable, Codable {
    case graphite
    case midnight
    case sapphire
    case ocean
    case teal
    case emerald
    case gold
    case rose
    case burgundy
    case sunset
    case platinum
    case violet

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var colors: [Color] {
        switch self {
        case .graphite: [Color(red: 0.23, green: 0.23, blue: 0.25), Color(red: 0.07, green: 0.07, blue: 0.08)]
        case .midnight: [Color(red: 0.12, green: 0.15, blue: 0.30), Color(red: 0.03, green: 0.04, blue: 0.12)]
        case .sapphire: [Color(red: 0.10, green: 0.26, blue: 0.55), Color(red: 0.03, green: 0.09, blue: 0.27)]
        case .ocean: [Color(red: 0.16, green: 0.50, blue: 0.93), Color(red: 0.06, green: 0.24, blue: 0.63)]
        case .teal: [Color(red: 0.10, green: 0.62, blue: 0.66), Color(red: 0.03, green: 0.32, blue: 0.40)]
        case .emerald: [Color(red: 0.13, green: 0.58, blue: 0.36), Color(red: 0.03, green: 0.28, blue: 0.17)]
        case .gold: [Color(red: 0.86, green: 0.71, blue: 0.43), Color(red: 0.62, green: 0.46, blue: 0.22)]
        case .rose: [Color(red: 0.93, green: 0.58, blue: 0.62), Color(red: 0.71, green: 0.31, blue: 0.40)]
        case .burgundy: [Color(red: 0.55, green: 0.12, blue: 0.20), Color(red: 0.25, green: 0.04, blue: 0.09)]
        case .sunset: [Color(red: 1.00, green: 0.58, blue: 0.20), Color(red: 0.86, green: 0.29, blue: 0.12)]
        case .platinum: [Color(red: 0.84, green: 0.85, blue: 0.87), Color(red: 0.58, green: 0.60, blue: 0.64)]
        case .violet: [Color(red: 0.52, green: 0.33, blue: 0.90), Color(red: 0.25, green: 0.12, blue: 0.55)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Light finishes need dark text.
    var foreground: Color {
        switch self {
        case .platinum, .gold: Color.black.opacity(0.82)
        default: .white
        }
    }
}
