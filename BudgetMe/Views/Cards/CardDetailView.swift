import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.firstPayday) private var firstPayday = 1
    @AppStorage(SettingsKey.secondPayday) private var secondPayday = 15

    let card: CreditCard

    @State private var isEditing = false
    @State private var isAddingCredit = false
    @State private var editingCredit: Benefit?
    @State private var isConfirmingDelete = false
    @State private var isDeleted = false

    private var month: Date { Date.now.startOfMonth }
    private var isPaid: Bool { card.isPaid(monthKey: month.monthKey) }
    private var dueDate: Date {
        // If this month's due date has passed and it's paid, show next month's.
        let thisMonth = month.day(card.dueDay)
        return (thisMonth.daysFromToday < 0 && isPaid) ? month.addingMonths(1).day(card.dueDay) : thisMonth
    }

    var body: some View {
        if isDeleted {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        List {
            Section {
                CardTile(card: card, isPaid: isPaid)
                    .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section("Payment") {
                LabeledContent("Due") {
                    Text(dueDate, format: .dateTime.weekday(.wide).month(.wide).day())
                }
                LabeledContent("Covered by", value: "Payday · \(PaydaySchedule([firstPayday, secondPayday]).payday(forDueDay: card.dueDay).ordinal)")
                Toggle(isOn: Binding(
                    get: { isPaid },
                    set: { newValue in withAnimation { card.setPaid(newValue, monthKey: month.monthKey) } }
                )) {
                    Text("Paid for \(month.formatted(.dateTime.month(.wide)))")
                }
                .tint(.green)
            }

            Section {
                let rates = card.rewardRates.sorted { $0.multiplier > $1.multiplier }
                if rates.isEmpty {
                    Text("No earning rates yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rates) { rate in
                        HStack(spacing: 12) {
                            Image(systemName: rate.category.symbol)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(rate.label)
                                if !rate.note.isEmpty && rate.note != rate.category.title {
                                    Text(rate.category.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(rate.multiplier.multiplierText)
                                .font(.body.weight(.semibold).monospacedDigit())
                        }
                    }
                }
            } header: {
                Text("Earning")
            }

            Section {
                ForEach(card.sortedBenefits) { benefit in
                    BenefitRow(benefit: benefit, onEdit: { editingCredit = $0 })
                }
                Button("Add Credit", systemImage: "plus.circle.fill") { isAddingCredit = true }
            } header: {
                Text("Credits")
            }

            if !card.perks.isEmpty {
                Section("Perks") {
                    ForEach(card.perks, id: \.self) { perk in
                        Label(perk, systemImage: "checkmark.shield.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }

            if !card.notes.isEmpty {
                Section("Notes") {
                    Text(card.notes)
                }
            }

            Section {
                Button("Delete Card", role: .destructive) { isConfirmingDelete = true }
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) { CardEditView(card: card) }
        .sheet(isPresented: $isAddingCredit) { BenefitEditView(benefit: nil, card: card) }
        .sheet(item: $editingCredit) { BenefitEditView(benefit: $0, card: card) }
        .confirmationDialog("Delete \(card.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Card and Its Credits", role: .destructive) {
                isDeleted = true
                dismiss()
                // Delete after the pop animation so the view never reads a deleted model.
                let doomed = self.card
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    context.delete(doomed)
                }
            }
        } message: {
            Text("This removes it from all your synced devices.")
        }
    }
}
