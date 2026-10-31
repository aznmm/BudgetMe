import SwiftUI
import SwiftData

/// "Which card should I use?" Pick what you're buying, see your cards ranked by what they earn.
struct BestCardView: View {
    @Query(sort: \CreditCard.sortOrder) private var cards: [CreditCard]
    @State private var category: SpendCategory = .dining
    @AppStorage(SettingsKey.includePortalRates) private var includePortal = true
    @AppStorage(SettingsKey.noForeignFeesOnly) private var noForeignFeesOnly = false
    @AppStorage(SettingsKey.widelyAcceptedOnly) private var widelyAcceptedOnly = false

    private struct Ranked: Identifiable {
        let card: CreditCard
        let earning: Earning
        var id: PersistentIdentifier { card.persistentModelID }
    }

    /// Cards you carry, which aren't hidden from Best Card.
    private var shownCards: [CreditCard] {
        cards.filter(\.showInBestCard)
    }

    /// Cards that pass the filters.
    private var eligibleCards: [CreditCard] {
        shownCards.filter { card in
            (!noForeignFeesOnly || card.effectiveNoForeignFee)
                && (!widelyAcceptedOnly || card.effectiveNetwork?.isWidelyAccepted == true)
        }
    }

    private var ranked: [Ranked] {
        eligibleCards
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
        eligibleCards.filter { $0.rewardRates.isEmpty }
    }

    private var filtersActive: Bool {
        !includePortal || noForeignFeesOnly || widelyAcceptedOnly
    }

    private var activeFiltersText: String {
        var parts: [String] = []
        if widelyAcceptedOnly { parts.append("Visa & Mastercard only") }
        if noForeignFeesOnly { parts.append("No foreign transaction fees") }
        if !includePortal { parts.append("Portal bookings left out") }
        return parts.joined(separator: " · ")
    }

    /// Why some cards aren't in the ranking, or rank lower than usual.
    private var footnotes: [String] {
        let names = { (cards: [CreditCard]) in ListFormatter.localizedString(byJoining: cards.map(\.name)) }
        var notes: [String] = []

        if widelyAcceptedOnly {
            let otherNetworks = shownCards.filter { card in
                guard let network = card.effectiveNetwork else { return false }
                return !network.isWidelyAccepted
            }
            let noNetwork = shownCards.filter { $0.effectiveNetwork == nil }
            if !otherNetworks.isEmpty {
                notes.append("Left out as Amex or Discover: \(names(otherNetworks)).")
            }
            if !noNetwork.isEmpty {
                notes.append("Left out because no network is set: \(names(noNetwork)). Set it when editing the card.")
            }
        }
        if noForeignFeesOnly {
            let withForeignFees = shownCards.filter { !$0.effectiveNoForeignFee }
            if !withForeignFees.isEmpty {
                notes.append("Left out because \(withForeignFees.count == 1 ? "it charges" : "they charge") foreign transaction fees: \(names(withForeignFees)).")
            }
        }

        for card in eligibleCards {
            let capped = card.rewardRates.filter { category.isCovered(by: $0.category) && card.isCapReached($0) }
            for rate in capped {
                notes.append("\(card.name)'s \(rate.multiplier.multiplierText) \(rate.label.lowercased()) has hit its cap, so its next rate is used until the cap resets.")
            }
        }
        let outdatedRotating = eligibleCards.filter { card in
            card.rewardRates.contains { $0.rotatingQuarter != nil && !$0.isActive() }
        }
        if !outdatedRotating.isEmpty {
            notes.append("Rotating categories are out of date for \(names(outdatedRotating)). Edit the card to set this quarter's.")
        }

        if !unrated.isEmpty {
            notes.append("No earning rates saved for \(names(unrated)).")
        }
        let hidden = cards.filter { !$0.showInBestCard }
        if !hidden.isEmpty {
            notes.append("Hidden from Best Card: \(names(hidden)).")
        }
        return notes
    }

    private var coverageCards: [CreditCard] {
        guard category == .carRental else { return [] }
        return eligibleCards.filter { card in card.perks.contains { $0.localizedCaseInsensitiveContains("rental") } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CategoryGrid(selection: $category)

                    if filtersActive {
                        HStack(alignment: .firstTextBaseline) {
                            Label(activeFiltersText, systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Button("Reset") {
                                withAnimation(.snappy) {
                                    includePortal = true
                                    noForeignFeesOnly = false
                                    widelyAcceptedOnly = false
                                }
                            }
                            .font(.footnote.weight(.semibold))
                        }
                        .padding(.horizontal, 4)
                    }

                    let ranked = self.ranked
                    if let winner = ranked.first {
                        WinnerCard(card: winner.card, earning: winner.earning, category: category, tieNote: tieNote(in: ranked))
                            .id("\(category.rawValue)-\(includePortal)-\(noForeignFeesOnly)-\(widelyAcceptedOnly)")
                            .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                    } else if filtersActive && !cards.isEmpty {
                        ContentUnavailableView(
                            "No Matching Cards",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("None of your cards earn on \(category.title.lowercased()) with these filters. Tap Reset or change them in the filter menu.")
                        )
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Toggle("Include Portal Bookings", systemImage: "globe", isOn: $includePortal.animation(.snappy))
                        Toggle("No Foreign Transaction Fees", systemImage: "airplane", isOn: $noForeignFeesOnly.animation(.snappy))
                        Toggle("Visa & Mastercard Only", systemImage: "creditcard", isOn: $widelyAcceptedOnly.animation(.snappy))
                    } label: {
                        Label("Filters", systemImage: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
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
                VStack(alignment: .trailing, spacing: 0) {
                    Text(earning.multiplier.multiplierText)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.tint)
                    Text("≈ \(card.percentBack(for: earning).percentText) back")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            CardTile(card: card)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(earning.details) { rate in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(rate.label)
                            Spacer()
                            Text(rate.multiplier.multiplierText)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                        if let capText = rate.capText {
                            Text(capText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if earning.isAssumed {
                    Text("No everyday rate is saved for this card, so 1× is assumed. Add one when editing the card.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if earning.isBaseRate && category != .everythingElse {
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

    private var subtitle: String {
        if earning.isAssumed { return "Everyday rate (assumed)" }
        if earning.isBaseRate && earning.details.first?.category == .everythingElse { return "Everyday rate" }
        return earning.details.first?.label ?? ""
    }

    var body: some View {
        HStack(spacing: 14) {
            MiniCard(theme: card.theme)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(earning.multiplier.multiplierText)
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text("≈ \(card.percentBack(for: earning).percentText)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
