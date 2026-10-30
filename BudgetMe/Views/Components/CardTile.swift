import SwiftUI

/// A Wallet-style card face.
struct CardTile: View {
    var name: String
    var issuer: String = ""
    var lastFour: String = ""
    var dueDay: Int
    var theme: CardTheme
    var isPaid: Bool = false

    init(name: String, issuer: String = "", lastFour: String = "", dueDay: Int, theme: CardTheme, isPaid: Bool = false) {
        self.name = name
        self.issuer = issuer
        self.lastFour = lastFour
        self.dueDay = dueDay
        self.theme = theme
        self.isPaid = isPaid
    }

    init(card: CreditCard, isPaid: Bool = false) {
        self.init(name: card.name, issuer: card.issuer, lastFour: card.lastFour, dueDay: card.dueDay, theme: card.theme, isPaid: isPaid)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.gradient)
                .overlay {
                    // Soft sheen across the top, like light on card stock.
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)], startPoint: .top, endPoint: .center))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.75)
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? "New Card" : name)
                            .font(.title3.weight(.semibold))
                        if !issuer.isEmpty {
                            Text(issuer)
                                .font(.caption.weight(.medium))
                                .opacity(0.7)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        if isPaid {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Due \(dueDay.ordinal)")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, theme.foreground == .white ? .dark : .light)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    ChipShape()
                        .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 28)
                    Spacer()
                    if !lastFour.isEmpty {
                        Text("•••• \(lastFour)")
                            .font(.callout.monospacedDigit().weight(.medium))
                            .opacity(0.85)
                    }
                }
            }
            .padding(18)
        }
        .foregroundStyle(theme.foreground)
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct ChipShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: 6, style: .continuous)
    }
}

/// A small card swatch used in list rows.
struct MiniCard: View {
    var theme: CardTheme
    var symbol: String?

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(theme.gradient)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                }
            }
            .frame(width: 42, height: 28)
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}

/// A Reminders-style completion circle.
struct CheckCircle: View {
    var isOn: Bool
    var tint: Color = .green
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isOn ? tint : Color.secondary.opacity(0.6))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.success, trigger: isOn) { _, new in new }
        .accessibilityLabel(isOn ? "Mark as not done" : "Mark as done")
    }
}

#Preview {
    VStack(spacing: 20) {
        CardTile(name: "Chase Sapphire", issuer: "Chase", lastFour: "4421", dueDay: 27, theme: .midnight)
        CardTile(name: "Amex", lastFour: "1005", dueDay: 16, theme: .gold, isPaid: true)
    }
    .padding()
}
