import SwiftUI
import SwiftData

/// Every credit used in a year, card by card. Tap a past period to fill in credits used before the app.
struct CreditHistoryView: View {
    /// Show only this card's credits, or every card when nil.
    var card: CreditCard?

    @Query(sort: \CreditCard.sortOrder) private var cards: [CreditCard]
    @Query(sort: \Benefit.name) private var benefits: [Benefit]

    @State private var year = Calendar.current.component(.year, from: .now)

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    /// Credits on a schedule. One-time credits aren't tied to a year.
    private var tracked: [Benefit] {
        benefits.filter { $0.cadence != .once && (card == nil || $0.card == card) }
    }

    private var hasOneTimeCredits: Bool {
        benefits.contains { $0.cadence == .once && (card == nil || $0.card == card) }
    }

    /// Lets you go back at least a year to fill it in, or further if older uses were recorded.
    private var earliestYear: Int {
        let recorded = tracked.flatMap(\.usedPeriods).compactMap { Int($0.prefix(4)) }
        return min(recorded.min() ?? currentYear, currentYear - 1)
    }

    private var shownCards: [CreditCard] {
        card.map { [$0] } ?? cards
    }

    private var title: String {
        if let card { return "\(card.name) Credits" }
        return "Credit History"
    }

    private var emptyMessage: String {
        if let card { return "Add a credit to \(card.name) to see its history here." }
        return "Add credits in the Credits tab to see their history here."
    }

    private var footnote: String {
        let tip = "Tap a period to mark it used or not. Periods that haven't started yet can't be marked."
        return hasOneTimeCredits ? tip + " One-time credits aren't tied to a year, so they aren't shown." : tip
    }

    var body: some View {
        Group {
            if tracked.isEmpty {
                ContentUnavailableView("No Credits", systemImage: "calendar", description: Text(emptyMessage))
            } else {
                list
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var list: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    YearStepper(year: $year, range: earliestYear...currentYear)
                    YearTotals(benefits: tracked, year: year)
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(shownCards) { card in
                let rows = tracked.filter { $0.card == card }
                if !rows.isEmpty {
                    Section {
                        ForEach(rows) { benefit in CreditYearRow(benefit: benefit, year: year) }
                    } header: {
                        HStack(spacing: 8) {
                            MiniCard(theme: card.theme)
                                .scaleEffect(0.7)
                                .frame(width: 30, height: 20)
                            Text(card.name)
                        }
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                    }
                }
            }

            if card == nil {
                let unassigned = tracked.filter { $0.card == nil }
                if !unassigned.isEmpty {
                    Section("Other") {
                        ForEach(unassigned) { benefit in CreditYearRow(benefit: benefit, year: year) }
                    }
                }
            }

            Section {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }
        .animation(.snappy, value: year)
    }
}

private struct YearStepper: View {
    @Binding var year: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Button("Previous Year", systemImage: "chevron.left") { year -= 1 }
                .disabled(year <= range.lowerBound)
            Spacer()
            // String(year) so it reads "2026", not "2,026".
            Text(String(year))
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
            Spacer()
            Button("Next Year", systemImage: "chevron.right") { year += 1 }
                .disabled(year >= range.upperBound)
        }
        .labelStyle(.iconOnly)
        .font(.title3.weight(.semibold))
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
    }
}

private struct YearTotals: View {
    let benefits: [Benefit]
    let year: Int

    private var totals: (used: Int, value: Double, missed: Int) {
        var used = 0
        var value = 0.0
        var missed = 0
        for benefit in benefits {
            for period in benefit.cadence.periods(inYear: year) {
                if benefit.isUsed(periodKey: period.key) {
                    used += 1
                    value += benefit.amount ?? 0
                } else if period.hasEnded() {
                    missed += 1
                }
            }
        }
        return (used, value, missed)
    }

    var body: some View {
        let totals = self.totals
        HStack(spacing: 12) {
            SummaryTile(value: "\(totals.used)", label: "Used", symbol: "checkmark.circle.fill", tint: .pink)
            if totals.value > 0 {
                SummaryTile(value: totals.value.currencyText, label: "Value used", symbol: "dollarsign.circle.fill", tint: .green)
            }
            SummaryTile(value: "\(totals.missed)", label: "Missed", symbol: "clock.badge.xmark", tint: .orange)
        }
    }
}

/// One credit's year: a box for each month, quarter or half, filled in when used.
private struct CreditYearRow: View {
    let benefit: Benefit
    let year: Int

    var body: some View {
        let periods = benefit.cadence.periods(inYear: year)
        let usedCount = periods.filter { benefit.isUsed(periodKey: $0.key) }.count
        let currentKey = benefit.cadence.periodKey(for: .now)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(benefit.name)
                    .font(.body.weight(.medium))
                Spacer(minLength: 8)
                Text(summary(used: usedCount, of: periods.count))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: max(1, min(periods.count, 6))), spacing: 6) {
                ForEach(periods) { period in
                    let isUsed = benefit.isUsed(periodKey: period.key)
                    PeriodBox(
                        label: period.label,
                        isUsed: isUsed,
                        isCurrent: period.key == currentKey,
                        isAvailable: period.hasStarted()
                    ) {
                        withAnimation(.snappy) { benefit.setUsed(!isUsed, periodKey: period.key) }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func summary(used: Int, of total: Int) -> String {
        let count = "\(used) of \(total) used"
        guard let amount = benefit.amount, used > 0 else { return count }
        return "\(count) · \((amount * Double(used)).currencyText)"
    }
}

private struct PeriodBox: View {
    let label: String
    let isUsed: Bool
    let isCurrent: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 32)
                .foregroundStyle(isUsed ? Color.white : (isAvailable ? Color.primary : Color.secondary.opacity(0.5)))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isUsed ? Color.pink : (isAvailable ? Color(.tertiarySystemFill) : Color(.quaternarySystemFill)))
                )
                .overlay {
                    if isCurrent && !isUsed {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.pink, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.borderless)
        .disabled(!isAvailable)
        .sensoryFeedback(.selection, trigger: isUsed)
        .accessibilityLabel("\(label), \(isUsed ? "used" : "not used")")
    }
}

#Preview {
    NavigationStack {
        CreditHistoryView()
    }
    .modelContainer(previewContainer)
}
