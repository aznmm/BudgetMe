import SwiftUI
import SwiftData

/// Add or edit a credit.
struct BenefitEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CreditCard.sortOrder) private var cards: [CreditCard]

    let benefit: Benefit?
    let card: CreditCard?

    @State private var name = ""
    @State private var amountText = ""
    @State private var cadence: Cadence = .monthly
    @State private var selectedCard: CreditCard?
    @State private var note = ""
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Uber Cash)", text: $name)
                        .textInputAutocapitalization(.words)
                    HStack {
                        Text("Value")
                        Spacer()
                        TextField("Optional", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Picker("Renews", selection: $cadence) {
                        ForEach(Cadence.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Card", selection: $selectedCard) {
                        Text("None").tag(CreditCard?.none)
                        ForEach(cards) { card in
                            Text(card.name).tag(CreditCard?.some(card))
                        }
                    }
                } footer: {
                    if let reset = cadence.nextReset(after: .now) {
                        Text("Current period: \(cadence.periodLabel(for: .now)). Resets \(reset.formatted(.dateTime.month(.wide).day().year())).")
                    } else {
                        Text("Stays checked once used.")
                    }
                }

                Section("Notes") {
                    TextField("Terms, enrollment, where it applies…", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let benefit {
                    Section {
                        Button("Delete Credit", role: .destructive) {
                            context.delete(benefit)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(benefit == nil ? "New Credit" : "Edit Credit")
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
        selectedCard = card
        guard let benefit else { return }
        name = benefit.name
        amountText = benefit.amount.map { $0.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? ""
        cadence = benefit.cadence
        selectedCard = benefit.card
        note = benefit.note
    }

    private func save() {
        let target: Benefit
        if let benefit {
            target = benefit
        } else {
            target = Benefit(name: name, cadence: cadence)
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.amount = parseAmount(amountText)
        target.cadence = cadence
        target.card = selectedCard
        target.note = note
        dismiss()
    }
}

/// Parses "$1,250.50", "50" or "50,5" into a number.
func parseAmount(_ text: String) -> Double? {
    let cleaned = text.filter { $0.isNumber || $0 == "." || $0 == "," }
    guard !cleaned.isEmpty else { return nil }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    if let number = formatter.number(from: cleaned) { return number.doubleValue }
    return Double(cleaned.replacingOccurrences(of: ",", with: ""))
}
