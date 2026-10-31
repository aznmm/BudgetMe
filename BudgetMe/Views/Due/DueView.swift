import SwiftUI
import SwiftData

/// Payments for a month, grouped by the payday that covers them.
struct DueView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CreditCard.dueDay) private var cards: [CreditCard]
    @Query(sort: \Bill.dueDay) private var bills: [Bill]
    @AppStorage(SettingsKey.firstPayday) private var firstPayday = 1
    @AppStorage(SettingsKey.secondPayday) private var secondPayday = 15

    @State private var month = Date.now.startOfMonth
    @State private var editingBill: Bill?
    @State private var billToDelete: Bill?
    @State private var isAddingBill = false
    @State private var isAddingCard = false

    private var schedule: PaydaySchedule { PaydaySchedule([firstPayday, secondPayday]) }

    /// Payments due in `month`, counting each card or bill only from the month it was added,
    /// so earlier months don't fill up with "overdue" payments you never tracked.
    private var items: [DueItem] {
        let cardItems = cards
            .filter { month >= $0.createdAt.startOfMonth }
            .map { DueItem(card: $0, month: month) }
        let billItems = bills
            .filter { month >= $0.createdAt.startOfMonth }
            .map { DueItem(bill: $0, month: month) }
        return (cardItems + billItems).sorted { ($0.dueDate, $0.title) < ($1.dueDate, $1.title) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty && bills.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Due")
            .navigationDestination(for: CreditCard.self) { CardDetailView(card: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add Card", systemImage: "creditcard") { isAddingCard = true }
                        Button("Add Bill", systemImage: "doc.text") { isAddingBill = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingBill) { BillEditView(bill: nil) }
            .sheet(isPresented: $isAddingCard) { CardEditView(card: nil) }
            .sheet(item: $editingBill) { BillEditView(bill: $0) }
            .confirmationDialog(
                "Delete \(billToDelete?.name ?? "this bill")?",
                isPresented: Binding(get: { billToDelete != nil }, set: { if !$0 { billToDelete = nil } }),
                titleVisibility: .visible,
                presenting: billToDelete
            ) { bill in
                Button("Delete Bill", role: .destructive) {
                    withAnimation { context.delete(bill) }
                }
            } message: { _ in
                Text("This also removes its payment history. It can't be undone.")
            }
        }
    }

    private var list: some View {
        let items = self.items
        return List {
            Section {
                DueSummary(month: $month, items: items)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(schedule.paydays, id: \.self) { payday in
                let group = items.filter { schedule.payday(forDueDay: $0.dueDay) == payday }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { item in
                            row(for: item)
                        }
                    } header: {
                        PaydayHeader(payday: payday, items: group)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: month)
    }

    private func row(for item: DueItem) -> some View {
        rowContent(for: item)
            .swipeActions(edge: .leading) {
                Button {
                    withAnimation(.snappy) { item.setPaid(!item.isPaid) }
                } label: {
                    Label(item.isPaid ? "Unpaid" : "Paid", systemImage: item.isPaid ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(item.isPaid ? .gray : .green)
            }
    }

    @ViewBuilder
    private func rowContent(for item: DueItem) -> some View {
        switch item.source {
        case .card(let card):
            NavigationLink(value: card) {
                DueRow(item: item)
            }
        case .bill(let bill):
            DueRow(item: item)
                .contentShape(Rectangle())
                .onTapGesture { editingBill = bill }
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { editingBill = bill }
                    Button("Delete", systemImage: "trash", role: .destructive) { billToDelete = bill }
                }
                .swipeActions(edge: .trailing) {
                    // Not role: .destructive, which would slide the row away before you confirm.
                    Button("Delete", systemImage: "trash") { billToDelete = bill }
                        .tint(.red)
                    Button("Edit", systemImage: "pencil") { editingBill = bill }
                        .tint(.indigo)
                }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing Due Yet", systemImage: "calendar.badge.clock")
        } description: {
            Text("Add your cards and bills to see what's due each payday.")
        } actions: {
            Button {
                withAnimation { StarterData.load(into: context) }
            } label: {
                Text("Load My Cards from Notes")
                    .frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Add a Card") { isAddingCard = true }
        }
    }
}

// MARK: - Summary

private struct DueSummary: View {
    @Binding var month: Date
    let items: [DueItem]

    private var paidCount: Int { items.filter(\.isPaid).count }
    private var progress: Double { items.isEmpty ? 0 : Double(paidCount) / Double(items.count) }
    private var isCurrentMonth: Bool { month.monthKey == Date.now.monthKey }

    private var nextUp: DueItem? {
        items.first { !$0.isPaid && $0.dueDate.daysFromToday >= 0 } ?? items.first { !$0.isPaid }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { month = month.addingMonths(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(month, format: .dateTime.month(.wide).year())
                        .font(.headline)
                    if !isCurrentMonth {
                        Button("Back to This Month") { month = Date.now.startOfMonth }
                            .font(.caption.weight(.medium))
                    }
                }
                Spacer()
                Button { month = month.addingMonths(1) } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.borderless)
            .font(.body.weight(.semibold))

            HStack(spacing: 20) {
                ProgressRing(progress: progress)
                    .frame(width: 76, height: 76)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("\(paidCount)")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .contentTransition(.numericText())
                            Text("of \(items.count)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    if paidCount == items.count && !items.isEmpty {
                        Text("All paid")
                            .font(.title3.weight(.semibold))
                        Text("Nice work — nothing left this month.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let next = nextUp {
                        Text("Next up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(next.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                        DueStatusText(item: next)
                            .font(.subheadline)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.vertical, 4)
    }
}

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(
                    AngularGradient(colors: [.mint, .green], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(duration: 0.6), value: progress)
    }
}

private struct PaydayHeader: View {
    let payday: Int
    let items: [DueItem]

    var body: some View {
        HStack {
            Label("Payday · \(payday.ordinal)", systemImage: "banknote")
            Spacer()
            Text("\(items.filter { !$0.isPaid }.count) left")
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .textCase(nil)
    }
}

// MARK: - Row

struct DueRow: View {
    let item: DueItem

    var body: some View {
        HStack(spacing: 12) {
            CheckCircle(isOn: item.isPaid) {
                withAnimation(.snappy) { item.setPaid(!item.isPaid) }
            }
            .padding(.leading, -8)

            switch item.source {
            case .card(let card):
                MiniCard(card: card)
            case .bill(let bill):
                MiniCard(theme: .graphite, symbol: bill.symbol)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(item.isPaid ? Color.secondary : Color.primary)
                Text(item.dueDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                if let amount = item.amount {
                    Text(amount.currencyText)
                        .font(.body.weight(.medium).monospacedDigit())
                        .foregroundStyle(item.isPaid ? Color.secondary : Color.primary)
                }
                DueStatusText(item: item)
                    .font(.footnote.weight(.medium))
            }
        }
        .padding(.vertical, 2)
    }
}

struct DueStatusText: View {
    let item: DueItem

    var body: some View {
        let days = item.dueDate.daysFromToday
        Group {
            if item.isPaid {
                Text("Paid").foregroundStyle(.green)
            } else if days < 0 {
                Text(days == -1 ? "1 day overdue" : "\(-days) days overdue").foregroundStyle(.red)
            } else if days == 0 {
                Text("Due today").foregroundStyle(.orange)
            } else if days == 1 {
                Text("Due tomorrow").foregroundStyle(.orange)
            } else {
                Text("In \(days) days").foregroundStyle(days <= 5 ? Color.orange : Color.secondary)
            }
        }
    }
}
