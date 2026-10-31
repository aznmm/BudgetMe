import SwiftUI
import SwiftData

/// Statement credits and perks, grouped by card. Each one resets on its own schedule.
struct CreditsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case available = "Available"
        case used = "Used"
        case all = "All"
        var id: String { rawValue }
    }

    @Query(sort: \CreditCard.sortOrder) private var cards: [CreditCard]
    @Query(sort: \Benefit.name) private var benefits: [Benefit]

    @State private var filter: Filter = .available
    @State private var editing: Benefit?
    @State private var isAdding = false

    private var available: [Benefit] { benefits.filter { !$0.isUsed() } }

    private func visible(_ list: [Benefit]) -> [Benefit] {
        switch filter {
        case .available: list.filter { !$0.isUsed() }
        case .used: list.filter { $0.isUsed() }
        case .all: list
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if benefits.isEmpty {
                    ContentUnavailableView {
                        Label("No Credits", systemImage: "gift")
                    } description: {
                        Text("Track monthly and yearly credits like Uber Cash, Resy or hotel credits so you never leave money on the table.")
                    } actions: {
                        Button("Add a Credit") { isAdding = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Credits")
            .toolbar {
                if !benefits.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            CreditHistoryView()
                        } label: {
                            Label("Credit History", systemImage: "calendar")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Credit", systemImage: "plus") { isAdding = true }
                }
            }
            .sheet(isPresented: $isAdding) { BenefitEditView(benefit: nil, card: nil) }
            .sheet(item: $editing) { BenefitEditView(benefit: $0, card: $0.card) }
        }
    }

    private var list: some View {
        List {
            Section {
                CreditsSummary(available: available)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(cards) { card in
                let rows = visible(card.sortedBenefits)
                if !rows.isEmpty {
                    Section {
                        ForEach(rows) { benefit in BenefitRow(benefit: benefit, onEdit: { editing = $0 }) }
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

            let unassigned = visible(benefits.filter { $0.card == nil })
            if !unassigned.isEmpty {
                Section("Other") {
                    ForEach(unassigned) { benefit in BenefitRow(benefit: benefit, onEdit: { editing = $0 }) }
                }
            }

            if visible(benefits).isEmpty {
                Text(filter == .available ? "Every credit is used for this period. 🎉" : "Nothing here yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .animation(.snappy, value: filter)
    }
}

private struct CreditsSummary: View {
    let available: [Benefit]

    private var unusedValue: Double { available.compactMap(\.amount).reduce(0, +) }

    private var expiringSoon: [Benefit] {
        available.filter { benefit in
            guard let reset = benefit.cadence.nextReset(after: .now) else { return false }
            return reset.daysFromToday <= 7
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            SummaryTile(value: "\(available.count)", label: "Left to use", symbol: "gift.fill", tint: .pink)
            if unusedValue > 0 {
                SummaryTile(value: unusedValue.currencyText, label: "Known value", symbol: "dollarsign.circle.fill", tint: .green)
            }
            SummaryTile(value: "\(expiringSoon.count)", label: "Reset this week", symbol: "hourglass", tint: .orange)
        }
        .padding(.vertical, 4)
    }
}

struct SummaryTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct BenefitRow: View {
    let benefit: Benefit
    var onEdit: (Benefit) -> Void

    private var resetText: String {
        guard let reset = benefit.cadence.nextReset(after: .now) else { return benefit.cadence.title }
        let days = reset.daysFromToday
        let when = days <= 1 ? "tomorrow" : (days <= 7 ? "in \(days) days" : reset.formatted(.dateTime.month(.abbreviated).day()))
        return "\(benefit.cadence.periodLabel(for: .now)) · resets \(when)"
    }

    private var resetsSoon: Bool {
        guard !benefit.isUsed(), let reset = benefit.cadence.nextReset(after: .now) else { return false }
        return reset.daysFromToday <= 7
    }

    var body: some View {
        HStack(spacing: 10) {
            CheckCircle(isOn: benefit.isUsed(), tint: .pink) {
                withAnimation(.snappy) { benefit.setUsed(!benefit.isUsed()) }
            }
            .padding(.leading, -8)

            VStack(alignment: .leading, spacing: 2) {
                Text(benefit.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(benefit.isUsed() ? Color.secondary : Color.primary)
                    .strikethrough(benefit.isUsed(), color: .secondary)
                Text(resetText)
                    .font(.footnote)
                    .foregroundStyle(resetsSoon ? Color.orange : Color.secondary)
            }

            Spacer(minLength: 8)

            if let amount = benefit.amount {
                Text(amount.currencyText)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(benefit.isUsed() ? Color.secondary : Color.primary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit(benefit) }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation(.snappy) { benefit.setUsed(!benefit.isUsed()) }
            } label: {
                Label(benefit.isUsed() ? "Unused" : "Used", systemImage: benefit.isUsed() ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(benefit.isUsed() ? .gray : .pink)
        }
    }
}
