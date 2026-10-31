import SwiftUI
import SwiftData

/// "Which card should I use?" Pick what you're buying, see your cards ranked by what they earn.
struct BestCardView: View {
    @Query(sort: \CreditCard.sortOrder) private var cards: [CreditCard]
    @State private var category: SpendCategory = .dining
    @AppStorage(SettingsKey.includePortalRates) private var includePortal = true

    private struct Ranked: Identifiable {
        let card: CreditCard
        let earning: Earning
        var id: PersistentIdentifier { card.persistentModelID }
    }

    private var ranked: [Ranked] {
        cards
            .compactMap { card in card.earning(for: category, includePortal: includePortal).map { Ranked(card: card, earning: $0) } }
            .sorted { lhs, rhs in
                if lhs.earning.multiplier != rhs.earning.multiplier {
                    return lhs.earning.multiplier > rhs.earning.multiplier
                }
                // Same multiplier: the card whose points are worth more wins.
                if lhs.card.effectivePointValue != rhs.card.effectivePointValue {
                    return lhs.card.effectivePointValue > rhs.card.effectivePointValue
                }
                return lhs.card.sortOrder < rhs.card.sortOrder
            }
    }

    /// Explains why the winner beat a card earning the same multiplier.
    private func tieNote(in ranked: [Ranked]) -> String? {
        guard let winner = ranked.first,
              let tied = ranked.dropFirst().first(where: { $0.earning.multiplier == winner.earning.multiplier })
        else { return nil }
        let rate = winner.earning.multiplier.multiplierText
        let mine = winner.card.effectivePointValue
        let theirs = tied.card.effectivePointValue
        if mine > theirs {
            return "Tied at \(rate) with \(tied.card.name). Ranked first because its points are worth more (\(mine.centsText) vs \(theirs.centsText))."
        }
        return "Tied at \(rate) with \(tied.card.name), and their points are worth the same, so your Wallet order decides."
    }

    /// Cards with no earning rates saved at all.
    private var unrated: [CreditCard] {
        cards.filter { $0.rewardRates.isEmpty }
    }

    /// Cards with rates, but none for this category and no everyday rate.
    private var noRateHere: [CreditCard] {
        cards.filter { !$0.rewardRates.isEmpty && $0.earning(for: category, includePortal: includePortal) == nil }
    }

    private var hasPortalRates: Bool {
        cards.contains { $0.rewardRates.contains(where: \.viaPortal) }
    }

    /// Why some cards aren't in the ranking.
    private var footnotes: [String] {
        let names = { (cards: [CreditCard]) in ListFormatter.localizedString(byJoining: cards.map(\.name)) }
        let portalOnly = noRateHere.filter { $0.earning(for: category, includePortal: true) != nil }
        let noRate = noRateHere.filter { $0.earning(for: category, includePortal: true) == nil }
        var notes: [String] = []
        if !portalOnly.isEmpty {
            notes.append("\(names(portalOnly)) only \(portalOnly.count == 1 ? "earns" : "earn") a rate here through a travel portal.")
        }
        if !noRate.isEmpty {
            let missing = category == .everythingElse ? "everyday" : "\(category.title.lowercased()) or everyday"
            notes.append("No \(missing) rate saved for \(names(noRate)).")
        }
        if !unrated.isEmpty {
            notes.append("No earning rates saved for \(names(unrated)).")
        }
        return notes
    }

    private var coverageCards: [CreditCard] {
        guard category == .carRental else { return [] }
        return cards.filter { card in card.perks.contains { $0.localizedCaseInsensitiveContains("rental") } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CategoryGrid(selection: $category)

                    if hasPortalRates {
                        Toggle(isOn: $includePortal.animation(.snappy)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Include portal bookings")
                                    .font(.body.weight(.medium))
                                Text("Rates you only get booking through Chase Travel, Amex Travel and similar.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    let ranked = self.ranked
                    if let winner = ranked.first {
                        WinnerCard(card: winner.card, earning: winner.earning, category: category, tieNote: tieNote(in: ranked))
                            .id("\(category.rawValue)-\(includePortal)")
                            .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                    } else {
                        ContentUnavailableView(
                            "No Earning Info",
                            systemImage: "sparkles",
                            description: Text("Add earning rates to your cards in Wallet to see the best one for \(category.title.lowercased()).")
                        )
                    }

                    if !coverageCards.isEmpty {
                        GroupBox {
                            ForEach(coverageCards) { card in
                                Label("\(card.name) includes rental car coverage", systemImage: "checkmark.shield.fill")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } label: {
                            Text("Coverage")
                        }
                        .tint(.green)
                    }

                    if ranked.count > 1 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Runners-up")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            VStack(spacing: 0) {
                                let runnersUp = Array(ranked.dropFirst())
                                ForEach(runnersUp) { entry in
                                    if entry.id != runnersUp.first?.id { Divider().padding(.leading, 70) }
                                    RunnerUpRow(card: entry.card, earning: entry.earning)
                                }
                            }
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }

                    let footnotes = self.footnotes
                    if !footnotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(footnotes, id: \.self) { Text($0) }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    }
                }
                .padding()
                .animation(.snappy, value: category)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Best Card")
        }
    }
}

private struct CategoryGrid: View {
    @Binding var selection: SpendCategory
    private let columns = [GridItem(.adaptive(minimum: 78), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(SpendCategory.allCases) { category in
                let isSelected = category == selection
                Button {
                    selection = category
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: category.symbol)
                            .font(.title3)
                            .frame(height: 24)
                        Text(category.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct WinnerCard: View {
    let card: CreditCard
    let earning: Earning
    let category: SpendCategory
    var tieNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label("Best for \(category.title)", systemImage: "crown.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(earning.multiplier.multiplierText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
            }

            CardTile(card: card)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(earning.details) { rate in
                    HStack {
                        Text(rate.label)
                        Spacer()
                        Text(rate.multiplier.multiplierText)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
                if earning.isBaseRate && category != .everythingElse {
                    Text("No bonus here — this is the card's everyday rate.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let tieNote {
                    Label(tieNote, systemImage: "equal.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct RunnerUpRow: View {
    let card: CreditCard
    let earning: Earning

    var body: some View {
        HStack(spacing: 14) {
            MiniCard(theme: card.theme)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.body.weight(.medium))
                Text(earning.isBaseRate && earning.details.first?.category == .everythingElse
                     ? "Everyday rate"
                     : (earning.details.first?.label ?? ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(earning.multiplier.multiplierText)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
