import SwiftUI
import SwiftData

/// Add or edit a non-card monthly payment.
struct BillEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let bill: Bill?

    @State private var name = ""
    @State private var amountText = ""
    @State private var dueDay = 1
    @State private var symbol = "dollarsign.circle.fill"
    @State private var hasCustomReminder = false
    @State private var reminderDays = 2
    @State private var isConfirmingDelete = false
    @State private var didLoad = false

    @AppStorage(SettingsKey.reminderDaysBefore) private var defaultReminderDays = 2

    private let symbols = [
        "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "house.fill", "car.fill",
        "bolt.fill", "wifi", "iphone", "tv.fill", "heart.fill", "graduationcap.fill",
        "cross.case.fill", "building.columns.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Rent, Invest)", text: $name)
                        .textInputAutocapitalization(.words)
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("Optional", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Due", selection: $dueDay) {
                        ForEach(1...31, id: \.self) { Text("\($0.ordinal) of the month").tag($0) }
                    }
                }

                ReminderSection(isCustom: $hasCustomReminder, daysBefore: $reminderDays)

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                        ForEach(symbols, id: \.self) { option in
                            Button {
                                symbol = option
                            } label: {
                                Image(systemName: option)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(symbol == option ? Color.white : Color.primary)
                                    .background(
                                        Circle().fill(symbol == option ? Color.accentColor : Color(.tertiarySystemFill))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if let bill {
                    Section {
                        Button("Delete Bill", role: .destructive) { isConfirmingDelete = true }
                    }
                    .confirmationDialog("Delete \(bill.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                        Button("Delete Bill", role: .destructive) {
                            context.delete(bill)
                            dismiss()
                        }
                    } message: {
                        Text("This also removes its payment history. It can't be undone.")
                    }
                }
            }
            .navigationTitle(bill == nil ? "New Bill" : "Edit Bill")
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

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        reminderDays = defaultReminderDays
        guard let bill else { return }
        if let days = bill.reminderDaysBefore {
            hasCustomReminder = true
            reminderDays = days
        }
        name = bill.name
        amountText = bill.amount.map { $0.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? ""
        dueDay = bill.dueDay
        symbol = bill.symbol
    }

    private func save() {
        let target: Bill
        if let bill {
            target = bill
        } else {
            target = Bill(name: name, dueDay: dueDay)
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.amount = parseAmount(amountText)
        target.dueDay = dueDay
        target.reminderDaysBefore = hasCustomReminder ? reminderDays : nil
        target.symbol = symbol
        dismiss()
    }
}
