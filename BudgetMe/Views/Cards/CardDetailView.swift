import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.firstPayday) private var firstPayday = 1
    @AppStorage(SettingsKey.secondPayday) private var secondPayday = 15
    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = false
    @AppStorage(SettingsKey.reminderDaysBefore) private var defaultReminderDays = 2

    let card: CreditCard

    @State private var isEditing = false
    @State private var isAddingCredit = false
    @State private var editingCredit: Benefit?
    @State private var isConfirmingDelete = false
    @State private var isDeleted = false
    @State private var isSettingRotating = false

    private var month: Date { Date.now.startOfMonth }
    private var isPaid: Bool { card.isPaid(monthKey: month.monthKey) }
    private var dueDate: Date {
        // If this month's due date has passed and it's paid, show next month's.
        let thisMonth = month.day(card.dueDay)
        return (thisMonth.daysFromToday < 0 && isPaid) ? month.addingMonths(1).day(card.dueDay) : thisMonth
    }

    /// Points out used credits that can't count toward the fee because they have no value.
    private func unpricedNote(year: Int) -> String {
        let unpriced = card.unpricedCreditsUsed(inYear: year)
        let counted = "Counts the value of each credit every time you use it this year."
        guard !unpriced.isEmpty else { return counted }
        let names = ListFormatter.localizedString(byJoining: unpriced.map(\.name))
        return "\(counted) \(names) \(unpriced.count == 1 ? "has" : "have") no value yet, so \(unpriced.count == 1 ? "it doesn't" : "they don't") count. Tap a credit above to add its value."
    }

    /// "Usual 3× + 4× bonus", or why the bonus isn't counting.
    private func rotatingCaption(_ earning: Earning) -> String {
        let usual = (earning.multiplier - earning.rotatingExtra).multiplierText
        guard earning.rotatingBonus != nil else { return "Cap reached, back to the usual \(usual)" }
        return "Usual \(usual) + \(earning.rotatingExtra.multiplierText) bonus"
    }

    private var rotatingSection: some View {
        let current = card.rotatingRates()
        let quarter = Cadence.quarterly.periodLabel(for: .now)
        let buttonTitle = current.isEmpty ? "Set \(quarter) Categories" : "Change Categories"
        return Section {
            if current.isEmpty {
                Text("Not set for \(quarter) yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(current) { rate in
                    // What the category earns with the bonus added on top of its usual rate.
                    let earning = card.earning(for: rate.choice)
                    HStack(spacing: 12) {
                        Image(systemName: rate.symbol)
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rate.choice.title)
                            if let earning {
                                Text(rotatingCaption(earning))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text((earning?.multiplier ?? rate.multiplier).multiplierText)
                            .font(.body.weight(.semibold).monospacedDigit())
                    }
                }
                Toggle("Activated with card issuer", isOn: Binding(
                    get: { card.isRotatingActivated() },
                    set: { activated in withAnimation { card.setRotatingActivated(activated) } }
                ))
                if let capText = current.first?.capText {
                    Toggle(isOn: Binding(
                        get: { current.allSatisfy { card.isCapReached($0) } },
                        set: { reached in withAnimation { current.forEach { card.setCapReached(reached, for: $0) } } }
                    )) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Cap reached")
                            Text(capText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button(buttonTitle, systemImage: "arrow.triangle.2.circlepath") {
                isSettingRotating = true
            }
        } header: {
            Text("\(quarter) Rotating 5× Categories")
        } footer: {
            Text("These only earn this quarter. When the next one starts, Best Card reminds you to set the new ones.")
        }
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
                if remindersEnabled {
                    LabeledContent("Reminder", value: ReminderPlan.noticeText(card.reminderDaysBefore ?? defaultReminderDays))
                }
                if let network = card.effectiveNetwork {
                    LabeledContent("Network", value: network.title)
                }
                Toggle(isOn: Binding(
                    get: { isPaid },
                    set: { newValue in withAnimation { card.setPaid(newValue, monthKey: month.monthKey) } }
                )) {
                    Text("Paid for \(month.formatted(.dateTime.month(.wide)))")
                }
                .tint(.green)
            }

            Section {
                // Rotating categories have their own section below.
                let rates = card.rewardRates.filter { $0.rotatingQuarter == nil }.sorted { $0.multiplier > $1.multiplier }
                if rates.isEmpty {
                    Text("No earning rates yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rates) { rate in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: rate.symbol)
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(rate.label)
                                    if !rate.note.isEmpty && rate.note != rate.choice.title {
                                        Text(rate.choice.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let capText = rate.capText {
                                        Text(capText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(rate.multiplier.multiplierText)
                                    .font(.body.weight(.semibold).monospacedDigit())
                            }
                            if rate.capPeriod != nil {
                                Toggle(isOn: Binding(
                                    get: { card.isCapReached(rate) },
                                    set: { reached in withAnimation { card.setCapReached(reached, for: rate) } }
                                )) {
                                    Text("Cap reached")
                                        .font(.subheadline)
                                }
                                .padding(.leading, 36)
                            }
                        }
                    }
                }
            } header: {
                Text("Earning")
            }

            if card.effectiveHasRotatingCategories || card.rewardRates.contains(where: { $0.rotatingQuarter != nil }) {
                rotatingSection
            }

            Section {
                ForEach(card.sortedBenefits) { benefit in
                    BenefitRow(benefit: benefit, onEdit: { editingCredit = $0 })
                }
                if !card.sortedBenefits.isEmpty {
                    NavigationLink {
                        CreditHistoryView(card: card)
                    } label: {
                        Label("Used This Year", systemImage: "calendar")
                    }
                }
                Button("Add Credit", systemImage: "plus.circle.fill") { isAddingCredit = true }
            } header: {
                Text("Credits")
            }

            if let fee = card.annualFee {
                let year = Calendar.current.component(.year, from: .now)
                Section {
                    LabeledContent("Annual fee", value: fee.currencyText)
                    VStack(alignment: .leading, spacing: 4) {
                        // String(year) so it reads "2026", not "2,026".
                        Text("Credits used in \(String(year))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        FeeProgress(fee: fee, earned: card.creditValueUsed(inYear: year))
                    }
                } header: {
                    Text("Annual Fee")
                } footer: {
                    Text(unpricedNote(year: year))
                }
            }

            if !card.perks.isEmpty || card.effectiveNoForeignFee {
                Section("Perks") {
                    if card.effectiveNoForeignFee {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("No foreign transaction fees")
                                if card.noForeignFee == nil {
                                    Text("Estimated. Check it in Edit.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "globe")
                        }
                        .symbolRenderingMode(.hierarchical)
                    }
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
        .sheet(isPresented: $isSettingRotating) { RotatingCategoriesView(card: card) }
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
            Text("This also removes its credits.")
        }
    }
}
