import SwiftUI
import SwiftData

/// Add or edit a card. Changes apply when you tap Save.
struct CardEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CreditCard.sortOrder) private var allCards: [CreditCard]

    let card: CreditCard?

    @State private var name = ""
    @State private var issuer = ""
    @State private var lastFour = ""
    @State private var theme: CardTheme = .graphite
    @State private var dueDay = 1
    @State private var rates: [RewardRate] = []
    @State private var perks: [String] = []
    @State private var notes = ""
    @State private var hasCustomReminder = false
    @State private var reminderDays = 2
    @State private var annualFeeText = ""
    @State private var pointValue = 1.0
    /// False while the point value is still the estimate from the card's name.
    @State private var hasCustomPointValue = false
    @State private var didLoad = false

    @AppStorage(SettingsKey.reminderDaysBefore) private var defaultReminderDays = 2

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CardTile(name: name, issuer: issuer, lastFour: lastFour, dueDay: dueDay, theme: theme)
                        .padding(.vertical, 4)
                        .animation(.snappy, value: theme)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CardTheme.allCases) { option in
                                Button {
                                    theme = option
                                } label: {
                                    Circle()
                                        .fill(option.gradient)
                                        .frame(width: 34, height: 34)
                                        .overlay {
                                            Circle()
                                                .strokeBorder(Color.primary, lineWidth: theme == option ? 2.5 : 0)
                                                .padding(-4)
                                        }
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.title)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                    .sensoryFeedback(.selection, trigger: theme)
                } header: {
                    Text("Finish")
                }

                Section("Card") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Issuer (optional)", text: $issuer)
                        .textInputAutocapitalization(.words)
                    TextField("Last four digits (optional)", text: $lastFour)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFour) {
                            let digits = String(lastFour.filter(\.isNumber).prefix(4))
                            if digits != lastFour { lastFour = digits }
                        }
                    Picker("Payment due", selection: $dueDay) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day.ordinal) of the month").tag(day)
                        }
                    }
                    HStack {
                        Text("Annual fee")
                        Spacer()
                        TextField("None", text: $annualFeeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                ReminderSection(isCustom: $hasCustomReminder, daysBefore: $reminderDays)

                Section {
                    ForEach($rates) { $rate in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Picker("Category", selection: $rate.category) {
                                    ForEach(SpendCategory.allCases) { category in
                                        Label(category.title, systemImage: category.symbol).tag(category)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .fixedSize()

                                Spacer()

                                Stepper(value: $rate.multiplier, in: 0.5...25, step: 0.5) {
                                    Text(rate.multiplier.multiplierText)
                                        .font(.body.weight(.semibold).monospacedDigit())
                                }
                                .fixedSize()
                            }
                            TextField("Details (e.g. Via Chase Travel)", text: $rate.note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Toggle("Through a travel portal", isOn: $rate.viaPortal)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { rates.remove(atOffsets: $0) }

                    Button("Add Earning Rate", systemImage: "plus.circle.fill") {
                        withAnimation {
                            rates.append(RewardRate(category: .dining, multiplier: 2))
                        }
                    }
                } header: {
                    Text("Earning")
                } footer: {
                    Text("Used by Best Card to rank your cards. Add an \u{201C}Everything Else\u{201D} rate for the card's base earn. Turn on \u{201C}Through a travel portal\u{201D} for rates you only get when booking through the card's portal, so Best Card can leave them out.")
                }

                Section {
                    Stepper(value: pointValueBinding, in: 0.1...5, step: 0.1) {
                        LabeledContent("Point value", value: "\(shownPointValue.centsText) per point")
                    }
                } footer: {
                    Text(pointValueFooter)
                }

                Section("Perks") {
                    ForEach(perks.indices, id: \.self) { index in
                        TextField("Perk", text: Binding(
                            get: { perks.indices.contains(index) ? perks[index] : "" },
                            set: { if perks.indices.contains(index) { perks[index] = $0 } }
                        ))
                    }
                    .onDelete { perks.remove(atOffsets: $0) }
                    Button("Add Perk", systemImage: "plus.circle.fill") {
                        perks.append("")
                    }
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(card == nil ? "New Card" : "Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    /// The point value on screen: what you picked, or the estimate from the name as you type it.
    private var shownPointValue: Double {
        hasCustomPointValue ? pointValue : CreditCard.estimatedPointValue(name: name, issuer: issuer)
    }

    private var pointValueBinding: Binding<Double> {
        Binding(
            get: { shownPointValue },
            set: { newValue in
                // Round so repeated 0.1 steps don't drift (0.30000000000000004).
                pointValue = (newValue * 10).rounded() / 10
                hasCustomPointValue = true
            }
        )
    }

    private var pointValueFooter: String {
        let tip = "Roughly what one point is worth. When two cards earn the same multiplier, Best Card puts the one with more valuable points first."
        return hasCustomPointValue ? tip : tip + " Estimated from the card's name until you change it."
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        reminderDays = defaultReminderDays
        guard let card else { return }
        if let days = card.reminderDaysBefore {
            hasCustomReminder = true
            reminderDays = days
        }
        if let value = card.pointValue {
            hasCustomPointValue = true
            pointValue = value
        }
        annualFeeText = card.annualFee.map { $0.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? ""
        name = card.name
        issuer = card.issuer
        lastFour = card.lastFour
        theme = card.theme
        dueDay = card.dueDay
        rates = card.rewardRates
        perks = card.perks
        notes = card.notes
    }

    private func save() {
        let target: CreditCard
        if let card {
            target = card
        } else {
            target = CreditCard(name: name, dueDay: dueDay, sortOrder: (allCards.map(\.sortOrder).max() ?? -1) + 1)
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.issuer = issuer.trimmingCharacters(in: .whitespaces)
        target.lastFour = lastFour
        target.theme = theme
        target.dueDay = dueDay
        target.reminderDaysBefore = hasCustomReminder ? reminderDays : nil
        target.pointValue = hasCustomPointValue ? pointValue : nil
        target.annualFee = parseAmount(annualFeeText).flatMap { $0 > 0 ? $0 : nil }
        target.rewardRates = rates
        target.perks = perks
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        target.notes = notes
        dismiss()
    }
}
