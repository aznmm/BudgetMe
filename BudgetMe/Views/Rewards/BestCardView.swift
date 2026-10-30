import SwiftUI
import SwiftData

/// "Which card should I use?" Pick what you're buying, see your cards ranked by what they earn.
struct BestCardView: View {
    @Query(sort: \CreditCard.sortOrder) private var cards: [CreditCard]
    @State private var category: SpendCategory = .dining

    private struct Ranked: Identifiable {
        let card: CreditCard
        let earning: Earning
        var id: PersistentIdentifier { card.persistentModelID }
    }

    private var ranked: [Ranked] {
        cards
            .compactMap { card in card.earning(for: category).map { Ranked(card: card, earning: $0) } }
            .sorted { lhs, rhs in
                if lhs.earning.multiplier != rhs.earning.multiplier {
                    return lhs.earning.multiplier > rhs.earning.multiplier
                }
                return lhs.card.sortOrder < rhs.card.sortOrder
            }
    }

    private var unrated: [CreditCard] {
        cards.filter { $0.earning(for: category) == nil }
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

                    let ranked = self.ranked
                    if let winner = ranked.first {
                        WinnerCard(card: winner.card, earning: winner.earning, category: category)
                            .id(category)
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

                    if !unrated.isEmpty {
                        Text("No earning rates saved for \(ListFormatter.localizedString(byJoining: unrated.map(\.name))).")
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
