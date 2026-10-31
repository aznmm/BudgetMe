import SwiftUI

/// A Wallet-style card face.
struct CardTile: View {
    var name: String
    var issuer: String = ""
    var lastFour: String = ""
    var dueDay: Int
    var theme: CardTheme
    var design: CardDesign = .classic
    var network: CardNetwork? = nil
    var imageData: Data? = nil
    var isPaid: Bool = false

    init(
        name: String,
        issuer: String = "",
        lastFour: String = "",
        dueDay: Int,
        theme: CardTheme,
        design: CardDesign = .classic,
        network: CardNetwork? = nil,
        imageData: Data? = nil,
        isPaid: Bool = false
    ) {
        self.name = name
        self.issuer = issuer
        self.lastFour = lastFour
        self.dueDay = dueDay
        self.theme = theme
        self.design = design
        self.network = network
        self.imageData = imageData
        self.isPaid = isPaid
    }

    init(card: CreditCard, isPaid: Bool = false) {
        self.init(
            name: card.name,
            issuer: card.issuer,
            lastFour: card.lastFour,
            dueDay: card.dueDay,
            theme: card.theme,
            design: card.design,
            network: card.effectiveNetwork,
            imageData: card.cardImageData,
            isPaid: isPaid
        )
    }

    /// A picture already shows the name, number and logo, so only the due date goes on top.
    private var showsPhoto: Bool { design == .photo && imageData != nil }
    private var foreground: Color { showsPhoto ? .white : theme.foreground }
    /// Light text needs a faint shadow to stay readable on busy patterns.
    private var textShadow: Color { foreground == .white ? .black.opacity(0.25) : .clear }

    private var accessibilityText: String {
        var parts = [name.isEmpty ? "New Card" : name, "due \(dueDay.ordinal)"]
        if !lastFour.isEmpty { parts.append("ending \(lastFour)") }
        if isPaid { parts.append("paid") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CardArt(design: showsPhoto ? .photo : (design == .photo ? .classic : design), theme: theme, imageData: imageData)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.75)
                }

            if showsPhoto {
                HStack {
                    Spacer()
                    duePill
                }
                .padding(14)
            } else {
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
                        .shadow(color: textShadow, radius: 1, y: 1)
                        Spacer()
                        duePill
                    }

                    Spacer(minLength: 6)

                    HStack(spacing: 10) {
                        CardChip()
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 15, weight: .semibold))
                            .opacity(0.75)
                    }

                    Spacer(minLength: 6)

                    HStack(alignment: .lastTextBaseline) {
                        if !lastFour.isEmpty {
                            Text("••••  \(lastFour)")
                                .font(.system(.callout, design: .monospaced).weight(.semibold))
                                .opacity(0.9)
                        }
                        Spacer()
                        if let network {
                            NetworkMark(network: network)
                                .opacity(0.9)
                        }
                    }
                    .shadow(color: textShadow, radius: 1, y: 1)
                }
                .padding(18)
            }
        }
        .foregroundStyle(foreground)
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var duePill: some View {
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
        .environment(\.colorScheme, foreground == .white ? .dark : .light)
    }
}

/// A small card swatch used in list rows.
struct MiniCard: View {
    var theme: CardTheme
    var design: CardDesign = .classic
    var imageData: Data? = nil
    var symbol: String?

    init(theme: CardTheme, design: CardDesign = .classic, imageData: Data? = nil, symbol: String? = nil) {
        self.theme = theme
        self.design = design
        self.imageData = imageData
        self.symbol = symbol
    }

    init(card: CreditCard) {
        self.init(theme: card.theme, design: card.design, imageData: card.cardImageData)
    }

    var body: some View {
        CardArt(design: design == .photo && imageData == nil ? .classic : design, theme: theme, imageData: imageData)
            .frame(width: 42, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        CardTile(name: "Chase Sapphire", issuer: "Chase", lastFour: "4421", dueDay: 27, theme: .midnight, design: .metal, network: .visa)
        CardTile(name: "Amex", lastFour: "1005", dueDay: 16, theme: .gold, design: .lines, network: .amex, isPaid: true)
    }
    .padding()
}
